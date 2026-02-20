import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../providers/auth_providers.dart';
import '../models/user_role.dart';
import '../screens/auth/unified_login_screen.dart';
import '../screens/dashboards/admin_dashboard.dart';
import '../screens/dashboards/parent_dashboard.dart';
import '../screens/dashboards/teacher_dashboard.dart';
import '../screens/dashboards/viewer_dashboard.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/parent/auth/parent_awaiting_approval_screen.dart';
import '../screens/parent/auth/parent_force_password_change_screen.dart';
import '../config/app_config.dart';
import '../utils/parent_auth_email.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(firebaseAuthUserProvider);
  final appUserState = ref.watch(appUserProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) async {
      final isLoggingIn = state.matchedLocation.startsWith('/login');
      final isParentAuthFlow = state.matchedLocation.startsWith('/parent-auth');

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

      // For parents, check approval status before proceeding to dashboard
      if (user.email != null && user.email!.contains('@parents.hongirana.school')) {
        final mobile = tryExtractMobileFromParentEmail(user.email ?? '');
        if (mobile != null) {
          try {
            final firestore = FirebaseFirestore.instance;
            final parentDoc = await firestore
                .collection('schools')
                .doc(AppConfig.schoolId)
                .collection('parents')
                .doc(mobile)
                .get();

            if (parentDoc.exists) {
              final data = parentDoc.data() ?? const <String, dynamic>{};
              final approvalStatus = (data['approvalStatus'] as String?)?.trim() ?? 'pending';
              final mustChangePassword = (data['mustChangePassword'] as bool?) ?? false;

              // If pending approval, redirect to waiting screen
              if (approvalStatus == 'pending') {
                if (isParentAuthFlow) {
                  return null;
                }
                return '/parent-auth/awaiting-approval';
              }

              // If blocked, sign out and redirect to login
              if (approvalStatus == 'blocked' || approvalStatus == 'rejected') {
                await FirebaseAuth.instance.signOut();
                return '/login';
              }

              // If must change password, redirect to password change screen
              if (mustChangePassword) {
                if (state.matchedLocation == '/parent-auth/force-password-change') {
                  return null;
                }
                if (isParentAuthFlow) {
                  return null;
                }
                return '/parent-auth/force-password-change';
              }
            }
          } catch (e) {
            // Log error but don't block access
          }
        }
      }

      // If role profile hasn't loaded yet, let the SplashScreen handle loading/error UI.
      if (appUserState.isLoading || appUserState.hasError) {
        return state.matchedLocation == '/' ? null : '/';
      }

      final appUser = appUserState.asData?.value;
      if (appUser == null) {
        return state.matchedLocation == '/' ? null : '/';
      }

      // Student login is no longer supported in the app.
      // If a student-role profile exists for a signed-in Firebase user (e.g. stale session),
      // sign out and send them back to the unified login screen.
      if (appUser.role == UserRole.student) {
        await FirebaseAuth.instance.signOut();
        return '/login';
      }

      final targetBase = switch (appUser.role) {
        UserRole.parent => '/parent',
        UserRole.teacher => '/teacher',
        UserRole.admin => '/admin',
        UserRole.student => '/login',
        UserRole.viewer => '/viewer',
      };

      // Keep users inside their dashboard namespace.
      if (state.matchedLocation == '/' || state.matchedLocation.startsWith(targetBase)) {
        return null;
      }

      // Admin and Viewer can access other dashboards for troubleshooting/viewing if needed.
      if (appUser.role == UserRole.admin || appUser.role == UserRole.viewer) {
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
      ),
      // Parent authentication flow screens
      GoRoute(
        path: '/parent-auth',
        redirect: (context, state) => null,
        routes: [
          GoRoute(
            path: 'awaiting-approval',
            builder: (context, state) => const ParentAwaitingApprovalScreen(),
          ),
          GoRoute(
            path: 'force-password-change',
            builder: (context, state) => const ParentForcePasswordChangeScreen(),
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
      GoRoute(
        path: '/viewer',
        builder: (context, state) => const ViewerDashboard(),
      ),
    ],
  );
});
