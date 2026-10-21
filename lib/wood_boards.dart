import 'dart:math' as math;

/// A conservative rectangular guillotine-cut estimate.
/// Irregular SVG nesting is NOT represented by this model.
class WoodCutRequest {
  const WoodCutRequest({required this.widthCm, required this.heightCm, this.count = 1});
  final double widthCm;
  final double heightCm;
  final int count;
}

class FreeWoodRect {
  const FreeWoodRect(this.x, this.y, this.width, this.height);
  final double x, y, width, height;
  double get area => width * height;
  Map<String, dynamic> toJson() => {'x':x,'y':y,'width':width,'height':height};
  factory FreeWoodRect.fromJson(Map<String,dynamic> v) => FreeWoodRect(
    (v['x'] as num).toDouble(), (v['y'] as num).toDouble(),
    (v['width'] as num).toDouble(), (v['height'] as num).toDouble());
}

class WoodPlacement {
  const WoodPlacement({required this.x, required this.y, required this.widthCm,
    required this.heightCm, required this.reservedWidthCm, required this.reservedHeightCm,
    required this.rotated});
  final double x, y, widthCm, heightCm, reservedWidthCm, reservedHeightCm;
  final bool rotated;
  double get reservedArea => reservedWidthCm * reservedHeightCm;
  double get netArea => widthCm * heightCm;
  Map<String,dynamic> toJson() => {'x':x,'y':y,'widthCm':widthCm,'heightCm':heightCm,
    'reservedWidthCm':reservedWidthCm,'reservedHeightCm':reservedHeightCm,'rotated':rotated};
  factory WoodPlacement.fromJson(Map<String,dynamic> v) => WoodPlacement(
    x:(v['x'] as num).toDouble(), y:(v['y'] as num).toDouble(),
    widthCm:(v['widthCm'] as num).toDouble(), heightCm:(v['heightCm'] as num).toDouble(),
    reservedWidthCm:(v['reservedWidthCm'] as num).toDouble(),
    reservedHeightCm:(v['reservedHeightCm'] as num).toDouble(),
    rotated:v['rotated'] as bool? ?? false);
}

class WoodBoard {
  WoodBoard({required this.id, required List<FreeWoodRect> free,
    List<WoodPlacement>? placements})
    : freeRects = free, placements = placements ?? [];
  final String id;
  final List<FreeWoodRect> freeRects;
  final List<WoodPlacement> placements;
  double get freeArea => freeRects.fold(0, (double s, r) => s+r.area);
  double get usedArea => placements.fold(0, (double s, p) => s+p.netArea);
  double get wasteArea => math.max(0, initialArea - freeArea - usedArea);
  // Must be supplied by parent when displaying actual board loss.
  double initialArea = 0;
  bool get isOpened => placements.isNotEmpty;
  bool get canCut => freeRects.any((r) => r.width>0.001 && r.height>0.001);
  WoodBoard copy() => WoodBoard(id:id,free:[...freeRects],placements:[...placements])..initialArea=initialArea;
  Map<String,dynamic> toJson() => {
    'id':id,'freeRects':freeRects.map((e)=>e.toJson()).toList(),
    'placements':placements.map((e)=>e.toJson()).toList()};
  factory WoodBoard.fromJson(Map<String,dynamic> v) => WoodBoard(
    id:v['id'] as String,
    free:(v['freeRects'] as List).map((e)=>FreeWoodRect.fromJson(Map<String,dynamic>.from(e as Map))).toList(),
    placements:(v['placements'] as List? ?? []).map((e)=>WoodPlacement.fromJson(Map<String,dynamic>.from(e as Map))).toList());
}

class BoardAllocation {
  const BoardAllocation(this.stock,this.placementsByBoard,this.message);
  final WoodBoardStock? stock;
  final Map<String,List<WoodPlacement>> placementsByBoard;
  final String? message;
  bool get successful => stock != null && message == null;
}

/// Each physical sheet owns non-overlapping free rectangles. This preserves
/// rectangular remnants instead of treating all leftover area as one board.
class WoodBoardStock {
  WoodBoardStock({required this.widthCm,required this.heightCm,required this.kerfCm,
    required this.boards}) {
    for(final b in boards) { b.initialArea=boardArea; }
  }
  final double widthCm, heightCm, kerfCm;
  final List<WoodBoard> boards;
  double get boardArea => widthCm*heightCm;
  int get physicalSheets => boards.where((b)=>b.canCut).length;
  int get untouchedSheets => boards.where((b)=>b.placements.isEmpty && b.canCut).length;
  int get openedSheets => boards.where((b)=>b.isOpened && b.canCut).length;
  double get totalFreeArea => boards.fold(0,(double s,b)=>s+b.freeArea);
  double get totalCutArea => boards.fold(0,(double s,b)=>s+b.usedArea);
  double get totalWasteArea => math.max(0,boardArea*boards.length-totalFreeArea-totalCutArea);
  double get sheetEquivalents => totalFreeArea / boardArea;
  WoodBoardStock copy() => WoodBoardStock(widthCm:widthCm,heightCm:heightCm,
    kerfCm:kerfCm,boards:boards.map((b)=>b.copy()).toList());

