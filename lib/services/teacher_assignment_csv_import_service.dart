import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../features/csv/teacher_assignments_csv.dart';

class TeacherAssignmentCsvImportRowResult {
  const TeacherAssignmentCsvImportRowResult({
    required this.rowNumber,
    required this.success,
    required this.message,
    this.teacherUid,
  });

  final int rowNumber;
  final bool success;
  final String message;
  final String? teacherUid;
}

class TeacherAssignmentCsvImportReport {
  const TeacherAssignmentCsvImportReport({
    required this.totalRows,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<TeacherAssignmentCsvImportRowResult> results;
}

class TeacherAssignmentCsvImportService {
  TeacherAssignmentCsvImportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  /// Export teacher assignments to CSV format
  Future<List<Map<String, Object?>>> exportTeacherAssignmentsForCsv({
    String schoolId = AppConfig.schoolId,
  }) async {
    final snap = await _schoolDoc(schoolId: schoolId)
        .collection('teacherAssignments')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      final classSectionIds = (data['classSectionIds'] as List?) ?? const [];
      return <String, Object?>{
        'teacherUid': d.id,
        'classSectionIds': classSectionIds,
      };
    }).toList(growable: false);
  }

  /// Import teacher assignments from CSV
  /// Each row contains a teacher UID and a list of class/section IDs to assign
  Future<TeacherAssignmentCsvImportReport> importTeacherAssignments({
    String schoolId = AppConfig.schoolId,
    required List<TeacherAssignmentCsvRow> rows,
    bool replaceExisting = true, // If true, replace existing assignments; if false, merge
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <TeacherAssignmentCsvImportRowResult>[];

    final school = _schoolDoc(schoolId: schoolId);
    final assignmentsCol = school.collection('teacherAssignments');

    const maxWritesPerBatch = 400;
    WriteBatch batch = _firestore.batch();
    var writesInBatch = 0;

    Future<void> commitBatchIfNeeded({bool force = false}) async {
      if (writesInBatch == 0) return;
      if (!force && writesInBatch < maxWritesPerBatch) return;
      await batch.commit();
      batch = _firestore.batch();
      writesInBatch = 0;
    }

    int done = 0;

    for (final r in rows) {
      try {
        final cleanedTeacherUid = r.teacherUid.trim();

        if (cleanedTeacherUid.isEmpty) {
          results.add(TeacherAssignmentCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Teacher UID is required',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        if (r.classSectionIds.isEmpty) {
          results.add(TeacherAssignmentCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'At least one class/section ID is required',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        final docRef = assignmentsCol.doc(cleanedTeacherUid);

        if (replaceExisting) {
          // Replace entire assignment
          batch.set(
            docRef,
            {
              'teacherUid': cleanedTeacherUid,
              'classSectionIds': r.classSectionIds,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        } else {
          // Merge with existing (append class section IDs)
          batch.set(
            docRef,
            {
              'teacherUid': cleanedTeacherUid,
              'classSectionIds': FieldValue.arrayUnion(r.classSectionIds),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        writesInBatch++;

        results.add(TeacherAssignmentCsvImportRowResult(
          rowNumber: r.rowNumber,
          success: true,
          message: 'OK ${r.classSectionIds.length} assignment(s)',
          teacherUid: cleanedTeacherUid,
        ));

        done++;
        onProgress?.call(done, rows.length);

        await commitBatchIfNeeded();
      } catch (e) {
        results.add(TeacherAssignmentCsvImportRowResult(
          rowNumber: r.rowNumber,
          success: false,
          message: 'Error: $e',
        ));
        done++;
        onProgress?.call(done, rows.length);
      }
    }

    await commitBatchIfNeeded(force: true);

    final successCount = results.where((x) => x.success).length;
    final failureCount = results.where((x) => !x.success).length;

    return TeacherAssignmentCsvImportReport(
      totalRows: rows.length,
      successCount: successCount,
      failureCount: failureCount,
      results: results,
    );
  }
}
