class ExamSubjectResult {
  const ExamSubjectResult({
    required this.subject,
    required this.maxMarks,
    required this.obtainedMarks,
  });

  final String subject;
  final double maxMarks;
  final double obtainedMarks;

  Map<String, Object?> toMap() {
    return {
      'subject': subject.trim(),
      'maxMarks': maxMarks,
      'obtainedMarks': obtainedMarks,
    };
  }

  factory ExamSubjectResult.fromMap(Map<String, Object?> map) {
    double readNum(Object? v) {
      if (v is num) return v.toDouble();
      return 0;
    }

    return ExamSubjectResult(
      subject: (map['subject'] as String?)?.trim() ?? '',
      maxMarks: readNum(map['maxMarks']),
      obtainedMarks: readNum(map['obtainedMarks']),
    );
  }
}
