import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hub City Transit — Design Token Reference
/// Light surface hierarchy (M3):
///   background   #FAF9FC
///   surface      #F5F3F7   (cards, tiles)
///   surfaceHigh  #ECEAF0   (pressed / selected)
///
/// Dark surface hierarchy:
///   background   #121214
///   surface      #1E1E22   (cards, tiles)
///   surfaceHigh  #2A2A30   (pressed / selected)

class AppColors {
  // Brand
  static const primary = Color(0xFF000101);
  static const primaryDark = Color(0xFFE2E2E5);

  // Light surfaces
  static const bgLight = Color(0xFFFAF9FC);
  static const surfaceLight = Color(0xFFF5F3F7);
  static const surfaceHighLight = Color(0xFFECEAF0);
  static const outlineLight = Color(0xFFC5C6CA);
  static const onSurfaceVariantLight = Color(0xFF44474A);

  // Dark surfaces
  static const bgDark = Color(0xFF121214);
  static const surfaceDark = Color(0xFF1E1E22);
  static const surfaceHighDark = Color(0xFF2A2A30);
  static const outlineDark = Color(0xFF3A3A42);
  static const onSurfaceVariantDark = Color(0xFFB0B0BA);
}

class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: Color(0xFF0061A4),
      onSecondary: Colors.white,
      surface: AppColors.bgLight,
      onSurface: Color(0xFF0D0D0F),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: AppColors.surfaceLight,
      surfaceContainer: AppColors.surfaceHighLight,
      onSurfaceVariant: AppColors.onSurfaceVariantLight,
      outline: AppColors.outlineLight,
      outlineVariant: AppColors.outlineLight,
      error: Color(0xFFBA1A1A),
      onError: Colors.white,
    );

    return _buildTheme(colorScheme, brightness: Brightness.light);
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: AppColors.primaryDark,
      onPrimary: Color(0xFF1A1A1E),
      secondary: Color(0xFF9FCAFF),
      onSecondary: Color(0xFF003259),
      surface: AppColors.bgDark,
      onSurface: Color(0xFFE8E8EC),
      surfaceContainerLowest: Color(0xFF0A0A0C),
      surfaceContainerLow: AppColors.surfaceDark,
      surfaceContainer: AppColors.surfaceHighDark,
      onSurfaceVariant: AppColors.onSurfaceVariantDark,
      outline: AppColors.outlineDark,
      outlineVariant: AppColors.outlineDark,
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
    );

    return _buildTheme(colorScheme, brightness: Brightness.dark);
  }

  static ThemeData _buildTheme(
    ColorScheme colorScheme, {
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Plus Jakarta Sans',
      scaffoldBackgroundColor: colorScheme.surface,

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 0.5,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.primary,
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.onSurfaceVariant,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        subtitleTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primary,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onPrimary, size: 22);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            );
          }
          return TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          );
        }),
        height: 68,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 4,
        dragHandleColor: colorScheme.outlineVariant,
        dragHandleSize: const Size(40, 4),
        showDragHandle: true,
      ),

      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 56,
          height: 1.0,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          height: 1.1,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
          letterSpacing: -0.5,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          height: 1.15,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          height: 1.2,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.3,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 16,
          height: 1.4,
          color: colorScheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          height: 1.35,
          color: colorScheme.onSurface,
        ),
        bodySmall: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          height: 1.3,
          color: colorScheme.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        labelMedium: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
        ),
        labelSmall: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
