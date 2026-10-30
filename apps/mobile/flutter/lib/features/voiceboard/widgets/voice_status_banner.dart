import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/voice_provider.dart';

/// Live status banner showing active recording duration, audio wave levels, and engine state
class VoiceStatusBanner extends ConsumerWidget {
  const VoiceStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(voiceProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(state.elapsed.inMinutes.remainder(60));
    final seconds = twoDigits(state.elapsed.inSeconds.remainder(60));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: state.isRecording ? colorScheme.error.withValues(alpha: 0.12) : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.isRecording ? colorScheme.error.withValues(alpha: 0.35) : colorScheme.onSurface.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: state.isRecording ? colorScheme.error : colorScheme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              state.isRecording ? Icons.mic : Icons.mic_none,
              size: 18,
              color: state.isRecording ? Colors.white : colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      state.isRecording ? 'LIVE DICTATION ACTIVE' : 'VOICE ENGINE READY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: state.isRecording ? colorScheme.error : colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    if (state.isRecording)
                      Text(
                        '$minutes:$seconds',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  state.statusMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
