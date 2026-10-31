import '../aircraft_layout.dart';

/// Hard-coded prototype aircraft. Each future level gets its own definition.
abstract final class LevelOne {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_1_single_aisle',
    designWidth: 360,
    designHeight: 580,
    rowCount: 13,
    zoneCount: 6,
    rowStartY: 108,
    rowSpacing: 33,
    seatWidth: 37,
    seatHeight: 27,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 70, aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 116, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 244, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 290, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 180,
        width: 32,
        capacity: 33,
        minimumSpacingRows: 0.4,
        entryIntervalSeconds: 0.20,
        walkingSpeedRowsPerSecond: 2.66,
        turnDurationSeconds: 0.68,
        entranceRow: -6.0,
        floorTop: 83,
      ),
    ],
    seatBlocks: [
      SeatBlockLayout(left: 51, right: 155),
      SeatBlockLayout(left: 205, right: 309),
    ],
    windowCentersX: [31, 319],
    cabinShell: CabinRegion(
      left: 20,
      top: 38,
      width: 320,
      height: 510,
      cornerRadius: 54,
    ),
    flightDeck: CabinRegion(
      left: 120,
      top: 42,
      width: 120,
      height: 24,
      cornerRadius: 12,
    ),
    gateLabelY: 24,
    entranceDoorY: 71,
    entranceDoorHeight: 13,
    seatLayout: ['A', 'B', 'W', 'C', 'D'],
    blockerRules: {'A': ['B'], 'B': [], 'C': [], 'D': ['C']},
  );
}
