// File generated for EduBoard Firebase project: eduboard-6fdcc
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Connects mobile and web containers to the shared Firebase project `eduboard-6fdcc`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAyF7MrKxdseKsh-Zux19Qbrrp3sz0Uymg',
    appId: '1:490296361729:web:071ea659c1d4a99d199100',
    messagingSenderId: '490296361729',
    projectId: 'eduboard-6fdcc',
    authDomain: 'eduboard-6fdcc.firebaseapp.com',
    storageBucket: 'eduboard-6fdcc.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAyF7MrKxdseKsh-Zux19Qbrrp3sz0Uymg',
    appId: '1:490296361729:android:eduboardmobilewrapper',
    messagingSenderId: '490296361729',
    projectId: 'eduboard-6fdcc',
    storageBucket: 'eduboard-6fdcc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAyF7MrKxdseKsh-Zux19Qbrrp3sz0Uymg',
    appId: '1:490296361729:ios:eduboardmobilewrapper',
    messagingSenderId: '490296361729',
    projectId: 'eduboard-6fdcc',
    storageBucket: 'eduboard-6fdcc.firebasestorage.app',
    iosBundleId: 'com.eduboard.mobile',
  );
}
