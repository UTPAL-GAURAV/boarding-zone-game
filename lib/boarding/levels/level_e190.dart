import '../aircraft_layout.dart';

/// 5-abreast cabin: 20 rows, 100 seats. Used by Embraer E190.
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
      SeatColumnLayout(label: 'A', centerX: 52,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 96,  aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 214, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 258, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'E', centerX: 302, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 155,
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
      SeatBlockLayout(left: 33, right: 115),
      SeatBlockLayout(left: 195, right: 321),
    ],
    windowCentersX: [18, 335],
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
    seatLayout: ['A', 'B', 'W', 'C', 'D', 'E'],
    blockerRules: {'A': ['B'], 'B': [], 'C': [], 'D': ['C'], 'E': ['C', 'D']},
  );
}
