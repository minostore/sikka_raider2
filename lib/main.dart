import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'firebase_options.dart';
import 'screens/splash_gate.dart';
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
  runApp(MishwarDriverApp(initError: initError));
}

class MishwarDriverApp extends StatelessWidget {
  final Object? initError;
  const MishwarDriverApp({super.key, this.initError});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'sikka rider',
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
