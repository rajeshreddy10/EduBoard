import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/doccanvas_provider.dart';

/// Interactive focus magnifier lens.
/// Uses Flutter's native [RawMagnifier] to sample and magnify the actual rendered
/// document text, formulas, diagrams, and annotations underneath the lens.
/// Features draggable movement, tap-to-cycle magnification levels (1.5x, 2.0x, 2.5x, 3.0x),
/// and an inline close button.
class MagnifierOverlay extends ConsumerWidget {
  const MagnifierOverlay({super.key});

  static const double _lensSize = 140.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(docCanvasProvider);
    final notifier = ref.read(docCanvasProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    if (!state.isMagnifierActive) return const SizedBox.shrink();

    final left = state.magnifierPosition.dx - (_lensSize / 2);
    final top = state.magnifierPosition.dy - (_lensSize / 2);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onPanUpdate: (details) {
          notifier.setMagnifierPosition(state.magnifierPosition + details.delta);
        },
        child: SizedBox(
          width: _lensSize,
          height: _lensSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // 1. Native Hardware-Accelerated Magnifier Lens
              RawMagnifier(
                decoration: MagnifierDecoration(
                  shape: const CircleBorder(
                    side: BorderSide(color: Color(0xFFF43F5E), width: 3.0),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                size: const Size(_lensSize, _lensSize),
                magnificationScale: state.magnifierScale,
                focalPointOffset: Offset.zero,
              ),

              // 2. Center reticle crosshair indicator
              IgnorePointer(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // 3. Zoom Multiplier Pill Badge (Tap to toggle 1.5x -> 2.0x -> 2.5x -> 3.0x)
              Positioned(
                bottom: -12,
                child: GestureDetector(
                  onTap: () {
                    final nextScale = switch (state.magnifierScale) {
                      1.5 => 2.0,
                      2.0 => 2.5,
                      2.5 => 3.0,
                      _ => 1.5,
                    };
                    notifier.setMagnifierScale(nextScale);
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF43F5E),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${state.magnifierScale.toStringAsFixed(1)}x',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 4. Quick Close Button
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: () {
                    notifier.toggleMagnifier();
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
