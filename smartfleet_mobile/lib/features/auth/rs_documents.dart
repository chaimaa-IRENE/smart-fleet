import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/vehicle_service.dart';
import '../../database/dao/document_dao.dart';

const _docTypes = [
  {'value': 'ASSURANCE', 'label': 'Assurance', 'icon': Icons.shield, 'mois': 12, 'obligatoire': true},
  {'value': 'CARTE_GRISE', 'label': 'Carte Grise', 'icon': Icons.assignment, 'mois': 120, 'obligatoire': true},
  {'value': 'VISITE_TECHNIQUE', 'label': 'Visite Technique', 'icon': Icons.car_repair, 'mois': 12, 'obligatoire': true},
  {'value': 'VIGNETTE', 'label': 'Vignette', 'icon': Icons.verified, 'mois': 12, 'obligatoire': false},
  {'value': 'AUTORISATION', 'label': 'Autorisation', 'icon': Icons.description, 'mois': 6, 'obligatoire': false},
  {'value': 'CONTROLE_TACHYGRAPHE', 'label': 'Controle Tachygraphe', 'icon': Icons.access_time, 'mois': 24, 'obligatoire': true},
  {'value': 'ONSSA', 'label': 'ONSSA', 'icon': Icons.verified_user, 'mois': 24, 'obligatoire': true},
  {'value': 'METROLOGIQUE', 'label': 'Metrologique', 'icon': Icons.speed, 'mois': 12, 'obligatoire': false},
];
const _obligatoireTypes = ['ASSURANCE', 'CARTE_GRISE', 'VISITE_TECHNIQUE', 'CONTROLE_TACHYGRAPHE', 'ONSSA'];

String _typeLabel(String t) => _docTypes.firstWhere((d) => d['value'] == t, orElse: () => {'label': t})['label'] as String;
IconData _typeIcon(String t) => _docTypes.firstWhere((d) => d['value'] == t, orElse: () => {'icon': Icons.description})['icon'] as IconData;

DateTime? _toDate(dynamic v) {
  if (v == null) return null;
  if (v is String) {
    final dt = DateTime.tryParse(v);
    if (dt != null) return dt;
  }
  if (v is List && v.length >= 3) {
    try { return DateTime(v[0], v[1], v[2]); } catch (_) { return null; }
  }
  return null;
}

String _fmtDate(dynamic v) {
  final dt = _toDate(v);
  if (dt == null) return '—';
  return '${dt.day}/${dt.month}/${dt.year}';
}

