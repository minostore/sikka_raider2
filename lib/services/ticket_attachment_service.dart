import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'upload_http.dart';

class TicketAttachmentService {
  static const _extensions = ['jpg','jpeg','png','webp','pdf','doc','docx'];
  static const _defaultUploadApi = 'https://sikka.mohamedmini2006.workers.dev';

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
    final cfg = (await FirebaseDatabase.instance.ref('settings/uploadApi').get()).value?.toString();
    final base = (cfg != null && cfg.trim().isNotEmpty) ? cfg.trim() : _defaultUploadApi;
    final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (token == null || token.isEmpty) throw Exception('انتهت جلسة الدخول. سجّل الدخول مرة أخرى.');
    final safeName = file.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final key = 'support_${ticketId}_${DateTime.now().microsecondsSinceEpoch}_$safeName';
    final endpoint = Uri.parse('${base.replaceAll(RegExp(r'/+$'), '')}/upload/$key');
    final response = await putFollowingRedirects(endpoint, headers: {'Authorization':'Bearer $token','Content-Type':mime}, body: bytes);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = response.body.trim();
      throw HttpException('فشل رفع المرفق (HTTP ${response.statusCode})${detail.isEmpty ? '' : ': ${detail.substring(0, detail.length > 160 ? 160 : detail.length)}'}');
    }
    String? url;
    try { final payload = jsonDecode(response.body); if (payload is Map) url = (payload['url'] ?? payload['publicUrl'] ?? payload['downloadUrl'])?.toString(); } catch (_) {}
    if (url == null || !url.startsWith('https://')) throw Exception('تم رفع الملف لكن خدمة الرفع لم تُرجع رابطًا صالحًا. تحقق من إعداد Public URL في Worker.');
    return {'storagePath': key, 'downloadUrl': url, 'name': file.name, 'contentType': mime, 'size': file.size};
  }
}
