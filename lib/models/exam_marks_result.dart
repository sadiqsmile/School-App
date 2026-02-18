import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents exam marks for a student across all subjects
/// Path: schools/{schoolId}/academicYears/{yearId}/exams/{examId}/results/{studentId}
class ExamMarksResult {
  const ExamMarksResult({
    required this.studentId,
    required this.admissionNo,
    required this.name,
    required this.classId,
    required this.sectionId,
    required this.groupId,
    required this.examId,
    required this.examName,
    required this.marks,
    required this.maxMarks,
    required this.total,
    required this.percentage,
    required this.grade,
    required this.resultStatus,
    required this.updatedAt,
    required this.updatedByUid,
    this.studentType, // 'hostel' or 'day'
  });

  final String studentId;
  final String? admissionNo;
  final String name;
  final String classId;
  final String sectionId;
  final String groupId;
  final String examId;
  final String examName;
  
  // Map<subjectId, marks>
  final Map<String, num> marks;
  
  // Map<subjectId, maxMarks>
  final Map<String, num> maxMarks;
  
  final num total;
  final num percentage;
  final String grade;
  final String resultStatus; // 'pass' or 'fail'
  final DateTime updatedAt;
  final String updatedByUid;
  final String? studentType; // 'hostel' or 'day'

  factory ExamMarksResult.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, Object?>{};

    num readNum(Object? v) {
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? 0;
      return 0;
    }

    DateTime readTs(Object? v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.now();
    }

    // Parse marks map
    final marksData = data['marks'] as Map<String, dynamic>? ?? {};
    final marks = <String, num>{};
    for (final entry in marksData.entries) {
      marks[entry.key] = readNum(entry.value);
    }

    // Parse maxMarks map
    final maxMarksData = data['maxMarks'] as Map<String, dynamic>? ?? {};
    final maxMarksMap = <String, num>{};
    for (final entry in maxMarksData.entries) {
      maxMarksMap[entry.key] = readNum(entry.value);
    }

    return ExamMarksResult(
      studentId: (data['studentId'] as String?)?.trim() ?? doc.id,
      admissionNo: (data['admissionNo'] as String?)?.trim(),
      name: (data['name'] as String?)?.trim() ?? 'Student',
      classId: (data['classId'] as String?)?.trim() ?? '',
      sectionId: (data['sectionId'] as String?)?.trim() ?? '',
      groupId: (data['groupId'] as String?)?.trim() ?? '',
      examId: (data['examId'] as String?)?.trim() ?? '',
      examName: (data['examName'] as String?)?.trim() ?? '',
      marks: marks,
      maxMarks: maxMarksMap,
      total: readNum(data['total']),
      percentage: readNum(data['percentage']),
      grade: (data['grade'] as String?)?.trim() ?? 'NA',
      resultStatus: (data['resultStatus'] as String?)?.trim() ?? 'pending',
      updatedAt: readTs(data['updatedAt']),
      updatedByUid: (data['updatedByUid'] as String?)?.trim() ?? '',
      studentType: (data['studentType'] as String?)?.trim(),
    );
  }

  Map<String, Object?> toFirestore() {
    return {
      'studentId': studentId,
      'admissionNo': admissionNo,
      'name': name,
      'classId': classId,
      'sectionId': sectionId,
      'groupId': groupId,
      'examId': examId,
      'examName': examName,
      'marks': marks,
      'maxMarks': maxMarks,
      'total': total,
      'percentage': percentage,
      'grade': grade,
      'resultStatus': resultStatus,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'updatedByUid': updatedByUid,
      if (studentType != null) 'studentType': studentType,
    };
  }

  ExamMarksResult copyWith({
    String? studentId,
    String? admissionNo,
    String? name,
    String? classId,
    String? sectionId,
    String? groupId,
    String? examId,
    String? examName,
    Map<String, num>? marks,
    Map<String, num>? maxMarks,
    num? total,
    num? percentage,
    String? grade,
    String? resultStatus,
    DateTime? updatedAt,
    String? updatedByUid,
    String? studentType,
  }) {
    return ExamMarksResult(
      studentId: studentId ?? this.studentId,
      admissionNo: admissionNo ?? this.admissionNo,
      name: name ?? this.name,
      classId: classId ?? this.classId,
      sectionId: sectionId ?? this.sectionId,
      groupId: groupId ?? this.groupId,
      examId: examId ?? this.examId,
      examName: examName ?? this.examName,
      marks: marks ?? this.marks,
      maxMarks: maxMarks ?? this.maxMarks,
      total: total ?? this.total,
      percentage: percentage ?? this.percentage,
      grade: grade ?? this.grade,
      resultStatus: resultStatus ?? this.resultStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByUid: updatedByUid ?? this.updatedByUid,
      studentType: studentType ?? this.studentType,
    );
  }
}
