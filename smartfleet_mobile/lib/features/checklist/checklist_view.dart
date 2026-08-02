import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/checklist_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/document_service.dart';
import '../../services/scan_code_service.dart';
import '../../services/decision/moteur_decision_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/signature_pad.dart';
import '../../widgets/barcode_scanner_dialog.dart';
import '../../utils/nv21_conversion.dart';

class ChecklistView extends StatefulWidget {
  const ChecklistView({super.key});

  @override
  State<ChecklistView> createState() => _ChecklistViewState();
}

class _ChecklistViewState extends State<ChecklistView> {
  final ChecklistService _svc = ChecklistService();
  final VehicleService _vehicleSvc = VehicleService();
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
          _checkDepartureAuthorization(_currentImmat);
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

  /// Ouvre le scanner code-barres du checkup : caméra en direct (multi-format)
  /// ou image importée (gallery) pour tester des photos réelles.
  Future<void> _openBarcodeScanner() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Scanner code-barres / QR',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Caméra en direct ou photo importée (gallery)',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primary),
              title: const Text('Scanner avec la caméra'),
              subtitle: const Text('QR + codes-barres (EAN, Code 128, Code 39, UPC…) en continu'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.accent),
              title: const Text('Importer une image'),
              subtitle: const Text('Photo de code collé sur véhicule / document'),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    if (source == 'camera') {
      final code = await BarcodeScannerDialog.show(context);
      if (code != null && code.trim().isNotEmpty && mounted) {
        _handleScannedCode(code.trim());
      }
    } else if (source == 'image') {
      await _scanFromImage();
    }
  }

  /// Décode un code-barres / QR depuis une image importée (gallery), via
  /// ML Kit (`InputImage.fromFilePath`). Utile pour tester des photos réelles.
  Future<void> _scanFromImage() async {
    if (!mounted) return;
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 90,
    );
    if (file == null || !mounted) return;

    // Indicateur d'analyse.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Analyse de l\'image…'),
              ],
            ),
          ),
        ),
      ),
    );

    String? code;
    BarcodeFormat? format;
    String? error;
    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final scanner = BarcodeScanner(formats: [BarcodeFormat.all]);
      try {
        final barcodes = await scanner.processImage(inputImage);
        final valid =
            barcodes.where((b) => (b.rawValue ?? '').trim().isNotEmpty).toList();
        if (valid.isNotEmpty) {
          code = valid.first.rawValue!.trim();
          format = valid.first.format;
        }
      } finally {
        scanner.close();
      }
    } catch (e) {
      error = '$e';
    }

    if (!mounted) return;
    Navigator.of(context).pop(); // ferme l'indicateur

    if (code == null || code.isEmpty) {
      await _showImageResult(
        ok: false,
        format: null,
        code: null,
        error: error,
      );
      return;
    }

    _handleScannedCode(code);
    await _showImageResult(
      ok: true,
      format: format,
      code: code,
      error: error,
    );
  }

  /// Affiche le résultat du décodage d'une image importée.
  Future<void> _showImageResult({
    required bool ok,
    required BarcodeFormat? format,
    required String? code,
    String? error,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          ok ? Icons.check_circle : Icons.error_outline,
          color: ok ? AppTheme.success : AppTheme.danger,
          size: 36,
        ),
        title: Text(ok ? 'Code détecté' : 'Aucun code détecté'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (ok) ...[
              _kv('Format', _formatName(format)),
              const SizedBox(height: 8),
              _kv('Contenu', code ?? ''),
              const SizedBox(height: 12),
              const Text(
                'Le contenu a été ajouté au commentaire du premier élément.',
                style: TextStyle(fontSize: 13),
              ),
            ] else ...[
              const Text(
                'Cette image ne contient aucun code-barres ou QR lisible. '
                'Vérifiez :\n'
                '• la netteté de la photo\n'
                '• l\'éclairage\n'
                '• que le code est standard (EAN, Code 128, Code 39, …)',
                style: TextStyle(fontSize: 13),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Erreur technique : $error',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  String _formatName(BarcodeFormat? format) {
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

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label : ',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Ajoute le code scanné au commentaire du premier élément de la checklist.
  void _handleScannedCode(String code) {
    if (!mounted) return;
    final firstItem = _itemValues.keys.firstOrNull;
    if (firstItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun élément de checklist disponible'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }
    final existing = _commentCtrls[firstItem]?.text ?? '';
    _commentCtrls[firstItem]?.text =
        existing.isEmpty ? code : '$existing\n[Code-barres] $code';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Code ajouté à "${_getItemName(firstItem)}"'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _checkDepartureAuthorization(String immat) async {
    if (!mounted) return;
    try {
      final docSvc = DocumentVehiculeService();
      final documents = await docSvc.getByVehicule(_currentVehiculeId ?? 0);
      final expired = documents.where((d) => docSvc.getStatutDocument(d) == 'EXPIRE').toList();
      final expiringSoon = documents.where((d) => docSvc.getStatutDocument(d) == 'BIENTOT_EXPIRE').toList();

      final blocked = _vehicules.where((v) => v['id'] == _currentVehiculeId && v['statut'] == 'BLOQUE').isNotEmpty;
      final nonConforme = _itemValues.values.any((v) => v == false);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            Icon(expired.isEmpty && !blocked && !nonConforme ? Icons.check_circle : Icons.warning, color: expired.isEmpty && !blocked && !nonConforme ? AppTheme.success : AppTheme.danger),
            const SizedBox(width: 8),
            const Text('Autorisation de départ'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Véhicule: $immat', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            _departRow('Conformité check-up', !nonConforme, nonConforme ? 'Non conforme' : 'OK'),
            _departRow('Statut véhicule', !blocked, blocked ? 'BLOQUÉ' : 'Disponible'),
            if (expired.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Documents expirés:', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
              ...expired.map((d) => Text('  • ${d['type'] ?? ''} (${d['dateExpiration'] ?? ''})', style: const TextStyle(fontSize: 13, color: AppTheme.danger))),
            ],
            if (expiringSoon.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Documents bientôt expirés:', style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600)),
              ...expiringSoon.map((d) => Text('  • ${d['type'] ?? ''} (${d['dateExpiration'] ?? ''})', style: const TextStyle(fontSize: 13, color: AppTheme.warning))),
            ],
            const Divider(),
            Row(children: [
              const Text('Autorisation: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: expired.isEmpty && !blocked && !nonConforme ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  expired.isEmpty && !blocked && !nonConforme ? 'DÉPART AUTORISÉ' : 'DÉPART BLOQUÉ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: expired.isEmpty && !blocked && !nonConforme ? AppTheme.success : AppTheme.danger,
                    fontSize: 13,
                  ),
                ),
              ),
            ]),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer'))],
        ),
      );
    } catch (_) {}
  }

  Widget _departRow(String label, bool ok, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(ok ? Icons.check_circle : Icons.cancel, size: 18, color: ok ? AppTheme.success : AppTheme.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(detail, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: ok ? AppTheme.success : AppTheme.danger)),
      ]),
    );
  }
}

