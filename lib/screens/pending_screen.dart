import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'docs_screen.dart';
import 'splash_gate.dart';

/// جارٍ التحقق من المستندات
class PendingScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const PendingScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final docs = asMap(data['docs']);
    final rejected = data['status'] == 'rejected';
    Widget row(String t, String st) {
      final ok = st == 'approved', bad = st == 'rejected';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(ok ? Icons.check_circle : bad ? Icons.cancel : Icons.hourglass_empty, color: ok ? AppColors.green : bad ? AppColors.red : Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(t)),
          Text(ok ? 'مقبول' : bad ? 'مرفوض' : 'قيد المراجعة', style: TextStyle(color: ok ? AppColors.green : bad ? AppColors.red : AppColors.orange, fontSize: 12)),
        ]),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          const SizedBox(height: 30),
          Center(
            child: Stack(clipBehavior: Clip.none, children: [
              Container(width: 96, height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [for (var i = 0; i < 4; i++) Container(margin: const EdgeInsets.only(bottom: 9), height: 6, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3)))]))),
              Positioned(right: -16, bottom: -10, child: Container(width: 46, height: 46, decoration: BoxDecoration(color: rejected ? AppColors.red : AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.navy, width: 3)), child: Icon(rejected ? Icons.close : Icons.check, color: Colors.white))),
            ]),
          ),
          const SizedBox(height: 34),
          Text(rejected ? 'تم رفض الطلب' : 'جارٍ التحقق من المستندات', textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 10),
          Text(rejected ? (data['rejectReason'] ?? 'عدّل المستندات المرفوضة وأعد الإرسال.').toString() : 'سنقوم بمراجعة مستنداتك\nوإشعارك قريباً', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5)),
          const SizedBox(height: 26),
          InfoCard(child: Column(children: [for (final e in docLabels.entries) row(e.value, asMap(docs[e.key])['status']?.toString() ?? 'pending'), row('الموافقة النهائية', 'pending')])),
          const SizedBox(height: 18),
          if (rejected) AppButton('تعديل المستندات', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DocsScreen(data: data)))),
          TextButton(
            onPressed: () async {
              await AuthService.signOut();
              if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashGate()), (r) => false);
            },
            child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white54)),
          ),
        ]),
      ),
    );
  }
}
