import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_client.dart';
import '../core/services/storage_service.dart';
import '../models/app_settings_model.dart';

abstract class SettingsRepository {
  Future<AppSettingsModel> getSettings([String? explicitUid]);
  Stream<AppSettingsModel> watchSettings([String? explicitUid]);
  Future<void> updateSettings(AppSettingsModel settings);
}

class FirestoreSettingsRepository implements SettingsRepository {
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

  @override
  Stream<AppSettingsModel> watchSettings([String? explicitUid]) {
    final uid = explicitUid ?? _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) {
      return Stream.value(AppSettingsModel.initial());
    }

    return fs.collection('userSettings').doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) {
        return AppSettingsModel.initial();
      }
      return AppSettingsModel.fromJson(snap.data()!);
    }).handleError((e) {
      debugPrint('[Firestore Settings Stream Note] $e');
    });
  }

  @override
  Future<AppSettingsModel> getSettings([String? explicitUid]) async {
    final uid = explicitUid ?? _currentUserId;
    final fs = _firestore;

    // 1. Try Firestore approved collection: "userSettings/{userId}"
    if (uid != null && fs != null) {
      try {
        final doc = await fs
            .collection('userSettings')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (doc.exists && doc.data() != null) {
          return AppSettingsModel.fromJson(doc.data()!);
        }
      } on TimeoutException {
        debugPrint('[Firestore Settings Fetch Note] timed out');
      } catch (e) {
        debugPrint('[Firestore Settings Fetch Note] $e');
      }
    }

    // 2. Try Backend GET /api/settings
    try {
      final res = await _api.get('/settings');
      if (res is Map && res['id'] != null) {
        return AppSettingsModel.fromJson(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('[Backend Settings Fetch Note] $e');
    }

    // 3. Fallback to local Hive store
    final lang = StorageService.get(AppConstants.settingsBox, 'language');
    final tz = StorageService.get(AppConstants.settingsBox, 'timezone');
    final reg = StorageService.get(AppConstants.settingsBox, 'region');
    final hc = StorageService.get(AppConstants.settingsBox, 'high_contrast');
    final rm = StorageService.get(AppConstants.settingsBox, 'reduce_motion');

    final base = AppSettingsModel.initial();
    return base.copyWith(
      language: lang is String ? lang : base.language,
      timeZone: tz is String ? tz : base.timeZone,
      region: reg is String ? reg : base.region,
      highContrast: hc is bool ? hc : base.highContrast,
      reduceMotion: rm is bool ? rm : base.reduceMotion,
    );
  }

  @override
  Future<void> updateSettings(AppSettingsModel settings) async {
    final uid = _currentUserId;

    // Local cache in Hive
    await StorageService.put(AppConstants.settingsBox, 'language', settings.language);
    await StorageService.put(AppConstants.settingsBox, 'timezone', settings.timeZone);
    await StorageService.put(AppConstants.settingsBox, 'region', settings.region);
    await StorageService.put(AppConstants.settingsBox, 'high_contrast', settings.highContrast);
    await StorageService.put(AppConstants.settingsBox, 'reduce_motion', settings.reduceMotion);

    final payload = {
      ...settings.toJson(),
      'updated_at': DateTime.now().toIso8601String(),
    };

    // 1. Write to Firestore approved collection "userSettings"
    final fs = _firestore;
    if (uid != null && fs != null) {
      try {
        await fs
            .collection('userSettings')
            .doc(uid)
            .set(payload, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        debugPrint('[Firestore Settings Update Note] timed out');
      } catch (e) {
        debugPrint('[Firestore Settings Update Note] $e');
      }
    }

    // 2. Sync to Backend PUT /api/settings
    try {
      await _api.put('/settings', body: payload);
    } catch (e) {
      debugPrint('[Backend Settings Update Note] $e');
    }
  }
}
