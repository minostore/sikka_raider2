import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../models/ride.dart';
import '../services/zone_service.dart';
import 'package:latlong2/latlong.dart';

class Offer {
  final String driverId;
  final String name;
  final String phone;
  final double rating;
  final int trips;
  final String vehicle;
  final double price;
  final int etaMin;
  final String note;
  final int createdAt;
  Offer(this.driverId, this.name, this.phone, this.rating, this.trips, this.vehicle,
      this.price, this.etaMin, this.note, this.createdAt);

  factory Offer.fromMap(String id, Map<String, dynamic> m) => Offer(
        id,
        (m['name'] ?? 'سائق').toString(),
        (m['phone'] ?? '').toString(),
        numD(m['rating']),
        (m['trips'] as num?)?.toInt() ?? 0,
        (m['vehicle'] ?? '').toString(),
        numD(m['price']),
        (m['etaMin'] as num?)?.toInt() ?? 0,
        (m['note'] ?? '').toString(),
        (m['createdAt'] as num?)?.toInt() ?? 0,
      );
}

class RideService {
  static final DatabaseReference db = FirebaseDatabase.instance.ref();
  static String get uid => FirebaseAuth.instance.currentUser!.uid;

  static Future<Map<String, double>> pricing() async {
    try {
      final m = asMap((await db.child('settings/pricing').get()).value);
      return {
        'base': numD(m['base'], 15),
        'perKm': numD(m['perKm'], 5),
        'minFare': numD(m['minFare'], 25),
      };
    } catch (_) {
      return {'base': 15, 'perKm': 5, 'minFare': 25};
    }
  }

  static Future<String?> activeRideId() async =>
      (await db.child('users/$uid/activeRide').get()).value?.toString();

  static Future<String> createRide({
    required Place pickup,
    required Place dest,
    required double distanceKm,
    required double durationMin,
    required double price,
    required String vehicleType,
    String note = '',
  }) async {
    if (await activeRideId() != null) {
      throw Exception('لديك رحلة جارية بالفعل.');
    }
    // اقرأ المناطق مباشرة من Firebase لضمان التحقق حتى لو لم يكتمل تحديث المستمع الحي.
    try {
      final zoneSnapshot = await db.child('zones').get();
      final zoneMap = asMap(zoneSnapshot.value);
      final activeZones = <ServiceZone>[];
      zoneMap.forEach((id, value) {
        final m = asMap(value);
        if (m['active'] == false) return;
        final rawPoints = m['points'];
        final pts = <LatLng>[];
        if (rawPoints is List) {
          for (final item in rawPoints) {
            final point = asMap(item);
            if (point['lat'] is num && point['lng'] is num) {
              pts.add(LatLng((point['lat'] as num).toDouble(), (point['lng'] as num).toDouble()));
            }
          }
        } else {
          final pointMap = asMap(rawPoints);
          final keys = pointMap.keys.toList()..sort((a, b) => int.tryParse(a)?.compareTo(int.tryParse(b) ?? 0) ?? 0);
          for (final key in keys) {
            final point = asMap(pointMap[key]);
            if (point['lat'] is num && point['lng'] is num) {
              pts.add(LatLng((point['lat'] as num).toDouble(), (point['lng'] as num).toDouble()));
            }
          }
        }
        if (pts.length >= 3) activeZones.add(ServiceZone(id, (m['name'] ?? '').toString(), pts, true, numD(m['surgePercent'])));
      });
      // توافقاً مع إعداد النظام الحالي: عدم وجود مناطق مفعّلة يعني عدم تقييد الخدمة.
      if (activeZones.isNotEmpty) {
        final pickupAllowed = activeZones.any((z) => z.contains(pickup.point));
        final destAllowed = activeZones.any((z) => z.contains(dest.point));
        if (!pickupAllowed) throw Exception('موقع الانطلاق خارج نطاق الخدمة. اختر نقطة داخل المنطقة المحددة.');
        if (!destAllowed) throw Exception('الوجهة خارج نطاق الخدمة. اختر وجهة داخل المنطقة المحددة.');
      }
    } on FirebaseException catch (e) {
      throw Exception('تعذر التحقق من مناطق الخدمة. تحقق من اتصال Firebase والصلاحيات (${e.code}).');
    }
    final user = FirebaseAuth.instance.currentUser!;
    final profile = asMap((await db.child('users/$uid').get()).value);
    final id = db.child('rides').push().key!;
    final base = {
      'riderId': uid,
      'riderName': profile['name'] ?? user.displayName ?? '',
      'riderPhone': profile['phone'] ?? '',
      'riderPhotoUrl': profile['photoUrl'] ?? profile['photoURL'] ?? profile['avatarUrl'] ?? '',
      'pickup': pickup.toMap(),
      'dest': dest.toMap(),
      'distanceKm': double.parse(distanceKm.toStringAsFixed(2)),
      'durationMin': durationMin.round(),
      'price': price,
      'vehicleType': vehicleType,
      'note': note,
      'paymentMethod': 'cash',
    };
    await db.update({
      'rides/$id': {...base, 'status': 'requested', 'createdAt': ServerValue.timestamp},
      'openRequests/$id': {
        ...base,
        'createdAt': ServerValue.timestamp,
        'expiresAt': DateTime.now().millisecondsSinceEpoch + 60 * 1000,
      },
      'userRides/$uid/$id': true,
      'users/$uid/activeRide': id,
    });
    return id;
  }

