import 'package:latlong2/latlong.dart';

/// إعدادات التطبيق — عدّل القيم هنا فقط (العملة، رمز الدولة، مصدر الخرائط...)
class AppConfig {
  static const appName = 'Sikka Driver';
  static const role = 'driver'; // rider | driver
  static const currency = 'ج.م';
  static const countryCode = '+20';
  static const packageName = 'com.sikka.driver';
  static const userAgent = 'MishwarApp/1.0 ($packageName)';
  // مصدر بلاطات OpenStreetMap. يجب الالتزام بسياسة الاستخدام وإظهار الإسناد.
  static const tileUrl = 'https://tile.openstreetmap.de/{z}/{x}/{y}.png';
  static const defaultCenter = LatLng(30.0444, 31.2357);
  static const nearbyRadiusKm = 8.0;
}
