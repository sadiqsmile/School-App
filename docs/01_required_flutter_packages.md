# 1) Required Flutter Packages

This project uses **Riverpod + GoRouter + Firebase**.

## pubspec.yaml dependencies (copy/paste list)

```yaml
dependencies:
  flutter:
    sdk: flutter

  cupertino_icons: ^1.0.8

  # Firebase
  firebase_core: ^4.4.0
  firebase_auth: ^6.1.4
  cloud_firestore: ^6.1.2
  firebase_storage: ^13.0.6
  firebase_messaging: ^16.1.1
  cloud_functions: ^6.0.6

  # State management + routing
  flutter_riverpod: ^3.2.1
  go_router: ^17.1.0

  # UI helpers
  intl: ^0.20.2
  table_calendar: ^3.2.0
  shared_preferences: ^2.5.4

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

Notes:
- `cloud_functions` is required to implement **Parent login without OTP/SMS** securely.
- You already have `assets/images/` configured in `pubspec.yaml`.
