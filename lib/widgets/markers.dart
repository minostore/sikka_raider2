import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';

class Markers {
  static Marker pin(LatLng p, Color c, {IconData icon = Icons.location_on}) => Marker(
        point: p,
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: Icon(icon, color: c, size: 40),
      );

  static Marker me(LatLng p) => Marker(
        point: p,
        width: 26,
        height: 26,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
          ),
        ),
      );

  static Marker car(LatLng p, {double heading = 0, Color color = AppColors.navy}) => Marker(
        point: p,
        width: 40,
        height: 40,
        child: Transform.rotate(
          angle: heading * math.pi / 180,
          child: Container(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 22),
          ),
        ),
      );
}
