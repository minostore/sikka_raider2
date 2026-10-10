// ملف إعدادات Firebase (مولَّد من google-services.json و GoogleService-Info.plist الخاصة بمشروعك)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('المنصة غير مدعومة');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDbImVnnxRMCQrCdNX6R1ntlX5cXHlB8gE',
    appId: '1:579375270214:android:babb61c0712c12722ffd47',
    messagingSenderId: '579375270214',
    projectId: 'el-ezz-express-179fc',
    databaseURL: 'https://el-ezz-express-179fc-default-rtdb.firebaseio.com',
    storageBucket: 'el-ezz-express-179fc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDQda-52L3uv_coXQZCqp0hpZGKNvtZOX0',
    appId: '1:579375270214:ios:a97ad73b48713e462ffd47',
    messagingSenderId: '579375270214',
    projectId: 'el-ezz-express-179fc',
    databaseURL: 'https://el-ezz-express-179fc-default-rtdb.firebaseio.com',
    storageBucket: 'el-ezz-express-179fc.firebasestorage.app',
    iosBundleId: 'com.sikka',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAWiPtxVQZAK48iAiKenuoteaH8j7MqK_Y',
    appId: '1:579375270214:web:0dd49d61ef9fdea92ffd47',
    messagingSenderId: '579375270214',
    projectId: 'el-ezz-express-179fc',
    authDomain: 'el-ezz-express-179fc.firebaseapp.com',
    databaseURL: 'https://el-ezz-express-179fc-default-rtdb.firebaseio.com',
    storageBucket: 'el-ezz-express-179fc.firebasestorage.app',
  );
}
