import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification_item_model.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return FirestoreNotificationRepository();
});

class NotificationState {
  final List<NotificationItemModel> items;
  final NotificationCategory selectedCategory;
  final bool isLoading;
  /// Friendly, user-facing failure text. Null = no error UI.
  final String? errorMessage;

  const NotificationState({
    this.items = const [],
    this.selectedCategory = NotificationCategory.all,
    this.isLoading = false,
    this.errorMessage,
  });

  NotificationState copyWith({
    List<NotificationItemModel>? items,
    NotificationCategory? selectedCategory,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NotificationState(
      items: items ?? this.items,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      isLoading: isLoading ?? this.isLoading,
      // `errorMessage: ''` clears any banner; omitting keeps it.
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  int get unreadCount => items.where((item) => !item.isRead).length;

  List<NotificationItemModel> get filteredItems {
    if (selectedCategory == NotificationCategory.all) return items;
    return items.where((item) => item.category == selectedCategory).toList();
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);
  StreamSubscription<List<NotificationItemModel>>? _notifSub;
  StreamSubscription<User?>? _authSub;

  @override
  NotificationState build() {
    ref.onDispose(() {
      _notifSub?.cancel();
      _authSub?.cancel();
    });

    Future.microtask(() => _init());
    return const NotificationState(isLoading: true);
  }

  Future<void> _init() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      await _subscribeToNotifications(currentUid);
    } else {
      await loadNotifications();
    }

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final uid = user?.uid;
      if (uid != null) {
        await _subscribeToNotifications(uid);
      } else {
        _notifSub?.cancel();
        state = const NotificationState(isLoading: false);
      }
    });
  }

  Future<void> _subscribeToNotifications(String uid) async {
    _notifSub?.cancel();
    await loadNotifications(uid);

    _notifSub = _repo.watchNotifications(uid).listen((liveItems) {
      state = state.copyWith(items: liveItems, isLoading: false, errorMessage: '');
    }, onError: (e) {
      debugPrint('[Notifications Stream Warning] $e');
    });
  }

  String _friendlyMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'Connection is slow. Showing cached notifications.';
    }
    if (raw.contains('permission') || raw.contains('token')) {
      return 'We could not refresh notifications. Please sign in again.';
    }
    return 'You are offline. Showing cached notifications.';
  }

  Future<void> loadNotifications([String? explicitUid]) async {
    state = state.copyWith(isLoading: true, errorMessage: '');
    try {
      final list = await _repo.getNotifications(explicitUid);
      state = state.copyWith(items: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyMessage(e));
    }
  }

  void setCategory(NotificationCategory cat) {
    state = state.copyWith(selectedCategory: cat);
  }

  Future<void> markAllAsRead() async {
    // Optimistic local update; backend/Firestore marked best-effort.
    final updated = state.items.map((i) => i.copyWith(isRead: true)).toList();
    state = state.copyWith(items: updated, errorMessage: '');
    try {
      await _repo.markAllRead();
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyMessage(e));
    }
  }

  Future<void> markAsRead(String id) async {
    final idx = state.items.indexWhere((i) => i.id == id);
    if (idx < 0 || state.items[idx].isRead) return;
    final updated = List<NotificationItemModel>.from(state.items);
    updated[idx] = updated[idx].copyWith(isRead: true);
    state = state.copyWith(items: updated, errorMessage: '');
    try {
      await _repo.markRead(id);
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyMessage(e));
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _repo.deleteNotification(id);
      state = state.copyWith(
        items: state.items.where((i) => i.id != id).toList(),
        errorMessage: '',
      );
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyMessage(e));
    }
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationState>(NotificationNotifier.new);
