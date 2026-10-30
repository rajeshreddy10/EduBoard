import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/services/storage_service.dart';
import '../models/user_profile_model.dart';
import '../repositories/auth_repository.dart';

class AuthState {
  final bool isAuthenticated;
  final bool isLoading;
  final bool isOnboarded;

  /// True while Firebase is restoring the persisted session on cold start.
  /// The splash screen waits for this to settle before routing, which is what
  /// makes app restarts land on the Dashboard instead of the Login screen.
  final bool isRestoringSession;

  final String? userEmail;
  final String? userId;
  final String? errorMessage;
  final UserProfileModel? profile;

  const AuthState({
    required this.isAuthenticated,
    this.isLoading = false,
    this.isOnboarded = false,
    this.isRestoringSession = false,
    this.userEmail,
    this.userId,
    this.errorMessage,
    this.profile,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    bool? isOnboarded,
    bool? isRestoringSession,
    String? userEmail,
    String? userId,
    String? errorMessage,
    UserProfileModel? profile,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      isLoading: isLoading ?? this.isLoading,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      isRestoringSession: isRestoringSession ?? this.isRestoringSession,
      userEmail: userEmail ?? this.userEmail,
      userId: userId ?? this.userId,
      errorMessage: errorMessage,
      profile: profile ?? this.profile,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _authRepository => ref.read(authRepositoryProvider);
  StreamSubscription<User?>? _restoreSub;

  @override
  AuthState build() {
    final onboarded = StorageService.get<bool>(AppConstants.authBox, 'is_onboarded', defaultValue: false) ?? false;
    final authed = StorageService.get<bool>(AppConstants.authBox, 'is_authenticated', defaultValue: false) ?? false;
    final email = StorageService.get<String>(AppConstants.authBox, 'user_email', defaultValue: '') ?? '';
    final currentFbUser = _authRepository.currentUser;

    final isActuallyAuthed = currentFbUser != null || (authed == true);
    final activeEmail = (currentFbUser?.email ?? email).toString();

    ref.onDispose(() {
      _restoreSub?.cancel();
    });

    // Background profile fetch immediately after first frame (doesn't block
    // startup rendering).
    if (isActuallyAuthed) {
      Future.microtask(() async {
        try {
          final profile = await _authRepository.getCurrentUserProfile();
          if (profile != null) {
            state = state.copyWith(
              profile: profile,
              userEmail: profile.email.isNotEmpty ? profile.email : activeEmail,
              userId: profile.id,
            );
          }
        } catch (e) {
          // Profile sync failures must never block the app shell.
          state = state.copyWith();
        }
      });
    }

    // React to session lifecycle: Firebase restores a persisted session
    // asynchronously on cold start (currentUser may still be null on the
    // first synchronous read). The stream completion flips
    // [isRestoringSession] off once the native bridge has resolved.
    _restoreSub = _authRepository.authStateChanges.listen(
      (user) {
        if (user != null) {
          state = state.copyWith(
            isAuthenticated: true,
            isRestoringSession: false,
            userEmail: user.email,
            userId: user.uid,
            errorMessage: null,
          );
          StorageService.put(AppConstants.authBox, 'is_authenticated', true);
          if (user.email != null) {
            StorageService.put(AppConstants.authBox, 'user_email', user.email);
          }
          Future.microtask(() async {
            final profile = await _authRepository.getCurrentUserProfile();
            if (profile != null) {
              state = state.copyWith(profile: profile, userId: profile.id);
            }
          });
        } else {
          state = state.copyWith(
            isAuthenticated: false,
            isRestoringSession: false,
            profile: null,
            userId: null,
          );
        }
      },
      onError: (_) {
        state = state.copyWith(isRestoringSession: false);
      },
    );

    return AuthState(
      isOnboarded: onboarded,
      isAuthenticated: isActuallyAuthed,
      // Firebase cold-start restore is considered pending until the stream
      // emits; the splash waits at most 2.5s before falling back to local
      // persisted state.
      isRestoringSession: true,
      userEmail: activeEmail.isNotEmpty ? activeEmail : null,
      userId: currentFbUser?.uid,
    );
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (email.isEmpty || password.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'Please enter both email and password');
      return false;
    }

    try {
      final profile = await _authRepository.login(email, password);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userEmail: email.trim().toLowerCase(),
        userId: profile?.id,
        profile: profile,
        errorMessage: null,
      );
      await StorageService.put(AppConstants.authBox, 'is_authenticated', true);
      await StorageService.put(AppConstants.authBox, 'user_email', email.trim().toLowerCase());
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e));
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      state = state.copyWith(isLoading: false, errorMessage: 'All fields are required');
      return false;
    }

    try {
      final profile = await _authRepository.signup(name, email, password);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        userEmail: email.trim().toLowerCase(),
        userId: profile?.id,
        profile: profile,
        errorMessage: null,
      );
      await StorageService.put(AppConstants.authBox, 'is_authenticated', true);
      await StorageService.put(AppConstants.authBox, 'user_email', email.trim().toLowerCase());
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e));
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final profile = await _authRepository.signInWithGoogle();
      if (profile != null) {
        state = state.copyWith(
          isLoading: false,
          isAuthenticated: true,
          userEmail: profile.email,
          userId: profile.id,
          profile: profile,
          errorMessage: null,
        );
        await StorageService.put(AppConstants.authBox, 'is_authenticated', true);
        if (profile.email.isNotEmpty) {
          await StorageService.put(AppConstants.authBox, 'user_email', profile.email);
        }
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e));
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _authRepository.sendPasswordReset(email);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: _friendlyAuthError(e));
      return false;
    }
  }

  Future<void> completeOnboarding() async {
    state = state.copyWith(isOnboarded: true);
    await StorageService.put(AppConstants.authBox, 'is_onboarded', true);
  }

  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (_) {}
    // Clear the persisted session flag so the next cold start routes to the
    // Login screen instead of briefly reaching for the Dashboard.
    await StorageService.put(AppConstants.authBox, 'is_authenticated', false);
    state = state.copyWith(
      isAuthenticated: false,
      userEmail: null,
      userId: null,
      profile: null,
      errorMessage: null,
    );
  }

  String _friendlyAuthError(Object e) {
    final raw = e.toString();
    if (raw.contains('DEVELOPER_ERROR') ||
        raw.contains('com.google.android.gms') ||
        raw.contains('12500') ||
        raw.contains('10:')) {
      return 'Google Sign-In is unavailable on this emulator/device setup. Please sign in with email and password.';
    }
    if (raw.contains('invalid-credential')) {
      return 'Incorrect email or password. Try again or reset your password.';
    }
    if (raw.contains('wrong-password')) {
      return 'Incorrect password. Please try again.';
    }
    if (raw.contains('user-not-found')) {
      return 'No account found for this email. Create one to continue.';
    }
    if (raw.contains('invalid-email')) {
      return 'That email address looks invalid. Please check it.';
    }
    if (raw.contains('email-already-in-use')) {
      return 'An account already exists with this email. Try signing in.';
    }
    if (raw.contains('weak-password')) {
      return 'Password too weak — use at least 6 characters.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (raw.contains('network-request-failed') ||
        raw.contains('Network error') ||
        raw.contains('Backend unreachable')) {
      return 'Network problem. Check your internet connection and try again.';
    }
    return raw.replaceFirst('Exception: ', '').trim();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => FirebaseAuthRepository());
final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
