import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../features/csv/classes_sections_csv.dart';

class ClassSectionCsvImportRowResult {
  const ClassSectionCsvImportRowResult({
    required this.rowNumber,
    required this.success,
    required this.message,
  });

  final int rowNumber;
  final bool success;
  final String message;
}

class ClassSectionCsvImportReport {
  const ClassSectionCsvImportReport({
    required this.results,
  });

  final List<ClassSectionCsvImportRowResult> results;

  int get successCount => results.where((r) => r.success).length;
  int get failureCount => results.where((r) => !r.success).length;
}

/// Service to import classes and sections from CSV
class ClassSectionCsvImportService {
  ClassSectionCsvImportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  /// Import classes and sections with progress tracking
  Future<ClassSectionCsvImportReport> importClassSections({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required List<ClassSectionCsvRow> rows,
    void Function(int done, int total)? onProgress,
  }) async {
    final results = <ClassSectionCsvImportRowResult>[];
    final classesProcessed = <String>{};
    final sectionsProcessed = <String>{};

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i + 1;

      try {
        // Create class if not already created in this batch
        if (!classesProcessed.contains(row.classId)) {
          await _schoolDoc(schoolId: schoolId).collection('classes').doc(row.classId).set({
            'className': row.className,
            'sortOrder': row.classOrder,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          classesProcessed.add(row.classId);
        }

        // Create section if not already created in this batch
        final sectionKey = '${row.classId}_${row.sectionId}';
        if (!sectionsProcessed.contains(sectionKey)) {
          await _schoolDoc(schoolId: schoolId).collection('sections').doc(row.sectionId).set({
            'sectionName': row.sectionName,
            'sortOrder': row.sectionOrder,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          sectionsProcessed.add(sectionKey);
        }

        // Create year class-section mapping
        final ycsId = '${row.classId}__${row.sectionId}';
        await _schoolDoc(schoolId: schoolId)
            .collection('academicYears')
            .doc(yearId)
            .collection('classSections')
            .doc(ycsId)
            .set({
          'classId': row.classId,
          'sectionId': row.sectionId,
          'label': '${row.className} - ${row.sectionName}',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        results.add(ClassSectionCsvImportRowResult(
          rowNumber: rowNum,
          success: true,
          message: 'Created ${row.className} - ${row.sectionName}',
        ));

        onProgress?.call(i + 1, rows.length);
      } catch (e) {
        results.add(ClassSectionCsvImportRowResult(
          rowNumber: rowNum,
          success: false,
          message: 'Error: $e',
        ));
      }
    }

    return ClassSectionCsvImportReport(results: results);
  }

  /// Export existing classes and sections to CSV format
  Future<String> exportClassSections({
    String schoolId = AppConfig.schoolId,
    required String yearId,
  }) async {
    final ycsQuery = await _schoolDoc(schoolId: schoolId)
        .collection('academicYears')
        .doc(yearId)
        .collection('classSections')
        .get();

    final rows = <String>[];
    rows.add('classId,className,classOrder,sectionId,sectionName,sectionOrder');

    for (final doc in ycsQuery.docs) {
      final data = doc.data();
      final classId = data['classId'] as String? ?? '';
      final sectionId = data['sectionId'] as String? ?? '';

      // Fetch class details
      final classDoc = await _schoolDoc(schoolId: schoolId).collection('classes').doc(classId).get();
      final classData = classDoc.data() ?? {};
      final className = classData['className'] as String? ?? classId;
      final classOrder = classData['sortOrder'] as int? ?? 0;

      // Fetch section details
      final sectionDoc = await _schoolDoc(schoolId: schoolId).collection('sections').doc(sectionId).get();
      final sectionData = sectionDoc.data() ?? {};
      final sectionName = sectionData['sectionName'] as String? ?? sectionId;
      final sectionOrder = sectionData['sortOrder'] as int? ?? 0;

      rows.add('$classId,$className,$classOrder,$sectionId,$sectionName,$sectionOrder');
    }

    return rows.join('\n');
  }
}
