class StudentYear {
  StudentYear({
    required this.studentId,
    required this.classSectionId,
    required this.rollNo,
    required this.parentUids,
  });

  final String studentId;
  final String classSectionId;
  final int? rollNo;
  final List<String> parentUids;

  factory StudentYear.fromMap(String studentId, Map<String, Object?> map) {
    return StudentYear(
      studentId: studentId,
      classSectionId: (map['classSectionId'] as String?) ?? 'unknown',
      rollNo: (map['rollNo'] as num?)?.toInt(),
      parentUids: ((map['parentUids'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}
