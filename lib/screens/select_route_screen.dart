import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../widgets/app_map.dart';
import '../widgets/map_utils.dart';
import '../widgets/markers.dart';
import 'place_search_screen.dart';
import 'trip_request_screen.dart';

class SelectRouteScreen extends StatefulWidget {
  final Place? initialDest;
  final Map<String, Place> saved;
  const SelectRouteScreen({super.key, this.initialDest, this.saved = const {}});
  @override
  State<SelectRouteScreen> createState() => _SelectRouteScreenState();
}

class _SelectRouteScreenState extends State<SelectRouteScreen> {
  final _map = MapController();
  Place? _pickup;
  Place? _dest;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _dest = widget.initialDest;
    _useMyLocation();
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final p = await LocationService.current();
      final a = await GeocodingService.reverse(p);
      if (mounted) setState(() => _pickup = Place(p.latitude, p.longitude, a));
      _fit();
    } catch (e) {
      if (mounted) showLocationError(context, e);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _fit() => fitPoints(_map, [
        if (_pickup != null) _pickup!.point,
        if (_dest != null) _dest!.point,
      ]);

  Future<void> _choose(bool pickup) async {
    final p = await Navigator.push<Place>(
        context,
        MaterialPageRoute(
            builder: (_) => PlaceSearchScreen(
                  title: pickup ? 'موقع الالتقاط' : 'الوجهة',
                  allowCurrent: pickup,
                  near: (_pickup ?? _dest)?.point,
                  saved: widget.saved,
                )));
    if (p == null) return;
    setState(() => pickup ? _pickup = p : _dest = p);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  Widget _field(String label, Place? p, Color c, bool pickup) => InkWell(
        onTap: () => _choose(pickup),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border)),
          child: Row(children: [
            Icon(Icons.circle, size: 14, color: c),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(p?.address ?? (pickup && _locating ? 'جاري تحديد موقعك...' : 'اختر الموقع'),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Icon(Icons.edit, size: 18, color: Colors.grey),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ready = _pickup != null && _dest != null;
    return Scaffold(
      appBar: AppBar(title: const Text('تحديد الرحلة')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            _field('موقع الالتقاط', _pickup, AppColors.green, true),
            const SizedBox(height: 8),
            _field('الوجهة', _dest, AppColors.red, false),
            if (widget.saved.isNotEmpty)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(spacing: 8, children: [
                  for (final e in widget.saved.entries)
                    ActionChip(
                      avatar: Icon(e.key == 'home' ? Icons.home : Icons.work, size: 16),
                      label: Text(e.key == 'home' ? 'المنزل' : 'العمل'),
                      onPressed: () {
                        setState(() => _dest = e.value);
                        WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
                      },
                    ),
                ]),
              ),
          ]),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AppMap(
              controller: _map,
              center: _pickup?.point ?? AppConfig.defaultCenter,
              zoom: 14,
              markers: [
                if (_pickup != null) Markers.pin(_pickup!.point, AppColors.green),
                if (_dest != null) Markers.pin(_dest!.point, AppColors.red),
              ],
              onRecenter: _useMyLocation,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton(
              onPressed: ready
                  ? () {
                      if (haversineKm(_pickup!.point, _dest!.point) < 0.05) {
                        showSnack(context, 'نقطة الالتقاط والوجهة متطابقتان', error: true);
                        return;
                      }
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  TripRequestScreen(pickup: _pickup!, dest: _dest!)));
                    }
                  : null,
              child: const Text('متابعة'),
            ),
          ),
        ),
      ]),
    );
  }
}
