import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants/app_constants.dart';
import '../core/services/api_client.dart';
import '../core/services/storage_service.dart';
import '../models/user_profile_model.dart';
import '../core/utilities/safe_json.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  User? get currentUser;

  /// True only when Firebase is live AND a Google OAuth client is registered
  /// for this package. Lets the Login screen disable the Google button
  /// gracefully instead of surfacing Android's raw DEVELOPER_ERROR.
  bool get googleSignInAvailable;

  /// Human-readable explanation when [googleSignInAvailable] is false.
  String? get googleSignInUnavailableReason;

  Future<UserProfileModel?> login(String email, String password);
  Future<UserProfileModel?> signup(String name, String email, String password);
  Future<UserProfileModel?> signInWithGoogle();
  Future<void> sendPasswordReset(String email);
  Future<void> logout();
  Future<UserProfileModel?> getCurrentUserProfile();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuth? get _auth {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null; // Firebase not initialized on this environment.
    }
  }

  FirebaseFirestore? get _firestore {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  final ApiClient _api = ApiClient();
  GoogleSignIn? _googleSignIn;

  @override
  Stream<User?> get authStateChanges => _auth?.authStateChanges() ?? Stream.value(null);

  @override
  User? get currentUser => _auth?.currentUser;

  /// Validates the local google-services configuration and logs actionable
  /// diagnostics. A configured OAuth client requires a syntactically valid
  /// web client ID (numeric prefix plus the googleusercontent.com suffix).
  /// Fabricated or missing values are the source of Android's
  /// `DEVELOPER_ERROR` / "Unknown calling package name" crash when tapping
  /// Continue with Google; the actual guard happens in [signInWithGoogle],
  /// which converts that native exception into a friendly message.
  @override
  bool get googleSignInAvailable {
    try {
      if (_auth == null) return false;
      _assertGoogleConfigHealth();
      _googleSignIn ??= GoogleSignIn();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _assertGoogleConfigHealth() {
    if (kIsWeb) return;
    try {
      if (!defaultTargetPlatform.toString().contains('android')) return;
    } catch (_) {
      return;
    }
    final app = _auth!.app;
    final options = app.options;
    // Real Firebase Android app IDs are "1:<senderId>:android:<22-char id>".
    final regex = RegExp(r'^1:\d+:android:[A-Za-z0-9_\-]{11,}$');
    if (!regex.hasMatch(options.appId)) {
      debugPrint(
        '[Auth] Google Sign-In config warning: app id "${options.appId}" does '
        'not look like a real Firebase Android app id. Regenerate '
        'google-services.json from the Firebase console (with the app\'s '
        'SHA-1/SHA-256 fingerprints registered) to enable Google Sign-In.',
      );
    }
  }

  @override
  String? get googleSignInUnavailableReason {
    if (googleSignInAvailable) return null;
    return 'Google Sign-In is not configured for this build. '
        'Sign in with email instead, or register this app\'s SHA fingerprints '
        'in the Firebase console and reinstall.';
  }

  @override
  Future<UserProfileModel?> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    UserCredential? credential;
    String? authError;

    try {
      credential = await _auth?.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      authError = e.message ?? e.code;
      debugPrint('[FirebaseAuth Login Note] ${e.code}: ${e.message}');
    } catch (e) {
      authError = e.toString();
    }

    // Authenticate with Express Backend to obtain/refresh backend JWT
    // (kept as a secondary session so the backend has its own claims even if
    // Firebase ID token verification fails).
    bool backendSuccess = false;
    try {
      final idToken = await _api.getFreshFirebaseToken();
      final res = await _api.post('/auth/login', body: {
        'email': normalizedEmail,
        'password': password,
        if (idToken != null) 'idToken': idToken,
      });
      if (res is Map && res['token'] != null) {
        _api.setToken(res['token'].toString());
        backendSuccess = true;
      }
    } catch (e) {
      debugPrint('[Backend Login Note] $e');
    }

    final uid = credential?.user?.uid ?? _auth?.currentUser?.uid;
    if (uid == null && !backendSuccess) {
      throw Exception(authError ?? 'Invalid email or password. Please try again.');
    }

    // Ensure the Firestore session data (userSettings/{uid}) has a base
    // record so the backend can always resolve the session user.
    final profile = await _fetchOrSyncUser(uid, normalizedEmail);
    if (uid != null) {
      try {
        await _firestore?.collection('users').doc(uid).set({
          'last_login_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    return profile;
  }

  @override
  Future<UserProfileModel?> signup(String name, String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    UserCredential? credential;

    try {
      if (_auth != null) {
        credential = await _auth!.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
        await credential.user?.updateDisplayName(name);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebaseAuth Signup Error] ${e.code}: ${e.message}');
      throw Exception(e.message ?? 'Signup failed: ${e.code}');
    } catch (e) {
      throw Exception(e.toString());
    }

    final uid = credential?.user?.uid;
    if (uid == null) {
      throw Exception('Account creation failed — signup engine unavailable.');
    }

    // Register with Express Backend to populate user record and obtain token
    try {
      final res = await _api.post('/auth/register', body: {
        'email': normalizedEmail,
        'password': password,
        'fullName': name,
        'name': name,
        'uid': uid,
      });
      if (res is Map && res['token'] != null) {
        _api.setToken(res['token'].toString());
      }
    } catch (e) {
      debugPrint('[Backend Register Note] $e');
    }

    // Persist to shared Firestore `users/{uid}` collection matching Web app schema
    final userDoc = {
      'id': uid,
      'uid': uid,
      'email': normalizedEmail,
      'name': name,
      'full_name': name,
      'role': 'teacher',
      'institution': 'EduBoard Academic Institute',
      'department': 'Education & Sciences',
      'bio': 'Passionate educator on EduBoard.',
      'teachingPhilosophy': 'Visual, interactive, and collaborative learning.',
      'subjects': ['Mathematics', 'Science'],
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'last_login_at': DateTime.now().toIso8601String(),
    };

    try {
      await _firestore?.collection('users').doc(uid).set(userDoc, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore User Creation Note] $e');
    }

    return UserProfileModel.fromJson(userDoc);
  }

  @override
  Future<UserProfileModel?> signInWithGoogle() async {
    // The Android DEVELOPER_ERROR / "Unknown calling package name" crash is
    // thrown natively when no OAuth client is registered for this package +
    // SHA fingerprint. Detect it up-front and fail with clear guidance
    // instead of surfacing a raw PlatformException.
    if (!googleSignInAvailable) {
      throw Exception(googleSignInUnavailableReason ??
          'Google Sign-In is not available on this device. Please sign in with email.');
    }

    try {
      final googleUser = await _googleSignIn?.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth?.signInWithCredential(credential);
      final user = userCredential?.user;

      // Sync with Express backend using a fresh Firebase ID token
      final idToken = await _api.getFreshFirebaseToken(forceRefresh: true);
      try {
        final res = await _api.post('/auth/oauth/google', body: {
          if (googleAuth.idToken != null) 'idToken': googleAuth.idToken,
          if (idToken != null) 'firebaseIdToken': idToken,
        });
        if (res is Map && res['token'] != null) {
          _api.setToken(res['token'].toString());
        }
      } catch (e) {
        debugPrint('[Backend Google Sync Note] $e');
      }

      if (user != null) {
        return await _fetchOrSyncUser(
          user.uid,
          user.email ?? googleUser.email,
          name: user.displayName ?? googleUser.displayName,
        );
      }
    } on PlatformException catch (e) {
      debugPrint('[Google Sign-In Error] ${e.code}: ${e.message}');
      if (e.code == 'DEVELOPER_ERROR' || e.code == '10') {
        throw Exception(
          'Google Sign-In is not registered for this app build. '
          'Email sign-in works right away — add this build\'s SHA-1/SHA-256 '
          'fingerprints in the Firebase console to enable Google sign-in.',
        );
      }
      if (e.code == 'sign_in_failed') {
        throw Exception('Google Sign-In was interrupted. Please try again.');
      }
      rethrow;
    } catch (e) {
      debugPrint('[Google Sign-In Error] $e');
      rethrow;
    }
    return null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final normalized = email.trim().toLowerCase();
    var firebaseSent = false;
    try {
      await _auth?.sendPasswordResetEmail(email: normalized);
      firebaseSent = true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email') {
        throw Exception('That email address looks invalid. Please check it.');
      }
      debugPrint('[Firebase sendPasswordReset Note] ${e.code}');
    } catch (e) {
      debugPrint('[Firebase sendPasswordReset Note] $e');
    }
    try {
      await _api.post('/auth/forgot-password', body: {'email': normalized});
    } catch (e) {
      debugPrint('[Backend forgot-password Note] $e');
      if (!firebaseSent) {
        throw Exception(
            'Reset email could not be sent. Check your connection and try again.');
      }
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _googleSignIn?.signOut();
    } catch (_) {}
    try {
      await _auth?.signOut();
    } catch (_) {}
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    _api.setToken(null);
    await StorageService.put(AppConstants.authBox, 'is_authenticated', false);
    await StorageService.delete(AppConstants.authBox, 'jwt_token');
    await StorageService.delete(AppConstants.authBox, 'user_email');
  }

  @override
  Future<UserProfileModel?> getCurrentUserProfile() async {
    final user = _auth?.currentUser;
    if (user == null) return null;
    return await _fetchOrSyncUser(user.uid, user.email ?? '', name: user.displayName);
  }

  Future<UserProfileModel> _fetchOrSyncUser(String? uid, String email, {String? name}) async {
    if (uid != null && _firestore != null) {
      try {
        final doc = await _firestore!.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          return UserProfileModel(
            id: uid,
            name: asStringOr(
                data['name'] ?? data['full_name'] ?? name ?? email.split('@')[0],
                email.split('@')[0]),
            email: asStringOr(data['email'] ?? email, email),
            address: asStringOr(data['address'], ''),
            organization: asStringOr(data['organization'] ?? data['institution'], 'EduBoard'),
            phone: asStringOr(data['phone'] ?? data['phoneNumber'] ?? data['phone_number'], ''),
            location: asStringOr(data['location'], ''),
            bio: asStringOr(data['bio'], ''),
            avatarUrl: asStringOrNullable(data['avatar'] ?? data['avatarUrl'] ?? data['photoURL']),
            role: asStringOr(data['role'], 'User'),
          );
        }
      } catch (e) {
        debugPrint('[Firestore Fetch User Note] $e');
      }

      // Try Backend GET /api/users/:id fallback
      try {
        final res = await _api.get('/users/$uid');
        if (res is Map && res['email'] != null) {
          return UserProfileModel(
            id: uid,
            name: asStringOr(res['name'] ?? res['full_name'] ?? name ?? email.split('@')[0],
                email.split('@')[0]),
            email: asStringOr(res['email'], email),
            address: asStringOr(res['address'], ''),
            organization: asStringOr(res['organization'] ?? res['institution'], 'EduBoard'),
            phone: asStringOr(res['phone'] ?? res['phoneNumber'] ?? res['phone_number'], ''),
            location: asStringOr(res['location'], ''),
            bio: asStringOr(res['bio'], ''),
            avatarUrl: asStringOrNullable(res['avatar'] ?? res['avatarUrl']),
            role: asStringOr(res['role'], 'User'),
          );
        }
      } catch (_) {}
    }

    final fallback = UserProfileModel(
      id: uid ?? 'user_default',
      name: name ?? email.split('@')[0],
      email: email,
      address: '',
      organization: 'EduBoard',
      phone: '',
      location: '',
      bio: 'EduBoard user.',
      role: 'User',
    );

    if (uid != null && _firestore != null) {
      try {
        await _firestore!.collection('users').doc(uid).set({
          ...fallback.toJson(),
          'full_name': fallback.name,
          'updated_at': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    return fallback;
  }
}

String? asStringOrNullable(dynamic value) {
  if (value == null) return null;
  final str = value.toString();
  return str.isEmpty ? null : str;
}

List<String> asStringListOr(dynamic value, List<String> fallback) {
  if (value is List) {
    return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
  }
  return fallback;
}
