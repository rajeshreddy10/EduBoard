import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class QuickActionGrid extends StatelessWidget {
  const QuickActionGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final actions = [
      _ActionData(
        title: 'DrawSpace',
        desc: '60FPS Whiteboard',
        icon: Icons.gesture_rounded,
        color: const Color(0xFF38BDF8),
        onTap: () => context.go('/drawspace'),
      ),
      _ActionData(
        title: 'VoiceBoard',
        desc: 'Speech Dictation',
        icon: Icons.mic_rounded,
        color: const Color(0xFF34D399),
        onTap: () => context.go('/voiceboard'),
      ),
      _ActionData(
        title: 'DocCanvas',
        desc: 'PDF Annotation',
        icon: Icons.description_rounded,
        color: const Color(0xFFF43F5E),
        onTap: () => context.push('/doccanvas'),
      ),
      _ActionData(
        title: 'Themes',
        desc: '6 Dynamic Styles',
        icon: Icons.palette_outlined,
        color: const Color(0xFFA855F7),
        onTap: () => context.push('/appearance'),
      ),
    ];

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemCount: actions.length,
      itemBuilder: (context, idx) {
        final a = actions[idx];
        final isDark = theme.brightness == Brightness.dark;

        return Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          elevation: isDark ? 2 : 1,
          shadowColor: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.lightImpact();
              a.onTap();
            },
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: colorScheme.onSurface.withValues(alpha: isDark ? 0.09 : 0.07),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          a.color.withValues(alpha: isDark ? 0.25 : 0.16),
                          a.color.withValues(alpha: isDark ? 0.10 : 0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: a.color.withValues(alpha: 0.18),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(a.icon, color: a.color, size: 20),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        a.desc,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
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

class _ActionData {
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ActionData({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
