import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/ride.dart';
import '../services/ride_service.dart';
import '../services/routing_service.dart';
import '../widgets/app_map.dart';
import '../widgets/common.dart';
import '../widgets/map_utils.dart';
import '../widgets/markers.dart';

/// يتابع حالة الرحلة لحظياً ويعرض: العروض ← التتبع ← التقييم
class RideFlowScreen extends StatelessWidget {
  final String rideId;
  const RideFlowScreen({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('رحلتك')),
        body: StreamBuilder<DatabaseEvent>(
          stream: RideService.db.child('rides/$rideId').onValue,
          builder: (c, s) {
            if (s.hasError) return const ErrorView('تعذر تحميل بيانات الرحلة.');
            if (!s.hasData) return const LoadingView();
            if (!s.data!.snapshot.exists) return const EmptyView('الرحلة غير موجودة');
            final ride = Ride.fromMap(rideId, asMap(s.data!.snapshot.value));
            switch (ride.status) {
              case 'requested':
                return _OffersView(ride: ride);
              case 'completed':
                return _RatingView(ride: ride);
              case 'cancelled':
                return _CancelledView(ride: ride);
              default:
                return _TrackingView(ride: ride);
            }
          },
        ),
      );
}

Future<void> _openCall(BuildContext c, String phone) async {
  if (phone.isEmpty) return showSnack(c, 'رقم الهاتف غير متاح', error: true);
  final ok = await launchUrl(Uri(scheme: 'tel', path: '+$phone'));
  if (!ok && c.mounted) showSnack(c, 'تعذر فتح تطبيق الاتصال', error: true);
}

// ───────────────────────── العروض ─────────────────────────
class _OffersView extends StatefulWidget {
  final Ride ride;
  const _OffersView({required this.ride});
  @override
  State<_OffersView> createState() => _OffersViewState();
}

class _OffersViewState extends State<_OffersView> {
  String _sort = 'price';
  bool _busy = false;

  Future<void> _cancel() async {
    if (!await confirmDialog(context, 'إلغاء الطلب', 'هل تريد إلغاء طلب الرحلة؟',
        yes: 'نعم، إلغاء')) {
      return;
    }
    try {
      await RideService.cancel(widget.ride.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر إلغاء الطلب', error: true);
    }
  }

  Future<void> _accept(Offer o) async {
    if (!await confirmDialog(context, 'تأكيد السائق',
        'اختيار ${o.name} بسعر ${money(o.price)}؟')) {
      return;
    }
    setState(() => _busy = true);
    try {
      await RideService.acceptOffer(widget.ride.id, o);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر قبول العرض. حاول مجدداً.', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ride;
    return Column(children: [
      InfoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('من: ${r.pickup.address}', maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('إلى: ${r.dest.address}', maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('سعرك المقترح: ${money(r.price)} • ${r.distanceKm.toStringAsFixed(1)} كم',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          const Text('الفرز: '),
          for (final e in const {'price': 'السعر الأقل', 'eta': 'الأقرب وصولاً', 'rating': 'الأعلى تقييماً'}.entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: ChoiceChip(
                label: Text(e.value, style: const TextStyle(fontSize: 12)),
                selected: _sort == e.key,
                onSelected: (_) => setState(() => _sort = e.key),
              ),
            ),
        ]),
      ),
      Expanded(
        child: StreamBuilder<DatabaseEvent>(
          stream: RideService.db.child('rides/${r.id}/offers').onValue,
          builder: (c, s) {
            final offers = <Offer>[];
            if (s.hasData && s.data!.snapshot.exists) {
              asMap(s.data!.snapshot.value).forEach((k, v) => offers.add(Offer.fromMap(k, asMap(v))));
            }
            offers.sort((a, b) {
              switch (_sort) {
                case 'eta':
                  return a.etaMin.compareTo(b.etaMin);
                case 'rating':
                  return b.rating.compareTo(a.rating);
                default:
                  return a.price.compareTo(b.price);
              }
            });
            final expired = r.createdAt != null &&
                DateTime.now().millisecondsSinceEpoch - r.createdAt! > 10 * 60 * 1000;
            if (offers.isEmpty) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (!expired) const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text(expired
                      ? 'انتهت مهلة الطلب بدون عروض. ألغِ الطلب وأعد المحاولة.'
                      : 'جاري إرسال طلبك للسائقين القريبين...'),
                ]),
              );
            }
            return ListView(padding: const EdgeInsets.all(12), children: [
              for (final o in offers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InfoCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const CircleAvatar(child: Icon(Icons.person)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('★ ${o.rating.toStringAsFixed(1)} • ${o.trips} رحلة',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ]),
                        ),
                        Text(money(o.price),
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ]),
                      const SizedBox(height: 6),
                      Text('${o.vehicle} • يصل خلال ${o.etaMin} دقائق'),
                      if (o.note.isNotEmpty) Text(o.note, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                        onPressed: _busy ? null : () => _accept(o),
                        child: const Text('اختيار'),
                      ),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red, minimumSize: const Size.fromHeight(48)),
            onPressed: _cancel,
            child: const Text('إلغاء الطلب'),
          ),
        ),
      ),
    ]);
  }
}

