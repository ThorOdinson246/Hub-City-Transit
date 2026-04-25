import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF000101);
  static const _background = Color(0xFFFAF9FC);
  static const _surfaceLow = Color(0xFFF5F3F7);
  static const _outline = Color(0xFFC5C6CA);
  static const _onSurfaceVariant = Color(0xFF44474A);

  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: _primary,
      secondary: Color(0xFF0061A4),
      surface: _background,
      onSurfaceVariant: _onSurfaceVariant,
      outlineVariant: _outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Plus Jakarta Sans',
      scaffoldBackgroundColor: _background,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _surfaceLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceLow,
        selectedColor: _primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        side: const BorderSide(color: _outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      textTheme: const TextTheme(
        displayMedium: TextStyle(fontSize: 56, height: 1.0, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(fontSize: 34, height: 1.15, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontSize: 28, height: 1.2, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(fontSize: 22, height: 1.2, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontFamily: 'Manrope', fontSize: 16, height: 1.4),
        bodyMedium: TextStyle(fontFamily: 'Manrope', fontSize: 14, height: 1.35),
        labelLarge: TextStyle(fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFFE2E2E5),
      secondary: Color(0xFF9FCAFF),
      surface: Color(0xFF1B1B1E),
      onSurfaceVariant: Color(0xFFC5C6CA),
      outlineVariant: Color(0xFF44474A),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Plus Jakarta Sans',
      scaffoldBackgroundColor: const Color(0xFF1B1B1E),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF303033),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}
