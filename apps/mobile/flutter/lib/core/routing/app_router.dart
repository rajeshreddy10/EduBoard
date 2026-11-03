import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../features/appearance/screens/appearance_screen.dart';
import '../../features/authentication/screens/forgot_password_screen.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/signup_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/doccanvas/screens/doccanvas_screen.dart';
import '../../features/drawspace/screens/drawspace_screen.dart';
import '../../features/history/screens/history_screen.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/onboarding/screens/splash_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/security/screens/security_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/voiceboard/screens/voiceboard_screen.dart';
import '../../features/help/screens/help_screen.dart';
import '../animations/page_transitions.dart';
import '../widgets/main_scaffold_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');
final _dashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dashNav');
final _studiosNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'studiosNav');
final _resourcesNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'resourcesNav');
final _analyticsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'analyticsNav');
final _profileNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'profNav');

/// Application GoRouter provider with StatefulShellRoute bottom navigation
final appRouterProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects whenever the Firebase session changes (login,
  // logout, cold-start restore). Without this the guard only runs on explicit
  // navigation events.
  final authStream = authStateChangesStream();

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: _StreamListenable(authStream),
    // Auth redirect guard: deep links and tab jumps into protected studio
    // routes are bounced to /login when no real session exists, while manual
    // navigation to /login stays stable while restoring/offline.
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onSplash = location == '/splash';
      final onPublicAuthRoute = location == '/login' ||
          location == '/signup' ||
          location == '/forgot-password' ||
          location == '/onboarding';

      // Never fight the splash while it performs its own restore-wait flow.
      if (onSplash) return null;

      final firebaseUser =
          Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser;
      // Offline tolerance: accept the locally persisted "was signed in" flag
      // when Firebase cannot confirm right now (no connectivity).
      final persistedAuth = ref.read(authProvider).isAuthenticated;
      final authenticated = firebaseUser != null || persistedAuth;

      if (!authenticated) {
        return onPublicAuthRoute ? null : '/login';
      }

      // Authenticated users should not sit on login/signup screens.
      if (authenticated && (location == '/login' || location == '/signup')) {
        return '/dashboard';
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 64),
            const SizedBox(height: 16),
            Text('Page Not Found', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(state.uri.toString()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    ),
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
          key: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const SignupScreen(),
        ),
      ),
      GoRoute(
        path: '/forgot-password',
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),
      // Stateful shell for Bottom Navigation Tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffoldShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _studiosNavigatorKey,
            routes: [
              GoRoute(
                path: '/studios',
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const DrawSpaceScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _resourcesNavigatorKey,
            routes: [
              GoRoute(
                path: '/resources',
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const HistoryScreen(),
                ),
              ),
              GoRoute(
                path: '/history',
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const HistoryScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _analyticsNavigatorKey,
            routes: [
              GoRoute(
                path: '/analytics',
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const HistoryScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                pageBuilder: (context, state) => AppPageTransitions.fadeThrough(
                  key: state.pageKey,
                  child: const ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      // Standalone full-screen studio and configuration screens
      GoRoute(
        path: '/normal-board',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? state.uri.queryParameters['boardId'] ?? (state.extra is Map ? ((state.extra as Map)['id'] ?? (state.extra as Map)['boardId'])?.toString() : (state.extra is String ? state.extra as String : null));
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: DrawSpaceScreen(boardId: id),
          );
        },
      ),
      GoRoute(
        path: '/drawspace',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? state.uri.queryParameters['boardId'] ?? (state.extra is Map ? ((state.extra as Map)['id'] ?? (state.extra as Map)['boardId'])?.toString() : (state.extra is String ? state.extra as String : null));
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: DrawSpaceScreen(boardId: id),
          );
        },
      ),
      GoRoute(
        path: '/voice-control',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? state.uri.queryParameters['sessionId'] ?? (state.extra is Map ? ((state.extra as Map)['id'] ?? (state.extra as Map)['sessionId'])?.toString() : (state.extra is String ? state.extra as String : null));
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: VoiceBoardScreen(sessionId: id),
          );
        },
      ),
      GoRoute(
        path: '/voiceboard',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? state.uri.queryParameters['sessionId'] ?? (state.extra is Map ? ((state.extra as Map)['id'] ?? (state.extra as Map)['sessionId'])?.toString() : (state.extra is String ? state.extra as String : null));
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: VoiceBoardScreen(sessionId: id),
          );
        },
      ),
      GoRoute(
        path: '/gesture-board',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? state.uri.queryParameters['docId'] ?? state.uri.queryParameters['documentId'] ?? (state.extra is Map ? ((state.extra as Map)['id'] ?? (state.extra as Map)['docId'])?.toString() : (state.extra is String ? state.extra as String : null));
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: DocCanvasScreen(documentId: id),
          );
        },
      ),
      GoRoute(
        path: '/document-studio',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? state.uri.queryParameters['docId'] ?? state.uri.queryParameters['documentId'] ?? (state.extra is Map ? ((state.extra as Map)['id'] ?? (state.extra as Map)['docId'])?.toString() : (state.extra is String ? state.extra as String : null));
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: DocCanvasScreen(documentId: id),
          );
        },
      ),
      GoRoute(
        path: '/doccanvas',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? state.uri.queryParameters['docId'] ?? state.uri.queryParameters['documentId'] ?? (state.extra is Map ? ((state.extra as Map)['id'] ?? (state.extra as Map)['docId'])?.toString() : (state.extra is String ? state.extra as String : null));
          return AppPageTransitions.slideUp(
            key: state.pageKey,
            child: DocCanvasScreen(documentId: id),
          );
        },
      ),
      GoRoute(
        path: '/dashboard/boards',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const HistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/settings/theme',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const AppearanceScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard/settings/profile',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/security',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const SecurityScreen(),
        ),
      ),
      GoRoute(
        path: '/security',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const SecurityScreen(),
        ),
      ),
      GoRoute(
        path: '/appearance',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const AppearanceScreen(),
        ),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const SettingsScreen(),
        ),
      ),
      GoRoute(
        path: '/notifications',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const NotificationsScreen(),
        ),
      ),
      GoRoute(
        path: '/help',
        parentNavigatorKey: _rootNavigatorKey,
        pageBuilder: (context, state) => AppPageTransitions.slideUp(
          key: state.pageKey,
          child: const HelpScreen(),
        ),
      ),
    ],
  );
});

/// Exposes Firebase's auth lifecycle as a plain stream for the router guard.
Stream<void> authStateChangesStream() {
  if (Firebase.apps.isEmpty) {
    return const Stream.empty();
  }
  try {
    return FirebaseAuth.instance.authStateChanges().map<void>((_) {});
  } catch (_) {
    return const Stream.empty();
  }
}

/// Bridges a [Stream] into a [Listenable] so `GoRouter.refreshListenable`
/// can re-run redirect logic on login / logout / session restore.
class _StreamListenable extends ChangeNotifier {
  late final StreamSubscription<void> _subscription;

  _StreamListenable(Stream<void> stream) {
    _subscription = stream.listen((_) => notifyListeners(), onError: (_) {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
