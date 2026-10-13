import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import 'ticket_chat_screen.dart';
import '../widgets/common.dart';
import 'ratings_screen.dart';
import 'support_tickets_screen.dart';
import 'splash_gate.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _row(BuildContext c, IconData i, String t, VoidCallback f) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: f,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [Icon(i, color: AppColors.primary), const SizedBox(width: 12), Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))), const Icon(Icons.chevron_left, color: Colors.white54)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ملفي'), automaticallyImplyLeading: false),
        body: StreamBuilder<DatabaseEvent>(
          stream: db.child('drivers/$myUid').onValue,
          builder: (c, s) {
            if (!s.hasData) return const LoadingView();
            final m = asMap(s.data!.snapshot.value);
            return FutureBuilder<({double avg, int count, List<Map<String, dynamic>> list})>(
              future: DriverService.ratings(),
              builder: (c, rs) => ListView(padding: const EdgeInsets.all(16), children: [
                _ProfileHeader(m: m, rating: rs.hasData && rs.data!.count > 0 ? rs.data!.avg.toStringAsFixed(1) : '—'),
                const SizedBox(height: 22),
                _row(context, Icons.person_outline, 'المعلومات الشخصية', () => Navigator.push(context, MaterialPageRoute(builder: (_) => _InfoScreen(m)))),
                _row(context, Icons.directions_car_outlined, 'المركبة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleScreen(m)))),
                _row(context, Icons.star_outline, 'التقييمات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingsScreen()))),
                _row(context, Icons.support_agent, 'الدعم الفني وتذاكري', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsScreen(role: 'driver')))),
                _row(context, Icons.settings_outlined, 'الإعدادات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
              ]),
            );
          },
        ),
      );
}

/// رأس الملف: الصورة (التقاط أو من المعرض) + الاسم + التقييم
class _ProfileHeader extends StatefulWidget {
  final Map<String, dynamic> m;
  final String rating;
  const _ProfileHeader({required this.m, required this.rating});
  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  String _fallbackName = FirebaseAuth.instance.currentUser?.displayName ?? '';
  String? _localPhoto;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadFallbackName();
  }

  String get _name {
    final n = (widget.m['name'] ?? widget.m['fullName'] ?? '').toString().trim();
    return n.isNotEmpty ? n : _fallbackName;
  }

  String get _photo =>
      _localPhoto ?? (widget.m['photoUrl'] ?? widget.m['photoURL'] ?? widget.m['avatarUrl'] ?? '').toString();

  /// إذا كان الاسم غير موجود في ملف السائق نقرأه من حساب المستخدم ونصلحه
  Future<void> _loadFallbackName() async {
    if ((widget.m['name'] ?? '').toString().trim().isNotEmpty) return;
    try {
      final v = (await db.child('users/$myUid/name').get()).value?.toString().trim() ?? '';
      final name = v.isNotEmpty ? v : _fallbackName;
      if (name.isEmpty) return;
      if (mounted) setState(() => _fallbackName = name);
      db.child('drivers/$myUid/name').set(name).catchError((_) {});
    } catch (_) {}
  }

  Future<void> _changePhoto() async {
    if (_uploading) return;
    const white = TextStyle(color: Colors.white, fontWeight: FontWeight.w700);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.field,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera, color: AppColors.primary),
            title: const Text('التقاط صورة', style: white),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppColors.primary),
            title: const Text('اختيار من المعرض', style: white),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
        preferredCameraDevice: CameraDevice.front,
      );
      if (x == null) return;
      if (mounted) setState(() => _uploading = true);
      final bytes = await x.readAsBytes();
      final ref = FirebaseStorage.instance.ref('driverAvatars/$myUid/avatar.jpg');
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = '${await ref.getDownloadURL()}&t=${DateTime.now().millisecondsSinceEpoch}';
      await db.child('drivers/$myUid/photoUrl').set(url);
      db.child('users/$myUid/photoUrl').set(url).catchError((_) {});
      if (mounted) {
        setState(() => _localPhoto = url);
        showSnack(context, 'تم تحديث صورتك الشخصية');
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e, fallback: 'تعذر تحديث الصورة. حاول مرة أخرى.'), error: true);
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final name = _name;
    final photo = _photo;
    final hasPhoto = photo.startsWith('http');
    return Row(children: [
      GestureDetector(
        onTap: _changePhoto,
        child: Stack(children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary,
            backgroundImage: hasPhoto ? NetworkImage(photo) : null,
            child: _uploading
                ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.navy))
                : hasPhoto
                    ? null
                    : name.isEmpty
                        ? const Icon(Icons.person, size: 38, color: AppColors.navy)
                        : Text(name.characters.first, style: const TextStyle(fontSize: 30, color: AppColors.navy, fontWeight: FontWeight.w900)),
          ),
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: AppColors.navy, width: 2)),
              child: const Icon(Icons.photo_camera, size: 15, color: AppColors.navy),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isEmpty ? 'سائق' : name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          Row(children: [
            const Icon(Icons.star, color: AppColors.orange, size: 18),
            Text(' ${widget.rating}', style: const TextStyle(color: Colors.white)),
            const SizedBox(width: 10),
            const Text('سائق معتمد', style: TextStyle(color: AppColors.green)),
          ]),
        ]),
      ),
    ]);
  }
}

