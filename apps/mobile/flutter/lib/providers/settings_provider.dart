import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings_model.dart';
import '../repositories/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return FirestoreSettingsRepository();
});

class SettingsNotifier extends Notifier<AppSettingsModel> {
  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  @override
  AppSettingsModel build() {
    Future.microtask(() => _loadSettings());
    return AppSettingsModel.initial();
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
