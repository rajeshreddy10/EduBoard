import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Unified dark top bar for all EduBoard boards, matching the web interface.
/// Features back navigation, sparkles icon, title, status subtitle,
/// center action pills, and a primary blue Save button.
class BoardTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> centerActions;
  final VoidCallback? onSave;
  final bool isSaving;
  final bool isSaved;
  final VoidCallback? onBack;

  const BoardTopBar({
    super.key,
    required this.title,
    required this.subtitle,
    this.centerActions = const [],
    this.onSave,
    this.isSaving = false,
    this.isSaved = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF1E293B),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Left: Back Arrow + Sparkle + Title + Subtitle ─────────────────
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            tooltip: 'Back',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              if (onBack != null) {
                onBack!();
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          const SizedBox(width: 4),

          // Sparkle Icon (✦)
          const Icon(
            Icons.auto_awesome,
            color: Color(0xFF38BDF8),
            size: 16,
          ),
          const SizedBox(width: 6),

          // Title & Subtitle
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isSaving
                            ? const Color(0xFFF59E0B)
                            : (isSaved
                                ? const Color(0xFF10B981)
                                : const Color(0xFF3B82F6)),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSaving
                          ? 'SAVING...'
                          : (isSaved ? 'SAVED' : 'READY'),
                      style: TextStyle(
                        color: isSaving
                            ? const Color(0xFFF59E0B)
                            : (isSaved
                                ? const Color(0xFF10B981)
                                : const Color(0xFF94A3B8)),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Center: Action Pills (Horizontally scrollable for responsiveness)
          if (centerActions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: centerActions,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else ...[
            const Spacer(),
          ],

          // ── Right: Save Button ───────────────────────────────────────────
          if (onSave != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isSaving ? null : onSave,
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSaved
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: (isSaved ? const Color(0xFF059669) : const Color(0xFF2563EB)).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSaving)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      else
                        Icon(
                          isSaved ? Icons.check_circle_rounded : Icons.save_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        isSaving ? 'Saving' : (isSaved ? 'Saved' : 'Save'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

