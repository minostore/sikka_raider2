import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';

/// عنوان خادم لوحة التحكم (الدومين الرسمي: AppConfig.adminApiBase).
/// يجرّب الثابت أولًا ثم settings/adminApiUrl من Firebase، ويختار أول عنوان يستجيب لـ /api/health.
class AdminApi {
  static String? _cached;

  static Future<String> base() async {
    if (_cached != null) return _cached!;
    final candidates = <String>[];
    void add(String? v) {
      final u = (v ?? '').trim().replaceAll(RegExp(r'/+$'), '');
      if (u.startsWith('https://') && !candidates.contains(u)) candidates.add(u);
    }

    add(AppConfig.adminApiBase);
    try {
      add((await FirebaseDatabase.instance.ref('settings/adminApiUrl').get()).value?.toString());
    } catch (_) {}
    for (final b in candidates) {
      try {
        final r = await http.get(Uri.parse('$b/api/health')).timeout(const Duration(seconds: 6));
        if (r.statusCode == 200 && (jsonDecode(r.body) as Map)['ok'] == true) return _cached = b;
      } catch (_) {}
    }
    return candidates.isEmpty ? '' : candidates.first;
  }
}
