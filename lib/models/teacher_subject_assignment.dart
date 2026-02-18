import 'package:cloud_firestore/cloud_firestore.dart';

/// Teacher subject assignment
/// Path: schools/{schoolId}/teacherAssignments/{teacherUid}
class TeacherSubjectAssignment {
  const TeacherSubjectAssignment({
    required this.teacherUid,
    required this.classSectionIds,
    required this.groups,
    required this.subjects,
    this.hostelFilterAccess = false,
  });

  final String teacherUid;
  
  // List of class section IDs (e.g., ["6_A", "6_B", "7_A"])
  final List<String> classSectionIds;
  
  // List of group IDs (e.g., ["primary", "middle", "highschool"])
  final List<String> groups;
  
  // List of subject IDs assigned to this teacher
  final List<String> subjects;
  
  // Can teacher filter by hostel/day student type
  final bool hostelFilterAccess;

  factory TeacherSubjectAssignment.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, Object?>{};

    List<String> readStringList(Object? v) {
      if (v is List) {
        return v
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(growable: false);
      }
      return const [];
    }

    return TeacherSubjectAssignment(
      teacherUid: doc.id,
      classSectionIds: readStringList(data['classSectionIds']),
      groups: readStringList(data['groups']),
      subjects: readStringList(data['subjects']),
      hostelFilterAccess: (data['hostelFilterAccess'] ?? false) == true,
    );
  }

  Map<String, Object?> toFirestore() {
    return {
      'classSectionIds': classSectionIds,
      'groups': groups,
      'subjects': subjects,
      'hostelFilterAccess': hostelFilterAccess,
    };
  }

  TeacherSubjectAssignment copyWith({
    String? teacherUid,
    List<String>? classSectionIds,
    List<String>? groups,
    List<String>? subjects,
    bool? hostelFilterAccess,
  }) {
    return TeacherSubjectAssignment(
      teacherUid: teacherUid ?? this.teacherUid,
      classSectionIds: classSectionIds ?? this.classSectionIds,
      groups: groups ?? this.groups,
      subjects: subjects ?? this.subjects,
      hostelFilterAccess: hostelFilterAccess ?? this.hostelFilterAccess,
    );
  }
}
