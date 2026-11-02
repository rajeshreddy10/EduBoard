import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../core/widgets/edu_image.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/accessibility_toggles.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/sync_status_card.dart';

/// System Settings & Accessibility - 2026 Material Design 3 Experience
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () {
            HapticFeedback.lightImpact();
            context.canPop() ? context.pop() : context.go('/dashboard');
          },
        ),
        title: Text(
          'System Settings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Account Section
                  Text(
                    'Workspace Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [colorScheme.primary, colorScheme.tertiary],
                              ),
                            ),
                            child: EduAvatar(
                              imageUrl: profile.avatarUrl,
                              name: profile.name,
                              radius: 22,
                            ),
                          ),
                          title: Text(
                            profile.name.isNotEmpty ? profile.name : 'EduBoard Instructor',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          subtitle: Text(
                            profile.email.isNotEmpty ? profile.email : 'Cloud Account',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/profile');
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.workspace_premium_rounded, color: colorScheme.primary, size: 20),
                          ),
                          title: const Text('Workspace Tier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: const Text('EduBoard Studio Pro (Unlimited Sync)', style: TextStyle(fontSize: 11)),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Localization & Timezone
                  const SettingsGroupCard(),
                  const SizedBox(height: 20),

                  // 3. Accessibility & Canvas Ergonomics
                  const AccessibilityToggles(),
                  const SizedBox(height: 20),

                  // 4. Persistence & Sync
                  const SyncStatusCard(),
                  const SizedBox(height: 32),

                  // 5. Version & Branding
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.school_rounded, size: 24, color: colorScheme.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface.withValues(alpha: 0.8),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version ${AppConstants.appVersion} • 2026 Material 3 Edition',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
