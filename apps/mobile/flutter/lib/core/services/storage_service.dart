import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

/// Local offline storage service wrapping Hive boxes with backend-ready contracts
class StorageService {
  static bool _isInitialized = false;
  static final Map<String, dynamic> _memoryFallback = {};

  static Future<void> init() async {
    try {
      await Hive.initFlutter();
      await Hive.openBox(AppConstants.settingsBox);
      await Hive.openBox(AppConstants.themeBox);
      await Hive.openBox(AppConstants.whiteboardBox);
      await Hive.openBox(AppConstants.notesBox);
      await Hive.openBox(AppConstants.authBox);
      _isInitialized = true;
    } catch (e) {
      // In-memory fallback if storage cannot be initialized on environment
      _isInitialized = false;
    }
  }

  static T? get<T>(String boxName, String key, {T? defaultValue}) {
    if (_isInitialized) {
      try {
        final box = Hive.box(boxName);
        final val = box.get(key, defaultValue: defaultValue);
        if (val is T) return val;
      } catch (_) {}
    }
    final fallback = _memoryFallback['${boxName}_$key'];
    if (fallback is T) return fallback;
    return defaultValue;
  }

  static Future<void> put(String boxName, String key, dynamic value) async {
    _memoryFallback['${boxName}_$key'] = value;
    if (_isInitialized) {
      try {
        final box = Hive.box(boxName);
        await box.put(key, value);
      } catch (_) {}
    }
  }

  static Future<void> delete(String boxName, String key) async {
    _memoryFallback.remove('${boxName}_$key');
    if (_isInitialized) {
      try {
        final box = Hive.box(boxName);
        await box.delete(key);
      } catch (_) {}
    }
  }

  static Future<void> clear(String boxName) async {
    _memoryFallback.removeWhere((k, _) => k.startsWith('${boxName}_'));
    if (_isInitialized) {
      try {
        final box = Hive.box(boxName);
        await box.clear();
      } catch (_) {}
    }
  }
}
