import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/loading_view.dart';
import 'student_profile_screen.dart';

class StudentListScreen extends ConsumerWidget {
  const StudentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);

    return FutureBuilder<String?>(
      future: ref.read(authServiceProvider).getParentMobile(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: LoadingView(message: 'Loading…')),
          );
        }
        final parentMobile = snap.data;
        if (parentMobile == null || parentMobile.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Student Profile')),
            body: const Center(child: Text('Please login again.')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Student Profile')),
          body: yearAsync.when(
            loading: () => const Center(child: LoadingView(message: 'Loading academic year…')),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (yearId) {
              final stream = ref
                  .read(parentDataServiceProvider)
                  .watchMyStudents(yearId: yearId, parentUid: parentMobile);

              return StreamBuilder(
                stream: stream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: LoadingView(message: 'Loading students…'));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final students = snapshot.data ?? const [];
                  if (students.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            AppLogo(height: 64),
                            SizedBox(height: 12),
                            Text(
                              'No student linked to this parent yet.\n\nAsk admin to link your parent mobile to a student for this academic year.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final s = students[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: s.base.photoUrl == null
                                ? null
                                : NetworkImage(s.base.photoUrl!),
                            child: s.base.photoUrl == null ? const Icon(Icons.person) : null,
                          ),
                          title: Text(s.base.fullName),
                          subtitle: Text(
                            'Admission: ${s.base.admissionNo ?? '-'} • Class/Section: ${s.year.classSectionId}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => StudentProfileScreen(
                                  student: s,
                                  yearId: yearId,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
