import 'package:flutter/material.dart';

import '../core/utilities/safe_json.dart';

enum HistoryCategory { all, whiteboard, docAnnotation, voiceSession }

/// Representation of past saved sessions, whiteboards, and recordings
class HistoryItemModel {
  final String id;
  final String title;
  final HistoryCategory category;
  final DateTime modifiedAt;
  final int strokeCount;
  final int durationSeconds;
  final bool isFavorite;
  final List<String> tags;
  final String summary;
  /// Optional board preview / session thumbnail. Can be a Firebase Storage
  /// URL, http(s) URL, or `data:image/...` Base64 payload — always render
  /// through [EduImage] so every source resolves safely.
  final String? thumbnailUrl;

  const HistoryItemModel({
    required this.id,
    required this.title,
    required this.category,
    required this.modifiedAt,
    this.strokeCount = 0,
    this.durationSeconds = 0,
    this.isFavorite = false,
    required this.tags,
    required this.summary,
    this.thumbnailUrl,
  });

  HistoryItemModel copyWith({
    String? id,
    String? title,
    HistoryCategory? category,
    DateTime? modifiedAt,
    int? strokeCount,
    int? durationSeconds,
    bool? isFavorite,
    List<String>? tags,
    String? summary,
    String? thumbnailUrl,
  }) {
    return HistoryItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      strokeCount: strokeCount ?? this.strokeCount,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
      summary: summary ?? this.summary,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }

  IconData get icon {
    switch (category) {
      case HistoryCategory.whiteboard:
        return Icons.gesture_rounded;
      case HistoryCategory.docAnnotation:
        return Icons.description_rounded;
      case HistoryCategory.voiceSession:
        return Icons.mic_rounded;
      case HistoryCategory.all:
        return Icons.all_inclusive_rounded;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'category': category.name,
    'updated_at': modifiedAt.toIso8601String(),
    'total_shapes': strokeCount,
    'duration_seconds': durationSeconds,
    'is_favorite': isFavorite,
    'tags': tags,
    'description': summary,
    'thumbnailUrl': thumbnailUrl,
    'thumbnail_url': thumbnailUrl,
  };

  factory HistoryItemModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final catName = (json['category'] ?? 'whiteboard').toString().toLowerCase();
    HistoryCategory cat = HistoryCategory.whiteboard;
    if (catName.contains('doc') || catName.contains('annotation')) {
      cat = HistoryCategory.docAnnotation;
    } else if (catName.contains('voice') || catName.contains('audio')) {
      cat = HistoryCategory.voiceSession;
    }

    final dateStr = json['updated_at'] ?? json['updatedAt'] ?? json['created_at'] ?? json['createdAt'];

    final tagsRaw = json['tags'];
    List<String> tags = [];
    if (tagsRaw is List) {
      tags = tagsRaw.map((e) => e.toString()).toList();
    }

    // Thumbnails: thumbnailUrl / thumbnail_url / image fields, plus web-side
    // `preview_image` convention. Never a required field — null falls back to
    // an icon placeholder in the history list.
    final thumb = asStringOr(
      json['thumbnailUrl'] ?? json['thumbnail_url'] ?? json['preview_image'] ?? json['image'],
      '',
    );

    return HistoryItemModel(
      id: id ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Untitled Board',
      category: cat,
      modifiedAt: asDateOr(dateStr, DateTime.now()),
      strokeCount: asIntOr(json['total_shapes'] ?? json['strokeCount'] ?? json['shapeCount'], 0),
      durationSeconds: asIntOr(json['duration_seconds'] ?? json['durationSeconds'], 0),
      isFavorite: asBoolOr(json['is_favorite'] ?? json['isFavorite'], false),
      tags: tags,
      summary: json['description']?.toString() ?? json['summary']?.toString() ?? 'Interactive whiteboard canvas',
      thumbnailUrl: thumb.isEmpty ? null : thumb,
    );
  }
}
