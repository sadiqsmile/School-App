class AttendancePAEntry {
  AttendancePAEntry({
    required this.dateId,
    required this.date,
    required this.status,
  });

  /// Firestore day document id (yyyy-MM-dd)
  final String dateId;

  final DateTime date;

  /// "P" | "A" | null (unmarked / missing)
  final String? status;
}
