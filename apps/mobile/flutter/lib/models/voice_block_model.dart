import 'package:flutter/material.dart';

import '../core/utilities/safe_json.dart';

enum VoiceBlockStatus { recording, processing, finalized }

/// Draggable speech transcription block model
class VoiceBlockModel {
  final String id;
  final String text;
  final String speakerName;
  final Duration timestamp;
  final Offset position;
  final VoiceBlockStatus status;
  final Color highlightColor;
  final double confidence;
  final double width;
  final String? groupId;

  const VoiceBlockModel({
    required this.id,
    required this.text,
    required this.speakerName,
    required this.timestamp,
    required this.position,
    this.status = VoiceBlockStatus.finalized,
    this.highlightColor = const Color(0xFF6366F1),
    this.confidence = 0.95,
    this.width = 290.0,
    this.groupId,
  });

  VoiceBlockModel copyWith({
    String? id,
    String? text,
    String? speakerName,
    Duration? timestamp,
    Offset? position,
    VoiceBlockStatus? status,
    Color? highlightColor,
    double? confidence,
    double? width,
    String? groupId,
  }) {
    return VoiceBlockModel(
      id: id ?? this.id,
      text: text ?? this.text,
      speakerName: speakerName ?? this.speakerName,
      timestamp: timestamp ?? this.timestamp,
      position: position ?? this.position,
      status: status ?? this.status,
      highlightColor: highlightColor ?? this.highlightColor,
      confidence: confidence ?? this.confidence,
      width: width ?? this.width,
      groupId: groupId ?? this.groupId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'transcript': text,
    'speaker': speakerName,
    'duration_ms': timestamp.inMilliseconds,
    'position_x': position.dx,
    'position_y': position.dy,
    'confidence': confidence,
  };

  factory VoiceBlockModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final text = (json['transcript'] ?? json['text'] ?? '').toString();
    final speaker = (json['speaker'] ?? json['speakerName'] ?? 'Instructor').toString();
    final durMs = asIntOr(json['duration_ms'], 0);
    final px = asDoubleOr(json['position_x'], 40.0);
    final py = asDoubleOr(json['position_y'], 160.0);
    final conf = asDoubleOr(json['confidence'], 0.95);

    return VoiceBlockModel(
      id: id ?? json['id']?.toString() ?? 'voice_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      speakerName: speaker,
      timestamp: Duration(milliseconds: durMs),
      position: Offset(px, py),
      confidence: conf,
      status: VoiceBlockStatus.finalized,
    );
  }
}
