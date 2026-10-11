import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/ride.dart';
import '../services/driver_service.dart';
import '../widgets/common.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Future<List<Ride>> _f = DriverService.myRides();
  String _p = 'week';
  static const _dn = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
  static const _mn = ['ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون', 'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس'];

  double _net(Ride r) => r.finalPrice - r.commission;

  Future<void> _payout() async {
    try {
      // Use lifetime completed trips, not the currently selected chart period.
      final rides = await DriverService.myRides();
      final lifetimeNet = rides
          .where((r) => r.status == 'completed' && r.completedAt != null)
          .fold<double>(0, (sum, r) => sum + _net(r));
      final requestSnapshot = await db.child('payoutRequests').orderByChild('driverId').equalTo(myUid).get();
      final requests = asMap(requestSnapshot.value);
      final reserved = requests.values.map((e) => asMap(e)).where((m) =>
          m['driverId'] == myUid && ['pending', 'approved', 'paid'].contains(m['status']))
          .fold<double>(0, (sum, m) => sum + numD(m['amount']));
      final available = (lifetimeNet - reserved).clamp(0.0, double.infinity).toDouble();
      if (available < 1) {
        if (mounted) showSnack(context, 'لا توجد أرباح متاحة للتحويل حالياً', error: true);
        return;
      }
      final c = TextEditingController(text: available.floor().toString());
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('طلب تحويل الأرباح'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المتاح للتحويل: ${money(available)}'),
            const SizedBox(height: 8),
            TextField(controller: c, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'المبلغ')),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال'))],
        ),
      );
      final amt = double.tryParse(c.text.trim()) ?? 0;
      c.dispose();
      if (ok != true) return;
      if (!amt.isFinite || amt <= 0 || amt > available) {
        if (mounted) showSnack(context, 'المبلغ يجب أن يكون أكبر من صفر ولا يتجاوز ${money(available)}', error: true);
        return;
      }
      final id = db.child('payoutRequests').push().key!;
      await db.child('payoutRequests/$id').set({
        'driverId': myUid,
        'amount': double.parse(amt.toStringAsFixed(2)),
        'status': 'pending',
        'createdAt': ServerValue.timestamp,
      });
      if (mounted) showSnack(context, 'تم إرسال طلب التحويل للإدارة');
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر حساب الرصيد أو إرسال الطلب. تحقق من اتصالك وصلاحيات Firebase.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('الأرباح'), automaticallyImplyLeading: false),
        body: FutureBuilder<List<Ride>>(
          future: _f,
          builder: (c, s) {
            if (s.connectionState != ConnectionState.done) return const LoadingView();
            if (s.hasError) return ErrorView('تعذر تحميل الأرباح', onRetry: () => setState(() => _f = DriverService.myRides()));
            final done = (s.data ?? []).where((r) => r.status == 'completed' && r.completedAt != null).toList();
            final now = DateTime.now(), t0 = DateTime(now.year, now.month, now.day);
            late DateTime from;
            late List<String> labels;
            late List<double> vals;
            late bool Function(DateTime d, int i) hit;
            if (_p == 'week') {
              from = t0.subtract(const Duration(days: 6));
              final days = List.generate(7, (i) => from.add(Duration(days: i)));
              labels = days.map((d) => _dn[d.weekday - 1]).toList();
              hit = (d, i) => d.year == days[i].year && d.month == days[i].month && d.day == days[i].day;
            } else if (_p == 'month') {
              from = t0.subtract(const Duration(days: 27));
              labels = ['أسبوع 1', 'أسبوع 2', 'أسبوع 3', 'أسبوع 4'];
              hit = (d, i) => !d.isBefore(from.add(Duration(days: 7 * i))) && d.isBefore(from.add(Duration(days: 7 * (i + 1))));
            } else {
              from = DateTime(now.year, 1, 1);
              labels = _mn;
              hit = (d, i) => d.year == now.year && d.month == i + 1;
            }
            vals = List.filled(labels.length, 0);
            double total = 0, mins = 0;
            int n = 0;
            for (final r in done) {
              final d = DateTime.fromMillisecondsSinceEpoch(r.completedAt!);
              if (d.isBefore(from)) continue;
              for (var i = 0; i < labels.length; i++) {
                if (hit(d, i)) {
                  vals[i] += _net(r);
                  total += _net(r);
                  mins += r.durationMin;
                  n++;
                  break;
                }
              }
            }
            final mx = vals.fold<double>(1, (a, b) => b > a ? b : a);
            Widget seg(String k, String t) => Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _p = k),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _p == k ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(10), boxShadow: _p == k ? const [BoxShadow(blurRadius: 4, color: Color(0x22000000))] : null),
                      child: Text(t, style: TextStyle(fontWeight: _p == k ? FontWeight.w900 : FontWeight.w500, color: AppColors.ink)),
                    ),
                  ),
                );
            return RefreshIndicator(
              onRefresh: () async => setState(() => _f = DriverService.myRides()),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                InfoCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFFEAF0F4), borderRadius: BorderRadius.circular(12)), child: Row(children: [seg('year', 'سنوي'), seg('month', 'شهري'), seg('week', 'أسبوعي')])),
                    const SizedBox(height: 18),
                    Text(money(total), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                    const Text('إجمالي الأرباح', style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 150,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        for (var i = 0; i < vals.length; i++)
                          Expanded(
                            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                              Container(margin: const EdgeInsets.symmetric(horizontal: 4), height: 100 * (vals[i] / mx) + 4, decoration: BoxDecoration(color: i.isEven ? AppColors.primary : AppColors.green, borderRadius: BorderRadius.circular(5))),
                              const SizedBox(height: 4),
                              Text(labels[i], style: const TextStyle(fontSize: 9, color: Colors.grey), overflow: TextOverflow.clip, maxLines: 1),
                            ]),
                          ),
                      ]),
                    ),
                    const Divider(height: 26),
                    Row(children: [
                      Expanded(child: Column(children: [Text('$n', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const Text('رحلة عمل', style: TextStyle(color: Colors.grey))])),
                      Container(width: 1, height: 36, color: const Color(0xFFE6ECF0)),
                      Expanded(child: Column(children: [Text((mins / 60).toStringAsFixed(1), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)), const Text('ساعة عمل', style: TextStyle(color: Colors.grey))])),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                AppButton('طلب تحويل الأرباح', onPressed: done.isNotEmpty ? _payout : null),
              ]),
            );
          },
        ),
      );
}
