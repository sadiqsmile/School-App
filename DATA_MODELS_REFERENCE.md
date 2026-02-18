# 📊 Data Models Reference

## Parents Import/Export

### Firestore Structure
```
schools/{schoolId}/parents/{mobile}
├── mobile: "+234801234567"           # Document ID
├── displayName: "Mrs. Johnson"
├── phone: "+234801234567"            # Metadata
├── passwordHash: "hash_string"        # Secure hash (PBKDF2)
├── passwordSalt: "salt_base64"
├── passwordVersion: 1
├── role: "parent"
├── isActive: true
├── children: ["student-123", "student-124"]  # Linked student IDs
├── failedAttempts: 0
├── createdAt: Timestamp
└── updatedAt: Timestamp
```

### CSV Row Model
```dart
class ParentCsvRow {
  final String mobile;              // Required
  final String displayName;         // Required
  final List<String> childrenIds;   // Optional, comma-separated
  final bool isActive;              // Default: true
  final int rowNumber;              // For error reporting
}
```

### Import Report
```dart
class ParentCsvImportReport {
  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<ParentCsvImportRowResult> results;  // One per row
}

class ParentCsvImportRowResult {
  final int rowNumber;
  final bool success;
  final String message;
  final String? mobile;
}
```

### Export Format
```dart
List<Map<String, Object?>> {
  'mobile': '+234801234567',
  'displayName': 'Mrs. Johnson',
  'childrenIds': ['student-123', 'student-124'],  // Array of IDs
  'isActive': true,
}
```

---

## Teacher Assignments Import/Export

### Firestore Structure
```
schools/{schoolId}/teacherAssignments/{teacherUid}
├── teacherUid: "teacher-uid-001"
├── classSectionIds: [
│   "classSection-1a",
│   "classSection-1b",
│   "classSection-2a"
│ ]
└── updatedAt: Timestamp
```

### CSV Row Model
```dart
class TeacherAssignmentCsvRow {
  final String teacherUid;              // Required
  final List<String> classSectionIds;   // Required, comma-separated
  final int rowNumber;                  // For error reporting
}
```

### Import Report
```dart
class TeacherAssignmentCsvImportReport {
  final int totalRows;
  final int successCount;
  final int failureCount;
  final List<TeacherAssignmentCsvImportRowResult> results;
}

class TeacherAssignmentCsvImportRowResult {
  final int rowNumber;
  final bool success;
  final String message;
  final String? teacherUid;
}
```

### Export Format
```dart
List<Map<String, Object?>> {
  'teacherUid': 'teacher-uid-001',
  'classSectionIds': [
    'classSection-1a',
    'classSection-1b',
    'classSection-2a'
  ],
}
```

---

## CSV Parse Results

### Parents CSV Parse Result
```dart
class ParentsCsvParseResult {
  final List<ParentCsvRow> rows;        // Valid rows
  final List<ParentsCsvParseIssue> issues;  // Validation errors
}

class ParentsCsvParseIssue {
  final int rowNumber;      // 1-based (including header)
  final String message;     // Error description
}
```

### Teacher Assignments CSV Parse Result
```dart
class TeacherAssignmentsCsvParseResult {
  final List<TeacherAssignmentCsvRow> rows;
  final List<TeacherAssignmentsCsvParseIssue> issues;
}

class TeacherAssignmentsCsvParseIssue {
  final int rowNumber;
  final String message;
}
```

---

## Validation Rules

### Parents CSV Field Validation
| Field | Required | Format | Notes |
|-------|----------|--------|-------|
| `mobile` | ✅ Yes | Any string | Must be unique per school |
| `displayName` | ✅ Yes | Any string (1-255 chars) | Parent's name |
| `childrenIds` | ❌ No | Comma-separated student IDs | Links to existing students |
| `isActive` | ❌ No | "true"/"false"/"1"/"0"/etc | Default: true |

### Teacher Assignments CSV Validation
| Field | Required | Format | Notes |
|-------|----------|--------|-------|
| `teacherUid` | ✅ Yes | Firebase Auth UID | Must exist as teacher |
| `classSectionIds` | ✅ Yes | Comma-separated IDs | Must exist in year |

---

## Import Modes

### Parents Import
- **Always**: Creates new parent or updates existing
- **Password**: Always auto-generated as last 4 digits of mobile
- **Children**: Links are set (replaces existing links)

### Teacher Assignments Import
- **Replace Mode** (default):
  ```dart
  // Old assignments are completely replaced
  classSectionIds: ['new-1', 'new-2']
  ```

- **Merge Mode**:
  ```dart
  // New assignments are added to existing ones
  classSectionIds: FieldValue.arrayUnion(['new-1', 'new-2'])
  ```

---

## Error Handling Examples

### Validation Errors (Parent Import)
```
Row 2: Mobile is required
Row 3: Display name is required
Row 5: Invalid mobile format (too short)
```

### Validation Errors (Teacher Assignments Import)
```
Row 1: Missing required column: teacherUid
Row 2: Teacher UID is required
Row 3: At least one class/section ID is required
```

### Runtime Errors (During Import)
```
Row 15: Error: Firestore operation failed
Row 20: Error: Invalid reference to student ID
```

---

## Batch Processing

### Firestore Batch Operations
```dart
// Parents Import
const maxWritesPerBatch = 400;
WriteBatch batch = firestore.batch();

for (final row in rows) {
  batch.set(docRef, data, SetOptions(merge: true));
  writesInBatch++;
  
  if (writesInBatch >= maxWritesPerBatch) {
    await batch.commit();
    batch = firestore.batch();
    writesInBatch = 0;
  }
}

await batch.commit(); // Final batch
```

### Progress Tracking
```dart
importParents(
  rows: csvRows,
  onProgress: (done, total) {
    // done = 15, total = 100
    // Progress = 15%
    progressBar.value = done / total;
  },
)
```

---

## Type Conversions

### String to Bool
```dart
bool parseBool(String raw) {
  final v = raw.trim().toLowerCase();
  return v == 'true' || v == '1' || v == 'yes' || v == 'y';
}

// Examples:
parseBool('true')   // ✓ true
parseBool('True')   // ✓ true
parseBool('1')      // ✓ true
parseBool('yes')    // ✓ true
parseBool('false')  // ✗ false
parseBool('0')      // ✗ false
parseBool('')       // ✗ false
```

### Comma-Separated to List
```dart
List<String> parseList(String raw) {
  return raw
    .split(',')
    .map((item) => item.trim())
    .where((item) => item.isNotEmpty)
    .toList();
}

// Examples:
parseList('id-1, id-2, id-3')  // ['id-1', 'id-2', 'id-3']
parseList('single')             // ['single']
parseList('')                   // []
```

---

## CSV Column Headers

### Parameters (case-insensitive):
```
Parents: mobile, displayName, childrenIds, isActive
Teachers: teacherUid, classSectionIds
```

### Header Validation
```dart
// Tries all these variations (case-insensitive):
'mobile' | 'Mobile' | 'MOBILE' | 'Mobile Number'

// Returns error if header missing
Missing required column: teacherUid
```

---

## Constants

### Service Defaults
```dart
class ParentPasswordHasher {
  static const int defaultVersion = 1;
  
  static String defaultPasswordForMobile(String mobile) {
    // Returns last 4 digits
    return mobile.substring(mobile.length - 4);
  }
}
```

### Batch Limits
```dart
const int maxWritesPerBatch = 400;  // Firestore limit
```

