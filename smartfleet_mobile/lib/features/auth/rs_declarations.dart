import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../config/theme.dart';
import '../../config/api_config.dart';

const _declStatutLabels = {
  'EN_ATTENTE': 'En attente',
  'EN_COURS': 'En cours',
  'EN_VALIDATION': 'En validation',
  'CLOTURE': 'Cloture',
  'RETOURNEE': 'Retournee',
  'REFUSE': 'Refuse',
};
const _declStatutColors = {
  'EN_ATTENTE': Color(0xFFF59E0B),
  'EN_COURS': Color(0xFF3B82F6),
  'EN_VALIDATION': Color(0xFF8B5CF6),
  'CLOTURE': Color(0xFF10B981),
  'RETOURNEE': Color(0xFFEF4444),
  'REFUSE': Color(0xFFDC2626),
};

DateTime? _toDate(dynamic d) {
  if (d == null) return null;
  if (d is String) return DateTime.tryParse(d);
  if (d is List && d.length >= 3) {
    try { return DateTime(d[0], d[1], d[2]); } catch (_) { return null; }
  }
  return null;
}

String _fmtDateTime(dynamic d) {
  if (d == null) return '-';
  if (d is String) {
    if (d.length >= 16) return d.substring(0, 16).replaceAll('T', ' ');
    if (d.length >= 10) return d.substring(0, 10);
    return d;
  }
  return '$d';
}

class RsDeclarations extends StatefulWidget {
  final bool showAppBar;
  const RsDeclarations({super.key, this.showAppBar = true});

  @override
  State<RsDeclarations> createState() => _RsDeclarationsState();
}

class _RsDeclarationsState extends State<RsDeclarations> {
  List<Map<String, dynamic>> _declarations = [];
  bool _loading = true;
  String _search = '';
  String _statutFilter = '';
  String _typePanneFilter = '';
  String _dateDebut = '';
  String _dateFin = '';
  bool _autoRefresh = false;
  Timer? _autoRefreshTimer;
  int? _expandedDeclId;
  Map<String, dynamic>? _selectedDeclaration;
  bool _showDetailModal = false;
  bool _showCloseModal = false;
  bool _showReturnModal = false;
  String _returnMotif = '';
  String? _toastMsg;
  Color? _toastColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoRefresh(bool on) {
    setState(() => _autoRefresh = on);
    _autoRefreshTimer?.cancel();
    if (on) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load());
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // In real app, fetch from API
      // For now, try to use DeclarationProvider or direct API call
      _loadFromProvider();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadFromProvider() {
    _fetchFromApi();
  }

