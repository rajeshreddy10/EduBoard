import 'package:flutter/material.dart';

import '../core/utilities/safe_json.dart';

/// Available whiteboard tools
enum WhiteboardTool {
  pen,
  pencil,
  brush,
  marker,
  highlighter,
  eraser,
  pan,
  selection,
  text,
  shape,
  fill,
  laser,
  spotlight,
  pointer,
  reveal;

  String get label {
    switch (this) {
      case WhiteboardTool.pen:
        return 'Freehand Pen';
      case WhiteboardTool.pencil:
        return 'Pencil';
      case WhiteboardTool.brush:
        return 'Brush';
      case WhiteboardTool.marker:
        return 'Marker';
      case WhiteboardTool.highlighter:
        return 'Highlighter';
      case WhiteboardTool.eraser:
        return 'Eraser';
      case WhiteboardTool.pan:
        return 'Move/Pan';
      case WhiteboardTool.selection:
        return 'Select';
      case WhiteboardTool.text:
        return 'Text';
      case WhiteboardTool.shape:
        return 'Shape';
      case WhiteboardTool.fill:
        return 'Fill Color';
      case WhiteboardTool.laser:
        return 'Laser Pointer';
      case WhiteboardTool.spotlight:
        return 'Focus Spotlight';
      case WhiteboardTool.pointer:
        return 'Pointer Tool';
      case WhiteboardTool.reveal:
        return 'Reveal Curtain';
    }
  }

  IconData get icon {
    switch (this) {
      case WhiteboardTool.pen:
        return Icons.edit_rounded;
      case WhiteboardTool.pencil:
        return Icons.draw_rounded;
      case WhiteboardTool.brush:
        return Icons.brush_rounded;
      case WhiteboardTool.marker:
        return Icons.format_color_fill_rounded;
      case WhiteboardTool.highlighter:
        return Icons.highlight_rounded;
      case WhiteboardTool.eraser:
        return Icons.auto_fix_normal_rounded;
      case WhiteboardTool.pan:
        return Icons.pan_tool_alt_rounded;
      case WhiteboardTool.selection:
        return Icons.highlight_alt_rounded;
      case WhiteboardTool.text:
        return Icons.text_fields_rounded;
      case WhiteboardTool.shape:
        return Icons.interests_rounded;
      case WhiteboardTool.fill:
        return Icons.format_paint_rounded;
      case WhiteboardTool.laser:
        return Icons.flare_rounded;
      case WhiteboardTool.spotlight:
        return Icons.wb_incandescent_rounded;
      case WhiteboardTool.pointer:
        return Icons.touch_app_rounded;
      case WhiteboardTool.reveal:
        return Icons.curtains_rounded;
    }
  }

  /// Returns the effective opacity for this tool's strokes.
  double get opacity {
    switch (this) {
      case WhiteboardTool.highlighter:
        return 0.40;
      case WhiteboardTool.marker:
        return 0.85;
      default:
        return 1.0;
    }
  }

  /// Returns the effective stroke-width multiplier for this tool.
  double get widthMultiplier {
    switch (this) {
      case WhiteboardTool.brush:
        return 2.5;
      case WhiteboardTool.marker:
        return 3.0;
      case WhiteboardTool.highlighter:
        return 6.0;
      default:
        return 1.0;
    }
  }
}

/// Geometric shapes supported by the Shape Tool
enum WhiteboardShapeType {
  rectangle,
  circle,
  triangle,
  line,
  arrow,
  doubleArrow,
  star,
  diamond;

  String get label {
    switch (this) {
      case WhiteboardShapeType.rectangle:
        return 'Rectangle';
      case WhiteboardShapeType.circle:
        return 'Circle / Oval';
      case WhiteboardShapeType.triangle:
        return 'Triangle';
      case WhiteboardShapeType.line:
        return 'Line';
      case WhiteboardShapeType.arrow:
        return 'Arrow';
      case WhiteboardShapeType.doubleArrow:
        return 'Double Arrow';
      case WhiteboardShapeType.star:
        return 'Star';
      case WhiteboardShapeType.diamond:
        return 'Diamond';
    }
  }

  IconData get icon {
    switch (this) {
      case WhiteboardShapeType.rectangle:
        return Icons.crop_square_rounded;
      case WhiteboardShapeType.circle:
        return Icons.circle_outlined;
      case WhiteboardShapeType.triangle:
        return Icons.change_history_rounded;
      case WhiteboardShapeType.line:
        return Icons.horizontal_rule_rounded;
      case WhiteboardShapeType.arrow:
        return Icons.arrow_forward_rounded;
      case WhiteboardShapeType.doubleArrow:
        return Icons.sync_alt_rounded;
      case WhiteboardShapeType.star:
        return Icons.star_border_rounded;
      case WhiteboardShapeType.diamond:
        return Icons.diamond_outlined;
    }
  }
}

/// Single point with pressure and coordinate data
class StrokePoint {
  final double x;
  final double y;
  final double pressure;

  const StrokePoint(this.x, this.y, [this.pressure = 1.0]);

  double get dx => x;
  double get dy => y;

  Offset get offset => Offset(x, y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'p': pressure, 'pressure': pressure};

  factory StrokePoint.fromJson(Map<String, dynamic> json) => StrokePoint(
        asDoubleOr(json['x'], 0),
        asDoubleOr(json['y'], 0),
        asDoubleOr(json['p'] ?? json['pressure'], 1.0),
      );
}

/// Drawn stroke data structure
class WhiteboardStroke {
  final String id;
  final List<StrokePoint> points;
  final Color color;
  final double strokeWidth;
  final WhiteboardTool tool;
  final WhiteboardShapeType? shapeType;
  final bool isSelected;

  const WhiteboardStroke({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.tool,
    this.shapeType,
    this.isSelected = false,
  });

  WhiteboardStroke copyWith({
    List<StrokePoint>? points,
    Color? color,
    double? strokeWidth,
    WhiteboardTool? tool,
    WhiteboardShapeType? shapeType,
    bool? isSelected,
  }) {
    return WhiteboardStroke(
      id: id,
      points: points ?? this.points,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      tool: tool ?? this.tool,
      shapeType: shapeType ?? this.shapeType,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Floating text element on canvas with rich typographic controls
class WhiteboardTextElement {
  final String id;
  final Offset position;
  final String text;
  final Color color;
  final double fontSize;
  final bool isSelected;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String? fontFamily;
  final TextAlign textAlign;
  final double rotation;
  final double scale;

  const WhiteboardTextElement({
    required this.id,
    required this.position,
    required this.text,
    required this.color,
    this.fontSize = 20.0,
    this.isSelected = false,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontFamily,
    this.textAlign = TextAlign.left,
    this.rotation = 0.0,
    this.scale = 1.0,
  });

  WhiteboardTextElement copyWith({
    Offset? position,
    String? text,
    Color? color,
    double? fontSize,
    bool? isSelected,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    String? fontFamily,
    TextAlign? textAlign,
    double? rotation,
    double? scale,
  }) {
    return WhiteboardTextElement(
      id: id,
      position: position ?? this.position,
      text: text ?? this.text,
      color: color ?? this.color,
      fontSize: fontSize ?? this.fontSize,
      isSelected: isSelected ?? this.isSelected,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: textAlign ?? this.textAlign,
      rotation: rotation ?? this.rotation,
      scale: scale ?? this.scale,
    );
  }
}

/// Teacher private lesson note
class TeacherNote {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;

  const TeacherNote({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
  });
}
