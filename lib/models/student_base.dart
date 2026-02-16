class StudentBase {
  StudentBase({
    required this.id,
    required this.fullName,
    required this.admissionNo,
    required this.photoUrl,
    this.classId,
    this.sectionId,
    this.groupId,
  });

  final String id;
  final String fullName;
  final String? admissionNo;
  final String? photoUrl;
  final String? classId;
  final String? sectionId;
  final String? groupId;

  factory StudentBase.fromMap(String id, Map<String, Object?> map) {
    // Current Firestore spec uses `name`, but older docs/screens used `fullName`.
    // Support both to avoid breaking existing data.
    final name = (map['name'] as String?)?.trim();
    final legacy = (map['fullName'] as String?)?.trim();

    final classId = (map['class'] as String?)?.trim() ?? (map['classId'] as String?)?.trim();
    final sectionId = (map['section'] as String?)?.trim() ?? (map['sectionId'] as String?)?.trim();
    final groupId = (map['group'] as String?)?.trim() ?? (map['groupId'] as String?)?.trim();

    return StudentBase(
      id: id,
      fullName: (name == null || name.isEmpty)
          ? ((legacy == null || legacy.isEmpty) ? 'Student' : legacy)
          : name,
      admissionNo: map['admissionNo'] as String?,
      photoUrl: map['photoUrl'] as String?,
      classId: (classId == null || classId.isEmpty) ? null : classId,
      sectionId: (sectionId == null || sectionId.isEmpty) ? null : sectionId,
      groupId: (groupId == null || groupId.isEmpty) ? null : groupId,
    );
  }
}
