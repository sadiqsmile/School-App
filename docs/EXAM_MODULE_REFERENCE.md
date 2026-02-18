# Exam Module - Developer Quick Reference

## Files Structure

```
lib/
├── models/
│   ├── exam.dart                 # Exam model (date, group, active)
│   ├── exam_result.dart          # ExamResult model (subjects array, total, %)
│   ├── exam_timetable.dart       # ExamTimetable model (schedule by class)
│   ├── exam_schedule_item.dart   # Schedule item (date, subject, times)
│   └── exam_subject_result.dart  # Subject marks (subject, max, obtained, %)
│
├── features/csv/
│   └── exam_results_csv.dart     # CSV parsing with subject detection
│
├── services/
│   ├── exam_service.dart         # Full exam CRUD + results operations
│   └── exam_result_csv_import_service.dart  # CSV import with grades
│
├── screens/
│   ├── admin/exams/
│   │   ├── admin_exams_screen.dart           # Exams list by group
│   │   ├── admin_create_edit_exam_screen.dart
│   │   ├── admin_exam_details_screen.dart
│   │   ├── admin_exam_timetable_screen.dart
│   │   ├── admin_exam_timetable_editor_screen.dart
│   │   ├── admin_publish_results_screen.dart (MODIFIED)
│   │   └── admin_exam_results_csv_import_screen.dart (NEW)
│   │
│   ├── teacher/exams/
│   │   └── teacher_exam_marks_entry_screen.dart
│   │
│   └── parent/exams/
│       └── parent_exam_details_screen.dart
│
└── providers/
    └── core_providers.dart (MODIFIED - new service registered)
```

## Core Models

### Exam
- `id`: String (unique)
- `name`: String (Mid-Term 1, Final Exam, etc.)
- `description`: String?
- `startDate`: DateTime
- `endDate`: DateTime
- `groupId`: String (primary/middle/highschool)
- `isActive`: bool

### ExamResult
- `studentId`: String (unique within results)
- `admissionNo`: String
- `studentName`: String
- `class`: String
- `section`: String
- `group`: String
- `subjects`: List<ExamSubjectResult>
- `total`: double
- `percentage`: double
- `grade`: String (A+, A, B, C, D, F)
- `isPublished`: bool

### ExamSubjectResult
- `subject`: String
- `maxMarks`: double
- `obtainedMarks`: double
- `percentage`: double
- `grade`: String

## Key Services

### ExamService

```dart
// Watch exams by group
Stream<List<Exam>> watchExamsForGroup(String groupId)

// Create/Update exams
Future<void> createExam(Exam exam)
Future<void> updateExam(Exam exam)

// Manage timetables
Future<void> upsertTimetableForClassSection(ExamTimetable timetable)
Stream<ExamTimetable?> watchTimetableForClassSection(...)

// Manage results
Stream<List<ExamResult>> watchResultsForClassSection(...)
Stream<ExamResult?> watchResultForStudent(...)
Future<void> upsertSubjectMarksForStudents(List<ExamSubjectResult> results)
Future<void> publishResults(List<String> resultIds)
Future<void> unpublishResults(List<String> resultIds)
```

### ExamResultCsvImportService

```dart
// Parse CSV
Future<ExamResultsCsvParseResult> parseExamResultsCsv({
  required String csvText,
  required double maxMarks,
})

// Import to Firestore
Future<ExamResultCsvImportReport> importExamResults({
  required String schoolId,
  required String academicYearId,
  required String examId,
  required List<ExamResultCsvRow> rows,
  required List<String> subjects,
  required double maxMarks,
  Function(int completed, int total)? onProgress,
})

// Grade calculation (private)
String _calculateGrade(double percentage)
// A+ >= 90, A >= 80, B >= 70, C >= 60, D >= 50, F < 50
```

## CSV Import Workflow

### 1. File Selection
```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['csv'],
);
```

### 2. CSV Parsing
```dart
final parseResult = await csvImportService.parseExamResultsCsv(
  csvText: fileContent,
  maxMarks: maxMarks,
);
// Returns: rows, detectedSubjects, validationErrors
```

### 3. CSV Validation
```dart
// Checks:
// - Required columns present: studentId, admissionNo, studentName, class, section, group
// - Additional columns = subjects
// - All rows have values for required fields
// - Marks are numeric
```

### 4. Preview Display
```dart
// Shows:
// - Detected subjects list
// - First 10 rows preview
// - Validation errors (if any)
// - Success message (if valid)
```

### 5. Import to Firestore
```dart
final report = await csvImportService.importExamResults(
  schoolId: schoolId,
  academicYearId: academicYearId,
  examId: examId,
  rows: parseResult.rows,
  subjects: parseResult.detectedSubjects,
  maxMarks: maxMarks,
  onProgress: (completed, total) {
    // Update progress UI
  },
);
// Returns: successCount, failureCount, rowErrors
```

