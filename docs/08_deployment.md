# 8) Deployment

## A) Build Android APK
In PowerShell inside the project folder:
- `flutter build apk --release`

APK output:
- `build/app/outputs/flutter-apk/app-release.apk`

For Play Store later:
- Use `flutter build appbundle --release`

## B) Build Web (PWA)
- `flutter build web --release`

Output:
- `build/web/`

### iPhone Safari (PWA) notes
- Add to Home Screen works if your web app is served over HTTPS.
- Push notifications on iPhone Safari depend on iOS/Safari version.
- Even without web push, you can still show notifications from Firestore in-app.

## C) Host Admin Panel on Firebase Hosting
Because this is ONE Flutter app, the admin dashboard is inside the same web build.

Steps:
1. `firebase init hosting`
   - Choose the Firebase project
   - Public directory: `build/web`
   - Configure as single-page app: **Yes**
2. Build web:
   - `flutter build web --release`
3. Deploy:
   - `firebase deploy --only hosting`

Your admin URL will be the same web app URL.
Admin sees a sidebar layout automatically on wide screens.
