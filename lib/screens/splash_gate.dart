import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'auth_driver.dart';
import 'docs_screen.dart';
import 'driver_shell.dart';
import 'pending_screen.dart';
import 'welcome_onboarding.dart';

Widget _gate() => const DriverGate();

class SplashGate extends StatelessWidget {
  const SplashGate({super.key});
  @override
  Widget build(BuildContext context) => DriverSplash(
        resolve: () async => FirebaseAuth.instance.currentUser != null ? _gate() : SikkaWelcome(homeBuilder: _gate),
      );
}

/// يوجّه السائق حسب حالة حسابه: مستندات ← مراجعة ← تشغيل
class DriverGate extends StatelessWidget {
  const DriverGate({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('drivers/$uid').onValue,
      builder: (c, s) {
        if (s.hasError) return const Scaffold(body: ErrorView('تعذر تحميل حالة الحساب.'));
        if (!s.hasData) return const Scaffold(body: LoadingView());
        final m = asMap(s.data!.snapshot.value);
        switch (m['status']) {
          case 'approved':
            return const DriverShell();
          case 'pending':
          case 'rejected':
            return PendingScreen(data: m);
          case 'suspended':
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.block, size: 64, color: AppColors.red),
                    const SizedBox(height: 12),
                    const Text('تم إيقاف حسابك. تواصل مع الدعم.', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () async {
                        await AuthService.signOut();
                        if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const SplashGate()), (r) => false);
                      },
                      child: const Text('تسجيل الخروج'),
                    ),
                  ]),
                ),
              ),
            );
          default:
            return DocsScreen(data: m);
        }
      },
    );
  }
}
