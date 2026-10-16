import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/face_verify_service.dart';
import '../widgets/common.dart';

/// شاشة التحقق من تطابق الوجه (على الجهاز) مع موافقة صريحة من السائق.
/// الرسائل المتتابعة للعرض فقط؛ النتيجة تأتي من تحليل فعلي للصورتين.
/// النتيجة مبدئية: لا تمنح صلاحية العمل، والإدارة هي من تعتمد.
/// تُرجع: 'passed' | 'review' | 'failed' | 'error'
class FaceVerifyScreen extends StatefulWidget {
  final String? selfiePath;
  final Map<String, String> idPaths;
  const FaceVerifyScreen({super.key, required this.selfiePath, required this.idPaths});
  @override
  State<FaceVerifyScreen> createState() => _FaceVerifyScreenState();
}

class _FaceVerifyScreenState extends State<FaceVerifyScreen> {
  static const _steps = [
    'جاري فحص وضوح الصورة…',
    'جاري تحديد ملامح الوجه…',
    'جاري مقارنة السيلفي بصورة الوجه في المستند…',
    'جاري تجهيز نتيجة التحقق…',
  ];
  int _i = 0;
  Timer? _t;
  FaceVerifyResult? _r;
  String? _err;
  bool _consented = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (mounted && _consented && _r == null && _err == null && _i < _steps.length - 1) setState(() => _i++);
    });
  }

  Future<void> _consent() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      await FirebaseDatabase.instance.ref('drivers/$uid/faceConsentAt').set(ServerValue.timestamp);
    } catch (_) {}
    setState(() => _consented = true);
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _r = null;
      _err = null;
      _i = 0;
    });
    try {
      final r = await FaceVerifyService.runLocal(selfiePath: widget.selfiePath, idPaths: widget.idPaths);
      if (mounted) setState(() => _r = r);
    } catch (e) {
      if (mounted) setState(() => _err = errorMessage(e, fallback: 'تعذر إكمال التحقق'));
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _failText(String? reason) {
    switch (reason) {
      case 'no_face':
        return 'لم نجد وجهًا واضحًا في السيلفي. التقط صورة بوجهك مواجهًا للكاميرا وإضاءة جيدة.';
      case 'multiple_faces':
        return 'يوجد أكثر من وجه في الصورة. التقط سيلفي لوجهك وحدك.';
      case 'face_too_small':
        return 'وجهك صغير في الصورة. قرّب الكاميرا وأعد الالتقاط.';
      case 'face_cut':
        return 'الوجه مقصوص من حواف الصورة. اجعل وجهك بالكامل داخل الإطار.';
      case 'bad_angle':
        return 'انظر للكاميرا مباشرة دون إمالة الرأس ثم أعد الالتقاط.';
      default:
        return 'لم تتطابق الصورة مع المستند. أعد التقاط صورة واضحة لوجهك.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_consented) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.privacy_tip_outlined, size: 80, color: AppColors.primary),
              const SizedBox(height: 22),
              const Text('موافقة على معالجة صورة الوجه', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 12),
              const Text(
                'سنقارن صورة السيلفي بصورة وجهك في مستنداتك للتأكد أنك صاحب الحساب. يطّلع على الصور ونتيجة المقارنة فريق الإدارة المخوّل فقط، ولا تُعرض لأي عميل. يمكنك الاعتراض على النتيجة عبر الدعم.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 26),
              AppButton('أوافق وأتابع', onPressed: _consent),
              TextButton(onPressed: () => Navigator.pop(context, 'error'), child: const Text('رجوع', style: TextStyle(color: Colors.white54))),
            ]),
          ),
        ),
      );
    }
    final r = _r;
    final loading = r == null && _err == null;
    IconData icon = Icons.face_retouching_natural;
    Color color = AppColors.primary;
    String title = 'جاري التحقق من هويتك';
    String body = _steps[_i];
    String? action;
    String result = 'error';
    if (_err != null) {
      icon = Icons.error_outline;
      color = AppColors.red;
      title = 'تعذر التحقق';
      body = _err!;
      action = 'إعادة المحاولة';
    } else if (r != null) {
      if (r.passed) {
        icon = Icons.task_alt;
        color = AppColors.green;
        title = r.status == 'verified' ? 'تم التحقق من تطابق الوجه بنجاح' : 'تم التحقق المبدئي من تطابق الوجه';
        body = 'تم إرسال النتيجة للإدارة. لن يتفعل حسابك قبل مراجعتها واعتمادها.';
        action = 'متابعة';
        result = 'passed';
      } else if (r.status == 'review' || r.status == 'unreadable') {
        icon = Icons.hourglass_top;
        color = AppColors.orange;
        title = 'طلبك قيد المراجعة اليدوية';
        body = 'سيراجع أحد أعضاء الفريق صورتك ومستنداتك ويخطرك بالنتيجة.';
        action = 'متابعة';
        result = 'review';
      } else {
        icon = Icons.cancel;
        color = AppColors.red;
        title = 'لم يتم التحقق';
        body = _failText(r.reason);
        action = 'إعادة التقاط السيلفي';
        result = 'failed';
      }
    }
    return PopScope(
      canPop: !loading,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              loading ? SizedBox(width: 96, height: 96, child: CircularProgressIndicator(strokeWidth: 5, color: color)) : Icon(icon, size: 96, color: color),
              const SizedBox(height: 26),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(body, key: ValueKey(body), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
              ),
              const SizedBox(height: 30),
              if (action != null) AppButton(action, onPressed: () => _err != null ? _run() : Navigator.pop(context, result)),
            ]),
          ),
        ),
      ),
    );
  }
}
