import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../models/history_item_model.dart';
import '../../../providers/whiteboard_provider.dart';
import '../../../providers/history_provider.dart';

/// Workspace Session History Hub - 2026 Material Design 3 Management Center
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _isGridView = true;
  int _selectedFilter = 0;
  final _searchController = TextEditingController();

  static const _filters = [
    (label: 'All Boards', category: HistoryCategory.all, icon: Icons.grid_view_rounded),
    (label: 'Whiteboards', category: HistoryCategory.whiteboard, icon: Icons.gesture_rounded),
    (label: 'DocCanvas', category: HistoryCategory.docAnnotation, icon: Icons.description_rounded),
    (label: 'Voice Boards', category: HistoryCategory.voiceSession, icon: Icons.mic_rounded),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToSession(BuildContext context, HistoryItemModel item) {
    HapticFeedback.lightImpact();
    switch (item.category) {
      case HistoryCategory.voiceSession:
        context.push('/voiceboard?id=${Uri.encodeComponent(item.id)}');
      case HistoryCategory.docAnnotation:
        context.push('/doccanvas?id=${Uri.encodeComponent(item.id)}');
      case HistoryCategory.whiteboard:
      case HistoryCategory.all:
        context.push('/drawspace?id=${Uri.encodeComponent(item.id)}');
    }
  }

  String _getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  void _renameSession(BuildContext context, HistoryItemModel item) {
    final controller = TextEditingController(text: item.title);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.edit_note_rounded, color: colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            const Text('Rename Board'),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Board Title',
            hintText: 'Enter new title',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              Navigator.pop(ctx);
              if (newTitle.isEmpty || newTitle == item.title) return;
              ref.read(historyProvider.notifier).saveItem(
                    item.copyWith(title: newTitle),
                  );
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Renamed to "$newTitle" — saved to cloud'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _shareSession(BuildContext context, HistoryItemModel item) {
    Clipboard.setData(ClipboardData(text: 'eduboard://board/${item.id}'));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Board link copied to clipboard'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _duplicateSession(BuildContext context, HistoryItemModel item) {
    final copy = item.copyWith(
      id: WhiteboardNotifier.mintBoardId(
        prefix: item.category == HistoryCategory.voiceSession
            ? 'voiceboard'
            : item.category == HistoryCategory.docAnnotation
                ? 'doccanvas'
                : 'drawspace',
      ),
      title: '${item.title} (Copy)',
      modifiedAt: DateTime.now(),
      isFavorite: false,
    );
    ref.read(historyProvider.notifier).saveItem(copy);
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Duplicate created: "${copy.title}"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _deleteSession(BuildContext context, HistoryItemModel item) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: colorScheme.error, size: 24),
            const SizedBox(width: 8),
            const Text('Delete Board?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item.title}"? This cannot be undone.',
          style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(historyProvider.notifier).deleteItem(item.id);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Deleted "${item.title}"'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSessionActions(BuildContext context, HistoryItemModel item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, color: colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${item.category.name} • ${_getRelativeTime(item.modifiedAt)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _ActionTile(
                icon: Icons.open_in_new_rounded,
                label: 'Open Board',
                subtitle: 'Continue editing and drawing',
                onTap: () {
                  Navigator.pop(ctx);
                  _navigateToSession(context, item);
                },
              ),
              _ActionTile(
                icon: Icons.edit_rounded,
                label: 'Rename Board',
                subtitle: 'Change title of this board',
                onTap: () {
                  Navigator.pop(ctx);
                  _renameSession(context, item);
                },
              ),
              _ActionTile(
                icon: Icons.share_rounded,
                label: 'Share Deep Link',
                subtitle: 'Copy link to clipboard',
                onTap: () {
                  Navigator.pop(ctx);
                  _shareSession(context, item);
                },
              ),
              _ActionTile(
                icon: Icons.copy_rounded,
                label: 'Duplicate Board',
                subtitle: 'Create an independent copy',
                onTap: () {
                  Navigator.pop(ctx);
                  _duplicateSession(context, item);
                },
              ),
              _ActionTile(
                icon: item.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                label: item.isFavorite ? 'Remove Favorite' : 'Add to Favorites',
                subtitle: item.isFavorite ? 'Unmark from starred boards' : 'Star for quick access',
                iconColor: item.isFavorite ? Colors.amber : null,
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(historyProvider.notifier).toggleFavorite(item.id);
                  HapticFeedback.selectionClick();
                },
              ),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete Board',
                subtitle: 'Permanently remove from workspace',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteSession(context, item);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final items = state.filteredItems;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        title: Text(
          'Workspace History Hub',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isGridView ? 'Switch to List' : 'Switch to Grid',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isGridView = !_isGridView);
            },
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Modern M3 Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (q) => ref.read(historyProvider.notifier).setSearchQuery(q),
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search boards by title or tag...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.search_rounded,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  setState(() => _searchController.clear());
                                  ref.read(historyProvider.notifier).setSearchQuery('');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Modern M3 Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: List.generate(_filters.length, (idx) {
                        final filter = _filters[idx];
                        final isSelected = _selectedFilter == idx;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            avatar: Icon(
                              filter.icon,
                              size: 16,
                              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                            ),
                            label: Text(filter.label),
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                            ),
                            backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            selectedColor: colorScheme.primary,
                            checkmarkColor: colorScheme.onPrimary,
                            showCheckmark: false,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            onSelected: (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedFilter = idx);
                              ref.read(historyProvider.notifier).setCategory(filter.category);
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Board List / Grid
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
                                    Icons.folder_open_rounded,
                                    size: 48,
                                    color: colorScheme.onSurface.withValues(alpha: 0.35),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  state.selectedCategory == HistoryCategory.all
                                      ? 'No Boards Found'
                                      : 'No ${state.selectedCategory.name} Boards Found',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Create a new board in any studio to see it here',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurface.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _isGridView
                            ? GridView.builder(
                                physics: const BouncingScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.88,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, idx) {
                                  final item = items[idx];
                                  return _SessionCardGrid(
                                    item: item,
                                    relativeTime: _getRelativeTime(item.modifiedAt),
                                    onTap: () => _navigateToSession(context, item),
                                    onMore: () => _showSessionActions(context, item),
                                    onToggleFavorite: () {
                                      HapticFeedback.selectionClick();
                                      ref.read(historyProvider.notifier).toggleFavorite(item.id);
                                    },
                                  );
                                },
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                itemCount: items.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, idx) {
                                  final item = items[idx];
                                  return _SessionCardList(
                                    item: item,
                                    relativeTime: _getRelativeTime(item.modifiedAt),
                                    onTap: () => _navigateToSession(context, item),
                                    onMore: () => _showSessionActions(context, item),
                                  );
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

class _SessionCardGrid extends StatelessWidget {
  final HistoryItemModel item;
  final String relativeTime;
  final VoidCallback onTap;
  final VoidCallback onMore;
  final VoidCallback onToggleFavorite;

  const _SessionCardGrid({
    required this.item,
    required this.relativeTime,
    required this.onTap,
    required this.onMore,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color categoryColor;
    switch (item.category) {
      case HistoryCategory.voiceSession:
        categoryColor = const Color(0xFF10B981);
        break;
      case HistoryCategory.docAnnotation:
        categoryColor = const Color(0xFFFB7185);
        break;
      case HistoryCategory.whiteboard:
      case HistoryCategory.all:
        categoryColor = const Color(0xFF6366F1);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: colorScheme.surface,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: categoryColor, size: 17),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        item.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 18,
                        color: item.isFavorite ? Colors.amber : colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                      onPressed: onToggleFavorite,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, size: 18),
                      onPressed: onMore,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      relativeTime,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category.name,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: categoryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionCardList extends StatelessWidget {
  final HistoryItemModel item;
  final String relativeTime;
  final VoidCallback onTap;
  final VoidCallback onMore;

  const _SessionCardList({
    required this.item,
    required this.relativeTime,
    required this.onTap,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color categoryColor;
    switch (item.category) {
      case HistoryCategory.voiceSession:
        categoryColor = const Color(0xFF10B981);
        break;
      case HistoryCategory.docAnnotation:
        categoryColor = const Color(0xFFFB7185);
        break;
      case HistoryCategory.whiteboard:
      case HistoryCategory.all:
        categoryColor = const Color(0xFF6366F1);
        break;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: categoryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          item.category.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: categoryColor,
                          ),
                        ),
                        Text(
                          ' • $relativeTime',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (item.isFavorite)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final Color? iconColor;

  const _ActionTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? colorScheme.error.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor ?? color, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
