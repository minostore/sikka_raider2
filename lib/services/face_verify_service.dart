import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import 'local_face_service.dart';

/// نتيجة التحقق المعروضة للسائق.
/// status: preliminary_match | mismatch | review | unreadable (محلي) — أو verified/manual_approved/failed (من الخادم).
class FaceVerifyResult {
  final String status;
  final String? reason;
  const FaceVerifyResult(this.status, this.reason);
  bool get passed => status == 'preliminary_match' || status == 'verified' || status == 'manual_approved';
}


/// يصغّر الصورة الحية (أقصى عرض 960px، JPEG 85) لتناسب حدود خدمات التعرف على الوجه وتسرّع الإرسال.
Uint8List _prepareLive(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  var im = img.bakeOrientation(decoded);
  if (im.width > 960) im = img.copyResize(im, width: 960);
  return Uint8List.fromList(img.encodeJpg(im, quality: 85));
}

class FaceVerifyService {
  static const _defaults = {'matchThreshold': 0.60, 'reviewThreshold': 0.40};

  static Future<Map<String, dynamic>> _cfg() async {
    final out = <String, dynamic>{..._defaults};
    try {
      final v = (await FirebaseDatabase.instance.ref('settings/faceVerification').get()).value;
      if (v is Map) {
        for (final k in ['matchThreshold', 'reviewThreshold', 'provider']) {
          if (v[k] != null) out[k] = v[k];
        }
      }
    } catch (_) {}
    return out;
  }

  /// يحلل السيلفي وصور المستندات على الجهاز، ثم يكتب النتيجة المبدئية في Firebase لتظهر في لوحة التحكم.
  /// لا تمنح هذه النتيجة صلاحية العمل: الصلاحية تأتي فقط من driverVerification (الخادم/الإدارة).
  static Future<FaceVerifyResult> runLocal({required String? selfiePath, required Map<String, String> idPaths}) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final cfg = await _cfg();
    final matchT = (cfg['matchThreshold'] as num).toDouble(), reviewT = (cfg['reviewThreshold'] as num).toDouble();

    String status;
    String? reason;
    double? score;
    String? matchedDoc;

    if (selfiePath == null || idPaths.isEmpty) {
      status = 'review';
      reason = 'no_local_copy'; // لا توجد نسخة محلية من الصور في هذه الجلسة → قرار موظف
    } else {
      final selfie = await LocalFaceService.analyze(selfiePath, isSelfie: true);
      if (!selfie.ok) {
        reason = selfie.reason;
        status = const ['no_face', 'multiple_faces', 'face_too_small', 'face_cut', 'bad_angle'].contains(reason)
            ? 'mismatch'
            : 'unreadable';
      } else {
        double? best;
        String? bestKey;
        String? idFail;
        for (final e in idPaths.entries) {
          final id = await LocalFaceService.analyze(e.value, isSelfie: false);
          if (!id.ok) {
            idFail = id.reason;
            continue;
          }
          final s = LocalFaceService.cosine(selfie.embedding!, id.embedding!);
          if (best == null || s > best) {
            best = s;
            bestKey = e.key;
          }
        }
        if (best == null) {
          status = 'unreadable';
          reason = idFail == 'model_missing' ? 'model_missing' : 'id_unreadable';
        } else {
          score = double.parse(best.toStringAsFixed(3));
          matchedDoc = bestKey;
          if (best >= matchT) {
            status = 'preliminary_match';
          } else if (best >= reviewT) {
            status = 'review';
            reason = 'borderline';
          } else {
            status = 'mismatch';
            reason = 'low_similarity';
          }
        }
      }
    }

    await FirebaseDatabase.instance.ref('driverFaceCheck/$uid').set({
      'status': status,
      if (score != null) 'score': score,
      if (reason != null) 'reason': reason,
      if (matchedDoc != null) 'idKey': matchedDoc,
      'liveness': false, // لم يُنفَّذ فحص حيوية؛ يراجع الموظف الصورة بنفسه
      'model': 'mobilefacenet-local',
      'createdAt': ServerValue.timestamp,
    });

    // المقارنة الموثوقة على الخادم (قراءة الصور من R2 مباشرة). إن تعذر الوصول نعتمد النتيجة المبدئية فقط.
    try {
      return await runServer();
    } catch (_) {}
    return FaceVerifyResult(status, reason);
  }

  static Future<String> _base() async {
    try {
      final v = (await FirebaseDatabase.instance.ref('settings/adminApiUrl').get()).value?.toString().trim() ?? '';
      if (v.startsWith('https://')) return v.replaceAll(RegExp(r'/+$'), '');
    } catch (_) {}
    return AppConfig.adminApiBase.replaceAll(RegExp(r'/+$'), '');
  }

  /// مقارنة على الخادم (AWS Rekognition) — اختيارية.
  static Future<FaceVerifyResult> runServer() async {
    final base = await _base();
    if (base.isEmpty) throw Exception('عنوان خادم التحقق غير مضبوط (settings/adminApiUrl).');
    final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
    final res = await http
        .post(Uri.parse('$base/api/driver/face-verify'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}, body: '{}')
        .timeout(const Duration(seconds: 60));
    final j = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception((j is Map ? j['error'] : null)?.toString() ?? 'تعذر التحقق (HTTP ${res.statusCode})');
    }
    return FaceVerifyResult((j['status'] ?? 'review').toString(), j['reason']?.toString());
  }

  /// يتحقق الخادم من صورة حية جديدة مقابل صورة السيلفي المعتمدة والمستندات؛ لا تُحفظ الصورة الجديدة.
  static Future<FaceVerifyResult> verifyOnlineSelfie(File selfie) async {
    final base = await _base();
    if (base.isEmpty) throw Exception('عنوان خادم التحقق غير مضبوط (settings/adminApiUrl).');
    final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
    final bytes = await compute(_prepareLive, await selfie.readAsBytes());
    final encoded = base64Encode(bytes);
    final res = await http.post(
      Uri.parse('$base/api/driver/online-face-verify'),
      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      body: jsonEncode({'selfieBase64': encoded}),
    )
.timeout(const Duration(seconds: 60));
    final j = jsonDecode(res.body.isEmpty ? '{}' : res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception((j is Map ? j['error'] : null)?.toString() ?? 'تعذر التحقق (HTTP ${res.statusCode})');
    }
    return FaceVerifyResult((j['status'] ?? 'review').toString(), j['reason']?.toString());
  }

  /// هل يُسمح للسائق بالاتصال؟ فقط عند verified (الخادم) أو manual_approved (الإدارة)، أو إيقاف الإلزام.
  static Future<bool> allowedOnline(String uid) async {
    final db = FirebaseDatabase.instance.ref();
    final enforce = (await db.child('settings/faceVerification/enforce').get()).value;
    if (enforce == false) return true;
    final st = (await db.child('driverVerification/$uid/status').get()).value?.toString();
    return st == 'verified' || st == 'manual_approved';
  }
}
