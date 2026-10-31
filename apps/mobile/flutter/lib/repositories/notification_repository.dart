import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/services/api_client.dart';
import '../models/notification_item_model.dart';

abstract class NotificationRepository {
  Future<List<NotificationItemModel>> getNotifications([String? explicitUid]);
  Stream<List<NotificationItemModel>> watchNotifications([String? explicitUid]);
  Future<void> markAllRead();
  Future<void> markRead(String id);
  Future<void> deleteNotification(String id);
  Future<void> addNotification(NotificationItemModel notification);
}

class FirestoreNotificationRepository implements NotificationRepository {
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

  List<NotificationItemModel> _sorted(List<NotificationItemModel> items) {
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items;
  }

  /// Composite-index–safe unread snapshot: the `userId + read` compound query
  /// needs a Firestore index that may not exist. A single-field query plus a
  /// local filter always resolves without index errors.
  Future<List<NotificationItemModel>> _unreadFor(
    String uid,
    String ownerField,
  ) async {
    final fs = _firestore;
    if (fs == null) return [];
    final snap = await fs
        .collection('notifications')
        .where(ownerField, isEqualTo: uid)
        .limit(100)
        .get()
        .timeout(const Duration(seconds: 8));
    return snap.docs
        .where((d) => d.data()['read'] == false || d.data()['read'] == null)
        .map((doc) => NotificationItemModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  @override
  Stream<List<NotificationItemModel>> watchNotifications([String? explicitUid]) {
    final uid = explicitUid ?? _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) {
      return Stream.value([]);
    }

    final controller = StreamController<List<NotificationItemModel>>.broadcast();
    final Map<String, NotificationItemModel> byId = {};
    StreamSubscription? subUserId;
    StreamSubscription? subUserIdSnake;

    void emitMerged() {
      if (!controller.isClosed) {
        final sorted = _sorted(byId.values.toList());
        controller.add(sorted);
      }
    }

    void handleSnap(QuerySnapshot<Map<String, dynamic>> snap) {
      for (final doc in snap.docs) {
        byId[doc.id] = NotificationItemModel.fromJson(doc.data(), doc.id);
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
        subUserId = fs
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .limit(100)
            .snapshots()
            .listen(handleSnap, onError: (e) {
          debugPrint('[Firestore Notifications Stream Note] $e');
        });

        subUserIdSnake = fs
            .collection('notifications')
            .where('user_id', isEqualTo: uid)
            .limit(100)
            .snapshots()
            .listen(handleSnap, onError: (e) {
          debugPrint('[Firestore Notifications Stream Note] $e');
        });
      } catch (e) {
        debugPrint('[Firestore Notifications Watch Error] $e');
      }
    };

    controller.onCancel = () {
      subUserId?.cancel();
      subUserIdSnake?.cancel();
    };

    return controller.stream;
  }

  @override
  Future<List<NotificationItemModel>> getNotifications([String? explicitUid]) async {
    final uid = explicitUid ?? _currentUserId;
    final fs = _firestore;

    // 1. Try Firestore approved collection: "notifications"
    if (uid != null && fs != null) {
      try {
        // Both field conventions are probed concurrently to avoid sequential
        // dead time on cold cache.
        final ownerFieldIds = await Future.wait([
          fs
              .collection('notifications')
              .where('userId', isEqualTo: uid)
              .limit(100)
              .get()
              .timeout(const Duration(seconds: 8)),
          fs
              .collection('notifications')
              .where('user_id', isEqualTo: uid)
              .limit(100)
              .get()
              .timeout(const Duration(seconds: 8)),
        ]).catchError((_) => <QuerySnapshot<Map<String, dynamic>>>[]);

        final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final snap in ownerFieldIds) {
          for (final doc in snap.docs) {
            byId[doc.id] = doc;
          }
        }

        if (byId.isNotEmpty) {
          final items = byId.values
              .map((doc) => NotificationItemModel.fromJson(doc.data(), doc.id))
              .toList();
          return _sorted(items);
        }
      } on TimeoutException {
        debugPrint('[Firestore Notifications Fetch Note] timed out — using backend');
      } catch (e) {
        debugPrint('[Firestore Notifications Fetch Note] $e');
      }
    }

    // 2. Try Backend GET /api/notifications
    try {
      final res = await _api.get('/notifications');
      List<NotificationItemModel> parsed;
      if (res is List) {
        parsed = res.whereType<Map>().map((n) {
          return NotificationItemModel.fromJson(Map<String, dynamic>.from(n));
        }).toList();
      } else if (res is Map && res['notifications'] is List) {
        parsed = (res['notifications'] as List).whereType<Map>().map((n) {
          return NotificationItemModel.fromJson(Map<String, dynamic>.from(n));
        }).toList();
      } else {
        parsed = const [];
      }
      return _sorted(parsed);
    } catch (e) {
      debugPrint('[Backend Notifications Fetch Note] $e');
    }

    return [];
  }

  @override
  Future<void> markRead(String id) async {
    try {
      await _firestore?.collection('notifications').doc(id).set({
        'read': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore markRead Note] $e');
    }

    try {
      await _api.put('/notifications/$id/read');
    } catch (e) {
      debugPrint('[Backend markRead Note] $e');
    }
  }

  @override
  Future<void> markAllRead() async {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid != null && fs != null) {
      try {
        final unread = [
          ...await _unreadFor(uid, 'userId'),
          ...await _unreadFor(uid, 'user_id'),
        ];

        final batch = fs.batch();
        final seen = <String>{};
        for (final doc in unread) {
          if (seen.contains(doc.id)) continue;
          seen.add(doc.id);
          batch.set(
            fs.collection('notifications').doc(doc.id),
            {'read': true, 'updated_at': DateTime.now().toIso8601String()},
            SetOptions(merge: true),
          );
        }
        if (seen.isNotEmpty) {
          await batch.commit();
        }
      } on TimeoutException {
        debugPrint('[Firestore markAllRead Note] timed out');
      } catch (e) {
        debugPrint('[Firestore markAllRead Note] $e');
      }
    }

    try {
      await _api.put('/notifications/read-all');
    } catch (e) {
      debugPrint('[Backend markAllRead Note] $e');
    }
  }

  @override
  Future<void> deleteNotification(String id) async {
    final fs = _firestore;
    if (fs != null) {
      try {
        await fs.collection('notifications').doc(id).delete();
      } catch (e) {
        debugPrint('[Firestore deleteNotification Note] $e');
      }
    }

    try {
      await _api.delete('/notifications/$id');
    } catch (e) {
      debugPrint('[Backend deleteNotification Note] $e');
    }
  }

  @override
  Future<void> addNotification(NotificationItemModel notification) async {
    final uid = _currentUserId;
    final fs = _firestore;
    final payload = {
      ...notification.toJson(),
      if (uid != null) 'userId': uid,
      if (uid != null) 'user_id': uid,
      'created_at': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    if (fs != null) {
      try {
        await fs
            .collection('notifications')
            .doc(notification.id)
            .set(payload, SetOptions(merge: true));
      } catch (e) {
        debugPrint('[Firestore addNotification Note] $e');
      }
    }

    try {
      await _api.post('/notifications', body: payload);
    } catch (e) {
      debugPrint('[Backend addNotification Note] $e');
    }
  }
}
