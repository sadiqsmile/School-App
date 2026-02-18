import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../models/user_role.dart';
import '../../widgets/dashboard_ui.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/notification_token_registration_runner.dart';
import '../student/exams/student_exams_screen.dart';
import '../student/timetable/student_timetable_screen.dart';
import '../student/attendance/student_attendance_screen.dart';
import '../student/homework/student_homework_list_screen.dart';
import '../shared/notifications/notification_inbox_screen.dart';
import '../student/settings/student_settings_screen.dart';

class StudentDashboard extends ConsumerWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final authUserAsync = ref.watch(firebaseAuthUserProvider);
    final appUserAsync = ref.watch(appUserProvider);

    final authUser = authUserAsync.asData?.value;

    if (authUserAsync.isLoading) {
      return const Scaffold(body: Center(child: LoadingView(message: 'Loading…')));
    }
    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Dashboard')),
        body: const Center(child: Text('Please login again.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: DashboardBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: NotificationTokenRegistrationRunner.user(
                  uid: authUser.uid,
                ),
              ),
              SliverToBoxAdapter(
                child: yearAsync.when(
                  data: (yearId) {
                    const size = 80.0;
                    const gap = 16.0;

                    final scheme = Theme.of(context).colorScheme;
                    final width = MediaQuery.sizeOf(context).width;
                    final crossAxisCount = width >= 900
                        ? 3
                        : width >= 560
                            ? 2
                            : 1;

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: GridView.extent(
                        maxCrossAxisExtent: 160,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: gap,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _DashboardCard(
                            label: 'Exams',
                            icon: Icons.assessment,
                            color: Colors.blue,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StudentExamsScreen(),
                              ),
                            ),
                          ),
                          _DashboardCard(
                            label: 'Timetable',
                            icon: Icons.schedule,
                            color: Colors.purple,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StudentTimetableScreen(),
                              ),
                            ),
                          ),
                          _DashboardCard(
                            label: 'Attendance',
                            icon: Icons.check_circle,
                            color: Colors.green,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StudentAttendanceScreen(),
                              ),
                            ),
                          ),
                          _DashboardCard(
                            label: 'Homework',
                            icon: Icons.assignment,
                            color: Colors.orange,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StudentHomeworkListScreen(),
                              ),
                            ),
                          ),
                          _DashboardCard(
                            label: 'Notifications',
                            icon: Icons.notifications,
                            color: Colors.red,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationInboxScreen(),
                              ),
                            ),
                          ),
                          _DashboardCard(
                            label: 'Settings',
                            icon: Icons.settings,
                            color: Colors.grey,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StudentSettingsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: LoadingView(message: 'Loading academic year…'),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Error: $error'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
