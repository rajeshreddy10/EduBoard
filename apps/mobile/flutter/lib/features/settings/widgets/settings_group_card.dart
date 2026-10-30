import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/settings_provider.dart';

class SettingsGroupCard extends ConsumerWidget {
  const SettingsGroupCard({super.key});

  void _showSelectorDialog({
    required BuildContext context,
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              final isMatch = opt == selected;
              return ListTile(
                title: Text(opt),
                trailing: isMatch ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                onTap: () {
                  onSelected(opt);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

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
              Icon(Icons.public_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Localization & Region',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language_rounded),
            title: const Text('Display Language'),
            subtitle: Text(settings.language),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showSelectorDialog(
              context: context,
              title: 'Select Language',
              options: ['English (US)', 'English (UK)', 'Spanish', 'French', 'German', 'Japanese', 'Mandarin'],
              selected: settings.language,
              onSelected: notifier.setLanguage,
            ),
          ),
          const Divider(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('Academic Time Zone'),
            subtitle: Text(settings.timeZone),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showSelectorDialog(
              context: context,
              title: 'Select Time Zone',
              options: [
                'UTC-08:00 (Pacific Time)',
                'UTC-05:00 (Eastern Time)',
                'UTC+00:00 (GMT/UTC)',
                'UTC+01:00 (Central European)',
                'UTC+05:30 (India Standard Time)',
                'UTC+09:00 (Tokyo Time)',
              ],
              selected: settings.timeZone,
              onSelected: notifier.setTimeZone,
            ),
          ),
          const Divider(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.map_rounded),
            title: const Text('Academic Region'),
            subtitle: Text(settings.region),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showSelectorDialog(
              context: context,
              title: 'Select Region',
              options: ['North America', 'Europe', 'Asia-Pacific', 'Latin America', 'Middle East & Africa'],
              selected: settings.region,
              onSelected: notifier.setRegion,
            ),
          ),
        ],
      ),
    );
  }
}
