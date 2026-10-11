import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../services/driver_service.dart';
import '../widgets/common.dart';
import 'ratings_screen.dart';
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
            decoration: BoxDecoration(color: const Color(0xFF173B5A), borderRadius: BorderRadius.circular(14)),
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
                Row(children: [
                  CircleAvatar(radius: 36, backgroundColor: AppColors.primary, child: Text((m['name'] ?? '؟').toString().characters.first, style: const TextStyle(fontSize: 30, color: AppColors.navy, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((m['name'] ?? '').toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    Row(children: [
                      const Icon(Icons.star, color: AppColors.orange, size: 18),
                      Text(' ${rs.hasData && rs.data!.count > 0 ? rs.data!.avg.toStringAsFixed(1) : '—'}', style: const TextStyle(color: Colors.white)),
                      const SizedBox(width: 10),
                      const Text('سائق معتمد', style: TextStyle(color: AppColors.green)),
                    ]),
                  ])),
                ]),
                const SizedBox(height: 22),
                _row(context, Icons.person_outline, 'المعلومات الشخصية', () => Navigator.push(context, MaterialPageRoute(builder: (_) => _InfoScreen(m)))),
                _row(context, Icons.directions_car_outlined, 'المركبة', () => Navigator.push(context, MaterialPageRoute(builder: (_) => VehicleScreen(m)))),
                _row(context, Icons.star_outline, 'التقييمات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingsScreen()))),
                _row(context, Icons.settings_outlined, 'الإعدادات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()))),
              ]),
            );
          },
        ),
      );
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
      await db.child('drivers/$myUid/vehicle').set({for (final e in ctl.entries) e.key: e.value.text.trim()});
      if (context.mounted) {
        showSnack(context, 'تم حفظ بيانات المركبة');
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
            AppButton('تعديل البيانات', onPressed: () => _edit(context, v)),
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
        await DriverService.createTicket(t.text.trim(), m.text.trim());
        if (context.mounted) showSnack(context, 'تم إرسال تذكرتك');
      } catch (_) {
        if (context.mounted) showSnack(context, 'تعذر الإرسال', error: true);
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
