import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';

class BarcodeScannerDialog extends StatefulWidget {
  final bool Function(String code)? onScanned;

  const BarcodeScannerDialog({super.key, this.onScanned});

  static Future<String?> show(BuildContext context, {bool Function(String code)? onScanned}) {
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
  bool _camReady = false;
  bool _processing = false;
  bool _paused = false;
  Timer? _scanTimer;
  String? _lastCode;
  int _scanCount = 0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      if (mounted) Navigator.pop(context);
      return;
    }
    List<CameraDescription> cameras;
    try {
      cameras = await availableCameras();
    } catch (_) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (cameras.isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final cam = CameraController(
      cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      ),
      ResolutionPreset.medium,
    );
    _camera = cam;
    try {
      await cam.initialize();
    } catch (_) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (!mounted) return;
    setState(() => _camReady = true);
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_processing && !_paused) _autoScan();
    });
  }

  Future<void> _autoScan() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    _processing = true;
    try {
      final file = await _camera!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      final barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.all]);
      try {
        final barcodes = await barcodeScanner.processImage(inputImage);
        if (barcodes.isNotEmpty && mounted) {
          final code = barcodes.first.rawValue ?? '';
          if (code.isNotEmpty && code != _lastCode) {
            _lastCode = code;
            _scanCount++;
            final format = _formatName(barcodes.first.format);
            setState(() => _paused = true);
            if (mounted) _showResult(code, format);
            return;
          }
        }
      } finally {
        await barcodeScanner.close();
        File(file.path).delete().catchError((_) {});
      }
    } catch (_) {}
    _processing = false;
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
            const Text('Code-barres détecté'),
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
                  const Text('Contenu :',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  SelectableText(code,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
                setState(() {
                  _paused = false;
                  _processing = false;
                });
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
        Text('$label : ',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_paused ? 'Scan en pause' : 'Scanner un code-barres'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (_scanCount > 0)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$_scanCount scanné(s)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
        body: _camReady && _camera != null
            ? Stack(
                children: [
                  CameraPreview(_camera!),
                  CustomPaint(painter: _BarcodeOverlayPainter(), size: Size.infinite),
                  Positioned(
                    top: 16, left: 0, right: 0,
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
                                  : 'Placez un code-barres devant la caméra',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                  if (_paused)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _paused = false;
                          _processing = false;
                        }),
                        child: Container(
                          color: Colors.black26,
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.touch_app, color: Colors.white, size: 48),
                                SizedBox(height: 8),
                                Text('Touchez pour scanner à nouveau',
                                    style: TextStyle(color: Colors.white, fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Caméra non disponible'),
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
        rect, topLeft: const Radius.circular(8), topRight: const Radius.circular(8),
        bottomLeft: const Radius.circular(8), bottomRight: const Radius.circular(8),
      ),
      paint,
    );
    final cp = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const cl = 24.0;
    final corners = [
      rect.topLeft, rect.topRight,
      rect.bottomLeft, rect.bottomRight,
    ];
    for (var c in corners) {
      canvas.drawLine(c, c + const Offset(cl, 0), cp);
      canvas.drawLine(c, c + const Offset(0, cl), cp);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
