import 'package:flutter/material.dart';
import '../../../core/theme/app_theme_types.dart';

/// Card showing preview swatches and description for a theme preset
class ThemePresetCard extends StatelessWidget {
  final EduThemePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemePresetCard({
    super.key,
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  List<Color> get _swatches {
    switch (preset) {
      case EduThemePreset.classicPaper:
        return const [Color(0xFFF4EFE6), Color(0xFFD4A373), Color(0xFF2C241E)];
      case EduThemePreset.deepAurora:
        return const [Color(0xFF0F172A), Color(0xFF38BDF8), Color(0xFF34D399)];
      case EduThemePreset.midnightNavy:
        return const [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF60A5FA)];
      case EduThemePreset.sunsetCrimson:
        return const [Color(0xFF1C1318), Color(0xFFFB923C), Color(0xFFF43F5E)];
      case EduThemePreset.emeraldForest:
        return const [Color(0xFF0D1E16), Color(0xFF163225), Color(0xFF4ADE80)];
      case EduThemePreset.cyberNeon:
        return const [Color(0xFF12121A), Color(0xFF00F0FF), Color(0xFFFF0055)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.08),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Color Swatches
                Row(
                  children: _swatches.map((c) {
                    return Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: colorScheme.primary, size: 22)
                else
                  Icon(Icons.radio_button_unchecked_rounded, color: colorScheme.onSurface.withValues(alpha: 0.3), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
