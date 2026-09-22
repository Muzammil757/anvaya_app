import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central theme definition for ANVAYA.
///
/// The platform shell uses a soft, pastel educational palette (mint, rose,
/// lavender, sky) over a near-white background, with a dark "Action Centre"
/// accent for the currently active learning unit.
class AppTheme {
  AppTheme._();

  // Legacy accents (still used by the Lecture / Q&A / Worksheet placeholder
  // screens) — kept unchanged so those screens keep compiling as-is.
  static const Color saffron = Color(0xFFFF9933);
  static const Color saffronDark = Color(0xFFE07C00);
  static const Color teal = Color(0xFF00796B);
  static const Color tealDark = Color(0xFF00504A);

  // Base surfaces.
  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E232E);
  static const Color textSecondary = Color(0xFF6B7280);

  // Pastel palette.
  static const Color mintContainer = Color(0xFFE9F7EF);
  static const Color mintAccent = Color(0xFF27AE60);

  static const Color roseContainer = Color(0xFFFDE8EC);
  static const Color roseAccent = Color(0xFFE91E63);

  static const Color lavenderContainer = Color(0xFFEFE9F9);
  static const Color lavenderAccent = Color(0xFF6C5CE7);

  static const Color skyContainer = Color(0xFFE1F5FE);
  static const Color skyAccent = Color(0xFF0288D1);

  static const Color actionCentreDark = Color(0xFF1E232E);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    final colorScheme = ColorScheme.fromSeed(
      seedColor: lavenderAccent,
      primary: lavenderAccent,
      secondary: mintAccent,
      surface: surface,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: baseTextTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shadowColor: textPrimary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mintAccent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lavenderContainer,
        labelStyle: GoogleFonts.plusJakartaSans(
          color: lavenderAccent,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: textSecondary.withValues(alpha: 0.12),
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 68,
        indicatorColor: lavenderContainer,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// A subtle ambient shadow for pastel containers built with [BoxDecoration]
  /// rather than the app-wide [CardTheme].
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: textPrimary.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
