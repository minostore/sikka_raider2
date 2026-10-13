import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/utils.dart';
import 'driver_service.dart';
import 'local_notify.dart';

/// تنبيه فوري عند وصول طلب رحلة جديد: نغمة (من لوحة التحكم أو الافتراضية) + إشعار في ستارة الهاتف.
/// يعمل طالما السائق «متصل»، حتى والتطبيق في الخلفية (خدمة الموقع تُبقي التطبيق حياً).
class RideAlerts {
  static final AudioPlayer _player = AudioPlayer();
  static StreamSubscription<DatabaseEvent>? _requests;
  static StreamSubscription<DatabaseEvent>? _tone;
  static String? _toneUrl;
  static final Set<String> _seen = <String>{};

  static void start() {
    if (_requests != null) return;
    _tone = db.child('settings/driverApp/ringtone/url').onValue.listen((e) {
      final v = e.snapshot.value;
      _toneUrl = v is String && v.startsWith('https://') ? v : null;
    }, onError: (_) {});
    _requests = db.child('openRequests').onChildAdded.listen(_onRequest, onError: (_) {});
  }

  static Future<void> _onRequest(DatabaseEvent e) async {
    final id = e.snapshot.key;
    final v = e.snapshot.value;
    if (id == null || v is! Map || _seen.contains(id)) return;
    _seen.add(id);
    if (!LocationPublisher.running) return; // التنبيه للسائق المتصل فقط
    final created = (v['createdAt'] as num?)?.toInt();
    if (created == null) return;
    final now = await DriverService.serverNowMs();
    if (now - created > 45000) return; // طلب قديم (تحميل أولي)
    final pickup = asMap(v['pickup']);
    final dest = asMap(v['dest']);
    unawaited(play());
    await LocalNotify.show(
      id: id.hashCode & 0x7fffffff,
      title: 'طلب رحلة جديد',
      body: '${pickup['address'] ?? ''} ← ${dest['address'] ?? ''}',
      rideChannel: true,
    );
  }

  static Future<void> play() async {
    try {
      await _player.stop();
      await _player.setVolume(1.0);
      final url = _toneUrl;
      await _player.play(url != null ? UrlSource(url) : AssetSource('sounds/new_ride.wav'));
    } catch (_) {
      try {
        await _player.play(AssetSource('sounds/new_ride.wav'));
      } catch (_) {}
    }
  }

  static Future<void> stop() async {
    await _requests?.cancel();
    await _tone?.cancel();
    _requests = null;
    _tone = null;
    _seen.clear();
    try {
      await _player.stop();
    } catch (_) {}
  }
}
