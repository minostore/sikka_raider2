import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'admin_api.dart';
import 'upload_http.dart';

/// رفع مستندات السائق مباشرة إلى Cloudflare R2 برابط موقّع يصدره خادم لوحة التحكم.
/// لا يمر عبر Worker، فلا يتأثر بـ Cloudflare Access (302) ولا بمفتاح Firebase في Worker (401).
class DocUploadService {
  static Future<String> _base() => AdminApi.base();

  /// يُرجع مفتاح الكائن في R2 عند النجاح، أو null إن لم تتوفر الطريقة (فنرجع للطريقة الاحتياطية).
  /// يرمي استثناءً فقط إذا نجح تجهيز الرابط ثم فشل الرفع الفعلي إلى R2.
  static Future<String?> putDirect({required String key, required List<int> bytes, required String contentType}) async {
    final base = await _base();
    if (base.isEmpty) return null;
    Map<String, dynamic> j;
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
      final r = await http
          .post(Uri.parse('$base/api/driver/doc-upload-url'),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({'key': key, 'size': bytes.length}))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      j = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    } catch (_) {
      return null;
    }
    final url = (j['url'] ?? '').toString(), objectKey = (j['key'] ?? '').toString();
    if (!url.startsWith('https://') || objectKey.isEmpty) return null;
    final put = await putFollowingRedirects(Uri.parse(url), headers: {'Content-Type': contentType}, body: bytes);
    if (put.statusCode < 200 || put.statusCode >= 300) {
      throw Exception('فشل الرفع إلى التخزين (HTTP ${put.statusCode}). تحقق من مفاتيح R2 في Vercel.');
    }
    return objectKey;
  }
}
