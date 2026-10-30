import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../models/history_item_model.dart';
import '../../../providers/whiteboard_provider.dart';
import '../../../providers/history_provider.dart';

/// Workspace Session History Hub - Mobile workspace management center
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
    (label: 'All Boards', category: HistoryCategory.all),
    (label: 'Whiteboards', category: HistoryCategory.whiteboard),
    (label: 'DocCanvas', category: HistoryCategory.docAnnotation),
    (label: 'Voice Sessions', category: HistoryCategory.voiceSession),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToSession(BuildContext context, HistoryItemModel item) {
    // Deep links carry the REAL board id: opening from History continues the
    // original record (same id, same content) instead of forking a new board.
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Session title',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              Navigator.pop(ctx);
              if (newTitle.isEmpty || newTitle == item.title) return;
              ref.read(historyProvider.notifier).saveItem(
                    item.copyWith(title: newTitle),
                  );
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Renamed to "$newTitle" — saved to cloud')),
              );
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _shareSession(BuildContext context, HistoryItemModel item) {
    // EduBoard board links align with the Web app deep-link convention.
    Clipboard.setData(ClipboardData(text: 'eduboard://board/${item.id}'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Board link copied — paste it in any chat to share')),
    );
  }

  void _duplicateSession(BuildContext context, HistoryItemModel item) {
    // Creates an independent copy (new id, same content) — mirrors the
    // Duplicate action in the Web history hub.
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
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Duplicate created: "${copy.title}"')),
    );
  }

  void _deleteSession(BuildContext context, HistoryItemModel item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text('"${item.title}" and all its cloud snapshots will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(historyProvider.notifier).deleteItem(item.id);
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted "${item.title}"')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSessionActions(BuildContext context, HistoryItemModel item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        // Scrollable so every action stays reachable on small screens
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 16),
              _ActionTile(Icons.open_in_new_rounded, 'Open Session', () {
                Navigator.pop(ctx);
                _navigateToSession(context, item);
              }),
              _ActionTile(Icons.edit_rounded, 'Rename Session', () {
                Navigator.pop(ctx);
                _renameSession(context, item);
              }),
              _ActionTile(Icons.share_rounded, 'Share (Copy Link)', () {
                Navigator.pop(ctx);
                _shareSession(context, item);
              }),
              _ActionTile(Icons.copy_rounded, 'Duplicate Session', () {
                Navigator.pop(ctx);
                _duplicateSession(context, item);
              }),
              _ActionTile(Icons.favorite_rounded, item.isFavorite ? 'Remove Favorite' : 'Mark Favorite', () {
                Navigator.pop(ctx);
                ref.read(historyProvider.notifier).toggleFavorite(item.id);
              }),
              _ActionTile(Icons.delete_rounded, 'Delete Session', () {
                Navigator.pop(ctx);
                _deleteSession(context, item);
              }, isDestructive: true),
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
    // Live search + category filter are wired to the provider state.
    final items = state.filteredItems;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        title: Text(
          'Workspace History Hub',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
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
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (q) => ref.read(historyProvider.notifier).setSearchQuery(q),
                      decoration: InputDecoration(
                        hintText: 'Search by board title...',
                        border: InputBorder.none,
                        icon: Icon(Icons.search_rounded, color: colorScheme.onSurface.withValues(alpha: 0.5)),
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
                  // Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_filters.length, (idx) {
                        final isSelected = _selectedFilter == idx;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedFilter = idx);
                              ref.read(historyProvider.notifier).setCategory(_filters[idx].category);
                              HapticFeedback.selectionClick();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.1)),
                              ),
                              child: Text(
                                _filters[idx].label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.folder_open_rounded, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                Text(
                                  state.selectedCategory == HistoryCategory.all
                                      ? 'No sessions found'
                                      : 'No ${state.selectedCategory.name} sessions found',
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text('Create a session in any studio to see it here', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5))),
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
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, idx) {
                                  final item = items[idx];
                                  return _SessionCardGrid(
                                    item: item,
                                    relativeTime: _getRelativeTime(item.modifiedAt),
                                    onTap: () => _navigateToSession(context, item),
                                    onMore: () => _showSessionActions(context, item),
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

  const _SessionCardGrid({required this.item, required this.relativeTime, required this.onTap, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [colorScheme.surface, colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
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
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: colorScheme.primary, size: 18),
                    ),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.more_vert_rounded, size: 18), onPressed: onMore),
                  ],
                ),
                const Spacer(),
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(item.summary, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(relativeTime, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Personal', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.green)),
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

  const _SessionCardList({required this.item, required this.relativeTime, required this.onTap, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${item.category.name} • $relativeTime', style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: onMore),
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
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionTile(this.icon, this.label, this.onTap, {this.isDestructive = false});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDestructive ? colorScheme.error : colorScheme.onSurface;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
