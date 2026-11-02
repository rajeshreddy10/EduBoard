import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notification_item_model.dart';
import '../../../providers/notifications_provider.dart';

class NotificationFilterChips extends ConsumerWidget {
  const NotificationFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final notifier = ref.read(notificationProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: NotificationCategory.values.map((cat) {
          final isSelected = state.selectedCategory == cat;
          String label;
          IconData icon;
          switch (cat) {
            case NotificationCategory.all:
              label = 'All';
              icon = Icons.all_inbox_rounded;
              break;
            case NotificationCategory.system:
              label = 'System & Cloud';
              icon = Icons.cloud_outlined;
              break;
            case NotificationCategory.classrooms:
              label = 'Classrooms';
              icon = Icons.class_outlined;
              break;
            case NotificationCategory.mentions:
              label = 'Student Questions';
              icon = Icons.question_answer_outlined;
              break;
          }

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterChip(
              avatar: Icon(
                icon,
                size: 15,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              ),
              label: Text(label),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              ),
              selected: isSelected,
              showCheckmark: false,
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              selectedColor: colorScheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                notifier.setCategory(cat);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
