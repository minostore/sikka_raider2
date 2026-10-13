import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'trips_screen.dart';
import 'wallet_screen.dart';
import 'account_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _i, children: const [
          HomeScreen(),
          TripsScreen(),
          WalletScreen(),
          AccountScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
          height: 68,
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.history), label: 'رحلاتي'),
            NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'المحفظة'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
          ],
        ),
      );
}
