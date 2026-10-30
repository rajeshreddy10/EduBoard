import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eduboard_mobile/models/user_profile_model.dart';
import 'package:eduboard_mobile/models/history_item_model.dart';
import 'package:eduboard_mobile/models/notification_item_model.dart';
import 'package:eduboard_mobile/models/app_settings_model.dart';
import 'package:eduboard_mobile/models/voice_block_model.dart';
import 'package:eduboard_mobile/models/whiteboard_stroke_model.dart';
import 'package:eduboard_mobile/models/security_info_model.dart';

void main() {
  group('Live Firestore Schema & Model Integrity Tests', () {
    test('UserProfileModel parses Firestore users collection document correctly', () {
      final firestoreDoc = {
        'id': 'usr_test123',
        'uid': 'usr_test123',
        'full_name': 'Prof. Alan Turing',
        'email': 'alan.turing@cambridge.edu',
        'role': 'teacher',
        'institution': 'Cambridge University',
        'department': 'Computer Science',
        'bio': 'Pioneer of theoretical computing.',
        'teachingPhilosophy': 'Formalize and verify.',
        'avatar': 'https://firebasestorage.googleapis.com/v0/b/eduboard-6fdcc.firebasestorage.app/o/users%2Fusr_test123%2Favatar',
        'subjects': ['Algorithms', 'Logic'],
      };

      final profile = UserProfileModel.fromJson(firestoreDoc);

      expect(profile.id, equals('usr_test123'));
      expect(profile.name, equals('Prof. Alan Turing'));
      expect(profile.email, equals('alan.turing@cambridge.edu'));
      expect(profile.role, equals('teacher'));
      expect(profile.avatarUrl, contains('eduboard-6fdcc.firebasestorage.app'));
      expect(profile.subjects.length, equals(2));

      final serialized = profile.toJson();
      expect(serialized['full_name'], equals('Prof. Alan Turing'));
      expect(serialized['uid'], equals('usr_test123'));
    });

    test('HistoryItemModel parses Firestore whiteboards collection document correctly', () {
      final firestoreBoard = {
        'title': 'Quantum Physics & Schrödinger Wave Equation',
        'description': 'Derivation of time-dependent wave equation in 3D potential wells.',
        'owner_id': 'usr_test123',
        'createdBy': 'usr_test123',
        'category': 'whiteboard',
        'total_shapes': 48,
        'duration_seconds': 1800,
        'is_favorite': true,
        'tags': ['Physics', 'Quantum'],
        'updated_at': '2026-10-28T07:00:00.000Z',
      };

      final item = HistoryItemModel.fromJson(firestoreBoard, 'wb_quantum_101');

      expect(item.id, equals('wb_quantum_101'));
      expect(item.title, equals('Quantum Physics & Schrödinger Wave Equation'));
      expect(item.category, equals(HistoryCategory.whiteboard));
      expect(item.strokeCount, equals(48));
      expect(item.isFavorite, isTrue);
      expect(item.tags, contains('Quantum'));
    });

    test('NotificationItemModel parses Firestore notifications collection correctly', () {
      final firestoreNotif = {
        'id': 'notif_999',
        'userId': 'usr_test123',
        'title': 'New Collaborative Whiteboard Invite',
        'message': 'Prof. Curie shared "Radioactivity Lecture" with you.',
        'type': 'classrooms',
        'read': false,
        'timestamp': '2026-10-28T07:15:00.000Z',
      };

      final notif = NotificationItemModel.fromJson(firestoreNotif);

      expect(notif.id, equals('notif_999'));
      expect(notif.title, equals('New Collaborative Whiteboard Invite'));
      expect(notif.category, equals(NotificationCategory.classrooms));
      expect(notif.isRead, isFalse);
    });

    test('AppSettingsModel parses Firestore userSettings collection correctly', () {
      final firestoreSettings = {
        'language': 'English (UK)',
        'timeZone': 'UTC+00:00 (London)',
        'region': 'Europe',
        'highContrast': true,
        'reduceMotion': false,
        'textScaleFactor': 1.15,
        'autoSyncOffline': true,
        'pendingLocalChanges': 0,
      };

      final settings = AppSettingsModel.fromJson(firestoreSettings);

      expect(settings.language, equals('English (UK)'));
      expect(settings.timeZone, contains('London'));
      expect(settings.highContrast, isTrue);
      expect(settings.textScaleFactor, equals(1.15));
    });

    test('VoiceBlockModel parses Firestore voice_transcriptions collection correctly', () {
      final firestoreTranscription = {
        'transcript': 'Evaluating the line integral along boundary curve C.',
        'speaker': 'Prof. Feynman',
        'duration_ms': 15000,
        'position_x': 50.0,
        'position_y': 250.0,
        'confidence': 0.98,
      };

      final voiceBlock = VoiceBlockModel.fromJson(firestoreTranscription, 'transcription_456');

      expect(voiceBlock.id, equals('transcription_456'));
      expect(voiceBlock.text, contains('line integral'));
      expect(voiceBlock.speakerName, equals('Prof. Feynman'));
      expect(voiceBlock.position, equals(const Offset(50.0, 250.0)));
      expect(voiceBlock.confidence, equals(0.98));
    });

    test('WhiteboardStroke parses vector points and tools correctly', () {
      const stroke = WhiteboardStroke(
        id: 'stroke_1',
        points: [StrokePoint(10.0, 20.0), StrokePoint(30.0, 40.0)],
        color: Color(0xFF38BDF8),
        strokeWidth: 4.0,
        tool: WhiteboardTool.pen,
      );

      expect(stroke.points.length, equals(2));
      expect(stroke.points.first.dx, equals(10.0));
      expect(stroke.tool, equals(WhiteboardTool.pen));
    });

    test('SecurityInfoModel parses and calculates scores dynamically', () {
      final initial = SecurityInfoModel.initial();
      expect(initial.authorizedDevices.length, equals(1));
      expect(initial.authorizedDevices.first.isCurrentDevice, isTrue);

      final updated = initial.copyWith(
        biometricsEnabled: true,
        twoFactorEnabled: true,
      );
      expect(updated.biometricsEnabled, isTrue);
      expect(updated.twoFactorEnabled, isTrue);
    });
  });
}

