import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../providers/security_provider.dart';
import '../widgets/device_list_widget.dart';
import '../widgets/password_update_modal.dart';
import '../widgets/security_score_card.dart';

/// Full security and authentication controls screen
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  void _openPasswordModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const PasswordUpdateModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);
    final notifier = ref.read(securityProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: Text(
          'Security & Biometrics',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SecurityScoreCard(),
                  const SizedBox(height: 24),
                  // Authentication Options Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Authentication Safeguards',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 14),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Biometric Fingerprint / Face ID', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Unlock EduBoard canvas via device biometrics'),
                          value: security.biometricsEnabled,
                          onChanged: notifier.toggleBiometrics,
                        ),
                        const Divider(height: 18),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Two-Factor Authentication (2FA)', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Require TOTP / SMS code on new device sign-in'),
                          value: security.twoFactorEnabled,
                          onChanged: notifier.toggleTwoFactor,
                        ),
                        const Divider(height: 18),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.password_rounded, color: colorScheme.primary),
                          title: const Text('Update Master Password', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: const Text('Recommended every 90 days'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openPasswordModal(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const DeviceListWidget(),
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
