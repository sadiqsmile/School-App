# 6) Firestore Security Rules

Rules are already created in the project root:
- `firestore.rules`
- `storage.rules`

## Firestore
- Admin: full access
- Teacher: only assigned class/section
- Parent: only their own children
- All year data is under `/academicYears/{yearId}/schools/{schoolId}/...`

## Storage
- Files stored under: `schools/{schoolId}/...`
- Admin + Teacher can upload
- Signed-in users can read

Next step: paste these rules into Firebase Console:
- Firestore → Rules
- Storage → Rules
