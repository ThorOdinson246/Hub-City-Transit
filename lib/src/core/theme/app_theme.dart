import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF111827),
      secondary: Color(0xFF2563EB),
      surface: Color(0xFFF4F5F9),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF4F5F9),
      navigationBarTheme: const NavigationBarThemeData(
        indicatorColor: Colors.black,
      ),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFFF9FAFB),
      secondary: Color(0xFF60A5FA),
      surface: Color(0xFF111827),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0B1220),
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: const CardThemeData(elevation: 0, color: Color(0xFF111827)),
    );
  }
}
