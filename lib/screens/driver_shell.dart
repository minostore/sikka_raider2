import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/driver_overlay.dart';
import '../services/driver_service.dart';
import '../services/local_notify.dart';
import '../services/nav_memory.dart';
import '../services/push_service.dart';
import '../services/ride_alerts.dart';
import '../services/zone_service.dart';
import 'active_ride_screen.dart';
import 'driver_home.dart';
import 'earnings_screen.dart';
import 'profile_screen.dart';
import 'trips_screen.dart';

class DriverShell extends StatefulWidget {
  const DriverShell({super.key});
  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> with WidgetsBindingObserver {
  int _i = NavMemory.tab(4); // آخر تبويب كان فيه السائق قبل إغلاق التطبيق
  StreamSubscription? _sub;
  String? _opened;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LocationPublisher.online.addListener(_onOnlineChanged);
    ZoneService.start();
    LocalNotify.startListening();
    PushService.start();
    RideAlerts.start();
    // يفتح شاشة الرحلة تلقائياً عندما يختار الراكب عرض السائق
    _sub = db.child('driverActive/$myUid').onValue.listen((e) {
      final id = e.snapshot.value?.toString();
      if (id == null) {
        _opened = null;
        return;
      }
      if (id != _opened && mounted) {
        _opened = id;
        // نزيل شاشة تفاصيل الطلب من المسار حتى لا يعود السائق إليها بعد انتهاء الرحلة
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => ActiveRideScreen(rideId: id)),
          (route) => route.settings.name != 'request_details',
        );
      }
    }, onError: (_) {});
  }

  // التطبيق المصغّر: يظهر عند الخروج من التطبيق لو السائق متصل، ويختفي عند العودة أو عند قطع الاتصال
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      DriverOverlay.hide();
    } else if (state == AppLifecycleState.paused) {
      DriverOverlay.onBackground();
    }
  }

  void _onOnlineChanged() {
    if (!LocationPublisher.online.value) DriverOverlay.hide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    LocationPublisher.online.removeListener(_onOnlineChanged);
    _sub?.cancel();
    RideAlerts.stop();
    LocalNotify.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: const [DriverHome(), EarningsScreen(), TripsScreen(), ProfileScreen()]),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.field))),
          child: BottomNavigationBar(
            currentIndex: _i,
            onTap: (v) {
              NavMemory.saveTab(v);
              setState(() => _i = v);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: AppColors.bg,
            elevation: 0,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: Colors.white60,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'الأرباح'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'الرحلات'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'ملفي'),
            ],
          ),
        ),
      );
}
