import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/error_view.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _navigated = false;
  late final ProviderSubscription<AsyncValue<AppUser>> _appUserSub;

  @override
  void initState() {
    super.initState();

    // NOTE: In Riverpod, `ref.listen` is only allowed during build.
    // For initState/dispose-style lifecycles, use `ref.listenManual`.
    _appUserSub = ref.listenManual(appUserProvider, (previous, next) {
      final user = next.asData?.value;
      if (user == null) return;
      if (_navigated) return;

      _navigated = true;

      unawaited(
        ref.read(messagingServiceProvider).initForSignedInUser(uid: user.uid),
      );

      if (!mounted) return;

      switch (user.role) {
        case UserRole.parent:
          context.go('/parent');
          break;
        case UserRole.teacher:
          context.go('/teacher');
          break;
        case UserRole.admin:
          context.go('/admin');
          break;
        case UserRole.student:
          context.go('/student');
          break;
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _appUserSub.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(firebaseAuthUserProvider);
    final appUserAsync = ref.watch(appUserProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.60),
              scheme.surface,
              scheme.secondaryContainer.withValues(alpha: 0.45),
            ],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.70)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const AppLogo(height: 92),
                        const SizedBox(height: 14),
                        Text(
                          'School App',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          authUser.asData?.value == null
                              ? 'Checking sign-in…'
                              : 'Loading your dashboard…',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        appUserAsync.when(
                          data: (_) {
                            // Navigation happens in ref.listen.
                            return const _SplashLoading(message: 'Opening your dashboard…');
                          },
                          loading: () => const _SplashLoading(message: 'Loading profile…'),
                          error: (err, _) {
                            return ErrorView(
                              title: 'Profile setup needed',
                              message:
                                  'This account is signed in, but its role profile is missing in Firestore.\n\nAsk the admin to create your user profile under: schools → ${AppConfig.schoolId} → users → (your uid).',
                              primaryActionLabel: 'Sign out',
                              onPrimaryAction: () async {
                                await ref.read(authServiceProvider).signOut();
                                if (context.mounted) context.go('/login');
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
