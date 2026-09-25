// Placeholder Firebase config used ONLY by CI so `flutter analyze` and
// `flutter test` can compile without the real, git-ignored
// `lib/firebase_options.dart`. The test suite never calls
// `Firebase.initializeApp`, so these dummy values are never used at runtime.
//
// CI copies this file to `lib/firebase_options.dart` before analysis.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => const FirebaseOptions(
    apiKey: 'ci-placeholder',
    appId: '1:0000000000:ios:ciplaceholder',
    messagingSenderId: '0000000000',
    projectId: 'ci-placeholder',
    storageBucket: 'ci-placeholder.appspot.com',
  );
}
