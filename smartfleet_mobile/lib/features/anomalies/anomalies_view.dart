import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/anomalie_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/kpi_card.dart';

class AnomaliesView extends StatefulWidget {
  const AnomaliesView({super.key});

  @override
  State<AnomaliesView> createState() => _AnomaliesViewState();
}

class _AnomaliesViewState extends State<AnomaliesView> {
  final AnomalieService _svc = AnomalieService();
  List<Map<String, dynamic>> _anomalies = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  String? _filterStatut;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _anomalies = await _svc.getAll(statut: _filterStatut);
      _stats = await _svc.getStats();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anomalies'),
        actions: [
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _filterStatut = v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: null, child: Text('Toutes')),
              PopupMenuItem(value: 'OUVERTE', child: Text('Ouvertes')),
              PopupMenuItem(value: 'EN_COURS', child: Text('En cours')),
              PopupMenuItem(value: 'RESOLUE', child: Text('Résolues')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: KpiCard(
                              title: 'Total',
                              value: '${_stats['total'] ?? 0}',
                              icon: Icons.bug_report,
                              color: AppTheme.primary,),),
                      const SizedBox(width: 8),
                      Expanded(
                          child: KpiCard(
                              title: 'Ouvertes',
                              value: '${_stats['ouvertes'] ?? 0}',
                              icon: Icons.error,
                              color: AppTheme.danger,),),
                      const SizedBox(width: 8),
                      Expanded(
                          child: KpiCard(
                              title: 'Critiques',
                              value: '${_stats['critiques'] ?? 0}',
                              icon: Icons.warning,
                              color: AppTheme.warning,),),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._anomalies.map((a) => _buildAnomalieCard(a)),
                ],
              ),
            ),
    );
  }

  Widget _buildAnomalieCard(Map<String, dynamic> a) {
    final statut = a['statut'] as String? ?? 'OUVERTE';
    final criticite = a['criticite'] as String? ?? 'MOYENNE';
    return Card(
      child: ListTile(
        leading: Icon(
          criticite == 'CRITIQUE'
              ? Icons.dangerous
              : criticite == 'MOYENNE'
                  ? Icons.warning
                  : Icons.info,
          color: criticite == 'CRITIQUE'
              ? AppTheme.danger
              : criticite == 'MOYENNE'
                  ? AppTheme.warning
                  : AppTheme.accent,
        ),
        title: Text('${a['element'] ?? ''} - ${a['immatriculation'] ?? ''}'),
        subtitle:
            Text('${a['description'] ?? ''} • ${a['dateCreation'] ?? ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: statut),
            PopupMenuButton(
              itemBuilder: (_) => [
                if (statut == 'OUVERTE')
                  const PopupMenuItem(
                      value: 'take', child: Text('Prendre en charge'),),
                if (statut == 'EN_COURS')
                  const PopupMenuItem(
                      value: 'resolve', child: Text('Résoudre'),),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
              onSelected: (v) async {
                if (v == 'take') {
                  await _svc.takeCharge(a['id'] as int, 'CurrentUser');
                }
                if (v == 'resolve') await _svc.resolve(a['id'] as int);
                if (v == 'delete') await _svc.delete(a['id'] as int);
                _load();
              },
            ),
          ],
        ),
      ),
    );
  }
}
