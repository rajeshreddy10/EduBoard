import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/edu_image.dart';
import '../../../models/history_item_model.dart';
import '../../../providers/history_provider.dart';

class HistoryListItem extends ConsumerWidget {
  final HistoryItemModel item;
  final VoidCallback onTap;

  const HistoryListItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat('MMM d, h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.08)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: _LeadingThumbnail(item: item),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                item.summary,
                style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    timeFormat.format(item.modifiedAt),
                    style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.45)),
                  ),
                  const SizedBox(width: 8),
                  AppStatusBadge(label: item.category.name, color: colorScheme.secondary),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: item.isFavorite ? Colors.amber : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                onPressed: () => ref.read(historyProvider.notifier).toggleFavorite(item.id),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error.withValues(alpha: 0.7)),
                onPressed: () => ref.read(historyProvider.notifier).deleteItem(item.id),
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Leading visual: board preview / session thumbnail when available
/// (Base64, Storage or http(s)), category icon otherwise.
class _LeadingThumbnail extends StatelessWidget {
  final HistoryItemModel item;

  const _LeadingThumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (item.thumbnailUrl != null && item.thumbnailUrl!.trim().isNotEmpty) {
      return EduAvatar(
        imageUrl: item.thumbnailUrl,
        name: item.title,
        radius: 22,
      );
    }

    return CircleAvatar(
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      child: Icon(item.icon, color: colorScheme.primary, size: 20),
    );
  }
}
