// File generated manually from google-services.json
// Project: learnco-ffe77

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCNXkZC4YIA0KXpFx_vL4MfgpPKmB-Usz4',
    appId: '1:863978031528:web:your_web_app_id', // You'll need to add Web app in Firebase Console
    messagingSenderId: '863978031528',
    projectId: 'learnco-ffe77',
    authDomain: 'learnco-ffe77.firebaseapp.com',
    storageBucket: 'learnco-ffe77.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCNXkZC4YIA0KXpFx_vL4MfgpPKmB-Usz4',
    appId: '1:863978031528:android:e010397c0e9486689c759d',
    messagingSenderId: '863978031528',
    projectId: 'learnco-ffe77',
    storageBucket: 'learnco-ffe77.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCNXkZC4YIA0KXpFx_vL4MfgpPKmB-Usz4',
    appId: '1:863978031528:ios:your_ios_app_id', // You'll need to add iOS app in Firebase Console if needed
    messagingSenderId: '863978031528',
    projectId: 'learnco-ffe77',
    storageBucket: 'learnco-ffe77.firebasestorage.app',
    iosBundleId: 'com.example.eduai',
  );
}
