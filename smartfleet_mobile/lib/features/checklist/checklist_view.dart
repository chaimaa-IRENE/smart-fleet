import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/checklist_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/qr_code_service.dart';
import '../../services/decision/moteur_decision_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/signature_pad.dart';
import '../../widgets/barcode_scanner_dialog.dart';

class ChecklistView extends StatefulWidget {
  const ChecklistView({super.key});

  @override
  State<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends State<ChecklistView> {
  final ChecklistService _svc = ChecklistService();
  final VehicleService _vehicleSvc = VehicleService();
  final QrCodeService _qrSvc = QrCodeService();
  final MoteurDecisionService _moteur = MoteurDecisionService();
  List<Map<String, dynamic>> _templates = [];
  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _vehicules = [];
  bool _loading = true;
  bool _inSession = false;
  int? _currentSessionId;
  int? _currentVehiculeId;
  String _currentImmat = '';
  final Map<int, bool?> _itemValues = {};
  final Map<int, TextEditingController> _commentCtrls = {};
  final Map<int, Map<String, dynamic>> _sessionItemsMap = {};
  final Map<int, List<String>> _itemDefauts = {};

  static const List<String> _defautMotifs = [
    'Usure excessive', 'Dégât visible', 'Fuite', 'Non fonctionnel',
    'Manquant', 'Date expirée', 'Corrosion', 'Document manquant', 'Autre',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (var c in _commentCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = context.read<AuthProvider>().userId;
      _templates = await _svc.getTemplates();
      if (userId != null) {
        _sessions = await _svc.getMySessions(userId);
        _vehicules = await _vehicleSvc.getMyVehicles(userId);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _startSession(int vehiculeId, String immat) async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) return;
    setState(() => _loading = true);
    try {
      final sessionId = await _svc.startSession(vehiculeId, immat, userId);
      final items = await _svc.getSessionItems(sessionId);
      _itemValues.clear();
      _commentCtrls.clear();
      _sessionItemsMap.clear();
      _itemDefauts.clear();
      for (var item in items) {
        final id = item['id'] as int;
        _itemValues[id] = item['value'] == null ? null : (item['value'] as int) == 1;
        _commentCtrls[id] = TextEditingController(text: item['commentaire'] ?? '');
        _sessionItemsMap[id] = item;
        if (item['defauts'] != null && (item['defauts'] as String).isNotEmpty) {
          _itemDefauts[id] = (item['defauts'] as String).split(',').map((e) => e.trim()).toList();
        }
      }
      if (mounted) {
        setState(() {
          _inSession = true;
          _currentSessionId = sessionId;
          _currentVehiculeId = vehiculeId;
          _currentImmat = immat;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _completeSession() async {
    if (_currentSessionId == null) return;
    final nonDecides = _itemValues.entries.where((e) {
      final item = _templates.where((t) => t['nom'] == _getItemName(e.key)).firstOrNull;
      return item != null && item['obligatoire'] == 1 && e.value == null;
    });
    if (nonDecides.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vérifier tous les éléments obligatoires (Conforme ou Non conforme)'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final signature = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const SignatureDialog(),
    );
    if (signature == null || !mounted) return;

    setState(() => _loading = true);
    int saved = 0, failed = 0;
    for (final entry in _itemValues.entries) {
      if (entry.value != null) {
        try {
          await _svc.updateItem(
            entry.key, entry.value!,
            commentaire: _commentCtrls[entry.key]?.text,
            defauts: _itemDefauts[entry.key]?.join(', '),
          );
          saved++;
        } catch (_) {
          failed++;
        }
      }
    }
    if (failed > 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$saved/$saved+$failed éléments sauvegardés'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      setState(() => _loading = false);
      return;
    }
    final conforme = _itemValues.values.every((v) => v != false);
    final userId = context.read<AuthProvider>().userId;

    try {
      await _svc.completeSession(_currentSessionId!, conforme: conforme, signature: signature);
      if (_currentVehiculeId != null && _currentVehiculeId! > 0 && userId != null) {
        final decision = await _moteur.verifierConformite(_currentVehiculeId!, userId);
        if (!mounted) return;
        if (decision['conforme'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-up terminé - Véhicule conforme'),
              backgroundColor: AppTheme.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Véhicule NON conforme: ${decision['niveauBlocage']}'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Check-up terminé'),
              backgroundColor: AppTheme.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
    setState(() => _inSession = false);
    _load();
  }

  String _getItemName(int itemId) {
    return _sessionItemsMap[itemId]?['nom'] as String? ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_inSession) return _buildSessionView();
    return _buildListView();
  }

  Widget _buildListView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-up véhicule')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showVehicleSelector,
        child: const Icon(Icons.add),
      ),
      body: _sessions.isEmpty
          ? const Center(child: Text('Aucun check-up effectué'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _sessions.length,
                itemBuilder: (_, i) {
                  final s = _sessions[i];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        _statutIcon(s['statut'] as String? ?? 'PENDING'),
                        color: _statutColor(s['statut'] as String? ?? 'PENDING'),
                      ),
                      title: Text(s['immatriculation'] as String? ?? ''),
                      subtitle: Text(s['date'] as String? ?? ''),
                      trailing: StatusBadge(status: s['statut'] as String? ?? 'PENDING'),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildSessionView() {
    final items = _itemValues.keys.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Check-up $_currentImmat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Scanner un code-barres',
            onPressed: _openBarcodeScanner,
          ),
          TextButton(
            onPressed: _completeSession,
            child: const Text('Terminer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: items.isEmpty
          ? const Center(child: Text('Aucun élément de vérification'))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Véhicule: $_currentImmat',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final itemId = items[i];
                      final value = _itemValues[itemId];
                      final itemName = _getItemName(itemId);
                      final itemData = _sessionItemsMap[itemId];
                      final obligatoire = itemData?['obligatoire'] == 1;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CheckboxListTile(
                              tristate: true,
                              value: value,
                              onChanged: (v) => setState(() {
                                _itemValues[itemId] = v;
                                if (v != false) _itemDefauts.remove(itemId);
                              }),
                              title: Row(
                                children: [
                                  Expanded(child: Text(itemName)),
                                  if (obligatoire)
                                    const Text(' *',
                                        style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold)),
                                ],
                              ),
                              subtitle: TextField(
                                controller: _commentCtrls[itemId],
                                decoration: const InputDecoration(
                                  hintText: 'Commentaire (optionnel)',
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                              ),
                              secondary: Icon(
                                value == true
                                    ? Icons.check_circle
                                    : value == false
                                        ? Icons.cancel
                                        : Icons.help_outline,
                                color: value == true
                                    ? AppTheme.success
                                    : value == false
                                        ? AppTheme.danger
                                        : AppTheme.warning,
                              ),
                            ),
                            if (value == false)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: _defautMotifs.map((motif) {
                                    final selected = _itemDefauts[itemId]?.contains(motif) ?? false;
                                    return FilterChip(
                                      label: Text(motif, style: const TextStyle(fontSize: 12)),
                                      selected: selected,
                                      onSelected: (sel) => setState(() {
                                        _itemDefauts.putIfAbsent(itemId, () => []);
                                        if (sel) {
                                          _itemDefauts[itemId]!.add(motif);
                                        } else {
                                          _itemDefauts[itemId]!.remove(motif);
                                        }
                                      }),
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  IconData _statutIcon(String statut) {
    switch (statut) {
      case 'PENDING': return Icons.pending;
      case 'COMPLETE': return Icons.check_circle_outline;
      case 'REPAIRE': return Icons.build;
      case 'VALIDATED': return Icons.verified;
      case 'REJECTED': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  Color _statutColor(String statut) {
    switch (statut) {
      case 'PENDING': return AppTheme.warning;
      case 'COMPLETE': return const Color(0xFF2196F3);
      case 'REPAIRE': return AppTheme.warning;
      case 'VALIDATED': return AppTheme.success;
      case 'REJECTED': return AppTheme.danger;
      default: return AppTheme.textSecondary;
    }
  }

  void _showVehicleSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final vehicules = _vehicules;
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Nouveau check-up',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                const SizedBox(height: 12),
                if (vehicules.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_car,
                              size: 64, color: Colors.grey),
                          const SizedBox(height: 12),
                          Text('Aucun véhicule affecté',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          const Text(
                            'Scannez un QR code ou saisissez manuellement',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _openQrScanner();
                            },
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scanner un QR code'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showManualEntryDialog();
                            },
                            child: const Text('Saisie manuelle'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: vehicules.length + 2,
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text('Sélectionnez un véhicule',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                )),
                          );
                        }
                        if (i == vehicules.length + 1) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _openQrScanner();
                                  },
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Scanner un QR code'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 48),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showManualEntryDialog();
                                  },
                                  child: const Text('Saisir manuellement'),
                                ),
                              ],
                            ),
                          );
                        }
                        final v = vehicules[i - 1];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary,
                              child: const Icon(Icons.directions_car,
                                  color: Colors.white),
                            ),
                            title: Text(
                                v['immatriculation'] as String? ?? '',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${v['marque'] as String? ?? ''} ${v['modele'] as String? ?? ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(ctx);
                              _startSession(
                                v['id'] as int,
                                v['immatriculation'] as String,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showManualEntryDialog() {
    final immatCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisie manuelle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Entrez l\'immatriculation du véhicule'),
            const SizedBox(height: 12),
            TextField(
              controller: immatCtrl,
              decoration: const InputDecoration(
                labelText: 'Immatriculation',
                hintText: 'Ex: AA-123-BC',
                prefixIcon: Icon(Icons.directions_car),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final immat = immatCtrl.text.trim().toUpperCase();
              if (immat.isEmpty) return;
              Navigator.pop(ctx);
              _startManualSession(immat);
            },
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
  }

  Future<void> _startManualSession(String immat) async {
    try {
      final v = await _vehicleSvc.getByImmat(immat);
      if (v != null) {
        await _startSession(v['id'] as int, immat);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Véhicule introuvable. Enregistrez-le d\'abord.'),
              backgroundColor: AppTheme.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openQrScanner() async {
    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => _QrScannerScreen()),
    )?.then((result) {
      if (result != null && mounted) {
        _startSession(
          result['id'] as int,
          result['immatriculation'] as String,
        );
      }
    });
  }

  Future<void> _openBarcodeScanner() async {
    final code = await BarcodeScannerDialog.show(context);
    if (code != null && mounted) {
      final firstItem = _itemValues.keys.firstOrNull;
      if (firstItem != null) {
        final existing = _commentCtrls[firstItem]?.text ?? '';
        _commentCtrls[firstItem]?.text = existing.isEmpty ? code : '$existing\n[Code-barres] $code';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Code ajouté à "${_getItemName(firstItem)}"'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

class _QrScannerScreen extends StatefulWidget {
  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  CameraController? _camera;
  final QrCodeService _qrSvc = QrCodeService();
  final VehicleService _vehicleSvc = VehicleService();
  bool _processing = false;
  bool _camReady = false;
  Timer? _scanTimer;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission caméra requise'), backgroundColor: AppTheme.danger),
        );
      }
      return;
    }
    List<CameraDescription> cameras;
    try { cameras = await availableCameras(); } catch (_) { return; }
    if (cameras.isEmpty) return;
    final cam = CameraController(
      cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first),
      ResolutionPreset.medium,
    );
    _camera = cam;
    try { await cam.initialize(); } catch (_) { return; }
    if (!mounted) return;
    setState(() => _camReady = true);
    _scanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_processing) _autoScan();
    });
  }

  Future<void> _autoScan() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    _processing = true;
    try {
      final file = await _camera!.takePicture();
      final inputImage = InputImage.fromFilePath(file.path);
      try {
        final barcodeScanner = BarcodeScanner();
        final barcodes = await barcodeScanner.processImage(inputImage);
        await barcodeScanner.close();
        if (barcodes.isNotEmpty && mounted) {
          _scanTimer?.cancel();
          final code = barcodes.first.rawValue ?? '';
          await _processCode(code);
          return;
        }
      } finally {
        File(file.path).delete();
      }
    } catch (_) {}
    _processing = false;
  }

  Future<void> _processCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      _processing = false;
      _restartTimer();
      return;
    }

    for (final variant in [trimmed, ..._immatVariants(trimmed)]) {
      final r = await _qrSvc.scan(variant);
      if (r != null && r['vehicule'] != null) {
        final v = r['vehicule'] as Map<String, dynamic>;
        if (mounted) Navigator.pop(context, {'id': v['id'], 'immatriculation': v['immatriculation']});
        return;
      }
      final veh = await _vehicleSvc.getByImmat(variant);
      if (veh != null && mounted) {
        Navigator.pop(context, {'id': veh['id'], 'immatriculation': veh['immatriculation']});
        return;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Véhicule "$trimmed" introuvable'), backgroundColor: AppTheme.danger),
      );
    }
    _processing = false;
    _restartTimer();
  }

  void _restartTimer() {
    _scanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_processing) _autoScan();
    });
  }

