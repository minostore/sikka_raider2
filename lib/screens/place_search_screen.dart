import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/place.dart';
import '../services/geocoding_service.dart';
import '../services/location_service.dart';
import 'map_pick_screen.dart';

class PlaceSearchScreen extends StatefulWidget {
  final String title;
  final bool allowCurrent;
  final LatLng? near;
  final Map<String, Place> saved;
  const PlaceSearchScreen({
    super.key,
    required this.title,
    this.allowCurrent = false,
    this.near,
    this.saved = const {},
  });
  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Place> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    // تأخير 800ms لتجنب إرسال طلب مع كل حرف (سياسة Nominatim)
    _debounce = Timer(const Duration(milliseconds: 800), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await GeocodingService.search(q, near: widget.near);
      if (!mounted) return;
      setState(() {
        _results = r;
        if (r.isEmpty) _error = 'العنوان غير موجود. جرّب كلمات أخرى.';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر البحث الآن. تحقق من الإنترنت وحاول مجدداً.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useCurrent() async {
    try {
      final p = await LocationService.current();
      final addr = await GeocodingService.reverse(p);
      if (mounted) Navigator.pop(context, Place(p.latitude, p.longitude, addr));
    } catch (e) {
      if (mounted) showLocationError(context, e);
    }
  }

  Future<void> _pickOnMap() async {
    final p = await Navigator.push<Place>(
        context, MaterialPageRoute(builder: (_) => MapPickScreen(start: widget.near)));
    if (p != null && mounted) Navigator.pop(context, p);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                  hintText: 'ابحث عن مدينة، شارع، أو معلم...', prefixIcon: Icon(Icons.search)),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: ListView(children: [
              if (widget.allowCurrent)
                ListTile(
                  leading: const Icon(Icons.my_location, color: AppColors.primary),
                  title: const Text('موقعي الحالي'),
                  onTap: _useCurrent,
                ),
              ListTile(
                leading: const Icon(Icons.map, color: AppColors.primary),
                title: const Text('اختيار من الخريطة'),
                onTap: _pickOnMap,
              ),
              for (final e in widget.saved.entries)
                ListTile(
                  leading: Icon(e.key == 'home' ? Icons.home : Icons.work, color: AppColors.orange),
                  title: Text(e.key == 'home' ? 'المنزل' : 'العمل'),
                  subtitle: Text(e.value.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, e.value),
                ),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: const TextStyle(color: Colors.grey))),
              for (final p in _results)
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(p.address, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(context, p),
                ),
            ]),
          ),
        ]),
      );
}
