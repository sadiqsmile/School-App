# 10. Exam Module - Complete Implementation Guide

## Overview

The Exam Module provides comprehensive examination management including:
- Admin exam creation and scheduling
- Exam timetable management by class
- Teacher marks entry
- Bulk exam results import (CSV)
- Exam results publishing to parents
- Parent exam results viewing

## Admin Workflow

### Step 1: Create an Exam

1. Navigate to **Admin Dashboard** → **Exams** → Select Group (Primary/Middle/High School)
2. Click **Create New Exam** button
3. Fill in exam details:
   - Exam Name (e.g., "Mid-Term 1", "Final Exam")
   - Description (optional)
   - Start Date
   - End Date
4. Click **Create Exam**
5. Exam is now active and ready for scheduling

### Step 2: Configure Exam Timetable

1. In **Exams** tab, click the exam name
2. Go to **Timetable** tab
3. Click **Edit Timetable** to schedule by class
4. Add schedule items:
   - Select Class and Section
   - Add subjects with start/end times
5. Click **Save Timetable**
6. Repeat for each class

### Step 3: Enter Results (Two Methods)

#### Method A: Bulk CSV Import (Recommended for 50+ students)

1. Go to **Exams** → [Exam Name] → **Publish Results** tab
2. Click **Import Results from CSV** button
3. **Configure Settings:**
   - Max Marks per Subject (e.g., 100)
   - Click **Continue** to select CSV file
4. **Select CSV File:**
   - Choose prepared CSV file
   - System validates file format
   - Shows detected subjects (from CSV headers)
5. **Review Preview:**
   - Shows first 10 student results
   - Displays all detected subjects
   - Check data accuracy
6. **Import:**
   - Click **Import** button
   - Progress bar shows import status
   - System calculates grades automatically
7. **Review Results:**
   - Dialog shows: X successful imports, Y failures
   - Click **OK** to proceed
8. Results are now in database (unpublished by default)

#### Method B: Manual Entry (Via Teacher Interface)

1. Teacher logs in → **Exams** → Select Exam
2. Click **Enter Marks** button
3. For each subject:
   - Select student
   - Enter marks obtained
   - Max marks auto-filled
4. System calculates grade automatically
5. Click **Submit Marks**

### Step 4: Publish Results to Parents

1. Go to **Exams** → [Exam Name] → **Publish Results** tab
2. View all results (imported or manually entered)
3. Select results to publish (checkbox or select all)
4. Click **Publish Results** button
5. Results become visible to parents
6. Parents receive notifications: "Your child's exam results are ready"

---

## CSV Import Format

### Required File Format

**File Type:** CSV (Comma-Separated Values)  
**Encoding:** UTF-8  
**First Row:** Headers (required column names + subject names)

### Column Structure

```
[Required Columns] | [Subject Columns...]
studentId         | English
admissionNo       | Mathematics
studentName       | Science
class             | Social Studies
section           | 
group             | 
```

### Complete Example

```csv
studentId,admissionNo,studentName,class,section,group,English,Mathematics,Science,Social Studies
student-001,ADM001,Chioma Okafor,5,A,primary,85,92,88,90
student-002,ADM002,Kunle Adegoke,5,A,primary,78,85,80,82
student-003,ADM003,Zainab Hassan,5,A,primary,90,88,95,92
student-004,ADM004,Chidi Nwosu,5,A,primary,72,75,70,73
student-005,ADM005,Fatima Yahaya,5,A,primary,88,91,89,87
```

### Column Definitions

| Column | Type | Required | Description |
|--------|------|----------|-------------|
| studentId | Text | Yes | Unique student identifier from system |
| admissionNo | Text | Yes | Admission number |
| studentName | Text | Yes | Full student name |
| class | Text | Yes | Class/Grade (e.g., 5, 6, 7) |
| section | Text | Yes | Section/Stream (e.g., A, B, C) |
| group | Text | Yes | Group (primary/middle/highschool) |
| [Subject Names] | Number | Yes | Obtained marks for each subject |

### Requirements

1. **Required Columns (In Order):**
   - studentId
   - admissionNo
   - studentName
   - class
   - section
   - group

2. **Subject Columns:**
   - Any columns after required fields are treated as subjects
   - Column headers become subject names
   - Marks must be numbers (0-100, or 0-max based on config)
   - Decimal values supported (85.5, 92.25, etc.)

3. **Data Validation:**
   - All required fields must be filled
   - Marks must be numeric
   - Student IDs must exist in the system
   - Duplicate student IDs in same class will overwrite

### Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| "CSV file not found" | Ensure file exists and is readable |
| "Invalid header format" | Check required columns are in exact order |
| "Student not found" | Verify studentId values match system database |
| "Invalid marks" | Ensure marks are numeric (no text or special chars) |
| "Missing required field" | All rows must have values for: studentId, admissionNo, studentName, class, section, group |

---

## Automatic Grade Calculation

Grades are calculated automatically based on percentage:

