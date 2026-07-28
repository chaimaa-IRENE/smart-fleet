import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';
import '../../config/translations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/danone_app_bar.dart';
import '../../widgets/premium/glass_card.dart';
import '../../services/sync_service.dart';
import '../../services/export_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final authProv = context.watch<AuthProvider>();
    final user = authProv.user;
    final isDark = themeProv.isDarkMode;
    final locale = themeProv.locale;

    return Scaffold(
      appBar: DanoneAppBar(title: 'Paramètres'),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.person, size: 40, color: AppTheme.primary),
                ),
                const SizedBox(height: 12),
                Text(
                  user?['nom'] as String? ?? 'Chauffeur',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?['email'] as String? ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user?['role'] as String? ?? '',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(context, 'Préférences', [
            _buildSwitchTile(
              context,
              icon: Icons.dark_mode,
              title: 'Mode sombre',
              value: isDark,
              onChanged: (_) => themeProv.toggleTheme(),
            ),
            _buildTile(
              context,
              icon: Icons.language,
              title: 'Langue',
              subtitle: locale == 'fr' ? 'Français' : 'العربية',
              onTap: () => _showLanguageDialog(context, themeProv),
            ),
          ]),
          const SizedBox(height: 16),
          _buildSection(context, 'Informations', [
            _buildTile(context,
                icon: Icons.info_outline,
                title: 'Version',
                subtitle: 'SmartFleet v1.0.0'),
            _buildTile(context,
                icon: Icons.storage,
                title: 'Stockage local',
                subtitle: 'Données stockées localement'),
          ]),
          if (user?['role'] == 'ADMIN') ...[
            const SizedBox(height: 16),
            GlassCard(
              padding: const EdgeInsets.all(16),
              glowColor: AppTheme.danger,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.sync, color: AppTheme.danger),
                ),
                title: Text('Forcer la synchronisation',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                trailing: TextButton(
                  onPressed: () {
                    Provider.of<SyncService>(context, listen: false).syncAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Synchronisation lancée')),
                    );
                  },
                  child: const Text('Lancer'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Export', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.table_chart, color: AppTheme.primary),
                    title: const Text('Excel (.xlsx)'),
                    subtitle: const Text('Déclarations, check-ups, départs'),
                    trailing: TextButton(
                      onPressed: () async {
                        final svc = ExportService();
                        final path = await svc.exportExcel();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Exporté: $path')),
                          );
                        }
                      },
                      child: const Text('Exporter'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.description, color: AppTheme.success),
                    title: const Text('CSV Déclarations'),
                    onTap: () async {
                      final svc = ExportService();
                      final path = await svc.exportDeclarationsCSV();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Exporté: $path')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  letterSpacing: 0.5,
                )),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildTile(BuildContext context,
      {required IconData icon,
      required String title,
      String? subtitle,
      VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppTheme.textPrimary)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
          : null,
      trailing: onTap != null
          ? Icon(Icons.chevron_right,
              color: AppTheme.textSecondary.withValues(alpha: 0.5))
          : null,
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(BuildContext context,
      {required IconData icon,
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : AppTheme.textPrimary)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.primary,
    );
  }

  void _showLanguageDialog(BuildContext context, ThemeProvider themeProv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Choisir la langue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('Français'),
              selected: themeProv.locale == 'fr',
              onTap: () {
                themeProv.setLocale('fr');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('العربية'),
              selected: themeProv.locale == 'ar',
              onTap: () {
                themeProv.setLocale('ar');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
