import 'dart:convert';
import '../../models/whiteboard_stroke_model.dart';
import '../../models/voice_block_model.dart';
import '../../models/doc_annotation_model.dart';

/// Unified export engine for DrawSpace, DocCanvas, and VoiceBoard studios.
/// Supports JSON, SVG, TXT, Markdown, LaTeX, and structured printable documents.
class CanvasExportService {
  CanvasExportService._();

  /// ─── MODULE 1: DRAWSPACE EXPORTS ──────────────────────────────────────────

  /// Serializes the complete whiteboard session to structured JSON
  static String exportWhiteboardToJson({
    required String boardId,
    required String title,
    required String category,
    required List<WhiteboardStroke> strokes,
    required List<WhiteboardTextElement> textElements,
    required List<TeacherNote> teacherNotes,
  }) {
    final payload = {
      'format': 'EduBoard_Whiteboard_v1',
      'exported_at': DateTime.now().toIso8601String(),
      'board_id': boardId,
      'title': title,
      'category': category,
      'stroke_count': strokes.length,
      'text_count': textElements.length,
      'strokes': strokes.map((s) => {
        'id': s.id,
        'tool': s.tool.name,
        'shape': s.shapeType?.name,
        'color': '#${(s.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
        'stroke_width': s.strokeWidth,
        'points': s.points.map((p) => {'x': p.x, 'y': p.y, 'p': p.pressure}).toList(),
      }).toList(),
      'text_elements': textElements.map((t) => {
        'id': t.id,
        'text': t.text,
        'x': t.position.dx,
        'y': t.position.dy,
        'font_size': t.fontSize,
        'color': '#${(t.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      }).toList(),
      'teacher_notes': teacherNotes.map((n) => {
        'id': n.id,
        'title': n.title,
        'content': n.content,
        'created_at': n.createdAt.toIso8601String(),
      }).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Converts all drawn strokes, shapes, and text elements into scalable SVG XML
  static String exportWhiteboardToSvg({
    required String title,
    required List<WhiteboardStroke> strokes,
    required List<WhiteboardTextElement> textElements,
    double width = 1920,
    double height = 1080,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height" width="$width" height="$height">');
    buffer.writeln('  <!-- Generator: EduBoard Studio Mobile SVG Exporter -->');
    buffer.writeln('  <rect width="100%" height="100%" fill="#FFFFFF" />');

    // Strokes & Shapes
    for (final s in strokes) {
      final hex = '#${(s.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      final opacity = s.tool.opacity;

      if (s.tool == WhiteboardTool.shape && s.shapeType != null && s.points.length >= 2) {
        final start = s.points.first;
        final end = s.points.last;
        switch (s.shapeType!) {
          case WhiteboardShapeType.rectangle:
            final x = start.x < end.x ? start.x : end.x;
            final y = start.y < end.y ? start.y : end.y;
            final w = (end.x - start.x).abs();
            final h = (end.y - start.y).abs();
            buffer.writeln('  <rect x="$x" y="$y" width="$w" height="$h" rx="4" fill="none" stroke="$hex" stroke-width="${s.strokeWidth}" opacity="$opacity" />');
            break;
          case WhiteboardShapeType.circle:
            final cx = (start.x + end.x) / 2;
            final cy = (start.y + end.y) / 2;
            final rx = (end.x - start.x).abs() / 2;
            final ry = (end.y - start.y).abs() / 2;
            buffer.writeln('  <ellipse cx="$cx" cy="$cy" rx="$rx" ry="$ry" fill="none" stroke="$hex" stroke-width="${s.strokeWidth}" opacity="$opacity" />');
            break;
          case WhiteboardShapeType.triangle:
            final midX = (start.x + end.x) / 2;
            buffer.writeln('  <polygon points="$midX,${start.y} ${end.x},${end.y} ${start.x},${end.y}" fill="none" stroke="$hex" stroke-width="${s.strokeWidth}" opacity="$opacity" />');
            break;
          case WhiteboardShapeType.line:
          case WhiteboardShapeType.arrow:
          case WhiteboardShapeType.doubleArrow:
            buffer.writeln('  <line x1="${start.x}" y1="${start.y}" x2="${end.x}" y2="${end.y}" stroke="$hex" stroke-width="${s.strokeWidth}" stroke-linecap="round" opacity="$opacity" />');
            break;
          case WhiteboardShapeType.diamond:
            final midX = (start.x + end.x) / 2;
            final midY = (start.y + end.y) / 2;
            buffer.writeln('  <polygon points="$midX,${start.y} ${end.x},$midY $midX,${end.y} ${start.x},$midY" fill="none" stroke="$hex" stroke-width="${s.strokeWidth}" opacity="$opacity" />');
            break;
          default:
            break;
        }
      } else if (s.points.isNotEmpty) {
        if (s.points.length == 1) {
          buffer.writeln('  <circle cx="${s.points.first.x}" cy="${s.points.first.y}" r="${s.strokeWidth / 2}" fill="$hex" opacity="$opacity" />');
        } else {
          final pathData = StringBuffer();
          pathData.write('M ${s.points.first.x} ${s.points.first.y} ');
          for (int i = 1; i < s.points.length; i++) {
            pathData.write('L ${s.points[i].x} ${s.points[i].y} ');
          }
          buffer.writeln('  <path d="${pathData.toString().trim()}" fill="none" stroke="$hex" stroke-width="${s.strokeWidth}" stroke-linecap="round" stroke-linejoin="round" opacity="$opacity" />');
        }
      }
    }

    // Text Elements
    for (final t in textElements) {
      final hex = '#${(t.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      final clean = t.text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
      buffer.writeln('  <text x="${t.position.dx}" y="${t.position.dy + t.fontSize}" font-family="sans-serif" font-size="${t.fontSize}" fill="$hex">$clean</text>');
    }

    buffer.writeln('</svg>');
    return buffer.toString();
  }

  /// ─── MODULE 2: DOCCANVAS EXPORTS ──────────────────────────────────────────

  /// Serializes document annotations into JSON format
  static String exportDocAnnotationsToJson({
    required String documentTitle,
    required List<DocAnnotationModel> annotations,
  }) {
    final payload = {
      'format': 'EduBoard_DocCanvas_v1',
      'exported_at': DateTime.now().toIso8601String(),
      'document_title': documentTitle,
      'total_annotations': annotations.length,
      'annotations': annotations.map((a) => a.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// ─── MODULE 3: VOICE BOARD EXPORTS ────────────────────────────────────────

  /// Formats voice board session into clean plain text
  static String exportVoiceToText({
    required String title,
    required List<VoiceBlockModel> blocks,
    required Duration duration,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('========================================');
    buffer.writeln('$title — Lecture Transcript');
    buffer.writeln('Exported: ${DateTime.now().toLocal()}');
    buffer.writeln('Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s');
    buffer.writeln('Total Blocks: ${blocks.length}');
    buffer.writeln('========================================\n');

    for (final b in blocks) {
      final min = b.timestamp.inMinutes.toString().padLeft(2, '0');
      final sec = (b.timestamp.inSeconds % 60).toString().padLeft(2, '0');
      buffer.writeln('[$min:$sec] ${b.speakerName}:');
      buffer.writeln('${b.text}\n');
    }
    return buffer.toString();
  }

  /// Formats voice board session into formatted Markdown
  static String exportVoiceToMarkdown({
    required String title,
    required List<VoiceBlockModel> blocks,
    required Duration duration,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# $title\n');
    buffer.writeln('> **EduBoard AI Voice Studio** · Lecture Transcript  ');
    buffer.writeln('> Date: `${DateTime.now().toLocal().toString().split('.').first}` · Duration: `${duration.inMinutes}m ${duration.inSeconds % 60}s` · Blocks: `${blocks.length}`\n');
    buffer.writeln('---\n');
    buffer.writeln('## Lecture Notes\n');

    for (final b in blocks) {
      final min = b.timestamp.inMinutes.toString().padLeft(2, '0');
      final sec = (b.timestamp.inSeconds % 60).toString().padLeft(2, '0');
      buffer.writeln('### `$min:$sec` — ${b.speakerName}');
      buffer.writeln('${b.text}\n');
    }

    buffer.writeln('---\n*Generated by EduBoard Studio*');
    return buffer.toString();
  }

  /// Formats voice board session into clean LaTeX document
  static String exportVoiceToLatex({
    required String title,
    required List<VoiceBlockModel> blocks,
    required Duration duration,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(r'\documentclass[11pt,a4paper]{article}');
    buffer.writeln(r'\usepackage[utf8]{inputenc}');
    buffer.writeln(r'\usepackage{amsmath,amsfonts,amssymb}');
    buffer.writeln(r'\usepackage{geometry}');
    buffer.writeln(r'\geometry{margin=1in}');
    buffer.writeln(r'\title{' '${title.replaceAll('_', r'\_')}' '}');
    buffer.writeln(r'\author{EduBoard AI Studio}');
    buffer.writeln(r'\date{\today}');
    buffer.writeln(r'\begin{document}');
    buffer.writeln(r'\maketitle');
    buffer.writeln(r'\section*{Lecture Transcription}');
    buffer.writeln(r'\begin{description}');

    for (final b in blocks) {
      final min = b.timestamp.inMinutes.toString().padLeft(2, '0');
      final sec = (b.timestamp.inSeconds % 60).toString().padLeft(2, '0');
      final safeText = b.text
          .replaceAll(r'\', r'\textbackslash{}')
          .replaceAll('%', r'\%')
          .replaceAll(r'$', r'\$')
          .replaceAll('_', r'\_')
          .replaceAll('&', r'\&');
      buffer.writeln('  \\item[$min:$sec] $safeText');
    }

    buffer.writeln(r'\end{description}');
    buffer.writeln(r'\end{document}');
    return buffer.toString();
  }
}

