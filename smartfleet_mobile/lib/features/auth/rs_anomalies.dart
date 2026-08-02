import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/anomalie_service.dart';
import '../../services/vehicle_service.dart';

const _statutLabels = {
  'DETECTEE': 'Détectée',
  'EN_REPARATION': 'En réparation',
  'REPAREE': 'Réparée',
  'NON_REPAREE': 'Non réparable',
  'VALIDEE': 'Validée',
  'ANNULEE': 'Annulée',
};
const _statutColors = {
  'DETECTEE': AppTheme.danger,
  'EN_REPARATION': AppTheme.warning,
  'REPAREE': Colors.blue,
  'NON_REPAREE': Colors.orange,
  'VALIDEE': AppTheme.success,
  'ANNULEE': Colors.grey,
};
const _categories = ['MECANIQUE', 'PNEUS', 'CARROSSERIE', 'ECLAIRAGE', 'CABINE', 'FREINS', 'SECURITE'];

String _fmtDate(dynamic d) {
  if (d == null) return '-';
  if (d is String) {
    if (d.length >= 16) return d.substring(0, 16).replaceAll('T', ' ');
    if (d.length >= 10) return d.substring(0, 10);
    return d;
  }
  return '$d';
}


class RsAnomalies extends StatefulWidget {
  const RsAnomalies({super.key});

  @override
  State<RsAnomalies> createState() => _RsAnomaliesState();
}

