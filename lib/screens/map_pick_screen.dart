import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/place.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import '../widgets/app_map.dart';

/// اختيار نقطة بتحريك الخريطة تحت دبوس ثابت في المنتصف
class MapPickScreen extends StatefulWidget {
  final LatLng? start;
  const MapPickScreen({super.key, this.start});
  @override
  State<MapPickScreen> createState() => _MapPickScreenState();
}

class _MapPickScreenState extends State<MapPickScreen> {
  final _map = MapController();
  late LatLng _center = widget.start ?? AppConfig.defaultCenter;
  String _address = 'حرّك الخريطة لتحديد الموقع';
  bool _busy = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.start == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toMe());
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _toMe() async {
    try {
      final p = await LocationService.current();
      _map.move(p, 16);
    } catch (e) {
      if (mounted) showLocationError(context, e);
    }
  }

  void _moved(MapCamera cam, bool gesture) {
    _center = cam.center;
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      setState(() => _busy = true);
      final a = await GeocodingService.reverse(_center);
      if (mounted) {
        setState(() {
          _address = a;
          _busy = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('اختيار الموقع')),
        body: Stack(children: [
          AppMap(
              controller: _map,
              center: _center,
              zoom: 16,
              onPositionChanged: _moved,
              onRecenter: _toMe),
          const Center(
              child: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.location_on, size: 48, color: AppColors.red))),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_busy ? 'جاري تحديد العنوان...' : _address,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(
                            context, Place(_center.latitude, _center.longitude, _address)),
                    child: const Text('تأكيد الموقع'),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      );
}
