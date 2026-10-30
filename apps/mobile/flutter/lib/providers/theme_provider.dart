import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/services/storage_service.dart';
import '../core/theme/app_theme_types.dart';

class ThemeState {
  final EduThemePreset preset;
  final EduAccentColor accent;
  final ThemeMode mode;

  const ThemeState({
    required this.preset,
    required this.accent,
    required this.mode,
  });

  ThemeState copyWith({
    EduThemePreset? preset,
    EduAccentColor? accent,
    ThemeMode? mode,
  }) {
    return ThemeState(
      preset: preset ?? this.preset,
      accent: accent ?? this.accent,
      mode: mode ?? this.mode,
    );
  }
}

class ThemeNotifier extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    final savedPresetIndex = StorageService.get(AppConstants.themeBox, 'preset_index');
    final savedAccentIndex = StorageService.get(AppConstants.themeBox, 'accent_index');
    final savedMode = StorageService.get(AppConstants.themeBox, 'theme_mode');

    EduThemePreset preset = EduThemePreset.deepAurora;
    if (savedPresetIndex is int && savedPresetIndex >= 0 && savedPresetIndex < EduThemePreset.values.length) {
      preset = EduThemePreset.values[savedPresetIndex];
    }

    EduAccentColor accent = EduAccentColor.blue;
    if (savedAccentIndex is int && savedAccentIndex >= 0 && savedAccentIndex < EduAccentColor.values.length) {
      accent = EduAccentColor.values[savedAccentIndex];
    }

    ThemeMode mode = ThemeMode.dark;
    if (savedMode == 'light') mode = ThemeMode.light;
    if (savedMode == 'dark') mode = ThemeMode.dark;
    if (savedMode == 'system') mode = ThemeMode.system;

    return ThemeState(preset: preset, accent: accent, mode: mode);
  }

  void _syncToRemote({String? theme, String? preset, String? accent}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (theme != null) updates['theme'] = theme;
      if (preset != null) updates['theme_preset'] = preset;
      if (accent != null) updates['accentColor'] = accent;

      FirebaseFirestore.instance
          .collection('userSettings')
          .doc(uid)
          .set(updates, SetOptions(merge: true))
          .catchError((_) {});
    }
  }

  void setPreset(EduThemePreset preset) {
    state = state.copyWith(preset: preset);
    StorageService.put(AppConstants.themeBox, 'preset_index', preset.index);
    _syncToRemote(preset: preset.name);
  }

  void setAccent(EduAccentColor accent) {
    state = state.copyWith(accent: accent);
    StorageService.put(AppConstants.themeBox, 'accent_index', accent.index);
    _syncToRemote(accent: accent.name);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    StorageService.put(AppConstants.themeBox, 'theme_mode', mode.name);
    _syncToRemote(theme: mode.name);
  }

  void toggleThemeMode() {
    final newMode = state.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(newMode);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeState>(ThemeNotifier.new);
