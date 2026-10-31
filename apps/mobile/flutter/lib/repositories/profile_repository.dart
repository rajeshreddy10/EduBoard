import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/services/api_client.dart';
import '../models/user_profile_model.dart';

abstract class ProfileRepository {
  Future<UserProfileModel> getProfile();
  Future<void> updateProfile(UserProfileModel profile);
  Stream<UserProfileModel?> watchProfile();
  Future<String?> uploadAvatarBytes(Uint8List bytes, String extension);
}

class FirebaseProfileRepository implements ProfileRepository {
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

  FirebaseStorage? get _storage {
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  final ApiClient _api = ApiClient();

  String? get _currentUserId => _auth?.currentUser?.uid;

  @override
  Stream<UserProfileModel?> watchProfile() {
    final uid = _currentUserId;
    final fs = _firestore;
    if (uid == null || fs == null) {
      return Stream.value(null);
    }
    return fs.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserProfileModel.fromJson({'id': snap.id, ...snap.data()!});
    }).handleError((e) {
      debugPrint('[Profile Stream Warning] $e');
    });
  }

  @override
  Future<UserProfileModel> getProfile() async {
    final uid = _currentUserId;
    final user = _auth?.currentUser;
    final fs = _firestore;

    if (uid != null && fs != null) {
      try {
        final doc = await fs
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 8));
        if (doc.exists && doc.data() != null) {
          return UserProfileModel.fromJson({'id': doc.id, ...doc.data()!});
        }
      } on TimeoutException {
        debugPrint('[Firestore getProfile Error] timed out');
      } catch (e) {
        debugPrint('[Firestore getProfile Error] $e');
      }

      // Try Backend GET /api/users/:id
      try {
        final res = await _api.get('/users/$uid');
        if (res is Map && res['email'] != null) {
          return UserProfileModel.fromJson(Map<String, dynamic>.from(res));
        }
      } catch (e) {
        debugPrint('[Backend getProfile Error] $e');
      }
    }

    if (user != null) {
      final defaultProfile = UserProfileModel(
        id: user.uid,
        name: user.displayName ?? user.email?.split('@').first ?? 'EduBoard User',
        email: user.email ?? '',
        address: '',
        organization: 'EduBoard',
        phone: '',
        location: '',
        bio: '',
        avatarUrl: user.photoURL,
      );
      try {
        await _firestore
            ?.collection('users')
            .doc(user.uid)
            .set(defaultProfile.toJson(), SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        debugPrint('[Firestore setDefaultProfile] timed out');
      } catch (_) {}
      return defaultProfile;
    }

    return UserProfileModel.empty();
  }

  @override
  Future<void> updateProfile(UserProfileModel profile) async {
    final uid = profile.id.isNotEmpty ? profile.id : _currentUserId;
    if (uid == null || uid.isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();
    final data = {
      'id': uid,
      'uid': uid,
      'name': profile.name,
      'full_name': profile.name,
      'email': profile.email,
      'address': profile.address,
      'organization': profile.organization,
      'institution': profile.organization,
      'phone': profile.phone,
      'phoneNumber': profile.phone,
      'phone_number': profile.phone,
      'location': profile.location,
      'bio': profile.bio,
      'avatar': profile.avatarUrl,
      'avatarUrl': profile.avatarUrl,
      'photoURL': profile.avatarUrl,
      'updated_at': nowIso,
      'updatedAt': nowIso,
    };

    // 1. Update shared Firestore users/{uid} collection
    final fs = _firestore;
    if (fs != null) {
      try {
        await fs
            .collection('users')
            .doc(uid)
            .set(data, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
      } on TimeoutException {
        debugPrint('[Firestore updateProfile Error] timed out');
      } catch (e) {
        debugPrint('[Firestore updateProfile Error] $e');
      }
    }

    // 2. Also sync to backend users route if available
    try {
      await _api.put('/users/$uid/role', body: {'role': profile.role});
    } catch (_) {}
  }

  @override
  Future<String?> uploadAvatarBytes(Uint8List bytes, String extension) async {
    final uid = _currentUserId;
    final storage = _storage;
    final fs = _firestore;
    if (uid == null || storage == null || fs == null) return null;

    try {
      final storageRef = storage.ref().child('users/$uid/avatar');
      final metadata = SettableMetadata(contentType: 'image/$extension');
      await storageRef.putData(bytes, metadata).timeout(const Duration(seconds: 30));
      final downloadUrl = await storageRef.getDownloadURL().timeout(const Duration(seconds: 10));

      // Persist download URL in user's profile
      await fs.collection('users').doc(uid).set({
        'avatar': downloadUrl,
        'avatarUrl': downloadUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));

      return downloadUrl;
    } on TimeoutException {
      debugPrint('[Avatar Upload Error] timed out');
      return null;
    } catch (e) {
      debugPrint('[Firebase Storage Avatar Upload Error] $e');
      return null;
    }
  }
}