| Percentage | Grade |
|-----------|-------|
| ≥ 90% | A+ (Outstanding) |
| 80-89% | A (Excellent) |
| 70-79% | B (Good) |
| 60-69% | C (Satisfactory) |
| 50-59% | D (Pass) |
| < 50% | F (Fail) |

**Note:** Percentage calculated as: `(Total Obtained ÷ Total Max) × 100`

### Example Calculation

Max marks = 100

| Student | Marks | Total | Percentage | Grade |
|---------|-------|-------|------------|-------|
| Chioma | 85+92+88+90 = 355 | 400 | 88.75% | A |
| Kunle | 78+85+80+82 = 325 | 400 | 81.25% | A |
| Zainab | 90+88+95+92 = 365 | 400 | 91.25% | A+ |

---

## Parent View of Results

### Before Publishing
- Parents see: "Results being compiled"
- Exam timetable is visible
- Individual marks not shown

### After Publishing
Parents can view:
1. **Exam Details:**
   - Exam name and dates
   - Exam timetable

2. **Child's Results:**
   - Marks by subject
   - Total marks obtained
   - Percentage score
   - Grade letter (A+, A, B, C, D, F)
   - Class performance summary

3. **Data Format:**
```
Exam: Mid-Term 1 (Jan 15 - Jan 20, 2024)

Results for: Chioma Okafor (Class 5A)
────────────────────────────
Subject          | Marks | Max | Grade
────────────────────────────
English          |    85 | 100 | A
Mathematics      |    92 | 100 | A+
Science          |    88 | 100 | A
Social Studies   |    90 | 100 | A+
────────────────────────────
Total            |   355 | 400 | A
Percentage       |  88.75%
────────────────────────────
```

---

## Teacher Marks Entry (Alternative to CSV)

### Process

1. **Login:** Teacher logs in with credentials
2. **Navigate:** Dashboard → Exams → Select Exam
3. **Enter Marks for Each Subject:**
   - Subject name auto-listed
   - For each student in class:
     - Enter marks obtained (0 to max)
     - System auto-calculates percentage
     - Grade auto-assigned
4. **Submit:** Click "Save Marks"
5. **Verify:** Marks saved to Firestore

### UI Elements

- **Student List:** Shows all students in class/section
- **Mark Input:** Text field for numbers (supports decimals)
- **Validation:** Real-time validation during entry
- **Grade Preview:** Shows calculated grade immediately
- **Submit Button:** Saves all marks at once (batch operation)

---

## CSV Export (View/Backup)

**Feature:** Export exam results back to CSV for backup or analysis

### How to Export

1. Go to **Exams** → [Exam Name] → **Publish Results** tab
2. Click **Export Results to CSV** button (if available)
3. Choose format:
   - **Summary:** Class, Section, Student Name, Grade
   - **Detailed:** Includes all marks per subject
4. File downloads as: `exam_results_[examName]_[date].csv`

### Export Format (Detailed)

```csv
studentId,admissionNo,studentName,class,section,English,Mathematics,Science,Social Studies,Total,Percentage,Grade
student-001,ADM001,Chioma Okafor,5,A,85,92,88,90,355,88.75,A
student-002,ADM002,Kunle Adegoke,5,A,78,85,80,82,325,81.25,A
```

---

## Firestore Data Structure

### Collection Path
```
schools/{schoolId}/academicYears/{academicYearId}/exams/{examId}/results/{studentId}
```

### Document Structure

```json
{
  "studentId": "student-001",
  "admissionNo": "ADM001",
  "studentName": "Chioma Okafor",
  "class": "5",
  "section": "A",
  "group": "primary",
  "subjects": [
    {
      "subject": "English",
      "maxMarks": 100,
      "obtainedMarks": 85,
      "percentage": 85.0,
      "grade": "A"
    },
    {
      "subject": "Mathematics",
      "maxMarks": 100,
      "obtainedMarks": 92,
      "percentage": 92.0,
      "grade": "A+"
    }
  ],
  "total": 355,
  "percentage": 88.75,
  "grade": "A",
  "isPublished": false,
  "createdAt": "2024-01-20T10:30:00Z",
  "updatedAt": "2024-01-20T10:30:00Z"
}
```

---

## API Reference

### ExamResultCsvImportService

```dart
// Import exam results from CSV
Future<ExamResultCsvImportReport> importExamResults({
  required String schoolId,
  required String academicYearId,
  required String examId,
  required List<ExamResultCsvRow> rows,
  required List<String> subjects,
  required double maxMarks,
  required Function(int completed, int total)? onProgress,
})

// Export exam results to CSV
Future<String> exportExamResultsToCsv({
  required String schoolId,
  required String academicYearId,
  required String examId,
  required bool includeGrades,
})
```

### ExamResultCsvImportReport

```dart
class ExamResultCsvImportReport {
  final int totalRows;
  final int successCount;
  final List<ExamResultCsvRowError> rowErrors;
  
  int get failureCount => totalRows - successCount;
}
```

