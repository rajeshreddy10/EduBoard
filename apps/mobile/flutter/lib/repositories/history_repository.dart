import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/services/api_client.dart';
import '../models/history_item_model.dart';

abstract class HistoryRepository {
  Future<List<HistoryItemModel>> getAllHistoryItems([String? explicitUid]);
  Stream<List<HistoryItemModel>> watchHistoryItems([String? explicitUid]);
  Future<void> deleteHistoryItem(String id);
  Future<void> toggleFavorite(String id);
  Future<void> saveHistoryItem(HistoryItemModel item);
}

class FirestoreHistoryRepository implements HistoryRepository {
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

  /// Firestore reads are capped and time-limited; a flaky socket (offline
  /// device) must never stall a screen. TimeoutException is swallowed by the
  /// callers which then fall through to the next data source.
  Future<QuerySnapshot<Map<String, dynamic>>> _guardedGet(
    Query<Map<String, dynamic>> query,
  ) {
    return query
        .limit(100)
        .get()
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw TimeoutException('Firestore history read timed out'),
        );
  }

  @override
  Stream<List<HistoryItemModel>> watchHistoryItems([String? explicitUid]) {
    final uid = explicitUid ?? _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) {
      return Stream.value([]);
    }

    final controller = StreamController<List<HistoryItemModel>>.broadcast();
    final Map<String, HistoryItemModel> byId = {};
    StreamSubscription? subOwner;
    StreamSubscription? subCreatedBy;

    void emitMerged() {
      if (!controller.isClosed) {
        final sorted = byId.values.toList()
          ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        controller.add(sorted);
      }
    }

    void handleSnap(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final doc in snap.docs) {
        byId[doc.id] = HistoryItemModel.fromJson(doc.data(), doc.id);
      }
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.removed) {
          byId.remove(change.doc.id);
        }
      }
      emitMerged();
    }

    controller.onListen = () {
      try {
        subOwner = fs
            .collection('whiteboards')
            .where('owner_id', isEqualTo: uid)
            .limit(100)
            .snapshots()
            .listen(handleSnap, onError: (e) {
          debugPrint('[Firestore History Stream Note] $e');
        });

        subCreatedBy = fs
            .collection('whiteboards')
            .where('createdBy', isEqualTo: uid)
            .limit(100)
            .snapshots()
            .listen(handleSnap, onError: (e) {
          debugPrint('[Firestore History Stream Note] $e');
        });
      } catch (e) {
        debugPrint('[Firestore History Watch Error] $e');
      }
    };

    controller.onCancel = () {
      subOwner?.cancel();
      subCreatedBy?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<List<HistoryItemModel>> getAllHistoryItems([String? explicitUid]) async {
    final uid = explicitUid ?? _currentUserId;
    final fs = _firestore;

    // 1. Try Firestore approved collection: "whiteboards"
    if (uid != null && fs != null) {
      try {
        // Both projections run concurrently instead of two sequential
        // round-trips (halves worst-case latency and reduces startup jank).
        final results = await Future.wait([
          _guardedGet(fs.collection('whiteboards').where('owner_id', isEqualTo: uid))
              .then((q) => q.docs.toList()),
          _guardedGet(fs.collection('whiteboards').where('createdBy', isEqualTo: uid))
              .then((q) => q.docs.toList()),
        ]).catchError((_) => <List<QueryDocumentSnapshot<Map<String, dynamic>>>>[]);

        final ownerDocs = results.isNotEmpty ? results[0] : <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final legacyDocs = results.length > 1 ? results[1] : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

        final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final doc in [...ownerDocs, ...legacyDocs]) {
          byId[doc.id] = doc;
        }

        if (byId.isNotEmpty) {
          final items = byId.values
              .map((doc) => HistoryItemModel.fromJson(doc.data(), doc.id))
              .toList();
          items.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
          return items;
        }
      } on TimeoutException {
        debugPrint('[Firestore History Fetch Note] timed out — using backend');
      } catch (e) {
        debugPrint('[Firestore History Fetch Note] $e');
      }
    }

    // 2. Fallback to Express backend GET /api/whiteboards (ApiClient handles
    // fresh-token refresh + single retry automatically).
    try {
      final res = await _api.get('/whiteboards');
      if (res is List) {
        final items = res
            .whereType<Map>()
            .map((item) => HistoryItemModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        items.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        return items;
      }
      if (res is Map && res['whiteboards'] is List) {
        final items = (res['whiteboards'] as List)
            .whereType<Map>()
            .map((item) => HistoryItemModel.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        items.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        return items;
      }
    } catch (e) {
      debugPrint('[Backend History Fetch Note] $e');
    }

    return [];
  }

  @override
  Future<void> deleteHistoryItem(String id) async {
    // 1. Delete from Firestore whiteboards and sub-collections
    final fs = _firestore;
    if (fs != null) {
      try {
        final boardRef = fs.collection('whiteboards').doc(id);
        final shapesSnap = await boardRef.collection('shapes').limit(600).get();
        final batch = fs.batch();
        for (final doc in shapesSnap.docs) {
          batch.delete(doc.reference);
        }
        batch.delete(boardRef);
        await batch.commit();
      } on TimeoutException {
        debugPrint('[Firestore Delete Board Note] timed out — continuing with backend');
      } catch (e) {
        debugPrint('[Firestore Delete Board Note] $e');
      }
    }

    // 2. Sync deletion to Express backend DELETE /api/whiteboards/:id
    try {
      await _api.delete('/whiteboards/$id');
    } catch (e) {
      debugPrint('[Backend Delete Board Note] $e');
    }
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final fs = _firestore;
    if (fs != null) {
      try {
        final docRef = fs.collection('whiteboards').doc(id);
        final docSnap = await docRef.get().timeout(const Duration(seconds: 8));
        if (docSnap.exists) {
          final currentFav = docSnap.data()?['is_favorite'] ?? docSnap.data()?['isFavorite'] ?? false;
          await docRef.set({
            'is_favorite': !currentFav,
            'isFavorite': !currentFav,
            'updated_at': DateTime.now().toIso8601String(),
          }, SetOptions(merge: true));
        }
      } on TimeoutException {
        debugPrint('[Toggle Favorite Note] timed out');
      } catch (e) {
        debugPrint('[Toggle Favorite Note] $e');
      }
    }
  }

  @override
  Future<void> saveHistoryItem(HistoryItemModel item) async {
    final uid = _currentUserId;
    final fs = _firestore;
    final nowIso = DateTime.now().toIso8601String();
    final payload = {
      ...item.toJson(),
      'owner_id': uid,
      'createdBy': uid,
      'user_id': uid,
      'userId': uid,
      'updated_at': nowIso,
      'updatedAt': nowIso,
    };

    // Firestore first (source of truth), backend mirror second. Uses a write
    // batch so the metadata update and board data commit atomically.
    if (fs != null) {
      try {
        final batch = fs.batch();
        batch.set(
          fs.collection('whiteboards').doc(item.id),
          payload,
          SetOptions(merge: true),
        );
        await batch.commit();
      } on TimeoutException {
        debugPrint('[Firestore Save Board Note] timed out — will sync later');
      } catch (e) {
        debugPrint('[Firestore Save Board Note] $e');
      }
    }

    try {
      await _api.post('/whiteboards', body: payload);
    } catch (e) {
      debugPrint('[Backend Save Board Note] $e');
    }
  }
}
