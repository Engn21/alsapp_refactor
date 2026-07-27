// Firebase Cloud Messaging background service worker. Handles push
// delivery while the tab is closed/unfocused - foreground messages are
// handled in Dart via FirebaseMessaging.onMessage instead (see
// lib/services/push_service.dart).
//
// PLACEHOLDER CONFIG - replace the firebaseConfig object below with the
// real values from the Firebase console (Project settings -> General ->
// Your apps -> Web app), matching lib/firebase_options.dart. This file
// can't read Dart config at runtime since it's a plain JS service worker.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REPLACE_ME',
  authDomain: 'REPLACE_ME.firebaseapp.com',
  projectId: 'REPLACE_ME',
  storageBucket: 'REPLACE_ME.appspot.com',
  messagingSenderId: 'REPLACE_ME',
  appId: 'REPLACE_ME',
});

const messaging = firebase.messaging();

// Deep-link taps on a background notification. The app may not be open
// at all, so this can only open/focus a window - Dart-side routing to
// the specific crop/livestock happens once the app picks up the click
// via FirebaseMessaging.onMessageOpenedApp (see push_service.dart).
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(clients.openWindow('/'));
});
