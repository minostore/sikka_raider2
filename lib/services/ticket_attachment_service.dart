import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';

class TicketAttachmentService {
  static const _extensions = ['jpg','jpeg','png','webp','pdf','doc','docx'];
  static const _defaultUploadApi = 'https://www.sikka-eg.online';

  static Future<Map<String, dynamic>?> pickAndUpload({required String uid, required String ticketId}) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: _extensions, withData: true);
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.size > 15 * 1024 * 1024) throw Exception('الحد الأقصى لحجم الملف 15 ميجابايت.');
    final ext = (file.extension ?? '').toLowerCase();
    if (!_extensions.contains(ext)) throw Exception('نوع الملف غير مدعوم.');
    final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
    if (bytes == null || bytes.isEmpty) throw Exception('تعذر قراءة الملف المحدد. اختر الملف مرة أخرى.');
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg', 'png' => 'image/png', 'webp' => 'image/webp',
      'pdf' => 'application/pdf', 'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      _ => 'application/octet-stream',
    };
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (token == null || token.isEmpty) throw Exception('انتهت جلسة الدخول. سجّل الدخول مرة أخرى.');
    // رفع مباشر إلى R2 برابط موقّع من خادم سِكّة (بدون Worker ولا workers.dev).
    final base = AppConfig.adminApiBase.replaceAll(RegExp(r'/+$'), '');
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final key = 'support_${ticketId}_${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final prep = await http
        .post(Uri.parse('$base/api/user/attachment-upload-url'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({'ext': ext, 'contentType': mime, 'size': bytes.length}))
        .timeout(const Duration(seconds: 60));
    if (prep.statusCode != 200) {
      var msg = 'HTTP ${prep.statusCode}';
      try { msg = (jsonDecode(prep.body) as Map)['error']?.toString() ?? msg; } catch (_) {}
      throw Exception('تعذر تجهيز رفع المرفق: $msg');
    }
    final j = Map<String, dynamic>.from(jsonDecode(prep.body) as Map);
    final put = await http.put(Uri.parse(j['url'].toString()), headers: {'Content-Type': mime}, body: bytes).timeout(const Duration(minutes: 10));
    if (put.statusCode < 200 || put.statusCode >= 300) throw Exception('فشل رفع المرفق إلى التخزين (HTTP ${put.statusCode}).');
    final url = j['publicUrl'].toString();
    if (!url.startsWith('https://')) throw Exception('لم تُرجع خدمة الرفع رابطًا صالحًا.');
    return {'storagePath': key, 'downloadUrl': url, 'name': file.name, 'contentType': mime, 'size': file.size};
  }
}
