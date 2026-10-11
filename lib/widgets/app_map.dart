import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../services/zone_service.dart';

class AppMap extends StatefulWidget {
  final MapController controller;
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final List<Polyline> polylines;
  final void Function(TapPosition, LatLng)? onTap;
  final void Function(MapCamera, bool)? onPositionChanged;
  final VoidCallback? onRecenter;
  final bool showControls;

  const AppMap({
    super.key,
    required this.controller,
    required this.center,
    this.zoom = 15,
    this.markers = const [],
    this.polylines = const [],
    this.onTap,
    this.onPositionChanged,
    this.onRecenter,
    this.showControls = true,
  });

  @override
  State<AppMap> createState() => _AppMapState();
}

class _AppMapState extends State<AppMap> {
  bool _tileError = false;

  void _zoom(double d) {
    final cam = widget.controller.camera;
    widget.controller.move(cam.center, (cam.zoom + d).clamp(3, 19).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      FlutterMap(
        mapController: widget.controller,
        options: MapOptions(
          initialCenter: widget.center,
          initialZoom: widget.zoom,
          onTap: widget.onTap,
          onPositionChanged: widget.onPositionChanged,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: AppConfig.tileUrl,
            userAgentPackageName: AppConfig.packageName,
            errorTileCallback: (tile, error, stack) {
              if (!_tileError && mounted) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _tileError = true);
                });
              }
            },
          ),
          ValueListenableBuilder<List<ServiceZone>>(
            valueListenable: ZoneService.zones,
            builder: (_, zs, __) => PolygonLayer(polygons: [
              for (final z in zs)
                if (z.active && z.points.length >= 3)
                  Polygon(
                    points: z.points,
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderColor: AppColors.primary,
                    borderStrokeWidth: 2,
                  ),
            ]),
          ),
          PolylineLayer(polylines: widget.polylines),
          MarkerLayer(markers: widget.markers),
          const SimpleAttributionWidget(
            source: Text('© OpenStreetMap', style: TextStyle(fontSize: 10)),
          ),
        ],
      ),
      if (_tileError)
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Material(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Text('تعذر تحميل بعض أجزاء الخريطة. تحقق من الإنترنت.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ),
      if (widget.showControls)
        Positioned(
          left: 12,
          bottom: 12,
          child: Column(children: [
            _btn(Icons.add, () => _zoom(1)),
            const SizedBox(height: 6),
            _btn(Icons.remove, () => _zoom(-1)),
            if (widget.onRecenter != null) ...[
              const SizedBox(height: 6),
              _btn(Icons.my_location, widget.onRecenter!),
            ],
          ]),
        ),
    ]);
  }

  Widget _btn(IconData i, VoidCallback f) => Material(
        color: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: f,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(i, size: 22, color: AppColors.navy),
          ),
        ),
      );
}
