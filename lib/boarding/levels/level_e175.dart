import '../aircraft_layout.dart';

/// 4-abreast (A-B-C-W-D): 20 rows, 80 seats. Embraer E175.
abstract final class LevelE175 {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_4abreast_20row_e175',
    designWidth: 360,
    designHeight: 826,
    rowCount: 20,
    zoneCount: 6,
    rowStartY: 104,
    rowSpacing: 34,
    seatWidth: 37,
    seatHeight: 28,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 55,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 97,  aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'C', centerX: 139, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 275, aisleIndex: 0, seatType: SeatType.aisle),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 207,
        width: 32,
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
      SeatBlockLayout(left: 36, right: 158),
      SeatBlockLayout(left: 256, right: 294),
    ],
    windowCentersX: [18, 319],
    cabinShell: CabinRegion(
      left: 20,
      top: 28,
      width: 320,
      height: 758,
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
    seatLayout: ['A', 'B', 'C', 'W', 'D'],
    blockerRules: {'A': ['B', 'C'], 'B': ['C'], 'C': [], 'D': []},
  );
}
