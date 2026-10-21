import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laser_pro_studio/main.dart' as studio;
import 'package:laser_pro_studio/wood_boards.dart';

void main() {
  testWidgets('Convert existing five pieces to five boards ONLY after size confirmation', (tester) async {
    studio.MaterialEditResult? edited;
    final original=studio.Material(id:'old-wood',name:'خشب ابيض 3 ملم',
      category:'خشب',quantity:5,unit:'قطعة',reorderLevel:1,
      unitCost:1,packUnits:1);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(ctx)=>
      ElevatedButton(onPressed:() async{
        edited=await showDialog<studio.MaterialEditResult>(
          context:ctx,builder:(_)=>studio.MaterialEditDialog(material:original));
      },child:const Text('Edit'))))));
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.byType(SwitchListTile),findsOneWidget);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('حفظ').last);
    await tester.tap(find.text('حفظ').last);
    await tester.pumpAndSettle();
    expect(edited?.convertedBoards,isNotNull);
    expect(edited?.convertedBoards!.physicalSheets,5);
    expect(edited?.convertedBoards!.widthCm,80);
    expect(edited?.convertedBoards!.heightCm,120);
    expect(original.boardInventory,isNull); // no mutation before confirmation
    expect(tester.takeException(),isNull);
  });

  testWidgets('A new wood stock item records quantity and physical sheet dimensions', (tester) async {
    studio.Material? created;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(ctx)=>
      ElevatedButton(onPressed:() async{
        created=await showDialog<studio.Material>(
          context:ctx,builder:(_)=>const studio.MaterialAddDialog());
      },child:const Text('New'))))));
    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first,'لوح اختبار');
    await tester.enterText(find.byType(TextFormField).at(1),'2');
    await tester.enterText(find.byType(TextFormField).last,'6');
    await tester.ensureVisible(find.text('حفظ المادة'));
    await tester.tap(find.text('حفظ المادة'));
    await tester.pumpAndSettle();
    expect(created?.boardInventory,isNotNull);
    expect(created?.boardInventory!.physicalSheets,2);
    expect(created?.unit,'لوح');
    expect(created?.quantity,2);
    expect(created?.unitCost,6);
    expect(tester.takeException(),isNull);
  });

  testWidgets('Measured cut dialog returns 15 by 20 cm with two pieces and estimated cost', (tester) async {
    studio.UsedMaterial? chosen;
    final wood=studio.Material(id:'board',name:'خشب ابيض',category:'خشب',
      unit:'لوح',quantity:5,reorderLevel:1,unitCost:6,
      boardInventory:WoodBoardStock.newSheets(count:5,widthCm:120,heightCm:80));
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Builder(builder:(ctx)=>
      ElevatedButton(onPressed:() async{
        chosen=await showDialog<studio.UsedMaterial>(
          context:ctx,builder:(_)=>studio.CutMaterialDialog(materials:[wood]));
      },child:const Text('Cut'))))));
    await tester.tap(find.text('Cut'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0),'15');
    await tester.enterText(find.byType(TextField).at(1),'20');
    await tester.enterText(find.byType(TextField).at(2),'2');
    await tester.ensureVisible(find.text('إضافة القياس للطلب'));
    await tester.tap(find.text('إضافة القياس للطلب'));
    await tester.pumpAndSettle();
    expect(chosen,isNotNull);
    expect(chosen!.pieceCount,2);
    expect(chosen!.widthCm,15);
    expect(chosen!.heightCm,20);
    expect(chosen!.cost,closeTo(6*((15.02*20.02)*2/9600),0.00001));
    expect(tester.takeException(),isNull);
  });
}
