import 'package:flutter/material.dart';

class AppTheme {
  // Primary Cybersecurity Theme Colors
  static const Color primary = Color(0xFF4F46E5); // Indigo primary
  static const Color primaryDark = Color(0xFF3730A3);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoDark = Color(0xFF3730A3);
  static const Color indigoLight = Color(0xFF818CF8);

  // Background and Surface
  static const Color lavenderBackground = Color(0xFFF8FAFC); // Clean neutral slate-50
  static const Color lavenderLight = Color(0xFFEEF2F6);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grayBackground = Color(0xFFF1F5F9);
  static const Color grayBorder = Color(0xFFCBD5E1);

  // Text Colors
  static const Color navyText = Color(0xFF0F172A); // Slate-900
  static const Color navyLight = Color(0xFF334155); // Slate-700
  static const Color mutedText = Color(0xFF64748B); // Slate-500

  // Status Colors
  static const Color teal = Color(0xFF0D9488);
  static const Color tealLight = Color(0xFFCCFBF1);
  static const Color green = Color(0xFF16A34A); // Success
  static const Color greenLight = Color(0xFFDCFCE7);
  static const Color amber = Color(0xFFD97706); // Warning
  static const Color amberLight = Color(0xFFFEF3C7);
  static const Color red = Color(0xFFDC2626); // Danger
  static const Color redLight = Color(0xFFFEE2E2);
  static const Color coral = Color(0xFFE11D48);
  static const Color coralLight = Color(0xFFFFE4E6);

  // Dark theme colors
  static const Color navy = Color(0xFF0F172A);
  static const Color navyDark = Color(0xFF020617);
  static const Color navyCard = Color(0xFF1E293B);

  static const String appFontFamily = 'Times New Roman';
  static const List<String> fontFallbacks = ['Times New Roman', 'Times', 'serif'];

  static const ColorScheme _lightColorScheme = ColorScheme.light(
    primary: primary,
    onPrimary: white,
    primaryContainer: primaryLight,
    onPrimaryContainer: navyText,
    secondary: teal,
    onSecondary: white,
    surface: white,
    onSurface: navyText,
    surfaceContainerHighest: lavenderBackground,
    onSurfaceVariant: mutedText,
    outline: grayBorder,
    error: red,
    onError: white,
  );

  static const ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: primaryLight,
    onPrimary: navyDark,
    primaryContainer: primaryDark,
    onPrimaryContainer: white,
    secondary: teal,
    onSecondary: navyDark,
    surface: navyCard,
    onSurface: white,
    surfaceContainerHighest: navy,
    onSurfaceVariant: Color(0xFF94A3B8),
    outline: Color(0xFF334155),
    error: red,
    onError: white,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: appFontFamily,
      fontFamilyFallback: fontFallbacks,
      colorScheme: _lightColorScheme,
      scaffoldBackgroundColor: lavenderBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: navyText,
        ),
        iconTheme: IconThemeData(color: navyText, size: 24),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: white,
        elevation: 2,
        indicatorColor: primaryLight.withValues(alpha: 0.25),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: appFontFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? primary : mutedText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? primary : mutedText,
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: grayBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: white,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: const BorderSide(color: primary, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: grayBorder, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: grayBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(
          fontFamily: appFontFamily,
          color: mutedText,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: grayBackground,
        labelStyle: const TextStyle(
          fontFamily: appFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: navyText,
        ),
        headlineMedium: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: navyText,
        ),
        headlineSmall: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: navyText,
        ),
        titleLarge: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: navyText,
        ),
        titleMedium: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: navyText,
        ),
        titleSmall: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: navyText,
        ),
        bodyLarge: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: navyLight,
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: navyLight,
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: mutedText,
          height: 1.3,
        ),
        labelLarge: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: navyText,
        ),
        labelMedium: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: mutedText,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: appFontFamily,
      fontFamilyFallback: fontFallbacks,
      colorScheme: _darkColorScheme,
      scaffoldBackgroundColor: navy,
      appBarTheme: const AppBarTheme(
        backgroundColor: navyCard,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: white,
        ),
        iconTheme: IconThemeData(color: white, size: 24),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navyCard,
        elevation: 2,
        indicatorColor: primaryDark,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: appFontFamily,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? primaryLight : const Color(0xFF94A3B8),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? primaryLight : const Color(0xFF94A3B8),
            size: 24,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: navyCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryLight,
          foregroundColor: navyDark,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          minimumSize: const Size(double.infinity, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: const BorderSide(color: primaryLight, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: const TextStyle(
            fontFamily: appFontFamily,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: white,
        ),
        headlineMedium: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: white,
        ),
        headlineSmall: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: white,
        ),
        titleLarge: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: white,
        ),
        titleMedium: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: white,
        ),
        titleSmall: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: white,
        ),
        bodyLarge: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: Color(0xFFE2E8F0),
          height: 1.4,
        ),
        bodyMedium: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFFE2E8F0),
          height: 1.4,
        ),
        bodySmall: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: Color(0xFF94A3B8),
          height: 1.3,
        ),
        labelLarge: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: white,
        ),
        labelMedium: TextStyle(
          fontFamily: appFontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}
