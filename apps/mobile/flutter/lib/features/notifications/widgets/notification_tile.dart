import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/notification_item_model.dart';
import '../../../providers/notifications_provider.dart';

class NotificationTile extends ConsumerWidget {
  final NotificationItemModel item;

  const NotificationTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat('h:mm a');

    final tileColor = item.isRead ? colorScheme.surface : colorScheme.primary.withValues(alpha: 0.06);
    final borderColor = item.isRead ? colorScheme.onSurface.withValues(alpha: 0.08) : colorScheme.primary.withValues(alpha: 0.25);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: tileColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            alignment: Alignment.topRight,
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                child: Icon(item.icon, size: 20, color: colorScheme.primary),
              ),
              if (!item.isRead)
                Container(
                  width: 10,
                  height: 10,
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
                    fontWeight: item.isRead ? FontWeight.w600 : FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                timeFormat.format(item.timestamp),
                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              item.message,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.75)),
            ),
          ),
          trailing: IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.4)),
            onPressed: () {
              ref.read(notificationProvider.notifier).deleteNotification(item.id);
            },
          ),
        ),
      ),
    );
  }
}
