import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../core/widgets/edu_image.dart';
import '../../../models/history_item_model.dart';
import '../../../providers/history_provider.dart';
import '../../../providers/notifications_provider.dart';
import '../../../providers/profile_provider.dart';

/// EduBoard Studio Dashboard - Premium 2026 Material Design 3 Workspace
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
          color: colorScheme.primary,
          backgroundColor: colorScheme.surfaceContainerHighest,
          onRefresh: () async {
            HapticFeedback.lightImpact();
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
                          // 1. Hero Header
                          _DashboardHeader(
                            greeting: greeting,
                            firstName: firstName,
                            avatarUrl: profile.avatarUrl,
                            fullName: profile.name,
                            unreadNotifs: unreadNotifs,
                          ),
                          const SizedBox(height: 24),

                          // 2. Metrics Section
                          Row(
                            children: [
                              Text(
                                'Workspace Activity',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Synced',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Saved Boards',
                                  value: '$totalBoards',
                                  icon: Icons.bookmark_rounded,
                                  gradientColors: const [
                                    Color(0xFF6366F1),
                                    Color(0xFF8B5CF6),
                                  ],
                                  accentColor: const Color(0xFF6366F1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Active Studios',
                                  value: '3',
                                  icon: Icons.layers_rounded,
                                  gradientColors: const [
                                    Color(0xFF06B6D4),
                                    Color(0xFF3B82F6),
                                  ],
                                  accentColor: const Color(0xFF06B6D4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Total Time',
                                  value: '${totalHoursStr}h',
                                  icon: Icons.timelapse_rounded,
                                  gradientColors: const [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                  ],
                                  accentColor: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // 3. Core Studios
                          Row(
                            children: [
                              Text(
                                'Core Creation Studios',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'M3 Engine',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _StudioCard(
                            title: 'DrawSpace Whiteboard',
                            description: 'Interactive infinite digital canvas with teacher cues, layers, real-time sync, and drawing instruments',
                            features: const ['Infinite Canvas', 'Layer Control', 'Real-time Sync'],
                            gradientColors: const [
                              Color(0xFF38BDF8),
                              Color(0xFF6366F1),
                            ],
                            icon: Icons.gesture_rounded,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.go('/normal-board');
                            },
                          ),
                          const SizedBox(height: 14),
                          _StudioCard(
                            title: 'Voice Board AI',
                            description: 'Speech-to-text live transcription, intelligent deduplication, voice commands, and AI lesson summaries',
                            features: const ['Live Speech-to-Text', 'AI Summaries', 'Voice Commands'],
                            gradientColors: const [
                              Color(0xFF34D399),
                              Color(0xFF10B981),
                            ],
                            icon: Icons.mic_rounded,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.go('/voice-control');
                            },
                          ),
                          const SizedBox(height: 14),
                          _StudioCard(
                            title: 'DocCanvas Annotator',
                            description: 'PDF, slide decks, and image markup studio with highlighters, pens, stamps, and instant exports',
                            features: const ['Document Import', 'Smart Highlighting', 'Export Ready'],
                            gradientColors: const [
                              Color(0xFFFB7185),
                              Color(0xFFE11D48),
                            ],
                            icon: Icons.description_rounded,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push('/gesture-board');
                            },
                          ),
                          const SizedBox(height: 28),

                          // 4. Recent Sessions
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
                              TextButton.icon(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  context.go('/dashboard/boards');
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                label: const Text(
                                  'View All',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const _RecentSessionsHorizontal(),
                          const SizedBox(height: 28),

                          // 5. Quick Access Tools
                          Text(
                            'Quick Access Tools',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 14),
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

class _DashboardHeader extends StatelessWidget {
  final String greeting;
  final String firstName;
  final String? avatarUrl;
  final String fullName;
  final int unreadNotifs;

  const _DashboardHeader({
    required this.greeting,
    required this.firstName,
    this.avatarUrl,
    required this.fullName,
    required this.unreadNotifs,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Profile picture with modern gradient border
        Container(
          width: 50,
          height: 50,
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
                color: colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.5),
          child: EduAvatar(
            imageUrl: avatarUrl,
            name: fullName,
            radius: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.12),
                          colorScheme.tertiary.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_rounded,
                          size: 11,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'EduBoard Studio 2026',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Notifications Button
        IconButton(
          tooltip: 'Notifications',
          style: IconButton.styleFrom(
            backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            padding: const EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          icon: Badge(
            isLabelVisible: unreadNotifs > 0,
            label: Text('$unreadNotifs'),
            backgroundColor: colorScheme.error,
            textColor: Colors.white,
            child: Icon(
              Icons.notifications_outlined,
              color: colorScheme.onSurface,
              size: 20,
            ),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.push('/notifications');
          },
        ),
      ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 12),
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
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.65),
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
    final primaryColor = gradientColors.first;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: colorScheme.surface,
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.28),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
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
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: features
                      .map(
                        (f) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Launch Studio',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ],
            ),
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
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No Saved Boards Yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Create or annotate on any studio above to see your history here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }

    final recentItems = historyItems.take(5).toList();

    return SizedBox(
      height: 205,
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
              },
              borderRadius: BorderRadius.circular(18),
              child: Ink(
                width: 270,
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
                            child: Icon(item.icon, color: colorScheme.primary, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category.name,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatRelativeTime(item.modifiedAt),
                            style: TextStyle(
                              fontSize: 10.5,
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
                      const SizedBox(height: 4),
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
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: colorScheme.primary, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Resume Session',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
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
        label: 'History Hub',
        color: const Color(0xFF6366F1),
        onTap: (context) {
          HapticFeedback.selectionClick();
          context.go('/history');
        },
      ),
      _ToolData(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        color: const Color(0xFFF59E0B),
        onTap: (context) {
          HapticFeedback.selectionClick();
          context.push('/notifications');
        },
      ),
      _ToolData(
        icon: Icons.person_rounded,
        label: 'My Profile',
        color: const Color(0xFF06B6D4),
        onTap: (context) {
          HapticFeedback.selectionClick();
          context.go('/profile');
        },
      ),
      _ToolData(
        icon: Icons.palette_rounded,
        label: 'Theme Studio',
        color: const Color(0xFFA855F7),
        onTap: (context) {
          HapticFeedback.selectionClick();
          context.push('/appearance');
        },
      ),
      _ToolData(
        icon: Icons.settings_rounded,
        label: 'Settings',
        color: const Color(0xFF64748B),
        onTap: (context) {
          HapticFeedback.selectionClick();
          context.push('/settings');
        },
      ),
      _ToolData(
        icon: Icons.help_outline_rounded,
        label: 'Help Center',
        color: const Color(0xFF10B981),
        onTap: (context) {
          HapticFeedback.selectionClick();
          context.push('/help');
        },
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: tools.length,
      itemBuilder: (context, idx) {
        final tool = tools[idx];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => tool.onTap(context),
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: colorScheme.surface,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: tool.color.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                    child: Icon(tool.icon, color: tool.color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      tool.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
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
