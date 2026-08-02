import 'dart:async';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';
import '../utils/nv21_conversion.dart';

/// Scanner multi-format (QR codes + codes-barres 1D : EAN-13, Code-128,
/// Code-39, UPC, ITF, DataMatrix, PDF417, Aztec, ...).
///
/// Détection en temps réel via le flux d'images continu (`startImageStream`,
/// conversion NV21) avec ML Kit. Autofocus + tap-to-focus, torche pour les
/// faibles luminosités et cadre de visée (bounding box).
class BarcodeScannerDialog extends StatefulWidget {
  /// Appelé après un scan. Retournez `true` pour clôturer le scanner avec le
  /// code, ou `false` pour continuer à scanner.
  final bool Function(String code)? onScanned;

  const BarcodeScannerDialog({super.key, this.onScanned});

  /// Ouvre le scanner et retourne le contenu décodé (matricule, ...) ou `null`
  /// si l'utilisateur ferme sans résultat.
  static Future<String?> show(
    BuildContext context, {
    bool Function(String code)? onScanned,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BarcodeScannerDialog(onScanned: onScanned),
    );
  }

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  CameraController? _camera;
  BarcodeScanner? _barcodeScanner;

  bool _camReady = false;
  bool _processing = false;
  bool _paused = false;
  bool _noCodeHint = false;
  bool _torchOn = false;
  bool _torchAvailable = true;
  String? _camError;

  Timer? _focusTimer;
  Timer? _timeoutTimer;

