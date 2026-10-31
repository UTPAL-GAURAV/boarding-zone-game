import '../aircraft_layout.dart';

/// 2+2 single-aisle, 18 rows (70 seats). Matches CRJ-700 / Il-114-300 real config.
abstract final class LevelTwo {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_2_single_aisle_22',
    designWidth: 360,
    designHeight: 750,
    rowCount: 18,
    zoneCount: 6,
    rowStartY: 104,
    rowSpacing: 34,
    seatWidth: 37,
    seatHeight: 28,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 70,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 116, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 244, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 290, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 180,
        width: 32,
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
      SeatBlockLayout(left: 51, right: 155),
      SeatBlockLayout(left: 205, right: 309),
    ],
    windowCentersX: [31, 319],
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
    seatLayout: ['A', 'B', 'W', 'C', 'D'],
    blockerRules: {'A': ['B'], 'B': [], 'C': [], 'D': ['C']},
  );
}
