import 'package:flutter/material.dart';

import '../core/utilities/safe_json.dart';

enum DocAnnotationType { highlight, pen, text, mathBox, eraser }

/// Represents an annotation overlay on top of the document canvas
class DocAnnotationModel {
  final String id;
  final int pageIndex;
  final DocAnnotationType type;
  final Rect? boundingBox;
  final List<Offset>? points;
  final String? text;
  final Color color;
  final double strokeWidth;
  final DateTime createdAt;

  const DocAnnotationModel({
    required this.id,
    required this.pageIndex,
    required this.type,
    this.boundingBox,
    this.points,
    this.text,
    this.color = const Color(0xFFFFD54F),
    this.strokeWidth = 3.0,
    required this.createdAt,
  });

  DocAnnotationModel copyWith({
    String? id,
    int? pageIndex,
    DocAnnotationType? type,
    Rect? boundingBox,
    List<Offset>? points,
    String? text,
    Color? color,
    double? strokeWidth,
    DateTime? createdAt,
  }) {
    return DocAnnotationModel(
      id: id ?? this.id,
      pageIndex: pageIndex ?? this.pageIndex,
      type: type ?? this.type,
      boundingBox: boundingBox ?? this.boundingBox,
      points: points ?? this.points,
      text: text ?? this.text,
      color: color ?? this.color,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pageIndex': pageIndex,
    'type': type.name,
    'text': text,
    'color': color.toARGB32(),
    'strokeWidth': strokeWidth,
    'createdAt': createdAt.toIso8601String(),
    'points': points?.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
  };

  factory DocAnnotationModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final tName = (json['type'] ?? 'highlight').toString();
    DocAnnotationType t = DocAnnotationType.highlight;
    for (final v in DocAnnotationType.values) {
      if (v.name == tName) {
        t = v;
        break;
      }
    }

    final ptsList = json['points'] as List<dynamic>?;
    List<Offset>? points;
    if (ptsList != null) {
      points = ptsList
          .whereType<Map>()
          .map((m) => Offset(asDoubleOr(m['x'], 0), asDoubleOr(m['y'], 0)))
          .toList();
    }

    Color color = const Color(0xFFFFD54F);
    final rawColor = json['color'];
    if (rawColor is int) {
      color = Color(rawColor);
    } else if (rawColor is num) {
      color = Color(rawColor.toInt());
    } else if (rawColor is String) {
      final parsed = int.tryParse(rawColor.replaceAll('#', ''), radix: 16);
      if (parsed != null) color = Color(parsed);
    }

    return DocAnnotationModel(
      id: id ?? json['id']?.toString() ?? 'ann_${DateTime.now().millisecondsSinceEpoch}',
      pageIndex: asIntOr(json['pageIndex'], 1),
      type: t,
      text: json['text']?.toString(),
      color: color,
      strokeWidth: asDoubleOr(json['strokeWidth'], 3.0),
      points: points,
      createdAt: asDateOr(json['createdAt'], DateTime.now()),
    );
  }
}

/// Represents an academic lecture document
class DocumentModel {
  final String id;
  final String title;
  final String author;
  final int totalPages;
  final String category;
  final String previewExcerpt;
  final DateTime updatedAt;
  final String? filePath;
  final String fileType;
  final String? fileContent;
  final String? url;

  const DocumentModel({
    required this.id,
    required this.title,
    required this.author,
    required this.totalPages,
    required this.category,
    required this.previewExcerpt,
    required this.updatedAt,
    this.filePath,
    this.fileType = 'doc',
    this.fileContent,
    this.url,
  });

  DocumentModel copyWith({
    String? id,
    String? title,
    String? author,
    int? totalPages,
    String? category,
    String? previewExcerpt,
    DateTime? updatedAt,
    String? filePath,
    String? fileType,
    String? fileContent,
    String? url,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      totalPages: totalPages ?? this.totalPages,
      category: category ?? this.category,
      previewExcerpt: previewExcerpt ?? this.previewExcerpt,
      updatedAt: updatedAt ?? this.updatedAt,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      fileContent: fileContent ?? this.fileContent,
      url: url ?? this.url,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'name': title,
    'author': author,
    'totalPages': totalPages,
    'category': category,
    'description': previewExcerpt,
    'updated_at': updatedAt.toIso8601String(),
    'filePath': filePath,
    'fileType': fileType,
    'type': fileType,
    'fileContent': fileContent,
    'url': url,
  };

  factory DocumentModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final type = json['fileType']?.toString() ?? json['type']?.toString() ?? 'doc';
    final url = json['url']?.toString() ?? json['dataUrl']?.toString();
    final content = json['fileContent']?.toString() ?? json['textContent']?.toString();
    return DocumentModel(
      id: id ?? json['id']?.toString() ?? 'doc_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? json['name']?.toString() ?? 'Untitled Document',
      author: json['author']?.toString() ?? json['createdBy']?.toString() ?? 'Instructor',
      totalPages: asIntOr(json['totalPages'] ?? json['page_count'] ?? json['pageCount'], 1),
      category: json['category']?.toString() ?? 'Lecture Document',
      previewExcerpt: json['description']?.toString() ?? json['previewExcerpt']?.toString() ?? (content != null && content.isNotEmpty ? content.substring(0, content.length.clamp(0, 160)) : 'Interactive pedagogical document'),
      updatedAt: asDateOr(json['updated_at'] ?? json['updatedAt'], DateTime.now()),
      filePath: json['filePath']?.toString(),
      fileType: type,
      fileContent: content,
      url: url,
    );
  }
}

/// Backward compatibility alias for UI widgets
typedef MockDocumentModel = DocumentModel;