  List<String> _immatVariants(String raw) {
    final variants = <String>{};
    final clean = raw.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean != raw) variants.add(clean);
    if (clean.length == 7) {
      variants.add('${clean.substring(0, 2)}-${clean.substring(2, 5)}-${clean.substring(5)}');
    }
    if (clean.length == 6) {
      variants.add('${clean.substring(0, 2)}-${clean.substring(2, 4)}-${clean.substring(4)}');
    }
    if (clean.length == 8) {
      variants.add('${clean.substring(0, 2)}-${clean.substring(2, 6)}-${clean.substring(6)}');
      variants.add('${clean.substring(0, 3)}-${clean.substring(3, 5)}-${clean.substring(5)}');
    }
    if (clean.length >= 9) {
      variants.add('${clean.substring(0, 2)}-${clean.substring(2)}');
    }
    if (raw.contains('-')) variants.add(raw.replaceAll('-', ''));
    return variants.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR code')),
      body: _camReady && _camera != null
          ? Stack(
              children: [
                CameraPreview(_camera!),
                CustomPaint(painter: _ScanOverlayPainter(), size: Size.infinite),
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
                        _processing ? 'Analyse...' : 'Scannez le QR code',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40, left: 0, right: 0,
                  child: TextButton.icon(
                    onPressed: _showManualInput,
                    icon: const Icon(Icons.edit, color: Colors.white70),
                    label: const Text('Saisir immatriculation', style: TextStyle(color: Colors.white70)),
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
                  const Text('Caméra non disponible'),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: _showManualInput,
                    icon: const Icon(Icons.edit),
                    label: const Text('Saisir immatriculation'),
                  ),
                ],
              ),
            ),
    );
  }

  void _showManualInput() {
    final immatCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saisie immatriculation'),
        content: TextField(
          controller: immatCtrl,
          decoration: const InputDecoration(
            labelText: 'Immatriculation',
            hintText: 'Ex: AA-123-BC',
            prefixIcon: Icon(Icons.directions_car),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final immat = immatCtrl.text.trim().toUpperCase();
              if (immat.isEmpty) return;
              Navigator.pop(ctx);
              await _lookupAndReturn(immat);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _lookupAndReturn(String immat) async {
    _processing = true;
    try {
      for (final variant in [immat, ..._immatVariants(immat)]) {
        final v = await _vehicleSvc.getByImmat(variant);
        if (v != null && mounted) {
          Navigator.pop(context, {'id': v['id'], 'immatriculation': v['immatriculation']});
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Véhicule non trouvé'), backgroundColor: AppTheme.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
    _processing = false;
    _restartTimer();
  }
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final s = size.shortestSide * 0.6;
    final left = (size.width - s) / 2;
    final top = (size.height - s) / 2 - 60;
    final rect = Rect.fromLTWH(left, top, s, s);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        rect,
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
        bottomLeft: const Radius.circular(12),
        bottomRight: const Radius.circular(12),
      ),
      paint,
    );
    final cp = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    const cl = 30.0;
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
