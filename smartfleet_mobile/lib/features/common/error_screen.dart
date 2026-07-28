import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/translations.dart';

class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorScreen({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(Translations.t('common.retry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
