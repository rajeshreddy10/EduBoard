import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/doc_annotation_model.dart';
import '../core/utilities/safe_json.dart';

abstract class DocumentRepository {
  Future<List<DocumentModel>> getDocuments([String? explicitUid]);
  Future<DocumentModel?> loadDocument(String docId);
  Future<List<DocAnnotationModel>> getAnnotations(String docId);
  Future<void> saveAnnotation(String docId, DocAnnotationModel annotation);
  Future<void> deleteAnnotation(String docId, String annotationId);
  Future<void> saveDocSession({
    required String docId,
    required DocumentModel document,
    required List<DocAnnotationModel> annotations,
  });
}

class FirestoreDocumentRepository implements DocumentRepository {
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

  String? get _currentUserId => _auth?.currentUser?.uid;

  @override
  Future<List<DocumentModel>> getDocuments([String? explicitUid]) async {
    final uid = explicitUid ?? _currentUserId;
    final fs = _firestore;
    if (uid != null && fs != null) {
      try {
        final results = await Future.wait([
          fs.collection('whiteboards').where('owner_id', isEqualTo: uid).get(),
          fs.collection('whiteboards').where('createdBy', isEqualTo: uid).get(),
          fs.collection('whiteboards').where('userId', isEqualTo: uid).get(),
          fs.collection('whiteboards').where('user_id', isEqualTo: uid).get(),
        ]).catchError((_) => <QuerySnapshot<Map<String, dynamic>>>[]);

        final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final snap in results) {
          for (final doc in snap.docs) {
            allDocs[doc.id] = doc;
          }
        }

        if (allDocs.isNotEmpty) {
          final docs = allDocs.values.where((d) {
            final data = d.data();
            final studio = data['studio']?.toString();
            final category = data['category']?.toString();
            return studio == 'doccanvas' || category == 'docAnnotation' || data['activeDocument'] != null;
          }).map((d) {
            final data = d.data();
            if (data['activeDocument'] is Map) {
              return DocumentModel.fromJson(Map<String, dynamic>.from(data['activeDocument'] as Map), d.id);
            }
            return DocumentModel.fromJson(data, d.id);
          }).toList();

          if (docs.isNotEmpty) return docs;
        }
      } catch (e) {
        debugPrint('[Firestore getDocuments Note] $e');
      }
    }

