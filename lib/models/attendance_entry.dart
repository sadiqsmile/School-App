import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceEntry {
  AttendanceEntry({
    required this.date,
    required this.status,
  });

  final DateTime date;
  final String status; // present | absent | leave

  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';

  factory AttendanceEntry.fromMap(String docId, Map<String, Object?> map) {
    final rawDate = map['date'];

    DateTime date;
    if (rawDate is Timestamp) {
      date = rawDate.toDate();
    } else if (rawDate is String) {
      date = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      // Fallback: try doc id like yyyyMMdd
      if (docId.length == 8) {
        final y = int.tryParse(docId.substring(0, 4));
        final m = int.tryParse(docId.substring(4, 6));
        final d = int.tryParse(docId.substring(6, 8));
        if (y != null && m != null && d != null) {
          date = DateTime(y, m, d);
        } else {
          date = DateTime.now();
        }
      } else {
        date = DateTime.now();
      }
    }

    return AttendanceEntry(
      date: DateTime(date.year, date.month, date.day),
      status: (map['status'] as String?) ?? 'absent',
    );
  }
}
