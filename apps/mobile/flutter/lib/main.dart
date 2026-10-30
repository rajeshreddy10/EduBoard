import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/firebase_options.dart';
import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    // Ensure Flutter engine bindings are initialized inside the guarded zone to prevent Zone Mismatch
    WidgetsFlutterBinding.ensureInitialized();
    // Global framework error handlers
    FlutterError.onError = (details) {
      debugPrint('[EduBoard FlutterError] ${details.exceptionAsString()}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('[EduBoard Platform Error] $error\n$stack');
      return true; // Prevents crash in engine
    };

    // Ultra-safe error widget builder that is self-contained with Material and Directionality.
    // Never throws unhandled layout/inheritance exceptions when building errors.
    ErrorWidget.builder = (details) => buildEduBoardErrorScreen(
          details.exceptionAsString().isNotEmpty
              ? details.exceptionAsString()
              : 'An unexpected rendering error occurred',
        );

    // 1. Offline storage with strict timeout so slow disk/emulator never blocks startup
    try {
      await StorageService.init().timeout(const Duration(seconds: 3));
      debugPrint('[EduBoard Storage] StorageService initialized successfully');
    } catch (e) {
      debugPrint('[EduBoard Storage Note] $e (using in-memory fallback)');
    }

    // 2. Initialize Firebase connected to eduboard-6fdcc (with duplicate check & timeout)
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        ).timeout(const Duration(seconds: 4));
        debugPrint('[EduBoard Firebase] Initialized successfully (project: eduboard-6fdcc)');
      } else {
        debugPrint('[EduBoard Firebase] Already initialized natively');
      }
    } catch (e) {
      debugPrint('[EduBoard Firebase Note] $e (continuing with offline-first fallbacks)');
    }

    // Launch the application shell
    runApp(
      const ProviderScope(
        child: EduBoardApp(),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('[EduBoard Uncaught Zone Error] $error\n$stackTrace');
  });
}

/// Robust, completely self-contained fallback screen used by [ErrorWidget.builder].
/// Guaranteed to never throw "No Directionality widget found" or Theme lookup errors.
Widget buildEduBoardErrorScreen(String message) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Material(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFF94A3B8),
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'EduBoard Studio',
                style: TextStyle(
                  color: Color(0xFFF1F5F9),
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Root EduBoard Native Flutter application
class EduBoardApp extends ConsumerWidget {
  const EduBoardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final router = ref.watch(appRouterProvider);

    // Build Material 3 dynamic themes for light and dark modes
    final lightTheme = AppTheme.buildTheme(
      preset: themeState.preset,
      accent: themeState.accent,
      isDark: false,
    );

    final darkTheme = AppTheme.buildTheme(
      preset: themeState.preset,
      accent: themeState.accent,
      isDark: true,
    );

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeState.mode,
      routerConfig: router,
    );
  }
}
