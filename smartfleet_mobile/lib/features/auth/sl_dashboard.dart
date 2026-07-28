import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../providers/auth_provider.dart';
import '../../services/alert_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/tournee_service.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_kpi_card.dart';
import '../../widgets/premium/aurora_background.dart';

class SlDashboard extends StatefulWidget {
  const SlDashboard({super.key});

  @override
  State<SlDashboard> createState() => _SlDashboardState();
}

class _SlDashboardState extends State<SlDashboard> {
  int _alertCount = 0;
  int _vehCount = 0;
  int _tourCount = 0;
  int _vehiculesDisponibles = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final alerts = await FleetAlertService().getActive();
    final vehs = await VehicleService().getAll();
    final tours = await TourneeService().getAll();
    final dispo = vehs.where((v) => v['statut'] == 'DISPONIBLE').length;
    if (mounted) {
      setState(() {
        _alertCount = alerts.length;
        _vehCount = vehs.length;
        _tourCount = tours.length;
        _vehiculesDisponibles = dispo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final dispoPct = _vehCount > 0 ? (_vehiculesDisponibles * 100 ~/ _vehCount) : 0;

    return Scaffold(
      appBar: DanoneAppBar(
        title: '${user?['nom'] ?? ''} (SL)',
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/sl/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            glowColor: AppTheme.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Monitoring Logistique',
                    style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text('Vue d\'ensemble opérationnelle',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: PremiumKpiCard(
                title: 'Alertes actives', value: '$_alertCount',
                icon: Icons.warning, color: _alertCount > 0 ? AppTheme.danger : AppTheme.success,
              )),
              const SizedBox(width: 12),
              Expanded(child: PremiumKpiCard(
                title: 'Véhicules', value: '$_vehCount',
                icon: Icons.directions_car, color: AppTheme.primary,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: PremiumKpiCard(
                title: 'Disponibilité', value: '$dispoPct%',
                icon: Icons.check_circle, color: dispoPct >= 80 ? AppTheme.success : AppTheme.warning,
              )),
              const SizedBox(width: 12),
              Expanded(child: PremiumKpiCard(
                title: 'Tournées', value: '$_tourCount',
                icon: Icons.route, color: Colors.deepOrange,
              )),
            ],
          ),
          const SizedBox(height: 24),
          Text('Actions',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white : AppTheme.textPrimary,
              )),
          const SizedBox(height: 12),
          _buildMenuCard('Alertes & Blocages', Icons.notifications_active,
              AppTheme.danger, '/sl/alerts'),
          const SizedBox(height: 12),
          _buildMenuCard('Tracking GPS', Icons.gps_fixed,
              Colors.purple, '/sl/tracking'),
          const SizedBox(height: 12),
          _buildMenuCard('Tournées', Icons.route,
              Colors.deepOrange, '/sl/tournees'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMenuCard(String label, IconData icon, Color color, String route) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      glowColor: color,
      onTap: () => context.go(route),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(label,
            style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 16,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            )),
        trailing: Icon(Icons.chevron_right,
            color: AppTheme.textSecondary.withValues(alpha: 0.5)),
      ),
    );
  }
}
