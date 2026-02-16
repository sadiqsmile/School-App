# 4) Full Working Code

All code is already present inside this project.

Start here:
- `lib/main.dart` → Firebase init + Riverpod `ProviderScope`
- `lib/app.dart` → Material 3 app
- `lib/router/app_router.dart` → routes + redirects

Auth screens:
- `lib/screens/auth/role_chooser_screen.dart`
- `lib/screens/auth/parent_login_screen.dart`
- `lib/screens/auth/teacher_login_screen.dart`
- `lib/screens/auth/admin_login_screen.dart`

Dashboards:
- `lib/screens/dashboards/parent_dashboard.dart`
- `lib/screens/dashboards/teacher_dashboard.dart`
- `lib/screens/dashboards/admin_dashboard.dart`

Services:
- `lib/services/auth_service.dart` (Parent login uses Cloud Function `parentLogin`)
- `lib/services/user_profile_service.dart` (loads role-based user profile)
- `lib/services/academic_year_service.dart` (reads active year)
- `lib/services/messaging_service.dart` (writes FCM tokens)

Important:
- `lib/firebase_options.dart` is currently a placeholder until you run `flutterfire configure`.

Run the app:
- `flutter run -d chrome` (web)
- `flutter run -d android` (android emulator/device)
