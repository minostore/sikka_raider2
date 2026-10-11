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
    _sub = LocationService.stream(distanceFilter: 8).listen((p) {
      position.value = LatLng(p.latitude, p.longitude);
      if (p.heading >= 0) _heading = p.heading;
      _publish();
    }, onError: (_) {});
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _publish());
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
    try {
      final uid = myUid;
      await db.child('onlineDrivers/$uid').remove();
      await db.child('driverLocations/$uid').remove();
    } catch (_) {}
  }
}

class DriverService {
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

  static Future<void> sendOffer({
    required String rideId,
    required double price,
    required int etaMin,
    required String note,
  }) async {
    if (!price.isFinite || price <= 0 || etaMin < 0 || etaMin > 240) {
      throw Exception('تحقق من السعر ووقت الوصول قبل إرسال العرض.');
    }
    final rideSnapshot = await db.child('rides/$rideId').get();
    if (!rideSnapshot.exists) throw Exception('الطلب غير موجود أو انتهت صلاحيته.');
    final ride = asMap(rideSnapshot.value);
    if (ride['status'] != 'requested') throw Exception('لم يعد هذا الطلب متاحاً لتقديم العروض.');
    final expiresAt = (asMap((await db.child('openRequests/$rideId').get()).value)['expiresAt'] as num?)?.toInt();
    if (expiresAt != null && expiresAt < DateTime.now().millisecondsSinceEpoch) {
      throw Exception('انتهت صلاحية هذا الطلب.');
    }
    final p = await profile();
    if (p['status'] != 'approved') throw Exception('يجب اعتماد حسابك قبل تقديم عروض الرحلات.');
    final r = await ratings();
    final v = asMap(p['vehicle']);
    await db.child('rides/$rideId/offers/$myUid').set({
      'name': p['name'] ?? '',
      'phone': p['phone'] ?? '',
      'rating': double.parse(r.avg.toStringAsFixed(1)),
      'trips': (p['tripsCount'] as num?)?.toInt() ?? 0,
      'vehicle': '${v['model'] ?? ''} • ${v['color'] ?? ''}',
      'plate': v['plate'] ?? '',
      'price': price,
      'etaMin': etaMin,
      'note': note,
      'status': 'pending',
      'createdAt': ServerValue.timestamp,
    });
  }

  static Future<void> withdrawOffer(String rideId) =>
      db.child('rides/$rideId/offers/$myUid').remove();

  static Future<void> createTicket(String title, String message) async {
    final id = db.child('tickets').push().key!;
    await db.update({
      'tickets/$id': {
        'uid': myUid,
        'title': title,
        'role': 'driver',
        'status': 'open',
        'priority': 'medium',
        'createdAt': ServerValue.timestamp,
        'messages': {
          'm1': {'from': 'user', 'text': message, 'createdAt': ServerValue.timestamp}
        },
      },
      'userTickets/$myUid/$id': true,
    });
  }
}
