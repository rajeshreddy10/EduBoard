import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../providers/notifications_provider.dart';
import '../widgets/notification_filter_chips.dart';
import '../widgets/notification_tile.dart';

/// Full notifications center screen with unread filters - 2026 Material Design 3
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = state.filteredItems;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            HapticFeedback.lightImpact();
            context.canPop() ? context.pop() : context.go('/dashboard');
          },
        ),
        title: Row(
          children: [
            Text(
              'Notifications',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.unreadCount} new',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              icon: const Icon(Icons.done_all_rounded, size: 16),
              label: const Text('Mark all read', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              onPressed: () {
                HapticFeedback.lightImpact();
                notifier.markAllAsRead();
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
              child: Column(
                children: [
                  const NotificationFilterChips(),
                  const SizedBox(height: 14),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.notifications_off_outlined,
                                    size: 48,
                                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'All Caught Up!',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'No pending notifications in this category.',
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              return NotificationTile(item: items[idx]);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
