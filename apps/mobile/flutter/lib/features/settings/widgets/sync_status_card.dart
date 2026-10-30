import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../providers/settings_provider.dart';

class SyncStatusCard extends ConsumerWidget {
  const SyncStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat.jm();

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
              Icon(Icons.cloud_sync_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Offline Local Persistence',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const AppStatusBadge(label: 'HIVE ENGINE', isFilled: true),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Local Cache Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    'Last synced: ${timeFormat.format(settings.lastSyncTime)}',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: const Text('Sync Cache'),
                onPressed: () {
                  notifier.triggerSync();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hive local cache flushed and synchronized.')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Whiteboard strokes, theme tokens, teacher cues, and draggable notes are persisted offline in local Hive storage boxes.',
            style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ),
    );
  }
}