class _QrScannerScreen extends StatefulWidget {
  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  CameraController? _camera;
  BarcodeScanner? _barcodeScanner;
  final ScanCodeService _scanSvc = ScanCodeService();
  bool _processing = false;
  bool _camReady = false;
  String? _camError;

  Timer? _focusTimer;

  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  String? _lastCode;
  DateTime? _lastDecodeAt;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);

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
    _camera?.stopImageStream();
    _camera?.dispose();
    _barcodeScanner?.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission caméra requise'), backgroundColor: AppTheme.danger),
        );
        setState(() => _camError = 'Permission caméra refusée. Autorisez la caméra dans les réglages.');
      }
      return;
    }
    List<CameraDescription> cameras;
    try { cameras = await availableCameras(); } catch (e) { print('[SCAN] availableCameras ERR $e'); if (mounted) setState(() => _camError = 'Caméra introuvable ($e)'); return; }
    if (cameras.isEmpty) { print('[SCAN] no cameras'); if (mounted) setState(() => _camError = 'Aucune caméra détectée sur cet appareil'); return; }

    final orientation = MediaQuery.orientationOf(context);
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
        try { await c.dispose(); } catch (_) {}
        _camera = null;
        if (attempt < 5) await Future.delayed(const Duration(seconds: 2));
      }
    }
    if (cam == null) {
      if (mounted) setState(() => _camError = 'Impossible d\'ouvrir la caméra : $lastErr');
      return;
    }

    try { await cam.setFocusMode(FocusMode.auto); } catch (_) {}
    try { await cam.setExposureMode(ExposureMode.auto); } catch (_) {}

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
    }

    // Refocus périodique pour les codes-barres 1D (sensibles au flou).
    _focusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final c = _camera;
      if (c == null || !c.value.isInitialized) return;
      try {
        await c.setFocusMode(FocusMode.auto);
      } catch (_) {}
    });
  }

  /// Traitement continu d'une image caméra (throttlé) pour détecter QR codes
  /// et codes-barres 1D en temps réel.
  Future<void> _onFrame(CameraImage image) async {
    final scanner = _barcodeScanner;
    final cam = _camera;
    if (scanner == null || cam == null || !cam.value.isInitialized) return;
    if (_processing) return;

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
        final code = valid.first.rawValue!.trim();
        print('[SCAN] DETECTED format=${valid.first.format} code=$code total=${valid.length}');
        final same = code == _lastCode;
        final cooldown = _lastDecodeAt != null &&
            now.difference(_lastDecodeAt!) < _sameCodeCooldown;
        if (same && cooldown) return;

        _lastCode = code;
        _lastDecodeAt = now;
        await _processCode(code);
        return;
      }
    } catch (e) {
      print('[SCAN] ERR $e');
      // Image illisible ou erreur MLKit : on continue la boucle.
    } finally {
      _processing = false;
    }
  }

  Future<void> _processCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      _processing = false;
      return;
    }

    final result = await _scanSvc.resolve(trimmed);
    if (result != null && mounted) {
      Navigator.pop(context, {'id': result['id'], 'immatriculation': result['immatriculation']});
      return;
    }

    if (mounted) _showVehicleNotFound(trimmed);
    _processing = false;
  }

  Future<void> _lookupAndReturn(String immat) async {
    _processing = true;
    try {
      final result = await _scanSvc.resolve(immat);
      if (result != null && mounted) {
        Navigator.pop(context, {'id': result['id'], 'immatriculation': result['immatriculation']});
        return;
      }
      if (mounted) _showVehicleNotFound(immat);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
    _processing = false;
  }

  /// Explique au chauffeur la cause réelle d'un code scanné / saisi qui ne
  /// correspond à aucun véhicule enregistré.
  void _showVehicleNotFound(String code) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.search_off, color: AppTheme.warning, size: 36),
        title: const Text('Véhicule introuvable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le code « $code » ne correspond à aucun véhicule enregistré dans l\'application.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Causes possibles :\n'
              '• Le code lu est incorrect ou incomplet.\n'
              '• Le véhicule n\'a pas encore été ajouté à la base.\n'
              '• Le code correspond à un autre identifiant.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Faites vérifier le code et l\'ajout du véhicule par votre administrateur '
              '(Admin → Véhicules) avant de démarrer le check-up.',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan véhicule')),
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
                        _processing ? 'Analyse...' : 'Scannez QR code ou code-barres',
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
                    onPressed: _initCamera,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
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
