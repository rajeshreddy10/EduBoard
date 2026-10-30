import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Clean typography definition with responsive scaling and GoogleFonts font family
class AppTypography {
  /// Resolved once at first use. `GoogleFonts.inter()` runs asset-registration
  /// logic every call; caching the resolved family name avoids repeating that
  /// work on each theme rebuild (a visible startup perf win).
  static final String _fontFamily = () {
    try {
      return GoogleFonts.inter().fontFamily ?? 'Roboto';
    } catch (_) {
      // Offline first-run fallback: GoogleFonts needs asset access; Roboto
      // ships with Android so text still renders correctly.
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
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface,
        fontSize: 15.0,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface.withValues(alpha: 0.85),
        fontSize: 14.0,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface.withValues(alpha: 0.65),
        fontSize: 12.0,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onPrimary,
        fontWeight: FontWeight.w600,
        fontSize: 14.0,
        letterSpacing: 0.2,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        color: colorScheme.onSurface.withValues(alpha: 0.7),
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
