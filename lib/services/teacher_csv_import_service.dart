import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../features/csv/teachers_csv.dart';

class TeacherCsvImportRowResult {
  const TeacherCsvImportRowResult({
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

class TeacherCsvImportReport {
  const TeacherCsvImportReport({
    required this.totalRows,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<TeacherCsvImportRowResult> results;
}

class TeacherCsvImportService {
  TeacherCsvImportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  Future<List<Map<String, Object?>>> exportTeachersForCsv({
    String schoolId = AppConfig.schoolId,
  }) async {
    final snap = await _schoolDoc(schoolId: schoolId)
        .collection('teachers')
        .orderBy('displayName')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      final assignedGroups = (data['assignedGroups'] as List?) ?? const [];
      return <String, Object?>{
        'teacherUid': d.id,
        'displayName': (data['displayName'] as String?) ?? '',
        'email': (data['email'] as String?) ?? '',
        'phone': (data['phone'] as String?) ?? '',
        'assignedGroups': assignedGroups,
        'isActive': (data['isActive'] ?? true) == true,
      };
    }).toList(growable: false);
  }

  Future<TeacherCsvImportReport> importTeachers({
    String schoolId = AppConfig.schoolId,
    required List<TeacherCsvRow> rows,
    bool allowUpdates = true,
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <TeacherCsvImportRowResult>[];

    final school = _schoolDoc(schoolId: schoolId);
    final teachersCol = school.collection('teachers');
    final usersCol = school.collection('users');

    final existingSnap = await teachersCol.get();
    final existingUids = <String>{};
    final existingByEmail = <String, String>{};

    for (final doc in existingSnap.docs) {
      existingUids.add(doc.id);
      final data = doc.data();
      final email = (data['email'] as String?)?.trim().toLowerCase();
      if (email != null && email.isNotEmpty) {
        existingByEmail[email] = doc.id;
      }
    }

    final seenUids = <String>{};
    final seenEmails = <String>{};

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
        final cleanedUid = r.teacherUid.trim();
        final cleanedDisplayName = r.displayName.trim();
        final cleanedEmail = r.email.trim();
        final cleanedEmailKey = cleanedEmail.toLowerCase();
        final cleanedPhone = r.phone.trim();

        if (cleanedUid.isEmpty) {
          results.add(TeacherCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Teacher UID is required',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        if (cleanedDisplayName.isEmpty) {
          results.add(TeacherCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Display name is required',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        if (cleanedEmail.isEmpty) {
          results.add(TeacherCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Email is required',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        if (seenUids.contains(cleanedUid)) {
          results.add(TeacherCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Duplicate teacher UID in file',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        if (cleanedEmailKey.isNotEmpty && seenEmails.contains(cleanedEmailKey)) {
          results.add(TeacherCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Duplicate email in file',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        seenUids.add(cleanedUid);
        if (cleanedEmailKey.isNotEmpty) seenEmails.add(cleanedEmailKey);

        final existingUidForEmail = cleanedEmailKey.isEmpty ? null : existingByEmail[cleanedEmailKey];
        final existsByUid = existingUids.contains(cleanedUid);

        if (existingUidForEmail != null && existingUidForEmail != cleanedUid) {
          results.add(TeacherCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Email already used by another teacher ($existingUidForEmail)',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        if (!allowUpdates && (existsByUid || existingUidForEmail != null)) {
          results.add(TeacherCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Teacher already exists',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        final payload = <String, Object?>{
          'role': 'teacher',
          'displayName': cleanedDisplayName,
          'email': cleanedEmail,
          'assignedGroups': r.assignedGroups,
          'isActive': r.isActive,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (cleanedPhone.isNotEmpty) {
          payload['phone'] = cleanedPhone;
        }

        if (!existsByUid) {
          payload['createdAt'] = FieldValue.serverTimestamp();
        }

        final teacherRef = teachersCol.doc(cleanedUid);
        final userRef = usersCol.doc(cleanedUid);

        batch.set(teacherRef, payload, SetOptions(merge: true));
        batch.set(userRef, payload, SetOptions(merge: true));
        writesInBatch += 2;

        results.add(TeacherCsvImportRowResult(
          rowNumber: r.rowNumber,
          success: true,
          message: existsByUid ? 'Updated' : 'Created',
          teacherUid: cleanedUid,
        ));

        done++;
        onProgress?.call(done, rows.length);

        await commitBatchIfNeeded();
      } catch (e) {
        results.add(TeacherCsvImportRowResult(
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
    final failureCount = results.length - successCount;

    return TeacherCsvImportReport(
      totalRows: results.length,
      successCount: successCount,
      failureCount: failureCount,
      results: results,
    );
  }
}
