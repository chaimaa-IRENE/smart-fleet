import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/alert_service.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_kpi_card.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _userCount = 0;
  int _vehCount = 0;
  int _alertCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final users = await UserService().getAll();
    final vehs = await VehicleService().getAll();
    final alerts = await FleetAlertService().getActive();
    if (mounted) {
      setState(() {
        _userCount = users.length;
        _vehCount = vehs.length;
        _alertCount = alerts.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: DanoneAppBar(
        title: '${user?['nom'] ?? ''} (Admin)',
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/admin/settings'),
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
                Text('Administration Centrale',
                    style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text('Gestion de la flotte',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: PremiumKpiCard(
                title: 'Utilisateurs', value: '$_userCount',
                icon: Icons.people, color: AppTheme.primary,
              )),
              const SizedBox(width: 12),
              Expanded(child: PremiumKpiCard(
                title: 'Véhicules', value: '$_vehCount',
                icon: Icons.directions_car, color: AppTheme.accent,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: PremiumKpiCard(
                title: 'Alertes', value: '$_alertCount',
                icon: Icons.notifications_active,
                color: _alertCount > 0 ? AppTheme.danger : AppTheme.success,
              )),
              const SizedBox(width: 12),
              Expanded(child: PremiumKpiCard(
                title: 'Admin', value: 'v1.0',
                icon: Icons.admin_panel_settings, color: Colors.indigo,
                subtitle: 'SmartFleet',
              )),
            ],
          ),
          const SizedBox(height: 24),
          Text('Gestion',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              )),
          const SizedBox(height: 12),
          _buildGrid(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    final items = [
      _AItem('Utilisateurs', Icons.people, AppTheme.primary, '/admin/users'),
      _AItem('Véhicules', Icons.directions_car, AppTheme.secondary, '/admin/vehicles'),
      _AItem('Documents', Icons.description, Colors.teal, '/admin/documents'),
      _AItem('Inspections', Icons.fact_check, AppTheme.success, '/admin/checkups'),
      _AItem('Alertes', Icons.notifications_active, Colors.deepOrange, '/admin/alerts'),
      _AItem('Audit', Icons.history, Colors.grey, '/admin/audit'),
      _AItem('Face ID', Icons.face, Colors.indigo, '/admin/biometric'),
      _AItem('Affectations', Icons.swap_horiz, Colors.orange, '/admin/affectations'),
    ];
    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: _buildTile(items[i])),
                if (i + 1 < items.length) ...[
                  const SizedBox(width: 12),
                  Expanded(child: _buildTile(items[i + 1])),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTile(_AItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => context.go(item.route),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: item.color.withValues(alpha: 0.12),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ColorFilter.mode(
              isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.5),
              BlendMode.srcOver,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.85),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : item.color.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 32, color: item.color),
                  const SizedBox(height: 8),
                  Text(item.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AItem {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  _AItem(this.label, this.icon, this.color, this.route);
}
