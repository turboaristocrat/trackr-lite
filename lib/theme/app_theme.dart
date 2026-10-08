import 'package:flutter/material.dart';

class AppTheme {
  // Stitch Design System: Field Utility & Industrial Ergonomics (matching TRACKR)
  static const Color background = Color(0xFFF8F9FB); // Anti-glare technical canvas
  static const Color surface = Color(0xFFF8F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // Pure White Cards
  static const Color surfaceContainerLow = Color(0xFFF3F4F6);
  static const Color surfaceContainer = Color(0xFFEDEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE7E8EA);
  static const Color cardBg = Color(0xFFFFFFFF);
  
  // High-Impact Carbon Graphite
  static const Color primary = Color(0xFF111418);
  static const Color primaryContainer = Color(0xFF191C20);
  static const Color onPrimaryContainer = Color(0xFF818489);

  // Railway Signal Amber / Caution Yellow
  static const Color secondary = Color(0xFF805600);
  static const Color secondaryContainer = Color(0xFFFDB324); // Signal Amber
  static const Color amberAccent = Color(0xFFFDB324);

  // Rail Safety Green
  static const Color tertiary = Color(0xFF0D8050);
  static const Color railSafetyGreen = Color(0xFF0D8050);
  static const Color greenAction = Color(0xFF0D8050);

  // Hazard & Error
  static const Color redDanger = Color(0xFFBA1A1A);
  static const Color error = Color(0xFFBA1A1A);

  // Typography & Outline
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF45474A);
  static const Color textPrimary = Color(0xFF191C1E);
  static const Color textSecondary = Color(0xFF45474A);
  static const Color textMuted = Color(0xFF75777B);
  static const Color outline = Color(0xFF75777B);
  static const Color outlineVariant = Color(0xFFC5C6CB);
  static const Color borderColor = Color(0xFFE2E5EA);

  // Messaging platforms
  static const Color telegramBlue = Color(0xFF0088CC);
  static const Color whatsAppGreen = Color(0xFF25D366);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondaryContainer,
        surface: surface,
        surfaceContainerHighest: surfaceContainerHigh,
        onPrimary: Colors.white,
        onSurface: onSurface,
        error: error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: borderColor,
            width: 1,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceContainerLowest,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          side: BorderSide(color: borderColor, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceContainerLow,
        labelStyle: const TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
        ),
        side: const BorderSide(color: borderColor, width: 0.8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderColor, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13.5),
        hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.7), fontSize: 13.5),
        prefixIconColor: textSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceContainerLowest,
        elevation: 0,
        indicatorColor: primary.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: textSecondary, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary);
          }
          return const IconThemeData(color: textSecondary);
        }),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
