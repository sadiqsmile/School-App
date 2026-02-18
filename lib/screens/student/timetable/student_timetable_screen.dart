import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/core_providers.dart';
import '../../../widgets/loading_view.dart';

class StudentTimetableScreen extends ConsumerWidget {
  const StudentTimetableScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final appUserAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Timetable')),
      body: yearAsync.when(
        loading: () =>
            const Center(child: LoadingView(message: 'Loading timetable…')),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (yearId) {
          return appUserAsync.when(
            loading: () =>
                const Center(child: LoadingView(message: 'Loading profile…')),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (user) {
              if (user.classId == null ||
                  user.classId!.isEmpty ||
                  user.sectionId == null ||
                  user.sectionId!.isEmpty) {
                return const Center(
                  child: Text('Class/Section information missing.'),
                );
              }

              return const Center(
                child: Text('Timetable view coming soon.'),
              );
            },
          );
        },
      ),
    );
  }
}
