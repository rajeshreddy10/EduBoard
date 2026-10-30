import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/security_provider.dart';

/// Security health score card with gauge indicator and status breakdown
class SecurityScoreCard extends ConsumerWidget {
  const SecurityScoreCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final security = ref.watch(securityProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color scoreColor;
    String scoreStatus;
    if (security.securityScore >= 80) {
      scoreColor = const Color(0xFF22C55E);
      scoreStatus = 'Excellent Protection';
    } else if (security.securityScore >= 60) {
      scoreColor = const Color(0xFFEAB308);
      scoreStatus = 'Moderate Protection';
    } else {
      scoreColor = const Color(0xFFEF4444);
      scoreStatus = 'Action Required';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
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
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  value: security.securityScore / 100.0,
                  strokeWidth: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                ),
              ),
              Text(
                '${security.securityScore}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scoreColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Health Score',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  scoreStatus,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Biometrics active • 2FA enabled on mobile',
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
