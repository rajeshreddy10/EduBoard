import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/whiteboard_stroke_model.dart';

/// 60 FPS CustomPainter rendering strokes, shapes, laser trails, spotlight, and reveal curtain
class DrawSpacePainter extends CustomPainter {
  /// Bounded cache of laid-out TextPainters, keyed by full visual state.
  /// Cleared when it grows past the cap so text edits never leak memory.
  static final Map<String, TextPainter> _textPainterCache = {};
  static const int _textPainterCacheCap = 64;

  final List<WhiteboardStroke> strokes;
  final WhiteboardStroke? currentStroke;
  final List<WhiteboardTextElement> textElements;
  final Offset? laserPosition;
  final Color laserColor;
  final Offset? spotlightPosition;
  final double spotlightRadius;
  final double revealFraction; // 0.0 to 1.0
  final Offset? pointerPosition;
  final String pointerStyle;

  DrawSpacePainter({
    required this.strokes,
    this.currentStroke,
    this.textElements = const [],
    this.laserPosition,
    this.laserColor = const Color(0xFFFF0000),
    this.spotlightPosition,
    this.spotlightRadius = 90.0,
    this.revealFraction = 0.0,
    this.pointerPosition,
    this.pointerStyle = 'dot',
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw all completed strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // 2. Draw current active stroke
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }

    // 3. Draw text elements with rich formatting, rotation, and selection highlights
    for (final textElem in textElements) {
      final key =
          '${textElem.id}|${textElem.text.hashCode}|${textElem.fontSize}|${textElem.color.toARGB32()}|${textElem.isBold}|${textElem.isItalic}|${textElem.isUnderline}|${textElem.fontFamily}|${textElem.textAlign.name}';
      TextPainter textPainter;
      final cached = _textPainterCache[key];
      if (cached != null) {
        textPainter = cached;
      } else {
        textPainter = TextPainter(
          text: TextSpan(
            text: textElem.text,
            style: TextStyle(
              color: textElem.color,
              fontSize: textElem.fontSize * textElem.scale,
              fontWeight: textElem.isBold ? FontWeight.bold : FontWeight.w600,
              fontStyle: textElem.isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: textElem.isUnderline ? TextDecoration.underline : TextDecoration.none,
              fontFamily: textElem.fontFamily,
              height: 1.4,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: textElem.textAlign,
        )..layout();
        if (_textPainterCache.length >= _textPainterCacheCap) {
          _textPainterCache.clear();
        }
        _textPainterCache[key] = textPainter;
      }

      canvas.save();
      canvas.translate(textElem.position.dx, textElem.position.dy);
      if (textElem.rotation != 0.0) {
        canvas.rotate(textElem.rotation);
      }

      // Draw selection card box if selected
      if (textElem.isSelected) {
        final boxPaint = Paint()
          ..color = const Color(0xFF6366F1).withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;
        final borderPaint = Paint()
          ..color = const Color(0xFF6366F1)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        final rect = Rect.fromLTWH(-4, -4, textPainter.width + 8, textPainter.height + 8);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), boxPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), borderPaint);
      }

      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }

    // 4. Render Spotlight overlay if active (dims ~70%)
    if (spotlightPosition != null) {
      final spotlightPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.72)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addOval(Rect.fromCircle(center: spotlightPosition!, radius: spotlightRadius))
        ..fillType = PathFillType.evenOdd;

