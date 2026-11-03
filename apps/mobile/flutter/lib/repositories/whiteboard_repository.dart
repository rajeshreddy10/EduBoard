import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/services/api_client.dart';
import '../core/services/socket_service.dart';
import '../models/whiteboard_stroke_model.dart';
import '../core/utilities/safe_json.dart';

abstract class WhiteboardRepository {
  Stream<List<WhiteboardStroke>> watchBoardStrokes(String boardId);
  Stream<Map<String, dynamic>> watchActiveBoard(String boardId);
  Future<List<WhiteboardStroke>> loadActiveBoardStrokes(String boardId);
  Future<void> saveStroke(String boardId, WhiteboardStroke stroke);
  Future<void> deleteStroke(String boardId, String strokeId);
  Future<void> clearBoard(String boardId);
  Future<List<TeacherNote>> loadTeacherNotes(String boardId);
  Future<void> addTeacherNote(String boardId, TeacherNote note);

  /// Floating text elements. Persisted on the board document as the `elements`
  /// array (the same convention the Web app writes/reads), so text placed on a
  /// phone re-opens on Web and vice versa.
  Future<List<WhiteboardTextElement>> loadTextElements(String boardId);
  Future<void> saveTextElements(String boardId, List<WhiteboardTextElement> elements);

  /// Lightweight board-document read: `{title, description}` (empty strings
  /// when the doc does not exist / is unreachable). Used when opening a saved
  /// board so its ORIGINAL title is restored, never overwritten.
  Future<Map<String, dynamic>> loadBoardMeta(String boardId);

  /// Full board auto-save: upserts the board document (title, description,
  /// counts, timestamps, ownership, studio) AND mirrors the strokes array on
  /// the document so Web's history/restore reads mobile-created boards.
  /// Identity fields (`owner_id`, `createdBy`, `created_at`, `createdAt`,
  /// favorites, thumbnails) are preserved when the board already exists.
  Future<void> saveBoardSnapshot(
    String boardId, {
    required String title,
    String? description,
    required List<WhiteboardStroke> strokes,
    required List<WhiteboardTextElement> textElements,
    String studio = 'drawspace',
    String category = 'whiteboard',
  });
}

class LiveWhiteboardRepository implements WhiteboardRepository {
  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final ApiClient _api = ApiClient();
  final SocketService _socket = SocketService();

