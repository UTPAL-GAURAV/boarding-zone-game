import '../aircraft_layout.dart';

/// 6-abreast narrow-body (A-B-W-C-D-E-F): 23 rows, 138 seats. Used by A319neo.
abstract final class LevelA319 {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_6abreast_23row',
    designWidth: 380,
    designHeight: 840,
    rowCount: 23,
    zoneCount: 6,
    rowStartY: 108,
    rowSpacing: 30,
    seatWidth: 32,
    seatHeight: 26,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 44,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 80,  aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 152, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 188, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'E', centerX: 224, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'F', centerX: 260, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 116,
        width: 36,
        capacity: 43,
        minimumSpacingRows: 0.4,
        entryIntervalSeconds: 0.20,
        walkingSpeedRowsPerSecond: 2.66,
        turnDurationSeconds: 0.68,
        entranceRow: -6.0,
        floorTop: 83,
      ),
    ],
    seatBlocks: [
      SeatBlockLayout(left: 25, right: 99),
      SeatBlockLayout(left: 133, right: 279),
    ],
    windowCentersX: [12, 291],
    cabinShell: CabinRegion(
      left: 20,
      top: 28,
      width: 340,
      height: 772,
      cornerRadius: 54,
    ),
    flightDeck: CabinRegion(
      left: 130,
      top: 32,
      width: 120,
      height: 24,
      cornerRadius: 12,
    ),
    gateLabelY: 14,
    entranceDoorY: 71,
    entranceDoorHeight: 13,
    seatLayout: ['A', 'B', 'W', 'C', 'D', 'E', 'F'],
    blockerRules: {'A': ['B'], 'B': [], 'C': [], 'D': ['C'], 'E': ['C', 'D'], 'F': ['C', 'D', 'E']},
  );
}
