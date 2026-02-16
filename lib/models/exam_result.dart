import 'package:cloud_firestore/cloud_firestore.dart';

import 'exam_subject_result.dart';

class ExamResult {
  const ExamResult({
    required this.studentId,
    required this.admissionNo,
    required this.studentName,
    required this.classId,
    required this.sectionId,
    required this.groupId,
    required this.subjects,
    required this.total,
    required this.percentage,
    required this.grade,
    required this.isPublished,
    this.updatedAt,
    this.enteredByTeacherUid,
  });

  final String studentId;
  final String? admissionNo;
  final String studentName;
  final String classId;
  final String sectionId;
  final String groupId;
  final List<ExamSubjectResult> subjects;
  final double total;
  final double percentage;
  final String grade;
  final bool isPublished;
  final DateTime? updatedAt;
  final String? enteredByTeacherUid;

  factory ExamResult.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, Object?>{};

    double readNum(Object? v) {
      if (v is num) return v.toDouble();
      return 0;
    }

    DateTime? readTs(Object? v) => v is Timestamp ? v.toDate() : null;

    final rawSubjects = data['subjects'];
    final subjects = <ExamSubjectResult>[];
    if (rawSubjects is List) {
      for (final it in rawSubjects) {
        if (it is Map) subjects.add(ExamSubjectResult.fromMap(it.cast<String, Object?>()));
      }
    }

    return ExamResult(
      studentId: (data['studentId'] as String?)?.trim() ?? doc.id,
      admissionNo: (data['admissionNo'] as String?)?.trim(),
      studentName: (data['studentName'] as String?)?.trim() ?? 'Student',
      classId: (data['class'] as String?)?.trim() ?? '',
      sectionId: (data['section'] as String?)?.trim() ?? '',
      groupId: (data['groupId'] as String?)?.trim() ?? '',
      subjects: subjects,
      total: readNum(data['total']),
      percentage: readNum(data['percentage']),
      grade: (data['grade'] as String?)?.trim() ?? '',
      isPublished: (data['isPublished'] ?? false) == true,
      updatedAt: readTs(data['updatedAt']),
      enteredByTeacherUid: (data['enteredByTeacherUid'] as String?)?.trim(),
    );
  }
}
