import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../services/ride_service.dart';
import '../services/routing_service.dart';
import '../widgets/app_map.dart';
import '../widgets/common.dart';
import '../widgets/map_utils.dart';
import '../widgets/markers.dart';
import 'ride_flow_screen.dart';

class TripRequestScreen extends StatefulWidget {
  final Place pickup;
  final Place dest;
  const TripRequestScreen({super.key, required this.pickup, required this.dest});
  @override
  State<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends State<TripRequestScreen> {
  final _map = MapController();
  final _price = TextEditingController();
  final _note = TextEditingController();
  RouteInfo? _route;
  Map<String, double> _pricing = {
    'base': 15,
    'perKm': 5,
    'minFare': 25,
    'perKm_car': 5,
    'perKm_motorcycle': 5,
    'perKm_scooter': 5,
  };
  String _vehicle = 'regular';
  String _payment = 'cash';
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([
        RoutingService.route(widget.pickup.point, widget.dest.point),
        RideService.pricing(),
      ]);
      _route = r[0] as RouteInfo;
      _pricing = r[1] as Map<String, double>;
      _suggest();
      WidgetsBinding.instance.addPostFrameCallback((_) => fitPoints(_map, _route!.points));
    } catch (e) {
      _error = 'تعذر حساب الطريق. تحقق من الإنترنت.';
    }
    if (mounted) setState(() => _loading = false);
  }

  String _perKmKey(String v) {
    switch (v) {
      case 'motorcycle':
        return 'perKm_motorcycle';
      case 'scooter':
        return 'perKm_scooter';
      default:
        return 'perKm_car'; // regular / family
    }
  }

  void _suggest() {
    final km = _route?.distanceKm ?? 0;
    // سعر الكيلومتر لكل وسيلة يأتي من لوحة التحكم (settings/pricing/vehicles)
    final perKm = _pricing[_perKmKey(_vehicle)] ?? _pricing['perKm']!;
    var p = _pricing['base']! + perKm * km;
    if (_vehicle == 'family') p *= 1.3;
    p = max(p, _pricing['minFare']!);
    _price.text = p.round().toString();
  }

  Future<void> _publish() async {
    final price = double.tryParse(_price.text.trim()) ?? 0;
    if (price < _pricing['minFare']!) {
      return showSnack(context, 'الحد الأدنى للسعر ${money(_pricing['minFare']!)}', error: true);
    }
    if (_route == null) return;
    setState(() => _busy = true);
    try {
      final id = await RideService.createRide(
        pickup: widget.pickup,
        dest: widget.dest,
        distanceKm: _route!.distanceKm,
        durationMin: _route!.durationMin,
        price: price,
        vehicleType: _vehicle,
        paymentMethod: _payment,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => RideFlowScreen(rideId: id)),
          (r) => r.isFirst);
    } catch (e) {
      showSnack(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الرحلة')),
        body: _loading
            ? const LoadingView()
            : _error != null
                ? ErrorView(_error!, onRetry: _load)
                : ListView(padding: const EdgeInsets.all(12), children: [
                    SizedBox(
                      height: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AppMap(
                          controller: _map,
                          center: widget.pickup.point,
                          zoom: 13,
                          showControls: false,
                          polylines: [
                            Polyline(
                                points: _route!.points,
                                strokeWidth: 5,
                                color: AppColors.primary)
                          ],
                          markers: [
                            Markers.pin(widget.pickup.point, AppColors.green),
                            Markers.pin(widget.dest.point, AppColors.red),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InfoCard(
                      child: Column(children: [
                        _row(Icons.circle, AppColors.green, 'من', widget.pickup.address),
                        const Divider(),
                        _row(Icons.circle, AppColors.red, 'إلى', widget.dest.address),
                        const Divider(),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                          Text('المسافة: ${_route!.distanceKm.toStringAsFixed(1)} كم'),
                          Text('الوقت المتوقع: ${_route!.durationMin.round()} دقيقة'),
                        ]),
                        if (_route!.estimated)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text('القيم تقديرية (تعذر الاتصال بخدمة الطرق)',
                                style: TextStyle(color: AppColors.orange, fontSize: 12)),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    const Text('نوع المركبة', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      SizedBox(
                          width: (MediaQuery.of(context).size.width - 32) / 2,
                          child: _vehicleChip('motorcycle', 'موتوسيكل', Icons.two_wheeler)),
                      SizedBox(
                          width: (MediaQuery.of(context).size.width - 32) / 2,
                          child: _vehicleChip('scooter', 'اسكوتر', Icons.moped)),
                      SizedBox(
                          width: (MediaQuery.of(context).size.width - 32) / 2,
                          child: _vehicleChip('regular', 'سيارة', Icons.directions_car)),
                      SizedBox(
                          width: (MediaQuery.of(context).size.width - 32) / 2,
                          child: _vehicleChip('family', 'عائلية', Icons.airport_shuttle)),
                    ]),
                    const SizedBox(height: 12),
                    const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(children: [
                      Expanded(child: _payChip('cash', 'نقداً', Icons.payments_outlined, true)),
                      const SizedBox(width: 8),
                      Expanded(child: _payChip('card', 'إلكتروني (قريباً)', Icons.credit_card, false)),
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _price,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: 'السعر المقترح (${money(0).split(' ').last})',
                          helperText: 'يمكن للسائقين تقديم عروض بأسعار مختلفة'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _note,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'ملاحظات للسائق (اختياري)')),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _busy ? null : _publish,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('نشر طلب الرحلة'),
                    ),
                  ]),
      );

  Widget _row(IconData i, Color c, String l, String t) => Row(children: [
        Icon(i, size: 12, color: c),
        const SizedBox(width: 8),
        Text('$l: ', style: const TextStyle(color: Colors.grey)),
        Expanded(child: Text(t, maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]);

  Widget _payChip(String v, String label, IconData icon, bool enabled) {
    final sel = _payment == v;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? () => setState(() => _payment = v) : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.card,
            border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: sel ? AppColors.primary : Colors.grey),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }

  Widget _vehicleChip(String v, String label, IconData icon) {
    final sel = _vehicle == v;
    return InkWell(
      onTap: () => setState(() {
        _vehicle = v;
        _suggest();
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.card,
          border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: sel ? AppColors.primary : Colors.grey),
          const SizedBox(width: 6),
          Text(label),
        ]),
      ),
    );
  }
}
