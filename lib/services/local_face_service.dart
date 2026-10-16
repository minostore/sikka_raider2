import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// نتيجة تحليل صورة وجه واحدة على الجهاز.
class FaceAnalysis {
  final bool ok;
  final String? reason; // no_face | multiple_faces | face_too_small | face_cut | bad_angle | decode_failed | model_missing | error
  final List<double>? embedding;
  const FaceAnalysis.fail(this.reason) : ok = false, embedding = null;
  const FaceAnalysis.ok(this.embedding) : ok = true, reason = null;
}

/// فحص الوجه على الجهاز: ML Kit لاكتشاف الوجه وجودته، ونموذج TFLite لاستخراج تمثيل رقمي ومقارنته.
/// تنبيه أمني: ما يُحسب على الجهاز يمكن العبث به؛ لذلك نتيجته «مبدئية» فقط، والقرار النهائي للإدارة.
class LocalFaceService {
  static const modelAsset = 'assets/models/mobilefacenet.tflite';
  static Interpreter? _interp;
  static final _detector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate, enableClassification: true, minFaceSize: 0.15),
  );

  static Future<Interpreter?> _model() async {
    if (_interp != null) return _interp;
    try {
      // تحقق من وجود الملف أولًا حتى لا يتوقف التطبيق إن لم يُضَف النموذج.
      await rootBundle.load(modelAsset);
      _interp = await Interpreter.fromAsset(modelAsset);
    } catch (_) {
      _interp = null;
    }
    return _interp;
  }

  /// [isSelfie]: للسيلفي نتشدد في الزاوية والحجم؛ لصورة البطاقة نتسامح لأن صورة الوجه فيها صغيرة.
  static Future<FaceAnalysis> analyze(String path, {required bool isSelfie}) async {
    try {
      final faces = await _detector.processImage(InputImage.fromFilePath(path));
      if (faces.isEmpty) return const FaceAnalysis.fail('no_face');
      // في صورة البطاقة قد يظهر وجه ثانوي (علامة مائية): نأخذ الأكبر. في السيلفي نشترط وجهًا واحدًا.
      if (isSelfie && faces.length > 1) return const FaceAnalysis.fail('multiple_faces');
      faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height).compareTo(a.boundingBox.width * a.boundingBox.height));
      final face = faces.first;

      final decoded = img.decodeImage(await File(path).readAsBytes());
      if (decoded == null) return const FaceAnalysis.fail('decode_failed');
      final image = img.bakeOrientation(decoded);
      final box = face.boundingBox;
      final area = (box.width * box.height) / (image.width * image.height);
      if (isSelfie) {
        if (area < 0.08) return const FaceAnalysis.fail('face_too_small');
        final yaw = (face.headEulerAngleY ?? 0).abs(), roll = (face.headEulerAngleZ ?? 0).abs();
        if (yaw > 20 || roll > 20) return const FaceAnalysis.fail('bad_angle');
        // قص شديد: الوجه ملاصق لحدود الصورة
        if (box.left < 2 || box.top < 2 || box.right > image.width - 2 || box.bottom > image.height - 2) return const FaceAnalysis.fail('face_cut');
      } else if (area < 0.002) {
        return const FaceAnalysis.fail('face_too_small');
      }

      final interp = await _model();
      if (interp == null) return const FaceAnalysis.fail('model_missing');

      // قص الوجه بهامش 20% ثم تحجيمه 112×112
      final cx = box.left + box.width / 2, cy = box.top + box.height / 2;
      final side = math.max(box.width, box.height) * 1.2;
      final x0 = (cx - side / 2).round().clamp(0, image.width - 1), y0 = (cy - side / 2).round().clamp(0, image.height - 1);
      final w = math.min(side.round(), image.width - x0), h = math.min(side.round(), image.height - y0);
      final crop = img.copyResize(img.copyCrop(image, x: x0, y: y0, width: w, height: h), width: 112, height: 112, interpolation: img.Interpolation.linear);

      final input = Float32List(1 * 112 * 112 * 3);
      var i = 0;
      for (var y = 0; y < 112; y++) {
        for (var x = 0; x < 112; x++) {
          final p = crop.getPixel(x, y);
          input[i++] = _normalize(p.r.toDouble());
          input[i++] = _normalize(p.g.toDouble());
          input[i++] = _normalize(p.b.toDouble());
        }
      }
      final outLen = interp.getOutputTensor(0).shape.last;
      final output = [List<double>.filled(outLen, 0)];
      interp.run(input.reshape([1, 112, 112, 3]), output);
      return FaceAnalysis.ok(_l2(output[0]));
    } catch (_) {
      return const FaceAnalysis.fail('error');
    }
  }

  static double _normalize(double v) => (v - 127.5) / 128.0;

  static List<double> _l2(List<double> v) {
    final n = math.sqrt(v.fold<double>(0, (s, e) => s + e * e));
    return n == 0 ? v : [for (final e in v) e / n];
  }

  /// تشابه جيب التمام بين متجهين مُطبَّعين (من -1 إلى 1).
  static double cosine(List<double> a, List<double> b) {
    var s = 0.0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      s += a[i] * b[i];
    }
    return s;
  }
}
