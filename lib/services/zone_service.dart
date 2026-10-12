import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../core/utils.dart';

class ServiceZone {
  final String id;
  final String name;
  final List<LatLng> points;
  final bool active;
  final double surge;
  ServiceZone(this.id, this.name, this.points, this.active, this.surge);

  /// اختبار نقطة داخل مضلع (Ray casting)
  bool contains(LatLng p) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i], b = points[j];
      final cross = (a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude <
              (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) + a.longitude;
      if (cross) inside = !inside;
    }
    return inside;
  }
}

/// مناطق الخدمة التي ترسمها الإدارة من لوحة التحكم.
/// لا تُتاح الخدمة إلا داخل منطقة فعّالة محددة من الإدارة.
class ZoneService {
  static final ValueNotifier<List<ServiceZone>> zones = ValueNotifier([]);
  static StreamSubscription? _sub;
  static bool _loaded = false;
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    try {
      final snapshot = await FirebaseDatabase.instance.ref('zones').get();
      _apply(snapshot.value);
      _loaded = true;
    } catch (_) {
      // Fail closed: without a confirmed service-zone list, rides stay disabled.
    }
  }
  static const outsideMessage = 'الموقع المحدد خارج نطاق الخدمة أو غير متاح حالياً.';

  static void start() {
    if (_sub != null) return;
    _sub = FirebaseDatabase.instance.ref('zones').onValue.listen((e) {
      _apply(e.snapshot.value);
      _loaded = true;
    }, onError: (_) {});
  }

  static void _apply(Object? value) {
      final out = <ServiceZone>[];
      asMap(value).forEach((id, v) {
        final m = asMap(v);
        final rawPoints = m['points'];
        final list = <LatLng>[];
        if (rawPoints is List) {
          for (final value in rawPoints) {
            final q = asMap(value);
            if (q['lat'] is num && q['lng'] is num) {
              list.add(LatLng(numD(q['lat']), numD(q['lng'])));
            }
          }
        } else {
          final pointMap = asMap(rawPoints);
          final keys = pointMap.keys.toList()
            ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
          for (final key in keys) {
            final q = asMap(pointMap[key]);
            if (q['lat'] is num && q['lng'] is num) {
              list.add(LatLng(numD(q['lat']), numD(q['lng'])));
            }
          }
        }
        out.add(ServiceZone(id, (m['name'] ?? '').toString(), list, m['active'] != false, numD(m['surgePercent'])));
      });
      zones.value = out;
  }

  static List<ServiceZone> get active =>
      zones.value.where((z) => z.active && z.points.length >= 3).toList();
  static bool get restricted => true;
  static bool allowed(LatLng p) => active.isNotEmpty && active.any((z) => z.contains(p));
  static double surgeAt(LatLng p) {
    var s = 0.0;
    for (final z in active) {
      if (z.contains(p) && z.surge > s) s = z.surge;
    }
    return s;
  }
}
