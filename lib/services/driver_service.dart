import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/utils.dart';
import '../models/ride.dart';
import 'location_service.dart';

final DatabaseReference db = FirebaseDatabase.instance.ref();
String get myUid => FirebaseAuth.instance.currentUser!.uid;

/// نشر موقع السائق حسب حالة العمل:
///  - متصل بدون رحلة: موقع تقريبي (3 خانات عشرية ≈ 110م) في onlineDrivers كل 15 ثانية
///  - أثناء رحلة (قبول/وصول/جارية): موقع دقيق في driverLocations مرتبط برقم الرحلة كل 5 ثوانٍ
///  - غير متصل / انتهت الرحلة: حذف البيانات فوراً
class LocationPublisher {
  static StreamSubscription<Position>? _sub;
  static Timer? _timer;
  static String? _rideId;
  static String _state = 'idle';
  static int _lastCoarse = 0;
  static double _heading = 0;
  static String _name = '';
  static double _rating = 0;
  static String _vehicle = '';
  static final ValueNotifier<LatLng?> position = ValueNotifier(null);
  static final ValueNotifier<bool> online = ValueNotifier(false);
  static bool get running => _sub != null;

  static Future<void> start() async {
    if (_sub != null) return;
    await LocationService.ensureReady();
    final uid = myUid;
    try {
      final pr = await DriverService.profile();
      final v = asMap(pr['vehicle']);
      _name = (pr['name'] ?? '').toString().split(' ').first;
      _vehicle = '${v['model'] ?? ''}';
      _rating = (await DriverService.ratings()).avg;
    } catch (_) {}
    db.child('onlineDrivers/$uid').onDisconnect().remove();
    db.child('driverLocations/$uid').onDisconnect().remove();
    _sub = LocationService.stream(distanceFilter: 8, foreground: true).listen((p) {
      position.value = LatLng(p.latitude, p.longitude);
      if (p.heading >= 0) _heading = p.heading;
      _publish();
    }, onError: (_) {});
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _publish());
    online.value = true;
    try {
      final last = await LocationService.current();
      position.value = last;
      _publish();
    } catch (_) {}
  }

  static void setRide(String? id, {String state = 'idle'}) {
    _rideId = id;
    _state = state;
    if (id == null) db.child('driverLocations/$myUid').remove().catchError((_) {});
    _publish();
  }

  static void _publish() {
    if (_sub == null) return; // غير متصل: لا ننشر الموقع (الموقع المحلي للعرض فقط)
    final p = position.value;
    if (p == null) return;
    final uid = myUid;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_rideId != null) {
      db.child('driverLocations/$uid').set({
        'lat': p.latitude,
        'lng': p.longitude,
        'heading': _heading,
        'rideId': _rideId,
        'state': _state,
        'updatedAt': ServerValue.timestamp,
      }).catchError((_) {});
    }
    if (now - _lastCoarse >= 15000) {
      _lastCoarse = now;
      db.child('onlineDrivers/$uid').set({
        'lat': double.parse(p.latitude.toStringAsFixed(3)),
        'lng': double.parse(p.longitude.toStringAsFixed(3)),
        'name': _name,
        'rating': double.parse(_rating.toStringAsFixed(1)),
        'vehicle': _vehicle,
        'updatedAt': ServerValue.timestamp,
      }).catchError((_) {});
    }
  }

  static Future<void> stop() async {
    await _sub?.cancel();
    _timer?.cancel();
    _sub = null;
    _timer = null;
    _rideId = null;
    online.value = false;
    try {
      final uid = myUid;
      await db.child('onlineDrivers/$uid').remove();
      await db.child('driverLocations/$uid').remove();
    } catch (_) {}
  }
}

class DriverService {
  static Future<int> serverNowMs() async {
    final localNow = DateTime.now().millisecondsSinceEpoch;
    try {
      final value = (await db.child('.info/serverTimeOffset').get()).value;
      final offset = value is num ? value.toInt() : 0;
      return localNow + offset;
    } catch (_) {
      return localNow;
    }
  }

  static Future<double> commissionPercent() async {
    try {
      final v = (await db.child('settings/commissionPercent').get()).value;
      return v is num ? v.toDouble() : 10;
    } catch (_) {
      return 10;
    }
  }

  static Future<Map<String, dynamic>> profile() async =>
      asMap((await db.child('drivers/$myUid').get()).value);

  static Future<({double avg, int count, List<Map<String, dynamic>> list})> ratings() async {
    final m = asMap((await db.child('driverRatings/$myUid').get()).value);
    final list = m.values.map((v) => asMap(v)).toList()
      ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
    if (list.isEmpty) return (avg: 0.0, count: 0, list: list);
    final sum = list.fold<double>(0, (s, e) => s + numD(e['stars']));
    return (avg: sum / list.length, count: list.length, list: list);
  }

