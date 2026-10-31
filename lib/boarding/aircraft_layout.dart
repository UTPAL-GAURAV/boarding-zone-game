enum SeatType { aisle, middle, window }

class CabinRegion {
  const CabinRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.cornerRadius = 0,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double cornerRadius;
}

class SeatColumnLayout {
  const SeatColumnLayout({
    required this.label,
    required this.centerX,
    required this.aisleIndex,
    required this.seatType,
  });

  final String label;
  final double centerX;
  final int aisleIndex;
  final SeatType seatType;
}

class BoardingAisleLayout {
  const BoardingAisleLayout({
    required this.id,
    required this.centerX,
    required this.width,
    required this.capacity,
    required this.minimumSpacingRows,
    required this.entryIntervalSeconds,
    required this.walkingSpeedRowsPerSecond,
    required this.turnDurationSeconds,
    required this.entranceRow,
    required this.floorTop,
  });

  final String id;
  final double centerX;
  final double width;
  final int capacity;
  final double minimumSpacingRows;
  final double entryIntervalSeconds;
  final double walkingSpeedRowsPerSecond;
  final double turnDurationSeconds;
  final double entranceRow;
  final double floorTop;
}

class SeatBlockLayout {
  const SeatBlockLayout({required this.left, required this.right});

  final double left;
  final double right;
}

class SeatLayoutSpec {
  const SeatLayoutSpec({
    required this.row,
    required this.columnIndex,
    required this.label,
    required this.aisleIndex,
    required this.defaultZone,
    required this.seatType,
  });

  final int row;
  final int columnIndex;
  final String label;
  final int aisleIndex;
  final int defaultZone;
  final SeatType seatType;
}

/// Immutable, source-authored geometry and rules for one aircraft level.
class AircraftLayout {
  const AircraftLayout({
    required this.id,
    required this.designWidth,
    required this.designHeight,
    required this.rowCount,
    required this.zoneCount,
    required this.rowStartY,
    required this.rowSpacing,
    required this.seatWidth,
    required this.seatHeight,
    required this.seatColumns,
    required this.rowDefaultZones,
    required this.aisles,
    required this.seatBlocks,
    required this.windowCentersX,
    required this.cabinShell,
    required this.flightDeck,
    required this.gateLabelY,
    required this.entranceDoorY,
    required this.entranceDoorHeight,
    required this.seatLayout,
    required this.blockerRules,
  }) : assert(rowCount > 0),
       assert(zoneCount > 0);

  final String id;
  final double designWidth;
  final double designHeight;
  final int rowCount;
  final int zoneCount;
  final double rowStartY;
  final double rowSpacing;
  final double seatWidth;
  final double seatHeight;
  final List<SeatColumnLayout> seatColumns;
  final List<int> rowDefaultZones;
  final List<BoardingAisleLayout> aisles;
  final List<SeatBlockLayout> seatBlocks;
  final List<double> windowCentersX;
  final CabinRegion cabinShell;
  final CabinRegion flightDeck;
  final double gateLabelY;
  final double entranceDoorY;
  final double entranceDoorHeight;

  /// Seat columns and walking aisles from left to right.
  /// Seat labels are letter strings (e.g. "A", "B"); walking aisles are "W".
  /// Example 2-4-2: ["A","B","W","C","D","E","F","W","G","H"]
  final List<String> seatLayout;

  /// Who must stand up when a given seat label is being filled.
  /// Key = seat label (e.g. "A"), value = list of seat labels that must vacate.
  /// Derived from seatLayout + aisleIndex at definition time — no runtime scanning.
  /// Example for ["A","B","W","C","D"]: blockerRules = {"A": ["B"], "B": [], "C": [], "D": []}
  final Map<String, List<String>> blockerRules;

  int get seatsPerRow => seatColumns.length;
  int get passengerCount => rowCount * seatsPerRow;

  Iterable<SeatLayoutSpec> seatSpecs() sync* {
    for (var row = 0; row < rowCount; row++) {
      for (
        var columnIndex = 0;
        columnIndex < seatColumns.length;
        columnIndex++
      ) {
        final column = seatColumns[columnIndex];
        yield SeatLayoutSpec(
          row: row,
          columnIndex: columnIndex,
          label: column.label,
          aisleIndex: column.aisleIndex,
          defaultZone: rowDefaultZones[row],
          seatType: column.seatType,
        );
      }
    }
  }
}
