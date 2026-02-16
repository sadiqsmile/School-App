import 'package:cloud_firestore/cloud_firestore.dart';

class Exam {
  const Exam({
    required this.id,
    required this.examName,
    required this.groupId,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String examName;
  final String groupId; // primary/middle/highschool
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime? createdAt;

  factory Exam.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, Object?>{};

    DateTime? readTs(Object? v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return Exam(
      id: doc.id,
      examName: (data['examName'] as String?)?.trim().isNotEmpty == true
          ? (data['examName'] as String).trim()
          : 'Exam',
      groupId: (data['groupId'] as String?)?.trim() ?? '',
      startDate: readTs(data['startDate']),
      endDate: readTs(data['endDate']),
      isActive: (data['isActive'] ?? true) == true,
      createdAt: readTs(data['createdAt']),
    );
  }
}
