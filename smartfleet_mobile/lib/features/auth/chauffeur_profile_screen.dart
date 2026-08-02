import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../config/translations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/declaration_service.dart';
import '../../services/vehicle_service.dart';
import '../../services/tournee_service.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';
import '../../widgets/premium/premium_kpi_card.dart';

class ChauffeurProfileScreen extends StatefulWidget {
  const ChauffeurProfileScreen({super.key});

  @override
  State<ChauffeurProfileScreen> createState() => _ChauffeurProfileScreenState();
}

class _ChauffeurProfileScreenState extends State<ChauffeurProfileScreen> {
  int _decCount = 0;
  int _vehCount = 0;
  int _tourCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final user = context.read<AuthProvider>().user;
    final id = user?['id'] as int? ?? 0;
    final dec = await DeclarationService().getMyDeclarations(id);
    final veh = await VehicleService().getMyVehicles(id);
    final tour = await TourneeService().getByChauffeur(id);
    if (mounted) setState(() {
      _decCount = dec.length;
      _vehCount = veh.length;
      _tourCount = tour.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final themeProv = context.watch<ThemeProvider>();
    final isDark = themeProv.isDarkMode;
    final locale = themeProv.locale;

    return Scaffold(
      appBar: DanoneAppBar(title: 'Profil'),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            glowColor: AppTheme.primary,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    (user?['nom'] as String? ?? '?').substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(user?['nom'] as String? ?? 'Chauffeur',
                    style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(user?['email'] as String? ?? '',
                    style: const TextStyle(color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(user?['matricule'] as String? ?? '',
                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(user?['role'] as String? ?? '',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600, fontSize: 14,
                      ), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: PremiumKpiCard(
                title: 'Déclarations', value: '$_decCount',
                icon: Icons.list_alt, color: AppTheme.primary,
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
                title: 'Tournées', value: '$_tourCount',
                icon: Icons.route, color: AppTheme.success,
              )),
              const SizedBox(width: 12),
              Expanded(child: PremiumKpiCard(
                title: 'Sync', value: 'OK',
                icon: Icons.sync, color: AppTheme.success,
              )),
            ],
          ),
          const SizedBox(height: 24),
          _buildInfoSection(context, 'Informations personnelles', [
            _buildInfoRow(Icons.email, 'Email', user?['email'] as String? ?? '-'),
            _buildInfoRow(Icons.badge, 'Matricule', user?['matricule'] as String? ?? '-'),
            _buildInfoRow(Icons.phone, 'Téléphone', user?['telephone'] as String? ?? '-'),
          ]),
          const SizedBox(height: 16),
          _buildInfoSection(context, 'Préférences', [
            SwitchListTile(
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                    color: AppTheme.primary, size: 20),
              ),
              title: Text('Mode sombre',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  )),
              value: isDark,
              onChanged: (_) => themeProv.toggleTheme(),
              activeColor: AppTheme.primary,
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.language, color: AppTheme.primary, size: 20),
              ),
              title: Text('Langue',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  )),
              subtitle: Text(locale == 'fr' ? 'Français' : 'العربية',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              trailing: Icon(Icons.chevron_right, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              onTap: () => _showLangDialog(themeProv),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, String title, List<Widget> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppTheme.primary, letterSpacing: 0.5,
                )),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }

  void _showLangDialog(ThemeProvider themeProv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Choisir la langue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.check, color: themeProv.locale == 'fr' ? AppTheme.primary : Colors.transparent),
              title: const Text('Français'),
              onTap: () { themeProv.setLocale('fr'); Navigator.pop(ctx); },
            ),
            ListTile(
              leading: Icon(Icons.check, color: themeProv.locale == 'ar' ? AppTheme.primary : Colors.transparent),
              title: const Text('العربية'),
              onTap: () { themeProv.setLocale('ar'); Navigator.pop(ctx); },
            ),
          ],
        ),
      ),
    );
  }
}
