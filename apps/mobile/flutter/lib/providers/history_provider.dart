import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/history_item_model.dart';
import '../repositories/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return FirestoreHistoryRepository();
});

class HistoryState {
  final List<HistoryItemModel> allItems;
  final HistoryCategory selectedCategory;
  final String searchQuery;
  final bool isGridView;
  final bool isLoading;
  /// Friendly, user-facing failure text (Offline malformed token,...).
  /// Null means no error UI should be shown.
  final String? errorMessage;

  const HistoryState({
    this.allItems = const [],
    this.selectedCategory = HistoryCategory.all,
    this.searchQuery = '',
    this.isGridView = true,
    this.isLoading = false,
    this.errorMessage,
  });

  HistoryState copyWith({
    List<HistoryItemModel>? allItems,
    HistoryCategory? selectedCategory,
    String? searchQuery,
    bool? isGridView,
    bool? isLoading,
    String? errorMessage,
  }) {
    return HistoryState(
      allItems: allItems ?? this.allItems,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: searchQuery ?? this.searchQuery,
      isGridView: isGridView ?? this.isGridView,
      isLoading: isLoading ?? this.isLoading,
      // `errorMessage: ''` clears any banner; passing nothing keeps it.
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  List<HistoryItemModel> get filteredItems {
    return allItems.where((item) {
      final matchesCategory = selectedCategory == HistoryCategory.all || item.category == selectedCategory;
      final matchesQuery = searchQuery.isEmpty ||
          item.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.summary.toLowerCase().contains(searchQuery.toLowerCase()) ||
          item.tags.any((t) => t.toLowerCase().contains(searchQuery.toLowerCase()));
      return matchesCategory && matchesQuery;
    }).toList();
  }
}

class HistoryNotifier extends Notifier<HistoryState> {
  HistoryRepository get _repo => ref.read(historyRepositoryProvider);
  StreamSubscription<List<HistoryItemModel>>? _historySub;
  StreamSubscription<User?>? _authSub;

  @override
  HistoryState build() {
    ref.onDispose(() {
      _historySub?.cancel();
      _authSub?.cancel();
    });

    Future.microtask(() => _init());
    return const HistoryState(isLoading: true);
  }

  Future<void> _init() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      await _subscribeToUserHistory(currentUid);
    } else {
      await loadHistory();
    }

    // Dynamic session reactivity: when a user logs in, automatically re-connect
    // the Firestore real-time listener to sync the remote boards immediately.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final uid = user?.uid;
      if (uid != null) {
        await _subscribeToUserHistory(uid);
      } else {
        _historySub?.cancel();
        state = const HistoryState(isLoading: false);
      }
    });
  }

  Future<void> _subscribeToUserHistory(String uid) async {
    _historySub?.cancel();
    await loadHistory(uid);

    // Setup live real-time subscription matching Web app's BoardContext.
    _historySub = _repo.watchHistoryItems(uid).listen((liveItems) {
      state = state.copyWith(allItems: liveItems, isLoading: false, errorMessage: '');
    }, onError: (e) {
      debugPrint('[History Stream Warning] $e');
    });
  }

  /// Friendly, never-throwing message for transient network/auth problems so
  /// the UI can render a soft banner instead of erroring out.
  String _friendlyMessage(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'Connection is slow. Showing your saved boards.';
    }
    if (raw.contains('permission') || raw.contains('token')) {
      return 'We could not refresh your boards. Please sign in again.';
    }
    return 'You are offline. Showing your saved boards.';
  }

  Future<void> loadHistory([String? explicitUid]) async {
    state = state.copyWith(isLoading: true, errorMessage: '');
    try {
      final items = await _repo.getAllHistoryItems(explicitUid);
      state = state.copyWith(allItems: items, isLoading: false);
    } catch (e) {
      // Never crash the screen: keep existing items and show a soft banner.
      state = state.copyWith(isLoading: false, errorMessage: _friendlyMessage(e));
    }
  }

  void setCategory(HistoryCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleViewMode() {
    state = state.copyWith(isGridView: !state.isGridView);
  }

  Future<void> deleteItem(String id) async {
    try {
      await _repo.deleteHistoryItem(id);
      state = state.copyWith(
        allItems: state.allItems.where((i) => i.id != id).toList(),
        errorMessage: '',
      );
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyMessage(e));
    }
  }

  Future<void> toggleFavorite(String id) async {
    // Optimistic toggle so the UI feels instant even on a flaky connection.
    try {
      final updated = state.allItems.map((item) {
        if (item.id == id) {
          return item.copyWith(isFavorite: !item.isFavorite);
        }
        return item;
      }).toList();
      state = state.copyWith(allItems: updated, errorMessage: '');
      await _repo.toggleFavorite(id);
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyMessage(e));
    }
  }

  Future<void> saveItem(HistoryItemModel item) async {
    try {
      await _repo.saveHistoryItem(item);
      final existingIdx = state.allItems.indexWhere((i) => i.id == item.id);
      if (existingIdx >= 0) {
        final updated = List<HistoryItemModel>.from(state.allItems);
        updated[existingIdx] = item;
        state = state.copyWith(allItems: updated, errorMessage: '');
      } else {
        state = state.copyWith(allItems: [item, ...state.allItems], errorMessage: '');
      }
    } catch (e) {
      state = state.copyWith(errorMessage: _friendlyMessage(e));
    }
  }
}

final historyProvider = NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);
