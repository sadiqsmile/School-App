# 7) Admin Setup Instructions

You (Admin) will create:
- Admin account (Firebase Auth)
- Teacher accounts (Firebase Auth)
- Parent accounts (Firestore + passwordHash)
- Student identities + yearly assignments

## Step 1: Create Admin
1. Firebase Console → Authentication → Users → **Add user**
2. Create: `admin@school.com` + password
3. Firestore: create doc:
   - `schools/school_001/users/<adminAuthUid>`

Example:
```json
{
  "role": "admin",
  "displayName": "School Admin",
  "email": "admin@school.com",
  "createdAt": "<serverTimestamp>"
}
```

Now admin can log in.

## Step 2: Create Teacher
1. Firebase Auth → Add user (teacher email/password)
2. Firestore:
   - `schools/school_001/users/<teacherUid>` with role = `teacher`
   - `schools/school_001/teachers/<teacherUid>` profile
   - `schools/school_001/teacherAssignments/<teacherUid>`

## Step 3: Create Parent (NO OTP)
Parents are created in Firestore (not in Firebase Auth manually).

Create in Firestore:
- `schools/school_001/parents/<parentUid>`

Fields:
- `phone`, `displayName`, `passwordHash`, `studentIds`, `isActive`

How to set password:
- Default password = last 4 digits of phone
- Store it as a **bcrypt hash** (done by you from an admin tool OR a one-time script)

After you deploy the Cloud Function `parentLogin`, the function will:
- validate password
- create the Firebase Auth user automatically (uid = parentUid)
- create custom token for sign-in

## Step 4: Create Students
Create base student:
- `schools/school_001/students/<studentId>`

Then assign student to class/section in the academic year:
- `academicYears/2025-26/schools/school_001/students/<studentId>`

Set:
- `classSectionId`
- `parentUids`

Also create (optional but helps rules for parent class-section access):
- `academicYears/2025-26/schools/school_001/parentClassSections/<parentUid__classSectionId>`

## Step 5: Create Academic Year + Make it Active
1. Create `academicYears/2025-26` doc
2. Set active year:
   - `schools/school_001/settings/app.activeAcademicYearId = "2025-26"`
