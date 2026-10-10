import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../models/ride.dart';

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
    final user = FirebaseAuth.instance.currentUser!;
    final profile = asMap((await db.child('users/$uid').get()).value);
    final id = db.child('rides').push().key!;
    final base = {
      'riderId': uid,
      'riderName': profile['name'] ?? user.displayName ?? '',
      'riderPhone': profile['phone'] ?? '',
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
        'expiresAt': DateTime.now().millisecondsSinceEpoch + 10 * 60 * 1000,
      },
      'userRides/$uid/$id': true,
      'users/$uid/activeRide': id,
    });
    return id;
  }

  static Future<void> acceptOffer(String rideId, Offer o) async {
    final code = (1000 + Random().nextInt(9000)).toString();
    await db.update({
      'rides/$rideId/driverId': o.driverId,
      'rides/$rideId/driverName': o.name,
      'rides/$rideId/driverPhone': o.phone,
      'rides/$rideId/vehicle': o.vehicle,
      'rides/$rideId/driverRating': o.rating,
      'rides/$rideId/agreedPrice': o.price,
      'rides/$rideId/startCode': code,
      'rides/$rideId/status': 'accepted',
      'rides/$rideId/acceptedAt': ServerValue.timestamp,
      'rides/$rideId/offers/${o.driverId}/status': 'accepted',
      'driverActive/${o.driverId}': rideId,
      'openRequests/$rideId': null,
    });
  }

  static Future<void> cancel(String rideId, {String? driverId}) async {
    await db.update({
      'rides/$rideId/status': 'cancelled',
      'rides/$rideId/cancelledBy': 'rider',
      'rides/$rideId/cancelledAt': ServerValue.timestamp,
      'openRequests/$rideId': null,
      'users/$uid/activeRide': null,
      if (driverId != null) 'driverActive/$driverId': null,
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
