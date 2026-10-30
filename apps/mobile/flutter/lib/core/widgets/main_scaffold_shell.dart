import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/notifications_provider.dart';
import '../utilities/responsive_layout.dart';

/// Adaptive Shell with Material 3 NavigationBar, Tablet NavigationRail, and Quick Actions FAB
class MainScaffoldShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffoldShell({
    super.key,
    required this.navigationShell,
  });

  void _onItemTapped(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _openQuickActions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Start a new session in EduBoard Studio',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ActionTile(
                  icon: Icons.gesture_rounded,
                  title: 'New Whiteboard',
                  subtitle: 'Interactive teaching canvas with drawing tools',
                  colors: [const Color(0xFF38BDF8), const Color(0xFF6366F1)],
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/normal-board');
                  },
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.mic_rounded,
                  title: 'New Voice Session',
                  subtitle: 'Speech-to-text with AI transcription',
                  colors: [const Color(0xFF34D399), const Color(0xFF10B981)],
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/voice-control');
                  },
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.upload_file_rounded,
                  title: 'Upload Document',
                  subtitle: 'PDF, Word, PPT for annotation',
                  colors: [const Color(0xFFF43F5E), const Color(0xFFEC4899)],
                  onTap: () {
                    Navigator.pop(ctx);
                    context.push('/gesture-board');
                  },
                ),
                const SizedBox(height: 10),
                _ActionTile(
                  icon: Icons.import_export_rounded,
                  title: 'Import Lesson',
                  subtitle: 'Load existing lesson from library',
                  colors: [const Color(0xFFA855F7), const Color(0xFF8B5CF6)],
                  onTap: () {
                    Navigator.pop(ctx);
                    context.go('/dashboard/boards');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTablet = ResponsiveLayout.isTablet(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final unreadNotifs = ref.watch(notificationProvider.select((s) => s.unreadCount));

    // Branch 1 hosts the DrawSpace studio, whose floating bottom tool palette
    // would collide with the Quick Actions FAB — hide the FAB there.
    final onStudioBranch = navigationShell.currentIndex == 1;

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: 'Dashboard',
      ),
      const NavigationDestination(
        icon: Icon(Icons.auto_awesome_mosaic_outlined),
        selectedIcon: Icon(Icons.auto_awesome_mosaic_rounded),
        label: 'Studios',
      ),
      const NavigationDestination(
        icon: Icon(Icons.folder_outlined),
        selectedIcon: Icon(Icons.folder_rounded),
        label: 'Resources',
      ),
      const NavigationDestination(
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics_rounded),
        label: 'Analytics',
      ),
      NavigationDestination(
        icon: Badge(
          isLabelVisible: unreadNotifs > 0,
          label: Text('$unreadNotifs'),
          child: const Icon(Icons.person_outline_rounded),
        ),
        selectedIcon: Badge(
          isLabelVisible: unreadNotifs > 0,
          label: Text('$unreadNotifs'),
          child: const Icon(Icons.person_rounded),
        ),
        label: 'Profile',
      ),
    ];

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onItemTapped,
              labelType: NavigationRailLabelType.all,
              leading: onStudioBranch
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20.0),
                      child: FloatingActionButton(
                        elevation: 4,
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        onPressed: () => _openQuickActions(context),
                        child: const Icon(Icons.add_rounded, size: 28),
                      ),
                    ),
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onItemTapped,
          height: 70,
          elevation: 0,
          backgroundColor: colorScheme.surface,
          indicatorColor: colorScheme.primary.withValues(alpha: 0.15),
          destinations: destinations,
        ),
      ),
      floatingActionButton: onStudioBranch
          ? null
          : FloatingActionButton(
              elevation: 6,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: () => _openQuickActions(context),
              child: const Icon(Icons.add_rounded, size: 32),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
            ),
            border: Border.all(
              color: colors.first.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
