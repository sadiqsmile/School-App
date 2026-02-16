import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';
import '../services/teacher_contact_parents_service.dart';

@immutable
class TeacherContactParentsQuery {
  const TeacherContactParentsQuery({
    required this.groupId,
    required this.classId,
    required this.sectionId,
    required this.activeOnly,
  });

  final String groupId;
  final String classId;
  final String sectionId;
  final bool activeOnly;

  @override
  bool operator ==(Object other) {
    return other is TeacherContactParentsQuery &&
        other.groupId == groupId &&
        other.classId == classId &&
        other.sectionId == sectionId &&
        other.activeOnly == activeOnly;
  }

  @override
  int get hashCode => Object.hash(groupId, classId, sectionId, activeOnly);
}

final studentsForTeacherContactProvider = StreamProvider.family<List<StudentParentContactEntry>, TeacherContactParentsQuery>(
  (ref, query) {
    return ref.read(teacherContactParentsServiceProvider).watchStudentsForGroupClassSection(
          groupId: query.groupId,
          classId: query.classId,
          sectionId: query.sectionId,
          activeOnly: query.activeOnly,
        );
  },
);
