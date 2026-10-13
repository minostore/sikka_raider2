import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/driver_service.dart';
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

class _DriverShellState extends State<DriverShell> {
  int _i = 0;
  StreamSubscription? _sub;
  String? _opened;

  @override
  void initState() {
    super.initState();
    ZoneService.start();
    // يفتح شاشة الرحلة تلقائياً عندما يختار الراكب عرض السائق
    _sub = db.child('driverActive/$myUid').onValue.listen((e) {
      final id = e.snapshot.value?.toString();
      if (id == null) {
        _opened = null;
        return;
      }
      if (id != _opened && mounted) {
        _opened = id;
        Navigator.push(context, MaterialPageRoute(builder: (_) => ActiveRideScreen(rideId: id)));
      }
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: const [DriverHome(), EarningsScreen(), TripsScreen(), ProfileScreen()]),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.field))),
          child: BottomNavigationBar(
            currentIndex: _i,
            onTap: (v) => setState(() => _i = v),
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
