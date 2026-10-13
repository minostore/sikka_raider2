import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationException implements Exception {
  final String message;
  final bool openLocationSettings;
  final bool openAppSettings;
  LocationException(this.message,
      {this.openLocationSettings = false, this.openAppSettings = false});
  @override
  String toString() => message;
}

class LocationService {
  /// يتحقق من تفعيل GPS والصلاحيات ويرمي LocationException عند الفشل
  static Future<void> ensureReady() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('يرجى تفعيل خدمة الموقع (GPS) من الهاتف.',
          openLocationSettings: true);
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied) {
      throw LocationException('يجب السماح للتطبيق بالوصول إلى الموقع.');
    }
    if (p == LocationPermission.deniedForever) {
      throw LocationException('تم منع إذن الموقع نهائياً. فعّله من إعدادات التطبيق.',
          openAppSettings: true);
    }
  }

  static Future<LatLng> current() async {
    await ensureReady();
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);
      throw LocationException('تعذر تحديد موقعك الحالي. حاول مرة أخرى.');
    }
  }

  /// [foreground]=true على أندرويد: يعمل مع إشعار دائم (خدمة أمامية) فيستمر التتبع والتنبيهات والتطبيق في الخلفية.
  static Stream<Position> stream({int distanceFilter = 10, bool foreground = false}) {
    final LocationSettings settings = (foreground && defaultTargetPlatform == TargetPlatform.android)
        ? AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: distanceFilter,
            foregroundNotificationConfig: ForegroundNotificationConfig(
              notificationTitle: 'سِكّة كابتن — متصل',
              notificationText: 'بانتظار طلبات الرحلات الجديدة',
              enableWakeLock: true,
              setOngoing: true,
            ),
          )
        : LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: distanceFilter);
    return Geolocator.getPositionStream(locationSettings: settings);
  }
}

/// عرض رسالة خطأ الموقع مع زر لفتح الإعدادات عند الحاجة
void showLocationError(BuildContext context, Object e) {
  if (!context.mounted) return;
  final le = e is LocationException ? e : null;
  final msg = le?.message ?? 'تعذر الوصول إلى الموقع.';
  SnackBarAction? action;
  if (le?.openLocationSettings ?? false) {
    action = SnackBarAction(label: 'الإعدادات', onPressed: Geolocator.openLocationSettings);
  } else if (le?.openAppSettings ?? false) {
    action = SnackBarAction(label: 'الإعدادات', onPressed: Geolocator.openAppSettings);
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg),
    behavior: SnackBarBehavior.floating,
    action: action,
  ));
}
