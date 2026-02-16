# Push Notifications (FCM) Setup — No Cloud Functions

This app uses **Firestore + FCM** only (no Cloud Functions).

What’s implemented in code (so far):
- **Token registration** into Firestore on dashboards
- **Notification Inbox** screen (Admin/Teacher/Parent) reading from `schools/{schoolId}/notifications`
- Foreground notification display on Android via `flutter_local_notifications`

> Next step (later): add “Send Notification” UI + delivery strategy (topics or server). Without any server component, secure in-app sending is limited.

---

## 1) Packages
Already added to `pubspec.yaml`:
- `firebase_messaging`
- `flutter_local_notifications`
- `crypto`

Run:
- `flutter pub get`

---

## 2) Android setup
### 2.1 Add notification permission (Android 13+)
In `android/app/src/main/AndroidManifest.xml` add:
- `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />`

### 2.2 Ensure Firebase is configured
You already have `android/app/google-services.json`.

---

## 3) Web setup (required for browser push)
### 3.1 Generate VAPID key
Firebase Console → **Project Settings** → **Cloud Messaging** → **Web configuration**:
- Generate / copy the **Web Push certificate** (VAPID key)

### 3.2 Add Service Worker
This repo now includes:
- `web/firebase-messaging-sw.js`

Edit it and replace the `firebase.initializeApp({...})` config with your Web config.

### 3.3 Register the service worker
In `web/index.html`, ensure the service worker is registered (if not already).
Add something like this near the end of body:

```html
<script>
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('firebase-messaging-sw.js');
    });
  }
</script>
```

### 3.4 Pass the VAPID key to token registration
In these files, there is a TODO to provide:
- `vapidKey: 'YOUR_WEB_PUSH_VAPID_KEY'`

Files:
- `lib/screens/dashboards/teacher_dashboard.dart`
- `lib/screens/dashboards/parent_dashboard.dart`
- `lib/screens/dashboards/admin_dashboard.dart`

---

## 4) Firestore structure
### 4.1 Tokens
On login/session, the app saves token docs:

- Parents:
  - `schools/school_001/parents/{mobile}/tokens/{tokenId}`

- Teachers/Admin:
  - `schools/school_001/users/{uid}/tokens/{tokenId}`

Doc fields:
- `token`
- `platform` (`android` / `web` / etc)
- `updatedAt`

> Note: parent login is not FirebaseAuth in this app, so **Firestore Rules may block token writes** unless rules are relaxed.

### 4.2 Notifications (inbox)
- `schools/school_001/notifications/{id}`

Recommended fields (current inbox expects these):
- `title` (string)
- `body` (string)
- `scope` one of: `school` | `group` | `classSection` | `parent`
- `groupId` (optional)
- `classId` (optional)
- `sectionId` (optional)
- `parentMobile` (optional)
- `createdAt` (timestamp)
- `createdByUid`, `createdByName`, `createdByRole` (optional)

---

## 5) How push delivery works without Cloud Functions
Inbox works purely from Firestore.

Actual *push* delivery (FCM) typically needs one of these:
1) A trusted server (Cloud Run / your backend) to call FCM HTTP v1
2) Firebase Cloud Functions (NOT allowed here)
3) Manually sending from Firebase Console
4) Topics + a trusted sender

If you still want in-app sending with **no server**, we can do it using FCM HTTP from the Admin app, but it requires embedding a server key/service credentials, which is **not secure**.

---

## 6) What to test
- Login as Teacher/Admin → open dashboard → check Firestore token written under `/users/{uid}/tokens`
- Login as Parent → open dashboard → token attempt under `/parents/{mobile}/tokens`
- Add a notification doc manually under `/schools/school_001/notifications` and confirm inbox shows it