class _InfoScreen extends StatelessWidget {
  final Map<String, dynamic> m;
  const _InfoScreen(this.m);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المعلومات الشخصية')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ListTile(leading: const Icon(Icons.person_outline), title: const Text('الاسم'), subtitle: Text('${m['name'] ?? ''}')),
            ListTile(leading: const Icon(Icons.phone_outlined), title: const Text('الموبايل'), subtitle: Text('+${m['phone'] ?? ''}', textDirection: TextDirection.ltr, textAlign: TextAlign.start)),
            ListTile(leading: const Icon(Icons.location_city), title: const Text('المدينة'), subtitle: Text('${m['city'] ?? ''}')),
            ListTile(leading: const Icon(Icons.directions_car_outlined), title: const Text('عدد الرحلات'), subtitle: Text('${m['tripsCount'] ?? 0}')),
          ])),
        ]),
      );
}

/// معلومات المركبة
class VehicleScreen extends StatelessWidget {
  final Map<String, dynamic> m;
  const VehicleScreen(this.m, {super.key});

  Future<void> _edit(BuildContext context, Map<String, dynamic> v) async {
    final ctl = {for (final k in ['model', 'year', 'color', 'plate']) k: TextEditingController(text: v[k]?.toString() ?? '')};
    final labels = {'model': 'نوع المركبة', 'year': 'سنة الصنع', 'color': 'اللون', 'plate': 'رقم اللوحة'};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل بيانات المركبة'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [for (final k in ctl.keys) Padding(padding: const EdgeInsets.only(bottom: 8), child: TextField(controller: ctl[k], decoration: InputDecoration(labelText: labels[k])))])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ'))],
      ),
    );
    if (ok == true && ctl.values.every((c) => c.text.trim().isNotEmpty)) {
      await db.update({'drivers/$myUid/vehicle': {for (final e in ctl.entries) e.key: e.value.text.trim()}, 'drivers/$myUid/vehicleReviewStatus': 'pending', 'drivers/$myUid/status': 'pending', 'drivers/$myUid/online': false, 'onlineDrivers/$myUid': null});
      if (context.mounted) {
        showSnack(context, 'تم إرسال بيانات المركبة الجديدة للمراجعة. لن تتمكن من استقبال رحلات حتى اعتمادها.');
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = asMap(m['vehicle']);
    return Scaffold(
      appBar: AppBar(title: const Text('معلومات المركبة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        InfoCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Icon(Icons.directions_car_filled, size: 90, color: AppColors.ink),
            const SizedBox(height: 8),
            Text('${v['model'] ?? ''}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            Text('${v['year'] ?? ''} • ${v['color'] ?? ''}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8), decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFDDE5EA))), child: Text('${v['plate'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            const SizedBox(height: 16),
            Text('حالة المراجعة: ${m['vehicleReviewStatus'] == 'pending' ? 'قيد المراجعة' : 'معتمدة'}', style: TextStyle(color: m['vehicleReviewStatus'] == 'pending' ? AppColors.orange : AppColors.green)),
            const SizedBox(height: 10),
            AppButton('تعديل البيانات وإرسالها للمراجعة', onPressed: () => _edit(context, v)),
          ]),
        ),
      ]),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _support(BuildContext context) async {
    final t = TextEditingController(), m = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('المساعدة والدعم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: t, decoration: const InputDecoration(labelText: 'العنوان')), const SizedBox(height: 8), TextField(controller: m, maxLines: 3, decoration: const InputDecoration(labelText: 'التفاصيل'))]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال'))],
      ),
    );
    if (ok == true && t.text.trim().isNotEmpty && m.text.trim().isNotEmpty) {
      try {
        final ticketId = await DriverService.createTicket(t.text.trim(), m.text.trim());
        if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => TicketChatScreen(ticketId: ticketId, role: 'driver')));
      } catch (e) {
        if (context.mounted) showSnack(context, errorMessage(e, fallback: 'تعذر إرسال تذكرة الدعم'), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          InfoCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              const ListTile(leading: Icon(Icons.language), title: Text('اللغة'), trailing: Text('العربية', style: TextStyle(color: Colors.grey))),
              const Divider(height: 1),
              ListTile(leading: const Icon(Icons.support_agent), title: const Text('المساعدة والدعم'), trailing: const Icon(Icons.chevron_left), onTap: () => _support(context)),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.red),
                title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.red)),
                onTap: () async {
                  if (!await confirmDialog(context, 'تسجيل الخروج', 'سيتوقف استقبال الطلبات ومشاركة الموقع.')) return;
                  await LocationPublisher.stop();
                  await db.child('drivers/$myUid/online').set(false).catchError((_) {});
                  await AuthService.signOut();
                  if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashGate()), (r) => false);
                },
              ),
            ]),
          ),
        ]),
      );
}
