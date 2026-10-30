import 'package:flutter/material.dart';

class OnboardingPageData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

class OnboardingPageItem extends StatelessWidget {
  final OnboardingPageData data;

  const OnboardingPageItem({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: data.accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: data.accentColor.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: data.accentColor.withValues(alpha: 0.2),
                  blurRadius: 32,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              data.icon,
              size: 64,
              color: data.accentColor,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
