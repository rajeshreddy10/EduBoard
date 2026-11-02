import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/notification_item_model.dart';
import '../../../providers/notifications_provider.dart';

class NotificationTile extends ConsumerWidget {
  final NotificationItemModel item;

  const NotificationTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeFormat = DateFormat('h:mm a');

    final tileColor = item.isRead
        ? colorScheme.surface
        : colorScheme.primaryContainer.withValues(alpha: 0.25);
    final borderColor = item.isRead
        ? colorScheme.outlineVariant.withValues(alpha: 0.4)
        : colorScheme.primary.withValues(alpha: 0.3);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (!item.isRead) {
            HapticFeedback.selectionClick();
            ref.read(notificationProvider.notifier).markAsRead(item.id);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: tileColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.isRead
                        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                        : colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: item.isRead ? colorScheme.onSurfaceVariant : colorScheme.primary,
                  ),
                ),
                if (!item.isRead)
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.surface, width: 1.5),
                    ),
                  ),
              ],
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 13.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  timeFormat.format(item.timestamp),
                  style: TextStyle(fontSize: 10.5, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                item.message,
                style: TextStyle(
                  fontSize: 11.5,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.3,
                ),
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.4)),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(notificationProvider.notifier).deleteNotification(item.id);
              },
            ),
          ),
        ),
      ),
    );
  }
}
