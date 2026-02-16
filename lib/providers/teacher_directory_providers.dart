import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/core_providers.dart';
import '../services/teacher_directory_service.dart';

/// Streams active teachers for a student's group.
final activeTeachersForGroupProvider = StreamProvider.family<List<TeacherDirectoryEntry>, String>((ref, groupId) {
  final service = ref.watch(teacherDirectoryServiceProvider);
  return service.watchActiveTeachersForGroup(groupId: groupId);
});
