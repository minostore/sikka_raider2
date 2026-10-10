import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../services/auth_service.dart';
import '../services/ride_service.dart';
import '../widgets/common.dart';
import 'notifications_screen.dart';
import 'place_search_screen.dart';
import 'splash_gate.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  Future<void> _editName(BuildContext context, String uid, String current) async {
    final c = TextEditingController(text: current);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الاسم'),
        content: TextField(controller: c),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && c.text.trim().length >= 3) {
      await FirebaseDatabase.instance.ref('users/$uid/name').set(c.text.trim());
    }
  }

  Future<void> _setPlace(BuildContext context, String uid, String key) async {
    final p = await Navigator.push<Place>(
        context, MaterialPageRoute(builder: (_) => PlaceSearchScreen(title: key == 'home' ? 'عنوان المنزل' : 'عنوان العمل')));
    if (p != null) {
      await FirebaseDatabase.instance.ref('users/$uid/places/$key').set(p.toMap());
    }
  }

  Future<void> _support(BuildContext context) async {
    final t = TextEditingController();
    final m = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('المساعدة والدعم'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: t, decoration: const InputDecoration(labelText: 'عنوان المشكلة')),
          const SizedBox(height: 8),
          TextField(controller: m, maxLines: 3, decoration: const InputDecoration(labelText: 'التفاصيل')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok == true && t.text.trim().isNotEmpty && m.text.trim().isNotEmpty) {
      try {
        await RideService.createTicket(t.text.trim(), m.text.trim());
        if (context.mounted) showSnack(context, 'تم إرسال تذكرتك. سنرد عليك قريباً');
      } catch (_) {
        if (context.mounted) showSnack(context, 'تعذر إرسال التذكرة', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('users/$uid').onValue,
        builder: (c, s) {
          if (!s.hasData) return const LoadingView();
          final m = asMap(s.data!.snapshot.value);
          final name = (m['name'] ?? '').toString();
          final places = asMap(m['places']);
          Widget item(IconData i, String t, VoidCallback f, {String? sub}) => ListTile(
              leading: Icon(i, color: AppColors.primary), title: Text(t), subtitle: sub == null ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.chevron_left), onTap: f);
          return ListView(children: [
            const SizedBox(height: 16),
            const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 8),
            Center(child: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            Center(child: Text('+${m['phone'] ?? ''}', textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.grey))),
            const SizedBox(height: 12),
            item(Icons.edit, 'تعديل الملف الشخصي', () => _editName(context, uid, name)),
            item(Icons.home, 'عنوان المنزل', () => _setPlace(context, uid, 'home'), sub: asMap(places['home'])['address']?.toString()),
            item(Icons.work, 'عنوان العمل', () => _setPlace(context, uid, 'work'), sub: asMap(places['work'])['address']?.toString()),
            item(Icons.notifications_none, 'الإشعارات', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
            item(Icons.support_agent, 'المساعدة والدعم', () => _support(context)),
            item(Icons.description_outlined, 'الشروط والخصوصية', () => showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('الشروط والخصوصية'), content: const Text('باستخدامك مشوار فأنت توافق على: تقديم بيانات صحيحة، الالتزام بالسعر المتفق عليه مع السائق، احترام السائقين والركاب، وعدم إساءة استخدام التطبيق. نستخدم موقعك أثناء استخدام التطبيق فقط لتحديد الالتقاط وتتبع الرحلة، ولا نشاركه مع أي جهة خارج الرحلة. يمكنك طلب حذف بياناتك عبر الدعم.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))]))),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.red),
              title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.red)),
              onTap: () async {
                if (!await confirmDialog(context, 'تسجيل الخروج', 'هل تريد تسجيل الخروج؟')) return;
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashGate()), (r) => false);
                }
              },
            ),
          ]);
        },
      ),
    );
  }
}
