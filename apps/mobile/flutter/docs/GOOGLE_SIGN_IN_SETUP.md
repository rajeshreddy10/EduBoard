# Enabling Google Sign-In for Android (production)

The `continue with Google` button is **runtime-guarded**: if the local
`google-services.json` is missing or fabricated (invalid app id / OAuth
client), the app logs a diagnostic warning, disables the button with a clear
reason, and email/password sign-in continues to work. No crash, no
`DEVELOPER_ERROR` dialog.

The current `android/app/google-services.json` contains placeholder values
(the `mobilesdk_app_id` is not a real Firebase Android app registration). To
turn Google Sign-In on for real builds, perform the following **once in the
Firebase console** — it cannot be fixed in code:

## 1. Register your signing fingerprints

For each build you plan to ship (debug keystore + your release keystore),
collect the SHA-1/SHA-256 pairs:

```bash
# Debug keystore (local machine)
keytool -list -v -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android

# Release keystore (replace alias/path)
keytool -list -v -alias <release-alias> -keystore <release.jks>
```

Or, from the Flutter/Android tooling:

```bash
cd android
./gradlew signingReport
```

## 2. Add the app in the Firebase console

1. Firebase Console → Project **eduboard-6fdcc** → Project Settings →
   **Your apps** → *Add app* → **Android**.
2. Package name: `com.eduboard.mobile` (must match `applicationId` in
   `android/app/build.gradle.kts`).
3. On the same page, paste **both SHA-1 and SHA-256** fingerprints from step 1
   and save. Google Sign-In will fail with `DEVELOPER_ERROR` /
   *"Unknown calling package"* until the fingerprint for the keystore that
   signs the installed APK is registered.
4. Download the generated `google-services.json`.

## 3. Replace the local config

Overwrite `apps/mobile/flutter/android/app/google-services.json` with the
downloaded file. It must contain:

- a real `mobilesdk_app_id` shaped like `1:<sender>:android:<22 chars>`,
- an `oauth_client` entry with `client_type: 1` (Android) derived from your
  fingerprints, plus the `client_type: 3` web client,
- the project's real `api_key`.

## 4. Rebuild and reinstall

```bash
flutter clean
flutter pub get
flutter build apk --release
```

The Google button reacts automatically: `EduBoardLogin` checks
`AuthRepository.googleSignInAvailable` on every app start, so replacing this
file (with a valid registration) re-enables Google Sign-In without any code
change.

## Notes

- Emulator limitation: Google Sign-In additionally requires a device with
  Google Play services signed in to a Google account. Plain emulators without
  Play Store support will always fall back to the guarded state — that is by
  design, not a defect.
- Authentication itself (email/password, Firestore, Storage, Socket.IO) is
  independent of Google Sign-In and works with the current configuration.
