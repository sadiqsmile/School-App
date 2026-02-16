/*
  Firebase Messaging Service Worker
  - Required for Web Push background notifications.
  - Keep this file at: /web/firebase-messaging-sw.js

  IMPORTANT:
  - Replace the firebaseConfig below with your web app config
    OR keep it if you already use flutterfire and the default config.
  - In many FlutterFire setups, config is injected in index.html.
    This SW still needs firebase.initializeApp().
*/

importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js');

// TODO: Replace with your Firebase web config (same values as web/index.html).
// You can find it in Firebase Console → Project settings → Your apps → Web app.
firebase.initializeApp({
  apiKey: 'REPLACE_ME',
  authDomain: 'REPLACE_ME',
  projectId: 'REPLACE_ME',
  storageBucket: 'REPLACE_ME',
  messagingSenderId: 'REPLACE_ME',
  appId: 'REPLACE_ME'
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = (payload.notification && payload.notification.title) ? payload.notification.title : 'Notification';
  const body = (payload.notification && payload.notification.body) ? payload.notification.body : '';

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png'
  });
});
