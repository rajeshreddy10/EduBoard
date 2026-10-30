import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/voice_provider.dart';

/// Floating controls for Voice Board AI
class VoiceControlsOverlay extends ConsumerWidget {
  const VoiceControlsOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceProvider);
    final notifier = ref.read(voiceProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    final isRecording = state.isRecording;
    final isPaused = state.isPaused;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording) ...[
            IconButton(
              icon: const Icon(Icons.stop_rounded, size: 26),
              tooltip: 'Stop Listening',
              onPressed: () {
                notifier.stopListening();
                HapticFeedback.mediumImpact();
              },
              color: colorScheme.error,
            ),
            const SizedBox(width: 4),
          ],
          GestureDetector(
            onTap: () {
              if (!isRecording) {
                notifier.startListening();
              } else if (isPaused) {
                notifier.resumeListening();
              } else {
                notifier.pauseListening();
              }
              HapticFeedback.lightImpact();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isRecording && !isPaused
                      ? [const Color(0xFFEF4444), const Color(0xFFDC2626)]
                      : isRecording && isPaused
                          ? [const Color(0xFFF59E0B), const Color(0xFFEA580C)]
                          : [const Color(0xFF34D399), const Color(0xFF10B981)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isRecording && !isPaused
                            ? const Color(0xFFEF4444)
                            : isRecording && isPaused
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981))
                        .withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                !isRecording
                    ? Icons.mic_rounded
                    : isPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
          ),
          if (isRecording) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 26),
              tooltip: isPaused ? 'Resume Listening' : 'Pause Listening',
              onPressed: () {
                if (isPaused) {
                  notifier.resumeListening();
                } else {
                  notifier.pauseListening();
                }
                HapticFeedback.lightImpact();
              },
              color: colorScheme.onSurface,
            ),
          ],
        ],
      ),
    );
  }
}
