import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../services/driver_service.dart';
import '../services/location_service.dart';
import '../services/zone_service.dart';
import '../widgets/app_map.dart';
import '../widgets/common.dart';
import '../widgets/markers.dart';
import 'request_details_screen.dart';

class DriverHome extends StatefulWidget {
  const DriverHome({super.key});
  @override
  State<DriverHome> createState() => _DriverHomeState();
}

class _DriverHomeState extends State<DriverHome> {
  final _map = MapController();
  bool _online = false, _busy = false;
  final Set<String> _hidden = {};

  @override
  void initState() {
    super.initState();
    LocationPublisher.stop(); // يبدأ دائماً غير متصل
    db.child('drivers/$myUid/online').set(false).catchError((_) {});
  }

  Future<void> _toggle(bool v) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (v) {
        final p = await LocationService.current(); // يتحقق من GPS والصلاحيات
        if (!ZoneService.allowed(p)) {
          if (mounted) showSnack(context, 'موقعك الحالي خارج نطاق الخدمة، لا يمكنك استقبال الرحلات من هنا.', error: true);
          if (mounted) setState(() => _busy = false);
          return;
        }
        await LocationPublisher.start();
      } else {
        await LocationPublisher.stop();
      }
      await db.child('drivers/$myUid/online').set(v);
      setState(() => _online = v);
    } catch (e) {
      if (mounted) showLocationError(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _toggleBar() => GestureDetector(
        onTap: () => _toggle(!_online),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 36, vertical: 10),
          height: 56,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _online ? const [Color(0xFF14D98A), Color(0xFF0BBF73)] : const [Color(0xFF2B4B69), Color(0xFF2B4B69)]),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(alignment: Alignment.center, children: [
            Text(_online ? 'متاح للرحلات' : 'غير متصل', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              alignment: _online ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(width: 46, height: 46, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: _busy ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(_online ? 'متاح للرحلات' : 'غير متصل', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          _toggleBar(),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ValueListenableBuilder<LatLng?>(
                  valueListenable: LocationPublisher.position,
                  builder: (_, p, __) => AppMap(
                    controller: _map,
                    center: p ?? AppConfig.defaultCenter,
                    zoom: 15,
                    markers: [if (p != null) _pulse(p)],
                    onRecenter: () {
                      final q = LocationPublisher.position.value;
                      if (q != null) _map.move(q, 15);
                    },
                  ),
                ),
              ),
            ),
          ),
          if (_online)
            Expanded(
              flex: 3,
              child: StreamBuilder<DatabaseEvent>(
                stream: db.child('openRequests').onValue,
                builder: (c, s) {
                  if (s.hasError) return const ErrorView('تعذر تحميل الطلبات. تحقق من اتصالك.');
                  if (!s.hasData) return const LoadingView();
                  final now = DateTime.now().millisecondsSinceEpoch;
                  final me = LocationPublisher.position.value;
                  final items = <MapEntry<String, Map<String, dynamic>>>[];
                  asMap(s.data!.snapshot.value).forEach((id, v) {
                    final m = asMap(v);
                    if (_hidden.contains(id) || ((m['expiresAt'] as num?) ?? 0) < now) return;
                    final pk = Place.fromMap(asMap(m['pickup'])).point;
                    if (me != null && haversineKm(me, pk) > 15) return;
                    items.add(MapEntry(id, m));
                  });
                  if (items.isEmpty) return const EmptyView('لا توجد طلبات قريبة الآن', icon: Icons.search_off);
                  return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 8), children: [for (final e in items) _requestCard(e.key, e.value, me)]);
                },
              ),
            )
          else
            const Padding(padding: EdgeInsets.all(18), child: Text('فعّل حالة العمل لاستقبال طلبات الرحلات', style: TextStyle(color: Colors.white60))),
        ]),
      );

  Marker _pulse(LatLng p) => Marker(
        point: p,
        width: 90,
        height: 90,
        child: Stack(alignment: Alignment.center, children: [
          Container(decoration: BoxDecoration(color: const Color(0xFF0A78FA).withValues(alpha: 0.18), shape: BoxShape.circle)),
          Container(width: 24, height: 24, decoration: BoxDecoration(color: const Color(0xFF0A78FA), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3))),
        ]),
      );

  Widget _requestCard(String id, Map<String, dynamic> m, LatLng? me) {
    final pk = Place.fromMap(asMap(m['pickup'])), ds = Place.fromMap(asMap(m['dest']));
    final toRider = me == null ? null : haversineKm(me, pk.point);
    Widget stop(Color c, String t) => Row(children: [Icon(Icons.location_on, color: c, size: 20), const SizedBox(width: 8), Expanded(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)))]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InfoCard(
        child: Column(children: [
          Row(children: [
            const CircleAvatar(radius: 22, backgroundColor: Color(0xFFE9F1F5), child: Icon(Icons.person, color: AppColors.ink)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('طلب رحلة جديد', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text('${numD(m['distanceKm']).toStringAsFixed(1)} كم  •  ${numD(m['durationMin']).round()} دقيقة${toRider == null ? '' : '  •  ${toRider.toStringAsFixed(1)} كم إليه'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ])),
            Text(money(numD(m['price'])), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          ]),
          const SizedBox(height: 10),
          stop(AppColors.primary, pk.address),
          const SizedBox(height: 6),
          stop(AppColors.red, ds.address),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: AppButton('قبول', color: AppColors.green, onPressed: () async {
                  final r = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => RequestDetailsScreen(requestId: id, data: m)));
                  if (r == 'hide') setState(() => _hidden.add(id));
                }),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 46, child: AppButton('رفض', color: AppColors.red, onPressed: () => setState(() => _hidden.add(id))))),
          ]),
        ]),
      ),
    );
  }
}
