import '../aircraft_layout.dart';

/// 6-abreast narrow-body (A-B-C-W-D-E-F): 26 rows, 156 seats. Used by COMAC C919.
abstract final class LevelC919 {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_6abreast_26row',
    designWidth: 380,
    designHeight: 930,
    rowCount: 26,
    zoneCount: 6,
    rowStartY: 108,
    rowSpacing: 30,
    seatWidth: 32,
    seatHeight: 26,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 50,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 88,  aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'C', centerX: 126, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 214, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'E', centerX: 252, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'F', centerX: 290, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 170,
        width: 36,
        capacity: 46,
        minimumSpacingRows: 0.4,
        entryIntervalSeconds: 0.20,
        walkingSpeedRowsPerSecond: 2.66,
        turnDurationSeconds: 0.68,
        entranceRow: -6.0,
        floorTop: 83,
      ),
    ],
    seatBlocks: [
      SeatBlockLayout(left: 31, right: 145),
      SeatBlockLayout(left: 195, right: 309),
    ],
    windowCentersX: [18, 322],
    cabinShell: CabinRegion(
      left: 20,
      top: 28,
      width: 340,
      height: 862,
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
    seatLayout: ['A', 'B', 'C', 'W', 'D', 'E', 'F'],
    blockerRules: {'A': ['B', 'C'], 'B': ['C'], 'C': [], 'D': [], 'E': ['D'], 'F': ['D', 'E']},
  );
}
