import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'config.dart';
import 'theme.dart';

String money(num v) {
  final s = v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  return '$s ${AppConfig.currency}';
}

String statusLabel(String s) {
  switch (s) {
    case 'requested':
      return 'بانتظار العروض';
    case 'accepted':
      return 'السائق في الطريق';
    case 'arrived':
      return 'وصل السائق';
    case 'started':
      return 'الرحلة جارية';
    case 'completed':
      return 'مكتملة';
    case 'cancelled':
      return 'ملغاة';
    default:
      return s;
  }
}

Color statusColor(String s) {
  switch (s) {
    case 'completed':
    case 'started':
      return AppColors.green;
    case 'cancelled':
      return AppColors.red;
    case 'requested':
    case 'accepted':
    case 'arrived':
      return AppColors.orange;
    default:
      return AppColors.primary;
  }
}

String timeAgo(int? ms) {
  if (ms == null) return 'غير متاح';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inSeconds < 10) return 'الآن';
  if (d.inSeconds < 60) return 'منذ ${d.inSeconds} ثانية';
  if (d.inMinutes < 60) return 'منذ ${d.inMinutes} دقيقة';
  if (d.inHours < 24) return 'منذ ${d.inHours} ساعة';
  return 'منذ ${d.inDays} يوم';
}

String dateLabel(int? ms) {
  if (ms == null) return '';
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String t(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${t(d.month)}/${t(d.day)}  ${t(d.hour)}:${t(d.minute)}';
}

double haversineKm(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Kilometer, a, b).toDouble();

double bearing(LatLng a, LatLng b) {
  final y = sin((b.longitude - a.longitude) * pi / 180) * cos(b.latitude * pi / 180);
  final x = cos(a.latitude * pi / 180) * sin(b.latitude * pi / 180) -
      sin(a.latitude * pi / 180) *
          cos(b.latitude * pi / 180) *
          cos((b.longitude - a.longitude) * pi / 180);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

/// تحويل قيمة Firebase (Map<Object?,Object?>) إلى Map<String,dynamic> بشكل متداخل
Map<String, dynamic> asMap(Object? v) {
  if (v is Map) {
    return v.map((k, val) => MapEntry(k.toString(), val is Map ? asMap(val) : val));
  }
  return <String, dynamic>{};
}

double numD(Object? v, [double d = 0]) => v is num ? v.toDouble() : d;

void showSnack(BuildContext c, String msg, {bool error = false}) {
  if (!c.mounted) return;
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppColors.red : AppColors.navy,
    behavior: SnackBarBehavior.floating,
  ));
}

Future<bool> confirmDialog(BuildContext c, String title, String msg,
    {String yes = 'تأكيد', String no = 'تراجع'}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(msg),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(no)),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
      ],
    ),
  );
  return r ?? false;
}
