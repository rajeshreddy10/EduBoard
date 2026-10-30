/// Application user configuration and accessibility preferences
library;

import '../core/utilities/safe_json.dart';

class AppSettingsModel {
  final String language;
  final String timeZone;
  final String region;
  final bool highContrast;
  final bool reduceMotion;
  final double textScaleFactor;
  final bool autoSyncOffline;
  final DateTime lastSyncTime;
  final int pendingLocalChanges;

  const AppSettingsModel({
    required this.language,
    required this.timeZone,
    required this.region,
    required this.highContrast,
    required this.reduceMotion,
    required this.textScaleFactor,
    required this.autoSyncOffline,
    required this.lastSyncTime,
    required this.pendingLocalChanges,
  });

  AppSettingsModel copyWith({
    String? language,
    String? timeZone,
    String? region,
    bool? highContrast,
    bool? reduceMotion,
    double? textScaleFactor,
    bool? autoSyncOffline,
    DateTime? lastSyncTime,
    int? pendingLocalChanges,
  }) {
    return AppSettingsModel(
      language: language ?? this.language,
      timeZone: timeZone ?? this.timeZone,
      region: region ?? this.region,
      highContrast: highContrast ?? this.highContrast,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      textScaleFactor: textScaleFactor ?? this.textScaleFactor,
      autoSyncOffline: autoSyncOffline ?? this.autoSyncOffline,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      pendingLocalChanges: pendingLocalChanges ?? this.pendingLocalChanges,
    );
  }

  Map<String, dynamic> toJson() => {
    'language': language,
    'timeZone': timeZone,
    'region': region,
    'highContrast': highContrast,
    'reduceMotion': reduceMotion,
    'textScaleFactor': textScaleFactor,
    'autoSyncOffline': autoSyncOffline,
    'lastSyncTime': lastSyncTime.toIso8601String(),
    'pendingLocalChanges': pendingLocalChanges,
  };

  factory AppSettingsModel.fromJson(Map<String, dynamic> json) {
    return AppSettingsModel(
      language: json['language']?.toString() ?? 'English (US)',
      timeZone: json['timeZone']?.toString() ?? 'UTC-08:00 (Pacific Time)',
      region: json['region']?.toString() ?? 'North America',
      highContrast: asBoolOr(json['highContrast'], false),
      reduceMotion: asBoolOr(json['reduceMotion'], false),
      textScaleFactor: asDoubleOr(json['textScaleFactor'], 1.0),
      autoSyncOffline: asBoolOr(json['autoSyncOffline'], true),
      lastSyncTime: asDateOr(json['lastSyncTime'], DateTime.now()),
      pendingLocalChanges: asIntOr(json['pendingLocalChanges'], 0),
    );
  }

  static AppSettingsModel initial() {
    return AppSettingsModel(
      language: 'English (US)',
      timeZone: 'UTC-08:00 (Pacific Time)',
      region: 'North America',
      highContrast: false,
      reduceMotion: false,
      textScaleFactor: 1.0,
      autoSyncOffline: true,
      lastSyncTime: DateTime.now(),
      pendingLocalChanges: 0,
    );
  }
}
