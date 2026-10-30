import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/widgets/edu_image.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../models/history_item_model.dart';
import '../../../providers/history_provider.dart';

class RecentSessionsWidget extends ConsumerWidget {
  const RecentSessionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyItems = ref.watch(historyProvider.select((s) => s.allItems));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat.jm();

    if (historyItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            'No previous sessions recorded.',
            style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
        ),
      );
    }

    final recentItems = historyItems.take(3).toList();

    return Column(
      children: recentItems.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.08)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: _LeadingThumbnail(item: item),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: Row(
                children: [
                  Text(
                    timeFormat.format(item.modifiedAt),
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  AppStatusBadge(
                    label: item.category.name,
                    color: colorScheme.secondary,
                  ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: item.isFavorite ? Colors.amber : colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                onPressed: () {
                  ref.read(historyProvider.notifier).toggleFavorite(item.id);
                },
              ),
              onTap: () {
                // Open the REAL board record — the same id the tile shows.
                switch (item.category) {
                  case HistoryCategory.voiceSession:
                    context.push('/voiceboard?id=${Uri.encodeComponent(item.id)}');
                  case HistoryCategory.docAnnotation:
                    context.push('/doccanvas?id=${Uri.encodeComponent(item.id)}');
                  case HistoryCategory.whiteboard:
                  case HistoryCategory.all:
                    context.push('/drawspace?id=${Uri.encodeComponent(item.id)}');
                }
              },
            ),
          ),
        );
      }).toList(),
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
        radius: 20,
      );
    }

    return CircleAvatar(
      backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
      child: Icon(item.icon, color: colorScheme.primary, size: 20),
    );
  }
}
