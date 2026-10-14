import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/splash_gate.dart';
import 'services/driver_overlay.dart';
import 'services/local_notify.dart';
import 'services/nav_memory.dart';
import 'services/zone_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Object? initError;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    initError = e;
  }
  if (initError == null) ZoneService.start();
  await LocalNotify.init();
  await NavMemory.init();
  runApp(MishwarDriverApp(initError: initError));
}

class MishwarDriverApp extends StatelessWidget {
  final Object? initError;
  const MishwarDriverApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Sikka Driver',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: initError != null
            ? Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('تعذر تهيئة Firebase:\n$initError', textAlign: TextAlign.center))))
            : const SplashGate(),
      );
}

/// نقطة دخول الفقاعة العائمة (التطبيق المصغّر) — يستدعيها flutter_overlay_window.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: Material(color: Colors.transparent, child: OverlayBubble())));
}
