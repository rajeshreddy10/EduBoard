import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/doc_annotation_model.dart';
import '../../../providers/doccanvas_provider.dart';

/// Interactive overlay layer that renders and records highlights and annotations on the document
class DocAnnotationLayer extends ConsumerStatefulWidget {
  const DocAnnotationLayer({super.key});

  @override
  ConsumerState<DocAnnotationLayer> createState() => _DocAnnotationLayerState();
}

class _DocAnnotationLayerState extends ConsumerState<DocAnnotationLayer> {
  Offset? _dragStart;
  Offset? _dragCurrent;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(docCanvasProvider);

    return GestureDetector(
      onPanStart: (details) {
        if (!state.isHighlighterActive) return;
        setState(() {
          _dragStart = details.localPosition;
          _dragCurrent = details.localPosition;
        });
      },
      onPanUpdate: (details) {
        if (!state.isHighlighterActive) return;
        setState(() {
          _dragCurrent = details.localPosition;
        });
      },
      onPanEnd: (details) {
        if (!state.isHighlighterActive || _dragStart == null || _dragCurrent == null) return;
        final rect = Rect.fromPoints(_dragStart!, _dragCurrent!);
        final annotation = DocAnnotationModel(
          id: 'annot_${DateTime.now().millisecondsSinceEpoch}',
          pageIndex: state.currentPageIndex,
          type: DocAnnotationType.highlight,
          boundingBox: rect,
          color: const Color(0xFFFFEB3B).withValues(alpha: 0.35),
          createdAt: DateTime.now(),
        );
        ref.read(docCanvasProvider.notifier).addAnnotation(annotation);
        setState(() {
          _dragStart = null;
          _dragCurrent = null;
        });
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: _AnnotationPainter(
          annotations: state.annotations.where((a) => a.pageIndex == state.currentPageIndex).toList(),
          activeDragRect: _dragStart != null && _dragCurrent != null
              ? Rect.fromPoints(_dragStart!, _dragCurrent!)
              : null,
        ),
      ),
    );
  }
}

class _AnnotationPainter extends CustomPainter {
  final List<DocAnnotationModel> annotations;
  final Rect? activeDragRect;

  _AnnotationPainter({
    required this.annotations,
    this.activeDragRect,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Render all annotations on the current page.
    for (final a in annotations) {
      if (a.boundingBox != null) {
        final paint = Paint()
          ..color = a.color
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(a.boundingBox!, const Radius.circular(6)),
          paint,
        );
      }
    }

    if (activeDragRect != null) {
      final activePaint = Paint()
        ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.4)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeDragRect!, const Radius.circular(6)),
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AnnotationPainter oldDelegate) => true;
}
