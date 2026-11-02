import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';

class AccessibilityToggles extends ConsumerWidget {
  const AccessibilityToggles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.accessibility_new_rounded, size: 18, color: colorScheme.secondary),
              ),
              const SizedBox(width: 10),
              Text(
                'Accessibility & Ergonomics',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('High Contrast Canvas Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text('Sharpen stroke outlines and contrast against background', style: TextStyle(fontSize: 11)),
            value: settings.highContrast,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              notifier.toggleHighContrast(val);
            },
          ),
          const Divider(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduced Motion', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: const Text('Disable micro-animations and smooth transition physics', style: TextStyle(fontSize: 11)),
            value: settings.reduceMotion,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              notifier.toggleReduceMotion(val);
            },
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Text Scale Factor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${settings.textScaleFactor.toStringAsFixed(1)}x',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colorScheme.primary,
              inactiveTrackColor: colorScheme.surfaceContainerHighest,
              thumbColor: colorScheme.primary,
              overlayColor: colorScheme.primary.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: settings.textScaleFactor,
              min: 0.8,
              max: 1.5,
              divisions: 7,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                notifier.setTextScale(val);
              },
            ),
          ),
        ],
      ),
    );
  }
}
