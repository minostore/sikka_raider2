import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/utils.dart';

class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;
  final bool estimated; // true إذا فشلت الخدمة وتم التقدير بخط مستقيم
  RouteInfo(this.points, this.distanceKm, this.durationMin, {this.estimated = false});
}

/// حساب المسافة والزمن ورسم الطريق عبر OSRM.
/// ملاحظة: الزمن لا يعكس الازدحام، والخادم العام ليس مضموناً للإنتاج.
class RoutingService {
  static Future<RouteInfo> route(LatLng a, LatLng b) async {
    try {
      final path =
          '/route/v1/driving/${a.longitude},${a.latitude};${b.longitude},${b.latitude}';
      final uri = Uri.https(
          'router.project-osrm.org', path, {'overview': 'full', 'geometries': 'geojson'});
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        final routes = j['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final r = routes.first as Map<String, dynamic>;
          final coords = (r['geometry']['coordinates'] as List)
              .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
              .toList();
          return RouteInfo(
              coords, (r['distance'] as num) / 1000, (r['duration'] as num) / 60);
        }
      }
    } catch (_) {}
    final km = haversineKm(a, b) * 1.3; // تقدير تقريبي عند تعذر الخدمة
    return RouteInfo([a, b], km, km / 0.5, estimated: true);
  }
}
