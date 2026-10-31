import '../aircraft_layout.dart';

/// 2+3 single-aisle, 20 rows (100 seats). Matches E190 / Superjet 100 / An-158 real config.
abstract final class LevelFive {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_5_single_aisle_23',
    designWidth: 360,
    designHeight: 750,
    rowCount: 20,
    zoneCount: 6,
    rowStartY: 104,
    rowSpacing: 30,
    seatWidth: 30,
    seatHeight: 27,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 62,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 101, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 219, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 258, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'E', centerX: 297, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 180,
        width: 38,
        capacity: 38,
        minimumSpacingRows: 0.4,
        entryIntervalSeconds: 0.20,
        walkingSpeedRowsPerSecond: 2.66,
        turnDurationSeconds: 0.68,
        entranceRow: -6.0,
        floorTop: 79,
      ),
    ],
    seatBlocks: [
      SeatBlockLayout(left: 46, right: 117),
      SeatBlockLayout(left: 203, right: 313),
    ],
    windowCentersX: [31, 329],
    cabinShell: CabinRegion(
      left: 20,
      top: 28,
      width: 320,
      height: 700,
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
