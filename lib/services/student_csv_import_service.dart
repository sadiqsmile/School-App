import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../features/csv/students_csv.dart';
import 'parent_password_hasher.dart';

class StudentCsvImportRowResult {
  const StudentCsvImportRowResult({
    required this.rowNumber,
    required this.success,
    required this.message,
    this.studentId,
  });

  final int rowNumber;
  final bool success;
  final String message;
  final String? studentId;
}

class StudentCsvImportReport {
  const StudentCsvImportReport({
    required this.totalRows,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<StudentCsvImportRowResult> results;
}

class StudentCsvImportService {
  StudentCsvImportService({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  Future<List<Map<String, Object?>>> exportBaseStudentsForCsv({
    String schoolId = AppConfig.schoolId,
  }) async {
    final snap = await _schoolDoc(schoolId: schoolId)
        .collection('students')
        .orderBy('name')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return <String, Object?>{
        'studentId': d.id,
        'admissionNo': (data['admissionNo'] as String?) ?? '',
        'name': (data['name'] as String?) ?? (data['fullName'] as String?) ?? '',
        'class': (data['class'] as String?) ?? (data['classId'] as String?) ?? '',
        'section': (data['section'] as String?) ?? (data['sectionId'] as String?) ?? '',
        'group': (data['group'] as String?) ?? (data['groupId'] as String?) ?? '',
        'parentMobile': (data['parentMobile'] as String?) ?? '',
        'isActive': (data['isActive'] ?? true) == true,
      };
    }).toList(growable: false);
  }

  Future<StudentCsvImportReport> importStudents({
    String schoolId = AppConfig.schoolId,
    required List<StudentCsvRow> rows,
    bool allowUpdates = true,
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <StudentCsvImportRowResult>[];

    final school = _schoolDoc(schoolId: schoolId);
    final studentsCol = school.collection('students');
    final admissionIndexCol = school.collection('admissionNumbers');
    final parentsCol = school.collection('parents');

    final admissionIndexSnap = await admissionIndexCol.get();
    final admissionIndex = <String, String>{};
    for (final doc in admissionIndexSnap.docs) {
      final admissionNo = doc.id.trim();
      final studentId = (doc.data()['studentId'] as String?)?.trim();
      if (admissionNo.isNotEmpty && studentId != null && studentId.isNotEmpty) {
        admissionIndex[admissionNo] = studentId;
      }
    }

    final existingStudentsSnap = await studentsCol.get();
    final existingById = <String, Map<String, dynamic>>{};
    final existingByNameKey = <String, String>{};
    for (final doc in existingStudentsSnap.docs) {
      final data = doc.data();
      existingById[doc.id] = data;
      final name = ((data['name'] as String?) ?? (data['fullName'] as String?) ?? '').trim();
      final classId = ((data['class'] as String?) ?? (data['classId'] as String?) ?? '').trim();
      final sectionId = ((data['section'] as String?) ?? (data['sectionId'] as String?) ?? '').trim();
      if (name.isNotEmpty && classId.isNotEmpty && sectionId.isNotEmpty) {
        final key = _nameClassSectionKey(name, classId, sectionId);
        existingByNameKey[key] = doc.id;
      }
    }

    final seenAdmissions = <String>{};
    final seenNameKeys = <String>{};

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
        final cleanedAdmission = r.admissionNo.trim();
        final cleanedName = r.name.trim();
        final cleanedClass = r.classId.trim();
        final cleanedSection = r.sectionId.trim();
        final cleanedGroup = r.groupId.trim();
        final cleanedParentMobile = r.parentMobile.trim();

        final nameKey = _nameClassSectionKey(cleanedName, cleanedClass, cleanedSection);

        if (seenAdmissions.contains(cleanedAdmission)) {
          results.add(StudentCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Duplicate admissionNo in file',
          ));
          continue;
        }

        if (seenNameKeys.contains(nameKey)) {
          results.add(StudentCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Duplicate name/class/section in file',
          ));
          continue;
        }

        seenAdmissions.add(cleanedAdmission);
        seenNameKeys.add(nameKey);

        final existingIdForAdmission = admissionIndex[cleanedAdmission];
        final indexExists = admissionIndex.containsKey(cleanedAdmission);
        final existingIdForName = existingByNameKey[nameKey];

        if (existingIdForAdmission != null &&
            existingIdForName != null &&
            existingIdForAdmission != existingIdForName) {
          throw Exception('AdmissionNo and name/class/section refer to different students');
        }

        final requestedStudentId = r.studentId.trim();
        String? targetStudentId;

        if (requestedStudentId.isNotEmpty) {
          if (existingIdForAdmission != null && existingIdForAdmission != requestedStudentId) {
            throw Exception('AdmissionNo already used by another studentId ($existingIdForAdmission)');
          }
          if (existingIdForName != null && existingIdForName != requestedStudentId) {
            throw Exception('Name/class/section already used by another studentId ($existingIdForName)');
          }
          if (!allowUpdates && existingById.containsKey(requestedStudentId)) {
            results.add(StudentCsvImportRowResult(
              rowNumber: r.rowNumber,
              success: false,
              message: 'Student already exists',
            ));
            continue;
          }
          targetStudentId = requestedStudentId;
        } else if (existingIdForAdmission != null) {
          if (!allowUpdates) {
            results.add(StudentCsvImportRowResult(
              rowNumber: r.rowNumber,
              success: false,
              message: 'AdmissionNo already exists',
            ));
            continue;
          }
          targetStudentId = existingIdForAdmission;
        } else if (existingIdForName != null) {
          if (!allowUpdates) {
            results.add(StudentCsvImportRowResult(
              rowNumber: r.rowNumber,
              success: false,
              message: 'Student already exists for name/class/section',
            ));
            continue;
          }
          targetStudentId = existingIdForName;
        }

        // Resolve student document.
        DocumentReference<Map<String, dynamic>> studentRef;
        DocumentSnapshot<Map<String, dynamic>>? existingStudentSnap;

        if (targetStudentId != null) {
          studentRef = studentsCol.doc(targetStudentId);
          if (existingById.containsKey(targetStudentId)) {
            existingStudentSnap = await studentRef.get();
          } else {
            existingStudentSnap = null;
          }
        } else {
          studentRef = studentsCol.doc();
          existingStudentSnap = null;
        }

        final studentId = studentRef.id;

        // Admission number uniqueness / index handling.
        String? oldAdmission;
        if (existingById.containsKey(studentId)) {
          final oldData = existingById[studentId] ?? const <String, Object?>{};
          oldAdmission = (oldData['admissionNo'] as String?)?.trim();
        } else if (existingStudentSnap != null && existingStudentSnap.exists) {
          final oldData = existingStudentSnap.data() ?? const <String, Object?>{};
          oldAdmission = (oldData['admissionNo'] as String?)?.trim();
        }

        // If admissionNo changed, delete old index (only if it points to this student).
        if (oldAdmission != null && oldAdmission.isNotEmpty && oldAdmission != cleanedAdmission) {
          final oldIndexRef = admissionIndexCol.doc(oldAdmission);
          final oldIndexSnap = await oldIndexRef.get();
          final mapped = (oldIndexSnap.data()?['studentId'] as String?)?.trim();
          if (mapped == studentId) {
            batch.delete(oldIndexRef);
            writesInBatch++;
          }
        }

        // Ensure desired index is set.
        final desiredIndexRef = admissionIndexCol.doc(cleanedAdmission);
        batch.set(
          desiredIndexRef,
          {
            'studentId': studentId,
            'updatedAt': FieldValue.serverTimestamp(),
            if (!indexExists) 'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        writesInBatch++;

        // Upsert student.
        final payload = <String, Object?>{
          'admissionNo': cleanedAdmission,
          'name': cleanedName,
          'fullName': cleanedName, // legacy compatibility
          'group': cleanedGroup,
          'class': cleanedClass,
          'section': cleanedSection,
          'parentMobile': cleanedParentMobile,
          'isActive': r.isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (existingStudentSnap == null || !existingStudentSnap.exists) {
          payload['createdAt'] = FieldValue.serverTimestamp();
        }

        batch.set(studentRef, payload, SetOptions(merge: true));
        writesInBatch++;

        // Ensure / update parent doc.
        final parentRef = parentsCol.doc(cleanedParentMobile);
        final parentSnap = await parentRef.get();
        if (parentSnap.exists) {
          batch.set(
            parentRef,
            {
              'children': FieldValue.arrayUnion([studentId]),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          writesInBatch++;
        } else {
          // Create missing parent with default password (last 4 digits), stored securely.
          final defaultPassword = ParentPasswordHasher.defaultPasswordForMobile(cleanedParentMobile);
          final saltBytes = ParentPasswordHasher.generateSaltBytes();
          final saltB64 = ParentPasswordHasher.saltToBase64(saltBytes);
          final hashB64 = await ParentPasswordHasher.hashPasswordToBase64(
            password: defaultPassword,
            saltBytes: saltBytes,
            version: ParentPasswordHasher.defaultVersion(),
          );

          batch.set(
            parentRef,
            {
              'mobile': cleanedParentMobile,
              'phone': cleanedParentMobile,
              'displayName': 'Parent',
              'role': 'parent',
              'isActive': true,
              'children': [studentId],
              'passwordHash': hashB64,
              'passwordSalt': saltB64,
              'passwordVersion': ParentPasswordHasher.defaultVersion(),
              'failedAttempts': 0,
              'lockUntil': FieldValue.delete(),
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          writesInBatch++;
        }

        // Batch commit guard.
        await commitBatchIfNeeded();

        results.add(StudentCsvImportRowResult(
          rowNumber: r.rowNumber,
          success: true,
          message: 'OK',
          studentId: studentId,
        ));
      } catch (e) {
        results.add(StudentCsvImportRowResult(
          rowNumber: r.rowNumber,
          success: false,
          message: e.toString(),
        ));
      } finally {
        done++;
        onProgress?.call(done, rows.length);
      }
    }

    await commitBatchIfNeeded(force: true);

    final successCount = results.where((x) => x.success).length;
    final failureCount = results.length - successCount;

    return StudentCsvImportReport(
      totalRows: results.length,
      successCount: successCount,
      failureCount: failureCount,
      results: results,
    );
  }
}

String _nameClassSectionKey(String name, String classId, String sectionId) {
  return '${name.trim().toLowerCase()}|${classId.trim().toLowerCase()}|${sectionId.trim().toLowerCase()}';
}
