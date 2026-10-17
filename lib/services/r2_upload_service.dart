import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'upload_http.dart';

/// Uploads profile images through the existing Sikka Cloudflare Worker/R2 API.
/// Worker must accept the `profile` key for authenticated rider and driver accounts.
class R2UploadService {
  static const _defaultBase = 'https://www.sikka-eg.online';

  static Future<Map<String, String>> uploadProfileImage({required File file, required String role}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('سجّل الدخول مرة أخرى ثم حاول رفع الصورة.');
    final configured = (await FirebaseDatabase.instance.ref('settings/uploadApi').get()).value?.toString().trim();
    final base = (configured != null && configured.isNotEmpty ? configured : _defaultBase).replaceAll(RegExp(r'/+$'), '');
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) throw Exception('تعذر الحصول على رمز تسجيل الدخول. سجّل الدخول مرة أخرى.');
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('ملف الصورة فارغ. اختر صورة أخرى.');
    if (bytes.length > 8 * 1024 * 1024) throw Exception('حجم الصورة أكبر من 8 ميجابايت. اختر صورة أصغر.');
    // الطريقة الأساسية: رابط موقّع من خادم لوحة التحكم (الدومين الرسمي) ثم رفع مباشر إلى R2.
    try {
      final r = await http
          .post(Uri.parse('${AppConfig.adminApiBase}/api/user/profile-upload-url'),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({'size': bytes.length}))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) {
        var msg = 'HTTP ${r.statusCode}';
        try { msg = (jsonDecode(r.body) as Map)['error']?.toString() ?? msg; } catch (_) {}
        throw Exception('تعذر تجهيز رفع الصورة: $msg');
      }
      if (r.statusCode == 200) {
        final j = Map<String, dynamic>.from(jsonDecode(r.body) as Map);
        final up = (j['url'] ?? '').toString(), pub = (j['publicUrl'] ?? '').toString();
        if (up.startsWith('https://') && pub.startsWith('https://')) {
          final put = await putFollowingRedirects(Uri.parse(up), headers: {'Content-Type': 'image/jpeg'}, body: bytes);
          if (put.statusCode >= 200 && put.statusCode < 300) return {'url': pub, 'path': (j['key'] ?? '').toString()};
          throw Exception('فشل الرفع إلى التخزين (HTTP ${put.statusCode}). تحقق من إعدادات R2 وCORS.');
        }
      }
    } on Exception catch (e) {
      if (e.toString().contains('تعذر تجهيز') || e.toString().contains('فشل الرفع')) rethrow;
      throw Exception('تعذر الاتصال بخادم سِكّة. تحقق من الإنترنت.');
    }
    final response = await putFollowingRedirects(Uri.parse('$base/upload/profile'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'image/jpeg', 'X-Sikka-Profile-Role': role}, body: bytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var detail = response.body.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (detail.length > 180) detail = detail.substring(0, 180);
      throw HttpException('HTTP ${response.statusCode}${detail.isEmpty ? '' : ': $detail'}');
    }
    dynamic payload;
    try { payload = jsonDecode(response.body); } catch (_) {}
    if (payload is! Map) throw Exception('خدمة R2 لم تُرجع بيانات الصورة. راجع إعداد Worker.');
    final url = (payload['url'] ?? payload['publicUrl'] ?? payload['downloadUrl'] ?? '').toString();
    final path = (payload['key'] ?? payload['path'] ?? payload['objectKey'] ?? '').toString();
    if (!url.startsWith('https://')) throw Exception('Worker لم يُرجع رابط HTTPS صالحًا للصورة. راجع مسار /file.');
    return {'url': url, if (path.isNotEmpty) 'path': path};
  }
}
