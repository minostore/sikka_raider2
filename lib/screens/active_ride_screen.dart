import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/ride.dart';
import '../services/driver_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../widgets/app_map.dart';
import '../widgets/common.dart';
import '../widgets/map_utils.dart';
import '../widgets/markers.dart';

const _blue = Color(0xFF0A78FA);

class ActiveRideScreen extends StatefulWidget {
  final String rideId;
  const ActiveRideScreen({super.key, required this.rideId});
  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  final _map = MapController();
  final _code = TextEditingController();
  RouteInfo? _route;
  DateTime _lastRoute = DateTime.fromMillisecondsSinceEpoch(0);
  bool _busy = false;
  Ride? _ride;
  int _riderStars = 5;

  @override
  void initState() {
    super.initState();
    _begin();
    LocationPublisher.position.addListener(_onPos);
  }

  Future<void> _begin() async {
    try {
      await LocationPublisher.start();
    } catch (e) {
      if (mounted) showLocationError(context, e);
    }
    await db.child('driverTrips/$myUid/${widget.rideId}').set(true).catchError((_) {});
  }

  @override
  void dispose() {
    LocationPublisher.position.removeListener(_onPos);
    super.dispose();
  }

  void _onPos() {
    final r = _ride, p = LocationPublisher.position.value;
    if (r == null || p == null || r.status == 'completed' || r.status == 'cancelled') return;
    if (DateTime.now().difference(_lastRoute).inSeconds < 20) return;
    _lastRoute = DateTime.now();
    final target = r.status == 'started' ? r.dest.point : r.pickup.point;
    RoutingService.route(p, target).then((info) {
      if (mounted) setState(() => _route = info);
    });
  }

