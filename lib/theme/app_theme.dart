import 'package:flutter/material.dart';

class AppColors {
  static const pink = Color(0xFFFF4F8B);
  static const purple = Color(0xFF7C4DFF);
  static const orange = Color(0xFFFF9F1C);
  static const teal = Color(0xFF14B8A6);
  static const blue = Color(0xFF3B82F6);

  static const brandGradient = LinearGradient(
    colors: [Color(0xFFFF4F8B), Color(0xFF7C4DFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class Spacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.purple,
      brightness: b,
      secondary: AppColors.pink,
    );
    final isDark = b == Brightness.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: isDark ? const Color(0xFF14111F) : const Color(0xFFF7F4FF),
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF211D32) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF211D32) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: isDark ? const Color(0xFF1B1730) : Colors.white,
        indicatorColor: AppColors.purple.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
