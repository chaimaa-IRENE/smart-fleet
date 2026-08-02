import 'dart:math';
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showPassword = false;
  bool _biometricAvailable = false;
  bool _showIntro = true;

  late AnimationController _animCtrl;
  late Animation<double> _truckAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _truckAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0, 0.6, curve: Curves.easeOutBack)),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeIn)),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic)),
    );
    _animCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showIntro = false);
        });
      }
    });
    _animCtrl.forward();
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
    _animCtrl.dispose();
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

    if (_showIntro) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A1628), Color(0xFF1A2940), Color(0xFF0D1B2A)],
            ),
          ),
          child: Stack(
            children: [
              // Particle background
              Positioned.fill(
                child: CustomPaint(
                  painter: _ParticlePainter(progress: _truckAnim.value),
                ),
              ),
              // Animated road lines
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                height: 3,
                child: IgnorePointer(
                  child: _AnimatedRoadLines(progress: _truckAnim.value),
                ),
              ),
              // Main content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Spacer(flex: 2),
                    // Animated truck icon
                    ScaleTransition(
                      scale: _truckAnim,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.local_shipping, size: 64, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(
                          children: [
                            const Text(
                              'DANONE',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SmartFleet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                color: Colors.white.withValues(alpha: 0.8),
                                letterSpacing: 8,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Pilotage intelligent de votre parc',
                                style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Loading dots
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) => _AnimatedDot(i: i, controller: _animCtrl)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF1A2940)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Compact header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.local_shipping, size: 32, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('DANONE', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 3)),
                            Text('SmartFleet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w300, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 4)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Login card
                    Card(
                      elevation: 12,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _emailCtrl,
                              decoration: InputDecoration(
                                labelText: Translations.t('login.email'),
                                prefixIcon: const Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: !_showPassword,
                              decoration: InputDecoration(
                                labelText: Translations.t('login.password'),
                                prefixIcon: const Icon(Icons.lock_outlined),
                                suffixIcon: IconButton(
                                  icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _showPassword = !_showPassword),
                                ),
                              ),
                              validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => context.go('/forgot-password'),
                                child: const Text('Mot de passe oublié ?', style: TextStyle(color: AppTheme.primary, fontSize: 12)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: authProv.status == AuthStatus.loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: authProv.status == AuthStatus.loading
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(Translations.t('login.button'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            if (authProv.error != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                                child: Text(authProv.error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            if (_biometricAvailable && bioProv.status == BiometricStatus.enrolled) ...[
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton.icon(
                                  onPressed: _biometricLogin,
                                  icon: const Icon(Icons.fingerprint, size: 22),
                                  label: Text(Translations.t('login.faceid')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.success,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(Translations.t('login.noAccount'), style: TextStyle(color: Colors.white.withValues(alpha: 0.6)), maxLines: 1, overflow: TextOverflow.ellipsis),
                        TextButton(
                          onPressed: () {},
                          child: Text(Translations.t('login.contact'), style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => themeProv.toggleTheme(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(themeProv.isDarkMode ? Icons.light_mode : Icons.dark_mode, size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(themeProv.isDarkMode ? 'Mode clair' : 'Mode sombre', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                          ],
                        ),
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

// ──── Animated Particles ────
class _ParticlePainter extends CustomPainter {
  final double progress;
  _ParticlePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final paint = Paint()..style = PaintingStyle.fill;
    final rng = Random(42);
    for (int i = 0; i < 30; i++) {
      final x = rng.nextDouble() * size.width;
      final y = ((rng.nextDouble() * size.height * 0.7) + (progress * size.height * 0.1) - size.height * 0.05) % size.height;
      final radius = 1.0 + rng.nextDouble() * 2.5;
      final alpha = ((0.2 + rng.nextDouble() * 0.4) * (1 - progress * 0.5)).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

// ──── Animated Road Lines ────
class _AnimatedRoadLines extends StatefulWidget {
  final double progress;
  const _AnimatedRoadLines({required this.progress});

  @override
  State<_AnimatedRoadLines> createState() => _AnimatedRoadLinesState();
}

class _AnimatedRoadLinesState extends State<_AnimatedRoadLines>
    with SingleTickerProviderStateMixin {
  late AnimationController _roadCtrl;

  @override
  void initState() {
    super.initState();
    _roadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _roadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _roadCtrl,
      builder: (_, __) => CustomPaint(
        painter: _RoadPainter(progress: _roadCtrl.value),
        size: Size.infinite,
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  final double progress;
  _RoadPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const lineCount = 15;
    final spacing = size.width / lineCount;
    for (int i = 0; i < lineCount; i++) {
      final x = (i * spacing + (progress * spacing * 2)) % (size.width + spacing) - spacing / 2;
      canvas.drawLine(Offset(x, 0), Offset(x + spacing * 0.4, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.progress != progress;
}

// ──── Animated Dot ────
class _AnimatedDot extends StatefulWidget {
  final int i;
  final AnimationController controller;
  const _AnimatedDot({required this.i, required this.controller});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotCtrl,
      builder: (_, __) {
        final delay = widget.i * 0.15;
        final value = ((_dotCtrl.value - delay) % 1.0).abs();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2 + value * 0.8),
            ),
          ),
        );
      },
    );
  }
}
