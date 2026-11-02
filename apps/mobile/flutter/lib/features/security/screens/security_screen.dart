import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utilities/responsive_layout.dart';
import '../../../providers/security_provider.dart';
import '../widgets/device_list_widget.dart';
import '../widgets/password_update_modal.dart';
import '../widgets/security_score_card.dart';

/// Full security and authentication controls screen - 2026 Material Design 3
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  void _openPasswordModal(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
          'Security & Biometrics',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: ResponsiveLayout.contentWidth(context)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SecurityScoreCard(),
                  const SizedBox(height: 20),

                  // Authentication Options Card
                  Container(
                    padding: const EdgeInsets.all(20),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.shield_outlined, size: 18, color: colorScheme.primary),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Authentication Safeguards',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Biometric Unlock', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: const Text('Unlock EduBoard canvas via fingerprint or face recognition', style: TextStyle(fontSize: 11)),
                          value: security.biometricsEnabled,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            notifier.toggleBiometrics(val);
                          },
                        ),
                        const Divider(height: 18),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Two-Factor Authentication (2FA)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: const Text('Require confirmation code when signing in on a new device', style: TextStyle(fontSize: 11)),
                          value: security.twoFactorEnabled,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            notifier.toggleTwoFactor(val);
                          },
                        ),
                        const Divider(height: 18),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.password_rounded, color: colorScheme.primary),
                          title: const Text('Update Master Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          subtitle: const Text('Recommended every 90 days for credential security', style: TextStyle(fontSize: 11)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => _openPasswordModal(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
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
