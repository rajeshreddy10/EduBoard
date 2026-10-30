import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_profile_model.dart';
import '../repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return FirebaseProfileRepository();
});

class ProfileNotifier extends Notifier<UserProfileModel> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);
  StreamSubscription<UserProfileModel?>? _profileSub;

  @override
  UserProfileModel build() {
    ref.onDispose(() {
      _profileSub?.cancel();
    });

    Future.microtask(() => _init());
    return UserProfileModel.empty();
  }

  Future<void> _init() async {
    final prof = await _repo.getProfile();
    state = prof;

    // Real-time synchronization: listen for remote Firestore profile changes
    _profileSub = _repo.watchProfile().listen((liveProf) {
      if (liveProf != null) {
        state = liveProf;
      }
    }, onError: (e) {
      debugPrint('[Profile Stream Warning] $e');
    });
  }

  Future<void> updateAcademicInfo({
    required String name,
    required String institution,
    required String department,
    required String role,
  }) async {
    final updated = state.copyWith(
      name: name,
      institution: institution,
      department: department,
      role: role,
    );
    state = updated;
    await _repo.updateProfile(updated);
  }

  Future<void> updateBio(String bio) async {
    final updated = state.copyWith(bio: bio);
    state = updated;
    await _repo.updateProfile(updated);
  }

  Future<void> updatePhilosophy(String philosophy) async {
    final updated = state.copyWith(teachingPhilosophy: philosophy);
    state = updated;
    await _repo.updateProfile(updated);
  }

  Future<void> updateAvatar(String? avatarUrl) async {
    final updated = state.copyWith(avatarUrl: avatarUrl);
    state = updated;
    await _repo.updateProfile(updated);
  }

  Future<String?> uploadAvatarBytes(Uint8List bytes, String extension) async {
    final url = await _repo.uploadAvatarBytes(bytes, extension);
    if (url != null) {
      state = state.copyWith(avatarUrl: url);
    }
    return url;
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, UserProfileModel>(ProfileNotifier.new);
