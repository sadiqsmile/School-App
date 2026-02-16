import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../config/app_config.dart';

class HomeworkService {
  HomeworkService({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _schoolDoc({String schoolId = AppConfig.schoolId}) {
    return _firestore.collection('schools').doc(schoolId);
  }

  CollectionReference<Map<String, dynamic>> homeworkCollection({
    String schoolId = AppConfig.schoolId,
    required String yearId,
  }) {
    // Must follow spec:
    // schools/{schoolId}/academicYears/{yearId}/homework/{homeworkId}
    return _schoolDoc(schoolId: schoolId)
        .collection('academicYears')
        .doc(yearId)
        .collection('homework');
  }

  Reference homeworkFileRef({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String homeworkId,
    required String fileName,
  }) {
    final safeName = _sanitizeFileName(fileName);

    // Must follow spec:
    // schools/{schoolId}/academicYears/{yearId}/homework/{homeworkId}/{fileName}
    final path = 'schools/$schoolId/academicYears/$yearId/homework/$homeworkId/$safeName';
    return _storage.ref().child(path);
  }

  String _sanitizeFileName(String input) {
    // Avoid path traversal and illegal storage path segments.
    var v = input.trim();
    if (v.isEmpty) v = 'file';
    v = v.replaceAll(RegExp(r'[\\/]+'), '_');
    v = v.replaceAll(RegExp(r'\s+'), '_');
    return v;
  }

  String detectFileType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif')) {
      return 'image';
    }
    return 'file';
  }

  String? detectContentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchHomework({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    String? classId,
    String? sectionId,
    String? subject,
    String? type,
    bool onlyActive = true,
    DateTime? minPublishDate,
  }) {
    Query<Map<String, dynamic>> q = homeworkCollection(schoolId: schoolId, yearId: yearId);

    if (onlyActive) {
      q = q.where('isActive', isEqualTo: true);
    }
    if (classId != null && classId.trim().isNotEmpty) {
      q = q.where('class', isEqualTo: classId.trim());
    }
    if (sectionId != null && sectionId.trim().isNotEmpty) {
      q = q.where('section', isEqualTo: sectionId.trim());
    }
    if (subject != null && subject.trim().isNotEmpty) {
      q = q.where('subject', isEqualTo: subject.trim());
    }
    if (type != null && type.trim().isNotEmpty) {
      q = q.where('type', isEqualTo: type.trim());
    }

    if (minPublishDate != null) {
      final d = DateTime(minPublishDate.year, minPublishDate.month, minPublishDate.day);
      q = q.where('publishDate', isGreaterThanOrEqualTo: Timestamp.fromDate(d));
    }

    // Default ordering
    q = q.orderBy('publishDate', descending: true);

    return q.snapshots();
  }

  /// Archives old homework/notes by setting `isActive=false`.
  ///
  /// FREE plan friendly alternative to scheduled deletion.
  /// This keeps documents (and attachments) as history, but hides them from UI.
  Future<int> archiveOldHomework({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required DateTime cutoffDate,
    void Function(int done, int total)? onProgress,
  }) async {
    final cutoff = DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day);

    // Query: active + older than cutoff.
    // Note: Firestore may prompt for a composite index on (isActive, publishDate).
    Query<Map<String, dynamic>> q = homeworkCollection(schoolId: schoolId, yearId: yearId)
        .where('isActive', isEqualTo: true)
        .where('publishDate', isLessThan: Timestamp.fromDate(cutoff))
        .orderBy('publishDate', descending: false)
        .limit(200);

    int archived = 0;
    int done = 0;

