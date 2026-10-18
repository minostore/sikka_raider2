import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'auth_driver.dart';
import 'face_verify_screen.dart';
import '../services/upload_http.dart';
import '../services/doc_upload_service.dart';
import 'splash_gate.dart';
import '../services/r2_upload_service.dart';

const _defaultUploadApi = 'https://www.sikka-eg.online'; // خدمة sikka-uploads على Cloudflare (يمكن تغييرها من لوحة التحكم > الإعدادات)

/// الأوراق المطلوبة الافتراضية. يمكن للإدارة تعديلها (الاسم/الصورة/الإضافة/الحذف) من لوحة التحكم
/// ← الأوراق المطلوبة، وتظهر مباشرة في التطبيق عبر settings/requiredDocs.
final Map<String, String> docLabels = {
  'nationalIdFront': 'صورة البطاقة الشخصية - الوجه الأمامي',
  'nationalIdBack': 'صورة البطاقة الشخصية - الوجه الخلفي',
  'licenseFront': 'صورة رخصة القيادة - الوجه الأمامي',
  'licenseBack': 'صورة رخصة القيادة - الوجه الخلفي',
  'vehicleRegFront': 'صورة رخصة المركبة - الوجه الأمامي',
  'vehicleRegBack': 'صورة رخصة المركبة - الوجه الخلفي',
  'photo': 'صورة سيلفي واضحة للوجه',
};
const docIcons = {
  'license': Icons.badge_outlined,
  'registration': Icons.directions_car_outlined,
  'nationalId': Icons.credit_card,
  'insurance': Icons.shield_outlined,
  'photo': Icons.account_box_outlined,
};

/// ورقة مطلوبة من السائق (اسم + صورة مثال اختيارية).
class DocReq {
  final String key, title;
  final String? image;
  const DocReq(this.key, this.title, [this.image]);
}

List<DocReq> get _defaultDocReqs => [for (final e in docLabels.entries) DocReq(e.key, e.value)];

/// يقرأ الأوراق المطلوبة من لوحة التحكم ويحدّث docLabels (للأسماء في بقية الشاشات).
Future<List<DocReq>> loadRequiredDocs() async {
  try {
    final raw = (await FirebaseDatabase.instance.ref('settings/requiredDocs').get()).value;
    final entries = <MapEntry<String, Map<String, dynamic>>>[];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is Map) entries.add(MapEntry(k.toString(), Map<String, dynamic>.from(v)));
      });
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final v = raw[i];
        if (v is Map) entries.add(MapEntry('$i', Map<String, dynamic>.from(v)));
      }
    }
    final list = entries.where((e) => e.value['active'] != false && (e.value['title'] ?? '').toString().trim().isNotEmpty).toList()
      ..sort((a, b) => ((a.value['order'] as num?) ?? 0).compareTo((b.value['order'] as num?) ?? 0));
    if (list.isEmpty) return _defaultDocReqs;
    docLabels
      ..clear()
      ..addEntries(list.map((e) => MapEntry(e.key, e.value['title'].toString().trim())));
    return [
      for (final e in list)
        DocReq(e.key, e.value['title'].toString().trim(), (e.value['image'] ?? '').toString().startsWith('https://') ? e.value['image'].toString() : null),
    ];
  } catch (_) {
    return _defaultDocReqs;
  }
}

/// ألوان المركبة (قابلة للتعديل من لوحة التحكم ← settings/vehicleColors).
class VehicleColor {
  final String name;
  final Color color;
  const VehicleColor(this.name, this.color);
}

const List<VehicleColor> _defaultColors = [
  VehicleColor('أبيض', Color(0xFFFFFFFF)),
  VehicleColor('أسود', Color(0xFF111111)),
  VehicleColor('رمادي', Color(0xFF808080)),
  VehicleColor('فضي', Color(0xFFC0C0C0)),
  VehicleColor('أحمر', Color(0xFFD32F2F)),
  VehicleColor('أزرق', Color(0xFF1976D2)),
  VehicleColor('أخضر', Color(0xFF388E3C)),
  VehicleColor('أصفر', Color(0xFFFBC02D)),
  VehicleColor('برتقالي', Color(0xFFF57C00)),
  VehicleColor('بني', Color(0xFF6D4C41)),
];

