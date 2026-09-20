import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) throw UnsupportedError('Web not supported');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('Platform not configured');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCiy7RN1lTdP4dS6bRCoLIsz1vmuf1kMLY',
    appId: '1:833714346893:android:5b54ab5d24f45e54b6fbc4',
    messagingSenderId: '833714346893',
    projectId: 'fitness-battle-27981',
    databaseURL: 'https://fitness-battle-27981-default-rtdb.firebaseio.com',
    storageBucket: 'fitness-battle-27981.firebasestorage.app',
  );
}
