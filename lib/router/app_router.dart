import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../providers/core_providers.dart';
import '../screens/auth/unified_login_screen.dart';
import '../screens/dashboards/admin_dashboard.dart';
import '../screens/dashboards/parent_dashboard.dart';
import '../screens/dashboards/teacher_dashboard.dart';
import '../screens/splash/splash_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(firebaseAuthUserProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoggingIn = state.matchedLocation.startsWith('/login');
      final isParentArea = state.matchedLocation.startsWith('/parent');

      if (authState.isLoading) {
        return null;
      }

      final User? user = authState.asData?.value;
      if (user == null) {
        // Parent login is Firestore-based (SharedPreferences session) and does not
        // affect FirebaseAuth state. Allow parent area when a parent session exists.
        final parentLoggedIn = await ref.read(authServiceProvider).isParentLoggedIn();
        if (parentLoggedIn) {
          return isParentArea ? null : '/parent';
        }

        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn) {
        return '/';
      }

      return null;
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
