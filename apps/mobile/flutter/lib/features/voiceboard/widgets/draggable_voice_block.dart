import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/voice_block_model.dart';
import '../../../providers/voice_provider.dart';

/// Draggable transcribed speech card on VoiceBoard.
/// Supports moving, inline text editing, dynamic resizing (+/- width), and grouping.
class DraggableVoiceBlock extends ConsumerWidget {
  final VoiceBlockModel block;

  const DraggableVoiceBlock({super.key, required this.block});

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: block.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Spoken Card'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Edit transcribed lecture text...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(voiceProvider.notifier).editBlockText(block.id, controller.text.trim());
                HapticFeedback.lightImpact();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final notifier = ref.read(voiceProvider.notifier);

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final timeStr = '${twoDigits(block.timestamp.inMinutes)}:${twoDigits(block.timestamp.inSeconds.remainder(60))}';

    final cardContent = Container(
      width: block.width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: block.highlightColor.withValues(alpha: 0.45),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: block.highlightColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  block.speakerName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  timeStr,
                  style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(width: 4),
              // Edit Text Button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit_outlined, size: 16),
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                tooltip: 'Edit Card Text',
                onPressed: () => _showEditDialog(context, ref),
              ),
              const SizedBox(width: 4),
              // Delete Button
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 16),
                color: colorScheme.onSurface.withValues(alpha: 0.4),
                tooltip: 'Delete Card',
                onPressed: () {
                  notifier.deleteBlock(block.id);
                  HapticFeedback.lightImpact();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Content
          GestureDetector(
            onDoubleTap: () => _showEditDialog(context, ref),
            child: Text(
              block.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Footer with Confidence & Resize Handles
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 13, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                '${(block.confidence * 100).toInt()}% conf',
                style: TextStyle(fontSize: 10, color: colorScheme.primary, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // Width shrink handle
              GestureDetector(
                onTap: () {
                  notifier.resizeBlockWidth(block.id, -30);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.remove, size: 12),
                ),
              ),
              const SizedBox(width: 4),
              // Width expand handle
              GestureDetector(
                onTap: () {
                  notifier.resizeBlockWidth(block.id, 30);
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.add, size: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Positioned(
      left: block.position.dx,
      top: block.position.dy,
      child: Draggable<String>(
        data: block.id,
        feedback: Material(
          color: Colors.transparent,
          elevation: 6,
          child: Opacity(opacity: 0.85, child: cardContent),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: cardContent),
        onDragEnd: (details) {
          final renderBox = context.findRenderObject() as RenderBox?;
          final localOffset = renderBox != null
              ? renderBox.globalToLocal(details.offset)
              : details.offset;

          notifier.updateBlockPosition(
            block.id,
            Offset(localOffset.dx.clamp(10.0, 500.0), localOffset.dy.clamp(60.0, 700.0)),
          );
        },
        child: cardContent,
      ),
    );
  }
}
