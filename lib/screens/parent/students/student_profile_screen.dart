import 'package:flutter/material.dart';

import '../../../models/parent_student.dart';
import '../attendance/attendance_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({
    super.key,
    required this.student,
    required this.yearId,
  });

  final ParentStudent student;
  final String yearId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundImage: student.base.photoUrl == null
                        ? null
                        : NetworkImage(student.base.photoUrl!),
                    child: student.base.photoUrl == null
                        ? const Icon(Icons.person, size: 36)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.base.fullName,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('Admission No: ${student.base.admissionNo ?? '-'}'),
                        const SizedBox(height: 4),
                        Text('Class/Section: ${student.year.classSectionId}'),
                        const SizedBox(height: 4),
                        Text('Roll No: ${student.year.rollNo ?? '-'}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AttendanceScreen(
                      yearId: yearId,
                      studentId: student.base.id,
                      studentName: student.base.fullName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text('View Attendance'),
            ),
          ),
        ],
      ),
    );
  }
}
