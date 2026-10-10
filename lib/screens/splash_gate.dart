import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'auth_screens.dart';
import 'main_shell.dart';

Widget _home() => const MainShell();

/// نقطة البداية: شاشة التحميل ثم الترحيب أو الرئيسية حسب حالة الدخول
class SplashGate extends StatelessWidget {
  const SplashGate({super.key});
  @override
  Widget build(BuildContext context) => SplashScreen(
        tagline: 'رحلتك تبدأ هنا',
        resolve: () async {
          final u = FirebaseAuth.instance.currentUser;
          if (u != null) {
            try {
              final st = (await FirebaseDatabase.instance.ref('users/${u.uid}/status').get()).value;
              if (st == 'suspended') {
                await AuthService.signOut();
              } else {
                return _home();
              }
            } catch (_) {
              return _home(); // بدون إنترنت: ندخل ونعرض رسائل الخطأ داخل الشاشات
            }
          }
          return WelcomeScreen(
            title: 'أهلاً بك في مشوار',
            subtitle: 'اطلب رحلتك بالسعر المناسب وتابعها لحظة بلحظة',
            homeBuilder: _home,
          );
        },
      );
}
