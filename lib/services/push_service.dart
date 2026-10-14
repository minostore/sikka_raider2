import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../core/config.dart';

/// إشعارات ستارة الهاتف (FCM) القادمة من لوحة التحكم — تصل والتطبيق مغلق.
/// يحفظ رمز الجهاز في users/{uid}/fcmToken أو drivers/{uid}/fcmToken ليستخدمه الخادم.
class PushService {
  static bool _started = false;
  static StreamSubscription<String>? _refresh;

  static Future<void> start() async {
    if (kIsWeb || _started) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _started = true;
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission(alert: true, badge: true, sound: true);
      // في المقدمة يعرض LocalNotify الإشعار بنفسه لتفادي التكرار على iOS
      await m.setForegroundNotificationPresentationOptions(alert: false, badge: false, sound: false);
      await _save(uid, await m.getToken());
      _refresh = m.onTokenRefresh.listen((t) => _save(FirebaseAuth.instance.currentUser?.uid, t), onError: (_) {});
    } catch (_) {
      _started = false;
    }
  }

  static Future<void> _save(String? uid, String? token) async {
    if (uid == null || token == null || token.isEmpty) return;
    final node = AppConfig.role == 'driver' ? 'drivers' : 'users';
    try {
      await FirebaseDatabase.instance.ref('$node/$uid/fcmToken').set(token);
    } catch (_) {}
  }

  /// عند تسجيل الخروج: نحذف الرمز كي لا تصل إشعارات الحساب السابق لهذا الجهاز.
  static Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    await _refresh?.cancel();
    _refresh = null;
    _started = false;
    if (uid == null || kIsWeb) return;
    final node = AppConfig.role == 'driver' ? 'drivers' : 'users';
    try {
      await FirebaseDatabase.instance.ref('$node/$uid/fcmToken').remove();
    } catch (_) {}
  }
}
