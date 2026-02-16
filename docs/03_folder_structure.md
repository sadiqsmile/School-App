# 3) Full Folder Structure

Current Flutter structure (important folders only):

```
lib/
  app.dart
  main.dart
  firebase_options.dart

  config/
    app_config.dart

  models/
    app_user.dart
    user_role.dart

  providers/
    auth_providers.dart
    core_providers.dart

  router/
    app_router.dart

  screens/
    auth/
      role_chooser_screen.dart
      parent_login_screen.dart
      teacher_login_screen.dart
      admin_login_screen.dart

    dashboards/
      parent_dashboard.dart
      teacher_dashboard.dart
      admin_dashboard.dart

    splash/
      splash_screen.dart

  services/
    academic_year_service.dart
    auth_service.dart
    messaging_service.dart
    storage_service.dart
    user_profile_service.dart

  widgets/
    app_logo.dart
    error_view.dart
    loading_view.dart
    feature_placeholder_screen.dart

assets/
  images/
    school_logo.png

firestore.rules
storage.rules
```
