import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/ride.dart';
import '../services/driver_service.dart';
import '../widgets/common.dart';
import 'ratings_screen.dart';

/// سجل الرحلات: الرحلات المكتملة والملغاة (مع فلترة يومي / أسبوعي / شهري)
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  static const bool _periodFilter = true;
  Future<List<Ride>> _f = DriverService.myRides();
  String _p = _periodFilter ? 'day' : 'all'; // day | week | month | all
  String _st = 'all'; // all | completed | cancelled

  String _day(DateTime d) {
    final n = DateTime.now(), t = DateTime(n.year, n.month, n.day);
    final x = DateTime(d.year, d.month, d.day);
    if (x == t) return 'اليوم';
    if (x == t.subtract(const Duration(days: 1))) return 'أمس';
    return '${d.year}/${d.month}/${d.day}';
  }

  DateTime _when(Ride r) => DateTime.fromMillisecondsSinceEpoch(r.completedAt ?? r.createdAt ?? 0);

  bool _inPeriod(Ride r) {
    if (_p == 'all') return true;
    final now = DateTime.now(), t0 = DateTime(now.year, now.month, now.day);
    final from = _p == 'day' ? t0 : _p == 'week' ? t0.subtract(const Duration(days: 6)) : t0.subtract(const Duration(days: 29));
    return !_when(r).isBefore(from);
  }

  void _reload() => setState(() => _f = DriverService.myRides());

  Widget _seg(String k, String t, String cur, void Function(String) on) => Expanded(
        child: GestureDetector(
          onTap: () => on(k),
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: cur == k ? AppColors.card : Colors.transparent, borderRadius: BorderRadius.circular(10), boxShadow: cur == k ? const [BoxShadow(blurRadius: 4, color: Color(0x22000000))] : null),
            child: Text(t, style: TextStyle(fontWeight: cur == k ? FontWeight.w900 : FontWeight.w500, color: AppColors.ink)),
          ),
        ),
      );

  Widget _bar(String cur, List<(String, String)> items, void Function(String) on) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [for (final i in items) _seg(i.$1, i.$2, cur, on)]),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('سجل الرحلات'), automaticallyImplyLeading: false, actions: [
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingsScreen())), child: const Text('التقييمات', style: TextStyle(color: AppColors.primary))),
        ]),
        body: RefreshIndicator(
          onRefresh: () async => _reload(),
          child: FutureBuilder<List<Ride>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const LoadingView();
              if (s.hasError) return ErrorView('تعذر تحميل الرحلات', onRetry: _reload);
              // الرحلات المنتهية فقط (مكتملة / ملغاة)
              final finished = (s.data ?? []).where((r) => r.createdAt != null && (r.status == 'completed' || r.status == 'cancelled')).toList();
              final inPeriod = finished.where(_inPeriod).toList();
              final done = inPeriod.where((r) => r.status == 'completed').length;
              final cancelled = inPeriod.where((r) => r.status == 'cancelled').length;
              final l = inPeriod.where((r) => _st == 'all' || r.status == _st).toList();
              final children = <Widget>[];
              String? last;
              for (final r in l) {
                final d = _when(r);
                final g = _day(d);
                if (g != last) {
                  last = g;
                  children.add(Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text(g, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w700))));
                }
                final tm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
                children.add(Column(children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tm, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${r.pickup.address.split('،').first} - ${r.dest.address.split('،').first}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      if (r.status == 'completed') Text(money(r.finalPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                      Pill(statusLabel(r.status), statusColor(r.status)),
                    ]),
                  ),
                  const Divider(height: 1),
                ]));
              }
              return ListView(padding: const EdgeInsets.all(16), children: [
                if (_periodFilter) ...[
                  _bar(_p, const [('month', 'شهري'), ('week', 'أسبوعي'), ('day', 'يومي')], (k) => setState(() => _p = k)),
                  const SizedBox(height: 10),
                ],
                _bar(_st, [('all', 'الكل (${done + cancelled})'), ('completed', 'مكتملة ($done)'), ('cancelled', 'ملغاة ($cancelled)')], (k) => setState(() => _st = k)),
                const SizedBox(height: 12),
                if (l.isEmpty)
                  const Padding(padding: EdgeInsets.only(top: 80), child: EmptyView('لا توجد رحلات في هذه الفترة'))
                else
                  InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
              ]);
            },
          ),
        ),
      );
}
