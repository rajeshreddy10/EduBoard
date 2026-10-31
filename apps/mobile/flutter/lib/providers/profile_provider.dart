import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
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
  StreamSubscription<User?>? _authSub;

  @override
  UserProfileModel build() {
    ref.onDispose(() {
      _profileSub?.cancel();
      _authSub?.cancel();
    });

    Future.microtask(() => _init());
    return UserProfileModel.empty();
  }

  Future<void> _init() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      await _subscribeToUserProfile(currentUid);
    } else {
      final prof = await _repo.getProfile();
      state = prof;
    }

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      final uid = user?.uid;
      if (uid != null) {
        await _subscribeToUserProfile(uid);
      } else {
        _profileSub?.cancel();
        state = UserProfileModel.empty();
      }
    });
  }

  Future<void> _subscribeToUserProfile(String uid) async {
    _profileSub?.cancel();
    final prof = await _repo.getProfile(uid);
    state = prof;

    // Real-time synchronization: listen for remote Firestore profile changes
    _profileSub = _repo.watchProfile(uid).listen((liveProf) {
      if (liveProf != null) {
        state = liveProf;
      }
    }, onError: (e) {
      debugPrint('[Profile Stream Warning] $e');
    });
  }

  Future<void> saveProfile({
    required String name,
    required String address,
    required String organization,
    required String phone,
    required String location,
    required String bio,
    String? avatarUrl,
  }) async {
    final updated = state.copyWith(
      name: name,
      address: address,
      organization: organization,
      phone: phone,
      location: location,
      bio: bio,
      avatarUrl: avatarUrl ?? state.avatarUrl,
    );
    state = updated;
    await _repo.updateProfile(updated);
  }

  Future<void> updateAcademicInfo({
    required String name,
    required String institution,
    required String department,
    required String role,
  }) async {
    final updated = state.copyWith(
      name: name,
      organization: institution,
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
    // Teaching philosophy removed as per profile requirements; no-op
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
