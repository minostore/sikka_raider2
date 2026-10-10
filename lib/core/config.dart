import 'package:latlong2/latlong.dart';

/// إعدادات التطبيق — عدّل القيم هنا فقط (العملة، رمز الدولة، مصدر الخرائط...)
class AppConfig {
  static const appName = 'مشوار';
  static const role = 'rider'; // rider | driver
  static const currency = 'ج.م';
  static const countryCode = '+20';
  static const packageName = 'com.sikka';
  static const userAgent = 'MishwarApp/1.0 ($packageName)';
  // مصدر بلاطات الخرائط: خادم OSM العام للتجربة فقط. للإنتاج استخدم مزوداً مناسباً.
  static const tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const defaultCenter = LatLng(30.0444, 31.2357);
  static const nearbyRadiusKm = 8.0;
}
