import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../providers/biometric_provider.dart';
import '../../services/biometric_auth_service.dart';

class BiometricSetupScreen extends StatefulWidget {
  final int userId;
  final String userName;
  const BiometricSetupScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  bool _loading = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBiometric());
  }

  Future<void> _checkBiometric() async {
    final bioService = context.read<BiometricAuthService>();
    final available = await bioService.isAvailable();
    if (!mounted) return;
    if (!available) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _enable() async {
    setState(() => _loading = true);
    final bioProv = context.read<BiometricProvider>();
    final ok = await bioProv.enroll(widget.userId, widget.userName);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _success = ok;
    });
    if (ok) {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _skip() async {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.primary,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: _success
                        ? const Icon(Icons.check_circle,
                            size: 100, color: Colors.greenAccent)
                        : Container(
                            key: const ValueKey('faceid'),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            child: const Icon(
                              Icons.face,
                              size: 56,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    _success
                        ? Translations.t('faceid.activated')
                        : Translations.t('faceid.setupTitle'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _success
                        ? Translations.t('faceid.activatedDesc')
                        : Translations.t('faceid.setupDesc'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  if (!_success) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _enable,
                        icon: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.face),
                        label: Text(_loading
                            ? Translations.t('common.loading')
                            : Translations.t('faceid.activate')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _skip,
                      child: Text(
                        Translations.t('faceid.skip'),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