  factory WoodBoardStock.newSheets({required int count,required double widthCm,
    required double heightCm,double kerfCm=0.02}) {
    if(count<0 || count>500 || !widthCm.isFinite || !heightCm.isFinite ||
      !kerfCm.isFinite || widthCm<=0 || heightCm<=0 || kerfCm<0) {
      throw ArgumentError('Invalid sheet dimensions or count');
    }
    return WoodBoardStock(widthCm:widthCm,heightCm:heightCm,kerfCm:kerfCm,
      boards:List.generate(count,(i)=>WoodBoard(
        id:'board-${DateTime.now().microsecondsSinceEpoch}-$i',
        free:[FreeWoodRect(0,0,widthCm,heightCm)])));
  }
  Map<String,dynamic> toJson() => {'widthCm':widthCm,'heightCm':heightCm,
    'kerfCm':kerfCm,'boards':boards.map((b)=>b.toJson()).toList()};
  factory WoodBoardStock.fromJson(Map<String,dynamic> v) => WoodBoardStock(
    widthCm:(v['widthCm'] as num).toDouble(),
    heightCm:(v['heightCm'] as num).toDouble(),
    kerfCm:(v['kerfCm'] as num? ?? 0.02).toDouble(),
    boards:(v['boards'] as List).map((e)=>WoodBoard.fromJson(Map<String,dynamic>.from(e as Map))).toList());

  double reservedAreaEstimate(double width,double height,int count) =>
    (width+kerfCm)*(height+kerfCm)*count;

  /// Works on a copy; a failed fit leaves the original inventory unchanged.
  /// Prefer already opened sheets and smallest fitting free rectangle.
  BoardAllocation tryAllocate(List<WoodCutRequest> requests) {
    final result=copy();
    final placements=<String,List<WoodPlacement>>{};
    for(final request in requests) {
      if(!request.widthCm.isFinite || !request.heightCm.isFinite ||
         request.widthCm<=0 || request.heightCm<=0 || request.count<1 || request.count>1000) {
         return const BoardAllocation(null,{},'قياسات القص أو عدد القطع غير صحيح');
      }
      for(var piece=0;piece<request.count;piece++) {
        ({WoodBoard board,int rectIndex,bool rotate,double occupiedW,double occupiedH,double waste})? best;
        for(final board in result.boards) {
          for(var idx=0;idx<board.freeRects.length;idx++) {
            final free=board.freeRects[idx];
            for(final rotate in [false,true]) {
              final actualW=rotate?request.heightCm:request.widthCm;
              final actualH=rotate?request.widthCm:request.heightCm;
              // No additional kerf is needed at a sheet boundary. Otherwise,
              // reserve a conservative laser-cut clearance for this rectangle.
              final occupiedW=actualW+(actualW+1e-7<free.width ? result.kerfCm:0);
              final occupiedH=actualH+(actualH+1e-7<free.height ? result.kerfCm:0);
              if(occupiedW>free.width+1e-7 || occupiedH>free.height+1e-7) continue;
              // Opened sheets are preferred over opening a fresh board.
              final waste=(board.isOpened ? 0 : 1e9) + free.area-occupiedW*occupiedH;
              if(best==null || waste<best.waste) {
                best=(board:board,rectIndex:idx,rotate:rotate,
                  occupiedW:occupiedW,occupiedH:occupiedH,waste:waste);
              }
            }
          }
        }
        if(best==null) {
          return BoardAllocation(null,{},'القطع ${request.widthCm}×${request.heightCm} سم ما بتركب بالبقايا المتوفرة. يمكن تحتاج لوح جديد أو تغيّر ترتيب القص.');
        }
        final slot=best.board.freeRects.removeAt(best.rectIndex);
        final actualW=best.rotate?request.heightCm:request.widthCm;
        final actualH=best.rotate?request.widthCm:request.heightCm;
        final p=WoodPlacement(x:slot.x,y:slot.y,widthCm:actualW,heightCm:actualH,
          reservedWidthCm:best.occupiedW,reservedHeightCm:best.occupiedH,rotated:best.rotate);
        best.board.placements.add(p);
        placements.putIfAbsent(best.board.id,()=>[]).add(p);
        final rightW=slot.width-best.occupiedW;
        final belowH=slot.height-best.occupiedH;
        if(rightW>0.001) best.board.freeRects.add(
          FreeWoodRect(slot.x+best.occupiedW,slot.y,rightW,slot.height));
        if(belowH>0.001) best.board.freeRects.add(
          FreeWoodRect(slot.x,slot.y+best.occupiedH,best.occupiedW,belowH));
      }
    }
    return BoardAllocation(result,placements,null);
  }
}
