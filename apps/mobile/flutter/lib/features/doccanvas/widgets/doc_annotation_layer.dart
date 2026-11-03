import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/doc_annotation_model.dart';
import '../../../providers/doccanvas_provider.dart';

/// Interactive overlay layer that renders and records pen drawings, highlights,
/// and provides real-time interactive erasing on top of the document canvas.
class DocAnnotationLayer extends ConsumerStatefulWidget {
  const DocAnnotationLayer({super.key});

  @override
  ConsumerState<DocAnnotationLayer> createState() => _DocAnnotationLayerState();
}

class _DocAnnotationLayerState extends ConsumerState<DocAnnotationLayer> {
  final List<Offset> _activePoints = [];
  Offset? _dragStart;
  Offset? _dragCurrent;

  void _handleEraserAt(Offset localPos) {
    final state = ref.read(docCanvasProvider);
    final pageAnnotations = state.annotations.where((a) => a.pageIndex == state.currentPageIndex).toList();

    for (final a in pageAnnotations) {
      bool shouldDelete = false;

      if (a.points != null && a.points!.isNotEmpty) {
        for (final pt in a.points!) {
          if ((pt - localPos).distance <= 24.0) {
            shouldDelete = true;
            break;
          }
        }
      } else if (a.boundingBox != null) {
        if (a.boundingBox!.inflate(12.0).contains(localPos)) {
          shouldDelete = true;
        }
      }

      if (shouldDelete) {
        ref.read(docCanvasProvider.notifier).deleteAnnotation(a.id);
        HapticFeedback.selectionClick();
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(docCanvasProvider);
    final tool = state.activeAnnotationTool;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        if (tool == DocAnnotationType.eraser) {
          _handleEraserAt(details.localPosition);
          return;
        }

        setState(() {
          _dragStart = details.localPosition;
          _dragCurrent = details.localPosition;
          _activePoints.clear();
          _activePoints.add(details.localPosition);
        });
      },
      onPanUpdate: (details) {
        if (tool == DocAnnotationType.eraser) {
          _handleEraserAt(details.localPosition);
          return;
        }

        setState(() {
          _dragCurrent = details.localPosition;
          _activePoints.add(details.localPosition);
        });
      },
      onPanEnd: (details) {
        if (tool == DocAnnotationType.eraser) return;

        if (_activePoints.length >= 2) {
          final isHighlight = tool == DocAnnotationType.highlight;
          final color = isHighlight
              ? state.activeHighlighterColor.withValues(alpha: 0.38)
              : state.activeHighlighterColor;

          final annotation = DocAnnotationModel(
            id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
            pageIndex: state.currentPageIndex,
            type: isHighlight ? DocAnnotationType.highlight : DocAnnotationType.pen,
            points: List.from(_activePoints),
            color: color,
            strokeWidth: isHighlight ? 20.0 : 3.5,
            createdAt: DateTime.now(),
          );
          ref.read(docCanvasProvider.notifier).addAnnotation(annotation);
          HapticFeedback.lightImpact();
        } else if (_dragStart != null && _dragCurrent != null && tool == DocAnnotationType.highlight) {
          final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
          if (rect.width > 10 || rect.height > 10) {
            final annotation = DocAnnotationModel(
              id: 'box_${DateTime.now().millisecondsSinceEpoch}',
              pageIndex: state.currentPageIndex,
              type: DocAnnotationType.highlight,
              boundingBox: rect,
              color: state.activeHighlighterColor.withValues(alpha: 0.35),
              createdAt: DateTime.now(),
            );
            ref.read(docCanvasProvider.notifier).addAnnotation(annotation);
            HapticFeedback.lightImpact();
          }
        }

        setState(() {
          _dragStart = null;
          _dragCurrent = null;
          _activePoints.clear();
        });
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _AnnotationPainter(
          annotations: state.annotations.where((a) => a.pageIndex == state.currentPageIndex).toList(),
          activePoints: _activePoints,
          activeTool: tool,
          activeColor: state.activeHighlighterColor,
          activeDragRect: _dragStart != null && _dragCurrent != null && _activePoints.length < 3
              ? Rect.fromPoints(_dragStart!, _dragCurrent!)
              : null,
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<DocAnnotationModel> annotations;
  final List<Offset> activePoints;
  final DocAnnotationType activeTool;
  final Color activeColor;
  final Rect? activeDragRect;

  _AnnotationPainter({
    required this.annotations,
    required this.activePoints,
    required this.activeTool,
    required this.activeColor,
    this.activeDragRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Render all committed annotations on this page
    for (final a in annotations) {
      if (a.points != null && a.points!.isNotEmpty) {
        final path = Path();
        path.moveTo(a.points!.first.dx, a.points!.first.dy);
        for (int i = 1; i < a.points!.length; i++) {
          path.lineTo(a.points![i].dx, a.points![i].dy);
        }

        final isHl = a.type == DocAnnotationType.highlight;
        final paint = Paint()
          ..color = isHl ? a.color.withValues(alpha: 0.38) : a.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = isHl ? 20.0 : a.strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

        canvas.drawPath(path, paint);
      } else if (a.boundingBox != null) {
        final paint = Paint()
          ..color = a.color
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(a.boundingBox!, const Radius.circular(6)),
          paint,
        );
      }
    }

    // 2. Render live in-progress stroke while finger is on screen
    if (activePoints.length >= 2) {
      final isHl = activeTool == DocAnnotationType.highlight;
      final livePath = Path();
      livePath.moveTo(activePoints.first.dx, activePoints.first.dy);
      for (int i = 1; i < activePoints.length; i++) {
        livePath.lineTo(activePoints[i].dx, activePoints[i].dy);
      }

      final livePaint = Paint()
        ..color = isHl ? activeColor.withValues(alpha: 0.38) : activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHl ? 20.0 : 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(livePath, livePaint);
    } else if (activeDragRect != null && activeTool == DocAnnotationType.highlight) {
      final rectPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeDragRect!, const Radius.circular(6)),
        rectPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
