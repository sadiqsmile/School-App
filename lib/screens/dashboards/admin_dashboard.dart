import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../models/user_role.dart';

import '../../widgets/dashboard_ui.dart';
import '../admin/attendance/admin_attendance_screen.dart';
import '../admin/classes/admin_classes_sections_screen.dart';
import '../admin/parents/admin_parents_screen.dart';
import '../admin/imports/modern_admin_setup_wizard.dart';
import '../admin/imports/excel_import_export_screen.dart';
import '../admin/students/admin_students_screen.dart';
import '../admin/teachers/admin_teachers_screen.dart';
import '../admin/timetable/admin_timetable_screen.dart';
import '../admin/exams/admin_exams_screen.dart';
import '../admin/academic_year/admin_academic_year_settings_screen.dart';
import '../admin/homework/admin_homework_maintenance_screen.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/notification_token_registration_runner.dart';
import '../shared/notifications/notification_center_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;


class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _selectedIndex = 0;
  bool _autoSelected = false;

  static const _items = <_AdminNavItem>[
    _AdminNavItem('Setup Wizard', Icons.auto_fix_high, _AdminPage.setupWizard),
    _AdminNavItem('Excel Import / Export', Icons.table_view_outlined, _AdminPage.excelImportExport),
    _AdminNavItem('Dashboard', Icons.dashboard, _AdminPage.dashboard),
    _AdminNavItem('Academic Year', Icons.calendar_today, _AdminPage.academicYear),
    _AdminNavItem('Students', Icons.badge, _AdminPage.students),
    _AdminNavItem('Attendance', Icons.fact_check_outlined, _AdminPage.attendance),
    _AdminNavItem('Parents', Icons.family_restroom, _AdminPage.parents),
    _AdminNavItem('Teachers', Icons.person, _AdminPage.teachers),
    _AdminNavItem('Classes/Sections', Icons.class_, _AdminPage.classes),
    _AdminNavItem('Timetable', Icons.calendar_month, _AdminPage.timetable),
    _AdminNavItem('Exams', Icons.school, _AdminPage.exams),
    _AdminNavItem('Homework Tools', Icons.archive_outlined, _AdminPage.homeworkTools),
    _AdminNavItem('Notifications', Icons.notifications, _AdminPage.notifications),
  ];

  @override
  void initState() {
    super.initState();
    final dashboardIndex = _items.indexWhere((item) => item.page == _AdminPage.dashboard);
    if (dashboardIndex >= 0) {
      _selectedIndex = dashboardIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUserAsync = ref.watch(appUserProvider);
    final yearAsync = ref.watch(activeAcademicYearIdProvider);
    final authUserAsync = ref.watch(firebaseAuthUserProvider);

    return appUserAsync.when(
      loading: () => const Scaffold(body: Center(child: LoadingView(message: 'Loading…'))),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: Center(child: Text('Error: $err')),
      ),
      data: (appUser) {
        final adminUid = authUserAsync.asData?.value?.uid;
        final isWide = MediaQuery.sizeOf(context).width >= 900;
        if (!_autoSelected) {
          final yearId = yearAsync.asData?.value;
          final needsSetup = yearId == null || yearId.isEmpty;
          if (needsSetup) {
            final setupIndex = _items.indexWhere((item) => item.page == _AdminPage.setupWizard);
            if (setupIndex >= 0) {
              _selectedIndex = setupIndex;
            }
          }
          _autoSelected = true;
        }

        final selected = _items[_selectedIndex];
        final scheme = Theme.of(context).colorScheme;

        final yearText = yearAsync.when(
          data: (yearId) => 'Academic Year: $yearId',
          loading: () => 'Academic Year: …',
          error: (_, _) => 'Academic Year: (not set)',
        );

        final yearId = yearAsync.asData?.value;

        final header = DashboardHeaderCard(
          title: 'Hello, ${appUser.displayName}',
          subtitle: yearText,
          trailing: Icon(Icons.admin_panel_settings_outlined, color: scheme.primary),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('Admin • ${selected.label}'),
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
          drawer: isWide
              ? null
              : Drawer(
                  child: SafeArea(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        DrawerHeader(
                          child: header,
                        ),
                        for (var i = 0; i < _items.length; i++)
                          ListTile(
                            selected: i == _selectedIndex,
                            leading: Icon(_items[i].icon),
                            title: Text(_items[i].label),
                            onTap: () {
                              setState(() => _selectedIndex = i);
                              Navigator.of(context).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                ),
          body: DashboardBackground(
            child: Row(
              children: [
                if (isWide)
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    backgroundColor: Colors.transparent,
                    onDestinationSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final item in _items)
                        NavigationRailDestination(
                          icon: Icon(item.icon),
                          label: Text(item.label),
                        ),
                    ],
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: header,
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      _AdminContent(
                    onNavigate: (page) {
                      final idx = _items.indexWhere((x) => x.page == page);
                      if (idx >= 0) setState(() => _selectedIndex = idx);
                    },
                    page: selected.page,
                    activeYearId: yearId,
                      ),
                      // Invisible token registration runner.
                      if (adminUid != null)
                        NotificationTokenRegistrationRunner.user(
                          uid: adminUid,
                          // TODO: For Web Push you must provide a VAPID key.
                          // vapidKey: 'YOUR_WEB_PUSH_VAPID_KEY',
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AdminContent extends ConsumerWidget {
  const _AdminContent({
    required this.page,
    required this.onNavigate,
    required this.activeYearId,
  });

  final _AdminPage page;
  final ValueChanged<_AdminPage> onNavigate;
  final String? activeYearId;

  Future<void> _syncSchoolData(BuildContext context) async {
    try {
      final response = await http.post(
        Uri.parse('https://asia-south1-hongiranaapp.cloudfunctions.net/syncSchoolData'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'secret': 'ADMIN_SYNC_2026'}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final added = data['added'] ?? 0;
        final updated = data['updated'] ?? 0;
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync Complete: $added Added, $updated Updated'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✗ Sync failed: ${response.statusCode}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (page == _AdminPage.setupWizard) {
      return const ModernAdminSetupWizard();
    }
    if (page == _AdminPage.excelImportExport) {
      return const AdminExcelImportExportScreen();
    }
    if (page == _AdminPage.academicYear) {
      return const AdminAcademicYearSettingsScreen();
    }
    if (page == _AdminPage.students) {
      return const AdminStudentsScreen();
    }
    if (page == _AdminPage.attendance) {
      return const AdminAttendanceScreen();
    }
    if (page == _AdminPage.parents) {
      return const AdminParentsScreen();
    }
    if (page == _AdminPage.teachers) {
      return const AdminTeachersScreen();
    }
    if (page == _AdminPage.classes) {
      return const AdminClassesSectionsScreen();
    }
    if (page == _AdminPage.timetable) {
      return const AdminTimetableScreen();
    }

    if (page == _AdminPage.exams) {
      return const AdminExamsScreen();
    }

    if (page == _AdminPage.homeworkTools) {
      return const AdminHomeworkMaintenanceScreen();
    }

    if (page == _AdminPage.notifications) {
      return const NotificationCenterScreen(viewerRole: UserRole.admin);
    }

    if (page == _AdminPage.dashboard) {
      final scheme = Theme.of(context).colorScheme;
      final width = MediaQuery.sizeOf(context).width;
      final crossAxisCount = width >= 1100
          ? 3
          : width >= 720
              ? 2
              : 1;

      return CustomScrollView(
        slivers: [
          // Premium Header with Gradient
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary, scheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 70,
                            height: 70,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(8),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/school_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hongirana School',
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Admin Control Center',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'ADMIN',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Quick Stats
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            sliver: SliverToBoxAdapter(
              child: _AdminSummaryRow(activeYearId: activeYearId),
            ),
          ),
          // Search Bar
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverToBoxAdapter(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search modules...',
                  prefixIcon: Icon(Icons.search, color: scheme.primary),
                  suffixIcon: Icon(Icons.mic, color: scheme.primary.withValues(alpha: 0.5)),
                  filled: true,
                  fillColor: scheme.primary.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.2), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.2), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          // Section Title
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          // Action Cards Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverGrid.count(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: crossAxisCount == 1 ? 2.6 : 1.25,
              children: [
                _PremiumActionCard(
                  title: 'Setup Wizard',
                  subtitle: 'Guided setup for your school',
                  icon: Icons.auto_fix_high,
                  gradient: [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
                  onTap: () => onNavigate(_AdminPage.setupWizard),
                ),
                _PremiumActionCard(
                  title: 'Academic Year',
                  subtitle: 'Set active year + rollover',
                  icon: Icons.calendar_today_outlined,
                  gradient: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
                  onTap: () => onNavigate(_AdminPage.academicYear),
                ),
                _PremiumActionCard(
                  title: 'Students',
                  subtitle: 'Create and manage students',
                  icon: Icons.badge_outlined,
                  gradient: [scheme.secondary, scheme.secondary.withValues(alpha: 0.7)],
                  onTap: () => onNavigate(_AdminPage.students),
                ),
                _PremiumActionCard(
                  title: 'Parents',
                  subtitle: 'Manage parent accounts',
                  icon: Icons.family_restroom,
                  gradient: [const Color(0xFF1565C0), const Color(0xFF0D47A1)],
                  onTap: () => onNavigate(_AdminPage.parents),
                ),
                _PremiumActionCard(
                  title: 'Teachers',
                  subtitle: 'Assign and manage teachers',
                  icon: Icons.person_outline,
                  gradient: [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
                  onTap: () => onNavigate(_AdminPage.teachers),
                ),
                _PremiumActionCard(
                  title: 'Classes/Sections',
                  subtitle: 'Manage class structure',
                  icon: Icons.class_outlined,
                  gradient: [const Color(0xFF00838F), const Color(0xFF004D40)],
                  onTap: () => onNavigate(_AdminPage.classes),
                ),
                _PremiumActionCard(
                  title: 'Timetable',
                  subtitle: 'Class schedules',
                  icon: Icons.calendar_month_outlined,
                  gradient: [const Color(0xFF6A1B9A), const Color(0xFF4A148C)],
                  onTap: () => onNavigate(_AdminPage.timetable),
                ),
                _PremiumActionCard(
                  title: 'Exams',
                  subtitle: 'Create and publish exams',
                  icon: Icons.school_outlined,
                  gradient: [const Color(0xFFC62828), const Color(0xFF880E4F)],
                  onTap: () => onNavigate(_AdminPage.exams),
                ),
              ],
            ),
          ),
          // Auto Sync Google Sheet Button
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: ElevatedButton.icon(
                onPressed: () => _syncSchoolData(context),
                icon: const Icon(Icons.sync),
                label: const Text('Auto Sync Google Sheet'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  backgroundColor: scheme.primary.withValues(alpha: 0.1),
                  foregroundColor: scheme.primary,
                  side: BorderSide(color: scheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          // Recent Actions Section
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Recent Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            sliver: SliverToBoxAdapter(
              child: _RecentActionsList(),
            ),
          ),
        ],
      );
    }

    final title = switch (page) {
      _AdminPage.setupWizard => 'Admin Setup Wizard',
      _AdminPage.excelImportExport => 'Excel Import / Export',
      _AdminPage.dashboard => 'Admin Dashboard',
      _AdminPage.academicYear => 'Academic Year Settings',
      _AdminPage.students => 'Manage Students',
      _AdminPage.attendance => 'Attendance Report',
      _AdminPage.parents => 'Manage Parents',
      _AdminPage.teachers => 'Manage Teachers',
      _AdminPage.classes => 'Manage Classes/Sections',
      _AdminPage.timetable => 'Manage Timetable',
      _AdminPage.exams => 'Manage Exams & Results',
      _AdminPage.homeworkTools => 'Homework Maintenance',
      _AdminPage.notifications => 'Send Notifications',
    };

    final desc = switch (page) {
      _AdminPage.setupWizard =>
        'Guided setup: academic year → classes → accounts → assignments → verify attendance.',
      _AdminPage.excelImportExport =>
        'Import or export students, parents, and teachers with CSV or Excel files.',
      _AdminPage.dashboard =>
        'Overview: total students, attendance, and recent notices.',
      _AdminPage.academicYear => 'Create years, set active year, and run rollover/promotion.',
      _AdminPage.students =>
        'Add/Edit/Delete students and assign to class/section for the academic year.',
      _AdminPage.attendance =>
        'View class/section attendance for a date and copy an export-ready table.',
      _AdminPage.parents =>
        'Create parent accounts (mobile login) and link to students.',
      _AdminPage.teachers => 'Create teacher accounts and assign classes/sections.',
      _AdminPage.classes => 'Create classes and sections (A/B/C).',
      _AdminPage.timetable => 'Upload timetable for each class/section.',
      _AdminPage.exams => 'Create exams, enter marks, and publish results.',
      _AdminPage.homeworkTools => 'Archive old homework/notes (history preserved).',
      _AdminPage.notifications =>
        'Send notifications school-wide or class-wise (FCM + Firestore).',
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(desc),
                  const SizedBox(height: 12),
                  Text(
                    'UI for this module will be built next. The database design and security rules are already prepared for it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSummaryRow extends ConsumerWidget {
  const _AdminSummaryRow({required this.activeYearId});

  final String? activeYearId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final adminData = ref.read(adminDataServiceProvider);

    final yearValue = activeYearId ?? '—';

    String countText(AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap) {
      if (snap.connectionState == ConnectionState.waiting) return '…';
      if (snap.hasError) return '—';
      return (snap.data?.docs.length ?? 0).toString();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: adminData.watchStudents(),
      builder: (context, studentsSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: adminData.watchTeachers(),
          builder: (context, teachersSnap) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: adminData.watchParents(),
              builder: (context, parentsSnap) {
                return DashboardSummaryStrip(
                  items: [
                    DashboardSummaryItemData(
                      label: 'Students',
                      value: countText(studentsSnap),
                      icon: Icons.badge_outlined,
                      tint: scheme.primary,
                    ),
                    DashboardSummaryItemData(
                      label: 'Teachers',
                      value: countText(teachersSnap),
                      icon: Icons.person_outline,
                      tint: scheme.secondary,
                    ),
                    DashboardSummaryItemData(
                      label: 'Parents',
                      value: countText(parentsSnap),
                      icon: Icons.family_restroom,
                      tint: scheme.tertiary,
                    ),
                    DashboardSummaryItemData(
                      label: 'Academic year',
                      value: yearValue,
                      icon: Icons.calendar_today_outlined,
                      tint: const Color(0xFF1565C0),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

enum _AdminPage {
  setupWizard,
  excelImportExport,
  dashboard,
  academicYear,
  students,
  attendance,
  parents,
  teachers,
  classes,
  timetable,
  exams,
  homeworkTools,
  notifications,
}

class _AdminNavItem {
  const _AdminNavItem(this.label, this.icon, this.page);

  final String label;
  final IconData icon;
  final _AdminPage page;
}

// Premium Action Card with Gradient
class _PremiumActionCard extends StatefulWidget {
  const _PremiumActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  State<_PremiumActionCard> createState() => _PremiumActionCardState();
}

class _PremiumActionCardState extends State<_PremiumActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradient[0].withValues(alpha: _isHovered ? 0.4 : 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Recent Actions List
class _RecentActionsList extends StatelessWidget {
  const _RecentActionsList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    final recentActions = [
      (icon: Icons.person_add, title: 'New teacher added', time: '2 hours ago', color: scheme.secondary),
      (icon: Icons.notification_add, title: 'Notification sent to all classes', time: '4 hours ago', color: scheme.primary),
      (icon: Icons.assessment, title: 'Exam results published', time: '1 day ago', color: const Color(0xFF6A1B9A)),
    ];

    return Column(
      children: [
        for (int i = 0; i < recentActions.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < recentActions.length - 1 ? 12 : 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: recentActions[i].color.withValues(alpha: 0.06),
                border: Border.all(color: recentActions[i].color.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: recentActions[i].color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      recentActions[i].icon,
                      color: recentActions[i].color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recentActions[i].title,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          recentActions[i].time,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
