# 2) Firebase Setup Steps (Windows + VS Code)

## A) Create Firebase Project
1. Go to Firebase Console → **Add project**.
2. Project name: `school_app` (any name is fine).
3. Disable/Enable Google Analytics (optional).

## B) Create Firebase Apps
### 1) Android
1. Firebase Console → Project → **Add app** → Android.
2. Android package name: open `android/app/build.gradle.kts` and use the `applicationId`.
3. Download `google-services.json` → place into `android/app/`.

### 2) Web
1. Firebase Console → Project → **Add app** → Web.
2. App nickname: `school_app_web`.
3. **Also check**: “Set up Firebase Hosting” (optional now).

## C) Enable Firebase Authentication
Firebase Console → **Authentication** → **Sign-in method**
- Enable **Email/Password**

Teacher/Admin login uses Email/Password directly.

Parent login uses Cloud Functions + Custom Token (still uses Firebase Auth behind the scenes, but NO phone OTP/SMS).

## D) Enable Firestore + Storage
1. Firestore Database → **Create database** (production mode recommended).
2. Storage → **Get started**.

## E) Enable Cloud Messaging (FCM)
1. Project settings → **Cloud Messaging**.
2. For Android, FCM works after you add `google-services.json`.
3. Web push notifications are trickier on iPhone Safari (PWA). You can still store notifications in Firestore and show them in-app; web push support depends on iOS/Safari version.

## F) Install FlutterFire CLI + Configure
In PowerShell:
1. Install FlutterFire CLI:
   - `dart pub global activate flutterfire_cli`
2. Login to Firebase:
   - `firebase login`
3. In your project folder run:
   - `flutterfire configure`

This generates `lib/firebase_options.dart` (replaces the placeholder).

## G) Parent Login (No OTP/SMS) — REQUIRED BACKEND
Important: If parents are not signed in, Firestore Security Rules cannot protect data.
So we do:
- Store parent accounts in Firestore (mobile + password hash)
- Call a **Cloud Function** to validate login
- Cloud Function returns a **Firebase Auth custom token**
- App calls `signInWithCustomToken(token)`

Cloud Functions setup:
1. Install Firebase CLI: https://firebase.google.com/docs/cli
2. In the project root:
   - `firebase init functions`
   - Choose **JavaScript** (beginner-friendly)
   - Choose **Use ESLint?** (optional)
3. Replace `functions/index.js` with the code from `firebase_backend/functions/index.js` in this repo.
4. In `functions` folder:
   - `npm install bcryptjs`
5. Deploy:
   - `firebase deploy --only functions`

After this, Parent login works from the app.
