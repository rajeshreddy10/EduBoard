import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/history_item_model.dart';
import '../../../providers/history_provider.dart';

/// Search input bar, category filter chips, and grid/list layout mode toggle
class HistoryFilterBar extends ConsumerWidget {
  const HistoryFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyProvider);
    final notifier = ref.read(historyProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        // Search & View Toggle Row
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: notifier.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search sessions, topics, tags...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: Icon(state.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
              tooltip: state.isGridView ? 'Switch to List View' : 'Switch to Grid View',
              onPressed: notifier.toggleViewMode,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: HistoryCategory.values.map((cat) {
              final isSelected = state.selectedCategory == cat;
              String label;
              switch (cat) {
                case HistoryCategory.all:
                  label = 'All Sessions';
                  break;
                case HistoryCategory.whiteboard:
                  label = 'Whiteboards';
                  break;
                case HistoryCategory.docAnnotation:
                  label = 'Doc Annotations';
                  break;
                case HistoryCategory.voiceSession:
                  label = 'Voice Recordings';
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
        ),
      ],
    );
  }
}
