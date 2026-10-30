import 'package:flutter/material.dart';

import '../core/utilities/safe_json.dart';

enum NotificationCategory { all, system, classrooms, mentions }

/// Academic and whiteboard collaboration notification item
class NotificationItemModel {
  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final DateTime timestamp;
  final bool isRead;
  final IconData icon;

  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.timestamp,
    this.isRead = false,
    this.icon = Icons.notifications_active_rounded,
  });

  NotificationItemModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationCategory? category,
    DateTime? timestamp,
    bool? isRead,
    IconData? icon,
  }) {
    return NotificationItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'type': category.name,
    'timestamp': timestamp.toIso8601String(),
    'read': isRead,
  };

  factory NotificationItemModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final typeStr = (json['type'] ?? json['category'] ?? 'system').toString().toLowerCase();
    NotificationCategory cat = NotificationCategory.system;
    IconData icon = Icons.notifications_active_rounded;

    if (typeStr.contains('mention') || typeStr.contains('forum')) {
      cat = NotificationCategory.mentions;
      icon = Icons.forum_rounded;
    } else if (typeStr.contains('class') || typeStr.contains('room')) {
      cat = NotificationCategory.classrooms;
      icon = Icons.event_note_rounded;
    } else if (typeStr.contains('cloud') || typeStr.contains('sync')) {
      cat = NotificationCategory.system;
      icon = Icons.cloud_done_rounded;
    } else {
      cat = NotificationCategory.system;
      icon = Icons.info_outline_rounded;
    }

    final timeStr = json['timestamp'] ?? json['created_at'];

    return NotificationItemModel(
      id: id ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      category: cat,
      timestamp: asDateOr(timeStr, DateTime.now()),
      isRead: asBoolOr(json['read'] ?? json['isRead'], false),
      icon: icon,
    );
  }
}