class _RsAnomaliesState extends State<RsAnomalies> {
  final AnomalieService _svc = AnomalieService();
  final VehicleService _vSvc = VehicleService();
  List<Map<String, dynamic>> _anomalies = [];
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;
  String _search = '';
  String _statutFilter = 'ALL';
  String _categorieFilter = 'ALL';
  String _dateFrom = '';
  String _dateTo = '';
  int? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_svc.getAll(), _vSvc.getAll()]);
      if (mounted) {
        setState(() {
          _anomalies = results[0] as List<Map<String, dynamic>>;
          _vehicles = results[1] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _anomalies.where((a) {
      if (_statutFilter != 'ALL' && a['statut'] != _statutFilter) return false;
      if (_categorieFilter != 'ALL' && a['categorie'] != _categorieFilter) return false;
      if (_dateFrom.isNotEmpty) {
        final dc = a['dateDetection'] as String? ?? '';
        if (dc.compareTo(_dateFrom) < 0) return false;
      }
      if (_dateTo.isNotEmpty) {
        final dc = a['dateDetection'] as String? ?? '';
        if (dc.compareTo(_dateTo) > 0) return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final desc = (a['description'] as String? ?? '').toLowerCase();
        final immat = (a['vehiculeImmatriculation'] as String? ?? '').toLowerCase();
        final chName = (a['chauffeurNom'] as String? ?? '').toLowerCase();
        final elem = (a['element'] as String? ?? '').toLowerCase();
        final code = (a['anomalieCode'] as String? ?? '').toLowerCase();
        if (!desc.contains(q) && !immat.contains(q) && !chName.contains(q) && !elem.contains(q) && !code.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _blocked {
    return _vehicles.where((v) => v['statut'] == 'BLOQUE').toList();
  }

  Future<void> _takeCharge(int id) async {
    await _svc.takeCharge(id, 'RS');
    _load();
  }

  Future<void> _resolve(int id) async {
    await _svc.resolve(id, notes: 'Réparation effectuée');
    _load();
  }

  Future<void> _annuler(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer'),
        content: const Text('Annuler cette anomalie ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oui')),
        ],
      ),
    );
    if (confirm == true) {
      await _svc.delete(id);
      _load();
    }
  }

  Future<void> _reject(int id) async {
    final motif = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Motif de rejet'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Raison...'), maxLines: 2),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Rejeter')),
          ],
        );
      },
    );
    if (motif != null) {
      await _svc.reject(id, raison: motif);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final blocked = _blocked;

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(children: [
          // Blocked vehicles section
          if (blocked.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.block, size: 16, color: AppTheme.danger),
                  const SizedBox(width: 6),
                  Text('Véhicules Bloqués (${blocked.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
                const SizedBox(height: 8),
                ...blocked.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.local_shipping, size: 14, color: AppTheme.danger),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('${v['truckNumber'] ?? v['immatriculation']} ${v['immatriculation']} – ${v['chauffeurNom'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TextButton(
                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        onPressed: () async {
                          await _vSvc.update(v['id'] as int, {'statut': 'DISPONIBLE'});
                          _load();
                        },
                        child: const Text('Débloquer', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                      ),
                    ),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          // Search
          TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher par immat, chauffeur, élément...',
              prefixIcon: const Icon(Icons.search, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 8),

          // Status filter
          SizedBox(
            height: 36,
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _chip('Tous statuts', 'ALL', _statutFilter == 'ALL' ? AppTheme.primary : Colors.grey),
              _chip('Détectée', 'DETECTEE', _statutColors['DETECTEE']!),
              _chip('En réparation', 'EN_REPARATION', _statutColors['EN_REPARATION']!),
              _chip('Réparée', 'REPAREE', _statutColors['REPAREE']!),
              _chip('Non réparable', 'NON_REPAREE', _statutColors['NON_REPAREE']!),
              _chip('Validée', 'VALIDEE', _statutColors['VALIDEE']!),
              _chip('Annulée', 'ANNULEE', _statutColors['ANNULEE']!),
            ])),
          ),
          const SizedBox(height: 8),

          // Category filter + date range
          SizedBox(
            height: 36,
            child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _chipCat('Toutes catégories', 'ALL'),
              ..._categories.map((c) => _chipCat(c, c)),
            ])),
          ),
          const SizedBox(height: 8),

          // Date range
          Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Date début',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  isDense: true,
                  suffixIcon: const Icon(Icons.calendar_today, size: 14),
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (v) => setState(() => _dateFrom = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Date fin',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  isDense: true,
                  suffixIcon: const Icon(Icons.calendar_today, size: 14),
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (v) => setState(() => _dateTo = v),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _load,
              style: IconButton.styleFrom(backgroundColor: Colors.grey[100], padding: const EdgeInsets.all(8)),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ]),
          const SizedBox(height: 8),

          // Anomaly list
          if (_filtered.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucune anomalie trouvée')))
          else
            ..._filtered.map((a) => _buildAnomalieCard(a)),
        ]),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    final active = _statutFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : Colors.grey[700])),
        selected: active,
        onSelected: (_) => setState(() => _statutFilter = active ? 'ALL' : value),
        selectedColor: color,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _chipCat(String label, String value) {
    final active = _categorieFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : Colors.grey[700])),
        selected: active,
        onSelected: (_) => setState(() => _categorieFilter = active ? 'ALL' : value),
        selectedColor: AppTheme.primary,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildAnomalieCard(Map<String, dynamic> a) {
    final id = a['id'] as int;
    final statut = a['statut'] as String? ?? 'DETECTEE';
    final statutLabel = _statutLabels[statut] ?? statut;
    final statutColor = _statutColors[statut] ?? Colors.grey;
    final expand = _expandedId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expandedId = expand ? null : id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              // Badge + code + element + description
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: statutColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Text(statutLabel, style: TextStyle(fontSize: 10, color: statutColor, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(child: Text(a['anomalieCode'] as String? ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${a['element'] ?? ''} – ${a['description'] ?? ''}',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Flexible(child: Text(_fmtDate(a['dateDetection']), style: TextStyle(fontSize: 10, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              Icon(expand ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey[400]),
            ]),
          ),
        ),
        if (expand) ...[
          Divider(height: 1, color: Colors.grey[200]),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Detail grid
              Wrap(runSpacing: 6, spacing: 16, children: [
                _detailRow('Camion', a['vehiculeImmatriculation'] as String? ?? '-'),
                _detailRow('Chauffeur', a['chauffeurNom'] as String? ?? '-'),
                _detailRow('Catégorie', a['categorie'] as String? ?? '-'),
                _detailRow('Criticité', a['criticite'] as String? ?? '-'),
                _detailRow('Source', a['source'] as String? ?? '-'),
                _detailRow('Détectée', _fmtDate(a['dateDetection'])),
                _detailRow('Assigné', a['assignedTo'] as String? ?? 'Non assigné'),
                if (a['datePriseEnCharge'] != null) _detailRow('Pris en charge', _fmtDate(a['datePriseEnCharge'])),
                if (a['reparePar'] != null) _detailRow('Réparé par', a['reparePar'] as String),
                if (a['validePar'] != null) _detailRow('Validé par', a['validePar'] as String),
              ]),
              if (a['observation'] != null && (a['observation'] as String).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Observation: ${a['observation']}', style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              if (a['resolutionNotes'] != null && (a['resolutionNotes'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Résolution: ${a['resolutionNotes']}', style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              // Warning badge
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  '⚠ SANS vérification budget – validation directe RS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red),
                ),
              ),
              const SizedBox(height: 8),
              // Action buttons
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (statut == 'DETECTEE') ...[
                  _actionBtn('Prendre en charge', Icons.build, AppTheme.warning, () => _takeCharge(id)),
                  _actionBtn('Annuler', Icons.cancel, Colors.grey, () => _annuler(id)),
                ],
                if (statut == 'EN_REPARATION') ...[
                  _actionBtn('Réparé', Icons.check_circle, Colors.blue, () => _resolve(id)),
                  _actionBtn('Non réparable', Icons.cancel, Colors.orange, () => _reject(id)),
                ],
                if (statut == 'REPAREE')
                  _actionBtn('Valider (RS)', Icons.verified, AppTheme.success, () async {
                    await _svc.validate(id);
                    _load();
                  }),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      Flexible(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 14),
      label: Text(label, style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500)),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
