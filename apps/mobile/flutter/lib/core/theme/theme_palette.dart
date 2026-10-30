import 'package:flutter/material.dart';
import 'app_theme_types.dart';

/// Palette specifications and color generators for EduBoard themes
class ThemePalette {
  static ColorScheme buildColorScheme({
    required EduThemePreset preset,
    required EduAccentColor accent,
    required bool isDark,
  }) {
    final accentColor = accent.color;

    switch (preset) {
      case EduThemePreset.classicPaper:
        return isDark
            ? ColorScheme.dark(
                primary: accentColor,
                secondary: const Color(0xFFD4A373),
                surface: const Color(0xFF1E1B18),
                onPrimary: Colors.white,
                onSurface: const Color(0xFFF3ECE4),
                surfaceContainerHighest: const Color(0xFF2B2724),
              )
            : ColorScheme.light(
                primary: accentColor,
                secondary: const Color(0xFF8B5E3C),
                surface: const Color(0xFFFAF7F2),
                onPrimary: Colors.white,
                onSurface: const Color(0xFF2C241E),
                surfaceContainerHighest: const Color(0xFFEBE3D5),
              );

      case EduThemePreset.deepAurora:
        return isDark
            ? ColorScheme.dark(
                primary: accentColor,
                secondary: const Color(0xFF38BDF8),
                tertiary: const Color(0xFF34D399),
                surface: const Color(0xFF0F172A),
                onPrimary: Colors.white,
                onSurface: const Color(0xFFF1F5F9),
                surfaceContainerHighest: const Color(0xFF1E293B),
              )
            : ColorScheme.light(
                primary: accentColor,
                secondary: const Color(0xFF0284C7),
                tertiary: const Color(0xFF059669),
                surface: const Color(0xFFF0FDF4),
                onPrimary: Colors.white,
                onSurface: const Color(0xFF0F172A),
                surfaceContainerHighest: const Color(0xFFCFFAFE),
              );

      case EduThemePreset.midnightNavy:
        return isDark
            ? ColorScheme.dark(
                primary: accentColor,
                secondary: const Color(0xFF60A5FA),
                surface: const Color(0xFF0B132B),
                onPrimary: Colors.white,
                onSurface: const Color(0xFFE2E8F0),
                surfaceContainerHighest: const Color(0xFF1C2541),
              )
            : ColorScheme.light(
                primary: accentColor,
                secondary: const Color(0xFF2563EB),
                surface: const Color(0xFFF8FAFC),
                onPrimary: Colors.white,
                onSurface: const Color(0xFF1E293B),
                surfaceContainerHighest: const Color(0xFFE2E8F0),
              );

      case EduThemePreset.sunsetCrimson:
        return isDark
            ? ColorScheme.dark(
                primary: accentColor,
                secondary: const Color(0xFFFB923C),
                tertiary: const Color(0xFFF43F5E),
                surface: const Color(0xFF1C1318),
                onPrimary: Colors.white,
                onSurface: const Color(0xFFFDE8E8),
                surfaceContainerHighest: const Color(0xFF2D1E26),
              )
            : ColorScheme.light(
                primary: accentColor,
                secondary: const Color(0xFFEA580C),
                tertiary: const Color(0xFFE11D48),
                surface: const Color(0xFFFFF7ED),
                onPrimary: Colors.white,
                onSurface: const Color(0xFF291515),
                surfaceContainerHighest: const Color(0xFFFED7AA),
              );

      case EduThemePreset.emeraldForest:
        return isDark
            ? ColorScheme.dark(
                primary: accentColor,
                secondary: const Color(0xFF4ADE80),
                surface: const Color(0xFF0D1E16),
                onPrimary: Colors.white,
                onSurface: const Color(0xFFE6F4EA),
                surfaceContainerHighest: const Color(0xFF163225),
              )
            : ColorScheme.light(
                primary: accentColor,
                secondary: const Color(0xFF15803D),
                surface: const Color(0xFFF0FDF4),
                onPrimary: Colors.white,
                onSurface: const Color(0xFF142C1E),
                surfaceContainerHighest: const Color(0xFFBBF7D0),
              );

      case EduThemePreset.cyberNeon:
        return isDark
            ? ColorScheme.dark(
                primary: accentColor,
                secondary: const Color(0xFF00F0FF),
                tertiary: const Color(0xFFFF0055),
                surface: const Color(0xFF12121A),
                onPrimary: Colors.black,
                onSurface: const Color(0xFF00FFCC),
                surfaceContainerHighest: const Color(0xFF1F1F2E),
              )
            : ColorScheme.light(
                primary: accentColor,
                secondary: const Color(0xFF0891B2),
                surface: const Color(0xFFF5F3FF),
                onPrimary: Colors.white,
                onSurface: const Color(0xFF2E1065),
                surfaceContainerHighest: const Color(0xFFDDD6FE),
              );
    }
  }
}
