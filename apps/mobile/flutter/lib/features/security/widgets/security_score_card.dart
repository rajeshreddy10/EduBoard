import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/security_provider.dart';

/// Security health score card with gauge indicator and 2026 Material 3 styling
class SecurityScoreCard extends ConsumerWidget {
  const SecurityScoreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color scoreColor;
    String scoreStatus;
    IconData statusIcon;
    if (security.securityScore >= 80) {
      scoreColor = const Color(0xFF10B981);
      scoreStatus = 'Optimal Security Health';
      statusIcon = Icons.verified_user_rounded;
    } else if (security.securityScore >= 60) {
      scoreColor = const Color(0xFFF59E0B);
      scoreStatus = 'Moderate Protection';
      statusIcon = Icons.info_outline_rounded;
    } else {
      scoreColor = const Color(0xFFEF4444);
      scoreStatus = 'Action Required';
      statusIcon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: scoreColor.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: security.securityScore / 100.0,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Text(
                '${security.securityScore}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: scoreColor,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Account Safeguard Score',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(statusIcon, size: 14, color: scoreColor),
                    const SizedBox(width: 5),
                    Text(
                      scoreStatus,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Biometrics enabled • 2FA safeguarded',
                  style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.55)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
