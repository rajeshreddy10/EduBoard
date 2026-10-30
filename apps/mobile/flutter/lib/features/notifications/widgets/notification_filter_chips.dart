import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notification_item_model.dart';
import '../../../providers/notifications_provider.dart';

class NotificationFilterChips extends ConsumerWidget {
  const NotificationFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: NotificationCategory.values.map((cat) {
          final isSelected = state.selectedCategory == cat;
          String label;
          switch (cat) {
            case NotificationCategory.all:
              label = 'All Notifications';
              break;
            case NotificationCategory.system:
              label = 'System & Cloud';
              break;
            case NotificationCategory.classrooms:
              label = 'Classrooms';
              break;
            case NotificationCategory.mentions:
              label = 'Student Questions';
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => notifier.setCategory(cat),
            ),
          );
        }).toList(),
      ),
    );
  }
}
