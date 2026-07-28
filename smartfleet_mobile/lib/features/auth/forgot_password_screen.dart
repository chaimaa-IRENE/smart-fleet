import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/app_sizes.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      // Simulate sending (backend endpoint: /api/users/forgot-password)
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _sent = true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.paddingXL),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset, size: 48, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text('Mot de passe oublié ?',
                      style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      )),
                  const SizedBox(height: 12),
                  Text(
                    'Saisissez votre adresse email pour recevoir un lien de réinitialisation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  if (!_sent) ...[
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email requis';
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _sendResetLink,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _sending
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Envoyer le lien', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle, size: 48, color: AppTheme.success),
                          const SizedBox(height: 12),
                          Text('Email envoyé !',
                              style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600,
                                color: AppTheme.success,
                              )),
                          const SizedBox(height: 8),
                          Text(
                            'Vérifiez votre boîte de réception pour réinitialiser votre mot de passe.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Retour à la connexion'),
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
