import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// يضبط الخريطة لتشمل كل النقاط (آمن حتى لو لم تكن الخريطة جاهزة بعد)
void fitPoints(MapController c, List<LatLng> pts) {
  if (pts.isEmpty) return;
  try {
    if (pts.length == 1) {
      c.move(pts.first, 15);
      return;
    }
    c.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(pts),
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
      maxZoom: 17,
    ));
  } catch (_) {}
}
