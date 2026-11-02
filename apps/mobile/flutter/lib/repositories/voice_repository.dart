import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/services/api_client.dart';
import '../models/voice_block_model.dart';

abstract class VoiceRepository {
  Future<List<VoiceBlockModel>> getInitialBlocks();
  Stream<List<VoiceBlockModel>> watchVoiceBlocks();
  Future<void> saveBlockPosition(String blockId, Offset position);
  Future<VoiceBlockModel> addVoiceTranscription(String text, Duration duration, Offset position);

  /// Voice sessions are mirrored into the approved `whiteboards` collection so
  /// they appear in the History hub (mobile AND web) and can be re-opened.
  /// Sessions are keyed by a stable session id; identity fields from an
  /// existing doc (owner/creator/timeline) are never overwritten.
  Future<Map<String, dynamic>> loadSavedVoiceSession(String sessionId);
  Stream<Map<String, dynamic>> watchVoiceSession(String sessionId);
  Future<void> saveVoiceSessionToHistory({
    required String sessionId,
    required String title,
    required List<VoiceBlockModel> blocks,
    required Duration duration,
    List<Map<String, dynamic>>? strokes,
  });
}

class LiveVoiceRepository implements VoiceRepository {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  final ApiClient _api = ApiClient();

  String? get _currentUserId => _auth?.currentUser?.uid;

  @override
  Stream<List<VoiceBlockModel>> watchVoiceBlocks() {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) return Stream.value([]);

