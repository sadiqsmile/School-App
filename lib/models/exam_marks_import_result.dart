/// Result for a single row in exam marks import
class ExamMarksImportRowResult {
  const ExamMarksImportRowResult({
    required this.rowNumber,
    required this.studentId,
    required this.success,
    required this.message,
    this.studentName,
  });

  final int rowNumber;
  final String studentId;
  final bool success;
  final String message;
  final String? studentName;
}

/// Report for exam marks import batch
class ExamMarksImportReport {
  const ExamMarksImportReport({
    required this.totalRows,
    required this.successCount,
    required this.failureCount,
    required this.results,
    required this.subjects,
  });

  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<ExamMarksImportRowResult> results;
  final List<String> subjects; // List of subject IDs
}

/// CSV preview before import
class ExamMarksImportPreview {
  const ExamMarksImportPreview({
    required this.totalRows,
    required this.subjects,
    required this.previewRows,
    required this.validationIssues,
  });

  final int totalRows;
  final List<String> subjects;
  final List<Map<String, Object?>> previewRows; // First 5 rows
  final List<String> validationIssues; // List of issues found
}