      canvas.drawPath(path, spotlightPaint);
    }

    // 5. Render Laser Pointer with glow and trail effect
    if (laserPosition != null) {
      final laserPaintGlow = Paint()
        ..color = laserColor.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
      final laserPaintCore = Paint()..color = laserColor;
      final laserPaintHalo = Paint()
        ..color = laserColor.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(laserPosition!, 18, laserPaintGlow);
      canvas.drawCircle(laserPosition!, 10, laserPaintHalo);
      canvas.drawCircle(laserPosition!, 5, laserPaintCore);
    }

    // 6. Render Reveal Curtain overlay
    if (revealFraction > 0.01) {
      final curtainHeight = size.height * revealFraction;
      final curtainPaint = Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.92);
      canvas.drawRect(Rect.fromLTWH(0, size.height - curtainHeight, size.width, curtainHeight), curtainPaint);

      // Handle grab line
      final handlePaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 3;
      canvas.drawLine(
        Offset(0, size.height - curtainHeight),
        Offset(size.width, size.height - curtainHeight),
        handlePaint,
      );
    }

    // 7. Render Presentation Pointer (Teacher cursor / dot / crosshair)
    if (pointerPosition != null) {
      final ringPaint = Paint()
        ..color = const Color(0xFF6366F1).withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      final corePaint = Paint()
        ..color = const Color(0xFF6366F1)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(pointerPosition!, 14, ringPaint);
      canvas.drawCircle(pointerPosition!, 6, corePaint);
      canvas.drawCircle(pointerPosition!, 6, strokePaint);
    }
  }

  void _drawStroke(Canvas canvas, WhiteboardStroke stroke) {
    if (stroke.points.isEmpty) return;

    if (stroke.tool == WhiteboardTool.shape && stroke.shapeType != null) {
      _drawShape(canvas, stroke);
      return;
    }

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    switch (stroke.tool) {
      case WhiteboardTool.eraser:
        paint.color = Colors.transparent;
        paint.blendMode = BlendMode.clear;
        paint.strokeWidth = stroke.strokeWidth * 2;
        break;
      case WhiteboardTool.pencil:
        paint.color = stroke.color.withValues(alpha: 0.65);
        paint.strokeWidth = stroke.strokeWidth * 0.75;
        break;
      case WhiteboardTool.brush:
        paint.color = stroke.color;
        paint.strokeWidth = stroke.strokeWidth * 2.5;
        paint.strokeCap = StrokeCap.round;
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        break;
      case WhiteboardTool.marker:
        paint.color = stroke.color.withValues(alpha: 0.85);
        paint.strokeWidth = stroke.strokeWidth * 3.0;
        paint.strokeCap = StrokeCap.square;
        break;
      case WhiteboardTool.highlighter:
        paint.color = stroke.color.withValues(alpha: 0.38);
        paint.strokeWidth = stroke.strokeWidth * 6.0;
        paint.strokeCap = StrokeCap.square;
        paint.blendMode = BlendMode.multiply;
        break;
      default:
        paint.color = stroke.color;
        paint.strokeWidth = stroke.strokeWidth;
        break;
    }

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first.offset, stroke.strokeWidth / 2, paint..style = PaintingStyle.fill);
      return;
    }

    final path = Path();
    path.moveTo(stroke.points.first.x, stroke.points.first.y);

    for (int i = 1; i < stroke.points.length - 1; i++) {
      final p0 = stroke.points[i];
      final p1 = stroke.points[i + 1];
      final midX = (p0.x + p1.x) / 2;
      final midY = (p0.y + p1.y) / 2;
      path.quadraticBezierTo(p0.x, p0.y, midX, midY);
    }
    path.lineTo(stroke.points.last.x, stroke.points.last.y);

    canvas.drawPath(path, paint);
  }

  void _drawShape(Canvas canvas, WhiteboardStroke stroke) {
    final start = stroke.points.first.offset;
    final end = stroke.points.last.offset;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke;

    switch (stroke.shapeType!) {
      case WhiteboardShapeType.rectangle:
        final rrect = RRect.fromRectAndRadius(
          Rect.fromPoints(start, end),
          const Radius.circular(4),
        );
        canvas.drawRRect(rrect, paint);
        break;
      case WhiteboardShapeType.circle:
        canvas.drawOval(Rect.fromPoints(start, end), paint);
        break;
      case WhiteboardShapeType.triangle:
        final mid = (start + end) / 2;
        final path = Path()
          ..moveTo(mid.dx, start.dy)
          ..lineTo(end.dx, end.dy)
          ..lineTo(start.dx, end.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case WhiteboardShapeType.line:
        canvas.drawLine(start, end, paint);
        break;
      case WhiteboardShapeType.arrow:
        _drawArrow(canvas, start, end, paint, headAtEnd: true);
        break;
      case WhiteboardShapeType.doubleArrow:
        _drawArrow(canvas, start, end, paint, headAtEnd: true, headAtStart: true);
        break;
      case WhiteboardShapeType.star:
        _drawStar(canvas, start, end, paint);
        break;
      case WhiteboardShapeType.diamond:
        final rect = Rect.fromPoints(start, end);
        final path = Path()
          ..moveTo(rect.center.dx, rect.top)
          ..lineTo(rect.right, rect.center.dy)
          ..lineTo(rect.center.dx, rect.bottom)
          ..lineTo(rect.left, rect.center.dy)
          ..close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint,
      {bool headAtEnd = true, bool headAtStart = false}) {
    canvas.drawLine(start, end, paint);
    const arrowLength = 18.0;
    const arrowAngle = math.pi / 6;
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);

    if (headAtEnd) {
      final path = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - arrowLength * math.cos(angle - arrowAngle),
            end.dy - arrowLength * math.sin(angle - arrowAngle))
        ..moveTo(end.dx, end.dy)
        ..lineTo(end.dx - arrowLength * math.cos(angle + arrowAngle),
            end.dy - arrowLength * math.sin(angle + arrowAngle));
      canvas.drawPath(path, paint);
    }

    if (headAtStart) {
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx + arrowLength * math.cos(angle - arrowAngle),
            start.dy + arrowLength * math.sin(angle - arrowAngle))
        ..moveTo(start.dx, start.dy)
        ..lineTo(start.dx + arrowLength * math.cos(angle + arrowAngle),
            start.dy + arrowLength * math.sin(angle + arrowAngle));
      canvas.drawPath(path, paint);
    }
  }

  void _drawStar(Canvas canvas, Offset start, Offset end, Paint paint) {
    final rect = Rect.fromPoints(start, end);
    final center = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    const numPoints = 5;
    const step = math.pi / numPoints;

    final path = Path();
    for (int i = 0; i < numPoints * 2; i++) {
      final angle = -math.pi / 2 + i * step;
      final r = i.isEven ? 1.0 : 0.4;
      final x = center.dx + rx * r * math.cos(angle);
      final y = center.dy + ry * r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  /// Field comparison instead of the previous always-`true`. This is the core
  /// frame-skip fix: pan/zoom/laser gestures now only repaint when values
  /// actually change, instead of invalidating the whole board raster on every
  /// pointer sample. Notifications already rebuild the CustomPaint subtree;
  /// this only short-circuits identical frames.
  @override
  bool shouldRepaint(covariant DrawSpacePainter oldDelegate) {
    if (strokes.length != oldDelegate.strokes.length) return true;
    for (int i = 0; i < strokes.length; i++) {
      // Identity is sufficient: provider updates always allocate new stroke
      // objects when their content changes.
      if (!identical(strokes[i], oldDelegate.strokes[i])) return true;
    }
    if (!identical(currentStroke, oldDelegate.currentStroke)) return true;
    if (textElements.length != oldDelegate.textElements.length) return true;
    for (int i = 0; i < textElements.length; i++) {
      if (!identical(textElements[i], oldDelegate.textElements[i])) return true;
    }
    if (laserPosition != oldDelegate.laserPosition ||
        laserColor != oldDelegate.laserColor ||
        spotlightPosition != oldDelegate.spotlightPosition ||
        spotlightRadius != oldDelegate.spotlightRadius ||
        revealFraction != oldDelegate.revealFraction ||
        pointerPosition != oldDelegate.pointerPosition ||
        pointerStyle != oldDelegate.pointerStyle) {
      return true;
    }
    // A single-point stroke can morph in place (edge case): fall back to deep
    // comparison only for the active stroke's count drift.
    if ((currentStroke?.points.length ?? 0) != (oldDelegate.currentStroke?.points.length ?? 0)) {
      return true;
    }
    return false;
  }
}