    return [];
  }

  @override
  Future<DocumentModel?> loadDocument(String docId) async {
    final fs = _firestore;
    if (fs == null || docId.trim().isEmpty) return null;
    try {
      final docSnap = await fs.collection('whiteboards').doc(docId.trim()).get();
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;
        if (data['activeDocument'] is Map) {
          return DocumentModel.fromJson(Map<String, dynamic>.from(data['activeDocument'] as Map), docId);
        }
        return DocumentModel.fromJson(data, docId);
      }
    } catch (e) {
      debugPrint('[loadDocument Note] $e');
    }
    return null;
  }

  @override
  Future<List<DocAnnotationModel>> getAnnotations(String docId) async {
    final fs = _firestore;
    if (fs == null || docId.trim().isEmpty) return [];

    try {
      // 1. FIRST: Check the whiteboards/{docId} document directly.
      // Web and unified saves store annotations/strokes directly on this doc!
      final docSnap = await fs.collection('whiteboards').doc(docId.trim()).get();
      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;

        // Case A: Document has explicit 'annotations' array
        if (data['annotations'] is List && (data['annotations'] as List).isNotEmpty) {
          final list = data['annotations'] as List;
          return list
              .whereType<Map>()
              .map((m) => DocAnnotationModel.fromJson(Map<String, dynamic>.from(m)))
              .toList();
        }

        // Case B: Document has 'strokes' array (drawn on Web!)
        if (data['strokes'] is List && (data['strokes'] as List).isNotEmpty) {
          final list = data['strokes'] as List;
          return list.whereType<Map>().map((s) {
            final id = s['id']?.toString() ?? 'ann_${DateTime.now().millisecondsSinceEpoch}';
            final pts = (s['points'] as List<dynamic>? ?? []).whereType<Map>().map((p) {
              return Offset(asDoubleOr(p['x'], 0), asDoubleOr(p['y'], 0));
            }).toList();

            Color color = const Color(0xFFFFD54F);
            final rawColor = s['color'];
            if (rawColor is String && rawColor.contains('#')) {
              final hex = rawColor.replaceAll('#', '').trim();
              final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
              if (parsed != null) color = Color(parsed);
            }

            final tool = s['tool']?.toString();
            DocAnnotationType type = DocAnnotationType.pen;
            if (tool == 'highlighter') type = DocAnnotationType.highlight;
            if (tool == 'text') type = DocAnnotationType.text;

            return DocAnnotationModel(
              id: id,
              pageIndex: 1,
              type: type,
              points: pts,
              color: color,
              strokeWidth: asDoubleOr(s['width'] ?? s['strokeWidth'], 3.0),
              createdAt: DateTime.now(),
            );
          }).toList();
        }
      }

      // 2. SECOND: Fallback to shapes subcollection
      final snap = await fs
          .collection('whiteboards')
          .doc(docId)
          .collection('shapes')
          .limit(300)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => DocAnnotationModel.fromJson(d.data(), d.id)).toList();
      }
    } catch (e) {
      debugPrint('[Firestore getAnnotations Note] $e');
    }
    return [];
  }

  @override
  Future<void> saveAnnotation(String docId, DocAnnotationModel annotation) async {
    try {
      await _firestore
          ?.collection('whiteboards')
          .doc(docId)
          .collection('shapes')
          .doc(annotation.id)
          .set({
        ...annotation.toJson(),
        'type': 'annotation_${annotation.type.name}',
        'is_annotation': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore saveAnnotation Error] $e');
    }
  }

  @override
  Future<void> deleteAnnotation(String docId, String annotationId) async {
    try {
      await _firestore
          ?.collection('whiteboards')
          .doc(docId)
          .collection('shapes')
          .doc(annotationId)
          .delete();
    } catch (e) {
      debugPrint('[Firestore deleteAnnotation Error] $e');
    }
  }

  @override
  Future<void> saveDocSession({
    required String docId,
    required DocumentModel document,
    required List<DocAnnotationModel> annotations,
  }) async {
    final fs = _firestore;
    if (fs == null || docId.trim().isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();
    final uid = _currentUserId ?? 'guest';

    // Serialize annotations as Web DrawingStroke format so Web renders them
    final strokesForWeb = annotations.map((a) {
      final hexColor = '#${(a.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
      return {
        'id': a.id,
        'tool': a.type == DocAnnotationType.highlight ? 'highlighter' : (a.type == DocAnnotationType.text ? 'text' : 'pen'),
        'color': hexColor,
        'colorHex': hexColor,
        'width': a.strokeWidth,
        'strokeWidth': a.strokeWidth,
        'points': (a.points ?? []).map((p) => {'x': p.dx, 'y': p.dy, 'pressure': 1.0}).toList(),
      };
    }).toList();

    final payload = <String, dynamic>{
      'id': docId,
      'title': document.title,
      'studio': 'doccanvas',
      'category': 'docAnnotation',
      'updated_at': nowIso,
      'updatedAt': nowIso,
      'owner_id': uid,
      'createdBy': uid,
      'user_id': uid,
      'userId': uid,
      'activeDocument': document.toJson(),
      'bgFile': {
        'url': document.url ?? document.filePath ?? '',
        'type': document.fileType,
      },
      'annotations': annotations.map((a) => a.toJson()).toList(),
      'strokes': strokesForWeb,
      'content': jsonEncode({
        'annotations': annotations.map((a) => a.toJson()).toList(),
        'strokes': strokesForWeb,
        'activeDocument': document.toJson(),
      }),
    };

    try {
      await fs.collection('whiteboards').doc(docId.trim()).set(
        payload,
        SetOptions(merge: true),
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('[saveDocSession Error] $e');
    }
  }
}
