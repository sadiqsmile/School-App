import 'package:cloud_firestore/cloud_firestore.dart';

import 'exam_schedule_item.dart';

class ExamTimetable {
  const ExamTimetable({
    required this.classSectionId, // "5-A"
    required this.classId,
    required this.sectionId,
    required this.schedule,
    required this.isPublished,
    this.updatedAt,
  });

  final String classSectionId;
  final String classId;
  final String sectionId;
  final List<ExamScheduleItem> schedule;
  final bool isPublished;
  final DateTime? updatedAt;

  factory ExamTimetable.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, Object?>{};

    final rawSchedule = data['schedule'];
    final list = <ExamScheduleItem>[];
    if (rawSchedule is List) {
      for (final it in rawSchedule) {
        if (it is Map) {
          list.add(ExamScheduleItem.fromMap(it.cast<String, Object?>()));
        }
      }
    }

    DateTime? readTs(Object? v) => v is Timestamp ? v.toDate() : null;

    return ExamTimetable(
      classSectionId: doc.id,
      classId: (data['class'] as String?)?.trim() ?? '',
      sectionId: (data['section'] as String?)?.trim() ?? '',
      schedule: list,
      isPublished: (data['isPublished'] ?? false) == true,
      updatedAt: readTs(data['updatedAt']),
    );
  }
}
