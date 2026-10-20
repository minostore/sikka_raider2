import '../services/finance_service.dart';
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
import '../services/ride_notification_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../widgets/app_map.dart';
import '../widgets/common.dart';
import '../widgets/map_utils.dart';
import '../widgets/markers.dart';
import '../widgets/back_guard.dart';
import 'ride_chat_screen.dart';

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
    _code.dispose();
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

  Future<void> _update(Map<String, Object?> up, {String? state, String? expectedStatus}) async {
    setState(() => _busy = true);
    try {
      final ref = db.child('rides/${widget.rideId}');
      if (up.containsKey('status')) {
        final current = asMap((await ref.get()).value);
        if (current['driverId'] != myUid || current['status'] != expectedStatus) {
          throw StateError('حالة الرحلة تغيرت. حدّث الشاشة وحاول مرة أخرى.');
        }
        // تحديث مباشر بعد التحقق من الحالة الفعلية؛ قواعد قاعدة البيانات تتحقق من صحة الانتقال أيضاً
        await ref.update(up);
      } else {
        await ref.update(up);
      }
      if (state != null) LocationPublisher.setRide(widget.rideId, state: state);
      if (up['status'] != null) {
        final ride = asMap((await db.child('rides/${widget.rideId}').get()).value);
        await RideNotificationService.notifyStatus(rideId: widget.rideId, status: up['status'].toString(), riderId: ride['riderId']?.toString(), driverId: myUid);
      }
    } catch (e) {
      if (mounted) showSnack(context, e is StateError ? e.message.toString() : 'تعذر تحديث الرحلة. تحقق من الاتصال.', error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish(Ride r) async {
    if (_busy) return;
    if (!await confirmDialog(context, 'إنهاء الرحلة', 'هل وصلت إلى الوجهة؟\nالأجرة النهائية: ${money(r.finalPrice)} (نقداً)', yes: 'تأكيد إنهاء الرحلة')) return;
    setState(() => _busy = true);
    var completedNow = false, completed = false;
    try {
      final rideRef = db.child('rides/${r.id}');
      // نقرأ الحالة الفعلية من الخادم أولاً: لا نعتمد على معاملة (Transaction) لأنها قد تبدأ بقيمة فارغة وتُلغى خطأً
      final current = asMap((await rideRef.get()).value);
      if (current['driverId'] != myUid) throw StateError('هذه الرحلة غير مسندة إليك.');
      final status = current['status']?.toString();
      if (status == 'completed') {
        completed = true; // أُنهيت بالفعل (مثلاً ضغطة مكررة) — ليست خطأ
      } else if (status != 'started') {
        throw StateError('لا يمكن إنهاء الرحلة قبل بدئها.');
      } else {
        final fareValue = current['agreedPrice'] ?? current['price'];
        if (fareValue is! num || !fareValue.isFinite || fareValue <= 0) throw StateError('سعر الرحلة غير صالح.');
        final fare = double.parse(fareValue.toDouble().toStringAsFixed(2));
        // العمولة تُحسب على الخادم فقط (FinanceService.sync) ولا يكتبها التطبيق.
        await rideRef.update({
          'status': 'completed',
          'completedAt': DateTime.now().millisecondsSinceEpoch,
          'finalPrice': fare,
        });
        completed = true;
        completedNow = true;
      }
    } catch (e) {
      if (mounted) showSnack(context, e is StateError ? e.message.toString() : 'تعذر إنهاء الرحلة. تحقق من الاتصال وحاول مرة أخرى.', error: true);
    }
    if (completed) {
      // بعد نجاح الإنهاء: كل خطوة تنظيف مستقلة، وفشل أي منها لا يُظهر رسالة خطأ للسائق
      Future<void> safe(Future<void> Function() step) async {
        try {
          await step();
        } catch (_) {}
      }
      LocationPublisher.setRide(null);
      await safe(() => db.child('driverActive/$myUid').remove());
      await safe(() => db.child('users/${r.riderId}/activeRide').remove());
      if (completedNow) {
        await safe(() => db.child('drivers/$myUid/tripsCount').runTransaction((v) => Transaction.success(((v as num?) ?? 0).toInt() + 1)));
        await safe(() => RideNotificationService.notifyStatus(rideId: r.id, status: 'completed', riderId: r.riderId, driverId: myUid));
        unawaited(FinanceService.sync(rideId: r.id));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel(Ride r) async {
    if (!await confirmDialog(context, 'إلغاء الرحلة', 'هل تريد إلغاء الرحلة؟ قد يؤثر ذلك على تقييمك.', yes: 'نعم، إلغاء')) return;
    try {
      final ref = db.child('rides/${r.id}');
      final current = asMap((await ref.get()).value);
      if (current['driverId'] != myUid || !['accepted', 'arrived'].contains(current['status'])) {
        throw StateError('لا يمكن إلغاء الرحلة في حالتها الحالية.');
      }
      await ref.update({'status': 'cancelled', 'cancelledBy': 'driver', 'cancelledAt': ServerValue.timestamp});
      // بعد نجاح الإلغاء كل خطوة تنظيف مستقلة ولا تُظهر خطأً للسائق
      LocationPublisher.setRide(null);
      try { await db.child('driverActive/$myUid').remove(); } catch (_) {}
      try { await db.child('users/${r.riderId}/activeRide').remove(); } catch (_) {}
      try { await RideNotificationService.notifyStatus(rideId: r.id, status: 'cancelled', riderId: r.riderId, driverId: myUid); } catch (_) {}
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, e is StateError ? e.message.toString() : 'تعذر الإلغاء', error: true);
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
              if (r.status == 'accepted' || r.status == 'arrived' || r.status == 'started') {
                LocationPublisher.setRide(r.id, state: r.status);
              } else if (r.status == 'completed' || r.status == 'cancelled') {
                // Capture the rider ID before the callback because `r` is nullable
                // in the surrounding StreamBuilder scope.
                final riderId = r?.riderId ?? '';
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  LocationPublisher.setRide(null);
                  db.child('driverActive/$myUid').remove().catchError((_) {});
                  if (riderId.isNotEmpty) {
                    db.child('users/$riderId/activeRide').remove().catchError((_) {});
                  }
                });
              }
            }
            _ride = r;
            if (r.status == 'cancelled') {
              body = _ended(r.cancelledBy == 'driver' ? 'ألغى السائق الرحلة' : (r.cancelledBy == 'rider' ? 'ألغيت الرحلة بواسطتك' : 'تم إلغاء الرحلة'), Icons.cancel, AppColors.red, r);
            } else if (r.status == 'completed') {
              body = _completed(r);
            } else {
              body = _active(r);
            }
          }
          // أثناء الرحلة المؤكدة: الرجوع لا يعيد لصفحة سابقة؛ الضغطة الثانية تغلق التطبيق
          final ended = s.hasData && (r?.status == 'completed' || r?.status == 'cancelled');
          return DoubleBackExit(
            enabled: !ended && r != null,
            child: Scaffold(appBar: AppBar(title: Text(_title(r)), automaticallyImplyLeading: ended), body: body),
          );
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
        decoration: const BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.vertical(top: Radius.circular(22)), boxShadow: [BoxShadow(blurRadius: 14, color: Colors.black38)]),
        child: SafeArea(
          top: false,
          child: Theme(
            data: AppTheme.dark,
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
                  const SizedBox(height: 6),
                  Text('الراكب: ${r.riderName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideChatScreen(rideId: r.id))),
                    icon: const Icon(Icons.chat_bubble_outline), label: const Text('محادثة مع الراكب'),
                  )),
                  const SizedBox(height: 4),
                  Text('الوجهة: ${r.dest.address}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  AppButton('ابدأ وجهتك', color: _blue, icon: Icons.navigation, onPressed: () => _navigate(r.dest.point)),
                  const SizedBox(height: 8),
                  AppButton('إنهاء الرحلة', color: AppColors.red, onPressed: () => _finish(r), busy: _busy),
                ] else ...[
                  if (r.status == 'accepted') ...[
                    const Center(child: Text('تم قبول الرحلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                    const Center(child: Text('جار التوجيه إلى الراكب', style: TextStyle(color: Colors.grey))),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    CircleAvatar(radius: 24, backgroundColor: AppColors.field, backgroundImage: (r.riderPhotoUrl ?? '').startsWith('http') ? NetworkImage(r.riderPhotoUrl!) : null, child: (r.riderPhotoUrl ?? '').startsWith('http') ? null : const Icon(Icons.person, color: _blue)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.riderName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      Text(r.pickup.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _blue, fontSize: 13)),
                      Text('${money(r.finalPrice)} (نقداً)', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ])),
                    InkWell(onTap: () => _launch('tel', r.riderPhone), child: Container(padding: const EdgeInsets.all(11), decoration: const BoxDecoration(color: AppColors.field, shape: BoxShape.circle), child: const Icon(Icons.call, color: AppColors.primary))),
                    const SizedBox(width: 6),
                    InkWell(onTap: () => _launch('sms', r.riderPhone), child: Container(padding: const EdgeInsets.all(11), decoration: const BoxDecoration(color: AppColors.field, shape: BoxShape.circle), child: const Icon(Icons.message, color: AppColors.primary))),
                    const SizedBox(width: 6),
                    InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideChatScreen(rideId: r.id))), child: Container(padding: const EdgeInsets.all(11), decoration: const BoxDecoration(color: AppColors.field, shape: BoxShape.circle), child: const Icon(Icons.chat_bubble_outline, color: AppColors.primary))),
                  ]),
                  const SizedBox(height: 12),
                  // ابدأ وجهتك: يفتح خرائط الهاتف للتوجيه إلى الراكب (قبل البدء) أو إلى نقطة إنهاء الرحلة
                  AppButton('ابدأ وجهتك', color: _blue, icon: Icons.navigation, onPressed: () => _navigate(r.pickup.point)),
                  const SizedBox(height: 8),
                  if (r.status == 'accepted') ...[
                    AppButton('تم الوصول', onPressed: () => _update({'status': 'arrived', 'arrivedAt': ServerValue.timestamp}, state: 'arrived', expectedStatus: 'accepted'), busy: _busy),
                  ],
                  if (r.status == 'arrived') ...[
                    AppButton('بدء الرحلة', busy: _busy, onPressed: () => _update({'status': 'started', 'startedAt': ServerValue.timestamp}, state: 'started', expectedStatus: 'arrived')),
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
