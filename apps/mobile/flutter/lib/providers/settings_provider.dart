import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings_model.dart';
import '../repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return FirestoreSettingsRepository();
});

class SettingsNotifier extends Notifier<AppSettingsModel> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);
  StreamSubscription<AppSettingsModel>? _settingsSub;
  StreamSubscription<User?>? _authSub;

  @override
  AppSettingsModel build() {
    ref.onDispose(() {
      _settingsSub?.cancel();
      _authSub?.cancel();
    });

    Future.microtask(() => _init());
    return AppSettingsModel.initial();
  }

  Future<void> _init() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      await _subscribeToSettings(currentUid);
    } else {
      await _loadSettings();
    }

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final uid = user?.uid;
      if (uid != null) {
        await _subscribeToSettings(uid);
      } else {
        _settingsSub?.cancel();
        state = AppSettingsModel.initial();
      }
    });
  }

  Future<void> _subscribeToSettings(String uid) async {
    _settingsSub?.cancel();
    final initial = await _repo.getSettings(uid);
    state = initial;

    _settingsSub = _repo.watchSettings(uid).listen((liveSettings) {
      state = liveSettings;
    }, onError: (e) {
      debugPrint('[Settings Stream Warning] $e');
    });
  }

  Future<void> _loadSettings() async {
    final s = await _repo.getSettings();
    state = s;
  }

  Future<void> setLanguage(String lang) async {
    final updated = state.copyWith(language: lang);
    state = updated;
    await _repo.updateSettings(updated);
  }

  Future<void> setTimeZone(String tz) async {
    final updated = state.copyWith(timeZone: tz);
    state = updated;
    await _repo.updateSettings(updated);
  }

  Future<void> setRegion(String region) async {
    final updated = state.copyWith(region: region);
    state = updated;
    await _repo.updateSettings(updated);
  }

  Future<void> toggleHighContrast(bool enabled) async {
    final updated = state.copyWith(highContrast: enabled);
    state = updated;
    await _repo.updateSettings(updated);
  }

  Future<void> toggleReduceMotion(bool enabled) async {
    final updated = state.copyWith(reduceMotion: enabled);
    state = updated;
    await _repo.updateSettings(updated);
  }

  Future<void> setTextScale(double scale) async {
    final updated = state.copyWith(textScaleFactor: scale);
    state = updated;
    await _repo.updateSettings(updated);
  }

  Future<void> triggerSync() async {
    final s = await _repo.getSettings();
    state = s.copyWith(lastSyncTime: DateTime.now(), pendingLocalChanges: 0);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettingsModel>(SettingsNotifier.new);
