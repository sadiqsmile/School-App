import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../features/csv/parents_csv.dart';
import 'parent_password_hasher.dart';

class ParentCsvImportRowResult {
  const ParentCsvImportRowResult({
    required this.rowNumber,
    required this.success,
    required this.message,
    this.mobile,
  });

  final int rowNumber;
  final bool success;
  final String message;
  final String? mobile;
}

class ParentCsvImportReport {
  const ParentCsvImportReport({
    required this.totalRows,
    required this.successCount,
    required this.failureCount,
    required this.results,
  });

  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<ParentCsvImportRowResult> results;
}

class ParentCsvImportService {
  ParentCsvImportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  Future<List<Map<String, Object?>>> exportParentsForCsv({
    String schoolId = AppConfig.schoolId,
  }) async {
    final snap = await _schoolDoc(schoolId: schoolId)
        .collection('parents')
        .orderBy('displayName')
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      final children = (data['children'] as List?) ?? const [];
      return <String, Object?>{
        'mobile': d.id,
        'displayName': (data['displayName'] as String?) ?? '',
        'childrenIds': children,
        'isActive': (data['isActive'] ?? true) == true,
      };
    }).toList(growable: false);
  }

  Future<ParentCsvImportReport> importParents({
    String schoolId = AppConfig.schoolId,
    required List<ParentCsvRow> rows,
    bool allowUpdates = true,
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <ParentCsvImportRowResult>[];

    final school = _schoolDoc(schoolId: schoolId);
    final parentsCol = school.collection('parents');

    final existingSnap = await parentsCol.get();
    final existingMobiles = existingSnap.docs.map((d) => d.id.trim()).toSet();
    final seenMobiles = <String>{};

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
        final cleanedMobile = r.mobile.trim();
        final cleanedDisplayName = r.displayName.trim();

        if (seenMobiles.contains(cleanedMobile)) {
          results.add(ParentCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Duplicate mobile in file',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        seenMobiles.add(cleanedMobile);

        if (cleanedMobile.isEmpty) {
          results.add(ParentCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Mobile number is required',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        if (cleanedDisplayName.isEmpty) {
          results.add(ParentCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Display name is required',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        final exists = existingMobiles.contains(cleanedMobile);
        if (exists && !allowUpdates) {
          results.add(ParentCsvImportRowResult(
            rowNumber: r.rowNumber,
            success: false,
            message: 'Parent already exists',
          ));
          done++;
          onProgress?.call(done, rows.length);
          continue;
        }

        // Generate password hash and salt
        final defaultPassword = ParentPasswordHasher.defaultPasswordForMobile(cleanedMobile);
        final saltBytes = ParentPasswordHasher.generateSaltBytes();
        final saltB64 = ParentPasswordHasher.saltToBase64(saltBytes);
        final hashB64 = await ParentPasswordHasher.hashPasswordToBase64(
          password: defaultPassword,
          saltBytes: saltBytes,
          version: ParentPasswordHasher.defaultVersion(),
        );

        final docRef = parentsCol.doc(cleanedMobile);

        batch.set(
          docRef,
          {
            'mobile': cleanedMobile,
            'phone': cleanedMobile,
            'displayName': cleanedDisplayName,
            'passwordHash': hashB64,
            'passwordSalt': saltB64,
            'passwordVersion': ParentPasswordHasher.defaultVersion(),
            'role': 'parent',
            'isActive': r.isActive,
            'children': r.childrenIds,
            'failedAttempts': 0,
            if (!exists) 'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        writesInBatch++;

        results.add(ParentCsvImportRowResult(
          rowNumber: r.rowNumber,
          success: true,
          message: 'OK',
          mobile: cleanedMobile,
        ));

        done++;
        onProgress?.call(done, rows.length);

        await commitBatchIfNeeded();
      } catch (e) {
        results.add(ParentCsvImportRowResult(
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

    return ParentCsvImportReport(
      totalRows: rows.length,
      successCount: successCount,
      failureCount: failureCount,
      results: results,
    );
  }
}
