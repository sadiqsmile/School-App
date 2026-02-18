import '../../models/exam_marks_result.dart';

/// CSV export row for exam marks
class ExamMarksCsvRow {
  const ExamMarksCsvRow({
    required this.studentId,
    required this.admissionNo,
    required this.name,
    required this.classId,
    required this.sectionId,
    required this.groupId,
    required this.studentType,
    required this.subjectMarks, // Map<subjectId, marks>
    required this.rowNumber,
  });

  final int rowNumber;
  final String studentId;
  final String? admissionNo;
  final String name;
  final String classId;
  final String sectionId;
  final String groupId;
  final String? studentType; // 'hostel' or 'day'
  final Map<String, num> subjectMarks;

  static List<String> headers({required List<String> subjects}) {
    return [
      'studentId',
      'admissionNo',
      'name',
      'classId',
      'sectionId',
      'groupId',
      'studentType',
      ...subjects, // Dynamic subject columns
    ];
  }

  Map<String, Object?> toMap() {
    final base = <String, Object?>{
      'studentId': studentId,
      'admissionNo': admissionNo ?? '',
      'name': name,
      'classId': classId,
      'sectionId': sectionId,
      'groupId': groupId,
      'studentType': studentType ?? '',
    };
    // Add subject marks
    for (final entry in subjectMarks.entries) {
      base[entry.key] = entry.value;
    }
    return base;
  }

  factory ExamMarksCsvRow.fromExamMarksResult(
    ExamMarksResult result, {
    required List<String> subjects,
    int rowNumber = 0,
  }) {
    final subjectMarks = <String, num>{};
    for (final subject in subjects) {
      subjectMarks[subject] = result.marks[subject] ?? 0;
    }

    return ExamMarksCsvRow(
      studentId: result.studentId,
      admissionNo: result.admissionNo,
      name: result.name,
      classId: result.classId,
      sectionId: result.sectionId,
      groupId: result.groupId,
      studentType: result.studentType,
      subjectMarks: subjectMarks,
      rowNumber: rowNumber,
    );
  }
}

