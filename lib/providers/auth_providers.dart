import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../providers/core_providers.dart';

final firebaseAuthUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges();
});

final appUserProvider = StreamProvider<AppUser>((ref) {
  final authUserAsync = ref.watch(firebaseAuthUserProvider);

  return authUserAsync.when(
    data: (authUser) {
      if (authUser == null) {
        return const Stream<AppUser>.empty();
      }
      final profileService = ref.watch(userProfileServiceProvider);
      return profileService.watchUserProfile(authUser.uid);
    },
    loading: () => const Stream<AppUser>.empty(),
    error: (error, stackTrace) => const Stream<AppUser>.empty(),
  );
});

final activeAcademicYearIdProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(academicYearServiceProvider);
  return service.getActiveAcademicYearId();
});
