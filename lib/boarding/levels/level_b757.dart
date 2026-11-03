import '../aircraft_layout.dart';

/// 6-abreast narrow-body (A-B-W-C-D-E-F): 33 rows, 198 seats. Used by Boeing 757-200.
abstract final class LevelB757 {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_6abreast_33row',
    designWidth: 380,
    designHeight: 1140,
    rowCount: 33,
    zoneCount: 6,
    rowStartY: 108,
    rowSpacing: 30,
    seatWidth: 32,
    seatHeight: 26,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 88,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 126, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 214, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 252, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'E', centerX: 290, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'F', centerX: 328, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 170,
        width: 36,
        capacity: 53,
        minimumSpacingRows: 0.4,
        entryIntervalSeconds: 0.20,
        walkingSpeedRowsPerSecond: 2.66,
        turnDurationSeconds: 0.68,
        entranceRow: -6.0,
        floorTop: 83,
      ),
    ],
    seatBlocks: [
      SeatBlockLayout(left: 69, right: 145),
      SeatBlockLayout(left: 195, right: 347),
    ],
    windowCentersX: [56, 360],
    cabinShell: CabinRegion(
      left: 20,
      top: 28,
      width: 340,
      height: 1072,
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
