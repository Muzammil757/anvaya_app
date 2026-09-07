import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Central theme definition for ANVAYA.
///
/// Palette is inspired by the Indian tricolor (saffron + white + teal-green)
/// to keep the app instantly familiar and welcoming for Class 3 students
/// and teachers, while staying calm enough for long classroom sessions.
class AppTheme {
  AppTheme._();

  static const Color saffron = Color(0xFFFF9933);
  static const Color saffronDark = Color(0xFFE07C00);
  static const Color teal = Color(0xFF00796B);
  static const Color tealDark = Color(0xFF00504A);
  static const Color background = Color(0xFFFAFAF7);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1F2A2E);
  static const Color textSecondary = Color(0xFF5A6B6E);

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.poppinsTextTheme();

    final colorScheme = ColorScheme.fromSeed(
      seedColor: teal,
      primary: teal,
      secondary: saffron,
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
        backgroundColor: teal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 3,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: saffron,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: teal.withValues(alpha: 0.1),
        labelStyle: GoogleFonts.poppins(
          color: tealDark,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        side: BorderSide(color: teal.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      dividerTheme: DividerThemeData(
        color: textSecondary.withValues(alpha: 0.15),
        thickness: 1,
      ),
    );
  }
}
