import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/doc_annotation_model.dart';
import '../../../models/whiteboard_stroke_model.dart';
import '../../../providers/whiteboard_provider.dart';
import 'drawspace_painter.dart';

/// Interactive Canvas supporting Pan, Zoom, Pinch-to-zoom, Palm rejection, 60 FPS rendering
class DrawSpaceCanvas extends ConsumerStatefulWidget {
  const DrawSpaceCanvas({super.key});

  @override
  ConsumerState<DrawSpaceCanvas> createState() => _DrawSpaceCanvasState();
}

class _DrawSpaceCanvasState extends ConsumerState<DrawSpaceCanvas> {
  WhiteboardStroke? _activeStroke;
  Offset _lastFocalPoint = Offset.zero;
  Timer? _laserTimer;

  // Live transform values held locally while a pan/pinch gesture is running.
  // Committing every pointer sample into Riverpod forces the whole widget
  // tree to rebuild at input frequency (the root cause of "Skipped N/50"
  // frames while panning). We render from these locals during the gesture and
  // push the result into the provider exactly once on [ScaleEndDetails].
  bool _gestureActive = false;
  double _gestureStartScale = 1.0;
  double _gestureStartRotation = 0.0;
  double _liveScale = 1.0;
  double _liveRotation = 0.0;
  Offset _livePan = Offset.zero;