  static Future<void> acceptOffer(String rideId, Offer o) async {
    // Claim the ride with a transaction so two offers cannot win simultaneously.
    final code = (1000 + Random().nextInt(9000)).toString();
    final rideRef = db.child('rides/$rideId');
    final result = await rideRef.runTransaction((Object? value) {
      if (value is! Map) return Transaction.abort();
      final ride = Map<String, dynamic>.from(value);
      if (ride['status'] != 'requested') return Transaction.abort();
      final offers = asMap(ride['offers']);
      final selected = asMap(offers[o.driverId]);
      if (selected.isEmpty || selected['status'] != 'pending') {
        return Transaction.abort();
      }
      ride['driverId'] = o.driverId;
      ride['driverName'] = o.name;
      ride['driverPhone'] = o.phone;
      ride['vehicle'] = o.vehicle;
      ride['driverRating'] = o.rating;
      ride['agreedPrice'] = o.price;
      ride['startCode'] = code;
      ride['status'] = 'accepted';
      ride['acceptedAt'] = DateTime.now().millisecondsSinceEpoch;
      offers[o.driverId] = {...selected, 'status': 'accepted'};
      ride['offers'] = offers;
      return Transaction.success(ride);
    });
    if (!result.committed) {
      throw Exception('تم اختيار سائق آخر أو انتهى الطلب. حدّث الشاشة وحاول مرة أخرى.');
    }
    // Update lookup indexes only after the ride has been claimed successfully.
    await db.update({
      'driverActive/${o.driverId}': rideId,
      'openRequests/$rideId': null,
    });
  }

  static Future<void> cancel(String rideId, {String? driverId}) async {
    final ref = db.child('rides/$rideId');
    final rideSnapshot = await ref.get();
    final ride = asMap(rideSnapshot.value);
    if (ride['riderId'] != uid) throw Exception('لا تملك صلاحية إلغاء هذه الرحلة.');
    final result = await ref.child('status').runTransaction((Object? value) {
      if (!['requested', 'accepted', 'arrived'].contains(value?.toString())) return Transaction.abort();
      return Transaction.success('cancelled');
    });
    if (!result.committed) {
      throw Exception('لا يمكن إلغاء الرحلة بعد بدء المشوار أو انتهاء الطلب. حدّث الشاشة.');
    }
    await ref.update({'cancelledBy': 'rider', 'cancelledAt': ServerValue.timestamp});
    final actualDriver = driverId ?? ride['driverId']?.toString();
    await db.update({
      'openRequests/$rideId': null,
      'users/$uid/activeRide': null,
      if (actualDriver != null && actualDriver.isNotEmpty) 'driverActive/$actualDriver': null,
    });
  }

  static Future<void> clearActive() => db.child('users/$uid/activeRide').remove();

  static Future<void> rate(Ride r, int stars, String comment) async {
    final updates = <String, Object?>{
      'rides/${r.id}/riderRated': true,
      'users/$uid/activeRide': null,
    };
    if (r.driverId != null) {
      updates['driverRatings/${r.driverId}/${r.id}'] = {
        'stars': stars,
        'comment': comment,
        'createdAt': ServerValue.timestamp,
      };
    }
    await db.update(updates);
  }

  static Future<List<Ride>> myRides() async {
    final idx = await db.child('userRides/$uid').get();
    if (!idx.exists) return [];
    final ids = asMap(idx.value).keys.toList();
    final list = <Ride>[];
    await Future.wait(ids.map((id) async {
      try {
        final s = await db.child('rides/$id').get();
        if (s.exists) list.add(Ride.fromMap(id, asMap(s.value)));
      } catch (_) {}
    }));
    list.sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
    return list;
  }

  static Future<void> createTicket(String title, String message, {String? rideId}) async {
    final id = db.child('tickets').push().key!;
    await db.update({
      'tickets/$id': {
        'uid': uid,
        'role': 'driver',
        'ticketNumber': id.substring(id.length - 8).toUpperCase(),
        'title': title,
        'rideId': rideId ?? '',
        'status': 'open',
        'priority': 'medium',
        'createdAt': ServerValue.timestamp,
        'messages': {
          'm1': {'from': 'user', 'text': message, 'createdAt': ServerValue.timestamp}
        },
      },
      'userTickets/$uid/$id': true,
    });
  }
}
