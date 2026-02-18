import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../features/csv/exam_marks_csv.dart';
import '../models/exam.dart';
import '../models/exam_marks_result.dart';
import '../models/exam_result.dart';
import '../models/exam_timetable.dart';
import '../models/teacher_subject_assignment.dart';
import '../services/exam_marks_import_service.dart';
import '../services/teacher_marks_import_service.dart';
import 'core_providers.dart';

// ===================== Exam Watching Providers =====================

/// Watch all exams for a given academic year by group.
final watchExamsByGroupProvider = StreamProvider.family<List<Exam>, ({String yearId, String groupId})>(
  (ref, params) {
    final examService = ref.watch(examServiceProvider);
    return examService.watchExamsForGroup(
      yearId: params.yearId,
      groupId: params.groupId,
      onlyActive: true,
    );
  },
);

/// Watch all exams for multiple groups (teacher use case).
final watchExamsByGroupsProvider = StreamProvider.family<List<Exam>, ({String yearId, List<String> groupIds})>(
  (ref, params) {
    final examService = ref.watch(examServiceProvider);
    return examService.watchExamsForGroups(
      yearId: params.yearId,
      groupIds: params.groupIds,
      onlyActive: true,
    );
  },
);

/// Watch all exams for an academic year (admin use case).
final watchAllExamsProvider = StreamProvider.family<List<Exam>, String>(
  (ref, yearId) {
    final examService = ref.watch(examServiceProvider);
    return examService.watchExams(yearId: yearId);
  },
);

/// Watch a single exam.
final watchExamProvider = StreamProvider.family<Exam?, ({String yearId, String examId})>(
  (ref, params) {
    final examService = ref.watch(examServiceProvider);
    return examService.watchExam(yearId: params.yearId, examId: params.examId);
  },
);

// ===================== Timetable Watching Providers =====================

/// Watch timetable for an exam.
final watchExamTimetableProvider =
    StreamProvider.family<List<ExamTimetable>, ({String yearId, String examId})>(
  (ref, params) {
    final examService = ref.watch(examServiceProvider);
    return examService.watchTimetable(yearId: params.yearId, examId: params.examId);
  },
);

/// Watch timetable for a specific class-section in an exam.
final watchExamTimetableForClassSectionProvider = StreamProvider.family<
    ExamTimetable?,
    ({
      String yearId,
      String examId,
      String classId,
      String sectionId,
    })>(
  (ref, params) {
    final examService = ref.watch(examServiceProvider);
    return examService.watchTimetableForClassSection(
      yearId: params.yearId,
      examId: params.examId,
      classId: params.classId,
      sectionId: params.sectionId,
    );
  },
);

// ===================== Results Watching Providers =====================

/// Watch exam results for a class-section (with approval status).
final watchExamResultsForClassSectionProvider = StreamProvider.family<
    List<ExamResult>,
    ({
      String yearId,
      String examId,
      String classId,
      String sectionId,
    })>(
  (ref, params) {
    final examService = ref.watch(examServiceProvider);
    return examService.watchResultsApprovalStatusForClassSection(
      yearId: params.yearId,
      examId: params.examId,
      classId: params.classId,
      sectionId: params.sectionId,
    );
  },
);

/// Watch exam result for a specific student.
final watchExamResultForStudentProvider = StreamProvider.family<
    ExamResult?,
    ({
      String yearId,
      String examId,
      String studentId,
    })>(
  (ref, params) {
    final examService = ref.watch(examServiceProvider);
    return examService.watchResultForStudent(
      yearId: params.yearId,
      examId: params.examId,
      studentId: params.studentId,
    );
  },
);

// ===================== Exam Creation/Update Providers (State Notifiers) =====================

class CreateExamNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async => '';

  Future<void> createExam({
    required String yearId,
    required String examName,
    required String groupId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final examService = ref.read(examServiceProvider);
      return await examService.createExam(
        yearId: yearId,
        examName: examName,
        groupId: groupId,
        startDate: startDate,
        endDate: endDate,
        isActive: true,
      );
    });
  }
}

final createExamProvider = AsyncNotifierProvider<CreateExamNotifier, String>(
  CreateExamNotifier.new,
);

class UpdateExamNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateExam({
    required String yearId,
    required String examId,
    required String examName,
    required String groupId,
    DateTime? startDate,
    DateTime? endDate,
    required bool isActive,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final examService = ref.read(examServiceProvider);
      await examService.updateExam(
        yearId: yearId,
        examId: examId,
        examName: examName,
        groupId: groupId,
        startDate: startDate,
        endDate: endDate,
        isActive: isActive,
      );
    });
  }
}

final updateExamProvider = AsyncNotifierProvider<UpdateExamNotifier, void>(
  UpdateExamNotifier.new,
);

// ===================== Admin Exam Filters =====================

final filteredExamsForGroupProvider = StreamProvider.family<List<Exam>, ({String yearId, String groupId})>(
  (ref, params) {
    final examService = ref.watch(examServiceProvider);
    return examService.watchExamsForGroup(
      yearId: params.yearId,
      groupId: params.groupId,
    );
  },
);

// ===================== Approval Workflow Notifiers =====================

class ApproveResultNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> approveForStudent({
    required String yearId,
    required String examId,
    required String studentId,
    required String approvedByUid,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final examService = ref.read(examServiceProvider);
      await examService.approveResultForStudent(
        yearId: yearId,
        examId: examId,
        studentId: studentId,
        approvedByUid: approvedByUid,
      );
    });
  }

  Future<void> approveForClassSection({
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
    required String approvedByUid,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final examService = ref.read(examServiceProvider);
      await examService.approveResultsForClassSection(
        yearId: yearId,
        examId: examId,
        classId: classId,
        sectionId: sectionId,
        approvedByUid: approvedByUid,
      );
    });
  }
}

final approveResultProvider = AsyncNotifierProvider<ApproveResultNotifier, void>(
  ApproveResultNotifier.new,
);

class PublishResultNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> publishForClassSection({
    required String yearId,
    required String examId,
    required String classId,
    required String sectionId,
    required String publishedByUid,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final examService = ref.read(examServiceProvider);
      await examService.publishResultsForClassSection(
        yearId: yearId,
        examId: examId,
        classId: classId,
        sectionId: sectionId,
        publishedByUid: publishedByUid,
      );
    });
  }
}

final publishResultProvider = AsyncNotifierProvider<PublishResultNotifier, void>(
  PublishResultNotifier.new,
);

// ===================== Exam Marks Import/Export Providers =====================

/// Service provider for exam marks import/export
final examMarksImportServiceProvider = Provider<ExamMarksImportService>((ref) {
  return ExamMarksImportService();
});

/// Service provider for teacher marks import
final teacherMarksImportServiceProvider = Provider<TeacherMarksImportService>((ref) {
  return TeacherMarksImportService();
});

/// Watch exam marks results for a specific class-section
final watchExamMarksResultsProvider = StreamProvider.family<
    List<ExamMarksResult>,
    ({
      String yearId,
      String examId,
      String classId,
      String sectionId,
    })>(
  (ref, params) {
    return FirebaseFirestore.instance
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('academicYears')
        .doc(params.yearId)
        .collection('exams')
        .doc(params.examId)
        .collection('results')
        .where('classId', isEqualTo: params.classId)
        .where('sectionId', isEqualTo: params.sectionId)
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExamMarksResult.fromDoc(
                  doc as DocumentSnapshot<Map<String, dynamic>>,
                ))
            .toList(growable: false));
  },
);

/// Watch a single student's exam marks result
final watchStudentExamMarksProvider = StreamProvider.family<
    ExamMarksResult?,
    ({
      String yearId,
      String examId,
      String studentId,
    })>(
  (ref, params) {
    return FirebaseFirestore.instance
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('academicYears')
        .doc(params.yearId)
        .collection('exams')
        .doc(params.examId)
        .collection('results')
        .doc(params.studentId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return ExamMarksResult.fromDoc(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    });
  },
);

/// Watch teacher assignment
final watchTeacherAssignmentProvider =
    StreamProvider.family<TeacherSubjectAssignment?, String>(
  (ref, teacherUid) {
    return FirebaseFirestore.instance
        .collection('schools')
        .doc(AppConfig.schoolId)
        .collection('teacherAssignments')
        .doc(teacherUid)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return TeacherSubjectAssignment.fromDoc(
          doc as DocumentSnapshot<Map<String, dynamic>>,
        );
      }
      return null;
    });
  },
);

// ===================== Exam Marks Notifiers =====================

class ImportExamMarksNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> importMarks({
    required String yearId,
    required String examId,
    required String examName,
    required List<ExamMarksCsvRow> csvRows,
    required List<String> subjects,
    required Map<String, int> maxMarksPerSubject,
    required String updatedByUid,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(examMarksImportServiceProvider);
      await service.importExamMarks(
        yearId: yearId,
        examId: examId,
        examName: examName,
        csvRows: csvRows,
        subjects: subjects,
        maxMarksPerSubject: maxMarksPerSubject,
        updatedByUid: updatedByUid,
      );
    });
  }
}

final importExamMarksProvider = AsyncNotifierProvider<ImportExamMarksNotifier, void>(
  ImportExamMarksNotifier.new,
);

class ImportTeacherMarksNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> importMarks({
    required String yearId,
    required String examId,
    required List<ExamMarksCsvRow> csvRows,
    required List<String> teacherSubjects,
    required Map<String, int> maxMarksPerSubject,
    required String updatedByUid,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(teacherMarksImportServiceProvider);
      await service.importTeacherMarks(
        yearId: yearId,
        examId: examId,
        csvRows: csvRows,
        teacherSubjects: teacherSubjects,
        maxMarksPerSubject: maxMarksPerSubject,
        updatedByUid: updatedByUid,
      );
    });
  }
}

final importTeacherMarksProvider = AsyncNotifierProvider<ImportTeacherMarksNotifier, void>(
  ImportTeacherMarksNotifier.new,
);

class UpdateStudentMarksNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateMarks({
    required String yearId,
    required String examId,
    required String studentId,
    required Map<String, num> subjectMarks,
    required Map<String, num> maxMarks,
    required String updatedByUid,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(teacherMarksImportServiceProvider);
      await service.updateStudentMarks(
        yearId: yearId,
        examId: examId,
        studentId: studentId,
        subjectMarks: subjectMarks,
        maxMarks: maxMarks,
        updatedByUid: updatedByUid,
      );
    });
  }
}

final updateStudentMarksProvider = AsyncNotifierProvider<UpdateStudentMarksNotifier, void>(
  UpdateStudentMarksNotifier.new,
);

