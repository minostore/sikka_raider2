import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'admin_api.dart';

/// حالة الكابتن المالية. الحساب والإيقاف يتمان على الخادم فقط؛ التطبيق يعرض ويطلب المزامنة.
class DriverFinance {
  final double due, max, percent;
  final bool blocked;
  final List<Map<String, dynamic>> methods, tx;
  const DriverFinance({this.due = 0, this.max = 0, this.percent = 0, this.blocked = false, this.methods = const [], this.tx = const []});
  double get ratio => max > 0 ? (due / max).clamp(0.0, 1.0).toDouble() : 0;
  bool get near => max > 0 && due >= max * 0.8;
}

class FinanceService {
  static Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  /// يحتسب عمولة الرحلات المكتملة التي لم تُحتسب بعد (يمكن تمرير رقم رحلة محدد). آمن للتكرار.
  static Future<void> sync({String? rideId}) async {
    try {
      final base = await AdminApi.base();
      await http
          .post(Uri.parse('$base/api/driver/finance/sync'), headers: await _headers(), body: jsonEncode({if (rideId != null) 'rideId': rideId}))
          .timeout(const Duration(seconds: 20));
    } catch (_) {}
  }

  static Future<DriverFinance> load() async {
    final base = await AdminApi.base();
    final r = await http.get(Uri.parse('$base/api/driver/finance'), headers: await _headers()).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      var msg = 'HTTP ${r.statusCode}';
      try { msg = (jsonDecode(r.body) as Map)['error']?.toString() ?? msg; } catch (_) {}
      throw Exception(msg);
    }
    final j = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    List<Map<String, dynamic>> list(dynamic v) => (v is List ? v : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    double num_(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
    return DriverFinance(due: num_(j['due']), max: num_(j['max']), percent: num_(j['percent']), blocked: j['blocked'] == true, methods: list(j['methods']), tx: list(j['tx']));
  }
}