// ───────────────────────── التتبع ─────────────────────────
class _TrackingView extends StatefulWidget {
  final Ride ride;
  const _TrackingView({required this.ride});
  @override
  State<_TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends State<_TrackingView> {
  final _map = MapController();
  StreamSubscription? _sub;
  LatLng? _driver;
  double _heading = 0;
  int? _updatedAt;
  RouteInfo? _route;
  DateTime _lastRoute = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _tick;

  Ride get r => widget.ride;
  LatLng get _target => r.status == 'started' ? r.dest.point : r.pickup.point;

  @override
  void initState() {
    super.initState();
    _sub = RideService.db.child('driverLocations/${r.driverId}').onValue.listen((e) {
      if (!e.snapshot.exists) return;
      final m = asMap(e.snapshot.value);
      final p = LatLng(numD(m['lat']), numD(m['lng']));
      setState(() {
        _driver = p;
        _heading = numD(m['heading']);
        _updatedAt = (m['updatedAt'] as num?)?.toInt();
      });
      _maybeRoute(p);
    }, onError: (_) {});
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _maybeRoute(LatLng p) async {
    if (DateTime.now().difference(_lastRoute).inSeconds < 25) return;
    _lastRoute = DateTime.now();
    final info = await RoutingService.route(p, _target);
    if (!mounted) return;
    setState(() => _route = info);
    if (_route != null && _route!.points.length > 1) fitPoints(_map, [p, _target]);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _cancel() async {
    if (!await confirmDialog(context, 'إلغاء الرحلة', 'هل أنت متأكد من إلغاء الرحلة؟',
        yes: 'نعم، إلغاء')) {
      return;
    }
    try {
      await RideService.cancel(r.id, driverId: r.driverId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر الإلغاء', error: true);
    }
  }

  Future<void> _report() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('الإبلاغ عن مشكلة'),
        content: TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(hintText: 'اشرح المشكلة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('إرسال')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      try {
        await RideService.createTicket('بلاغ عن رحلة', ctrl.text.trim(), rideId: r.id);
        if (mounted) showSnack(context, 'تم إرسال البلاغ للدعم');
      } catch (_) {
        if (mounted) showSnack(context, 'تعذر إرسال البلاغ', error: true);
      }
    }
  }

  void _share() {
    final p = _driver;
    final link = p == null
        ? ''
        : '\nhttps://www.openstreetmap.org/?mlat=${p.latitude}&mlon=${p.longitude}#map=16/${p.latitude}/${p.longitude}';
    SharePlus.instance.share(ShareParams(
        text: 'أنا في رحلة مع مشوار إلى ${r.dest.address}\nالسائق: ${r.driverName ?? ''} - ${r.vehicle ?? ''}$link'));
  }

  @override
  Widget build(BuildContext context) {
    final stale = _updatedAt != null &&
        DateTime.now().millisecondsSinceEpoch - _updatedAt! > 60 * 1000;
    return Column(children: [
      Expanded(
        child: AppMap(
          controller: _map,
          center: _driver ?? r.pickup.point,
          zoom: 14,
          polylines: [
            if (_route != null)
              Polyline(points: _route!.points, strokeWidth: 5, color: AppColors.primary),
          ],
          markers: [
            Markers.pin(r.pickup.point, AppColors.green),
            Markers.pin(r.dest.point, AppColors.red),
            if (_driver != null) Markers.car(_driver!, heading: _heading),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(blurRadius: 12, color: Colors.black26)],
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Pill(statusLabel(r.status), statusColor(r.status)),
              const Spacer(),
              if (_route != null) Text('الوصول المتوقع: ${_route!.durationMin.round()} دقيقة'),
            ]),
            const SizedBox(height: 4),
            Text(
              _driver == null
                  ? 'بانتظار موقع السائق...'
                  : stale
                      ? 'انقطع تحديث موقع السائق (${timeAgo(_updatedAt)})'
                      : 'آخر تحديث للموقع: ${timeAgo(_updatedAt)}',
              style: TextStyle(fontSize: 12, color: stale ? AppColors.red : Colors.grey),
            ),
            const Divider(),
            Row(children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.driverName ?? 'السائق', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${r.vehicle ?? ''}  ★ ${r.driverRating.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ]),
              ),
              Text(money(r.finalPrice),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ]),
            if (r.status == 'accepted' || r.status == 'arrived')
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Icons.pin, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('رمز بدء الرحلة (أخبره للسائق عند الركوب):')),
                  Text(r.startCode ?? '----',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4)),
                ]),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _openCall(context, r.driverPhone ?? ''), icon: const Icon(Icons.call), label: const Text('اتصال'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: _share, icon: const Icon(Icons.share), label: const Text('مشاركة'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: _report, icon: const Icon(Icons.report_problem_outlined), label: const Text('بلاغ'))),
            ]),
            if (r.status == 'accepted' || r.status == 'arrived')
              TextButton(
                onPressed: _cancel,
                child: const Text('إلغاء الرحلة', style: TextStyle(color: AppColors.red)),
              ),
          ]),
        ),
      ),
    ]);
  }
}

