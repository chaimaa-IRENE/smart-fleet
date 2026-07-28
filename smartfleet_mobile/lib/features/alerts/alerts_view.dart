import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/alert_service.dart';
import '../../widgets/kpi_card.dart';

class AlertsView extends StatefulWidget {
  const AlertsView({super.key});

  @override
  State<AlertsView> createState() => _AlertsViewState();
}

class _AlertsViewState extends State<AlertsView> {
  final FleetAlertService _svc = FleetAlertService();
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _blockings = [];
  Map<String, dynamic> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _alerts = await _svc.getActive();
      _blockings = await _svc.getActiveBlockings();
      _counts = await _svc.getCounts();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alertes & Blocages')),
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
                              title: 'Alertes actives',
                              value: '${_counts['total'] ?? 0}',
                              icon: Icons.notifications_active,
                              color: AppTheme.danger,),),
                      const SizedBox(width: 8),
                      Expanded(
                          child: KpiCard(
                              title: 'Critiques',
                              value: '${_counts['critiques'] ?? 0}',
                              icon: Icons.dangerous,
                              color: AppTheme.danger,),),
                      const SizedBox(width: 8),
                      Expanded(
                          child: KpiCard(
                              title: 'Véhicules bloqués',
                              value: '${_blockings.length}',
                              icon: Icons.block,
                              color: AppTheme.warning,),),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_blockings.isNotEmpty) ...[
                    const Text(
                      'Véhicules bloqués',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._blockings.map(
                      (b) => Card(
                        child: ListTile(
                          leading:
                              const Icon(Icons.block, color: AppTheme.danger),
                          title: Text(b['immatriculation'] as String? ?? ''),
                          subtitle: Text('Raison: ${b['raison'] ?? ''}'),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              await _svc.unblockVehicle(
                                  b['vehiculeId'] as int, 0,);
                              _load();
                            },
                            child: const Text('Débloquer'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Alertes actives',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._alerts.map((a) => _buildAlertCard(a)),
                ],
              ),
            ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> a) {
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
        title: Text(a['message'] as String? ?? ''),
        subtitle: Text(
            '${a['immatriculation'] ?? ''} • ${a['type'] ?? ''} • ${a['dateCreation'] ?? ''}',),
        trailing: IconButton(
          icon: const Icon(Icons.check_circle_outline),
          onPressed: () async {
            await _svc.resolve(a['id'] as int, 'CurrentUser');
            _load();
          },
        ),
      ),
    );
  }
}
