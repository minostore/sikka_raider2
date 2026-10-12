import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sikka_driver/screens/welcome_onboarding.dart';

void main() {
  testWidgets('shows four onboarding steps and continues to login', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SikkaWelcome(homeBuilder: () => const Scaffold(body: Text('home')))));
    await tester.pumpAndSettle();

    expect(find.text('ابدأ معنا يا كابتن'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('اختار رحلتك'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('اقبل الرحلة واعرف تفاصيلها'), findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('أكمل الرحلة بثقة'), findsOneWidget);
    await tester.tap(find.text('ابدأ معنا'));
    await tester.pumpAndSettle();
    expect(find.text('سائق جديد؟ سجّل الآن'), findsOneWidget);
  });

  testWidgets('skip opens login directly', (tester) async {
    await tester.pumpWidget(MaterialApp(home: SikkaWelcome(homeBuilder: () => const Scaffold(body: Text('home')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(find.text('سائق جديد؟ سجّل الآن'), findsOneWidget);
  });
}
