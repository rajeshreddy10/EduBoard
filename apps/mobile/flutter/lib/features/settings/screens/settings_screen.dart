import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../core/widgets/edu_image.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/accessibility_toggles.dart';
import '../widgets/settings_group_card.dart';
import '../widgets/sync_status_card.dart';

/// System Settings & Accessibility
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: Text(
          'System Settings',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account Section
                  Text('Account', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: EduAvatar(
                            imageUrl: profile.avatarUrl,
                            name: profile.name,
                            radius: 20,
                          ),
                          title: Text(profile.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(profile.email),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/profile'),
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          leading: Icon(Icons.card_membership_rounded),
                          title: Text('Subscription Information', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('EduBoard Studio Pro'),
                          trailing: Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SettingsGroupCard(),
                  const SizedBox(height: 20),
                  const AccessibilityToggles(),
                  const SizedBox(height: 20),
                  const SyncStatusCard(),
                  const SizedBox(height: 32),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          AppConstants.appName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version ${AppConstants.appVersion}',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.4)),
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
