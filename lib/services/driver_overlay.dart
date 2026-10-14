import 'dart:io' show Platform;
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../core/config.dart';
import 'driver_service.dart';
import 'nav_memory.dart';

/// التطبيق المصغّر (فقاعة عائمة) يظهر فوق التطبيقات الأخرى عندما يخرج السائق من التطبيق
/// وهو «متصل». إذا كان غير متصل لا تظهر. الضغط عليها يعيد فتح التطبيق.
class DriverOverlay {
  static bool get _supported => Platform.isAndroid;

  /// يطلب إذن «العرض فوق التطبيقات» مرة واحدة فقط عند أول اتصال.
  static Future<void> askPermissionOnce() async {
    if (!_supported || NavMemory.flag('overlay_asked')) return;
    try {
      if (await FlutterOverlayWindow.isPermissionGranted()) return;
      NavMemory.setFlag('overlay_asked', true);
      await FlutterOverlayWindow.requestPermission();
    } catch (_) {}
  }

  /// التطبيق ذهب للخلفية: نُظهر الفقاعة إذا كان السائق متصلاً.
  static Future<void> onBackground() async {
    if (!_supported || !LocationPublisher.running) return;
    try {
      if (!await FlutterOverlayWindow.isPermissionGranted()) return;
      if (await FlutterOverlayWindow.isActive()) return;
      await FlutterOverlayWindow.showOverlay(
        height: 150,
        width: 150,
        alignment: OverlayAlignment.centerRight,
        enableDrag: true,
        flag: OverlayFlag.defaultFlag,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'سِكّة — أنت متصل',
        overlayContent: 'تستقبل طلبات الرحلات',
      );
    } catch (_) {}
  }

  /// التطبيق عاد للمقدمة أو السائق أصبح غير متصل: نُخفي الفقاعة.
  static Future<void> hide() async {
    if (!_supported) return;
    try {
      if (await FlutterOverlayWindow.isActive()) await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }
}

/// واجهة الفقاعة نفسها (تعمل في Isolate منفصل بواسطة flutter_overlay_window).
class OverlayBubble extends StatelessWidget {
  const OverlayBubble({super.key});

  Future<void> _open() async {
    try {
      await const AndroidIntent(
        action: 'android.intent.action.MAIN',
        category: 'android.intent.category.LAUNCHER',
        package: AppConfig.packageName,
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK, Flag.FLAG_ACTIVITY_REORDER_TO_FRONT],
      ).launch();
    } catch (_) {}
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: GestureDetector(
          onTap: _open,
          child: Center(
            child: Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                color: const Color(0xFF040D22),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFFCC00), width: 3),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.local_taxi_rounded, color: Color(0xFFFFCC00), size: 40),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF14D98A), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  const Text('متصل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, decoration: TextDecoration.none)),
                ]),
              ]),
            ),
          ),
        ),
      );
}
