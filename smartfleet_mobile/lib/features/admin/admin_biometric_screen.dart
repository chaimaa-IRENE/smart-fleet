import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../providers/biometric_provider.dart';

class AdminBiometricScreen extends StatefulWidget {
  const AdminBiometricScreen({super.key});

  @override
  State<AdminBiometricScreen> createState() => _AdminBiometricScreenState();
}

class _AdminBiometricScreenState extends State<AdminBiometricScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<BiometricProvider>().loadAllBiometricUsers();
  }

  Future<void> _disableRemote(int userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Translations.t('faceid.disableRemoteTitle')),
        content: Text('${Translations.t('faceid.disableRemoteDesc')} $userName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Translations.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(Translations.t('common.yes'),
                style: const TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await context.read<BiometricProvider>().adminDisableRemote(userId);
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bioProv = context.watch<BiometricProvider>();
    final users = bioProv.allBiometricUsers;

    return Scaffold(
      appBar: AppBar(
        title: Text(Translations.t('faceid.adminTitle')),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${Translations.t('faceid.activeDevices')}: ${bioProv.activeDeviceCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: users.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.face, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(Translations.t('faceid.noUsers'),
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, i) {
                  final d = users[i];
                  final isActive = d['biometricEnabled'] == 1;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isActive
                          ? AppTheme.success.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      child: Icon(
                        isActive ? Icons.face : Icons.face_retouching_off,
                        color: isActive ? AppTheme.success : Colors.grey,
                      ),
                    ),
                    title: Text(d['nom']?.toString() ?? ''),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${d['email']} • ${d['role']}'),
                        Text(
                          '${d['platform']} • ${d['deviceName']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    trailing: isActive
                        ? IconButton(
                            icon: const Icon(Icons.block, color: AppTheme.danger),
                            tooltip: Translations.t('faceid.disableRemoteTitle'),
                            onPressed: () => _disableRemote(
                              d['userId'] as int,
                              d['nom']?.toString() ?? '',
                            ),
                          )
                        : const Icon(Icons.block, color: Colors.grey),
                    isThreeLine: true,
                  );
                },
              ),
            ),
    );
  }
}
