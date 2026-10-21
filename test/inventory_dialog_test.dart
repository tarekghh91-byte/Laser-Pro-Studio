import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laser_pro_studio/main.dart' as studio;

void main() {
  testWidgets('Material form opens, accepts data, closes without widget teardown errors', (tester) async {
    studio.Material? created;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        onPressed: () async {
          created = await showDialog<studio.Material>(
            context: context,
            builder: (_) => const studio.MaterialAddDialog(),
          );
        },
        child: const Text('افتح المادة'),
      ))),
    ));

    await tester.tap(find.text('افتح المادة'));
    await tester.pumpAndSettle();
    expect(find.text('مادة جديدة'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'خشب تجربة');
    await tester.pump();
    await tester.tap(find.text('حفظ المادة'));
    await tester.pumpAndSettle();
    expect(created, isNotNull);
    expect(created!.name, 'خشب تجربة');
    expect(tester.takeException(), isNull);
    expect(find.text('مادة جديدة'), findsNothing);
  });

  testWidgets('Cancel and reopen a material form without reused GlobalKeys', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        onPressed: () => showDialog<studio.Material>(
          context: context,
          builder: (_) => const studio.MaterialAddDialog(),
        ),
        child: const Text('افتح المادة'),
      ))),
    ));

    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('افتح المادة'));
      await tester.pumpAndSettle();
      expect(find.text('مادة جديدة'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Material edit dialog safely returns changed values', (tester) async {
    studio.MaterialEditResult? edited;
    final item = studio.Material(
      id: 'test-material', name: 'MDF', quantity: 10,
      unit: 'قطعة', reorderLevel: 2, unitCost: 1,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
        onPressed: () async => edited = await showDialog<studio.MaterialEditResult>(
          context: context,
          builder: (_) => studio.MaterialEditDialog(material: item),
        ),
        child: const Text('فتح التعديل'),
      ))),
    ));

    await tester.tap(find.text('فتح التعديل'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل MDF'), findsOneWidget);
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(edited?.quantity, 10);
    expect(edited?.packagePrice, 1);
    expect(tester.takeException(), isNull);
  });
}
