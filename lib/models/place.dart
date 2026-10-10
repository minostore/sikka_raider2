import 'package:latlong2/latlong.dart';

class Place {
  final double lat;
  final double lng;
  final String address;
  const Place(this.lat, this.lng, this.address);

  LatLng get point => LatLng(lat, lng);

  Map<String, dynamic> toMap() => {'lat': lat, 'lng': lng, 'address': address};

  factory Place.fromMap(Map<String, dynamic> m) => Place(
        (m['lat'] as num?)?.toDouble() ?? 0,
        (m['lng'] as num?)?.toDouble() ?? 0,
        (m['address'] ?? '').toString(),
      );
}