    // We don't know total without an extra count query (paid feature on some plans),
    // so we report (done, -1) style to the UI.
    while (true) {
      final snap = await q.get();
      if (snap.docs.isEmpty) break;

      final batch = _firestore.batch();
      for (final d in snap.docs) {
        batch.set(
          d.reference,
          {
            'isActive': false,
            'archivedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();

      archived += snap.docs.length;
      done += snap.docs.length;
      onProgress?.call(done, -1);

      final last = snap.docs.last;
      q = homeworkCollection(schoolId: schoolId, yearId: yearId)
          .where('isActive', isEqualTo: true)
          .where('publishDate', isLessThan: Timestamp.fromDate(cutoff))
          .orderBy('publishDate', descending: false)
          .startAfterDocument(last)
          .limit(200);
    }

    return archived;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOldActiveHomework({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required DateTime cutoffDate,
    int limit = 50,
  }) {
    final cutoff = DateTime(cutoffDate.year, cutoffDate.month, cutoffDate.day);

    Query<Map<String, dynamic>> q = homeworkCollection(schoolId: schoolId, yearId: yearId)
        .where('isActive', isEqualTo: true)
        .where('publishDate', isLessThan: Timestamp.fromDate(cutoff))
        .orderBy('publishDate', descending: true)
        .limit(limit);

    return q.snapshots();
  }

  Future<void> setHomeworkActive({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String homeworkId,
    required bool isActive,
  }) {
    return homeworkCollection(schoolId: schoolId, yearId: yearId)
        .doc(homeworkId)
        .set({'isActive': isActive}, SetOptions(merge: true));
  }

  /// Creates a homework/notes document and uploads all attachments to Firebase Storage.
  ///
  /// Attachments must be provided as bytes for Android/Web compatibility.
  Future<String> createHomeworkWithUploads({
    String schoolId = AppConfig.schoolId,
    required String yearId,
    required String title,
    required String description,
    required String classId,
    required String sectionId,
    required String subject,
    required String type, // "homework" | "notes"
    required DateTime publishDate,
    required String createdByUid,
    required String createdByName,
    required bool isActive,
    required List<HomeworkUploadFile> files,
    void Function(HomeworkUploadProgress progress)? onProgress,
  }) async {
    final cleanedTitle = title.trim();
    final cleanedDesc = description.trim();
    final cleanedClass = classId.trim();
    final cleanedSection = sectionId.trim();
    final cleanedSubject = subject.trim();
    final cleanedType = type.trim();

    if (cleanedTitle.isEmpty) throw Exception('Title is required');
    if (cleanedClass.isEmpty) throw Exception('Class is required');
    if (cleanedSection.isEmpty) throw Exception('Section is required');
    if (cleanedSubject.isEmpty) throw Exception('Subject is required');
    if (cleanedType != 'homework' && cleanedType != 'notes') {
      throw Exception('Invalid type');
    }

    final col = homeworkCollection(schoolId: schoolId, yearId: yearId);
    final docRef = col.doc();
    final homeworkId = docRef.id;

    onProgress?.call(const HomeworkUploadProgress(stage: HomeworkUploadStage.preparing));

    final attachments = <Map<String, Object?>>[];

    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final fileName = f.fileName.trim().isEmpty ? 'file_${i + 1}' : f.fileName.trim();
      final ref = homeworkFileRef(
        schoolId: schoolId,
        yearId: yearId,
        homeworkId: homeworkId,
        fileName: fileName,
      );

      final metadata = SettableMetadata(contentType: detectContentType(fileName));

      final uploadTask = ref.putData(f.bytes, metadata);

      uploadTask.snapshotEvents.listen((snap) {
        final total = snap.totalBytes;
        final done = snap.bytesTransferred;
        final frac = total == 0 ? 0.0 : (done / total);
        onProgress?.call(
          HomeworkUploadProgress(
            stage: HomeworkUploadStage.uploading,
            fileIndex: i,
            fileCount: files.length,
            fileName: fileName,
            progress: frac.clamp(0.0, 1.0),
          ),
        );
      });

      await uploadTask;
      final url = await ref.getDownloadURL();

      attachments.add({
        'fileName': fileName,
        'fileUrl': url,
        'fileType': detectFileType(fileName),
        'storagePath': ref.fullPath,
        'size': f.size,
      });
    }

    onProgress?.call(const HomeworkUploadProgress(stage: HomeworkUploadStage.saving));

    await docRef.set({
      'title': cleanedTitle,
      'description': cleanedDesc,
      'class': cleanedClass,
      'section': cleanedSection,
      'subject': cleanedSubject,
      'type': cleanedType,
      'publishDate': Timestamp.fromDate(publishDate),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'attachments': attachments,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    });

    onProgress?.call(const HomeworkUploadProgress(stage: HomeworkUploadStage.done));
    return homeworkId;
  }
}

class HomeworkUploadFile {
  HomeworkUploadFile({
    required this.fileName,
    required this.bytes,
    required this.size,
  });

  final String fileName;
  final Uint8List bytes;
  final int size;
}

enum HomeworkUploadStage {
  preparing,
  uploading,
  saving,
  done,
}

class HomeworkUploadProgress {
  const HomeworkUploadProgress({
    required this.stage,
    this.fileIndex,
    this.fileCount,
    this.fileName,
    this.progress,
  });

  final HomeworkUploadStage stage;
  final int? fileIndex;
  final int? fileCount;
  final String? fileName;
  final double? progress;
}