  void _onScaleStart(ScaleStartDetails details) {
    final state = ref.read(whiteboardProvider);
    _lastFocalPoint = details.localFocalPoint;

    // Multi-touch or pan/select/spotlight mode
    if (details.pointerCount > 1 || state.activeTool == WhiteboardTool.pan || state.activeTool == WhiteboardTool.selection) {
      _gestureActive = true;
      _gestureStartScale = state.scale;
      _gestureStartRotation = state.rotation;
      _liveScale = state.scale;
      _liveRotation = state.rotation;
      _livePan = state.panOffset;
      return;
    }

    if (state.activeTool == WhiteboardTool.laser) {
      ref.read(whiteboardProvider.notifier).setLaserPosition(details.localFocalPoint);
      HapticFeedback.lightImpact();
      return;
    }

    if (state.activeTool == WhiteboardTool.pointer) {
      ref.read(whiteboardProvider.notifier).setPointerPosition(details.localFocalPoint);
      HapticFeedback.selectionClick();
      return;
    }

    if (state.activeTool == WhiteboardTool.spotlight) {
      ref.read(whiteboardProvider.notifier).setSpotlightPosition(details.localFocalPoint);
      HapticFeedback.selectionClick();
      return;
    }

    if (state.activeTool == WhiteboardTool.text || state.activeTool == WhiteboardTool.selection) {
      // Check if tapping an existing text element
      WhiteboardTextElement? hitText;
      for (final t in state.textElements.reversed) {
        final dist = (t.position - details.localFocalPoint).distance;
        if (dist < 80) {
          hitText = t;
          break;
        }
      }
      if (hitText != null) {
        ref.read(whiteboardProvider.notifier).selectTextElement(hitText.id);
        _showAddTextModal(context, details.localFocalPoint, hitText);
        return;
      } else if (state.activeTool == WhiteboardTool.text) {
        _showAddTextModal(context, details.localFocalPoint);
        return;
      }
    }

    if (state.activeTool == WhiteboardTool.eraser) {
      HapticFeedback.selectionClick();
    }

    // Begin drawing stroke
    final point = StrokePoint(details.localFocalPoint.dx, details.localFocalPoint.dy);
    _activeStroke = WhiteboardStroke(
      id: 'stroke_${DateTime.now().millisecondsSinceEpoch}',
      points: [point],
      color: state.activeColor,
      strokeWidth: state.activeStrokeWidth,
      tool: state.activeTool,
      shapeType: state.activeTool == WhiteboardTool.shape ? state.activeShape : null,
    );
    setState(() {});
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final state = ref.read(whiteboardProvider);

    if (_gestureActive) {
      // Update live local transform — pinch to zoom, pan.
      // Scale/rotation from [ScaleUpdateDetails] are cumulative relative to
      // the gesture start, so they must be based against the start values,
      // not compounded onto the live ones.
      final delta = details.localFocalPoint - _lastFocalPoint;
      _lastFocalPoint = details.localFocalPoint;
      setState(() {
        _livePan += delta;
        _liveScale = (_gestureStartScale * details.scale).clamp(0.25, 6.0);
        _liveRotation = _gestureStartRotation + details.rotation * 0.1;
      });
      return;
    }

    if (state.activeTool == WhiteboardTool.laser) {
      ref.read(whiteboardProvider.notifier).setLaserPosition(details.localFocalPoint);
      return;
    }

    if (state.activeTool == WhiteboardTool.pointer) {
      ref.read(whiteboardProvider.notifier).setPointerPosition(details.localFocalPoint);
      return;
    }

    if (state.activeTool == WhiteboardTool.spotlight) {
      ref.read(whiteboardProvider.notifier).setSpotlightPosition(details.localFocalPoint);
      return;
    }

    if (_activeStroke != null) {
      final point = StrokePoint(details.localFocalPoint.dx, details.localFocalPoint.dy);
      setState(() {
        _activeStroke = _activeStroke!.copyWith(
          points: [..._activeStroke!.points, point],
        );
      });
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final state = ref.read(whiteboardProvider);

    if (_gestureActive) {
      _gestureActive = false;
      // Single commit into the provider per gesture instead of per pointer
      // sample — the heavy rebuild happens once, after the fingers lift.
      ref.read(whiteboardProvider.notifier).updateTransform(
            scale: _liveScale,
            panOffset: _livePan,
            rotation: _liveRotation,
          );
      return;
    }

    if (state.activeTool == WhiteboardTool.laser) {
      // Fade out after configured duration
      _laserTimer?.cancel();
      _laserTimer = Timer(Duration(seconds: state.laserDurationSeconds), () {
        if (mounted) {
          ref.read(whiteboardProvider.notifier).setLaserPosition(null);
        }
      });
    }

    if (state.activeTool == WhiteboardTool.pointer) {
      ref.read(whiteboardProvider.notifier).setPointerPosition(null);
    }

    if (_activeStroke != null) {
      ref.read(whiteboardProvider.notifier).addStroke(_activeStroke!);
      _activeStroke = null;
      setState(() {});
      HapticFeedback.mediumImpact();
    }
  }

  void _onDoubleTap() {
    ref.read(whiteboardProvider.notifier).resetTransform();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Canvas viewport reset (Zoom: 100%, Pan: 0, Rotation: 0°)'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  void _onLongPress() {
    // Quick modal cue for text
    final state = ref.read(whiteboardProvider);
    if (state.activeTool == WhiteboardTool.text) {
      _showAddTextModal(context, _lastFocalPoint);
    } else {
      _showAddTextModal(context, _lastFocalPoint);
    }
  }

  void _showAddTextModal(BuildContext context, [Offset? position, WhiteboardTextElement? existing]) {
    final textController = TextEditingController(text: existing?.text ?? '');
    final pos = position ?? existing?.position ?? _lastFocalPoint;
    bool isBold = existing?.isBold ?? false;
    bool isItalic = existing?.isItalic ?? false;
    bool isUnderline = existing?.isUnderline ?? false;
    double fontSize = existing?.fontSize ?? 20.0;
    TextAlign align = existing?.textAlign ?? TextAlign.left;
    Color textColor = existing?.color ?? ref.read(whiteboardProvider).activeColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Text(existing == null ? 'Add Text Card' : 'Edit Text Card'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    autofocus: true,
                    maxLines: 3,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                      fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
                      decoration: isUnderline ? TextDecoration.underline : TextDecoration.none,
                      color: textColor,
                    ),
                    textAlign: align,
                    decoration: const InputDecoration(
                      hintText: 'Enter text, formula, or note...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Formatting toolbar
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(Icons.format_bold_rounded, size: 20),
                        isSelected: isBold,
                        onPressed: () => setDialogState(() => isBold = !isBold),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.format_italic_rounded, size: 20),
                        isSelected: isItalic,
                        onPressed: () => setDialogState(() => isItalic = !isItalic),
                      ),
                      const SizedBox(width: 4),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.format_underlined_rounded, size: 20),
                        isSelected: isUnderline,
                        onPressed: () => setDialogState(() => isUnderline = !isUnderline),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.format_align_left_rounded, size: 20),
                        onPressed: () => setDialogState(() => align = TextAlign.left),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_align_center_rounded, size: 20),
                        onPressed: () => setDialogState(() => align = TextAlign.center),
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_align_right_rounded, size: 20),
                        onPressed: () => setDialogState(() => align = TextAlign.right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Font Size Slider
                  Row(
                    children: [
                      Text('Size: ${fontSize.toInt()} px', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 12.0,
                          max: 48.0,
                          divisions: 18,
                          onChanged: (v) => setDialogState(() => fontSize = v),
                        ),
                      ),
                    ],
                  ),
                  if (existing != null) ...[
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.rotate_left_rounded, size: 18),
                          label: const Text('-15°'),
                          onPressed: () {
                            ref.read(whiteboardProvider.notifier).rotateTextElement(existing.id, -0.2618);
                            Navigator.pop(ctx);
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.rotate_right_rounded, size: 18),
                          label: const Text('+15°'),
                          onPressed: () {
                            ref.read(whiteboardProvider.notifier).rotateTextElement(existing.id, 0.2618);
                            Navigator.pop(ctx);
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                          onPressed: () {
                            ref.read(whiteboardProvider.notifier).deleteTextElement(existing.id);
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final text = textController.text.trim();
                  if (text.isNotEmpty) {
                    if (existing == null) {
                      ref.read(whiteboardProvider.notifier).addTextElement(text, pos);
                    } else {
                      ref.read(whiteboardProvider.notifier).updateTextElement(
                            existing.id,
                            text: text,
                            fontSize: fontSize,
                            color: textColor,
                          );
                    }
                    HapticFeedback.lightImpact();
                  }
                  Navigator.pop(ctx);
                },
                child: Text(existing == null ? 'Place on Canvas' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _laserTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whiteboardProvider);

    // During an active pan/pinch gesture we render from the local live
    // transform (fast path, no Riverpod rebuilds); otherwise from state.
    final scale = _gestureActive ? _liveScale : state.scale;
    final panOffset = _gestureActive ? _livePan : state.panOffset;
    final rotation = _gestureActive ? _liveRotation : state.rotation;

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      onDoubleTap: _onDoubleTap,
      onLongPress: _onLongPress,
      behavior: HitTestBehavior.opaque,
      child: ClipRect(
        child: Transform(
          transform: Matrix4.identity()
            ..translateByDouble(panOffset.dx, panOffset.dy, 0.0, 1.0)
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..rotateZ(rotation),
          alignment: Alignment.center,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (state.referenceDocument != null && state.showDocOnCanvas)
                  Center(
                    child: _buildCanvasDocumentUnderlay(state.referenceDocument!),
                  ),
                CustomPaint(
                  size: Size.infinite,
                  painter: DrawSpacePainter(
                    strokes: state.strokes,
                    currentStroke: _activeStroke,
                    textElements: state.textElements,
                    laserPosition: state.laserPosition,
                    laserColor: state.laserColor,
                    spotlightPosition: state.spotlightPosition,
                    spotlightRadius: state.spotlightRadius,
                    revealFraction: state.revealFraction,
                    pointerPosition: state.pointerPosition,
                    pointerStyle: state.pointerStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasDocumentUnderlay(DocumentModel doc) {
    final ext = doc.fileType.toLowerCase();
    final isImage = ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg'].contains(ext);

    if (isImage) {
      Widget? imgWidget;
      if (doc.url != null && doc.url!.startsWith('data:image')) {
        try {
          final base64String = doc.url!.split(',').last;
          final bytes = base64Decode(base64String);
          imgWidget = Image.memory(bytes, fit: BoxFit.contain);
        } catch (_) {}
      } else if (doc.filePath != null && File(doc.filePath!).existsSync()) {
        imgWidget = Image.file(File(doc.filePath!), fit: BoxFit.contain);
      } else if (doc.url != null && doc.url!.startsWith('http')) {
        imgWidget = Image.network(doc.url!, fit: BoxFit.contain);
      }

      return Container(
        constraints: const BoxConstraints(maxWidth: 880, maxHeight: 680),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF131823),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: imgWidget ??
            Center(
              child: Text(doc.title, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ),
      );
    }

    // PDF, Text, or Academic Document Sheet on Canvas
    final isPdf = ext == 'pdf';
    return Container(
      width: 760,
      height: 940,
      margin: const EdgeInsets.all(32),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPdf ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
                      color: isPdf ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        ' • Academic Problem Set',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'Write & Solve on Sheet',
                  style: TextStyle(color: Color(0xFF6D28D9), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFFE2E8F0), height: 28),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.fileContent != null && doc.fileContent!.isNotEmpty
                        ? doc.fileContent!
                        : (doc.previewExcerpt.isNotEmpty
                            ? doc.previewExcerpt
                            : 'Solve problem statement and draw coordinates directly on this sheet.'),
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 13,
                      height: 1.5,
                      fontFamily: 'sans-serif',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 280,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Center(
                      child: Text(
                        'Canvas Work Area: Graph, Draw & Annotate with Pen',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'EduBoard Smart Whiteboard Canvas Layer',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w600),
              ),
              Text(
                'Page 1 of ',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
