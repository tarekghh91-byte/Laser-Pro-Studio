import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laser_pro_studio/main.dart';

void main() {
  testWidgets('The Android splash is replaced by a visible Flutter loading screen', (tester) async {
    final completer = Completer<void>();
    await tester.pumpWidget(LaserProBootstrap(initializeForTest: () => completer.future));
    await tester.pump();
    expect(find.text('عم نجهّز اتصال التطبيق...'), findsOneWidget);
    completer.completeError(StateError('test only'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('تعذّر تشغيل اتصال البرنامج'), findsOneWidget);
    expect(find.text('إعادة المحاولة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Startup initialization failures offer retry without restarting the app', (tester) async {
    var attempts = 0;
    Future<void> errorOnInit() async {
      attempts++;
      throw StateError('simulated initialization failure');
    }
    await tester.pumpWidget(LaserProBootstrap(initializeForTest: errorOnInit));
    await tester.pump();
    await tester.pump();
    expect(find.text('تعذّر تشغيل اتصال البرنامج'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pump();
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('تعذّر تشغيل اتصال البرنامج'), findsOneWidget);
  });
}
