# 🎯 Quick Integration Guide - Advanced Analytics Dashboard

## Navigation Integration Examples

### Option 1: Add to Admin Dashboard Menu

**File:** `lib/screens/admin/admin_dashboard_screen.dart`

```dart
import 'package:flutter/material.dart';
import '../admin/advanced_attendance_analytics_dashboard.dart';

// In your admin dashboard GridView or ListView
GridView.count(
  crossAxisCount: 2,
  children: [
    // ... existing cards ...
    
    // NEW: Analytics Dashboard Card
    _buildDashboardCard(
      context: context,
      title: 'Attendance Analytics',
      icon: Icons.analytics,
      color: Colors.purple,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AdvancedAttendanceAnalyticsDashboard(
              userRole: 'admin',
            ),
          ),
        );
      },
    ),
  ],
)
```

---

### Option 2: Add to Admin Drawer Menu

**File:** `lib/screens/admin/admin_dashboard_screen.dart`

```dart
Drawer(
  child: ListView(
    children: [
      // ... existing menu items ...
      
      // NEW: Analytics Menu Item
      ListTile(
        leading: const Icon(Icons.analytics, color: Colors.purple),
        title: const Text('Attendance Analytics'),
        onTap: () {
          Navigator.pop(context); // Close drawer
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdvancedAttendanceAnalyticsDashboard(
                userRole: 'admin',
              ),
            ),
          );
        },
      ),
    ],
  ),
)
```

---

### Option 3: Add to Teacher Dashboard (Class Teacher)

**File:** `lib/screens/teacher/teacher_dashboard_screen.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../admin/advanced_attendance_analytics_dashboard.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get teacher's assigned class from your teacher provider
    final teacherData = ref.watch(teacherProfileProvider);
    
    return Scaffold(
      body: GridView.count(
        crossAxisCount: 2,
        children: [
          // ... existing cards ...
          
          // NEW: My Class Analytics Card
          _buildDashboardCard(
            context: context,
            title: 'My Class Analytics',
            icon: Icons.bar_chart,
            color: Colors.indigo,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdvancedAttendanceAnalyticsDashboard(
                    userRole: 'class_teacher',
                    assignedClassId: teacherData.classId,
                    assignedSectionId: teacherData.sectionId,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

---

### Option 4: Add as Floating Action Button (FAB)

**File:** `lib/screens/admin/admin_attendance_screen.dart`

```dart
Scaffold(
  appBar: AppBar(title: const Text('Attendance')),
  body: AttendanceListView(),
  
  // NEW: Quick access to analytics
  floatingActionButton: FloatingActionButton.extended(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AdvancedAttendanceAnalyticsDashboard(
            userRole: 'admin',
          ),
        ),
      );
    },
    icon: const Icon(Icons.analytics),
    label: const Text('Analytics'),
    backgroundColor: Colors.purple,
  ),
)
```

---

### Option 5: Add to AppBar Actions

**File:** `lib/screens/teacher/attendance/teacher_attendance_screen.dart`

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('Mark Attendance'),
    actions: [
      // NEW: Analytics icon in AppBar
      IconButton(
        icon: const Icon(Icons.analytics),
        tooltip: 'View Analytics',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdvancedAttendanceAnalyticsDashboard(
                userRole: 'class_teacher',
                assignedClassId: widget.classId,
                assignedSectionId: widget.sectionId,
              ),
            ),
          );
        },
      ),
    ],
  ),
  body: AttendanceMarkingView(),
)
```

---

## Complete Example with Bottom Navigation

**File:** `lib/screens/admin/admin_main_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import 'admin_attendance_screen.dart';
import '../admin/advanced_attendance_analytics_dashboard.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const AdminDashboardScreen(),
    const AdminAttendanceScreen(),
    const AdvancedAttendanceAnalyticsDashboard(userRole: 'admin'), // NEW
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics), // NEW
            label: 'Analytics', // NEW
          ),
        ],
      ),
    );
  }
}
```

---

## Tab-Based Navigation Example

**File:** `lib/screens/admin/admin_attendance_tabs_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'admin_attendance_list_screen.dart';
import '../admin/advanced_attendance_analytics_dashboard.dart';

class AdminAttendanceTabsScreen extends StatelessWidget {
  const AdminAttendanceTabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance Management'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'Records'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'), // NEW
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminAttendanceListScreen(),
            AdvancedAttendanceAnalyticsDashboard(userRole: 'admin'), // NEW
          ],
        ),
      ),
    );
  }
}
```

---

## Role-Based Routing Example

**File:** `lib/router/app_router.dart`

