import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../services/location_service.dart';
import '../widgets/app_map.dart';
import '../widgets/common.dart';
import '../widgets/markers.dart';
import 'notifications_screen.dart';
import 'ride_flow_screen.dart';
import 'select_route_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _map = MapController();
  final _db = FirebaseDatabase.instance.ref();
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  LatLng? _me;
  bool _loading = true;
  List<LatLng> _drivers = [];
  String? _activeRide;
  Map<String, Place> _saved = {};
  String _name = '';
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _locate();
    _subs.add(_db.child('onlineDrivers').onValue.listen(_onDrivers, onError: (_) {}));
    _subs.add(_db.child('users/$_uid/activeRide').onValue.listen((e) {
      if (mounted) setState(() => _activeRide = e.snapshot.value?.toString());
    }, onError: (_) {}));
    _subs.add(_db.child('users/$_uid').onValue.listen((e) {
      final m = asMap(e.snapshot.value);
      final places = asMap(m['places']);
      if (mounted) {
        setState(() {
          _name = (m['name'] ?? '').toString();
          _saved = places.map((k, v) => MapEntry(k, Place.fromMap(asMap(v))));
        });
      }
    }, onError: (_) {}));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _onDrivers(DatabaseEvent e) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final out = <LatLng>[];
    asMap(e.snapshot.value).forEach((_, v) {
      final m = asMap(v);
      final upd = (m['updatedAt'] as num?)?.toInt() ?? 0;
      if (now - upd > 3 * 60 * 1000) return;
      final p = LatLng(numD(m['lat']), numD(m['lng']));
      if (_me == null || haversineKm(_me!, p) <= AppConfig.nearbyRadiusKm) out.add(p);
    });
    if (mounted) setState(() => _drivers = out);
  }

  Future<void> _locate({bool move = false}) async {
    try {
      final p = await LocationService.current();
      if (!mounted) return;
      setState(() => _me = p);
      if (move) _map.move(p, 15);
    } catch (e) {
      showLocationError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _start({Place? dest}) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SelectRouteScreen(initialDest: dest, saved: _saved)));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    final center = _me ?? AppConfig.defaultCenter;
    return Stack(children: [
      Positioned.fill(
        child: AppMap(
          controller: _map,
          center: center,
          markers: [
            ..._drivers.map((d) => Markers.car(d, color: AppColors.primary)),
            if (_me != null) Markers.me(_me!),
          ],
          onRecenter: () => _locate(move: true),
        ),
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: InfoCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              Expanded(
                  child: Text('مرحباً${_name.isEmpty ? '' : '، $_name'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
            ]),
          ),
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 12,
        child: SafeArea(
          child: InfoCard(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_activeRide != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.directions_car, color: AppColors.orange),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('لديك رحلة جارية')),
                    TextButton(
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RideFlowScreen(rideId: _activeRide!))),
                      child: const Text('متابعة'),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
              InkWell(
                onTap: _activeRide != null ? null : () => _start(),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F7), borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.search, color: AppColors.primary),
                    SizedBox(width: 10),
                    Text('إلى أين تريد الذهاب؟',
                        style: TextStyle(fontSize: 16, color: AppColors.navy)),
                  ]),
                ),
              ),
              if (_saved.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  for (final e in _saved.entries)
                    ActionChip(
                      avatar: Icon(e.key == 'home' ? Icons.home : Icons.work, size: 18),
                      label: Text(e.key == 'home' ? 'المنزل' : 'العمل'),
                      onPressed: _activeRide != null ? null : () => _start(dest: e.value),
                    ),
                ]),
              ],
              const SizedBox(height: 6),
              Text(
                  _drivers.isEmpty
                      ? 'لا يوجد سائقون قريبون حالياً'
                      : 'يوجد ${_drivers.length} سائق قريب منك',
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
        ),
      ),
    ]);
  }
}
