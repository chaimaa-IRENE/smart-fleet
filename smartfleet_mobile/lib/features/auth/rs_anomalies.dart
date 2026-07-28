import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/anomalie_service.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/status_badge.dart';

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
  String _statutFilter = '';
  String _categorieFilter = '';
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
      final results = await Future.wait([
        _svc.getAll(),
        _vSvc.getAll(),
      ]);
      if (mounted) {
        setState(() {
          _anomalies = results[0];
          _vehicles = results[1];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _anomalies.where((a) {
      if (_statutFilter.isNotEmpty && a['statut'] != _statutFilter) return false;
      if (_categorieFilter.isNotEmpty && a['categorie'] != _categorieFilter) return false;
      if (_dateFrom.isNotEmpty) {
        final dateC = a['dateCreation'] as String? ?? '';
        if (dateC.compareTo(_dateFrom) < 0) return false;
      }
      if (_dateTo.isNotEmpty) {
        final dateC = a['dateCreation'] as String? ?? '';
        if (dateC.compareTo(_dateTo) > 0) return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final desc = (a['description'] as String? ?? '').toLowerCase();
        final immat = (a['immatriculation'] as String? ?? '').toLowerCase();
        final chName = (a['chauffeurNom'] as String? ?? '').toLowerCase();
        final elem = (a['element'] as String? ?? '').toLowerCase();
        if (!desc.contains(q) && !immat.contains(q) && !chName.contains(q) && !elem.contains(q)) return false;
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
    final motif = await showDialog<String>(context: context, builder: (ctx) {
      final ctrl = TextEditingController();
      return AlertDialog(
        title: const Text('Motif de rejet'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Raison...'), maxLines: 2),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')), ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Rejeter'))],
      );
    });
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
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        children: [
          if (blocked.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Véhicules bloqués (${blocked.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.danger, fontSize: 13)),
                const SizedBox(height: 6),
                ...blocked.map((v) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Icon(Icons.block, size: 16, color: AppTheme.danger),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${v['truckNumber'] ?? v['immatriculation']} — ${v['immatriculation']}', style: const TextStyle(fontSize: 12))),
                    TextButton(
                      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () async {
                        await _vSvc.update(v['id'] as int, {'statut': 'DISPONIBLE'});
                        _load();
                      },
                      child: const Text('Débloquer', style: TextStyle(fontSize: 11, color: AppTheme.success)),
                    ),
                  ]),
                )),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            decoration: InputDecoration(hintText: 'Rechercher...', prefixIcon: const Icon(Icons.search, size: 20), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), isDense: true),
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(
              decoration: InputDecoration(hintText: 'Du (AAAA-MM-JJ)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), isDense: true),
              style: const TextStyle(fontSize: 12),
              onChanged: (v) => setState(() => _dateFrom = v),
            )),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              decoration: InputDecoration(hintText: 'Au (AAAA-MM-JJ)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), isDense: true),
              style: const TextStyle(fontSize: 12),
              onChanged: (v) => setState(() => _dateTo = v),
            )),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _chip('Tous', ''),
              _chip('Détectée', 'DETECTEE'),
              _chip('En réparation', 'EN_REPARATION'),
              _chip('Réparée', 'REPAREE'),
              _chip('Non réparable', 'NON_REPAREE'),
              _chip('Validée', 'VALIDEE'),
              _chip('Annulée', 'ANNULEE'),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              _chipCat('Tous', ''),
              _chipCat('Mécanique', 'Mécanique'),
              _chipCat('Pneus', 'Pneus'),
              _chipCat('Carrosserie', 'Carrosserie'),
              _chipCat('Éclairage', 'Éclairage'),
              _chipCat('Cabine', 'Cabine'),
              _chipCat('Freins', 'Freins'),
              _chipCat('Sécurité', 'Sécurité'),
            ]),
          ),
          const SizedBox(height: 8),
          if (_filtered.isEmpty)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucune anomalie')))
          else
            ..._filtered.map((a) => _buildAnomalieCard(a)),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final active = _statutFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : null)),
        selected: active,
        onSelected: (_) => setState(() => _statutFilter = active ? '' : value),
        selectedColor: _chipColor(value),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Color _chipColor(String value) {
    switch (value) { case 'DETECTEE': return AppTheme.danger; case 'EN_REPARATION': return AppTheme.warning; case 'REPAREE': return Colors.blue; case 'NON_REPAREE': return Colors.orange; case 'VALIDEE': return AppTheme.success; case 'ANNULEE': return Colors.grey; default: return AppTheme.primary; }
  }

  Widget _chipCat(String label, String value) {
    final active = _categorieFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, color: active ? Colors.white : null)),
        selected: active,
        onSelected: (_) => setState(() => _categorieFilter = active ? '' : value),
        selectedColor: AppTheme.primary,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildAnomalieCard(Map<String, dynamic> a) {
    final id = a['id'] as int;
    final statut = a['statut'] as String? ?? 'DETECTEE';
    final expand = _expandedId == id;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        ListTile(
          leading: Icon(_statusIcon(statut), color: _statusColor(statut)),
          title: Text('${a['element'] ?? ''} — ${a['immatriculation'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('${a['description'] ?? ''}  •  ${a['chauffeurNom'] ?? ''}', style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            StatusBadge(status: statut),
            IconButton(icon: Icon(expand ? Icons.expand_less : Icons.expand_more, size: 20), onPressed: () => setState(() => _expandedId = expand ? null : id)),
          ]),
        ),
        if (expand) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _detailInfo(a),
              const SizedBox(height: 8),
              Row(children: [
                if (statut == 'DETECTEE') ...[
                  _actionBtn('Prendre en charge', Icons.pan_tool, AppTheme.primary, () => _takeCharge(id)),
                  const SizedBox(width: 8),
                  _actionBtn('Annuler', Icons.cancel, Colors.grey, () => _annuler(id)),
                ],
                if (statut == 'EN_REPARATION') ...[
                  _actionBtn('Réparé', Icons.check_circle, AppTheme.success, () => _resolve(id)),
                  const SizedBox(width: 8),
                  _actionBtn('Non réparable', Icons.cancel, Colors.orange, () => _reject(id)),
                ],
                if (statut == 'REPAREE')
                  _actionBtn('Valider', Icons.verified, AppTheme.success, () async { await _svc.validate(id); _load(); }),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _detailInfo(Map<String, dynamic> a) {
    return Column(children: [
      _row('Camion', a['immatriculation'] as String? ?? '-'),
      _row('Chauffeur', a['chauffeurNom'] as String? ?? '-'),
      _row('Catégorie', a['categorie'] as String? ?? '-'),
      _row('Criticité', a['criticite'] as String? ?? '-'),
      _row('Détectée', a['dateCreation'] as String? ?? '-'),
      if (a['assignedTo'] != null) _row('Assigné à', a['assignedTo'] as String),
      if (a['datePriseEnCharge'] != null) _row('Pris en charge', a['datePriseEnCharge'] as String),
      if (a['resolutionNotes'] != null) _row('Résolution', a['resolutionNotes'] as String),
    ]);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [SizedBox(width: 110, child: Text('$label:', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))), Expanded(child: Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)))]),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return TextButton.icon(
      icon: Icon(icon, size: 16), label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      onPressed: onTap,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), foregroundColor: color, side: BorderSide(color: color.withValues(alpha: 0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
    );
  }

  IconData _statusIcon(String s) { switch (s) { case 'DETECTEE': return Icons.error_outline; case 'EN_REPARATION': return Icons.build; case 'REPAREE': return Icons.check_circle; case 'NON_REPAREE': return Icons.cancel; case 'VALIDEE': return Icons.verified; case 'ANNULEE': return Icons.cancel; default: return Icons.cancel; } }
  Color _statusColor(String s) { switch (s) { case 'DETECTEE': return AppTheme.danger; case 'EN_REPARATION': return AppTheme.warning; case 'REPAREE': return Colors.blue; case 'NON_REPAREE': return Colors.orange; case 'VALIDEE': return AppTheme.success; case 'ANNULEE': return Colors.grey; default: return Colors.grey; } }
}
