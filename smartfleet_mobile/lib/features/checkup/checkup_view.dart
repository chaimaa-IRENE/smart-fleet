import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/checkup_service.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/kpi_card.dart';

class CheckupView extends StatefulWidget {
  const CheckupView({super.key});

  @override
  State<CheckupView> createState() => _CheckupViewState();
}

class _CheckupViewState extends State<CheckupView> {
  final CheckupService _svc = CheckupService();
  List<Map<String, dynamic>> _checkups = [];
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _checkups = await _svc.getAll();
      _stats = await _svc.getStats();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspections véhicules')),
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
                          icon: Icons.fact_check,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KpiCard(
                          title: 'Conformes',
                          value: '${_stats['conforme'] ?? 0}',
                          icon: Icons.check_circle,
                          color: AppTheme.success,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KpiCard(
                          title: 'Taux',
                          value: '${(_stats['taux'] ?? 0).toStringAsFixed(0)}%',
                          icon: Icons.percent,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._checkups.map((c) => _buildCheckupCard(c)),
                ],
              ),
            ),
    );
  }

  Widget _buildCheckupCard(Map<String, dynamic> c) {
    final conforme = c['conforme'] == 1;
    return Card(
      child: ListTile(
        leading: Icon(
          conforme ? Icons.check_circle : Icons.warning,
          color: conforme ? AppTheme.success : AppTheme.danger,
          size: 36,
        ),
        title: Text('${c['immatriculation'] ?? ''} - ${c['code'] ?? ''}'),
        subtitle:
            Text('${c['chauffeurNom'] ?? ''} • ${c['dateCheckup'] ?? ''}'),
        trailing: StatusBadge(status: conforme ? 'VALIDEE' : 'BLOQUEE'),
        onTap: () => _showDetails(c),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> c) async {
    final details = await _svc.getDetails(c['id'] as int);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Détails inspection ${c['immatriculation'] ?? ''}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...details.map(
              (d) => ListTile(
                leading: Icon(
                  d['conforme'] == 1 ? Icons.check : Icons.close,
                  color:
                      d['conforme'] == 1 ? AppTheme.success : AppTheme.danger,
                ),
                title: Text(d['element'] as String? ?? ''),
                subtitle: Text(d['observation'] as String? ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
