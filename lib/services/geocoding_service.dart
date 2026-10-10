import 'dart:convert';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../models/place.dart';

/// بحث العناوين عبر Nominatim (OpenStreetMap).
/// تنبيه: الخادم العام محدود (طلب واحد/ثانية تقريباً) — استخدم debounce ولا تعتمد عليه للإنتاج الكثيف.
class GeocodingService {
  static const _headers = {'User-Agent': AppConfig.userAgent};

  static Future<List<Place>> search(String q, {LatLng? near}) async {
    final params = <String, String>{
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'accept-language': 'ar',
      'countrycodes': 'eg', // البحث داخل مصر فقط
    };
    if (near != null) {
      params['viewbox'] =
          '${near.longitude - 0.6},${near.latitude + 0.6},${near.longitude + 0.6},${near.latitude - 0.6}';
    }
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('خدمة البحث لا تستجيب (${res.statusCode})');
    }
    final list = jsonDecode(res.body) as List;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return Place(double.parse(m['lat'].toString()), double.parse(m['lon'].toString()),
          (m['display_name'] ?? m['name'] ?? '').toString());
    }).toList();
  }

  static Future<String> reverse(LatLng p) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': p.latitude.toString(),
        'lon': p.longitude.toString(),
        'format': 'jsonv2',
        'accept-language': 'ar',
      });
      final res = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final m = jsonDecode(res.body) as Map<String, dynamic>;
        final name = m['display_name']?.toString();
        if (name != null && name.isNotEmpty) return name;
      }
    } catch (_) {}
    try {
      final list = await gc.placemarkFromCoordinates(p.latitude, p.longitude);
      if (list.isNotEmpty) {
        final x = list.first;
        final parts = [x.street, x.subLocality, x.locality]
            .where((s) => s != null && s.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) return parts.join('، ');
      }
    } catch (_) {}
    return '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
  }
}
