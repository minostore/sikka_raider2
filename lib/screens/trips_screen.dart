import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/ride.dart';
import '../services/driver_service.dart';
import '../widgets/common.dart';
import 'ratings_screen.dart';

/// سجل الرحلات
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  Future<List<Ride>> _f = DriverService.myRides();

  String _day(DateTime d) {
    final n = DateTime.now(), t = DateTime(n.year, n.month, n.day);
    final x = DateTime(d.year, d.month, d.day);
    if (x == t) return 'اليوم';
    if (x == t.subtract(const Duration(days: 1))) return 'أمس';
    return '${d.year}/${d.month}/${d.day}';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('سجل الرحلات'), automaticallyImplyLeading: false, actions: [
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingsScreen())), child: const Text('التقييمات', style: TextStyle(color: AppColors.primary))),
        ]),
        body: RefreshIndicator(
          onRefresh: () async => setState(() => _f = DriverService.myRides()),
          child: FutureBuilder<List<Ride>>(
            future: _f,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) return const LoadingView();
              if (s.hasError) return ErrorView('تعذر تحميل الرحلات', onRetry: () => setState(() => _f = DriverService.myRides()));
              final l = (s.data ?? []).where((r) => r.createdAt != null).toList();
              if (l.isEmpty) return ListView(children: const [SizedBox(height: 140), EmptyView('لا توجد رحلات بعد')]);
              final children = <Widget>[];
              String? last;
              for (final r in l) {
                final d = DateTime.fromMillisecondsSinceEpoch(r.createdAt!);
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
                      Text(money(r.finalPrice), style: const TextStyle(fontWeight: FontWeight.w900)),
                      if (r.status != 'completed') Pill(statusLabel(r.status), statusColor(r.status)),
                    ]),
                  ),
                  const Divider(height: 1),
                ]));
              }
              return ListView(padding: const EdgeInsets.all(16), children: [InfoCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children))]);
            },
          ),
        ),
      );
}
