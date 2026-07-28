import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'config/theme.dart';
import 'config/translations.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/declaration_provider.dart';
import 'providers/biometric_provider.dart';
import 'services/sync_service.dart';
import 'services/auth_service.dart';
import 'services/biometric_auth_service.dart';
import 'services/declaration_service.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final authService = AuthService();
  final declarationService = DeclarationService();
  final syncService = SyncService();
  final biometricAuthService = BiometricAuthService();

  final authProvider = AuthProvider(authService);
  final themeProvider = ThemeProvider();
  final declarationProvider = DeclarationProvider(declarationService);
  final biometricProvider = BiometricProvider(biometricAuthService);

  await authProvider.init();
  await themeProvider.init();
  await syncService.init();
  await biometricProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: declarationProvider),
        ChangeNotifierProvider.value(value: syncService),
        ChangeNotifierProvider.value(value: biometricProvider),
        Provider.value(value: declarationService),
        Provider.value(value: biometricAuthService),
        Provider.value(value: authService),
      ],
      child: const SmartFleetApp(),
    ),
  );
}

class SmartFleetApp extends StatelessWidget {
  const SmartFleetApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final authProv = context.watch<AuthProvider>();
    final bioProv = context.watch<BiometricProvider>();
    final router = createRouter(authProv, bioProv);

    return MaterialApp.router(
      title: Translations.t('app.title'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProv.themeMode,
      locale: Locale(themeProv.locale),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