  static Future<List<Ride>> myRides() async {
    final idx = await db.child('driverTrips/$myUid').get();
    if (!idx.exists) return [];
    final out = <Ride>[];
    await Future.wait(asMap(idx.value).keys.map((id) async {
      try {
        final s = await db.child('rides/$id').get();
        if (s.exists) out.add(Ride.fromMap(id, asMap(s.value)));
      } catch (_) {}
    }));
    out.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    return out;
  }

  /// ينفّذ خطوة ويحوّل خطأ الصلاحيات إلى رسالة تحدد أي مسار رفضته قواعد Firebase
  static Future<T> _step<T>(String label, Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      final t = e.toString().toLowerCase();
      if (t.contains('permission denied') || t.contains('permission-denied')) {
        throw Exception('رفضت قواعد Firebase صلاحية: $label');
      }
      rethrow;
    }
  }

  static Future<void> sendOffer({
    required String rideId,
    required double price,
    required int etaMin,
    required String note,
  }) async {
    if (!price.isFinite || price <= 0 || etaMin < 0 || etaMin > 240) {
      throw Exception('تحقق من السعر ووقت الوصول قبل إرسال العرض.');
    }
    // الطلب المفتوح هو المصدر الوحيد: وجوده يعني أنه ما زال متاحاً (لا نقرأ rides/ لأن السائق لا يملك صلاحيتها قبل قبول عرضه)
    final requestSnap = await _step('قراءة الطلب المفتوح (openRequests)', () => db.child('openRequests/$rideId').get());
    if (!requestSnap.exists) throw Exception('الطلب غير موجود أو لم يعد متاحاً لتقديم العروض.');
    final request = asMap(requestSnap.value);
    final createdAt = (request['createdAt'] as num?)?.toInt();
    final legacyExpiry = (request['expiresAt'] as num?)?.toInt();
    final expiry = createdAt != null ? createdAt + const Duration(seconds: 60).inMilliseconds : legacyExpiry;
    final serverNow = await serverNowMs();
    if (expiry == null || expiry <= serverNow) {
      throw Exception('انتهت مهلة استقبال العروض لهذا الطلب (60 ثانية).');
    }
    final p = await _step('قراءة بيانات السائق (drivers)', () => profile());
    if (p['status'] != 'approved' && p['status'] != 'active') throw Exception('يجب اعتماد حسابك قبل تقديم عروض الرحلات.');
    var avg = 0.0;
    try {
      avg = (await ratings()).avg;
    } catch (_) {}
    final v = asMap(p['vehicle']);
    final vehicleImages = <String, String>{};
    try {
      final raw = (await db.child('settings/vehicleImages').get()).value;
      if (raw is Map) raw.forEach((k, val) { if (val is String && val.startsWith('https://')) vehicleImages[k.toString()] = val; });
    } catch (_) {}
    await _step('كتابة العرض (rides/$rideId/offers)', () => db.child('rides/$rideId/offers/$myUid').set({
          'name': p['name'] ?? '',
          'photoUrl': p['photoUrl'] ?? p['photoURL'] ?? p['avatarUrl'] ?? '',
          'phone': p['phone'] ?? '',
          'rating': double.parse(avg.toStringAsFixed(1)),
          'trips': (p['tripsCount'] as num?)?.toInt() ?? 0,
          'vehicle': '${v['model'] ?? ''} • ${v['color'] ?? ''}',
          'plate': v['plate'] ?? '',
          'vehicleColor': v['color'] ?? '',
          'vehicleImage': v['photoUrl'] ?? (vehicleImages[v['type']?.toString() ?? ''] ?? ''),
          'price': price,
          'etaMin': etaMin,
          'note': note,
          'status': 'pending',
          'createdAt': ServerValue.timestamp,
        }));
  }

  static Future<void> withdrawOffer(String rideId) =>
      db.child('rides/$rideId/offers/$myUid').remove();

  static Future<String> createTicket(String title, String message) async {
    final id = db.child('tickets').push().key!;
    await db.update({
      'tickets/$id': {
        'uid': myUid,
        'ticketNumber': id.substring(id.length - 8).toUpperCase(),
        'title': title,
        'role': 'driver',
        'status': 'open',
        'priority': 'medium',
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
        'messages': {
          'm1': {'from': 'driver', 'uid': myUid, 'text': message, 'createdAt': ServerValue.timestamp}
        },
      },
      'userTickets/$myUid/$id': true,
    });
    return id;
  }
}
