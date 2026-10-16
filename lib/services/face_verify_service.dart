import 'dart:convert';
import 'dart:io';
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

    return FaceVerifyResult(status, reason);
  }

  static Future<String> _base() async {
    try {
      final v = (await FirebaseDatabase.instance.ref('settings/adminApiUrl').get()).value?.toString().trim() ?? '';
      if (v.startsWith('https://')) return v.replaceAll(RegExp(r'/+$'), '');
    } catch (_) {}
    return AppConfig.adminApiBase.replaceAll(RegExp(r'/+$'), '');
  }

  /// التحقق عند «متصل» بمكتبات فلاتر على الجهاز: الصورة الحية ↔ السيلفي المعتمدة (ليست البطاقة).
  /// الخادم يسلّم الصورة المعتمدة فقط، ثم يُصدر تصريح الاتصال بعد نجاح المقارنة.
  static Future<FaceVerifyResult> verifyOnlineDevice(File live) async {
    final cfg = await _cfg();
    final matchT = (cfg['matchThreshold'] as num).toDouble(), reviewT = (cfg['reviewThreshold'] as num).toDouble();
    final liveA = await LocalFaceService.analyze(live.path, isSelfie: true);
    if (!liveA.ok) return FaceVerifyResult('failed', liveA.reason);

    final base = await _base();
    if (base.isEmpty) return const FaceVerifyResult('review', 'service_unavailable');
    final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
    File? ref;
    try {
      final res = await http.get(Uri.parse('$base/api/driver/my-selfie'), headers: {'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) {
        String? reason;
        try { reason = (jsonDecode(res.body) as Map)['reason']?.toString(); } catch (_) {}
        return FaceVerifyResult('review', reason ?? 'approved_selfie_unreadable');
      }
      ref = File('${Directory.systemTemp.path}/approved_selfie_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.writeAsBytes(res.bodyBytes);
      final refA = await LocalFaceService.analyze(ref.path, isSelfie: false);
      if (!refA.ok) return FaceVerifyResult('review', refA.reason == 'model_missing' ? 'model_missing' : 'approved_selfie_unreadable');
      final score = LocalFaceService.cosine(liveA.embedding!, refA.embedding!);
      if (score < matchT) return FaceVerifyResult('failed', score >= reviewT ? 'borderline' : 'mismatch');
      final g = await http
          .post(Uri.parse('$base/api/driver/online-face-grant'),
              headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
              body: jsonEncode({'score': double.parse(score.toStringAsFixed(3)), 'liveness': true}))
          .timeout(const Duration(seconds: 30));
      final j = jsonDecode(g.body.isEmpty ? '{}' : g.body);
      if (g.statusCode != 200) return FaceVerifyResult('review', (j is Map ? j['error'] : null)?.toString() ?? 'service_unavailable');
      return FaceVerifyResult((j['status'] ?? 'review').toString(), j['reason']?.toString());
    } catch (_) {
      return const FaceVerifyResult('review', 'service_unavailable');
    } finally {
      try { await ref?.delete(); } catch (_) {}
    }
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
