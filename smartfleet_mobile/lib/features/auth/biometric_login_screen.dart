import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_auth_service.dart';

class BiometricLoginScreen extends StatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  State<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends State<BiometricLoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  bool _authenticating = true;
  bool _failed = false;
  int _attempts = 0;
  static const int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _startBiometricAuth();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startBiometricAuth() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    _doAuth();
  }

  Future<void> _doAuth() async {
    setState(() {
      _authenticating = true;
      _failed = false;
    });
    final bioProv = context.read<BiometricProvider>();
    final ok = await bioProv.authenticate();
    if (!mounted) return;
    if (ok) {
      setState(() => _authenticating = false);
      await _loginWithBiometric();
    } else {
      _attempts++;
      setState(() {
        _authenticating = false;
        _failed = true;
      });
      if (_attempts >= _maxAttempts) {
        if (mounted) {
          context.go('/login');
        }
        return;
      }
    }
  }

  Future<void> _loginWithBiometric() async {
    final authService = context.read<AuthService>();
    final bioService = context.read<BiometricAuthService>();
    final authProv = context.read<AuthProvider>();
    final userId = await bioService.getBiometricUserId();
    if (userId == null) {
      if (mounted) context.go('/login');
      return;
    }
    final user = await authService.getUserById(userId);
    if (user == null) {
      if (mounted) context.go('/login');
      return;
    }
    await authProv.loadUser(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.face,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) => Opacity(
                  opacity: _fadeAnimation.value,
                  child: child,
                ),
                child: Text(
                  Translations.t('faceid.look'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                Translations.t('faceid.prompt'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 36),
              if (_authenticating) ...[
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    Translations.t('faceid.usePassword'),
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ),
              ] else if (_failed) ...[
                const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 48),
                const SizedBox(height: 16),
                Text(
                  '${Translations.t('faceid.failed')} (${_maxAttempts - _attempts}/$_maxAttempts)',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _doAuth,
                  icon: const Icon(Icons.refresh),
                  label: Text(Translations.t('faceid.retry')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    Translations.t('faceid.usePassword'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
