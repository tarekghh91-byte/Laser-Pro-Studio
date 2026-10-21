import 'package:flutter_test/flutter_test.dart';
import 'package:laser_pro_studio/wood_boards.dart';

void main() {
  test('Two different measured cuts use one board and preserve four untouched', () {
    final before=WoodBoardStock.newSheets(count:5,widthCm:120,heightCm:80,kerfCm:0.02);
    final after=before.tryAllocate([
      const WoodCutRequest(widthCm:15,heightCm:15),
      const WoodCutRequest(widthCm:20,heightCm:12),
    ]);
    expect(after.successful,isTrue);
    expect(after.stock!.physicalSheets,5);
    expect(after.stock!.untouchedSheets,4);
    expect(after.stock!.openedSheets,1);
    expect(after.stock!.totalCutArea,closeTo(465,0.001));
    expect(after.stock!.totalFreeArea,lessThan(48000-465));
    expect(before.totalCutArea,0); // simulation must not mutate stock
    expect(before.untouchedSheets,5);
  });

  test('Do not combine separate remnants into a virtual large rectangle', () {
    final first=WoodBoardStock.newSheets(count:1,widthCm:10,heightCm:10,kerfCm:0)
      .tryAllocate([const WoodCutRequest(widthCm:6,heightCm:10)]);
    expect(first.successful,isTrue);
    expect(first.stock!.totalFreeArea,closeTo(40,0.0001));
    // A 5x5 rectangle has less total area than the remainder but cannot fit.
    final second=first.stock!.tryAllocate([
      const WoodCutRequest(widthCm:5,heightCm:5),
    ]);
    expect(second.successful,isFalse);
    expect(second.stock,isNull);
    expect(first.stock!.totalFreeArea,closeTo(40,0.0001));
  });

  test('Deduct complete panels only once on an allocation result', () {
    final before=WoodBoardStock.newSheets(count:2,widthCm:10,heightCm:10,kerfCm:0);
    final after=before.tryAllocate([
      const WoodCutRequest(widthCm:10,heightCm:10,count:2),
    ]);
    expect(after.successful,isTrue);
    expect(after.stock!.physicalSheets,0);
    expect(after.stock!.totalFreeArea,0);
    expect(before.physicalSheets,2);
  });

  test('Reject oversized cuts without mutating any previously tracked remnants', () {
    final before=WoodBoardStock.newSheets(count:1,widthCm:120,heightCm:80);
    final after=before.tryAllocate([
      const WoodCutRequest(widthCm:15,heightCm:20),
      const WoodCutRequest(widthCm:200,heightCm:20),
    ]);
    expect(after.successful,isFalse);
    expect(before.totalCutArea,0);
    expect(before.totalFreeArea,9600);
  });

  test('Persist exact rectangle remnants across app restart; add new panels safely', () {
    final start=WoodBoardStock.newSheets(count:1,widthCm:120,heightCm:80,kerfCm:0.02);
    final used=start.tryAllocate([
      const WoodCutRequest(widthCm:20,heightCm:12,count:2),
    ]).stock!;
    final restored=WoodBoardStock.fromJson(used.toJson());
    expect(restored.totalCutArea,closeTo(480,0.001));
    expect(restored.totalFreeArea,closeTo(used.totalFreeArea,0.001));
    expect(restored.openedSheets,1);
    final added=restored.withAddedSheets(2);
    expect(added.untouchedSheets,2);
    expect(added.openedSheets,1);
    expect(added.totalFreeArea,closeTo(restored.totalFreeArea+19200,0.001));
    expect(restored.boards.length,1);
  });

  test('Wood saw clearance is included in billable reserved area estimate', () {
    final board=WoodBoardStock.newSheets(count:1,widthCm:120,heightCm:80,kerfCm:0.02);
    expect(board.reservedAreaEstimate(15,20,1),closeTo(300.7004,0.0001));
  });
}
