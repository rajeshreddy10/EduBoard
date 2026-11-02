import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    HapticFeedback.lightImpact();
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, idx) {
                    final opt = options[idx];
                    final isMatch = opt == selected;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Text(
                        opt,
                        style: TextStyle(
                          fontWeight: isMatch ? FontWeight.w800 : FontWeight.w500,
                          color: isMatch ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                      trailing: isMatch
                          ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                          : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onSelected(opt);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
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
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.public_rounded, size: 18, color: colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Localization & Region',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.language_rounded, color: colorScheme.onSurfaceVariant),
            title: const Text('Display Language', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(settings.language, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
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
            leading: Icon(Icons.schedule_rounded, color: colorScheme.onSurfaceVariant),
            title: const Text('Academic Time Zone', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(settings.timeZone, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
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
        ],
      ),
    );
  }
}
