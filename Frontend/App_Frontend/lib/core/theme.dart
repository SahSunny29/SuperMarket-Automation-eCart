import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens and theme system matching Google Stitch: "Cart-app-screens-final-design"
class AppTheme {
  // Core Brand Colors
  static const Color primary = Color(0xFFFF6400); // Solar Orange
  static const Color primaryHover = Color(0xFFE65100);
  static const Color primaryActive = Color(0xFFC43D00);
  static const Color primaryContainer = Color(0xFFFFF7ED);
  static const Color onPrimaryContainer = Color(0xFF9A3000);
  static const Color primarySubtle = Color(0xFFFFEDD5);

  // Secondary & Dark In-Store Surfaces
  static const Color secondary = Color(0xFF0F172A); // Slate 900
  static const Color inverseSurface = Color(0xFF0F172A);
  static const Color inverseSurfaceCard = Color(0xFF1E293B); // Trolley Sync Card
  static const Color onInverseSurface = Color(0xFFF8FAFC);

  // Semantic & Wayfinding Accents
  static const Color tertiary = Color(0xFF10B981); // Supermarket Emerald
  static const Color supermarketGreen = Color(0xFF10B981);
  static const Color supermarketGreenSubtle = Color(0xFFECFDF5);
  static const Color supermarketGreenBorder = Color(0xFFA7F3D0);

  static const Color wayfindingBlue = Color(0xFF0284C7);
  static const Color wayfindingBlueSubtle = Color(0xFFF0F9FF);

  static const Color offerAmber = Color(0xFFF59E0B);
  static const Color offerAmberSubtle = Color(0xFFFFFBEB);

  static const Color hazardError = Color(0xFFEF4444);
  static const Color hazardErrorSubtle = Color(0xFFFEF2F2);

  // Neutral & Outline Architecture
  static const Color neutral = Color(0xFF64748B);
  static const Color onSurfaceVariant = Color(0xFF64748B);
  static const Color onSurfaceMuted = Color(0xFF94A3B8);
  static const Color outline = Color(0xFFE2E8F0);
  static const Color outlineSubtle = Color(0xFFF1F5F9);
  static const Color outlineStrong = Color(0xFFCBD5E1);

  // Background & Surfaces
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF0F172A);
  static const Color onSurface = Color(0xFF0F172A);
  static const Color surfaceContainer = Color(0xFFF1F5F9);
  static const Color surfaceContainerLow = Color(0xFFF8FAFC);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0);

  // Border Radiuses
  static const double radiusXs = 4.0;
  static const double radiusSm = 6.0;
  static const double radiusDefault = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusPill = 9999.0;

  /// Generate ThemeData utilizing GoogleFonts.inter
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: Colors.white,
        tertiary: tertiary,
        onTertiary: Colors.white,
        error: hazardError,
        onError: Colors.white,
        errorContainer: hazardErrorSubtle,
        onErrorContainer: hazardError,
        surface: surface,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineStrong,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: onSurface,
          letterSpacing: -0.8,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.2,
        ),
        headlineSmall: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: onSurface,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: onSurface,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: neutral,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: secondary),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: secondary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: outline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: secondary,
          side: const BorderSide(color: outline, width: 1.5),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: hazardError),
        ),
        hintStyle: GoogleFonts.inter(
          color: onSurfaceMuted,
          fontSize: 14,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: neutral,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
