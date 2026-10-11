import '../core/utils.dart';
import 'place.dart';

class Ride {
  final String id;
  final String status;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final Place pickup;
  final Place dest;
  final double distanceKm;
  final double durationMin;
  final double price;
  final double? agreedPrice;
  final String vehicleType;
  final String note;
  final String paymentMethod;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? vehicle;
  final String? plate;
  final double driverRating;
  final String? startCode;
  final int? createdAt;
  final int? startedAt;
  final int? completedAt;
  final double commission;
  final bool riderRated;
  final String? cancelledBy;

  Ride({
    required this.id,
    required this.status,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.pickup,
    required this.dest,
    required this.distanceKm,
    required this.durationMin,
    required this.price,
    this.agreedPrice,
    required this.vehicleType,
    required this.note,
    required this.paymentMethod,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.vehicle,
    this.plate,
    this.driverRating = 0,
    this.startCode,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.commission = 0,
    this.riderRated = false,
    this.cancelledBy,
  });

  double get finalPrice => agreedPrice ?? price;

  factory Ride.fromMap(String id, Map<String, dynamic> m) => Ride(
        id: id,
        status: (m['status'] ?? 'requested').toString(),
        riderId: (m['riderId'] ?? '').toString(),
        riderName: (m['riderName'] ?? '').toString(),
        riderPhone: (m['riderPhone'] ?? '').toString(),
        pickup: Place.fromMap(asMap(m['pickup'])),
        dest: Place.fromMap(asMap(m['dest'])),
        distanceKm: numD(m['distanceKm']),
        durationMin: numD(m['durationMin']),
        price: numD(m['price']),
        agreedPrice: m['agreedPrice'] is num ? (m['agreedPrice'] as num).toDouble() : null,
        vehicleType: (m['vehicleType'] ?? 'regular').toString(),
        note: (m['note'] ?? '').toString(),
        paymentMethod: (m['paymentMethod'] ?? 'cash').toString(),
        driverId: m['driverId']?.toString(),
        driverName: m['driverName']?.toString(),
        driverPhone: m['driverPhone']?.toString(),
        vehicle: m['vehicle']?.toString(),
        plate: m['plate']?.toString(),
        driverRating: numD(m['driverRating']),
        startCode: m['startCode']?.toString(),
        createdAt: m['createdAt'] is int ? m['createdAt'] as int : null,
        startedAt: m['startedAt'] is int ? m['startedAt'] as int : null,
        completedAt: m['completedAt'] is int ? m['completedAt'] as int : null,
        commission: numD(m['commission']),
        riderRated: m['riderRated'] == true,
        cancelledBy: m['cancelledBy']?.toString(),
      );
}