// ───────────────────────── التقييم ─────────────────────────
class _RatingView extends StatefulWidget {
  final Ride ride;
  const _RatingView({required this.ride});
  @override
  State<_RatingView> createState() => _RatingViewState();
}

class _RatingViewState extends State<_RatingView> {
  int _stars = 5;
  final _c = TextEditingController();
  bool _busy = false;

  Future<void> _done({required bool send}) async {
    setState(() => _busy = true);
    try {
      if (send && !widget.ride.riderRated) {
        await RideService.rate(widget.ride, _stars, _c.text.trim());
      } else {
        await RideService.clearActive();
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showSnack(context, 'تعذر إرسال التقييم', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ride;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Icon(Icons.check_circle, size: 80, color: AppColors.green),
      const SizedBox(height: 8),
      const Text('تمت الرحلة بنجاح', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(money(r.finalPrice), textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.primary)),
      Text('الدفع: نقداً للسائق', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
      const SizedBox(height: 4),
      Text('${r.distanceKm.toStringAsFixed(1)} كم • ${r.durationMin.round()} دقيقة', textAlign: TextAlign.center),
      const SizedBox(height: 20),
      const Text('قيّم الرحلة', textAlign: TextAlign.center),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            iconSize: 38,
            onPressed: () => setState(() => _stars = i),
            icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: AppColors.orange),
          ),
      ]),
      TextField(controller: _c, maxLines: 3, decoration: const InputDecoration(hintText: 'أضف تعليقاً (اختياري)')),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: _busy ? null : () => _done(send: true), child: const Text('إرسال التقييم')),
      TextButton(onPressed: _busy ? null : () => _done(send: false), child: const Text('تخطي')),
    ]);
  }
}

class _CancelledView extends StatelessWidget {
  final Ride ride;
  const _CancelledView({required this.ride});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cancel, size: 72, color: AppColors.red),
            const SizedBox(height: 10),
            const Text('تم إلغاء الرحلة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  await RideService.clearActive();
                } catch (_) {}
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('حسناً'),
            ),
          ]),
        ),
      );
}