```dart
import 'package:go_router/go_router.dart';
import '../screens/admin/advanced_attendance_analytics_dashboard.dart';

final router = GoRouter(
  routes: [
    // ... existing routes ...
    
    // NEW: Analytics routes with role-based parameters
    GoRoute(
      path: '/analytics',
      builder: (context, state) {
        final userRole = state.queryParams['role'] ?? 'admin';
        final classId = state.queryParams['classId'];
        final sectionId = state.queryParams['sectionId'];
        
        return AdvancedAttendanceAnalyticsDashboard(
          userRole: userRole,
          assignedClassId: classId,
          assignedSectionId: sectionId,
        );
      },
    ),
  ],
);

// Usage:
// context.go('/analytics?role=admin');
// context.go('/analytics?role=class_teacher&classId=5&sectionId=A');
```

---

## Dynamic Role-Based Navigation Helper

**File:** `lib/utils/navigation_helper.dart`

```dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../screens/admin/advanced_attendance_analytics_dashboard.dart';

class NavigationHelper {
  /// Navigate to analytics dashboard based on user role
  static void navigateToAnalytics(BuildContext context, UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          // Admin - full access
          if (user.role == 'admin') {
            return const AdvancedAttendanceAnalyticsDashboard(
              userRole: 'admin',
            );
          }
          
          // Class Teacher - restricted to assigned class
          else if (user.role == 'class_teacher' && 
                   user.classId != null && 
                   user.sectionId != null) {
            return AdvancedAttendanceAnalyticsDashboard(
              userRole: 'class_teacher',
              assignedClassId: user.classId!,
              assignedSectionId: user.sectionId!,
            );
          }
          
          // Regular Teacher - can select from their classes
          else if (user.role == 'teacher') {
            return const AdvancedAttendanceAnalyticsDashboard(
              userRole: 'teacher',
            );
          }
          
          // Fallback - show error
          else {
            return Scaffold(
              body: Center(
                child: Text('Analytics not available for ${user.role}'),
              ),
            );
          }
        },
      ),
    );
  }
}

// Usage in any screen:
ElevatedButton(
  onPressed: () {
    final user = ref.read(currentUserProvider);
    NavigationHelper.navigateToAnalytics(context, user);
  },
  child: const Text('View Analytics'),
)
```

---

## Permission Check Before Navigation

**File:** `lib/utils/permission_helper.dart`

```dart
import '../models/user_model.dart';

class PermissionHelper {
  /// Check if user can access analytics dashboard
  static bool canAccessAnalytics(UserModel user) {
    return user.role == 'admin' || 
           user.role == 'teacher' || 
           user.role == 'class_teacher';
  }
  
  /// Check if user can view all classes (admin only)
  static bool canViewAllClasses(UserModel user) {
    return user.role == 'admin';
  }
  
  /// Check if user can export reports
  static bool canExportReports(UserModel user) {
    return user.role == 'admin' || user.role == 'class_teacher';
  }
}

// Usage in UI:
final user = ref.watch(currentUserProvider);

if (PermissionHelper.canAccessAnalytics(user)) {
  // Show analytics button
  _buildAnalyticsButton(context);
}
```

---

## Integration with Existing Attendance Screen

**File:** `lib/screens/teacher/attendance/enhanced_attendance_marking_screen.dart`

Add this button at the bottom of the attendance marking screen:

```dart
// At the bottom of your attendance marking screen
Padding(
  padding: const EdgeInsets.all(16),
  child: Row(
    children: [
      Expanded(
        child: ElevatedButton(
          onPressed: _saveAttendance,
          child: const Text('Save Attendance'),
        ),
      ),
      const SizedBox(width: 12),
      
      // NEW: Quick analytics access
      ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdvancedAttendanceAnalyticsDashboard(
                userRole: widget.userRole,
                assignedClassId: widget.classId,
                assignedSectionId: widget.sectionId,
              ),
            ),
          );
        },
        icon: const Icon(Icons.analytics),
        label: const Text('Analytics'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
        ),
      ),
    ],
  ),
)
```

---

## Testing Navigation

**Test Code:**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Admin can navigate to analytics dashboard', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AdminDashboardScreen(),
    ));
    
    // Find analytics button
    final analyticsButton = find.text('Attendance Analytics');
    expect(analyticsButton, findsOneWidget);
    
    // Tap button
    await tester.tap(analyticsButton);
    await tester.pumpAndSettle();
    
    // Verify navigation to analytics screen
    expect(find.byType(AdvancedAttendanceAnalyticsDashboard), findsOneWidget);
  });
}
```

---

## Summary of Integration Options

| Method | Best For | Complexity |
|--------|----------|------------|
| Dashboard Card | Primary navigation | Low |
| Drawer Menu | Secondary navigation | Low |
| Bottom Nav Bar | Frequent access | Medium |
| AppBar Action | Context-specific | Low |
| FAB | Quick access | Low |
| Tab Navigation | Related features | Medium |
| Route-based | Large apps | High |

**Recommendation:** Start with **Dashboard Card** or **Drawer Menu** for simplest integration.

---

## Next Steps

1. Choose integration method
2. Add navigation code to your dashboard
3. Test with different user roles
4. Verify permissions work correctly

**Done!** Your analytics dashboard is ready to use! 🚀
