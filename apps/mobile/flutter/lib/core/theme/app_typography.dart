import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean modern 2026 typography definition with Material Design 3 type scales
class AppTypography {
  static final String _fontFamily = () {
    try {
      return GoogleFonts.plusJakartaSans().fontFamily ??
          GoogleFonts.inter().fontFamily ??
          'Roboto';
    } catch (_) {
      return 'Roboto';
    }
  }();

  static TextTheme buildTextTheme(ColorScheme colorScheme) {
    final fontFamily = _fontFamily;
    const baseTheme = TextTheme();

    return baseTheme.copyWith(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.15,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.35,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.0,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 15.0,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface.withValues(alpha: 0.88),
        fontSize: 14.0,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface.withValues(alpha: 0.65),
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 14.0,
        letterSpacing: 0.1,
        height: 1.3,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface.withValues(alpha: 0.75),
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1.3,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface.withValues(alpha: 0.6),
        fontSize: 11.0,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        height: 1.25,
      ),
    );
  }
}