  @override
  Stream<List<WhiteboardStroke>> watchBoardStrokes(String boardId) {
    _socket.connectAsync();
    _socket.joinBoard(boardId);

    final fs = _firestore;
    if (fs == null) return Stream.value([]);

    return fs
        .collection('whiteboards')
        .doc(boardId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return <WhiteboardStroke>[];
      final data = doc.data()!;
      if (data['strokes'] is List && (data['strokes'] as List).isNotEmpty) {
        final list = data['strokes'] as List;
        return list.whereType<Map>().map((s) => _mapMapToStroke(Map<String, dynamic>.from(s))).toList();
      } else if (data['content'] is String && (data['content'] as String).trim().isNotEmpty) {
        try {
          final parsed = jsonDecode(data['content'] as String);
          if (parsed is Map && parsed['strokes'] is List) {
            return (parsed['strokes'] as List)
                .whereType<Map>()
                .map((s) => _mapMapToStroke(Map<String, dynamic>.from(s)))
                .toList();
          } else if (parsed is List) {
            return parsed
                .whereType<Map>()
                .map((s) => _mapMapToStroke(Map<String, dynamic>.from(s)))
                .toList();
          }
        } catch (_) {}
      }
      return <WhiteboardStroke>[];
    }).handleError((e) {
      debugPrint('[Whiteboard Stream Warning] $e');
    });
  }

  @override
  Stream<Map<String, dynamic>> watchActiveBoard(String boardId) {
    _socket.connectAsync();
    _socket.joinBoard(boardId);

    final fs = _firestore;
    if (fs == null) return Stream.value({});

    return fs
        .collection('whiteboards')
        .doc(boardId)
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) return <String, dynamic>{};
      final data = doc.data()!;

      List<WhiteboardStroke> strokes = [];
      if (data['strokes'] is List && (data['strokes'] as List).isNotEmpty) {
        final list = data['strokes'] as List;
        strokes = list.whereType<Map>().map((s) => _mapMapToStroke(Map<String, dynamic>.from(s))).toList();
      } else if (data['content'] is String && (data['content'] as String).trim().isNotEmpty) {
        try {
          final parsed = jsonDecode(data['content'] as String);
          if (parsed is Map && parsed['strokes'] is List) {
            strokes = (parsed['strokes'] as List)
                .whereType<Map>()
                .map((s) => _mapMapToStroke(Map<String, dynamic>.from(s)))
                .toList();
          } else if (parsed is List) {
            strokes = parsed
                .whereType<Map>()
                .map((s) => _mapMapToStroke(Map<String, dynamic>.from(s)))
                .toList();
          }
        } catch (_) {}
      }

      List<WhiteboardTextElement> elements = [];
      if (data['elements'] is List) {
        elements = (data['elements'] as List)
            .whereType<Map>()
            .map((e) => _mapMapToTextElement(Map<String, dynamic>.from(e)))
            .toList();
      } else if (data['content'] is String && (data['content'] as String).trim().isNotEmpty) {
        try {
          final parsed = jsonDecode(data['content'] as String);
          if (parsed is Map && parsed['elements'] is List) {
            elements = (parsed['elements'] as List)
                .whereType<Map>()
                .map((e) => _mapMapToTextElement(Map<String, dynamic>.from(e)))
                .toList();
          }
        } catch (_) {}
      }

      return {
        'title': data['title']?.toString(),
        'description': data['description']?.toString(),
        'strokes': strokes,
        'elements': elements,
        'hasPendingWrites': doc.metadata.hasPendingWrites,
      };
    }).handleError((e) {
      debugPrint('[Active Board Watch Warning] $e');
    });
  }

  @override
  Future<List<WhiteboardStroke>> loadActiveBoardStrokes(String boardId) async {
    final fs = _firestore;
    if (fs != null) {
      try {
        // 1. FIRST: Check the board document itself (whiteboards/{boardId}).
        // Both Web and Mobile persist the full strokes array directly on the board doc!
        final boardDoc = await fs
            .collection('whiteboards')
            .doc(boardId)
            .get()
            .timeout(const Duration(seconds: 8));

        if (boardDoc.exists && boardDoc.data() != null) {
          final data = boardDoc.data()!;
          if (data['strokes'] is List && (data['strokes'] as List).isNotEmpty) {
            final strokesList = data['strokes'] as List;
            return strokesList
                .whereType<Map>()
                .map((s) => _mapMapToStroke(Map<String, dynamic>.from(s)))
                .toList();
          } else if (data['annotations'] is List && (data['annotations'] as List).isNotEmpty) {
            final annList = data['annotations'] as List;
            return annList
                .whereType<Map>()
                .map((s) => _mapMapToStroke(Map<String, dynamic>.from(s)))
                .toList();
          } else if (data['shapes'] is List && (data['shapes'] as List).isNotEmpty) {
            final shapesList = data['shapes'] as List;
            return shapesList
                .whereType<Map>()
                .map((s) => _mapMapToStroke(Map<String, dynamic>.from(s)))
                .toList();
          } else if (data['content'] is String && (data['content'] as String).trim().isNotEmpty) {
            try {
              final parsed = jsonDecode(data['content'] as String);
              if (parsed is Map) {
                final list = (parsed['strokes'] ?? parsed['annotations'] ?? parsed['shapes']) as List?;
                if (list != null && list.isNotEmpty) {
                  return list
                      .whereType<Map>()
                      .map((s) => _mapMapToStroke(Map<String, dynamic>.from(s)))
                      .toList();
                }
              } else if (parsed is List) {
                return parsed
                    .whereType<Map>()
                    .map((s) => _mapMapToStroke(Map<String, dynamic>.from(s)))
                    .toList();
              }
            } catch (_) {}
          }
        }

        // 2. SECOND: Check subcollection shapes (live real-time stroke stream fallback)
        final snap = await fs
            .collection('whiteboards')
            .doc(boardId)
            .collection('shapes')
            .limit(600)
            .get()
            .timeout(const Duration(seconds: 8));

        if (snap.docs.isNotEmpty) {
          return snap.docs.map((doc) => _mapDocToStroke(doc.id, doc.data())).toList();
        }
      } on TimeoutException {
        debugPrint('[Whiteboard Load Warning] timed out — resuming empty board');
      } catch (e) {
        debugPrint('[Whiteboard Load Warning] $e');
      }
    }

    // Fallback to Express API GET /api/whiteboards/:id
    try {
      final res = await _api.get('/whiteboards/$boardId');
      if (res is Map && res['shapes'] is List) {
        final shapes = res['shapes'] as List;
        return shapes.whereType<Map>().map((s) => _mapMapToStroke(Map<String, dynamic>.from(s))).toList();
      }
    } catch (_) {}

    return [];
  }

  @override
  Future<void> saveStroke(String boardId, WhiteboardStroke stroke) async {
    final shapeData = _mapStrokeToMap(stroke);
    final fs = _firestore;

    // 1. Persist to Firestore sub-collection: whiteboards/{boardId}/shapes/{shapeId}
    // AND mirror onto whiteboards/{boardId} doc strokes array for instant cross-device sync
    if (fs != null) {
      try {
        final compressed = _compressStrokeForDoc(stroke);
        await Future.wait([
          fs
              .collection('whiteboards')
              .doc(boardId)
              .collection('shapes')
              .doc(stroke.id)
              .set(shapeData, SetOptions(merge: true))
              .timeout(const Duration(seconds: 10)),
          fs
              .collection('whiteboards')
              .doc(boardId)
              .set({
                'strokes': FieldValue.arrayUnion([compressed]),
                'total_shapes': FieldValue.increment(1),
                'strokeCount': FieldValue.increment(1),
                'updated_at': DateTime.now().toIso8601String(),
                'updatedAt': DateTime.now().toIso8601String(),
              }, SetOptions(merge: true))
              .timeout(const Duration(seconds: 10)),
        ]);
      } on TimeoutException {
        debugPrint('[Firestore Save Stroke Note] timed out — stroke kept in memory');
      } catch (e) {
        debugPrint('[Firestore Save Stroke Note] $e');
      }
    }

    // 2. Real-time broadcast via Socket.IO to web collaborators
    if (_socket.isConnected) {
      try {
        _socket.emitShapeAdd(boardId, shapeData);
      } catch (e) {
        debugPrint('[Socket Emit Stroke Note] $e');
      }
    }
  }

  @override
  Future<void> deleteStroke(String boardId, String strokeId) async {
    final fs = _firestore;
    if (fs != null) {
      try {
        await fs
            .collection('whiteboards')
            .doc(boardId)
            .collection('shapes')
            .doc(strokeId)
            .delete()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        debugPrint('[Whiteboard Delete Stroke Note] $e');
      }
    }

    if (_socket.isConnected) {
      try {
        _socket.emitShapeDelete(boardId, strokeId);
      } catch (_) {}
    }
  }

  @override
  Future<void> clearBoard(String boardId) async {
    final fs = _firestore;
    if (fs != null) {
      try {
        final snap = await fs
            .collection('whiteboards')
            .doc(boardId)
            .collection('shapes')
            .limit(600)
            .get()
            .timeout(const Duration(seconds: 10));
        final batch = fs.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        if (snap.docs.isNotEmpty) {
          await batch.commit();
        }
      } on TimeoutException {
        debugPrint('[Whiteboard Clear Note] timed out');
      } catch (e) {
        debugPrint('[Whiteboard Clear Note] $e');
      }
    }

    if (_socket.isConnected) {
      try {
        _socket.emitClearBoard(boardId);
      } catch (_) {}
    }
  }

  @override
  Future<List<TeacherNote>> loadTeacherNotes(String boardId) async {
    try {
      final doc = await _firestore
          ?.collection('whiteboards')
          .doc(boardId)
          .get()
          .timeout(const Duration(seconds: 8));
      if (doc != null && doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final rawNotes = data['teacherNotes'] ?? data['teacher_notes'];
        if (rawNotes is List) {
          return rawNotes.whereType<Map>().take(100).map((n) {
            final m = Map<String, dynamic>.from(n);
            final text = m['text']?.toString() ?? m['content']?.toString() ?? '';
            return TeacherNote(
              id: m['id']?.toString() ?? 'tn_${DateTime.now().millisecondsSinceEpoch}',
              title: m['title']?.toString() ?? (text.isNotEmpty ? text : 'Note'),
              content: text,
              createdAt: asDateOr(m['createdAt'] ?? m['timestamp'], DateTime.now()),
            );
          }).toList();
        }
      }
    } on TimeoutException {
      debugPrint('[Teacher Notes Load Warning] timed out');
    } catch (e) {
      debugPrint('[Teacher Notes Load Warning] $e');
    }

    return [];
  }

  @override
  Future<void> addTeacherNote(String boardId, TeacherNote note) async {
    try {
      final noteMap = {
        'id': note.id,
        'title': note.title,
        'content': note.content,
        'text': note.content,
        'timestamp': note.createdAt.toIso8601String(),
        'createdAt': note.createdAt.toIso8601String(),
      };
      await _firestore?.collection('whiteboards').doc(boardId).set({
        'teacherNotes': FieldValue.arrayUnion([noteMap]),
        'teacher_notes': FieldValue.arrayUnion([noteMap]),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('[Add Teacher Note Warning] timed out');
    } catch (e) {
      debugPrint('[Add Teacher Note Warning] $e');
    }
  }

  @override
  Future<Map<String, dynamic>> loadBoardMeta(String boardId) async {
    final fs = _firestore;
    if (fs == null) return const {};
    try {
      final doc = await fs.collection('whiteboards').doc(boardId).get().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException('Board meta read timed out'),
          );
      return doc.data() ?? const {};
    } on TimeoutException {
      debugPrint('[Board Meta Load Warning] timed out');
    } catch (e) {
      debugPrint('[Board Meta Load Warning] $e');
    }
    return const {};
  }

  @override
  Future<List<WhiteboardTextElement>> loadTextElements(String boardId) async {
    final fs = _firestore;
    if (fs == null) return [];

    try {
      final doc = await fs.collection('whiteboards').doc(boardId).get().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException('Text elements read timed out'),
          );
      if (!doc.exists) return [];

      final data = doc.data() ?? const <String, dynamic>{};
      List elements;
      if (data['elements'] is List) {
        // Live convention: `elements` array written by Web & Mobile.
        elements = data['elements'] as List;
      } else if (data['content'] is String) {
        // Legacy convention: JSON string inside `content`.
        try {
          final parsed = jsonDecode(data['content'] as String);
          if (parsed is Map && parsed['elements'] is List) {
            elements = parsed['elements'] as List;
          } else {
            return [];
          }
        } catch (_) {
          return [];
        }
      } else {
        return [];
      }

      return elements
          .whereType<Map>()
          .take(200)
          .map((e) => _mapMapToTextElement(Map<String, dynamic>.from(e)))
          .where((e) => e.text.trim().isNotEmpty)
          .toList();
    } on TimeoutException {
      debugPrint('[Text Elements Load Warning] timed out');
    } catch (e) {
      debugPrint('[Text Elements Load Warning] $e');
    }
    return [];
  }

  @override
  Future<void> saveTextElements(String boardId, List<WhiteboardTextElement> elements) async {
    final fs = _firestore;
    if (fs == null) return;
    try {
      await fs.collection('whiteboards').doc(boardId).set({
        'elements': elements.take(200).map(_mapTextElementToMap).toList(),
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('[Text Elements Save Note] timed out — elements kept in memory');
    } catch (e) {
      debugPrint('[Text Elements Save Note] $e');
    }
  }

  @override
  Future<void> saveBoardSnapshot(
    String boardId, {
    required String title,
    String? description,
    required List<WhiteboardStroke> strokes,
    required List<WhiteboardTextElement> textElements,
    String studio = 'drawspace',
    String category = 'whiteboard',
  }) async {
    final fs = _firestore;
    if (fs == null) return;

    final nowIso = DateTime.now().toIso8601String();

    // Read the existing record first (single read) so identity, timeline and
    // user markers (favorites/thumbnails set from Web) are never overwritten.
    Map<String, dynamic>? existing;
    try {
      final doc = await fs.collection('whiteboards').doc(boardId).get().timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException('Board snapshot read timed out'),
          );
      if (doc.exists) existing = doc.data();
    } on TimeoutException {
      debugPrint('[Board Auto-Save Note] skipped this cycle (offline)');
      return;
    } catch (e) {
      debugPrint('[Board Auto-Save Note] $e');
      existing = null;
    }

    final ownerId = existing?['owner_id']?.toString() ?? _currentUserId;
    final createdBy = existing?['createdBy']?.toString() ?? _currentUserId;
    final createdAt = existing?['created_at']?.toString() ?? existing?['createdAt']?.toString() ?? nowIso;
    final tagList = existing?['tags'] is List && (existing!['tags'] as List).isNotEmpty
        ? List<String>.from(existing['tags'])
        : <String>[category, studio, 'eduboard'];

    final payload = <String, dynamic>{
      'title': title,
      'category': category,
      // `total_shapes`/`strokeCount`/`shapeCount` keep all three client
      // projections (mobile history, web Board, backend API) in agreement.
      'total_shapes': strokes.length,
      'strokeCount': strokes.length,
      'shapeCount': strokes.length,
      'description': description ??
          'Interactive canvas session with ${strokes.length} strokes and ${textElements.length} text elements.',
      'updated_at': nowIso,
      'updatedAt': nowIso,
      // Mirror the strokes on the document (capacity-guarded) so Web's
      // restore path and cross-device history open see mobile-drawn content.
      'strokes': strokes.take(600).map(_compressStrokeForDoc).toList(),
      'elements': textElements.take(200).map(_mapTextElementToMap).toList(),
      'content': jsonEncode({
        'strokes': strokes.take(600).map(_compressStrokeForDoc).toList(),
        'elements': textElements.take(200).map(_mapTextElementToMap).toList(),
      }),
      // Only stamp ownership/timeline fields when creating a NEW board —
      // re-opening a board from History must never fork its identity.
      'owner_id': ownerId,
      'createdBy': createdBy ?? 'guest',
      'user_id': ownerId,
      'userId': ownerId,
      'created_at': createdAt,
      'createdAt': createdAt,
      'tags': tagList,
      'studio': existing?['studio']?.toString() ?? studio,
    };

    try {
      await fs.collection('whiteboards').doc(boardId).set(
        payload,
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 10));
    } on TimeoutException {
      debugPrint('[Board Auto-Save Note] write timed out — will retry on next change');
    } catch (e) {
      debugPrint('[Board Auto-Save Note] $e');
    }
  }

  String? get _currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Doc-size guard for the strokes mirror: rounded coordinates (1 decimal)
  /// and capped point counts, matching the Web compression strategy.
  Map<String, dynamic> _compressStrokeForDoc(WhiteboardStroke stroke) {
    final hexColor = '#${(stroke.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return {
      'id': stroke.id,
      'tool': stroke.tool.name,
      'type': stroke.shapeType != null ? 'shape' : stroke.tool.name,
      'shape': stroke.shapeType?.name,
      'shapeType': stroke.shapeType?.name,
      'color': hexColor,
      'colorHex': hexColor,
      'width': stroke.strokeWidth,
      'strokeWidth': stroke.strokeWidth,
      'opacity': 1.0,
      'points': stroke.points
          .take(1200)
          .map((p) => {
                'x': (p.x * 10).roundToDouble() / 10,
                'y': (p.y * 10).roundToDouble() / 10,
                'pressure': (p.pressure * 100).roundToDouble() / 100,
                'p': (p.pressure * 100).roundToDouble() / 100,
              })
          .toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _mapTextElementToMap(WhiteboardTextElement e) {
    // Shape matches Web's BoardTextElement: {id, text, x, y, fontSize, color}.
    return {
      'id': e.id,
      'text': e.text,
      'x': e.position.dx,
      'y': e.position.dy,
      'fontSize': e.fontSize,
      // Alpha-stripped hex string ('#ff0000') — the CSS color Web expects.
      'color': '#${(e.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
    };
  }

  WhiteboardTextElement _mapMapToTextElement(Map<String, dynamic> data) {
    Offset position = Offset.zero;
    if (data['position'] is Map) {
      final m = Map<String, dynamic>.from(data['position'] as Map);
      position = Offset(asDoubleOr(m['dx'] ?? m['x'], 0), asDoubleOr(m['dy'] ?? m['y'], 0));
    } else {
      position = Offset(asDoubleOr(data['x'], 0), asDoubleOr(data['y'], 0));
    }

    Color color = Colors.black;
    final rawColor = data['color'];
    if (rawColor is String) {
      final hex = rawColor.replaceAll('#', '').trim();
      final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (parsed != null) color = Color(parsed);
    } else if (rawColor is int) {
      color = Color(rawColor);
    } else if (rawColor is num) {
      color = Color(rawColor.toInt());
    }

    return WhiteboardTextElement(
      id: data['id']?.toString() ?? 'text_${DateTime.now().millisecondsSinceEpoch}',
      position: position,
      text: data['text']?.toString() ?? '',
      color: color,
      fontSize: asDoubleOr(data['fontSize'], 20.0),
    );
  }

  Map<String, dynamic> _mapStrokeToMap(WhiteboardStroke stroke) {
    final hexColor = '#${(stroke.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    return {
      'id': stroke.id,
      'tool': stroke.tool.name,
      'type': stroke.shapeType != null ? 'shape' : stroke.tool.name,
      'shape': stroke.shapeType?.name,
      'shapeType': stroke.shapeType?.name,
      'color': hexColor,
      'colorHex': hexColor,
      'strokeWidth': stroke.strokeWidth,
      'width': stroke.strokeWidth,
      'opacity': 1.0,
      'points': stroke.points.map((p) => p.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  WhiteboardStroke _mapDocToStroke(String id, Map<String, dynamic> data) {
    return _mapMapToStroke({'id': id, ...data});
  }

  WhiteboardStroke _mapMapToStroke(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? 'stroke_${DateTime.now().millisecondsSinceEpoch}';
    final pointsList = data['points'] as List<dynamic>? ?? [];
    // Cap the number of points so a malformed/huge stroke cannot blow up memory
    // or the raster cache while rendering.
    final points = pointsList
        .take(2000)
        .map((p) {
          if (p is Map) return StrokePoint.fromJson(Map<String, dynamic>.from(p));
          return const StrokePoint(0, 0);
        })
        .toList();

    // Color can arrive as:
    // 1. CSS hex string ('#ffffff' or '#3b82f6') from Web
    // 2. int or num (4294967295)
    Color color = Colors.white;
    final rawColor = data['color'];
    final rawColorHex = data['colorHex'];

    if (rawColor is String && rawColor.contains('#')) {
      final hex = rawColor.replaceAll('#', '').trim();
      final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (parsed != null) color = Color(parsed);
    } else if (rawColorHex is String && rawColorHex.contains('#')) {
      final hex = rawColorHex.replaceAll('#', '').trim();
      final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (parsed != null) color = Color(parsed);
    } else if (rawColor is int) {
      color = Color(rawColor);
    } else if (rawColor is num) {
      color = Color(rawColor.toInt());
    }

    final toolName = data['tool']?.toString() ?? data['type']?.toString() ?? 'pen';
    WhiteboardTool tool = WhiteboardTool.pen;
    for (final t in WhiteboardTool.values) {
      if (t.name == toolName) {
        tool = t;
        break;
      }
    }
    if (toolName == 'area-eraser') tool = WhiteboardTool.eraser;

    final shapeName = data['shape']?.toString() ?? data['shapeType']?.toString();
    WhiteboardShapeType? shapeType;
    if (shapeName != null) {
      for (final s in WhiteboardShapeType.values) {
        if (s.name == shapeName) {
          shapeType = s;
          break;
        }
      }
    }

    final strokeWidth = (data['width'] ?? data['strokeWidth'] as num?)?.toDouble() ?? 3.0;

    return WhiteboardStroke(
      id: id,
      points: points,
      color: color,
      strokeWidth: strokeWidth,
      tool: tool,
      shapeType: shapeType,
    );
  }
}
