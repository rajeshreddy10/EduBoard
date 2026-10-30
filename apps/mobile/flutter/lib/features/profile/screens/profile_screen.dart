import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../widgets/academic_info_form.dart';
import '../widgets/avatar_picker_widget.dart';
import '../widgets/bio_section_widget.dart';

/// Full instructor profile screen with academic information, bio, and settings links
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Instructor Profile',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'App Settings',
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
              child: Column(
                children: [
                  const AvatarPickerWidget(),
                  const SizedBox(height: 16),
                  Text(
                    profile.name,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.email,
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  AppStatusBadge(label: profile.role, color: colorScheme.primary),
                  const SizedBox(height: 24),

                  // Settings Hub Navigation Card
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.security_rounded, color: colorScheme.primary),
                          title: const Text('Security & Biometrics', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Password, 2FA, authorized devices'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/profile/security'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.palette_outlined, color: colorScheme.secondary),
                          title: const Text('Themes & Appearance', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('6 dynamic themes, 9 color accents'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/dashboard/settings/theme'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.settings_outlined, color: colorScheme.tertiary),
                          title: const Text('General Settings', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Language, accessibility, offline sync'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  const AcademicInfoForm(),
                  const SizedBox(height: 20),
                  const BioSectionWidget(),
                  const SizedBox(height: 28),

                  // Sign Out
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text('Sign Out of Workspace'),
                    onPressed: () {
                      ref.read(authProvider.notifier).logout();
                      context.go('/login');
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
