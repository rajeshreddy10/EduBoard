import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/edu_image.dart';
import '../../../models/history_item_model.dart';
import '../../../providers/history_provider.dart';

class HistoryGridItem extends ConsumerWidget {
  final HistoryItemModel item;
  final VoidCallback onTap;

  const HistoryGridItem({
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
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _LeadingThumbnail(item: item),
                    Row(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 18,
                            color: item.isFavorite ? Colors.amber : colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          onPressed: () => ref.read(historyProvider.notifier).toggleFavorite(item.id),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: colorScheme.error.withValues(alpha: 0.7)),
                          onPressed: () => ref.read(historyProvider.notifier).deleteItem(item.id),
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  item.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                Text(
                  timeFormat.format(item.modifiedAt),
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.45)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Leading visual: shows the board preview / session thumbnail when the item
/// carries one (Base64, Storage or http(s)) through the crash-proof resolver,
/// otherwise falls back to the category icon. Never throws.
class _LeadingThumbnail extends StatelessWidget {
  final HistoryItemModel item;

  const _LeadingThumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (item.thumbnailUrl != null && item.thumbnailUrl!.trim().isNotEmpty) {
      return EduImage(
        source: item.thumbnailUrl,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        fallback: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(item.icon, size: 16, color: colorScheme.primary),
        ),
      );
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      child: Icon(item.icon, size: 16, color: colorScheme.primary),
    );
  }
}
