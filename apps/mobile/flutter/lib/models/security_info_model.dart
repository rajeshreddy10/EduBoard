/// Active authorized device record
library;

import '../core/utilities/safe_json.dart';

class SecurityDeviceModel {
  final String id;
  final String deviceName;
  final String platform;
  final String ipAddress;
  final DateTime lastActive;
  final bool isCurrentDevice;

  const SecurityDeviceModel({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.ipAddress,
    required this.lastActive,
    this.isCurrentDevice = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceName': deviceName,
    'platform': platform,
    'ipAddress': ipAddress,
    'lastActive': lastActive.toIso8601String(),
    'isCurrentDevice': isCurrentDevice,
  };

  factory SecurityDeviceModel.fromJson(Map<String, dynamic> json) {
    return SecurityDeviceModel(
      id: json['id']?.toString() ?? 'dev_${DateTime.now().millisecondsSinceEpoch}',
      deviceName: json['deviceName']?.toString() ?? 'Mobile Client',
      platform: json['platform']?.toString() ?? 'Android',
      ipAddress: json['ipAddress']?.toString() ?? '127.0.0.1',
      lastActive: asDateOr(json['lastActive'], DateTime.now()),
      isCurrentDevice: asBoolOr(json['isCurrentDevice'], false),
    );
  }
}

/// Security overview state containing score, biometrics, 2FA, and devices
class SecurityInfoModel {
  final int securityScore;
  final bool biometricsEnabled;
  final bool twoFactorEnabled;
  final DateTime lastPasswordChange;
  final List<SecurityDeviceModel> authorizedDevices;

  const SecurityInfoModel({
    required this.securityScore,
    required this.biometricsEnabled,
    required this.twoFactorEnabled,
    required this.lastPasswordChange,
    required this.authorizedDevices,
  });

  SecurityInfoModel copyWith({
    int? securityScore,
    bool? biometricsEnabled,
    bool? twoFactorEnabled,
    DateTime? lastPasswordChange,
    List<SecurityDeviceModel>? authorizedDevices,
  }) {
    return SecurityInfoModel(
      securityScore: securityScore ?? this.securityScore,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      lastPasswordChange: lastPasswordChange ?? this.lastPasswordChange,
      authorizedDevices: authorizedDevices ?? this.authorizedDevices,
    );
  }

  static SecurityInfoModel initial() {
    return SecurityInfoModel(
      securityScore: 85,
      biometricsEnabled: false,
      twoFactorEnabled: false,
      lastPasswordChange: DateTime.now(),
      authorizedDevices: [
        SecurityDeviceModel(
          id: 'dev_current',
          deviceName: 'EduBoard Mobile Device',
          platform: 'Mobile Native (Flutter)',
          ipAddress: '10.0.2.2',
          lastActive: DateTime.now(),
          isCurrentDevice: true,
        ),
      ],
    );
  }
}
