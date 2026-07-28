import 'package:flutter/material.dart';
import '../../config/theme.dart';

class LoadingScreen extends StatelessWidget {
  final String? message;
  const LoadingScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(message!, style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
}