---

## Security & Validations

### Validations Performed

✅ **File Format:**
- CSV file structure
- Required header columns present

✅ **Data Type:**
- Student IDs are strings
- Marks are numeric
- Percentages calculated correctly

✅ **Data Existence:**
- Student must exist in database
- Class/Section/Group must match
- Academic year must be active

✅ **Business Rules:**
- Marks cannot exceed max marks (soft validation)
- Duplicate entries overwrite previous
- Results not auto-published (safety)

### Permissions

- **Admin:** Full access (create, import, publish, export)
- **Teacher:** Can enter marks for assigned subjects
- **Parent:** View-only for own child's results
- **Student:** View own results

---

## Troubleshooting

### Import Fails with "Student Not Found"

**Cause:** studentId in CSV doesn't match database

**Solution:**
1. Export student list from Students section
2. Copy exact studentIds to CSV
3. Retry import

### Grades Not Calculated

**Cause:** Max marks not configured or wrong in import dialog

**Solution:**
1. Check max marks input in import dialog
2. Ensure subject marks don't exceed max marks
3. Retry import

### Partial Import Success

**Cause:** Some rows valid, some have errors

**Solution:**
1. Error dialog lists row numbers with issues
2. Fix specific rows in CSV
3. Re-import only fixed rows
4. Or delete import and start over

### Results Not Showing to Parents

**Cause:** Results not published yet

**Solution:**
1. Go to **Publish Results** tab
2. Ensure "isPublished" checkbox is enabled
3. Click **Publish Results**
4. Wait 30 seconds for data sync

---

## Best Practices

### Before Importing

1. **Prepare CSV:**
   - Use template provided
   - Verify all student IDs exist
   - Check for duplicate rows
   - Ensure marks are numeric

2. **Test First:**
   - Import small batch first
   - Review preview carefully
   - Verify grades calculated correctly
   - Then import full batch

3. **Backup:**
   - Take CSV export after import
   - Store backup before publishing
   - Keep original CSV file

### During Import

1. **Monitor Progress:**
   - Don't close app during import
   - Check progress bar
   - Wait for completion

2. **Review Results:**
   - Check error count
   - Look at error rows
   - Fix and re-import if needed

### After Import

1. **Verify:**
   - Check random student results
   - Verify grades calculated correctly
   - Ensure all students imported

2. **Publish Safely:**
   - Review unpublished results first
   - Publish only when confident
   - Can unpublish if needed

3. **Communicate:**
   - Notify parents when results published
   - Check parent access via parent app
   - Answer parent queries

---

## Example Workflow: Importing Mid-Term Results

### Timeline

| Step | Time Est. | Action |
|------|-----------|--------|
| 1 | 5 min | Receive marks from teachers |
| 2 | 10 min | Compile into CSV using template |
| 3 | 5 min | Import via admin dashboard |
| 4 | 2 min | Review preview and errors |
| 5 | 1 min | Confirm import |
| 6 | 2 min | Export as backup |
| 7 | 2 min | Publish to parents |
| 8 | 1 min | Verify parent access |

**Total: ~30 minutes for 500+ students**

### Sample CSV

```csv
studentId,admissionNo,studentName,class,section,group,English,Mathematics,Science,Social Studies
student-001,ADM001,Chioma Okafor,5,A,primary,85,92,88,90
student-002,ADM002,Kunle Adegoke,5,A,primary,78,85,80,82
student-003,ADM003,Zainab Hassan,5,A,primary,90,88,95,92
student-004,ADM004,Chidi Nwosu,5,A,primary,72,75,70,73
student-005,ADM005,Fatima Yahaya,5,A,primary,88,91,89,87
```

### Admin Steps

1. Admin → Exams → [Mid-Term 1] → Publish Results
2. Click **Import Results from CSV**
3. Set Max Marks = 100
4. Select CSV file
5. Review preview (shows 5 students imported)
6. Click **Import**
7. See: "5 successful imports, 0 failures"
8. Click **Export** for backup
9. Click **Publish Results**
10. Parents notified automatically

---

## FAQ

**Q: Can I import partial classes?**  
A: Yes, import only students in CSV. Other students' results unaffected.

**Q: What if marks exceed max marks?**  
A: System allows import but notes warning. Grade calculated on actual marks.

**Q: Can results be unpublished?**  
A: Yes, uncheck published checkbox in results list and click update.

**Q: How many students can be imported at once?**  
A: Up to 10,000 per import (system uses batch operations).

**Q: Can subjects change per exam?**  
A: Yes, each exam can have different subjects based on CSV headers.

**Q: Are grades changeable after import?**  
A: Yes, edit individual result or re-import with new marks.

**Q: Can teachers override admin-imported marks?**  
A: Yes if permissions allow, or admin can re-import to reset.

---

## Support

For issues or questions:
1. Check troubleshooting section above
2. Verify CSV format matches template
3. Review error messages in import dialog
4. Contact support with error screenshot

