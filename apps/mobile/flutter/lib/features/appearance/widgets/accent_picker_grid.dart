import 'package:flutter/material.dart';
import '../../../core/theme/app_theme_types.dart';

/// Grid of the 9 requested accent colors with interactive selection
class AccentPickerGrid extends StatelessWidget {
  final EduAccentColor selectedAccent;
  final ValueChanged<EduAccentColor> onSelect;

  const AccentPickerGrid({
    super.key,
    required this.selectedAccent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: EduAccentColor.values.map((accent) {
        final isSelected = selectedAccent == accent;
        return GestureDetector(
          onTap: () => onSelect(accent),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: isSelected ? 3.0 : 0.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.color.withValues(alpha: isSelected ? 0.6 : 0.25),
                      blurRadius: isSelected ? 12 : 6,
                      spreadRadius: isSelected ? 2 : 0,
                    ),
                  ],
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                accent.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
