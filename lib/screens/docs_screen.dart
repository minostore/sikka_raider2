import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'auth_driver.dart';
import 'splash_gate.dart';

const _defaultUploadApi = 'https://sikka.mohamedmini2006.workers.dev'; // خدمة sikka-uploads على Cloudflare (يمكن تغييرها من لوحة التحكم > الإعدادات)

const docLabels = {
  'license': 'رخصة القيادة',
  'registration': 'استمارة المركبة',
  'nationalId': 'الهوية الوطنية',
  'insurance': 'التأمين',
  'photo': 'صورة شخصية',
};
const docIcons = {
  'license': Icons.badge_outlined,
  'registration': Icons.directions_car_outlined,
  'nationalId': Icons.credit_card,
  'insurance': Icons.shield_outlined,
  'photo': Icons.account_box_outlined,
};

/// الخطوة 2: بيانات المركبة — الخطوة 3: رفع المستندات
class DocsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const DocsScreen({super.key, required this.data});
  @override
  State<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends State<DocsScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  late final Map<String, dynamic> _veh = asMap(widget.data['vehicle']);
  late final _model = TextEditingController(text: _veh['model']?.toString() ?? '');
  late final _year = TextEditingController(text: _veh['year']?.toString() ?? '');
  late final _color = TextEditingController(text: _veh['color']?.toString() ?? '');
  late final _plate = TextEditingController(text: _veh['plate']?.toString() ?? '');
  late Map<String, dynamic> _docs = asMap(widget.data['docs']);
  final Set<String> _uploading = {};
  bool _busy = false;
  late int _step = (_veh['plate'] ?? '').toString().isNotEmpty ? 3 : 2;

  bool _has(String k) {
    final d = asMap(_docs[k]);
    return d['path'] != null || d['url'] != null;
  }

  Future<void> _pick(String key) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
    if (x == null) return;
    setState(() => _uploading.add(key));
    try {
      // الرفع إلى Cloudflare R2 عبر خدمة sikka-uploads (عنوانها يُضبط من لوحة التحكم > الإعدادات)
      final cfg = (await FirebaseDatabase.instance.ref('settings/uploadApi').get()).value?.toString();
      final base = (cfg != null && cfg.trim().isNotEmpty) ? cfg.trim() : _defaultUploadApi;
      final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
      if (token == null || token.isEmpty) throw Exception('تعذر الحصول على رمز تسجيل الدخول. سجل الدخول مرة أخرى.');
      final bytes = await x.readAsBytes();
      final type = (x.mimeType != null && x.mimeType!.startsWith('image/')) ? x.mimeType! : 'image/jpeg';
      final endpoint = Uri.parse('${base.trim().replaceAll(RegExp(r'/+$'), '')}/upload/$key');
      final res = await http.put(endpoint,
          headers: {'Authorization': 'Bearer $token', 'Content-Type': type},
          body: bytes).timeout(const Duration(seconds: 90));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final detail = res.body.trim().replaceAll(RegExp(r'\s+'), ' ');
        throw HttpException('HTTP ${res.statusCode}${detail.isEmpty ? '' : ': ${detail.substring(0, detail.length > 180 ? 180 : detail.length)}'}');
      }
      String? returnedUrl;
      try {
        final payload = jsonDecode(res.body);
        if (payload is Map) {
          returnedUrl = (payload['url'] ?? payload['publicUrl'] ?? payload['downloadUrl'])?.toString();
        }
      } catch (_) {}
      final path = 'driverDocs/$_uid/$key';
      final doc = <String, dynamic>{'path': path, 'status': 'pending', 'uploadedAt': ServerValue.timestamp};
      if (returnedUrl != null && returnedUrl.startsWith('https://')) doc['url'] = returnedUrl;
      await FirebaseDatabase.instance.ref('drivers/$_uid/docs/$key').set(doc);
      setState(() => _docs[key] = {'path': path, if (returnedUrl != null) 'url': returnedUrl, 'status': 'pending'});
    } on SocketException {
      if (mounted) showSnack(context, 'تعذر الوصول إلى خدمة الرفع. تحقق من عنوان Worker واتصال الخادم.', error: true);
    } on FormatException {
      if (mounted) showSnack(context, 'عنوان خدمة الرفع غير صحيح. راجع إعداد uploadApi.', error: true);
    } on HttpException catch (e) {
      if (mounted) showSnack(context, 'فشل الرفع: ${e.message}', error: true);
    } on Exception catch (e) {
      if (mounted) showSnack(context, e.toString().contains('TimeoutException') ? 'انتهت مهلة رفع الملف. حاول مرة أخرى.' : 'تعذر رفع الملف: ${e.toString().replaceFirst('Exception: ', '')}', error: true);
    }
    if (mounted) setState(() => _uploading.remove(key));
  }

  Future<void> _vehicleNext() async {
    if ([_model, _year, _color, _plate].any((c) => c.text.trim().isEmpty)) return showSnack(context, 'أكمل بيانات المركبة', error: true);
    setState(() => _busy = true);
    try {
      await FirebaseDatabase.instance.ref('drivers/$_uid/vehicle').set({'model': _model.text.trim(), 'year': _year.text.trim(), 'color': _color.text.trim(), 'plate': _plate.text.trim()});
      setState(() => _step = 3);
    } catch (e) {
      showSnack(context, AuthService.message(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submit() async {
    final missing = docLabels.keys.where((k) => !_has(k));
    if (missing.isNotEmpty) return showSnack(context, 'ارفع: ${missing.map((k) => docLabels[k]).join('، ')}', error: true);
    setState(() => _busy = true);
    try {
      await FirebaseDatabase.instance.ref('drivers/$_uid').update({'status': 'pending', 'submittedAt': ServerValue.timestamp});
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, AuthService.message(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _f(TextEditingController c, String h, IconData i, {bool num = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: num ? TextInputType.number : null, style: const TextStyle(color: Colors.white), decoration: fieldDec(context, h, i)),
      );

  Widget _docRow(String k) {
    final d = asMap(_docs[k]);
    final st = d['status']?.toString();
    final up = _uploading.contains(k);
    return InkWell(
      onTap: up ? null : () => _pick(k),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFE9F1F5), borderRadius: BorderRadius.circular(10)), child: Icon(docIcons[k], color: AppColors.ink)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(docLabels[k]!, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            if (st == 'rejected') Text('مرفوض: ${d['note'] ?? 'أعد الرفع'}', style: const TextStyle(color: AppColors.red, fontSize: 12)),
          ])),
          up
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : !_has(k)
                  ? const Icon(Icons.add_circle_outline, color: Colors.grey)
                  : Icon(st == 'rejected' ? Icons.error : Icons.check_circle, color: st == 'rejected' ? AppColors.red : AppColors.green),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(22, 34, 22, 24), children: [
            Text(_step == 2 ? 'تسجيل السائق' : 'رفع المستندات', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 18),
            StepperHeader(_step),
            const SizedBox(height: 24),
            if (_step == 2) ...[
              _f(_model, 'نوع المركبة (مثال: تويوتا كامري)', Icons.directions_car_outlined),
              _f(_year, 'سنة الصنع', Icons.calendar_today_outlined, num: true),
              _f(_color, 'اللون', Icons.palette_outlined),
              _f(_plate, 'رقم اللوحة', Icons.pin_outlined),
              const SizedBox(height: 10),
              AppButton('التالي', onPressed: _vehicleNext, busy: _busy),
            ] else ...[
              InfoCard(child: Column(children: [for (final k in docLabels.keys) ...[_docRow(k), if (k != docLabels.keys.last) const Divider(height: 1)]])),
              const SizedBox(height: 18),
              AppButton('إرسال المستندات', onPressed: _uploading.isEmpty ? _submit : null, busy: _busy),
              TextButton(onPressed: () => setState(() => _step = 2), child: const Text('تعديل بيانات المركبة', style: TextStyle(color: Colors.white70))),
            ],
            TextButton(
              onPressed: () async {
                await AuthService.signOut();
                if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashGate()), (r) => false);
              },
              child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white54)),
            ),
          ]),
        ),
      );
}
