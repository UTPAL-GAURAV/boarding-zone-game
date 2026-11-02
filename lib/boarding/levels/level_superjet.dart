import '../aircraft_layout.dart';

/// 5-abreast cabin (W-A-B-C-D-E): 20 rows, 100 seats. Used by Sukhoi Superjet 100.
abstract final class LevelSuperjet {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_5abreast_20row_superjet',
    designWidth: 360,
    designHeight: 806,
    rowCount: 20,
    zoneCount: 6,
    rowStartY: 104,
    rowSpacing: 33,
    seatWidth: 37,
    seatHeight: 27,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 138, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'B', centerX: 180, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'C', centerX: 222, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'D', centerX: 264, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'E', centerX: 306, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 96,
        width: 36,
        capacity: 40,
        minimumSpacingRows: 0.4,
        entryIntervalSeconds: 0.20,
        walkingSpeedRowsPerSecond: 2.66,
        turnDurationSeconds: 0.68,
        entranceRow: -6.0,
        floorTop: 79,
      ),
    ],
    seatBlocks: [
      SeatBlockLayout(left: 119, right: 325),
    ],
    windowCentersX: [30, 337],
    cabinShell: CabinRegion(
      left: 20,
      top: 28,
      width: 320,
      height: 738,
      cornerRadius: 54,
    ),
    flightDeck: CabinRegion(
      left: 120,
      top: 32,
      width: 120,
      height: 24,
      cornerRadius: 12,
    ),
    gateLabelY: 14,
    entranceDoorY: 67,
    entranceDoorHeight: 13,
    seatLayout: ['W', 'A', 'B', 'C', 'D', 'E'],
    blockerRules: {'A': [], 'B': ['A'], 'C': ['A', 'B'], 'D': ['A', 'B', 'C'], 'E': ['A', 'B', 'C', 'D']},
  );
}
