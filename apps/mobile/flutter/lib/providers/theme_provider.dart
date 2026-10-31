import 'dart:async';

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
  StreamSubscription? _settingsSub;
  StreamSubscription<User?>? _authSub;

  @override
  ThemeState build() {
    ref.onDispose(() {
      _settingsSub?.cancel();
      _authSub?.cancel();
    });

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

    Future.microtask(() => _setupSettingsListener());

    return ThemeState(preset: preset, accent: accent, mode: mode);
  }

  void _setupSettingsListener() {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      _listenToRemoteSettings(currentUid);
    }

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      final uid = user?.uid;
      if (uid != null) {
        _listenToRemoteSettings(uid);
      } else {
        _settingsSub?.cancel();
      }
    });
  }

  void _listenToRemoteSettings(String uid) {
    _settingsSub?.cancel();
    try {
      _settingsSub = FirebaseFirestore.instance
          .collection('userSettings')
          .doc(uid)
          .snapshots()
          .listen((snap) {
        if (!snap.exists || snap.data() == null) return;
        final data = snap.data()!;

        // 1. Theme mode
        final remoteTheme = data['theme']?.toString().toLowerCase();
        if (remoteTheme != null) {
          ThemeMode? newMode;
          if (remoteTheme == 'light') newMode = ThemeMode.light;
          if (remoteTheme == 'dark') newMode = ThemeMode.dark;
          if (remoteTheme == 'system') newMode = ThemeMode.system;
          if (newMode != null && newMode != state.mode) {
            state = state.copyWith(mode: newMode);
            StorageService.put(AppConstants.themeBox, 'theme_mode', newMode.name);
          }
        }

        // 2. Preset
        final remotePreset = data['theme_preset']?.toString();
        if (remotePreset != null) {
          final matched = EduThemePreset.values.cast<EduThemePreset?>().firstWhere(
                (p) => p?.name == remotePreset,
                orElse: () => null,
              );
          if (matched != null && matched != state.preset) {
            state = state.copyWith(preset: matched);
            StorageService.put(AppConstants.themeBox, 'preset_index', matched.index);
          }
        }

        // 3. Accent
        final remoteAccent = data['accentColor']?.toString();
        if (remoteAccent != null) {
          final matched = EduAccentColor.values.cast<EduAccentColor?>().firstWhere(
                (a) => a?.name == remoteAccent,
                orElse: () => null,
              );
          if (matched != null && matched != state.accent) {
            state = state.copyWith(accent: matched);
            StorageService.put(AppConstants.themeBox, 'accent_index', matched.index);
          }
        }
      }, onError: (e) {
        debugPrint('[Theme Settings Listener Warning] $e');
      });
    } catch (_) {}
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