Color _parseHex(String? hex, Color fallback) {
  var h = (hex ?? '').trim().replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null || h.length != 8 ? fallback : Color(v);
}

Future<List<VehicleColor>> loadVehicleColors() async {
  try {
    final raw = (await FirebaseDatabase.instance.ref('settings/vehicleColors').get()).value;
    final vals = raw is Map ? raw.values.toList() : raw is List ? raw : const [];
    final list = <VehicleColor>[
      for (final v in vals)
        if (v is Map && (v['name'] ?? '').toString().trim().isNotEmpty) VehicleColor(v['name'].toString().trim(), _parseHex(v['hex']?.toString(), Colors.grey)),
    ];
    return list.isEmpty ? _defaultColors : list;
  } catch (_) {
    return _defaultColors;
  }
}

/// صور وسائل النقل (نفس صور تطبيق المستخدم، من لوحة التحكم ← settings/vehicleImages).
Future<Map<String, String>> loadVehicleImages() async {
  try {
    final v = (await FirebaseDatabase.instance.ref('settings/vehicleImages').get()).value;
    if (v is Map) {
      return {
        for (final e in v.entries)
          if (e.value is String && (e.value as String).startsWith('https://')) e.key.toString(): e.value as String,
      };
    }
  } catch (_) {}
  return {};
}

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
  late String _vtype = (_veh['type'] ?? '').toString();
  late final _model = TextEditingController(text: _veh['model']?.toString() ?? '');
  late final _year = TextEditingController(text: _veh['year']?.toString() ?? '');
  late String _color = (_veh['color'] ?? '').toString();
  // اللوحة: حروف (حتى 3) منفصلة عن الأرقام (حتى 4)
  late final _plateLetters = TextEditingController(text: _veh['plateLetters']?.toString() ?? '');
  late final _plateDigits = TextEditingController(text: _veh['plateDigits']?.toString() ?? '');
  List<VehicleColor> _colors = _defaultColors;
  List<DocReq> _reqDocs = _defaultDocReqs;
  Map<String, String> _vehicleImages = {};
  late final Map<String, dynamic> _docs = asMap(widget.data['docs']);
  final Set<String> _uploading = {};
  final Map<String, String> _localPaths = {}; // نسخة محلية من الصور التي رُفعت في هذه الجلسة (للمقارنة على الجهاز)
  bool _busy = false;
  late int _step = (_veh['plate'] ?? '').toString().isNotEmpty ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final r = await Future.wait<Object>([loadVehicleColors(), loadRequiredDocs(), loadVehicleImages()]);
    if (!mounted) return;
    setState(() {
      _colors = r[0] as List<VehicleColor>;
      _reqDocs = r[1] as List<DocReq>;
      _vehicleImages = r[2] as Map<String, String>;
    });
  }

  bool _has(String k) {
    final d = asMap(_docs[k]);
    return d['path'] != null || d['url'] != null;
  }

  Future<void> _pick(String key) async {
    // السيلفي (photo) يُلتقط من الكاميرا الأمامية مباشرة ولا يُقبل من المعرض، لضمان أنه صورة حية.
    final isSelfie = key == 'photo';
    final x = await ImagePicker().pickImage(
      source: isSelfie ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: isSelfie ? 85 : 70,
      maxWidth: 1600,
    );
    if (x == null) return;
    setState(() => _uploading.add(key));
    try {
      final bytes = await x.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) throw Exception('حجم الصورة أكبر من 8 ميجابايت. اختر صورة أصغر.');
      final type = (x.mimeType != null && x.mimeType!.startsWith('image/')) ? x.mimeType! : 'image/jpeg';
      String? returnedUrl, workerKey;
      // 1) رفع مباشر إلى R2 برابط موقّع من خادم لوحة التحكم (لا يمر على Worker ولا Cloudflare Access)
      final direct = await DocUploadService.putDirect(key: key, bytes: bytes, contentType: type);
      if (direct == null) {
        // 2) احتياطي: خدمة Worker (عنوانها settings/uploadApi)
        final cfg = (await FirebaseDatabase.instance.ref('settings/uploadApi').get()).value?.toString();
        final base = (cfg != null && cfg.trim().isNotEmpty) ? cfg.trim() : _defaultUploadApi;
        final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
        if (token == null || token.isEmpty) throw Exception('تعذر الحصول على رمز تسجيل الدخول. سجل الدخول مرة أخرى.');
        final endpoint = Uri.parse('${base.trim().replaceAll(RegExp(r'/+$'), '')}/upload/$key');
        final res = await putFollowingRedirects(endpoint, headers: {'Authorization': 'Bearer $token', 'Content-Type': type}, body: bytes);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          final detail = res.body.trim().replaceAll(RegExp(r'\s+'), ' ');
          throw HttpException('HTTP ${res.statusCode}${detail.isEmpty ? '' : ': ${detail.substring(0, detail.length > 180 ? 180 : detail.length)}'}');
        }
        try {
          final payload = jsonDecode(res.body);
          if (payload is Map) {
            returnedUrl = (payload['url'] ?? payload['publicUrl'] ?? payload['downloadUrl'])?.toString();
            workerKey = (payload['key'] ?? payload['path'])?.toString(); // مثال: account-files/{uid}/{key}
          }
        } catch (_) {}
      }
      final path = direct ?? ((workerKey != null && workerKey!.isNotEmpty) ? workerKey! : 'driverDocs/$_uid/$key');
      final doc = <String, dynamic>{'path': path, 'status': 'pending', 'uploadedAt': ServerValue.timestamp};
      if (returnedUrl != null && returnedUrl.startsWith('https://')) doc['url'] = returnedUrl;
      await FirebaseDatabase.instance.ref('drivers/$_uid/docs/$key').set(doc);
      if (isSelfie) {
        // السيلفي المرفوع يصبح صورة الملف الشخصي للكابتن (تُقفل بعد اعتماد الحساب ولا تتغير إلا من الإدارة).
        try {
          final up = await R2UploadService.uploadProfileImage(file: File(x.path), role: 'driver');
          final u = up['url'];
          if (u != null && u.startsWith('https://')) {
            await FirebaseDatabase.instance.ref('drivers/$_uid').update({'photoUrl': u, if (up['path'] != null) 'photoPath': up['path']});
          }
        } catch (_) {}
      }
      _localPaths[key] = x.path;
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
    if (_vtype.isEmpty) return showSnack(context, 'اختر نوع الوسيلة (موتوسيكل أو اسكوتر)', error: true);
    if (_model.text.trim().isEmpty) return showSnack(context, 'أدخل موديل المركبة', error: true);
    final year = int.tryParse(_year.text.trim());
    if (_year.text.trim().length != 4 || year == null || year < 1980 || year > DateTime.now().year + 1) {
      return showSnack(context, 'أدخل سنة صنع صحيحة من 4 أرقام', error: true);
    }
    if (_color.isEmpty) return showSnack(context, 'اختر لون المركبة', error: true);
    final letters = _plateLetters.text.trim(), digits = _plateDigits.text.trim();
    if (letters.isEmpty || letters.length > 3) return showSnack(context, 'أدخل حروف اللوحة (حتى 3 حروف)', error: true);
    if (digits.isEmpty || digits.length > 4) return showSnack(context, 'أدخل أرقام اللوحة (حتى 4 أرقام)', error: true);
    setState(() => _busy = true);
    try {
      await FirebaseDatabase.instance.ref('drivers/$_uid/vehicle').set({
        'type': _vtype,
        'model': _model.text.trim(),
        'year': _year.text.trim(),
        'color': _color,
        'plateLetters': letters,
        'plateDigits': digits,
        'plate': '$digits ${letters.split('').join(' ')}',
      });
      setState(() => _step = 3);
    } catch (e) {
      showSnack(context, AuthService.message(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submit() async {
    final missing = _reqDocs.where((d) => !_has(d.key));
    if (missing.isNotEmpty) return showSnack(context, 'ارفع: ${missing.map((d) => d.title).join('، ')}', error: true);
    setState(() => _busy = true);
    try {
      await FirebaseDatabase.instance.ref('drivers/$_uid').update({'status': 'pending', 'submittedAt': ServerValue.timestamp});
      if (!mounted) return;
      // التحقق من تطابق السيلفي مع المستندات (يتم على الخادم بخدمة تعرف على الوجه)
      final r = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => FaceVerifyScreen(selfiePath: _localPaths['photo'], idPaths: {for (final k in const ['nationalIdFront', 'nationalIdBack', 'licenseFront', 'licenseBack', 'nationalId', 'license']) if (_localPaths[k] != null) k: _localPaths[k]!})));
      if (!mounted) return;
      if (r == 'failed') {
        showSnack(context, 'أعد التقاط السيلفي ثم أرسل المستندات مرة أخرى', error: true);
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) showSnack(context, AuthService.message(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _typeCard(String type, String label, IconData icon) {
    final sel = _vtype == type;
    final img = _vehicleImages[type];
    return InkWell(
      onTap: () => setState(() => _vtype = type),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 70,
            child: img != null ? Image.network(img, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(icon, size: 44, color: AppColors.ink)) : Icon(icon, size: 44, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: sel ? AppColors.primary : Colors.white)),
        ]),
      ),
    );
  }

  Widget _f(TextEditingController c, String h, IconData i, {bool num = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: c, keyboardType: num ? TextInputType.number : null, style: const TextStyle(color: Colors.white), decoration: fieldDec(context, h, i)),
      );

  Widget _docRow(DocReq req) {
    final k = req.key;
    final d = asMap(_docs[k]);
    final st = d['status']?.toString();
    final up = _uploading.contains(k);
    return InkWell(
      onTap: up ? null : () => _pick(k),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(10)),
            child: req.image != null
                ? Image.network(req.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(docIcons[k] ?? Icons.description_outlined, color: AppColors.ink))
                : Icon(docIcons[k] ?? Icons.description_outlined, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(req.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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
              const Text('نوع الوسيلة', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _typeCard('motorcycle', 'موتوسيكل', Icons.two_wheeler)),
                const SizedBox(width: 10),
                Expanded(child: _typeCard('scooter', 'اسكوتر', Icons.moped)),
              ]),
              const SizedBox(height: 14),
              _f(_model, 'الموديل (مثال: هوندا 125)', Icons.two_wheeler),
              // سنة الصنع: 4 أرقام كحد أقصى
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _year,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  style: const TextStyle(color: Colors.white),
                  decoration: fieldDec(context, 'سنة الصنع (4 أرقام)', Icons.calendar_today_outlined).copyWith(counterText: ''),
                ),
              ),
              const Text('اللون', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in _colors)
                  ChoiceChip(
                    avatar: CircleAvatar(radius: 9, backgroundColor: c.color, child: _color == c.name ? Icon(Icons.check, size: 12, color: c.color.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null),
                    label: Text(c.name),
                    selected: _color == c.name,
                    onSelected: (_) => setState(() => _color = c.name),
                  ),
              ]),
              const SizedBox(height: 14),
              const Text('رقم اللوحة', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                // الأرقام (حتى 4) ثم الحروف (حتى 3) في خانتين منفصلتين
                Expanded(
                  child: TextField(
                    controller: _plateDigits,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 3),
                    decoration: fieldDec(context, 'الأرقام', Icons.pin_outlined).copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _plateLetters,
                    maxLength: 3,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\u0621-\u064Aa-zA-Z]')), LengthLimitingTextInputFormatter(3)],
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 3),
                    decoration: fieldDec(context, 'الحروف', Icons.abc).copyWith(counterText: ''),
                  ),
                ),
              ]),
              AppButton('التالي', onPressed: _vehicleNext, busy: _busy),
            ] else ...[
              InfoCard(child: Column(children: [for (final d in _reqDocs) ...[_docRow(d), if (d != _reqDocs.last) const Divider(height: 1)]])),
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
