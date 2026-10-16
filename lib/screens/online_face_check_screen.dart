import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  int _frames = 0;

  @override
  void initState() { super.initState(); _initCamera(); }

  Future<void> _initCamera() async {
    try {
      final cams = await availableCameras();
      final front = cams.where((c) => c.lensDirection == CameraLensDirection.front).toList();
      if (front.isEmpty) throw Exception('الكاميرا الأمامية غير متاحة');
      final c = CameraController(front.first, ResolutionPreset.medium, enableAudio: false, imageFormatGroup: ImageFormatGroup.yuv420);
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
      final rotation = InputImageRotationValue.fromRawValue(c.description.sensorOrientation);
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (rotation == null || format == null) return;
      final buffer = WriteBuffer();
      for (final plane in image.planes) { buffer.putUint8List(plane.bytes); }
      final bytes = buffer.done().buffer.asUint8List();
      final input = InputImage.fromBytes(bytes: bytes, metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ));
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
    } catch (_) {
      // transient frame conversion errors are ignored; subsequent frames retry.
    } finally { _processing = false; }
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
      setState(() => _message = 'جارٍ مقارنة الوجه بالصورة المعتمدة…');
      final result = await FaceVerifyService.verifyOnlineSelfie(File(shot.path));
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
            'approved_selfie_missing' => 'لا توجد صورة سيلفي معتمدة. تواصل مع الدعم.',
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
        const Padding(padding: EdgeInsets.symmetric(horizontal: 24), child: Text('لأمان حسابك، التقط التطبيق صورة جديدة بعد التأكد من حركة الوجه، ثم يقارنها بصورة المستندات المعتمدة.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 15))),
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