  Future<void> _update(Map<String, Object?> up, {String? state}) async {
    setState(() => _busy = true);
    try {
      await db.child('rides/${widget.rideId}').update(up);
      if (state != null) LocationPublisher.setRide(widget.rideId, state: state);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر تحديث الرحلة. تحقق من الاتصال.', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish(Ride r) async {
    if (!await confirmDialog(context, 'إنهاء الرحلة', 'هل وصلت إلى الوجهة؟\nالأجرة النهائية: ${money(r.finalPrice)} (نقداً)', yes: 'تأكيد إنهاء الرحلة')) return;
    setState(() => _busy = true);
    try {
      final pct = await DriverService.commissionPercent();
      final commission = double.parse((r.finalPrice * pct / 100).toStringAsFixed(2));
      await db.update({
        'rides/${r.id}/status': 'completed',
        'rides/${r.id}/completedAt': ServerValue.timestamp,
        'rides/${r.id}/commission': commission,
        'rides/${r.id}/finalPrice': r.finalPrice,
        'driverActive/$myUid': null,
      });
      await db.child('drivers/$myUid/tripsCount').runTransaction((v) => Transaction.success(((v as num?) ?? 0).toInt() + 1));
      LocationPublisher.setRide(null);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر إنهاء الرحلة', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel(Ride r) async {
    if (!await confirmDialog(context, 'إلغاء الرحلة', 'هل تريد إلغاء الرحلة؟ قد يؤثر ذلك على تقييمك.', yes: 'نعم، إلغاء')) return;
    try {
      await db.update({'rides/${r.id}/status': 'cancelled', 'rides/${r.id}/cancelledBy': 'driver', 'rides/${r.id}/cancelledAt': ServerValue.timestamp, 'driverActive/$myUid': null});
      LocationPublisher.setRide(null);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر الإلغاء', error: true);
    }
  }

  Future<void> _launch(String scheme, String phone) async {
    if (phone.isEmpty) return;
    await launchUrl(Uri(scheme: scheme, path: '+$phone'));
  }

  /// بدء التوجيه عبر تطبيق الخرائط في الهاتف
  Future<void> _navigate(LatLng to) async {
    final nav = Uri.parse('google.navigation:q=${to.latitude},${to.longitude}');
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${to.latitude},${to.longitude}&travelmode=driving');
    if (!await launchUrl(nav, mode: LaunchMode.externalApplication)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _done(Ride r) async {
    await db.child('rides/${r.id}/riderScore').set(_riderStars).catchError((_) {});
    LocationPublisher.setRide(null);
    await db.child('driverActive/$myUid').remove().catchError((_) {});
    if (mounted) Navigator.pop(context);
  }

  String _title(Ride? r) {
    switch (r?.status) {
      case 'accepted':
        return 'قبول الرحلة';
      case 'arrived':
        return 'الوصول إلى الراكب';
      case 'started':
        return 'الرحلة الحالية';
      case 'completed':
        return 'إنهاء الرحلة';
      default:
        return 'الرحلة';
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<DatabaseEvent>(
        stream: db.child('rides/${widget.rideId}').onValue,
        builder: (c, s) {
          Widget body;
          Ride? r;
          if (s.hasError) {
            body = const ErrorView('تعذر تحميل الرحلة');
          } else if (!s.hasData) {
            body = const LoadingView();
          } else if (!s.data!.snapshot.exists) {
            body = const EmptyView('الرحلة غير موجودة');
          } else {
            r = Ride.fromMap(widget.rideId, asMap(s.data!.snapshot.value));
            if (_ride?.status != r.status) {
              _ride = r;
              _route = null;
              _lastRoute = DateTime.fromMillisecondsSinceEpoch(0);
              WidgetsBinding.instance.addPostFrameCallback((_) => _onPos());
              if (r.status == 'accepted' || r.status == 'arrived' || r.status == 'started') LocationPublisher.setRide(r.id, state: r.status);
            }
            _ride = r;
            if (r.status == 'cancelled') {
              body = _ended('ألغى الراكب الرحلة', Icons.cancel, AppColors.red, r);
            } else if (r.status == 'completed') {
              body = _completed(r);
            } else {
              body = _active(r);
            }
          }
          return Scaffold(appBar: AppBar(title: Text(_title(r))), body: body);
        },
      );

  Widget _ended(String msg, IconData i, Color col, Ride r) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(i, size: 72, color: col),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            AppButton('العودة للرئيسية', onPressed: () => _done(r)),
          ]),
        ),
      );

  // إنهاء الرحلة (تقييم الراكب)
  Widget _completed(Ride r) => ListView(padding: const EdgeInsets.all(18), children: [
        InfoCard(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Container(width: 66, height: 66, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.check, color: Colors.white, size: 40)),
            const SizedBox(height: 10),
            const Text('تم إنهاء الرحلة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Text(money(r.finalPrice), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            Text('صافي ربحك: ${money(r.finalPrice - r.commission)}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _cell('المسافة', '${r.distanceKm.toStringAsFixed(1)} كم')),
              Expanded(child: _cell('المدة', '${r.durationMin.round()} دقيقة')),
            ]),
            const SizedBox(height: 14),
            const Text('كيف كانت رحلتك؟', style: TextStyle(color: Colors.grey)),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++) IconButton(iconSize: 34, onPressed: () => setState(() => _riderStars = i), icon: Icon(i <= _riderStars ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.orange)),
            ]),
            AppButton('العودة للرئيسية', onPressed: () => _done(r)),
          ]),
        ),
      ]);

  Widget _cell(String k, String v) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Text(k, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(v, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
      );

  Widget _active(Ride r) {
    final me = LocationPublisher.position.value;
    final heading = me != null && _route != null && _route!.points.length > 1 ? bearing(me, _route!.points[1]) : 0.0;
    final target = r.status == 'started' ? r.dest.point : r.pickup.point;
    return Column(children: [
      Expanded(
        child: AppMap(
          controller: _map,
          center: me ?? r.pickup.point,
          zoom: 14,
          onRecenter: () {
            if (me != null) fitPoints(_map, [me, target]);
          },
          polylines: [if (_route != null) Polyline(points: _route!.points, strokeWidth: 5, color: _blue)],
          markers: [
            if (r.status != 'started') Markers.pin(r.pickup.point, _blue, icon: Icons.person_pin_circle),
            Markers.pin(r.dest.point, AppColors.red),
            if (me != null) Markers.car(me, heading: heading, color: AppColors.navy),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22)), boxShadow: [BoxShadow(blurRadius: 14, color: Colors.black38)]),
        child: SafeArea(
          top: false,
          child: Theme(
            data: AppTheme.light,
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: AppColors.ink),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (r.status == 'started') ...[
                  const Center(child: Text('الرحلة الحالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _cell('المسافة المتبقية', _route == null ? '—' : '${_route!.distanceKm.toStringAsFixed(1)} كم')),
                    Expanded(child: _cell('الوقت المتوقع', _route == null ? '—' : '${_route!.durationMin.round()} دقيقة')),
                  ]),
                  const SizedBox(height: 4),
                  Text('الوجهة: ${r.dest.address}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  AppButton('إنهاء الرحلة', color: AppColors.red, onPressed: () => _finish(r), busy: _busy),
                ] else ...[
                  if (r.status == 'accepted') ...[
                    const Center(child: Text('تم قبول الرحلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    const Center(child: Text('جار التوجيه إلى الراكب', style: TextStyle(color: Colors.grey))),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    const CircleAvatar(radius: 24, backgroundColor: Color(0xFFE3EEFB), child: Icon(Icons.person, color: _blue)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.riderName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(r.pickup.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _blue, fontSize: 13)),
                      Text('${money(r.finalPrice)} (نقداً)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ])),
                    InkWell(onTap: () => _launch('tel', r.riderPhone), child: Container(padding: const EdgeInsets.all(11), decoration: const BoxDecoration(color: Color(0xFFE9F1F5), shape: BoxShape.circle), child: const Icon(Icons.call, color: AppColors.primary))),
                    const SizedBox(width: 6),
                    InkWell(onTap: () => _launch('sms', r.riderPhone), child: Container(padding: const EdgeInsets.all(11), decoration: const BoxDecoration(color: Color(0xFFE9F1F5), shape: BoxShape.circle), child: const Icon(Icons.message, color: AppColors.primary))),
                  ]),
                  const SizedBox(height: 12),
                  if (r.status == 'accepted') ...[
                    AppButton('ابدأ التوجيه', color: _blue, icon: Icons.navigation, onPressed: () => _navigate(r.pickup.point)),
                    const SizedBox(height: 8),
                    AppButton('تم الوصول', onPressed: () => _update({'status': 'arrived', 'arrivedAt': ServerValue.timestamp}, state: 'arrived'), busy: _busy),
                  ],
                  if (r.status == 'arrived') ...[
                    TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(labelText: 'رمز الراكب (4 أرقام)', counterText: '', filled: true, fillColor: AppColors.field)),
                    const SizedBox(height: 8),
                    AppButton('بدء الرحلة', busy: _busy, onPressed: () {
                      if (_code.text.trim() != r.startCode) return showSnack(context, 'رمز الراكب غير صحيح', error: true);
                      _update({'status': 'started', 'startedAt': ServerValue.timestamp}, state: 'started');
                    }),
                  ],
                  if (r.status == 'accepted' || r.status == 'arrived') TextButton(onPressed: () => _cancel(r), child: const Text('إلغاء الرحلة', style: TextStyle(color: AppColors.red))),
                ],
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}
