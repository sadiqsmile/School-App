# 5) Firestore Database Structure (Full)

Goal: keep **users** permanent, but keep **year data** under:

`/academicYears/{yearId}/schools/{schoolId}/...`

So you can delete one year safely.

---

## Top-level collections

### 1) `schools/{schoolId}`
This stores master data that does NOT change yearly.

#### A) `schools/{schoolId}/settings/app`
Example:
```json
{
  "activeAcademicYearId": "2025-26",
  "schoolName": "ABC Public School",
  "createdAt": "<serverTimestamp>"
}
```

#### B) `schools/{schoolId}/users/{uid}` (role profile for every signed-in user)
Used for routing + security rules.

Example (Admin):
```json
{
  "role": "admin",
  "displayName": "School Admin",
  "email": "admin@school.com",
  "phone": null,
  "createdAt": "<serverTimestamp>"
}
```

Example (Teacher):
```json
{
  "role": "teacher",
  "displayName": "Mr. Khan",
  "email": "khan@school.com",
  "phone": null,
  "createdAt": "<serverTimestamp>"
}
```

Example (Parent):
```json
{
  "role": "parent",
  "displayName": "Parent of Ali",
  "email": null,
  "phone": "+923001112233",
  "createdAt": "<serverTimestamp>"
}
```

#### C) `schools/{schoolId}/parents/{parentUid}`
Stores login + linked students.

Recommended fields:
```json
{
  "phone": "+923001112233",
  "displayName": "Mrs. Ali",
  "passwordHash": "<bcrypt hash>",
  "studentIds": ["stu_0001"],
  "createdAt": "<serverTimestamp>",
  "isActive": true
}
```

#### D) `schools/{schoolId}/teachers/{teacherUid}`
```json
{
  "displayName": "Mr. Khan",
  "email": "khan@school.com",
  "phone": "+923009998877",
  "employeeNo": "T-102",
  "createdAt": "<serverTimestamp>",
  "isActive": true
}
```

#### E) `schools/{schoolId}/students/{studentId}` (base student identity)
Student identity stays across years.

```json
{
  "fullName": "Ali Ahmed",
  "admissionNo": "A-1001",
  "photoUrl": null,
  "createdAt": "<serverTimestamp>",
  "isActive": true
}
```

#### F) `schools/{schoolId}/classes/{classId}`
```json
{
  "name": "Class 5",
  "sortOrder": 5
}
```

#### G) `schools/{schoolId}/sections/{sectionId}`
```json
{
  "name": "A",
  "sortOrder": 1
}
```

#### H) `schools/{schoolId}/teacherAssignments/{teacherUid}`
Used by security rules to restrict teacher access.

```json
{
  "classSectionIds": ["class5_A"],
  "updatedAt": "<serverTimestamp>"
}
```

#### I) `schools/{schoolId}/users/{uid}/fcmTokens/{token}`
```json
{
  "token": "<fcm token>",
  "platform": "flutter",
  "createdAt": "<serverTimestamp>"
}
```

---

## Academic Year data

### 2) `academicYears/{yearId}`
Example document:
```json
{
  "label": "2025-26",
  "startsOn": "2025-04-01",
  "endsOn": "2026-03-31",
  "createdAt": "<serverTimestamp>"
}
```

All year data is under:

`academicYears/{yearId}/schools/{schoolId}/...`

### A) `academicYears/{yearId}/schools/{schoolId}/classSections/{classSectionId}`
Represents a class+section for a year.

```json
{
  "classId": "class5",
  "sectionId": "A",
  "label": "Class 5 - A"
}
```

### B) `academicYears/{yearId}/schools/{schoolId}/students/{studentId}` (year snapshot)
This is where you assign class/section and parents for the year.

```json
{
  "studentId": "stu_0001",
  "classSectionId": "class5_A",
  "rollNo": 12,
  "parentUids": ["parentUid_001"],
  "updatedAt": "<serverTimestamp>"
}
```

### C) Attendance
Option 1 (simple, per student per date):

`academicYears/{yearId}/schools/{schoolId}/students/{studentId}/attendance/{yyyyMMdd}`

Example (`20260215`):
```json
{
  "date": "2026-02-15",
  "status": "present",
  "markedBy": "teacherUid_01",
  "markedAt": "<serverTimestamp>"
}
```

### D) Fees
`academicYears/{yearId}/schools/{schoolId}/students/{studentId}/fees/{invoiceId}`

```json
{
  "invoiceId": "inv_0001",
  "title": "Tuition Fee Feb",
  "amount": 5000,
  "status": "paid",
  "paidAt": "<serverTimestamp>",
  "receiptUrls": ["https://..."]
}
```

### E) Homework / Notes
Store per class-section:

`academicYears/{yearId}/schools/{schoolId}/classSections/{classSectionId}/homework/{homeworkId}`

```json
{
  "title": "Math Worksheet 1",
  "description": "Solve Q1-10",
  "fileUrls": ["https://..."],
  "fileTypes": ["pdf"],
  "assignedOn": "2026-02-15",
  "createdBy": "teacherUid_01",
  "createdAt": "<serverTimestamp>"
}
```

### F) Timetable
`academicYears/{yearId}/schools/{schoolId}/classSections/{classSectionId}/timetable/{itemId}`

```json
{
  "day": "monday",
  "periodNo": 1,
  "subject": "Math",
  "startsAt": "09:00",
  "endsAt": "09:40",
  "teacherUid": "teacherUid_01"
}
```

### G) Exams
`academicYears/{yearId}/schools/{schoolId}/exams/{examId}`

```json
{
  "name": "Mid Term",
  "startsOn": "2026-03-01",
  "endsOn": "2026-03-10",
  "isPublished": true,
  "createdAt": "<serverTimestamp>"
}
```

### H) Marks
Option 1 (per student per exam+subject):

`academicYears/{yearId}/schools/{schoolId}/students/{studentId}/marks/{markId}`

```json
{
  "examId": "exam_mid_2026",
  "subject": "Math",
  "maxMarks": 100,
  "obtained": 85,
  "enteredBy": "teacherUid_01",
  "enteredAt": "<serverTimestamp>"
}
```

### I) Notifications
`academicYears/{yearId}/schools/{schoolId}/notifications/{notificationId}`

```json
{
  "title": "School Holiday",
  "body": "Tomorrow is a holiday due to weather.",
  "audience": "school",
  "classSectionId": null,
  "createdBy": "adminUid_01",
  "createdAt": "<serverTimestamp>"
}
```

### J) Helper mapping for parent access (optional but useful)
`academicYears/{yearId}/schools/{schoolId}/parentClassSections/{parentUid__classSectionId}`

```json
{
  "parentUid": "parentUid_001",
  "classSectionId": "class5_A",
  "createdAt": "<serverTimestamp>"
}
```

---

## Where the requested collections appear
You asked for these names: schools, users, roles, students, parents, teachers, classes, sections, attendance, fees, homework, timetable, exams, marks, notifications.

In this design:
- `schools` is a top-level collection
- `users/parents/teachers/students/classes/sections` are under `schools/{schoolId}/...`
- `attendance/fees/homework/timetable/exams/marks/notifications` are under `academicYears/{yearId}/schools/{schoolId}/...`
- `roles` is stored as a field: `schools/{schoolId}/users/{uid}.role`
