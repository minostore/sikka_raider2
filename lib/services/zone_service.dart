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
  static final Completer<void> _firstLoad = Completer<void>();
  /// آخر خطأ في قراءة المناطق (مثلاً permission-denied) لعرضه عند التشخيص
  static String? lastError;
  static const outsideMessage = 'الموقع المحدد خارج نطاق الخدمة أو غير متاح حالياً.';

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  static LatLng? _point(dynamic v) {
    double? lat, lng;
    if (v is Map) {
      final q = asMap(v);
      lat = _num(q['lat'] ?? q['latitude'] ?? q['Lat'] ?? q['Latitude']);
      lng = _num(q['lng'] ?? q['lon'] ?? q['long'] ?? q['longitude'] ?? q['Lng'] ?? q['Longitude']);
    } else if (v is List && v.length >= 2) {
      final x = _num(v[0]), y = _num(v[1]);
      if (x != null && y != null) {
        // مصر: خط العرض ≈ 22–32 وخط الطول ≈ 25–37؛ نرتّب حسب المنطق إذا كانت القيم مقلوبة
        if (x.abs() > 90) {
          lat = y;
          lng = x;
        } else {
          lat = x;
          lng = y;
        }
      }
    }
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  static List<LatLng> _points(Map<String, dynamic> m) {
    final raw = m['points'] ?? m['polygon'] ?? m['coordinates'] ?? m['coords'] ?? m['path'];
    final list = <LatLng>[];
    if (raw is List) {
      for (final value in raw) {
        final p = _point(value);
        if (p != null) list.add(p);
      }
    } else if (raw is Map) {
      final pointMap = asMap(raw);
      final keys = pointMap.keys.toList()
        ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
      for (final key in keys) {
        final p = _point(pointMap[key]);
        if (p != null) list.add(p);
      }
    }
    return list;
  }

  static bool _isActive(dynamic v) => !(v == false || v == 'false' || v == 0 || v == '0');

  static void start() {
    if (_sub != null) return;
    _sub = FirebaseDatabase.instance.ref('zones').onValue.listen((e) {
      lastError = null;
      final out = <ServiceZone>[];
      asMap(e.snapshot.value).forEach((id, v) {
        final m = asMap(v);
        out.add(ServiceZone(id, (m['name'] ?? '').toString(), _points(m), _isActive(m['active']), numD(m['surgePercent'])));
      });
      zones.value = out;
      if (!_firstLoad.isCompleted) _firstLoad.complete();
    }, onError: (Object err) {
      lastError = err.toString();
      if (!_firstLoad.isCompleted) _firstLoad.complete();
    });
  }

  /// ينتظر وصول أول قراءة للمناطق (حتى 8 ثوانٍ) قبل اتخاذ قرار السماح
  static Future<void> ensureLoaded() async {
    start();
    await _firstLoad.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  /// سبب المنع عند وجود مشكلة في تحميل المناطق، أو null إذا كانت المناطق محمّلة
  static String? get loadProblem {
    if (lastError != null) {
      return 'تعذر تحميل مناطق الخدمة ($lastError). راجع قواعد Firebase لمسار zones.';
    }
    if (zones.value.isEmpty) return 'لا توجد مناطق خدمة مضافة من الإدارة بعد.';
    if (active.isEmpty) return 'مناطق الخدمة غير فعّالة أو غير مكتملة (تحتاج 3 نقاط على الأقل).';
    return null;
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
