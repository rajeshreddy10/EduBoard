import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/security_info_model.dart';
import '../repositories/security_repository.dart';

final securityRepositoryProvider = Provider<SecurityRepository>((ref) {
  return LiveSecurityRepository();
});

class SecurityNotifier extends Notifier<SecurityInfoModel> {
  SecurityRepository get _repo => ref.read(securityRepositoryProvider);

  @override
  SecurityInfoModel build() {
    Future.microtask(() => _loadSecurity());
    return SecurityInfoModel.initial();
  }

  Future<void> _loadSecurity() async {
    final info = await _repo.getSecurityInfo();
    state = info;
  }

  Future<void> toggleBiometrics(bool enabled) async {
    state = state.copyWith(
      biometricsEnabled: enabled,
      securityScore: enabled ? (state.securityScore + 6).clamp(0, 100) : (state.securityScore - 6).clamp(0, 100),
    );
    await _repo.toggleBiometrics(enabled);
  }

  Future<void> toggleTwoFactor(bool enabled) async {
    state = state.copyWith(
      twoFactorEnabled: enabled,
      securityScore: enabled ? (state.securityScore + 10).clamp(0, 100) : (state.securityScore - 10).clamp(0, 100),
    );
    await _repo.toggleTwoFactor(enabled);
  }

  Future<void> revokeDevice(String deviceId) async {
    await _repo.revokeDevice(deviceId);
    final updated = state.authorizedDevices.where((d) => d.id != deviceId).toList();
    state = state.copyWith(authorizedDevices: updated);
  }

  Future<bool> updatePassword(String oldPass, String newPass) async {
    final success = await _repo.updatePassword(oldPass, newPass);
    if (success) {
      state = state.copyWith(lastPasswordChange: DateTime.now());
    }
    return success;
  }
}

final securityProvider = NotifierProvider<SecurityNotifier, SecurityInfoModel>(SecurityNotifier.new);
