import 'package:flutter/material.dart';
import '../core/utils.dart';
import '../models/ride.dart';
import '../services/ride_service.dart';
import '../widgets/common.dart';
import 'ride_flow_screen.dart';
import 'trip_request_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});
  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  Future<List<Ride>> _f = RideService.myRides();
  String _tab = 'all';

  void _reload() => setState(() => _f = RideService.myRides());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('رحلاتي')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(spacing: 8, children: [
              for (final e in const {'all': 'الكل', 'past': 'السابقة', 'active': 'النشطة'}.entries)
                ChoiceChip(
                    label: Text(e.value),
                    selected: _tab == e.key,
                    onSelected: (_) => setState(() => _tab = e.key)),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<Ride>>(
                future: _f,
                builder: (c, s) {
                  if (s.connectionState != ConnectionState.done) return const LoadingView();
                  if (s.hasError) return ErrorView('تعذر تحميل الرحلات', onRetry: _reload);
                  var list = s.data ?? [];
                  bool done(Ride r) => r.status == 'completed' || r.status == 'cancelled';
                  if (_tab == 'past') list = list.where(done).toList();
                  if (_tab == 'active') list = list.where((r) => !done(r)).toList();
                  if (list.isEmpty) return ListView(children: const [SizedBox(height: 120), EmptyView('لا توجد رحلات')]);
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _tile(list[i]),
                  );
                },
              ),
            ),
          ),
        ]),
      );

  Widget _tile(Ride r) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (r.status == 'completed' || r.status == 'cancelled') {
            showModalBottomSheet(
              context: context,
              builder: (_) => Padding(
                padding: const EdgeInsets.all(18),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('من: ${r.pickup.address}'),
                  const SizedBox(height: 4),
                  Text('إلى: ${r.dest.address}'),
                  const SizedBox(height: 8),
                  Text('${r.distanceKm.toStringAsFixed(1)} كم • ${money(r.finalPrice)} • ${dateLabel(r.createdAt)}'),
                  if (r.driverName != null) Text('السائق: ${r.driverName}'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => TripRequestScreen(pickup: r.pickup, dest: r.dest)));
                    },
                    child: const Text('إعادة الطلب'),
                  ),
                ]),
              ),
            );
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => RideFlowScreen(rideId: r.id)));
          }
        },
        child: InfoCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.pickup.address.split('،').first} ← ${r.dest.address.split('،').first}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(dateLabel(r.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(money(r.finalPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
              Pill(statusLabel(r.status), statusColor(r.status)),
            ]),
          ]),
        ),
      );
}
