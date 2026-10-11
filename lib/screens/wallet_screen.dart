import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/common.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  Future<void> _topup(BuildContext context, String uid) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('طلب شحن الرصيد'),
        content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال الطلب')),
        ],
      ),
    );
    final amount = double.tryParse(ctrl.text.trim()) ?? 0;
    if (ok != true) return;
    if (amount <= 0) {
      if (context.mounted) showSnack(context, 'أدخل مبلغاً صحيحاً', error: true);
      return;
    }
    try {
      final ref = FirebaseDatabase.instance.ref('wallets/$uid/topups').push();
      await ref.set({'amount': amount, 'status': 'pending', 'createdAt': ServerValue.timestamp});
      if (context.mounted) showSnack(context, 'تم إرسال الطلب وسيتم مراجعته من الإدارة');
    } catch (_) {
      if (context.mounted) showSnack(context, 'تعذر إرسال الطلب', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('المحفظة')),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('wallets/$uid').onValue,
        builder: (c, s) {
          if (s.hasError) return const ErrorView('تعذر تحميل المحفظة');
          if (!s.hasData) return const LoadingView();
          final m = asMap(s.data!.snapshot.value);
          final tx = asMap(m['tx']).entries.map((e) => asMap(e.value)).toList()
            ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
          final topups = asMap(m['topups']).entries.map((e) => asMap(e.value)).toList()
            ..sort((a, b) => ((b['createdAt'] as num?) ?? 0).compareTo((a['createdAt'] as num?) ?? 0));
          return ListView(padding: const EdgeInsets.all(14), children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.navy, borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                const Text('الرصيد الحالي', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                Text(money(numD(m['balance'])),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                    onPressed: () => _topup(context, uid),
                    icon: const Icon(Icons.add),
                    label: const Text('طلب شحن رصيد')),
              ]),
            ),
            const SizedBox(height: 12),
            const InfoCard(
                child: Text('طريقة الدفع الحالية: نقداً للسائق عند نهاية الرحلة.',
                    style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 16),
            const Text('طلبات الشحن', style: TextStyle(fontWeight: FontWeight.bold)),
            if (topups.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد طلبات', style: TextStyle(color: Colors.grey))),
            for (final t in topups)
              ListTile(
                leading: const Icon(Icons.add_card),
                title: Text(money(numD(t['amount']))),
                subtitle: Text(dateLabel((t['createdAt'] as num?)?.toInt())),
                trailing: Pill(
                    t['status'] == 'approved' ? 'مقبول' : t['status'] == 'rejected' ? 'مرفوض' : 'قيد المراجعة',
                    t['status'] == 'approved' ? AppColors.green : t['status'] == 'rejected' ? AppColors.red : AppColors.orange),
              ),
            const SizedBox(height: 12),
            const Text('سجل العمليات', style: TextStyle(fontWeight: FontWeight.bold)),
            if (tx.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد عمليات', style: TextStyle(color: Colors.grey))),
            for (final t in tx)
              ListTile(
                title: Text((t['title'] ?? 'عملية').toString()),
                subtitle: Text(_transactionDetails(t)),
                trailing: Text('${numD(t['amount']) >= 0 ? '+' : ''}${numD(t['amount']).toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.bold, color: numD(t['amount']) >= 0 ? AppColors.green : AppColors.red)),
              ),
          ]);
        },
      ),
    );
  }
}


/// يوضح مصدر الحركة والمرجع المرتبط بها بجانب التاريخ، مع التوافق مع السجلات القديمة.
String _transactionDetails(Map<String, dynamic> t) {
  final parts = <String>[dateLabel((t['createdAt'] as num?)?.toInt())];
  final rawSource = (t['source'] ?? t['type'] ?? t['category'] ?? '').toString().trim();
  const sourceLabels = <String, String>{
    'ride': 'رحلة', 'trip': 'رحلة', 'commission': 'عمولة',
    'topup': 'شحن رصيد', 'wallet_topup': 'شحن رصيد',
    'refund': 'استرداد', 'transfer': 'تحويل', 'adjustment': 'تسوية إدارية',
    'cashout': 'سحب أرباح', 'payout': 'صرف أرباح',
  };
  if (rawSource.isNotEmpty) parts.add(sourceLabels[rawSource.toLowerCase()] ?? rawSource);
  final rideId = (t['rideId'] ?? t['ride_id'] ?? '').toString().trim();
  final reference = (t['reference'] ?? t['referenceId'] ?? t['requestId'] ?? '').toString().trim();
  if (rideId.isNotEmpty) parts.add('رحلة #${rideId.length > 8 ? rideId.substring(0, 8) : rideId}');
  else if (reference.isNotEmpty) parts.add('مرجع #${reference.length > 8 ? reference.substring(0, 8) : reference}');
  return parts.join(' • ');
}