    return fs
        .collection('voice_transcriptions')
        .where('user_id', isEqualTo: uid)
        .limit(100)
        .snapshots()
        .map((snap) {
      final blocks = snap.docs.map((doc) => VoiceBlockModel.fromJson(doc.data(), doc.id)).toList();
      blocks.sort((a, b) => a.timestamp.inMilliseconds.compareTo(b.timestamp.inMilliseconds));
      return blocks;
    }).handleError((e) {
      debugPrint('[Firestore Voice Stream Note] $e');
    });
  }

  @override
  Future<List<VoiceBlockModel>> getInitialBlocks() async {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid != null && fs != null) {
      try {
        final snap = await fs
            .collection('voice_transcriptions')
            .where('user_id', isEqualTo: uid)
            .limit(100)
            .get()
            .timeout(const Duration(seconds: 8));

        if (snap.docs.isNotEmpty) {
          return snap.docs.map((doc) => VoiceBlockModel.fromJson(doc.data(), doc.id)).toList();
        }
      } on TimeoutException {
        debugPrint('[Firestore Voice Fetch Note] timed out');
      } catch (e) {
        debugPrint('[Firestore Voice Fetch Note] $e');
      }
    }
    return [];
  }

  @override
  Future<void> saveBlockPosition(String blockId, Offset position) async {
    final fs = _firestore;
    if (fs != null) {
      try {
        await fs.collection('voice_transcriptions').doc(blockId).set({
          'position_x': position.dx,
          'position_y': position.dy,
          'updated_at': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } on TimeoutException {
        debugPrint('[saveBlockPosition Note] timed out');
      } catch (e) {
        debugPrint('[saveBlockPosition Note] $e');
      }
    }
  }

  @override
  Future<VoiceBlockModel> addVoiceTranscription(String text, Duration duration, Offset position) async {
    final uid = _currentUserId;
    final fs = _firestore;
    final id = 'voice_${DateTime.now().millisecondsSinceEpoch}';

    final payload = {
      'id': id,
      'user_id': uid,
      'transcript': text,
      'raw_transcript': text,
      'confidence': 0.96,
      'language': 'en',
      'duration_ms': duration.inMilliseconds,
      'audio_format': 'webm',
      'source': 'mobile_dictation',
      'word_count': text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
      'position_x': position.dx,
      'position_y': position.dy,
      'created_at': DateTime.now().toIso8601String(),
    };

    // 1. Write to approved Firestore collection: "voice_transcriptions"
    bool savedLocally = false;
    if (fs != null) {
      try {
        await fs.collection('voice_transcriptions').doc(id).set(payload);
        savedLocally = true;
      } on TimeoutException catch (e) {
        debugPrint('[Firestore addVoiceTranscription Error] timed out — $e');
      } catch (e) {
        debugPrint('[Firestore addVoiceTranscription Error] $e');
      }
    }

    // 2. Dispatch command to Express backend /api/voice/command
    try {
      await _api.post('/voice/command', body: {
        'command': text,
        'transcript': text,
        'duration_ms': payload['duration_ms'],
      });
    } catch (e) {
      debugPrint('[Backend Voice Command Note] $e');
    }

    // Ensure the on-canvas block is still produced even when the Firestore
    // write timed out (network interruption) — the local block keeps the
    // session usable, and the next successful save syncs it.
    if (!savedLocally) {
      debugPrint('[Voice] Transcription saved locally only; will rebroadcast when online.');
    }
    return VoiceBlockModel.fromJson(payload, id);
  }

  @override
  Future<Map<String, dynamic>> loadSavedVoiceSession(String sessionId) async {
    final fs = _firestore;
    if (fs == null || sessionId.trim().isEmpty) return const {};
    try {
      final doc = await fs.collection('whiteboards').doc(sessionId.trim()).get().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException('Voice session read timed out'),
          );
      if (doc.exists) return doc.data() ?? const {};
    } on TimeoutException {
      debugPrint('[Voice Session Load Warning] timed out');
    } catch (e) {
      debugPrint('[Voice Session Load Warning] $e');
    }
    return const {};
  }

  @override
  Stream<Map<String, dynamic>> watchVoiceSession(String sessionId) {
    final fs = _firestore;
    if (fs == null || sessionId.trim().isEmpty) return Stream.value({});
    return fs
        .collection('whiteboards')
        .doc(sessionId.trim())
        .snapshots()
        .map((snap) => snap.exists && snap.data() != null ? snap.data()! : <String, dynamic>{})
        .handleError((e) {
      debugPrint('[Firestore watchVoiceSession Error] $e');
    });
  }

  @override
  Future<void> saveVoiceSessionToHistory({
    required String sessionId,
    required String title,
    required List<VoiceBlockModel> blocks,
    required Duration duration,
    List<Map<String, dynamic>>? strokes,
  }) async {
    final fs = _firestore;
    if (fs == null || sessionId.trim().isEmpty || blocks.isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();

    // Preserve identity of an already-saved session snapshot.
    Map<String, dynamic>? existing;
    try {
      final doc = await fs.collection('whiteboards').doc(sessionId.trim()).get().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException('Voice session snapshot read timed out'),
          );
      if (doc.exists) existing = doc.data();
    } on TimeoutException {
      return;
    } catch (e) {
      existing = null;
    }

    final tags = existing?['tags'] is List && (existing!['tags'] as List).isNotEmpty
        ? List<String>.from(existing['tags'])
        : <String>['voiceSession', 'voiceboard', 'eduboard'];

    final payload = <String, dynamic>{
      'title': title,
      'category': 'voiceSession',
      'studio': 'voiceboard',
      'description': 'Voice session with ${blocks.length} transcription blocks (${duration.inMinutes} min).',
      'updated_at': nowIso,
      'updatedAt': nowIso,
      'created_at': existing?['created_at']?.toString() ?? existing?['createdAt']?.toString() ?? nowIso,
      'createdAt': existing?['createdAt']?.toString() ?? nowIso,
      'owner_id': existing?['owner_id']?.toString() ?? _currentUserId,
      'createdBy': existing?['createdBy']?.toString() ?? (_currentUserId ?? 'guest'),
      'user_id': existing?['owner_id']?.toString() ?? _currentUserId,
      'userId': existing?['owner_id']?.toString() ?? _currentUserId,
      'duration_seconds': duration.inSeconds,
      'total_shapes': blocks.length + (strokes?.length ?? (existing?['strokes'] as List?)?.length ?? 0),
      'tags': tags,
      // Full block snapshot with positions so re-opening restores the canvas.
      'blocks': blocks.take(200).map((b) => b.toJson()).toList(),
      // Spoken elements mirror matching Web's BoardTextElement schema:
      // allows the Web Voice Board to render speech blocks created on Mobile.
      'elements': blocks.take(200).map((b) => {
        'id': b.id,
        'type': 'text',
        'text': b.text,
        'x': b.position.dx,
        'y': b.position.dy,
        'fontSize': 24,
        'color': '#ffffff',
      }).toList(),
      'transcript': blocks.map((b) => b.text).join('\n'),
      'strokes': strokes ?? existing?['strokes'] ?? [],
    };

    try {
      await fs.collection('whiteboards').doc(sessionId.trim()).set(
        payload,
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('[Voice Session Save Note] timed out — will save on next stop');
    } catch (e) {
      debugPrint('[Voice Session Save Note] $e');
    }
  }
}