  int _scanCount = 0;
  int _consecutiveEmpty = 0;
  String? _lastCode;
  DateTime? _lastDecodeAt;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);

  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  static const Duration _minFrameInterval = Duration(milliseconds: 200);
  static const Duration _sameCodeCooldown = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
    _initCamera();
  }

  @override
  void dispose() {
    _focusTimer?.cancel();
    _timeoutTimer?.cancel();
    _camera?.stopImageStream();
    _camera?.dispose();
    _barcodeScanner?.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final orientation = MediaQuery.orientationOf(context);
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        setState(() => _camError = 'Permission caméra refusée. Autorisez la caméra dans les réglages.');
      }
      return;
    }

    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (e) {
      print('[SCAN] availableCameras ERR $e');
      if (mounted) setState(() => _camError = 'Caméra introuvable ($e)');
      return;
    }
    if (cameras.isEmpty) {
      print('[SCAN] no cameras');
      if (mounted) setState(() => _camError = 'Aucune caméra détectée sur cet appareil');
      return;
    }

    final description = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    // L'ouverture caméra peut échouer transitoirement sur certains appareils
    // (trop tôt après le lancement) : on réessaie quelques fois.
    CameraController? cam;
    Object? lastErr;
    for (var attempt = 1; attempt <= 5; attempt++) {
      final c = CameraController(
        description,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _camera = c;
      try {
        await c.initialize();
        lastErr = null;
        cam = c;
        break;
      } catch (e) {
        lastErr = e;
        print('[SCAN] init essai $attempt ERR $e');
        try {
          await c.dispose();
        } catch (_) {}
        _camera = null;
        if (attempt < 5) await Future.delayed(const Duration(seconds: 2));
      }
    }
    if (cam == null) {
      if (mounted) setState(() => _camError = 'Impossible d\'ouvrir la caméra : $lastErr');
      return;
    }

    // Autofocus + exposition automatique.
    try {
      await cam.setFocusMode(FocusMode.auto);
    } catch (_) {}
    try {
      await cam.setExposureMode(ExposureMode.auto);
    } catch (_) {}

    // Rotation à appliquer à l'image (portrait : écran à 90°).
    final sensor = description.sensorOrientation;
    final device = orientation == Orientation.landscape ? 0 : 90;
    _rotation = rotationFromDegrees((sensor - device + 360) % 360);

    if (!mounted) return;
    setState(() {
      _camReady = true;
      _camError = null;
    });

    // Analyse image : flux continu (NV21) → ML Kit.
    try {
      await cam.startImageStream(_onFrame);
    } catch (e) {
      print('[SCAN] startImageStream ERR $e');
      if (mounted) setState(() => _camError = 'Impossible de lancer l\'analyse ($e)');
    }

    // Refocus périodique pour les codes-barres 1D (sensibles au flou).
    _focusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final c = _camera;
      if (c == null || !c.value.isInitialized || _paused) return;
      try {
        await c.setFocusMode(FocusMode.auto);
      } catch (_) {}
    });

    _startTimeout();
  }

  static const Duration _timeout = Duration(seconds: 30);

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeout, () {
      if (!mounted || _paused || _scanCount > 0) return;
      _showNoCode();
    });
  }

  /// Aucun code détecté avant le timeout : propose de réessayer ou de fermer.
  void _showNoCode() {
    if (!mounted) return;
    print('[SCAN] TIMEOUT aucun code détecté');
    setState(() => _paused = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.qr_code_scanner, color: AppTheme.warning, size: 36),
        title: const Text('Aucun code détecté'),
        content: const Text(
          'Aucun QR code ou code-barres n\'a été lu. Vérifiez :\n'
          '• l\'éclairage (bouton torche)\n'
          '• la netteté (approchez/éloignez, touchez pour la mise au point)\n'
          '• que le code est un code standard (EAN, Code 128, Code 39, …)',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (mounted) {
                _resume();
                _startTimeout();
              }
            },
            child: const Text('Réessayer'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Traitement continu d'une image caméra (throttlé ~5 img/s).
  Future<void> _onFrame(CameraImage image) async {
    final scanner = _barcodeScanner;
    final cam = _camera;
    if (scanner == null || cam == null || !cam.value.isInitialized) return;
    if (_paused || _processing) return;

    final now = DateTime.now();
    if (now.difference(_lastFrameAt) < _minFrameInterval) return;
    _lastFrameAt = now;

    _processing = true;
    try {
      final bytes = convertYuv420ToNv21(image);
      if (bytes == null) return;

      final barcodes = await scanner.processImage(
        InputImage.fromBytes(
          bytes: bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: _rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.planes[0].bytesPerRow,
          ),
        ),
      );

      if (!mounted) return;

      final valid = barcodes.where((b) => (b.rawValue ?? '').trim().isNotEmpty).toList();
      if (valid.isNotEmpty) {
        final b = valid.first;
        final code = b.rawValue!.trim();
        print('[SCAN] DETECTED format=${b.format} code=$code total=${valid.length}');
        final same = code == _lastCode;
        final cooldown = _lastDecodeAt != null &&
            now.difference(_lastDecodeAt!) < _sameCodeCooldown;
        if (same && cooldown) return;

        _lastCode = code;
        _lastDecodeAt = now;
        _scanCount++;
        setState(() {
          _paused = true;
          _noCodeHint = false;
        });
        if (mounted) _showResult(code, _formatName(b.format));
        return;
      }

      setState(() {
        _consecutiveEmpty++;
        if (_consecutiveEmpty >= 15) _noCodeHint = true;
      });
    } catch (e) {
      print('[SCAN] ERR $e');
      // Image illisible ou erreur MLKit : on continue la boucle.
    } finally {
      _processing = false;
    }
  }

  Future<void> _toggleTorch() async {
    final cam = _camera;
    if (cam == null) return;
    try {
      await cam.setFlashMode(_torchOn ? FlashMode.off : FlashMode.torch);
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      if (mounted) setState(() => _torchAvailable = false);
    }
  }

  Future<void> _tapToFocus(TapDownDetails details) async {
    final cam = _camera;
    if (cam == null) return;
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return;
      final local = box.globalToLocal(details.globalPosition);
      final size = box.size;
      if (size.width == 0 || size.height == 0) return;
      final point = Offset(
        (local.dx / size.width).clamp(0.0, 1.0),
        (local.dy / size.height).clamp(0.0, 1.0),
      );
      await cam.setFocusPoint(point);
      await cam.setExposurePoint(point);
    } catch (_) {}
  }

  void _resume() {
    setState(() {
      _paused = false;
      _processing = false;
      _noCodeHint = false;
    });
    _startTimeout();
  }

  String _formatName(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.qrCode: return 'QR Code';
      case BarcodeFormat.ean8: return 'EAN-8';
      case BarcodeFormat.ean13: return 'EAN-13';
      case BarcodeFormat.upca: return 'UPC-A';
      case BarcodeFormat.upce: return 'UPC-E';
      case BarcodeFormat.code39: return 'Code 39';
      case BarcodeFormat.code93: return 'Code 93';
      case BarcodeFormat.code128: return 'Code 128';
      case BarcodeFormat.codabar: return 'Codabar';
      case BarcodeFormat.itf: return 'ITF';
      case BarcodeFormat.dataMatrix: return 'Data Matrix';
      case BarcodeFormat.pdf417: return 'PDF417';
      case BarcodeFormat.aztec: return 'Aztec';
      default: return 'Inconnu';
    }
  }

  void _showResult(String code, String format) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner, color: AppTheme.success),
            const SizedBox(width: 8),
            const Flexible(
              child: Text('Code détecté', overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Format', format),
            const SizedBox(height: 8),
            _infoRow('Scan n°', '$_scanCount'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Matricule / contenu :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    code,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onScanned != null && widget.onScanned!(code)) {
                Navigator.pop(context, code);
              } else {
                _resume();
              }
            },
            child: const Text('Scanner suivant'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, code),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label : ',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_paused ? 'Scan en pause' : 'Scanner code-barres / QR'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_torchAvailable)
              IconButton(
                icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off,
                    color: _torchOn ? AppTheme.warning : null),
                tooltip: _torchOn ? 'Éteindre la torche' : 'Allumer la torche',
                onPressed: _toggleTorch,
              ),
            if (_scanCount > 0)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_scanCount scanné(s)',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
        body: _camReady && _camera != null
            ? Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: _tapToFocus,
                      child: CameraPreview(_camera!),
                    ),
                  ),
                  CustomPaint(painter: _BarcodeOverlayPainter(), size: Size.infinite),
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _paused
                              ? 'Scanner en pause'
                              : _processing
                                  ? 'Analyse...'
                                  : 'Alignez le code dans le cadre',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  if (_noCodeHint && !_paused)
                    Positioned(
                      bottom: 24,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lightbulb_outline, color: AppTheme.warning, size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Aucun code détecté : éclairez le code (bouton torche) ou ajustez la distance',
                                style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_paused)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _resume,
                        child: Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app, color: Colors.white, size: 48),
                                SizedBox(height: 8),
                                Text(
                                  'Touchez pour scanner à nouveau',
                                  style: TextStyle(color: Colors.white, fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _camError ?? 'Caméra non disponible',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _camError = null);
                        _initCamera();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _BarcodeOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final h = size.height * 0.25;
    final w = size.width * 0.8;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2 - 40;
    final rect = Rect.fromLTWH(left, top, w, h);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      ),
      paint,
    );
    final cp = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const cl = 24.0;
    final corners = [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight];
    for (final c in corners) {
      canvas.drawLine(c, c + const Offset(cl, 0), cp);
      canvas.drawLine(c, c + const Offset(0, cl), cp);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
