import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/anomalie_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/alert_service.dart';
import '../../widgets/danone_app_bar.dart';
import 'rs_anomalies.dart';
import 'rs_declarations.dart';
import 'rs_documents.dart';

class RsDashboard extends StatefulWidget {
  const RsDashboard({super.key});

  @override
  State<RsDashboard> createState() => _RsDashboardState();
}

class _RsDashboardState extends State<RsDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  Map<String, dynamic> _anomalieStats = {};
  List<Map<String, dynamic>> _vehicles = [];
  int _alertCount = 0;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AnomalieService().getStats(),
        VehicleService().getAll(),
        FleetAlertService().getActive(),
      ]);
      if (mounted) {
        setState(() {
          _anomalieStats = results[0] as Map<String, dynamic>;
          _vehicles = results[1] as List<Map<String, dynamic>>;
          _alertCount = (results[2] as List).length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final blockedCount = _vehicles.where((v) => v['statut'] == 'BLOQUE').length;

    final detectees = _anomalieStats['detectees'] as int? ?? 0;
    final enReparation = _anomalieStats['enReparation'] as int? ?? 0;
    final reparees = _anomalieStats['reparees'] as int? ?? 0;
    final total = (_anomalieStats['total'] as int? ?? 0);
    final validees = _anomalieStats['validees'] as int? ?? 0;
    final nonReparables = _anomalieStats['nonReparees'] as int? ?? 0;
    final tauxReparation = _anomalieStats['tauxReparation'] as String? ?? '0%';

    return Scaffold(
      appBar: DanoneAppBar(
        title: user?['nom'] as String? ?? 'RS',
        actions: [
          if (_alertCount > 0)
            Stack(children: [
              IconButton(icon: const Icon(Icons.notifications_active), onPressed: () => context.go('/rs/alerts')),
              Positioned(right: 6, top: 6, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: AppTheme.danger, shape: BoxShape.circle), child: Text('$_alertCount', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)))),
            ]),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => context.go('/rs/settings')),
          IconButton(icon: const Icon(Icons.logout), onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (context.mounted) context.go('/login');
          }),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.shade300)),
                  child: const Text('Anomalies = SANS budget', style: TextStyle(fontSize: 10, color: Colors.orange)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade300)),
                  child: const Text('Déclarations = AVEC budget', style: TextStyle(fontSize: 10, color: Colors.blue)),
                ),
              ]),
            ),
            TabBar(
              controller: _tabCtrl,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(icon: Icon(Icons.bug_report), text: 'Anomalies'),
                Tab(icon: Icon(Icons.list_alt), text: 'Déclarations'),
                Tab(icon: Icon(Icons.description), text: 'Documents'),
              ],
            ),
          ]),
        ),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : TabBarView(
        controller: _tabCtrl,
        children: [
          _buildAnomaliesTab(detectees, enReparation, reparees, total, validees, nonReparables, tauxReparation, blockedCount),
          const RsDeclarations(),
          const RsDocuments(),
        ],
      ),
    );
  }

  Widget _buildAnomaliesTab(int detectees, int enReparation, int reparees, int total, int validees, int nonReparables, String tauxReparation, int blocked) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            Expanded(child: _miniKpi('Total', '$total', Icons.bug_report, AppTheme.primary)),
            const SizedBox(width: 6),
            Expanded(child: _miniKpi('Détectées', '$detectees', Icons.error_outline, AppTheme.danger)),
            const SizedBox(width: 6),
            Expanded(child: _miniKpi('En réparation', '$enReparation', Icons.build, AppTheme.warning)),
            const SizedBox(width: 6),
            Expanded(child: _miniKpi('Réparées', '$reparees', Icons.check_circle, AppTheme.success)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _miniKpi('Validées', '$validees', Icons.verified, AppTheme.success)),
            const SizedBox(width: 6),
            Expanded(child: _miniKpi('Non réparables', '$nonReparables', Icons.cancel, Colors.orange)),
            const SizedBox(width: 6),
            Expanded(child: _miniKpi('Taux réparation', tauxReparation, Icons.percent, Colors.blue)),
          ]),
          const SizedBox(height: 8),
          if (blocked > 0)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.block, size: 18, color: AppTheme.danger),
                const SizedBox(width: 8),
                Text('$blocked véhicule(s) bloqué(s)', style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                TextButton(onPressed: () => context.go('/rs/anomalies'), child: const Text('Voir', style: TextStyle(fontSize: 12))),
              ]),
            ),
        ]),
      ),
      const Expanded(child: RsAnomalies()),
    ]);
  }

  Widget _miniKpi(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(title, style: TextStyle(fontSize: 9, color: color)),
      ]),
    );
  }
}
