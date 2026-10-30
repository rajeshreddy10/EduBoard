import 'package:flutter/material.dart';
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
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.accessibility_new_rounded, size: 20, color: colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'Accessibility & Ergonomics',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('High Contrast Canvas Mode'),
            subtitle: const Text('Sharpen stroke outlines and contrast against background'),
            value: settings.highContrast,
            onChanged: notifier.toggleHighContrast,
          ),
          const Divider(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduced Motion'),
            subtitle: const Text('Disable micro-animations and smooth transition physics'),
            value: settings.reduceMotion,
            onChanged: notifier.toggleReduceMotion,
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Text Scale Factor: ', style: TextStyle(fontWeight: FontWeight.w600)),
              Text('${settings.textScaleFactor.toStringAsFixed(1)}x'),
            ],
          ),
          Slider(
            value: settings.textScaleFactor,
            min: 0.8,
            max: 1.5,
            divisions: 7,
            onChanged: notifier.setTextScale,
          ),
        ],
      ),
    );
  }
}