  Future<void> _fetchFromApi() async {
    try {
      final client = http.Client();
      final url = Uri.parse('${ApiConfig.baseUrl}/declarations');
      final res = await client.get(url).timeout(ApiConfig.timeout);
      client.close();
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        final list = (decoded is List ? decoded : []).cast<Map<String, dynamic>>();
        if (mounted) setState(() { _declarations = list; _loading = false; });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void setDeclarations(List<Map<String, dynamic>> decls) {
    setState(() { _declarations = decls; _loading = false; });
  }

  List<Map<String, dynamic>> get _filtered {
    return _declarations.where((d) {
      if (_statutFilter.isNotEmpty && d['statut'] != _statutFilter) return false;
      if (_typePanneFilter.isNotEmpty && d['typePanne'] != _typePanneFilter && d['categorie'] != _typePanneFilter) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final immat = (d['vehiculeImmatriculation'] as String? ?? '').toLowerCase();
        final nd = (d['numeroDeclaration'] as String? ?? '').toLowerCase();
        final nm = (d['numeroDemande'] as String? ?? '').toLowerCase();
        final ch = (d['chauffeurNom'] as String? ?? '').toLowerCase();
        if (!immat.contains(q) && !nd.contains(q) && !nm.contains(q) && !ch.contains(q)) return false;
      }
      if (_dateDebut.isNotEmpty) {
        final dd = _toDate(d['dateDeclaration']);
        final ddBeg = DateTime.tryParse(_dateDebut);
        if (dd == null || ddBeg == null || dd.isBefore(ddBeg)) return false;
      }
      if (_dateFin.isNotEmpty) {
        final dd = _toDate(d['dateDeclaration']);
        final ddEnd = DateTime.tryParse(_dateFin);
        if (dd == null || ddEnd == null || dd.isAfter(ddEnd.add(const Duration(days: 1)))) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _takeCharge(int id) async {
    try {
      await _apiPut('$baseUrl/declarations/${id}/takeCharge', {});
      _showToast('Prise en charge effectuée', AppTheme.success);
      _load();
    } catch (_) {
      _showToast('Erreur', AppTheme.danger);
    }
  }

  Future<void> _closeDeclaration(int id) async {
    try {
      await _apiPut('$baseUrl/declarations/${id}/close', {});
      _showToast('Déclaration clôturée', AppTheme.success);
      setState(() { _showCloseModal = false; _selectedDeclaration = null; });
      _load();
    } catch (_) {
      _showToast('Erreur', AppTheme.danger);
    }
  }

  Future<void> _returnDeclaration(int id, String motif) async {
    try {
      await _apiPut('$baseUrl/declarations/${id}/return', {'motif': motif});
      _showToast('Déclaration retournée', AppTheme.warning);
      setState(() { _showReturnModal = false; _selectedDeclaration = null; _returnMotif = ''; });
      _load();
    } catch (_) {
      _showToast('Erreur', AppTheme.danger);
    }
  }

  Future<http.Response> _apiPut(String url, Map<String, dynamic> body) async {
    final client = http.Client();
    try {
      final res = await client
          .put(Uri.parse(url), headers: ApiConfig.headers, body: jsonEncode(body))
          .timeout(ApiConfig.timeout);
      return res;
    } finally {
      client.close();
    }
  }

  String get baseUrl => ApiConfig.baseUrl;

  void _showToast(String msg, Color color) {
    setState(() { _toastMsg = msg; _toastColor = color; });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() { _toastMsg = null; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final bodyContent = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                if (_toastMsg != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _toastColor!.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: _toastColor!.withValues(alpha: 0.3))),
                    child: Row(children: [
                      Icon(Icons.info, color: _toastColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_toastMsg!, style: TextStyle(color: _toastColor, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),

                // Filtres
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher (immat, N°, chauffeur)',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _filterDropdown('Statut', _statutFilter, {
                    '': 'Tous',
                    'EN_ATTENTE': 'En attente',
                    'EN_COURS': 'En cours',
                    'EN_VALIDATION': 'En validation',
                    'CLOTURE': 'Cloture',
                    'RETOURNEE': 'Retournee',
                    'REFUSE': 'Refuse',
                  }, (v) => setState(() => _statutFilter = v))),
                  const SizedBox(width: 8),
                  Expanded(child: _filterDropdown('Type panne', _typePanneFilter, {
                    '': 'Tous',
                    'MECANIQUE': 'Mecanique',
                    'ELECTRIQUE': 'Electrique',
                    'CAISSE': 'Caisse',
                    'CABINE': 'Cabine',
                    'SECURITE': 'Securite',
                    'AUTRES': 'Autres',
                  }, (v) => setState(() => _typePanneFilter = v))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Date debut',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true,
                      suffixIcon: _dateDebut.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _dateDebut = '')) : null,
                    ),
                    readOnly: true,
                    controller: TextEditingController(text: _dateDebut),
                    onTap: () async {
                      final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (date != null) setState(() => _dateDebut = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
                    },
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Date fin',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), isDense: true,
                      suffixIcon: _dateFin.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () => setState(() => _dateFin = '')) : null,
                    ),
                    readOnly: true,
                    controller: TextEditingController(text: _dateFin),
                    onTap: () async {
                      final date = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2030));
                      if (date != null) setState(() => _dateFin = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
                    },
                  )),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reinitialiser', style: TextStyle(fontSize: 12)),
                      onPressed: () => setState(() { _search = ''; _statutFilter = ''; _typePanneFilter = ''; _dateDebut = ''; _dateFin = ''; }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: Icon(_autoRefresh ? Icons.timer_off : Icons.timer, size: 16),
                    label: Text(_autoRefresh ? 'Auto 30s' : 'Auto', style: TextStyle(fontSize: 10, color: _autoRefresh ? AppTheme.primary : Colors.grey)),
                    onPressed: () => _toggleAutoRefresh(!_autoRefresh),
                    style: OutlinedButton.styleFrom(foregroundColor: _autoRefresh ? AppTheme.primary : Colors.grey),
                  ),
                ]),
                const SizedBox(height: 12),

                // Declarations list
                if (_filtered.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucune déclaration')))
                else
                  ..._filtered.map((d) => _buildDeclarationCard(d)),

                // Modals
                if (_showDetailModal && _selectedDeclaration != null) _buildDetailModal(),
                if (_showCloseModal && _selectedDeclaration != null) _buildCloseModal(),
                if (_showReturnModal && _selectedDeclaration != null) _buildReturnModal(),

              ]),
            ),
          );

    return widget.showAppBar ? Scaffold(appBar: AppBar(title: const Text('Déclarations')), body: bodyContent) : bodyContent;
  }

  Widget _filterDropdown(String label, String value, Map<String, String> options, ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        labelStyle: const TextStyle(fontSize: 10), floatingLabelBehavior: FloatingLabelBehavior.never),
      items: options.entries.map((e) => DropdownMenuItem(value: e.key, child: FittedBox(fit: BoxFit.scaleDown, child: Text(e.value, style: const TextStyle(fontSize: 11))))).toList(),
      onChanged: (v) => onChanged(v ?? ''),
    );
  }

  Widget _buildDeclarationCard(Map<String, dynamic> d) {
    final id = d['id'] as int? ?? 0;
    final statut = d['statut'] as String? ?? '';
    final numDecl = d['numeroDeclaration'] as String? ?? d['numeroDemande'] as String? ?? '-';
    final immat = d['vehiculeImmatriculation'] as String? ?? '';
    final chauffeur = d['chauffeurNom'] as String? ?? '-';
    final typePanne = d['typePanneFrancais'] as String? ?? d['typePanne'] as String? ?? '-';
    final criticite = d['criticite'] as String? ?? '-';
    final source = d['source'] as String? ?? '-';
    final expand = _expandedDeclId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expandedDeclId = expand ? null : id),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      FittedBox(fit: BoxFit.scaleDown, child: Text(numDecl, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (_declStatutColors[statut] ?? Colors.grey).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FittedBox(child: Text(_declStatutLabels[statut] ?? statut,
                          style: TextStyle(fontSize: 9, color: _declStatutColors[statut] ?? Colors.grey, fontWeight: FontWeight.w600))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Text(_fmtDateTime(d['dateDeclaration']), style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$immat • $chauffeur • $typePanne', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(children: [
                      Text('Criticité: $criticite', style: TextStyle(fontSize: 11, color: _criticiteColor(criticite))),
                      const SizedBox(width: 8),
                      Text('Source: $source', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ]),
                  ),
                ]),
              ),
              Icon(expand ? Icons.expand_less : Icons.expand_more, color: Colors.grey[400]),
            ]),
          ),
        ),
        if (expand) ...[
          Divider(height: 1, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Details
              Wrap(runSpacing: 6, spacing: 16, children: [
                _declDetail('Coût', d['coutProbleme'] != null ? '${(d['coutProbleme'] as num).toInt()} MAD' : '-'),
                _declDetail('Durée réparation', d['dureeReparation'] != null ? _fmtDuree(d['dureeReparation'] as int) : '-'),
                _declDetail('Actions réalisées', d['actionsRealisees'] as String? ?? '-'),
                _declDetail('Contrat / Bon commande', d['contratBonCommande'] as String? ?? '-'),
                _declDetail('Date début intervention', _fmtDateTime(d['dateDebutIntervention'])),
                _declDetail('Date réparation', _fmtDateTime(d['dateReparation'])),
                _declDetail('Pièces nécessaires', d['piecesNecessaires'] as String? ?? '-'),
                _declDetail('Qualification', d['qualification'] as String? ?? '-'),
              ]),
              // Action buttons
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _compactBtn('Détails', Icons.info, AppTheme.primary, () {
                  setState(() { _selectedDeclaration = d; _showDetailModal = true; });
                }),
                if (statut == 'EN_ATTENTE')
                  _compactBtn('Prendre en charge', Icons.handshake, AppTheme.warning, () => _takeCharge(id), filled: true),
                if (statut == 'EN_VALIDATION') ...[
                  _compactBtn('Clôturer', Icons.check, AppTheme.success, () => setState(() { _selectedDeclaration = d; _showCloseModal = true; }), filled: true),
                  _compactBtn('Retourner', Icons.undo, AppTheme.danger, () => setState(() { _selectedDeclaration = d; _showReturnModal = true; _returnMotif = ''; })),

                ],
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _compactBtn(String label, IconData icon, Color color, VoidCallback onTap, {bool filled = false}) {
    final btn = filled
        ? ElevatedButton.icon(
            icon: Icon(icon, size: 14),
            label: Text(label, style: const TextStyle(fontSize: 10)),
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          )
        : OutlinedButton.icon(
            icon: Icon(icon, size: 14),
            label: Text(label, style: TextStyle(fontSize: 10, color: color)),
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: color,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              side: BorderSide(color: color.withValues(alpha: 0.4)),
            ),
          );
    return btn;
  }

  Widget _declDetail(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }

  String _fmtDuree(int minutes) {
    final t = (minutes / 60).floor();
    final h = (t / 60).floor();
    final m = t % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  Color _criticiteColor(String c) {
    switch (c) {
      case 'BLOQUANT': case 'SECURITE': return AppTheme.danger;
      case 'URGENT': return AppTheme.warning;
      case 'MOYEN': return Colors.orange;
      default: return AppTheme.success;
    }
  }

  // ─── DETAIL MODAL ───
  Widget _buildDetailModal() {
    final d = _selectedDeclaration!;
    final id = d['id'] as int? ?? 0;
    return Stack(children: [
      GestureDetector(onTap: () => setState(() { _showDetailModal = false; _selectedDeclaration = null; }), child: Container(color: Colors.black54)),
      Center(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Détails - ${d['numeroDeclaration'] ?? d['numeroDemande'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _showDetailModal = false; _selectedDeclaration = null; })),
              ]),
              const SizedBox(height: 12),
              // Fields
              _detailField('Chauffeur', d['chauffeurNom'] as String? ?? '-'),
              _detailField('Immatriculation', d['vehiculeImmatriculation'] as String? ?? '-'),
              _detailField('Type panne', d['typePanneFrancais'] as String? ?? d['typePanne'] as String? ?? '-'),
              _detailField('Criticité', d['criticite'] as String? ?? '-'),
              _detailField('Statut', _declStatutLabels[d['statut']] ?? d['statut'] ?? '-'),
              _detailField('Source', d['source'] as String? ?? '-'),
              _detailField('Catégorie', d['categorie'] as String? ?? '-'),
              _detailField('Élément', d['elementVehicule'] as String? ?? '-'),
              _detailField('Coût', d['coutProbleme'] != null ? '${(d['coutProbleme'] as num).toInt()} MAD' : '-'),
              _detailField('Km', d['kilometrage'] != null ? '${d['kilometrage']} km' : '-'),
              // Description
              const SizedBox(height: 8),
              const Text('Description:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
                child: Text(d['descriptionFrancais'] as String? ?? d['description'] as String? ?? '-',
                  style: const TextStyle(fontSize: 12)),
              ),
              // Rapport d'intervention
              if (d['actionsRealisees'] != null || d['piecesNecessaires'] != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Rapport d\'intervention', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    if (d['dateDebutIntervention'] != null) _detailField('Date début intervention', _fmtDateTime(d['dateDebutIntervention'])),
                    if (d['dateReparation'] != null) _detailField('Date réparation', _fmtDateTime(d['dateReparation'])),
                    if (d['dureeReparation'] != null) _detailField('Durée réparation', _fmtDuree(d['dureeReparation'] as int)),
                    if (d['actionsRealisees'] != null) _detailField('Actions réalisées', d['actionsRealisees'] as String),
                    if (d['piecesNecessaires'] != null) _detailField('Pièces nécessaires', d['piecesNecessaires'] as String),
                    if (d['qualification'] != null) _detailField('Qualification', d['qualification'] as String),
                    if (d['contratBonCommande'] != null) _detailField('Contrat / Bon de commande', d['contratBonCommande'] as String),
                  ]),
                ),
              ],
              // Motif refus
              if (d['motifRefus'] != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: Text('Motif de retour/refus: ${d['motifRefus']}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(onPressed: () => setState(() { _showDetailModal = false; _selectedDeclaration = null; }), child: const Text('Fermer')),
              ),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _detailField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text('$label:', style: TextStyle(fontSize: 12, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  // ─── CLOSE MODAL ───
  Widget _buildCloseModal() {
    final d = _selectedDeclaration!;
    return Stack(children: [
      GestureDetector(onTap: () => setState(() { _showCloseModal = false; _selectedDeclaration = null; }), child: Container(color: Colors.black54)),
      Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Clôturer la déclaration ?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('Déclaration ${d['numeroDeclaration'] ?? d['numeroDemande'] ?? ''} — Statut actuel: ${_declStatutLabels[d['statut']] ?? d['statut']}',
              style: const TextStyle(fontSize: 13, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(onPressed: () => setState(() { _showCloseModal = false; _selectedDeclaration = null; }), child: const Text('Annuler')),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _closeDeclaration(d['id'] as int? ?? 0),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, foregroundColor: Colors.white),
                child: const Text('Clôturer'),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }

  // ─── RETURN MODAL ───
  Widget _buildReturnModal() {
    final d = _selectedDeclaration!;
    return Stack(children: [
      GestureDetector(onTap: () => setState(() { _showReturnModal = false; _selectedDeclaration = null; _returnMotif = ''; }), child: Container(color: Colors.black54)),
      Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Retourner la déclaration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Déclaration ${d['numeroDeclaration'] ?? d['numeroDemande'] ?? ''}',
              style: const TextStyle(fontSize: 13, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(labelText: 'Motif du retour', border: OutlineInputBorder()),
              maxLines: 3,
              onChanged: (v) => _returnMotif = v,
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(onPressed: () => setState(() { _showReturnModal = false; _selectedDeclaration = null; _returnMotif = ''; }), child: const Text('Annuler')),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _returnMotif.trim().isEmpty ? null : () => _returnDeclaration(d['id'] as int? ?? 0, _returnMotif.trim()),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
                child: const Text('Retourner'),
              ),
            ]),
          ]),
        ),
      ),
    ]);
  }


}
