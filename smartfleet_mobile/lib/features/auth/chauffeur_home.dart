import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../config/translations.dart';
import '../../providers/auth_provider.dart';
import '../../services/declaration_service.dart';
import '../../services/vehicle_service.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_kpi_card.dart';
import '../../services/sync_service.dart';

class ChauffeurHome extends StatefulWidget {
  const ChauffeurHome({super.key});

  @override
  State<ChauffeurHome> createState() => _ChauffeurHomeState();
}

class _ChauffeurHomeState extends State<ChauffeurHome> {
  int _decCount = 0;
  int _vehCount = 0;
  int _syncing = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = context.read<AuthProvider>().user;
    final chauffeurId = user?['id'] as int? ?? 0;
    final dec = await DeclarationService().getMyDeclarations(chauffeurId);
    final veh = await VehicleService().getMyVehicles(chauffeurId);
    if (mounted) {
      setState(() {
        _decCount = dec.length;
        _vehCount = veh.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final syncState = context.watch<SyncService>();
    final pending = syncState.pendingCount;

    return Scaffold(
      appBar: DanoneAppBar(
        title: user?['nom'] as String? ?? '',
        actions: [
          if (pending > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('$pending', style: TextStyle(color: Colors.orange, fontSize: 11)),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/chauffeur/settings'),
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
                Text('Bon retour, ${user?['nom'] as String? ?? ''} !',
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text('Prêt pour une nouvelle journée ?',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PremiumKpiCard(
                  title: 'Déclarations',
                  value: '$_decCount',
                  icon: Icons.list_alt,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PremiumKpiCard(
                  title: 'Véhicules',
                  value: '$_vehCount',
                  icon: Icons.directions_car,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PremiumKpiCard(
                  title: 'Sync',
                  value: '$pending',
                  icon: Icons.sync,
                  color: pending > 0 ? AppTheme.warning : AppTheme.success,
                  subtitle: pending > 0 ? 'En attente' : 'À jour',
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 24),
          Text('Actions rapides',
              style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white : AppTheme.textPrimary,
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ActionTile(
                icon: Icons.add_circle,
                label: 'Déclaration',
                color: AppTheme.primary,
                onTap: () => context.go('/chauffeur/declarations/create'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _ActionTile(
                icon: Icons.mic,
                label: 'Agent vocal',
                color: AppTheme.accent,
                onTap: () => context.go('/chauffeur/voice'),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ActionTile(
                icon: Icons.checklist,
                label: 'Check-up',
                color: AppTheme.success,
                onTap: () => context.go('/chauffeur/checklist'),
              )),
              const SizedBox(width: 12),
              Expanded(child: _ActionTile(
                icon: Icons.list_alt,
                label: 'Mes déclarations',
                color: AppTheme.secondary,
                onTap: () => context.go('/chauffeur/declarations'),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _ActionTile(
                icon: Icons.description,
                label: 'Documents',
                color: Colors.teal,
                onTap: () => context.go('/chauffeur/documents'),
              )),
              const SizedBox(width: 12),
              // empty placeholder to keep 2-column grid
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final double iconSize;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
                      : color.withValues(alpha: 0.2),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: iconSize, color: color),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
