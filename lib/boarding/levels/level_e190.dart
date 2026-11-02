import '../aircraft_layout.dart';

/// 5-abreast cabin (A-W-B-C-D-E): 20 rows, 100 seats. Used by Embraer E190.
abstract final class LevelE190 {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_5abreast_20row_e190',
    designWidth: 360,
    designHeight: 806,
    rowCount: 20,
    zoneCount: 6,
    rowStartY: 104,
    rowSpacing: 33,
    seatWidth: 37,
    seatHeight: 27,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 68,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 162, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 204, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'D', centerX: 246, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'E', centerX: 288, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 115,
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
      SeatBlockLayout(left: 49, right: 87),
      SeatBlockLayout(left: 143, right: 307),
    ],
    windowCentersX: [30, 319],
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
    seatLayout: ['A', 'W', 'B', 'C', 'D', 'E'],
    blockerRules: {'A': [], 'B': [], 'C': ['B'], 'D': ['B', 'C'], 'E': ['B', 'C', 'D']},
  );
}
