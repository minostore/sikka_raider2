import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../services/driver_service.dart';
import '../services/routing_service.dart';
import '../widgets/app_map.dart';
import '../widgets/common.dart';
import '../widgets/map_utils.dart';
import '../widgets/markers.dart';

/// تفاصيل الطلب: الخريطة + المسافة والسعر ثم قبول (إرسال عرض) أو رفض
class RequestDetailsScreen extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> data;
  const RequestDetailsScreen({super.key, required this.requestId, required this.data});
  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  final _map = MapController();
  late final Place _pickup = Place.fromMap(asMap(widget.data['pickup']));
  late final Place _dest = Place.fromMap(asMap(widget.data['dest']));
  late final _price = TextEditingController(text: numD(widget.data['price']).round().toString());
  final _note = TextEditingController(text: 'سأصل خلال دقائق');
  RouteInfo? _toPickup, _trip;
  bool _sent = false, _busy = false, _gone = false;
  Timer? _timer;
  StreamSubscription? _sub;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    final exp = (widget.data['expiresAt'] as num?)?.toInt() ?? 0;
    _left = ((exp - DateTime.now().millisecondsSinceEpoch) / 1000).round();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _left--);
    });
    _sub = db.child('openRequests/${widget.requestId}').onValue.listen((e) {
      if (!e.snapshot.exists && mounted) setState(() => _gone = true);
    }, onError: (_) {});
    _route();
  }

  Future<void> _route() async {
    final me = LocationPublisher.position.value;
    final t = await RoutingService.route(_pickup.point, _dest.point);
    RouteInfo? p;
    if (me != null) p = await RoutingService.route(me, _pickup.point);
    if (!mounted) return;
    setState(() {
      _trip = t;
      _toPickup = p;
    });
    fitPoints(_map, [if (me != null) me, ...t.points]);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final price = double.tryParse(_price.text.trim()) ?? 0;
    if (price <= 0) return showSnack(context, 'أدخل سعراً صحيحاً', error: true);
    setState(() => _busy = true);
    try {
      await DriverService.sendOffer(rideId: widget.requestId, price: price, etaMin: (_toPickup?.durationMin ?? 5).round().clamp(1, 120), note: _note.text.trim());
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) showSnack(context, 'تعذر إرسال العرض. قد يكون الطلب انتهى.', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _stop(Color c, String t, String sub) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.location_on, color: c, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text(t, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
      ]);

  @override
  Widget build(BuildContext context) {
    final locked = _gone || _left <= 0;
    final mm = (_left.clamp(0, 99999) ~/ 60).toString().padLeft(2, '0'), ss = (_left.clamp(0, 99999) % 60).toString().padLeft(2, '0');
    final me = LocationPublisher.position.value;
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الطلب')),
      body: Column(children: [
        Expanded(
          child: AppMap(
            controller: _map,
            center: _pickup.point,
            zoom: 13,
            showControls: false,
            polylines: [if (_trip != null) Polyline(points: _trip!.points, strokeWidth: 4, color: const Color(0xFF0A78FA))],
            markers: [Markers.pin(_pickup.point, AppColors.green), Markers.pin(_dest.point, const Color(0xFF0A78FA)), if (me != null) Markers.me(me)],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
          child: SafeArea(
            top: false,
            child: Theme(
              data: AppTheme.light,
              child: DefaultTextStyle.merge(
              style: const TextStyle(color: AppColors.ink),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                _stop(AppColors.primary, _pickup.address, ''),
                const SizedBox(height: 8),
                _stop(AppColors.red, _dest.address, ''),
                const Divider(height: 22),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('المسافة', style: TextStyle(color: Colors.grey, fontSize: 12)), Text('${numD(widget.data['distanceKm']).toStringAsFixed(1)} كم', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))])),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('الوقت', style: TextStyle(color: Colors.grey, fontSize: 12)), Text('${numD(widget.data['durationMin']).round()} دقيقة', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))])),
                  if (_toPickup != null) Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('إلى الراكب', style: TextStyle(color: Colors.grey, fontSize: 12)), Text('${_toPickup!.distanceKm.toStringAsFixed(1)} كم', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))])),
                ]),
                const SizedBox(height: 4),
                Text(locked ? 'انتهى هذا الطلب أو لم يعد متاحاً' : 'ينتهي الطلب خلال $mm:$ss', style: TextStyle(color: locked ? AppColors.red : AppColors.orange, fontSize: 12)),
                const SizedBox(height: 10),
                if (_sent && !locked) ...[
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: Text('تم إرسال عرضك. بانتظار قرار الراكب...', style: TextStyle(fontWeight: FontWeight.w800)))),
                  Center(child: TextButton(onPressed: () async { await DriverService.withdrawOffer(widget.requestId); if (mounted) setState(() => _sent = false); }, child: const Text('سحب العرض'))),
                ] else if (!locked) ...[
                  Row(children: [
                    SizedBox(width: 120, child: TextField(controller: _price, keyboardType: TextInputType.number, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20), decoration: InputDecoration(labelText: 'سعرك (${AppConfigCurrency.c})', filled: true, fillColor: AppColors.field))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة للراكب', filled: true, fillColor: AppColors.field))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: SizedBox(height: 50, child: AppButton('قبول', color: AppColors.green, onPressed: _send, busy: _busy))),
                    const SizedBox(width: 10),
                    Expanded(child: SizedBox(height: 50, child: AppButton('رفض', color: AppColors.red, onPressed: () => Navigator.pop(context, 'hide')))),
                  ]),
                ] else
                  const Center(child: Padding(padding: EdgeInsets.all(10), child: Text('الطلب غير متاح'))),
              ]),
            )),
          ),
        ),
      ]),
    );
  }
}

class AppConfigCurrency {
  static String get c => money(0).split(' ').last;
}
