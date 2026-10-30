import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/whiteboard_stroke_model.dart';
import '../../../providers/whiteboard_provider.dart';

/// Floating dark bottom toolbar matching the web DrawSpace Canvas interface.
class ToolPalette extends ConsumerWidget {
  final VoidCallback onOpenStrokeSettings;
  final VoidCallback onToggleTeacherNotes;
  final VoidCallback? onClearCanvas;
  final VoidCallback? onTogglePresent;
  final bool isPresenting;

  const ToolPalette({
    super.key,
    required this.onOpenStrokeSettings,
    required this.onToggleTeacherNotes,
    this.onClearCanvas,
    this.onTogglePresent,
    this.isPresenting = false,
  });

  static const List<Color> _swatchColors = [
    Color(0xFFFFFFFF), // White
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFF10B981), // Green
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whiteboardProvider);
    final notifier = ref.read(whiteboardProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF131823),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFF262F40), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── 1. Pen Tool (Active in Blue Circle) ──────────────────────────
            _IconToolButton(
              icon: Icons.edit_rounded,
              tooltip: 'Pen Tool',
              isSelected: state.activeTool == WhiteboardTool.pen,
              selectedBgColor: const Color(0xFF3B82F6),
              onTap: () {
                notifier.setTool(WhiteboardTool.pen);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(width: 4),

            // ── 2. Eraser Tool ──────────────────────────────────────────────
            _IconToolButton(
              icon: Icons.cleaning_services_rounded,
              tooltip: 'Eraser',
              isSelected: state.activeTool == WhiteboardTool.eraser,
              onTap: () {
                notifier.setTool(WhiteboardTool.eraser);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(width: 4),

            // ── 3. Pointer / Cursor Tool ────────────────────────────────────
            _IconToolButton(
              icon: Icons.near_me_rounded,
              tooltip: 'Pointer',
              isSelected: state.activeTool == WhiteboardTool.pointer,
              onTap: () {
                notifier.setTool(WhiteboardTool.pointer);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(width: 4),

            // ── 4. Laser Pointer ⚡ ─────────────────────────────────────────
            _IconToolButton(
              icon: Icons.bolt_rounded,
              tooltip: 'Laser Pointer',
              isSelected: state.activeTool == WhiteboardTool.laser,
              onTap: () {
                notifier.setTool(WhiteboardTool.laser);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(width: 8),

            // ── 5. Color Swatches ───────────────────────────────────────────
            ..._swatchColors.map((color) {
              final isCurrent = state.activeColor.toARGB32() == color.toARGB32();
              return GestureDetector(
                onTap: () {
                  notifier.setColor(color);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(color: Colors.white, width: 2.2)
                        : Border.all(color: Colors.transparent, width: 1),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.6),
                              blurRadius: 6,
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }),
            const SizedBox(width: 8),

            // ── 6. Spotlight / Visibility 👁 ─────────────────────────────────
            _IconToolButton(
              icon: Icons.visibility_rounded,
              tooltip: 'Spotlight Focus',
              isSelected: state.activeTool == WhiteboardTool.spotlight,
              onTap: () {
                notifier.setTool(state.activeTool == WhiteboardTool.spotlight
                    ? WhiteboardTool.pen
                    : WhiteboardTool.spotlight);
                HapticFeedback.selectionClick();
              },
            ),
            const SizedBox(width: 4),

            // ── 7. Undo ─────────────────────────────────────────────────────
            _IconToolButton(
              icon: Icons.undo_rounded,
              tooltip: 'Undo',
              isSelected: false,
              isEnabled: state.strokes.isNotEmpty || state.textElements.isNotEmpty,
              onTap: () {
                notifier.undo();
                HapticFeedback.lightImpact();
              },
            ),
            const SizedBox(width: 4),

            // ── 8. Redo ─────────────────────────────────────────────────────
            _IconToolButton(
              icon: Icons.redo_rounded,
              tooltip: 'Redo',
              isSelected: false,
              isEnabled: state.undoneStrokes.isNotEmpty || state.undoneTextElements.isNotEmpty,
              onTap: () {
                notifier.redo();
                HapticFeedback.lightImpact();
              },
            ),
            const SizedBox(width: 4),

            // ── 9. Reset / Clear ↺ ──────────────────────────────────────────
            _IconToolButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Reset Canvas',
              isSelected: false,
              onTap: () {
                if (onClearCanvas != null) {
                  onClearCanvas!();
                } else {
                  notifier.clearCanvas();
                }
              },
            ),
            const SizedBox(width: 6),

            // ── 10. Present Button (Dark Pill with Expand Icon) ─────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (onTogglePresent != null) {
                    onTogglePresent!();
                  }
                  HapticFeedback.mediumImpact();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isPresenting
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPresenting
                          ? const Color(0xFF60A5FA)
                          : const Color(0xFF334155),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPresenting ? Icons.fullscreen_exit_rounded : Icons.open_in_full_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isPresenting ? 'Exit' : 'Present',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isSelected;
  final bool isEnabled;
  final Color? selectedBgColor;
  final VoidCallback onTap;

  const _IconToolButton({
    required this.icon,
    required this.tooltip,
    required this.isSelected,
    this.isEnabled = true,
    this.selectedBgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? (selectedBgColor ?? const Color(0xFF3B82F6))
                  : Colors.transparent,
            ),
            child: Icon(
              icon,
              size: 18,
              color: !isEnabled
                  ? const Color(0xFF475569)
                  : (isSelected ? Colors.white : const Color(0xFF94A3B8)),
            ),
          ),
        ),
      ),
    );
  }
}
