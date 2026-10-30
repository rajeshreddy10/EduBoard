import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/services/api_client.dart';
import '../core/utilities/safe_json.dart';
import '../models/security_info_model.dart';

/// Safe substring that never RangeErrors on short IDs.
String _shortId(String value) =>
    value.length <= 5 ? value : value.substring(0, 5);

abstract class SecurityRepository {
  Future<SecurityInfoModel> getSecurityInfo();
  Future<void> toggleBiometrics(bool enabled);
  Future<void> toggleTwoFactor(bool enabled);
  Future<void> revokeDevice(String deviceId);
  Future<bool> updatePassword(String oldPassword, String newPassword);
}

class LiveSecurityRepository implements SecurityRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiClient _api = ApiClient();

  String? get _currentUserId => _auth.currentUser?.uid;

  @override
  Future<SecurityInfoModel> getSecurityInfo() async {
    final uid = _currentUserId;
    if (uid != null) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final isBio = asBoolOr(
            data['isBiometricEnabled'] ?? data['biometricsEnabled'],
            false,
          );
          final is2fa = asBoolOr(data['twoFactorEnabled'], false);
          final lastPass = asDateOr(data['lastPasswordChange'], DateTime.now());

          final rawDevices = data['authorizedDevices'] as List<dynamic>?;
          List<SecurityDeviceModel> devices = [];
          if (rawDevices != null && rawDevices.isNotEmpty) {
            devices = rawDevices
                .whereType<Map>()
                .map((d) => SecurityDeviceModel.fromJson(Map<String, dynamic>.from(d)))
                .toList();
          } else {
            devices = [
              SecurityDeviceModel(
                id: 'dev_mobile_${_shortId(uid)}',
                deviceName: 'EduBoard Mobile Client',
                platform: 'Mobile Native',
                ipAddress: '10.0.2.2',
                lastActive: DateTime.now(),
                isCurrentDevice: true,
              )
            ];
          }

          int score = 70;
          if (isBio) score += 15;
          if (is2fa) score += 15;

          return SecurityInfoModel(
            securityScore: score,
            biometricsEnabled: isBio,
            twoFactorEnabled: is2fa,
            lastPasswordChange: lastPass,
            authorizedDevices: devices,
          );
        }
      } catch (e) {
        debugPrint('[Firestore getSecurityInfo Error] $e');
      }
    }

    return SecurityInfoModel.initial();
  }

  @override
  Future<void> toggleBiometrics(bool enabled) async {
    final uid = _currentUserId;
    if (uid != null) {
      try {
        await _firestore.collection('users').doc(uid).set({
          'isBiometricEnabled': enabled,
          'biometricsEnabled': enabled,
          'updated_at': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        debugPrint('[toggleBiometrics Error] timed out');
      } catch (e) {
        debugPrint('[toggleBiometrics Error] $e');
      }
    }
  }

  @override
  Future<void> toggleTwoFactor(bool enabled) async {
    final uid = _currentUserId;
    if (uid != null) {
      try {
        await _firestore.collection('users').doc(uid).set({
          'twoFactorEnabled': enabled,
          'updated_at': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      } on TimeoutException {
        debugPrint('[toggleTwoFactor Error] timed out');
      } catch (e) {
        debugPrint('[toggleTwoFactor Error] $e');
      }
    }
  }

  @override
  Future<void> revokeDevice(String deviceId) async {
    final uid = _currentUserId;
    if (uid != null) {
      try {
        final docRef = _firestore.collection('users').doc(uid);
        final doc = await docRef.get().timeout(const Duration(seconds: 8));
        if (doc.exists && doc.data() != null) {
          final rawDevices = doc.data()!['authorizedDevices'] as List<dynamic>? ?? [];
          final filtered =
              rawDevices.whereType<Map>().where((d) => d['id'].toString() != deviceId.toString()).toList();
          await docRef
              .set({'authorizedDevices': filtered}, SetOptions(merge: true))
              .timeout(const Duration(seconds: 10));
        }
      } on TimeoutException {
        debugPrint('[revokeDevice Error] timed out');
      } catch (e) {
        debugPrint('[revokeDevice Error] $e');
      }
    }
  }

  @override
  Future<bool> updatePassword(String oldPassword, String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Re-authenticate if email is available and old password was provided
      if (user.email != null && oldPassword.isNotEmpty) {
        final cred = EmailAuthProvider.credential(email: user.email!, password: oldPassword);
        await user.reauthenticateWithCredential(cred);
      }

      await user.updatePassword(newPassword);

      if (_currentUserId != null) {
        await _firestore.collection('users').doc(_currentUserId).set({
          'lastPasswordChange': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }

      // Also notify backend if supported
      try {
        await _api.post('/auth/reset-password', body: {'password': newPassword});
      } catch (_) {}

      return true;
    } catch (e) {
      debugPrint('[updatePassword Error] $e');
      rethrow;
    }
  }
}
