import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../core/widgets/edu_image.dart';
import '../../../providers/history_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../../providers/profile_provider.dart';

/// EduBoard Studio Dashboard - Premium modern workspace
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final historyItems = ref.watch(historyProvider.select((s) => s.allItems));
    final unreadNotifs = ref.watch(notificationProvider.select((s) => s.unreadCount));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final totalBoards = historyItems.length;
    final totalSeconds = historyItems.fold<int>(0, (sum, i) => sum + i.durationSeconds);
    final totalHoursStr = (totalSeconds / 3600).toStringAsFixed(1);

    final firstName = profile.name.trim().isNotEmpty
        ? profile.name.trim().split(RegExp(r'\s+')).first
        : 'Instructor';
    final greeting = _getGreeting();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Trigger refresh by invalidating providers
            ref.invalidate(historyProvider);
            ref.invalidate(profileProvider);
            ref.invalidate(notificationProvider);
            await Future.delayed(const Duration(milliseconds: 600));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with greeting, profile, icons, badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Profile picture
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      colorScheme.primary,
                                      colorScheme.tertiary,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colorScheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: EduAvatar(
                                  imageUrl: profile.avatarUrl,
                                  name: profile.name,
                                  radius: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$greeting, $firstName',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            colorScheme.primary.withValues(alpha: 0.15),
                                            colorScheme.tertiary.withValues(alpha: 0.15),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: colorScheme.primary.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        'EduBoard Studio v3.1',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: colorScheme.primary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Search',
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.search_rounded,
                                    color: colorScheme.onSurface,
                                    size: 20,
                                  ),
                                ),
                                onPressed: () {},
                              ),
                              IconButton(
                                tooltip: 'Notifications',
                                icon: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: colorScheme.onSurface.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Badge(
                                    isLabelVisible: unreadNotifs > 0,
                                    label: Text('$unreadNotifs'),
                                    child: Icon(
                                      Icons.notifications_outlined,
                                      color: colorScheme.onSurface,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                onPressed: () => context.push('/notifications'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Session Metrics
                          Text(
                            'Session Metrics',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Saved Sessions',
                                  value: '$totalBoards',
                                  icon: Icons.bookmark_rounded,
                                  gradientColors: [
                                    const Color(0xFF6366F1).withValues(alpha: 0.8),
                                    const Color(0xFF8B5CF6).withValues(alpha: 0.9),
                                  ],
                                  accentColor: const Color(0xFF6366F1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Active Studio Modules',
                                  value: '3',
                                  icon: Icons.widgets_rounded,
                                  gradientColors: [
                                    const Color(0xFF06B6D4).withValues(alpha: 0.8),
                                    const Color(0xFF3B82F6).withValues(alpha: 0.9),
                                  ],
                                  accentColor: const Color(0xFF06B6D4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: "Today's Resource Activity",
                                  value: '${totalHoursStr}h',
                                  icon: Icons.trending_up_rounded,
                                  gradientColors: [
                                    const Color(0xFF10B981).withValues(alpha: 0.8),
                                    const Color(0xFF34D399).withValues(alpha: 0.9),
                                  ],
                                  accentColor: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Core Studios
                          Text(
                            'Core Studios',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _StudioCard(
                            title: 'DrawSpace Whiteboard',
                            description: 'Interactive teaching canvas with teacher notes, progressive reveal, references, and drawing tools',
                            features: const ['Infinite Canvas', 'Layer Management', 'Real-time Sync'],
                            gradientColors: [
                              const Color(0xFF38BDF8).withValues(alpha: 0.9),
                              const Color(0xFF6366F1).withValues(alpha: 0.9),
                            ],
                            icon: Icons.gesture_rounded,
                            onTap: () => context.go('/normal-board'),
                          ),
                          const SizedBox(height: 12),
                          _StudioCard(
                            title: 'Voice Board AI',
                            description: 'Speech-to-text transcription, deduplication, voice controls, AI summaries',
                            features: const ['Live Transcription', 'AI Summaries', 'Voice Commands'],
                            gradientColors: [
                              const Color(0xFF34D399).withValues(alpha: 0.9),
                              const Color(0xFF10B981).withValues(alpha: 0.9),
                            ],
                            icon: Icons.mic_rounded,
                            onTap: () => context.go('/voice-control'),
                          ),
                          const SizedBox(height: 12),
                          _StudioCard(
                            title: 'DocCanvas Annotator',
                            description: 'PDF, Word, PPT annotation and markup with advanced tools',
                            features: const ['Multi-format', 'Smart Markup', 'Export Tools'],
                            gradientColors: [
                              const Color(0xFFF43F5E).withValues(alpha: 0.9),
                              const Color(0xFFEC4899).withValues(alpha: 0.9),
                            ],
                            icon: Icons.description_rounded,
                            onTap: () => context.push('/gesture-board'),
                          ),
                          const SizedBox(height: 28),
                          // Recent Sessions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Recent Sessions',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go('/dashboard/boards'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                ),
                                child: const Text(
                                  'View All',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const _RecentSessionsHorizontal(),
                          const SizedBox(height: 28),
                          // Quick Access Tools
                          Text(
                            'Quick Access Tools',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _QuickAccessGrid(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradientColors,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudioCard extends StatelessWidget {
  final String title;
  final String description;
  final List<String> features;
  final List<Color> gradientColors;
  final IconData icon;
  final VoidCallback onTap;

  const _StudioCard({
    required this.title,
    required this.description,
    required this.features,
    required this.gradientColors,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: gradientColors.first.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors.first.withValues(alpha: 0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: features
                    .map(
                      (f) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: gradientColors.first.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: gradientColors.first.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: gradientColors.first,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Open Studio',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSessionsHorizontal extends ConsumerWidget {
  const _RecentSessionsHorizontal();

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyItems = ref.watch(historyProvider.select((s) => s.allItems));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (historyItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No sessions yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start creating in any studio to see them here',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final recentItems = historyItems.take(5).toList();

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: recentItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = recentItems[index];
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (item.category.name.contains('whiteboard')) {
                  context.go('/drawspace');
                } else if (item.category.name.contains('voice')) {
                  context.go('/voiceboard');
                } else {
                  context.push('/doccanvas');
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.surface,
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
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
                          Text(
                            _formatRelativeTime(item.modifiedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.65),
                          height: 1.3,
                        ),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: (item.tags.take(2).toList())
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tag,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.secondary,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: colorScheme.primary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Resume',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickAccessGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final tools = [
      _ToolData(
        icon: Icons.history_rounded,
        label: 'Workspace History',
        color: const Color(0xFF6366F1),
        onTap: (context) => context.go('/history'),
      ),
      _ToolData(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        color: const Color(0xFFF59E0B),
        onTap: (context) => context.push('/notifications'),
      ),
      _ToolData(
        icon: Icons.person_rounded,
        label: 'Profile Settings',
        color: const Color(0xFF06B6D4),
        onTap: (context) => context.go('/profile'),
      ),
      _ToolData(
        icon: Icons.palette_rounded,
        label: 'Theme Studio',
        color: const Color(0xFFA855F7),
        onTap: (context) => context.push('/appearance'),
      ),
      _ToolData(
        icon: Icons.settings_rounded,
        label: 'System Settings',
        color: const Color(0xFF64748B),
        onTap: (context) => context.push('/settings'),
      ),
      _ToolData(
        icon: Icons.help_rounded,
        label: 'Help Center',
        color: const Color(0xFF10B981),
        onTap: (context) => context.push('/help'),
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.9,
      ),
      itemCount: tools.length,
      itemBuilder: (context, idx) {
        final tool = tools[idx];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => tool.onTap(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ],
                ),
                border: Border.all(
                  color: tool.color.withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tool.color.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tool.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tool.icon, color: tool.color, size: 24),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      tool.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToolData {
  final IconData icon;
  final String label;
  final Color color;
  final Function(BuildContext) onTap;

  _ToolData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
