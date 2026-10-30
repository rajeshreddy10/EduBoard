import 'package:flutter/material.dart';

/// Status chips and pill badges for states, categories, and counters
class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;
  final bool isFilled;

  const AppStatusBadge({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.isFilled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isFilled ? badgeColor : badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFilled ? Colors.transparent : badgeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13,
              color: isFilled ? Colors.white : badgeColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isFilled ? Colors.white : badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}
