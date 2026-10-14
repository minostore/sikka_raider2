import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// إشعارات النظام (تظهر في ستارة الهاتف) وربطها بإشعارات التطبيق في قاعدة البيانات.
class LocalNotify {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static StreamSubscription<DatabaseEvent>? _sub;
  static final Set<String> _shown = <String>{};
  static AppLifecycleState _lifecycle = AppLifecycleState.resumed;
  static final _LifecycleWatcher _watcher = _LifecycleWatcher();

  /// هل التطبيق ظاهر أمام المستخدم الآن؟ (في المقدمة FCM لا يعرض إشعاراً بنفسه)
  static bool get inForeground => _lifecycle == AppLifecycleState.resumed;

  static const String updatesChannel = 'sikka_updates';
  static const String ridesChannel = 'sikka_rides';

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    WidgetsBinding.instance.addObserver(_watcher);
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings);
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        updatesChannel,
        'تنبيهات الرحلات',
        description: 'تحديثات حالة الرحلات والعروض',
        importance: Importance.high,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        ridesChannel,
        'طلبات الرحلات الجديدة',
        description: 'تنبيه فوري عند وصول طلب رحلة جديد',
        importance: Importance.max,
        playSound: false,
      ));
      if (android != null) unawaited(android.requestNotificationsPermission());
      _ready = true;
    } catch (_) {}
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
    bool rideChannel = false,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            rideChannel ? ridesChannel : updatesChannel,
            rideChannel ? 'طلبات الرحلات الجديدة' : 'تنبيهات الرحلات',
            importance: rideChannel ? Importance.max : Importance.high,
            priority: Priority.high,
            playSound: !rideChannel,
            enableVibration: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true),
        ),
      );
    } catch (_) {}
  }

  /// يستمع لإشعارات المستخدم الجديدة في قاعدة البيانات ويعرضها في ستارة الإشعارات.
  static void startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _sub != null) return;
    final since = DateTime.now().millisecondsSinceEpoch - 60000;
    _sub = FirebaseDatabase.instance.ref('notifications/$uid').onChildAdded.listen((e) {
      final key = e.snapshot.key ?? '';
      final v = e.snapshot.value;
      if (key.isEmpty || v is! Map || _shown.contains(key)) return;
      if (v['read'] == true) return;
      final created = v['createdAt'];
      if (created is num && created < since) return;
      // delivery (من لوحة التحكم): inapp = داخل التطبيق فقط | push = ستارة الهاتف | both = الاثنان
      final delivery = (v['delivery'] ?? '').toString();
      if (delivery == 'inapp') {
        _shown.add(key);
        return; // يظهر في صفحة الإشعارات فقط ولا يظهر في ستارة الهاتف
      }
      // push/both: FCM يعرضه بنفسه والتطبيق في الخلفية أو مغلق؛ نعرضه محلياً فقط والتطبيق مفتوح
      if ((delivery == 'push' || delivery == 'both') && !inForeground) {
        _shown.add(key);
        return;
      }
      _shown.add(key);
      show(
        id: key.hashCode & 0x7fffffff,
        title: (v['title'] ?? 'سِكّة').toString(),
        body: (v['body'] ?? '').toString(),
      );
    }, onError: (_) {});
  }

  static Future<void> stopListening() async {
    await _sub?.cancel();
    _sub = null;
  }
}

class _LifecycleWatcher with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    LocalNotify._lifecycle = state;
  }
}
