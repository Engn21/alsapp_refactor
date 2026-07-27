import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

// PLACEHOLDER - replace this file by running `flutterfire configure` from
// frontend/ after setting up a real Firebase project (see the push
// notifications setup steps). The values below are not real; Firebase
// initialization is wrapped in a try/catch in main.dart so the app keeps
// working normally (without push) until this file has real values.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
        apiKey: 'REPLACE_ME',
        appId: 'REPLACE_ME',
        messagingSenderId: 'REPLACE_ME',
        projectId: 'REPLACE_ME',
        authDomain: 'REPLACE_ME.firebaseapp.com',
        storageBucket: 'REPLACE_ME.appspot.com',
      );
}
