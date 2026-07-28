import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/biometric_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_auth_service.dart';
import 'biometric_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPassword = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBiometric());
  }

  Future<void> _initBiometric() async {
    final bioService = context.read<BiometricAuthService>();
    final available = await bioService.isAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);
    if (available) {
      final bioProv = context.read<BiometricProvider>();
      if (bioProv.status == BiometricStatus.enrolled) {
        _biometricLogin();
      }
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final authProv = context.read<AuthProvider>();
    await authProv.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (authProv.status == AuthStatus.authenticated) {
      await _checkBiometricSetup(authProv.user!['id'] as int);
    }
  }

  Future<void> _checkBiometricSetup(int userId) async {
    if (!_biometricAvailable) return;
    final bioProv = context.read<BiometricProvider>();
    final enrolled = await bioProv.checkForUser(userId);
    if (!mounted) return;
    if (!enrolled) {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BiometricSetupScreen(
          userId: userId,
          userName: _emailCtrl.text.trim(),
        ),
      );
    }
  }

  Future<void> _biometricLogin() async {
    final bioProv = context.read<BiometricProvider>();
    final ok = await bioProv.authenticate();
    if (!ok || !mounted) return;
    final bioService = context.read<BiometricAuthService>();
    final userId = await bioService.getBiometricUserId();
    if (userId == null) return;
    final authService = context.read<AuthService>();
    final user = await authService.getUserById(userId);
    if (user == null || !mounted) return;
    await context.read<AuthProvider>().loadUser(user);
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final themeProv = context.watch<ThemeProvider>();
    final bioProv = context.watch<BiometricProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primary, AppTheme.secondary],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping,
                          size: 56, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'DANONE',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SmartFleet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 6,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Card(
                      elevation: 12,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 28),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: InputDecoration(
                                labelText: Translations.t('login.email'),
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Requis' : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: !_showPassword,
                              decoration: InputDecoration(
                                labelText: Translations.t('login.password'),
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  onPressed: () => setState(
                                      () => _showPassword = !_showPassword),
                                ),
                              ),
                              validator: (v) =>
                                  v?.isEmpty ?? true ? 'Requis' : null,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => context.go('/forgot-password'),
                                child: const Text('Mot de passe oublié ?',
                                    style: TextStyle(color: AppTheme.primary, fontSize: 13)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed:
                                    authProv.status == AuthStatus.loading
                                        ? null
                                        : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child:
                                    authProv.status == AuthStatus.loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            Translations.t('login.button'),
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600),
                                          ),
                              ),
                            ),
                            if (authProv.error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  authProv.error!,
                                  style: const TextStyle(
                                    color: AppTheme.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                            if (_biometricAvailable &&
                                bioProv.status == BiometricStatus.enrolled) ...[
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _biometricLogin,
                                  icon: const Icon(Icons.fingerprint,
                                      size: 24),
                                  label: Text(
                                      Translations.t('login.faceid')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          Translations.t('login.noAccount'),
                          style:
                              TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: Text(
                            Translations.t('login.contact'),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            themeProv.isDarkMode
                                ? Icons.light_mode
                                : Icons.dark_mode,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => themeProv.toggleTheme(),
                            child: Text(
                              themeProv.isDarkMode
                                  ? 'Mode clair'
                                  : 'Mode sombre',
                              style:
                                  TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
