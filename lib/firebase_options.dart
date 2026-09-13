
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;


class DefaultFirebaseOptions {
  static const String _webApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
    defaultValue: 'YOUR_FIREBASE_WEB_API_KEY',
  );

  static const String _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: 'YOUR_FIREBASE_ANDROID_API_KEY',
  );

  static const String _iosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
    defaultValue: 'YOUR_FIREBASE_IOS_API_KEY',
  );

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
    apiKey: _webApiKey,
    appId: '1:840739691330:web:614296709d2eedf9e2c6db',
    messagingSenderId: '840739691330',
    projectId: 'wavelinkapp-e100c',
    authDomain: 'wavelinkapp-e100c.firebaseapp.com',
    storageBucket: 'wavelinkapp-e100c.firebasestorage.app',
    measurementId: 'G-DFVKXFMEXD',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: _androidApiKey,
    appId: '1:840739691330:android:911c884c99c2cad9e2c6db',
    messagingSenderId: '840739691330',
    projectId: 'wavelinkapp-e100c',
    storageBucket: 'wavelinkapp-e100c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _iosApiKey,
    appId: '1:840739691330:ios:56c34d9290c0de06e2c6db',
    messagingSenderId: '840739691330',
    projectId: 'wavelinkapp-e100c',
    storageBucket: 'wavelinkapp-e100c.firebasestorage.app',
    iosBundleId: 'com.example.wavelinkApp',
  );
}
