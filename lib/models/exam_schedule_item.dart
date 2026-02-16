import 'package:cloud_firestore/cloud_firestore.dart';

class ExamScheduleItem {
  const ExamScheduleItem({
    required this.date,
    required this.subject,
    required this.startTime,
    required this.endTime,
  });

  final DateTime date; // date-only
  final String subject;
  final String startTime; // "HH:mm"
  final String endTime; // "HH:mm"

  Map<String, Object?> toMap() {
    return {
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'subject': subject.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
    };
  }

  factory ExamScheduleItem.fromMap(Map<String, Object?> map) {
    final ts = map['date'];
    final d = ts is Timestamp ? ts.toDate() : DateTime.now();
    return ExamScheduleItem(
      date: DateTime(d.year, d.month, d.day),
      subject: (map['subject'] as String?)?.trim() ?? '',
      startTime: (map['startTime'] as String?)?.trim() ?? '',
      endTime: (map['endTime'] as String?)?.trim() ?? '',
    );
  }
}
