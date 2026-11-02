import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    final isDark = theme.brightness == Brightness.dark;

    if (historyItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 20.0),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: isDark ? 0.09 : 0.07),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.history_edu_rounded, size: 32, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'No previous sessions recorded',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create a new whiteboard, voice, or document session to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Start First Board'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                context.go('/normal-board');
              },
            ),
          ],
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
            elevation: isDark ? 2 : 1,
            shadowColor: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colorScheme.onSurface.withValues(alpha: isDark ? 0.09 : 0.07)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: _LeadingThumbnail(item: item),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, letterSpacing: -0.2),
              ),
              subtitle: Row(
                children: [
                  Text(
                    timeFormat.format(item.modifiedAt),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(width: 8),
                  AppStatusBadge(
                    label: item.category.name,
                    color: item.category == HistoryCategory.voiceSession
                        ? const Color(0xFF10B981)
                        : (item.category == HistoryCategory.docAnnotation
                            ? const Color(0xFFF43F5E)
                            : colorScheme.primary),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(
                  item.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: item.isFavorite ? Colors.amber : colorScheme.onSurface.withValues(alpha: 0.35),
                  size: 22,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref.read(historyProvider.notifier).toggleFavorite(item.id);
                },
              ),
              onTap: () {
                HapticFeedback.lightImpact();
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