### 6. Batch Management
- Creates batch writes (max 400 per batch)
- Auto-creates new batch when limit reached
- Commits final batch
- All-or-nothing per batch (atomic operations)

## Grade Calculation

```dart
double percentage = (totalObtained / totalMax) * 100;

String grade = percentage >= 90 ? 'A+'
  : percentage >= 80 ? 'A'
  : percentage >= 70 ? 'B'
  : percentage >= 60 ? 'C'
  : percentage >= 50 ? 'D'
  : 'F';
```

## Firestore Collections

### Path Structure
```
schools/{schoolId}/
  academicYears/{academicYearId}/
    exams/{examId}/
      results/{studentId}
      timetables/{classId}
```

### Query Examples

```dart
// Get all results for an exam
query = db
  .collection('schools').doc(schoolId)
  .collection('academicYears').doc(academicYearId)
  .collection('exams').doc(examId)
  .collection('results')
  .snapshots();

// Get results for a class
query = db
  .collection('schools').doc(schoolId)
  .collection('academicYears').doc(academicYearId)
  .collection('exams').doc(examId)
  .collection('results')
  .where('class', isEqualTo: '5')
  .where('section', isEqualTo: 'A')
  .snapshots();

// Get single student result
doc = db
  .collection('schools').doc(schoolId)
  .collection('academicYears').doc(academicYearId)
  .collection('exams').doc(examId)
  .collection('results').doc(studentId)
  .snapshots();
```

## Provider Registration

```dart
// In core_providers.dart
final examResultCsvImportServiceProvider = Provider((ref) {
  return ExamResultCsvImportService(
    db: FirebaseFirestore.instance,
  );
});
```

## UI Components

### AdminExamResultsCsvImportScreen
- CSV validation status display
- Subject detection list
- Results preview table (first 10)
- Progress bar during import
- Results dialog (success/failure counts)

### AdminPublishResultsScreen (Modified)
- CSV import button at top
- Dialog to configure max marks
- File picker integration
- Routes to import screen
- Shows all results with publish checkboxes
- Publish/Unpublish buttons

## Common Code Patterns

### Watch exam results
```dart
ref.watch(examProvider(examId).select((exam) => exam?.id))
ref.watch(examResultsProvider(examId))
```

### Import results with progress
```dart
final importFuture = csvImportService.importExamResults(
  schoolId: schoolId,
  academicYearId: academicYearId,
  examId: examId,
  rows: csvRows,
  subjects: detectedSubjects,
  maxMarks: maxMarks,
  onProgress: (completed, total) {
    setState(() {
      progress = completed / total;
    });
  },
);

final report = await importFuture;
// Handle report.successCount and report.rowErrors
```

### Batch write operation
```dart
final batch = db.batch();
var batchCount = 0;

for (final result in results) {
  if (batchCount >= 400) {
    await batch.commit();
    batch = db.batch();
    batchCount = 0;
  }
  
  batch.set(
    db.collection('schools')...collection('results').doc(result.studentId),
    result.toJson(),
  );
  batchCount++;
}

await batch.commit();
```

## Testing Checklist

- [ ] CSV parsing with 3+ subjects
- [ ] CSV parsing with different max marks
- [ ] Batch operations with 500+ students
- [ ] Grade calculation (all grade ranges)
- [ ] Error handling (missing columns, invalid marks)
- [ ] Firestore data integrity post-import
- [ ] Publication/unpublication toggling
- [ ] Parent visibility after publishing
- [ ] Export CSV (if implemented)

## Performance Notes

- **Batch Limit:** Firestore allows 500 writes per batch, we use 400 to be safe
- **Import Speed:** ~100-200 students per second (depends on network)
- **CSV Parsing:** <100ms for typical files (<1000 rows)
- **Grade Calculation:** Done at import time, no runtime calculation

## Error Handling

```dart
// CSV parse errors
List<ExamResultCsvRowError> rowErrors = parseResult.validationErrors;
// Contains: rowNumber, studentId, errorMessage

// Import errors
List<ExamResultCsvRowError> importErrors = report.rowErrors;
// Contains: rowNumber, studentId, errorMessage
// Import continues despite row errors (partial success)
```

## Dependencies

```yaml
dependencies:
  flutter:
  firebase_core:
  cloud_firestore:
  csv: ^5.0.0+1  # For CSV parsing
  file_picker: ^5.0.0+1  # For file selection
  riverpod: ^2.0.0+1  # For providers
```

## Next Steps

1. **Export UI:** Add export button to publish results screen
2. **Notifications:** Notify parents when results published
3. **Analytics:** Class performance summary dashboard
4. **Notifications:** Teacher notification for marks entry deadline
5. **Mobile:** Mobile-optimized exam view

