# Instructions to update Firebase configuration

1. Download the new `google-services.json` for the `sk-school-master` project from the Firebase Console.
2. Replace the existing file at:
   `android/app/google-services.json`

3. If you are building for iOS, download the new `GoogleService-Info.plist` and place it in `ios/Runner/` (no existing file found, so just add if needed).

4. Remove all references to the old projectId `skschoolmasterapp`:
   - Update `lib/firebase_options.dart` to use the new projectId and config (regenerate this file using `flutterfire configure --project=sk-school-master`).
   - Update `firebase.json` and `.firebaserc` to use the new projectId.
   - Remove or update any URLs or references in code that use `skschoolmasterapp` (see below for details).

5. Ensure `Firebase.initializeApp()` in `lib/main.dart` uses the correct config (it should use the new `firebase_options.dart`).

6. Verify `android/app/build.gradle` and `android/build.gradle` for correct Firebase setup (no projectId hardcoding found, but ensure plugins and dependencies are correct).

7. Remove or update any old references to `skschoolmasterapp` in:
   - `lib/screens/dashboards/admin_dashboard.dart` (line 218)
   - `lib/screens/admin/imports/excel_import_export_screen.dart` (line 266)
   - `firebase.json` (lines 6, 13)
   - `.firebaserc` (line 3)
   - `deploy_output.txt` (multiple lines)
   - `android/app/google-services.json` (lines 4, 5)
   - `lib/firebase_options.dart` (multiple lines)

# Next Steps
- After replacing the config files and updating code, run your app and verify Firebase is connected to `sk-school-master`.
- If you need help regenerating `firebase_options.dart`, install FlutterFire CLI and run:
  ```
  dart pub global activate flutterfire_cli
  flutterfire configure --project=sk-school-master
  ```
- Remove any remaining references to `skschoolmasterapp` in your codebase.