String _fmtDateTime(dynamic v) {
  final dt = _toDate(v);
  if (dt == null) return '—';
  return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _calcExpiration(String emission, int mois) {
  final dt = _toDate(emission);
  if (dt == null) return '';
  return DateTime(dt.year, dt.month + mois, dt.day).toIso8601String().split('T')[0];
}

({String label, Color color, Color bg, IconData icon}) _statusInfo(String? dateStr, {bool manquant = false}) {
  if (manquant || dateStr == null) return (label: 'Manquant', color: Colors.grey, bg: Colors.grey.withValues(alpha: 0.1), icon: Icons.block);
  final dt = _toDate(dateStr);
  if (dt == null) return (label: 'Manquant', color: Colors.grey, bg: Colors.grey.withValues(alpha: 0.1), icon: Icons.block);
  final days = dt.difference(DateTime.now()).inDays;
  if (days < 0) return (label: 'Expire (${days.abs()}j)', color: Colors.red, bg: Colors.red.withValues(alpha: 0.1), icon: Icons.error);
  if (days <= 30) return (label: 'Expire bientot (${days}j)', color: Colors.orange, bg: Colors.orange.withValues(alpha: 0.1), icon: Icons.warning);
  return (label: 'Valide (${days}j)', color: Colors.green, bg: Colors.green.withValues(alpha: 0.1), icon: Icons.check_circle);
}

class RsDocuments extends StatefulWidget {
  final bool showAppBar;
  const RsDocuments({super.key, this.showAppBar = true});

  @override
  State<RsDocuments> createState() => _RsDocumentsState();
}

class _RsDocumentsState extends State<RsDocuments> {
  final VehicleService _vSvc = VehicleService();
  final DocumentVehiculeDao _docDao = DocumentVehiculeDao();
  List<Map<String, dynamic>> _vehicules = [];
  List<Map<String, dynamic>> _documents = [];
  bool _loading = true;
  String _search = '';
  String _filterType = '';
  String _filterStatus = '';
  String _filterVehicle = '';

  // Form
  bool _showForm = false;
  Map<String, dynamic>? _editDoc;
  final _formData = <String, dynamic>{
    'vehiculeId': 0, 'vehiculeImmatriculation': '', 'typeDocument': 'ASSURANCE',
    'numeroDocument': '', 'dateEmission': '', 'dureeAnnees': 1, 'dureeMois': 0, 'dureeJours': 0,
    'notes': '', 'fichiers': <String>[],
  };
  String _expiryDate = '';

  // Detail
  Map<String, dynamic>? _showDetail;

  String? _toastMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_vSvc.getAll(), _fetchDocs()]);
      if (mounted) setState(() { _vehicules = results[0]; _documents = results[1]; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<List<Map<String, dynamic>>> _fetchDocs() async {
    List<Map<String, dynamic>> apiDocs = [];
    try {
      final client = http.Client();
      final res = await client.get(Uri.parse('${ApiConfig.baseUrl}/documents-vehicule')).timeout(ApiConfig.timeout);
      client.close();
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data is List ? data : (data['documents'] ?? []) as List).cast<Map<String, dynamic>>();
        apiDocs = list.map((d) => _enrichDoc(d)).toList();
      }
    } catch (_) {}
    // Merge local docs (created offline / fallback) not present in API
    try {
      final localDocs = (await _docDao.getAll()).map((d) => _enrichDoc(d)).toList();
      for (final ld in localDocs) {
        final dup = apiDocs.any((ad) =>
          ad['vehiculeId'] == ld['vehiculeId'] &&
          ad['typeDocument'] == ld['typeDocument'] &&
          (ad['numeroDocument'] ?? '') == (ld['numeroDocument'] ?? ''));
        if (!dup) apiDocs.add(ld);
      }
    } catch (_) {}
    return apiDocs;
  }

  Map<String, dynamic> _enrichDoc(Map<String, dynamic> d) {
    final dateExp = d['dateExpiration'] as String?;
    final manquant = d['estDisponible'] == false;
    final info = _statusInfo(dateExp, manquant: manquant);
    final immat = d['vehiculeImmatriculation'] as String? ?? d['immatriculation'] as String? ?? '';
    return {
      ...d,
      'vehiculeImmatriculation': immat,
      'immatriculation': immat,
      'statut': manquant ? 'MANQUANT' : info.label.contains('Valide') ? 'VALIDE' : info.label.contains('bientot') ? 'EXPIRE_BIENTOT' : info.label.contains('Expire') ? 'EXPIRE' : 'MANQUANT',
      'joursRestants': dateExp != null ? _toDate(dateExp)!.difference(DateTime.now()).inDays : 0,
      'piecesJointes': (d['piecesJointes'] as List?) ?? (d['fichierUrl'] != null ? [{'name': d['fichierUrl'], 'url': d['fichierUrl']}] : []),
      'historique': (d['historique'] as List?) ?? [],
      'notes': d['notes'] ?? '',
      'responsableNom': d['importePar'] ?? d['responsableNom'] ?? '',
      'createdAt': d['createdAt'] ?? d['dateImport'] ?? '',
      'updatedAt': d['updatedAt'] ?? '',
    };
  }

  Map<String, dynamic> get _docStats {
    final docs = _documents;
    return {
      'valides': docs.where((d) => d['statut'] == 'VALIDE').length,
      'expireBientot': docs.where((d) => d['statut'] == 'EXPIRE_BIENTOT').length,
      'expires': docs.where((d) => d['statut'] == 'EXPIRE').length,
      'manquants': docs.where((d) => d['statut'] == 'MANQUANT').length,
      'total': docs.length,
    };
  }

  List<Map<String, dynamic>> get _filteredDocs {
    return _documents.where((d) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final immat = (d['vehiculeImmatriculation'] as String? ?? '').toLowerCase();
        final numDoc = (d['numeroDocument'] as String? ?? '').toLowerCase();
        final type = _typeLabel(d['typeDocument'] as String? ?? '').toLowerCase();
        if (!immat.contains(q) && !numDoc.contains(q) && !type.contains(q)) return false;
      }
      if (_filterType.isNotEmpty && d['typeDocument'] != _filterType) return false;
      if (_filterStatus.isNotEmpty && d['statut'] != _filterStatus) return false;
      if (_filterVehicle.isNotEmpty && d['vehiculeImmatriculation'] != _filterVehicle) return false;
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _blockedVehicles {
    final blocked = <Map<String, dynamic>>[];
    for (final v in _vehicules) {
      final vDocs = _documents.where((d) => d['vehiculeId'] == v['id']).toList();
      for (final reqType in _obligatoireTypes) {
        final doc = vDocs.cast<Map<String, dynamic>?>().firstWhere((d) => d?['typeDocument'] == reqType, orElse: () => null);
        if (doc == null || doc['statut'] == 'MANQUANT' || doc['statut'] == 'EXPIRE') {
          blocked.add({
            'immatriculation': v['immatriculation'] ?? v['truckNumber'] ?? '',
            'typeManquant': _typeLabel(reqType),
            'statut': doc == null ? 'MANQUANT' : doc['statut'],
          });
          break;
        }
      }
    }
    return blocked;
  }

  List<Map<String, dynamic>> get _conformiteVehicules {
    return _vehicules.map((v) {
      final vDocs = _documents.where((d) => d['vehiculeId'] == v['id']).toList();
      int valides = 0;
      for (final t in _obligatoireTypes) {
        final doc = vDocs.cast<Map<String, dynamic>?>().firstWhere((d) => d?['typeDocument'] == t, orElse: () => null);
        if (doc != null && (doc['statut'] == 'VALIDE' || doc['statut'] == 'EXPIRE_BIENTOT')) valides++;
      }
      return {
        'immatriculation': v['immatriculation'] ?? v['truckNumber'] ?? '',
        'total': _obligatoireTypes.length,
        'valides': valides,
        'conformite': _obligatoireTypes.isNotEmpty ? (valides / _obligatoireTypes.length * 100).round() : 100,
      };
    }).toList();
  }

  List<Map<String, dynamic>> get _notifications {
    return _documents
      .where((d) => d['statut'] != 'MANQUANT' && d['dateExpiration'] != null)
      .map((d) => {'doc': d, 'joursRestants': _toDate(d['dateExpiration'])!.difference(DateTime.now()).inDays})
      .where((n) => (n['joursRestants'] as int) <= 30)
      .toList()
      ..sort((a, b) => (a['joursRestants'] as int).compareTo(b['joursRestants'] as int));
  }

  void _resetForm() {
    if (!mounted) return;
    setState(() {
      _formData['vehiculeId'] = 0;
      _formData['vehiculeImmatriculation'] = '';
      _formData['typeDocument'] = 'ASSURANCE';
      _formData['numeroDocument'] = '';
      _formData['dateEmission'] = '';
      _formData['dureeAnnees'] = 1;
      _formData['dureeMois'] = 0;
      _formData['dureeJours'] = 0;
      _formData['notes'] = '';
      _formData['fichiers'] = <String>[];
      _expiryDate = '';
      _editDoc = null;
      _showForm = false;
    });
  }

  void _openEdit(Map<String, dynamic> doc) {
    if (!mounted) return;
    final em = _toDate(doc['dateEmission']);
    final ex = _toDate(doc['dateExpiration']);
    int yrs = 1, mos = 0;
    if (em != null && ex != null) {
      int totalM = (ex.year - em.year) * 12 + (ex.month - em.month);
      if (ex.day < em.day) totalM -= 1;
      if (totalM < 1) {
        final dt = _docTypes.firstWhere((d) => d['value'] == doc['typeDocument'], orElse: () => {'mois': 12});
        totalM = dt['mois'] as int;
      }
      yrs = totalM ~/ 12;
      mos = totalM % 12;
    }
    // dys unused - kept for API compatibility
    setState(() {
      _editDoc = doc;
      _formData['vehiculeId'] = doc['vehiculeId'] ?? 0;
      _formData['vehiculeImmatriculation'] = doc['vehiculeImmatriculation'] ?? '';
      _formData['typeDocument'] = doc['typeDocument'] ?? 'ASSURANCE';
      _formData['numeroDocument'] = doc['numeroDocument'] ?? '';
      _formData['dateEmission'] = doc['dateEmission'] is String ? (doc['dateEmission'] as String).split('T')[0] : '';
      _formData['dureeAnnees'] = yrs;
      _formData['dureeMois'] = mos;
      _formData['dureeJours'] = 0;
      _formData['notes'] = doc['notes'] ?? '';
      _formData['fichiers'] = <String>[];
      _expiryDate = doc['dateExpiration'] is String ? (doc['dateExpiration'] as String).split('T')[0] : '';
      _showForm = true;
    });
  }

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() => _toastMsg = msg);
    Future.delayed(const Duration(seconds: 3), () { if (mounted) setState(() => _toastMsg = null); });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final stats = _docStats;
    final blocked = _blockedVehicles;
    final notifyDocs = _notifications;
    final filtered = _filteredDocs;

    final bodyContent = Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            // Toast
            if (_toastMsg != null)
              Container(
                width: double.infinity, margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withValues(alpha: 0.3))),
                child: Text(_toastMsg!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),

            // Header (embedded mode) — web-style: title + refresh + Nouveau Document
            if (!widget.showAppBar) ...[
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Gestion Documents Vehicules', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Suivi, conformite et alertes documentaires', style: TextStyle(fontSize: 10, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Rafraichir',
                  onPressed: _load,
                ),
              ]),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nouveau Document', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () { _resetForm(); setState(() { _editDoc = null; _showForm = true; }); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // === DASHBOARD ===
            // Stats cards
            Row(children: [
              _statCard('Valides', '${stats['valides']}', Colors.green, Icons.check_circle),
              const SizedBox(width: 6),
              _statCard('Expire bientot', '${stats['expireBientot']}', Colors.orange, Icons.warning),
              const SizedBox(width: 6),
              _statCard('Expires', '${stats['expires']}', Colors.red, Icons.error),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _statCard('Manquants', '${stats['manquants']}', Colors.grey, Icons.block),
              const SizedBox(width: 6),
              _statCard('Total', '${stats['total']}', Colors.blue, Icons.description),
              const SizedBox(width: 6),
              _statCard('Notifications', '${notifyDocs.length}', Colors.purple, Icons.notifications_active),
            ]),
            const SizedBox(height: 12),

            // Blocked vehicles
            if (blocked.isNotEmpty)
              Container(
                width: double.infinity, margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.2))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.block, size: 16, color: Colors.red),
                    const SizedBox(width: 6),
                    Text('${blocked.length} vehicule(s) non conforme(s)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                  const SizedBox(height: 6),
                  ...blocked.map((b) => Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.local_shipping, size: 14, color: Colors.red[400]),
                      const SizedBox(width: 6),
                      Expanded(child: Text('${b['immatriculation']} — ${b['typeManquant']}: ${b['statut'] == 'MANQUANT' ? 'Document manquant' : 'Document expire'}', style: TextStyle(fontSize: 10, color: Colors.red[700]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  )),
                ]),
              ),

            // Compliance per vehicle
            Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.percent, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 6),
                  const Text('Conformite par vehicule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
                const SizedBox(height: 8),
                ..._conformiteVehicules.take(10).map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(width: 80, child: Text('${v['immatriculation']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (v['conformite'] as int) / 100,
                          minHeight: 10,
                          backgroundColor: Colors.grey[200],
                          color: v['conformite'] == 100 ? Colors.green : v['conformite'] >= 50 ? Colors.orange : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(width: 32, child: FittedBox(fit: BoxFit.scaleDown, child: Text('${v['conformite']}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: v['conformite'] == 100 ? Colors.green : v['conformite'] >= 50 ? Colors.orange : Colors.red)))),
                    const SizedBox(width: 4),
                    SizedBox(width: 48, child: Text('${v['valides']}/${v['total']}', style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                )),
              ]),
            ),

            // === DOCUMENTS LIST ===
            // Filters
            Container(
              width: double.infinity, margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher par immat, N document, type...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _filterDropdown('Type', _filterType, [{'': 'Tous'}, ..._docTypes.map((d) => {d['value'] as String: d['label'] as String})], (v) => setState(() => _filterType = v))),
                  const SizedBox(width: 6),
                  Expanded(child: _filterDropdown('Statut', _filterStatus, [
                    {'': 'Tous'}, {'VALIDE': 'Valide'}, {'EXPIRE_BIENTOT': 'Expire bientot'},
                    {'EXPIRE': 'Expire'}, {'MANQUANT': 'Manquant'},
                  ], (v) => setState(() => _filterStatus = v))),
                  const SizedBox(width: 6),
                  Expanded(child: _filterDropdown('Vehicule', _filterVehicle, [
                    {'': 'Tous'},
                    ..._vehicules.map((v) => {v['immatriculation'] as String? ?? '': v['immatriculation'] as String? ?? ''}),
                  ], (v) => setState(() => _filterVehicle = v))),
                ]),
              ]),
            ),

            // Document cards
            if (filtered.isEmpty)
              Container(
                width: double.infinity, padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: const Center(child: Text('Aucun document trouve', style: TextStyle(color: Colors.grey))),
              )
            else
              ...filtered.map((doc) => _buildDocCard(doc)),

            // Footer
            const SizedBox(height: 8),
            Text('${filtered.length} documents sur ${_documents.length} total',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 40),

            // === NOTIFICATIONS ===
            if (notifyDocs.isNotEmpty)
              Container(
                width: double.infinity, margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.notifications_active, size: 16, color: Colors.orange),
                    const SizedBox(width: 6),
                    Text('Alertes expiration (${notifyDocs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                  const SizedBox(height: 8),
                  // Expired section
                  if (notifyDocs.where((n) => (n['joursRestants'] as int) < 0).isNotEmpty) ...[
                    const Text('Documents expires — Action recréer:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    ...notifyDocs.where((n) => (n['joursRestants'] as int) < 0).map((n) => _buildNotifItem(n)),
                    const SizedBox(height: 6),
                  ],
                  // Upcoming
                  ...notifyDocs.where((n) => (n['joursRestants'] as int) >= 0).map((n) => _buildNotifItem(n)),
                ]),
              ),
          ]),
        ),
      ),
      // Form modal
      if (_showForm) _buildFormModal(),
      // Detail modal
      if (_showDetail != null) _buildDetailModal(),
    ]);

    return widget.showAppBar
        ? Scaffold(
            appBar: AppBar(title: const Text('Gestion Documents Vehicules'), actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                onPressed: () { _resetForm(); setState(() { _editDoc = null; _showForm = true; }); },
              ),
            ]),
            body: bodyContent,
          )
        : bodyContent;
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: TextStyle(fontSize: 7, color: color, fontWeight: FontWeight.w500), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  Widget _filterDropdown(String label, String value, List<Map<String, String>> options, ValueChanged<String> onChanged) {
    final flat = <String, String>{};
    for (final m in options) { flat.addAll(m); }
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: const TextStyle(fontSize: 10), floatingLabelBehavior: FloatingLabelBehavior.never),
      items: flat.entries.map((e) => DropdownMenuItem(value: e.key, child: FittedBox(fit: BoxFit.scaleDown, child: Text(e.value, style: const TextStyle(fontSize: 11))))).toList(),
      onChanged: (v) => onChanged(v ?? ''),
    );
  }

  Widget _buildDocCard(Map<String, dynamic> doc) {
    final info = _statusInfo(doc['dateExpiration'] as String?, manquant: doc['statut'] == 'MANQUANT');
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: InkWell(
        onTap: () => setState(() => _showDetail = doc),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            Icon(_typeIcon(doc['typeDocument'] as String? ?? ''), size: 20, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    Text(doc['vehiculeImmatriculation'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
                    const SizedBox(width: 6),
                    Text(_typeLabel(doc['typeDocument'] as String? ?? ''), style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    const SizedBox(width: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: info.bg, borderRadius: BorderRadius.circular(6)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(info.icon, size: 10, color: info.color),
                          const SizedBox(width: 2),
                          Text(info.label.length > 12 ? '${info.label.substring(0, 10)}..' : info.label, style: TextStyle(fontSize: 7, color: info.color, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 2),
                Text('N ${doc['numeroDocument'] ?? '-'} — Exp: ${_fmtDate(doc['dateExpiration'])}', style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              color: Colors.orange,
              tooltip: 'Modifier',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: Colors.orange.withValues(alpha: 0.12)),
              onPressed: () => _openEdit(doc),
            ),
            IconButton(
              icon: const Icon(Icons.archive, size: 18),
              color: Colors.red,
              tooltip: 'Archiver',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.12)),
              onPressed: () => _archiveDoc(doc),
            ),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ]),
        ),
      ),
    );
  }

  Widget _buildNotifItem(Map<String, dynamic> n) {
    final doc = n['doc'] as Map<String, dynamic>;
    final jours = n['joursRestants'] as int;
    final color = jours < 0 ? Colors.red : jours <= 7 ? Colors.orange : Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(_typeIcon(doc['typeDocument'] as String? ?? ''), size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_typeLabel(doc['typeDocument'] as String? ?? '')} — ${doc['vehiculeImmatriculation'] ?? ''}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(jours < 0 ? 'Expire depuis ${_fmtDate(doc['dateExpiration'])}' : 'Expire le ${_fmtDate(doc['dateExpiration'])}',
              style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        FittedBox(fit: BoxFit.scaleDown, child: Text(jours < 0 ? 'Expire' : 'J-$jours', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color))),
      ]),
    );
  }

  // ─── FORM MODAL ───
  Widget _buildFormModal() {
    return Stack(children: [
      GestureDetector(onTap: _resetForm, child: Container(color: Colors.black54)),
      Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_editDoc != null ? 'Modifier le document' : 'Nouveau document',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                IconButton(icon: const Icon(Icons.close), onPressed: _resetForm),
              ]),
              const SizedBox(height: 12),
              // Vehicle select
              DropdownButtonFormField<int>(
                initialValue: _formData['vehiculeId'] as int,
                isDense: true,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Vehicule *',
                  labelStyle: const TextStyle(fontSize: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('Selectionner un vehicule', style: TextStyle(fontSize: 12))),
                  ..._vehicules.map((v) => DropdownMenuItem(
                    value: v['id'] as int? ?? 0,
                    child: Text('${v['immatriculation'] ?? ''} — ${v['marque'] ?? ''} ${v['modele'] ?? ''}', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) {
                  final veh = v != null ? _vehicules.cast<Map<String, dynamic>?>().firstWhere((x) => x?['id'] == v, orElse: () => null) : null;
                  setState(() { _formData['vehiculeId'] = v ?? 0; _formData['vehiculeImmatriculation'] = veh?['immatriculation'] ?? ''; });
                },
              ),
              const SizedBox(height: 10),
              // Type document
              DropdownButtonFormField<String>(
                initialValue: _formData['typeDocument'] as String,
                isDense: true,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Type de document *',
                  labelStyle: const TextStyle(fontSize: 11),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
                items: _docTypes.map((dt) => DropdownMenuItem(
                  value: dt['value'] as String,
                  child: Text('${dt['label']}${dt['obligatoire'] == true ? ' (Obligatoire)' : ''}', style: const TextStyle(fontSize: 12)),
                )).toList(),
                onChanged: (v) {
                  final dt = _docTypes.firstWhere((d) => d['value'] == v, orElse: () => {'mois': 12});
                  final mois = dt['mois'] as int;
                  setState(() {
                    _formData['typeDocument'] = v ?? 'ASSURANCE';
                    _formData['dureeAnnees'] = mois ~/ 12;
                    _formData['dureeMois'] = mois % 12;
                    if ((_formData['dateEmission'] as String).isNotEmpty) {
                      _expiryDate = _calcExpiration(_formData['dateEmission'] as String, mois);
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              // Numero
              TextField(
                decoration: InputDecoration(labelText: 'Numero du document *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
                controller: TextEditingController(text: _formData['numeroDocument'] as String? ?? ''),
                onChanged: (v) => _formData['numeroDocument'] = v,
              ),
              const SizedBox(height: 10),
              // Date emission
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(2030));
                  if (date != null) {
                    final d = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                    final totalMois = (_formData['dureeAnnees'] as int) * 12 + (_formData['dureeMois'] as int);
                    setState(() { _formData['dateEmission'] = d; _expiryDate = _calcExpiration(d, totalMois); });
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(labelText: "Date d'emission *", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true),
                  child: Text(_formData['dateEmission'] as String? ?? '', style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(height: 10),
              // Duree
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  SizedBox(width: 90, child: TextField(
                    decoration: const InputDecoration(labelText: 'Annees', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: '${_formData['dureeAnnees']}'),
                    onChanged: (v) {
                      final a = int.tryParse(v) ?? 0;
                      final totalMois = a * 12 + (_formData['dureeMois'] as int);
                      setState(() { _formData['dureeAnnees'] = a; _expiryDate = _calcExpiration(_formData['dateEmission'] as String, totalMois); });
                    },
                  )),
                  const SizedBox(width: 6),
                  SizedBox(width: 90, child: TextField(
                    decoration: const InputDecoration(labelText: 'Mois', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: '${_formData['dureeMois']}'),
                    onChanged: (v) {
                      final m = int.tryParse(v) ?? 0;
                      final totalMois = (_formData['dureeAnnees'] as int) * 12 + m;
                      setState(() { _formData['dureeMois'] = m; _expiryDate = _calcExpiration(_formData['dateEmission'] as String, totalMois); });
                    },
                  )),
                  const SizedBox(width: 6),
                  SizedBox(width: 90, child: TextField(
                    decoration: const InputDecoration(labelText: 'Jours', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(text: '${_formData['dureeJours']}'),
                    onChanged: (v) => _formData['dureeJours'] = int.tryParse(v) ?? 0,
                  )),
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Text('Expiration: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Flexible(child: Text(_expiryDate.isNotEmpty ? _expiryDate : '(calculee apres date emission)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 10),
              // Notes
              TextField(
                decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder(), isDense: true),
                maxLines: 2,
                controller: TextEditingController(text: _formData['notes'] as String? ?? ''),
                onChanged: (v) => _formData['notes'] = v,
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _resetForm, child: const Text('Annuler'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  child: Text(_editDoc != null ? 'Mettre a jour' : 'Enregistrer'),
                )),
              ]),
            ]),
          ),
        ),
      ),
    ]);
  }

  Future<void> _handleSubmit() async {
    if ((_formData['vehiculeId'] as int) == 0) { _showToast('Selectionnez un vehicule'); return; }
    if ((_formData['numeroDocument'] as String).trim().isEmpty) { _showToast('Entrez le numero du document'); return; }
    if ((_formData['dateEmission'] as String).isEmpty) { _showToast("Selectionnez la date d'emission"); return; }

    final totalMois = (_formData['dureeAnnees'] as int) * 12 + (_formData['dureeMois'] as int);
    final payload = {
      'vehiculeId': _formData['vehiculeId'],
      'vehiculeImmatriculation': _formData['vehiculeImmatriculation'],
      'typeDocument': _formData['typeDocument'],
      'numeroDocument': _formData['numeroDocument'],
      'dateEmission': _formData['dateEmission'],
      'dureeValiditeMois': totalMois,
      'dateExpiration': _expiryDate,
      'notes': _formData['notes'],
      'importePar': 'RS',
    };

    try {
      final client = http.Client();
      http.Response res;
      if (_editDoc != null && _editDoc!['id'] != null) {
        res = await client.put(Uri.parse('${ApiConfig.baseUrl}/documents-vehicule/${_editDoc!['id']}'), headers: ApiConfig.headers, body: jsonEncode(payload)).timeout(ApiConfig.timeout);
      } else {
        res = await client.post(Uri.parse('${ApiConfig.baseUrl}/documents-vehicule'), headers: ApiConfig.headers, body: jsonEncode(payload)).timeout(ApiConfig.timeout);
      }
      client.close();
      if (res.statusCode == 200 || res.statusCode == 201) {
        if (!mounted) return;
        _showToast(_editDoc != null ? 'Document mis a jour' : 'Document ajoute');
        _resetForm();
        _load();
        return;
      }
    } catch (_) {}
    // Fallback local
    try {
      final localData = {...payload}
        ..remove('vehiculeImmatriculation')
        ..['immatriculation'] = _formData['vehiculeImmatriculation']
        ..['responsableNom'] = 'RS';
      if (_editDoc != null && _editDoc!['id'] != null) {
        await _docDao.update(_editDoc!['id'] as int, localData);
      } else {
        await _docDao.insert(localData);
      }
      if (!mounted) return;
      _showToast(_editDoc != null ? 'Document mis a jour (local)' : 'Document ajoute (local)');
      _resetForm();
      _load();
    } catch (e) {
      if (!mounted) return;
      _showToast('Erreur: $e');
    }
  }

  void _archiveDoc(Map<String, dynamic> doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver le document ?'),
        content: Text('Voulez-vous archiver ${_typeLabel(doc['typeDocument'] as String? ?? '')} — ${doc['vehiculeImmatriculation'] ?? ''} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Archiver')),
        ],
      ),
    );
    if (confirm != true) return;
    final id = doc['id'] as int?;
    if (id == null) { _showToast('ID document manquant'); return; }
    try {
      final client = http.Client();
      final res = await client.put(Uri.parse('${ApiConfig.baseUrl}/documents-vehicule/$id/archive'), headers: ApiConfig.headers).timeout(ApiConfig.timeout);
      client.close();
      if (!mounted) return;
      if (res.statusCode == 200) { _showToast('Document archive'); setState(() => _showDetail = null); _load(); return; }
    } catch (_) {}
    // Fallback local
    try { await _docDao.archive(id); if (!mounted) return; _showToast('Document archive (local)'); setState(() => _showDetail = null); _load(); } catch (e) { if (!mounted) return; _showToast('Erreur: $e'); }
  }

  // ─── DETAIL MODAL ───
  Widget _buildDetailModal() {
    final d = _showDetail!;
    final info = _statusInfo(d['dateExpiration'] as String?, manquant: d['statut'] == 'MANQUANT');
    final pieces = (d['piecesJointes'] as List?) ?? [];
    final historique = (d['historique'] as List?) ?? [];

    return Stack(children: [
      GestureDetector(onTap: () => setState(() => _showDetail = null), child: Container(color: Colors.black54)),
      Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(
                  child: Row(children: [
                    Icon(_typeIcon(d['typeDocument'] as String? ?? ''), size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Flexible(child: Text(_typeLabel(d['typeDocument'] as String? ?? ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    color: Colors.orange,
                    tooltip: 'Modifier',
                    style: IconButton.styleFrom(backgroundColor: Colors.orange.withValues(alpha: 0.12)),
                    onPressed: () { setState(() => _showDetail = null); _openEdit(d); },
                  ),
                  IconButton(
                    icon: const Icon(Icons.archive, size: 18),
                    color: Colors.red,
                    tooltip: 'Archiver',
                    style: IconButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.12)),
                    onPressed: () => _archiveDoc(d),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _showDetail = null)),
                ]),
              ]),
              const SizedBox(height: 12),
              _detailField('Vehicule', d['vehiculeImmatriculation'] as String? ?? '-'),
              _detailField('Statut', info.label, info.color),
              _detailField('N Document', d['numeroDocument'] as String? ?? '-'),
              _detailField('Jours restants', d['statut'] != 'MANQUANT' ? '${d['joursRestants']} jours' : '-', d['joursRestants'] <= 0 ? Colors.red : d['joursRestants'] <= 30 ? Colors.orange : Colors.green),
              _detailField("Date d'emission", _fmtDate(d['dateEmission'])),
              _detailField("Date d'expiration", _fmtDate(d['dateExpiration']), d['statut'] == 'EXPIRE' ? Colors.red : null),
              _detailField('Responsable', d['responsableNom'] as String? ?? '-'),
              _detailField('Cree le', _fmtDateTime(d['createdAt'])),
              _detailField('Derniere modif.', _fmtDateTime(d['updatedAt'])),
              // Notes
              if ((d['notes'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Notes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(d['notes'] as String, style: const TextStyle(fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ],
              // Pieces jointes
              if (pieces.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Pieces jointes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 4),
                ...pieces.map((pj) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.attach_file, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(child: Text(pj['name'] ?? pj['url'] ?? '-', style: TextStyle(fontSize: 11, color: Colors.blue[700]), overflow: TextOverflow.ellipsis)),
                    Icon(Icons.open_in_new, size: 12, color: Colors.grey[400]),
                  ]),
                )),
              ],
              // Historique
              if (historique.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.history, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  const Text('Historique', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                ]),
                const SizedBox(height: 4),
                ...historique.take(20).map((h) => Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(6)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 4, right: 6), decoration: BoxDecoration(color: Colors.blue[400], shape: BoxShape.circle)),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(h['action'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (h['userName'] != null) Text('par ${h['userName']} ${_fmtDateTime(h['timestamp'])}', style: TextStyle(fontSize: 9, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (h['oldValue'] != null && h['newValue'] != null)
                          Text('${h['oldValue']} -> ${h['newValue']}', style: TextStyle(fontSize: 9, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                )),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Modifier', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () { setState(() => _showDetail = null); _openEdit(d); },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.archive, size: 18),
                  label: const Text('Archiver', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => _archiveDoc(d),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(() => _showDetail = null),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('Fermer'),
                ),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _detailField(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text('$label:', style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: valueColor), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}
