import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_version.dart';

/// صفحة تحديث كاملة بحجم الهاتف: صورة + عنوان + وصف.
/// إجباري: لا يُفتح التطبيق قبل التحديث — اختياري: يظهر زر «تخطي».
class UpdateGate extends StatefulWidget {
  final String role; // rider | driver
  final Widget child;
  const UpdateGate({super.key, required this.role, required this.child});
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  String? _skipped;
  StreamSubscription<OtaEvent>? _ota;
  double? _progress; // null = لم يبدأ التنزيل
  String _otaMsg = '';

  @override
  void dispose() {
    _ota?.cancel();
    super.dispose();
  }

  bool _isApk(Map<String, dynamic> u, String url) {
    final name = (u['fileName'] ?? '').toString().toLowerCase();
    final path = (Uri.tryParse(url)?.path ?? '').toLowerCase();
    return name.endsWith('.apk') || path.endsWith('.apk');
  }

  /// تنزيل APK داخل التطبيق مع نسبة التقدم ثم فتح شاشة التثبيت. يطلب أندرويد موافقة المستخدم
  /// على «تثبيت التطبيقات غير المعروفة» لهذا التطبيق، ولا يمكن تجاوز ذلك. التحديث يجب أن يكون
  /// موقّعًا بنفس مفتاح النسخة المثبتة وإلا يرفضه النظام.
  void _install(Map<String, dynamic> u, String url, String version) {
    if (_ota != null) return;
    setState(() { _progress = 0; _otaMsg = 'جارٍ التنزيل…'; });
    final sha = (u['sha256'] ?? '').toString();
    try {
      _ota = OtaUpdate()
          .execute(url, destinationFilename: 'sikka-${widget.role}-$version.apk', sha256checksum: sha.length == 64 ? sha : null)
          .listen((e) {
        if (!mounted) return;
        final st = e.status.toString().split('.').last;
        if (st == 'DOWNLOADING') {
          setState(() { _progress = ((double.tryParse(e.value ?? '0') ?? 0) / 100).clamp(0.0, 1.0).toDouble(); _otaMsg = 'جارٍ التنزيل ${e.value ?? 0}%'; });
        } else if (st == 'INSTALLING') {
          setState(() { _progress = 1; _otaMsg = 'اكتمل التنزيل — اضغط «تثبيت» في الشاشة التي ستظهر'; });
        } else if (st == 'INSTALLATION_DONE') {
          setState(() => _otaMsg = 'تم التثبيت');
        } else {
          final reason = st == 'PERMISSION_NOT_GRANTED_ERROR'
              ? 'لم تُمنح صلاحية تثبيت التطبيقات. اسمح لهذا التطبيق من إعدادات الهاتف ثم أعد المحاولة.'
              : st == 'CHECKSUM_ERROR'
                  ? 'فشل التحقق من سلامة الملف. لا تُثبّت هذا التحديث.'
                  : st == 'ALREADY_RUNNING_ERROR'
                      ? 'التنزيل يعمل بالفعل.'
                      : st == 'CANCELED'
                          ? 'أُلغي التنزيل.'
                          : 'تعذر تنزيل أو تثبيت التحديث. تحقق من الإنترنت وأعد المحاولة.';
          _ota?.cancel();
          setState(() { _ota = null; _progress = null; _otaMsg = reason; });
        }
      }, onError: (_) {
        if (!mounted) return;
        _ota?.cancel();
        setState(() { _ota = null; _progress = null; _otaMsg = 'تعذر تنزيل التحديث. تحقق من الإنترنت وأعد المحاولة.'; });
      });
    } catch (_) {
      setState(() { _ota = null; _progress = null; _otaMsg = 'تعذر بدء التنزيل.'; });
    }
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _skipped = p.getString('skipped_update_${widget.role}') ?? '');
    });
  }

  int _cmp(String a, String b) {
    List<int> parse(String s) => s.split(RegExp(r'[^0-9]+')).where((e) => e.isNotEmpty).map((e) => int.tryParse(e) ?? 0).toList();
    final x = parse(a), y = parse(b);
    for (var i = 0; i < (x.length > y.length ? x.length : y.length); i++) {
      final xv = i < x.length ? x[i] : 0, yv = i < y.length ? y[i] : 0;
      if (xv != yv) return xv.compareTo(yv);
    }
    return 0;
  }

  Future<void> _skip(String version) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('skipped_update_${widget.role}', version);
    if (mounted) setState(() => _skipped = version);
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('appUpdates').onValue,
        builder: (context, snap) {
          final raw = snap.data?.snapshot.value;
          if (raw is! Map || _skipped == null) return widget.child;
          final items = <Map<String, dynamic>>[];
          raw.forEach((id, v) {
            if (v is Map) {
              final m = Map<String, dynamic>.from(v);
              final t = (m['target'] ?? '').toString();
              if (m['active'] == true && (t == widget.role || t == 'both')) items.add(m);
            }
          });
          items.sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
          if (items.isEmpty) return widget.child;
          final u = items.first;
          final version = (u['version'] ?? '').toString();
          if (version.isEmpty || _cmp(version, AppVersion.current) <= 0) return widget.child;
          final mandatory = u['mandatory'] == true;
          if (!mandatory && _skipped == version) return widget.child;
          final url = (u['downloadUrl'] ?? u['linkUrl'] ?? '').toString();
          final image = (u['imageUrl'] ?? '').toString();
          return Directionality(
            textDirection: TextDirection.rtl,
            child: PopScope(
              canPop: false,
              child: Scaffold(
                backgroundColor: const Color(0xFF0B1B2E),
                body: Stack(fit: StackFit.expand, children: [
                  if (image.startsWith('https://'))
                    Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x55000000), Color(0x00000000), Color(0xE6000000)], stops: [0, .4, 1]),
                    ),
                  ),
                  if (!mandatory)
                    SafeArea(
                      child: Align(
                        alignment: AlignmentDirectional.topEnd,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: TextButton(
                            style: TextButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white),
                            onPressed: () => _skip(version),
                            child: const Text('تخطي'),
                          ),
                        ),
                      ),
                    ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text((u['title'] ?? 'تحديث جديد').toString(), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFFD84D), fontSize: 26, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Text((u['message'] ?? '').toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6)),
                          const SizedBox(height: 18),
                          if (_progress != null) ...[
                            LinearProgressIndicator(value: _progress, minHeight: 8, borderRadius: BorderRadius.circular(8)),
                            const SizedBox(height: 8),
                          ],
                          if (_otaMsg.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(_otaMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFCC00), foregroundColor: const Color(0xFF061B31), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                              onPressed: url.isEmpty || _ota != null ? null : () => (Platform.isAndroid && _isApk(u, url)) ? _install(u, url, version) : _open(url),
                              child: Text(_ota != null ? 'جارٍ التحديث…' : 'تحديث الآن'),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      );
}
