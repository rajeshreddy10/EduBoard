import 'package:flutter/material.dart';

/// The 6 design themes requested for EduBoard
enum EduThemePreset {
  classicPaper,
  deepAurora,
  midnightNavy,
  sunsetCrimson,
  emeraldForest,
  cyberNeon;

  String get displayName {
    switch (this) {
      case EduThemePreset.classicPaper:
        return 'Classic Paper';
      case EduThemePreset.deepAurora:
        return 'Deep Aurora';
      case EduThemePreset.midnightNavy:
        return 'Midnight Navy';
      case EduThemePreset.sunsetCrimson:
        return 'Sunset Crimson';
      case EduThemePreset.emeraldForest:
        return 'Emerald Forest';
      case EduThemePreset.cyberNeon:
        return 'Cyber Neon';
    }
  }

  String get description {
    switch (this) {
      case EduThemePreset.classicPaper:
        return 'Parchment and ink tones for comfortable academic reading';
      case EduThemePreset.deepAurora:
        return 'Luminescent northern lights on dark polar night skies';
      case EduThemePreset.midnightNavy:
        return 'Deep indigo and sapphire for focused dark environments';
      case EduThemePreset.sunsetCrimson:
        return 'Warm amber, coral, and burgundy glow for evening sessions';
      case EduThemePreset.emeraldForest:
        return 'Rich botanic greens, jade, and earthy serene accents';
      case EduThemePreset.cyberNeon:
        return 'High contrast synthwave neon glow on obsidian canvas';
    }
  }
}

/// The 9 dynamic accent colors available across any theme
enum EduAccentColor {
  blue(Color(0xFF2563EB), 'Blue'),
  purple(Color(0xFF9333EA), 'Purple'),
  green(Color(0xFF16A34A), 'Green'),
  red(Color(0xFFDC2626), 'Red'),
  orange(Color(0xFFEA580C), 'Orange'),
  cyan(Color(0xFF0891B2), 'Cyan'),
  teal(Color(0xFF0D9488), 'Teal'),
  pink(Color(0xFFDB2777), 'Pink'),
  yellow(Color(0xFFCA8A04), 'Yellow');

  final Color color;
  final String label;
  const EduAccentColor(this.color, this.label);
}
