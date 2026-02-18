import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../models/user_role.dart';
import '../screens/auth/unified_login_screen.dart';
import '../screens/dashboards/admin_dashboard.dart';
import '../screens/dashboards/parent_dashboard.dart';
import '../screens/dashboards/teacher_dashboard.dart';
import '../screens/splash/splash_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(firebaseAuthUserProvider);
  final appUserState = ref.watch(appUserProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoggingIn = state.matchedLocation.startsWith('/login');

      if (authState.isLoading) {
        return null;
      }

      final User? user = authState.asData?.value;
      if (user == null) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return '/';
      }

      // If role profile hasn't loaded yet, let the SplashScreen handle loading/error UI.
      if (appUserState.isLoading || appUserState.hasError) {
        return state.matchedLocation == '/' ? null : '/';
      }

      final appUser = appUserState.asData?.value;
      if (appUser == null) {
        return state.matchedLocation == '/' ? null : '/';
      }

      final targetBase = switch (appUser.role) {
        UserRole.parent => '/parent',
        UserRole.teacher => '/teacher',
        UserRole.admin => '/admin',
      };

      // Keep users inside their dashboard namespace.
      if (state.matchedLocation == '/' || state.matchedLocation.startsWith(targetBase)) {
        return null;
      }

      // Admin can access other dashboards for troubleshooting if needed.
      if (appUser.role == UserRole.admin) {
        return null;
      }

      return targetBase;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const UnifiedLoginScreen(),
        routes: [
          GoRoute(
            path: 'parent',
            builder: (context, state) => const UnifiedLoginScreen(initialTab: LoginTab.parent),
          ),
          GoRoute(
            path: 'teacher',
            builder: (context, state) => const UnifiedLoginScreen(initialTab: LoginTab.teacher),
          ),
          GoRoute(
            path: 'admin',
            builder: (context, state) => const UnifiedLoginScreen(initialTab: LoginTab.admin),
          ),
        ],
      ),
      GoRoute(
        path: '/parent',
        builder: (context, state) => const ParentDashboard(),
      ),
      GoRoute(
        path: '/teacher',
        builder: (context, state) => const TeacherDashboard(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminDashboard(),
      ),
    ],
  );
});
