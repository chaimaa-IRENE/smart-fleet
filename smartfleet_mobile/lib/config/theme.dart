import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF003DA5);
  static const Color secondary = Color(0xFF002776);
  static const Color accent = Color(0xFF00BCD4);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color danger = Color(0xFFF44336);
  static const Color background = Color(0xFFF0F2F5);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color danoneBlue = Color(0xFF003DA5);
  static const Color danoneLight = Color(0xFFE8F0FE);

  static List<Color> get primaryGradient => [primary, secondary];

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primary,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: danger,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: surface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade200,
      thickness: 1,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: primary,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF4A7CC9),
      secondary: Color(0xFF1565C0),
      surface: Color(0xFF1E1E1E),
      error: danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E1E1E),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4A7CC9),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

class AppColors {
  static const List<Color> chartColors = [
    Color(0xFF1A237E),
    Color(0xFF0D47A1),
    Color(0xFF00BCD4),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFF44336),
    Color(0xFF9C27B0),
    Color(0xFF607D8B),
  ];

  static Color statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'EN_ATTENTE':
        return AppTheme.warning;
      case 'EN_COURS':
      case 'EN_REPARATION':
        return AppTheme.warning;
      case 'EN_VALIDATION':
      case 'TRAITE':
        return const Color(0xFF9C27B0);
      case 'RETOURNEE':
        return const Color(0xFF795548);
      case 'REFUSE':
      case 'REJETEE':
      case 'BLOQUEE':
      case 'NON_REPAREE':
        return AppTheme.danger;
      case 'CLOTURE':
      case 'VALIDEE':
        return AppTheme.success;
      case 'PRISE_EN_CHARGE':
        return const Color(0xFF2196F3);
      case 'DETECTEE':
        return AppTheme.danger;
      case 'REPAREE':
        return Colors.blue;
      case 'ANNULEE':
        return Colors.grey;
      default:
        return AppTheme.textSecondary;
    }
  }
}
