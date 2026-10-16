import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show DeviceOrientation;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_verify_service.dart';

/// Live liveness check: requires a detected blink and a small head turn, then
/// sends the newly captured frame to the server for comparison with approved documents.
class OnlineFaceCheckScreen extends StatefulWidget {
  const OnlineFaceCheckScreen({super.key});
  @override
  State<OnlineFaceCheckScreen> createState() => _OnlineFaceCheckScreenState();
}

class _OnlineFaceCheckScreenState extends State<OnlineFaceCheckScreen> {
  CameraController? _camera;
  final FaceDetector _detector = FaceDetector(options: FaceDetectorOptions(
    performanceMode: FaceDetectorMode.accurate,
    enableClassification: true,
    enableLandmarks: true,
    enableContours: false,
    minFaceSize: 0.18,
  ));
  bool _busy = false, _processing = false, _blinkClosed = false;
  bool _blinkDone = false, _turned = false, _returnedCenter = false;
  double? _initialYaw;
  String _message = 'ضع وجهك داخل الإطار وانظر إلى الكاميرا';
  int _frames = 0, _errors = 0;
  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() { super.initState(); _initCamera(); }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final front = cams.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      if (front.isEmpty) throw Exception('الكاميرا الأمامية غير متاحة');
      final c = CameraController(front.first, ResolutionPreset.high, enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888);
      await c.initialize();
      if (!mounted) { await c.dispose(); return; }
      _camera = c;
      await c.startImageStream(_onFrame);
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _message = 'تعذر تشغيل الكاميرا: $e');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    final c = _camera;
    if (c == null || _processing || _busy || !c.value.isStreamingImages) return;
    _processing = true;
    try {
      // Process every third frame to keep mid-range Android phones responsive.
      _frames++;
      if (_frames % 3 != 0) return;
      final input = _toInputImage(c, image);
      if (input == null) {
        if (++_errors >= 8 && mounted) setState(() => _message = 'تعذر قراءة صورة الكاميرا على هذا الجهاز.');
        return;
      }
      final faces = await _detector.processImage(input);
      if (!mounted || _busy) return;
      if (faces.length != 1) {
        setState(() => _message = faces.isEmpty ? 'قرّب وجهك من الكاميرا' : 'يجب أن يظهر وجه واحد فقط');
        return;
      }
      final f = faces.first;
      final left = f.leftEyeOpenProbability, right = f.rightEyeOpenProbability;
      final eyes = left != null && right != null ? (left + right) / 2 : null;
      final yaw = f.headEulerAngleY ?? 0;
      if (_initialYaw == null && yaw.abs() < 10) _initialYaw = yaw;
      if (eyes != null && eyes < 0.25) _blinkClosed = true;
      if (_blinkClosed && eyes != null && eyes > 0.70) _blinkDone = true;
      if (_initialYaw != null && (yaw - _initialYaw!).abs() >= 12) _turned = true;
      if (_turned && yaw.abs() < 8) _returnedCenter = true;
      if (_blinkDone && _returnedCenter && (eyes == null || eyes > 0.45)) {
        setState(() => _message = 'تم التأكد من الحركة، جارٍ التقاط الصورة والتحقق…');
        await _captureAndVerify();
        return;
      }
      setState(() {
        if (!_blinkDone) _message = 'ارمش بعينيك مرة واحدة';
        else if (!_turned) _message = 'حرّك رأسك قليلًا يمينًا أو يسارًا';
        else if (!_returnedCenter) _message = 'ارجع برأسك للأمام';
        else _message = 'ثبّت وجهك وانظر إلى الكاميرا';
      });
      _errors = 0;
    } catch (e) {
      if (++_errors >= 8 && mounted) setState(() => _message = 'تعذر تحليل الوجه: $e');
    } finally { _processing = false; }
  }


  /// يبني InputImage بالصيغة والدوران الذي يتوقعه ML Kit (NV21 على أندرويد، BGRA على iOS).
  InputImage? _toInputImage(CameraController c, CameraImage image) {
    final sensor = c.description.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      var comp = _orientations[c.value.deviceOrientation] ?? 0;
      comp = c.description.lensDirection == CameraLensDirection.front ? (sensor + comp) % 360 : (sensor - comp + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || (Platform.isAndroid && format != InputImageFormat.nv21) || (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(size: Size(image.width.toDouble(), image.height.toDouble()), rotation: rotation, format: format, bytesPerRow: plane.bytesPerRow),
    );
  }

  Future<FaceVerifyResult> _compare(File shot) async {
    // The trusted server performs selfie-to-selfie matching and issues the
    // short-lived authorization required by Firebase rules. Face detection alone
    // must never grant online access.
    try {
      return await FaceVerifyService.verifyOnlineSelfie(shot);
    } catch (_) {
      return const FaceVerifyResult('failed', 'service_unavailable');
    }
  }

  Future<void> _captureAndVerify() async {
    if (_busy) return;
    _busy = true;
    final c = _camera;
    try {
      if (c == null || !c.value.isInitialized) throw Exception('الكاميرا غير جاهزة');
      if (c.value.isStreamingImages) await c.stopImageStream();
      final shot = await c.takePicture();
      if (!mounted) return;
      setState(() => _message = 'جارٍ مقارنة وجهك بالسيلفي المعتمدة…');
      final result = await _compare(File(shot.path));
      if (!mounted) return;
      if (result.status == 'verified') {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _busy = false;
          _message = switch (result.reason) {
            'mismatch' => 'الوجه غير مطابق للصورة المعتمدة. أعد المحاولة بإضاءة جيدة.',
            'no_face' => 'لم يظهر وجه واضح. أعد المحاولة.',
            'multiple_faces' => 'يجب أن يظهر وجه واحد فقط داخل الإطار.',
            'low_quality' => 'الإضاءة أو وضوح الصورة غير كافٍ. أعد المحاولة.',
            'face_too_small' => 'قرّب وجهك أكثر من الكاميرا.',
            'face_cut' => 'ضع وجهك بالكامل داخل الإطار.',
            'bad_angle' => 'انظر مباشرة إلى الكاميرا دون إمالة.',
            'low_similarity' || 'borderline' => 'الوجه غير مطابق للصورة المعتمدة. أعد المحاولة بإضاءة جيدة.',
            'model_missing' => 'نموذج التحقق غير مثبت في التطبيق. تواصل مع الدعم.',
            'service_unavailable' => 'خدمة التحقق غير متاحة الآن. أعد المحاولة بعد قليل.',
            'no_reference' => 'لا توجد صورة معتمدة للمقارنة. تواصل مع الدعم.',
            'approved_selfie_missing' => 'لا توجد صورة سيلفي معتمدة. ارفع السيلفي أولًا أو تواصل مع الدعم.',
            _ => 'تعذر تأكيد الهوية (${result.reason ?? 'سبب غير معروف'}). أعد المحاولة.'
          };
          _blinkClosed = false; _blinkDone = false; _turned = false; _returnedCenter = false; _initialYaw = null;
        });
        await c.startImageStream(_onFrame);
      }
    } catch (e) {
      if (mounted) {
        setState(() { _busy = false; _message = 'تعذر التحقق: $e. يمكنك إعادة المحاولة.'; });
        try { if (c != null && c.value.isInitialized && !c.value.isStreamingImages) await c.startImageStream(_onFrame); } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    try { _camera?.stopImageStream(); } catch (_) {}
    _camera?.dispose(); _detector.close(); super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _camera;
    return Scaffold(
      backgroundColor: const Color(0xFF071426),
      appBar: AppBar(title: const Text('التحقق من الوجه'), backgroundColor: const Color(0xFF071426), foregroundColor: Colors.white),
      body: SafeArea(child: Column(children: [
        const SizedBox(height: 18),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('لأمان حسابك، التقط التطبيق صورة جديدة بعد التأكد من حركة الوجه، ثم يقارنها بصورة السيلفي التي رفعتها سابقًا، وليس بصورة البطاقة.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 15))),
        const SizedBox(height: 18),
        Expanded(child: Center(child: c != null && c.value.isInitialized
          ? ClipRRect(borderRadius: BorderRadius.circular(24), child: AspectRatio(aspectRatio: 1 / c.value.aspectRatio, child: CameraPreview(c)))
          : const CircularProgressIndicator(color: Colors.white))),
        Container(margin: const EdgeInsets.all(20), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF142940), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.face_retouching_natural, color: Colors.lightBlueAccent, size: 30), const SizedBox(width: 12), Expanded(child: Text(_message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))])),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('إلغاء')))),
      ])),
    );
  }
}
