import '../aircraft_layout.dart';

/// Hard-coded prototype aircraft. Each future level gets its own definition.
abstract final class LevelOne {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_1_single_aisle',
    designWidth: 360,
    designHeight: 620,
    rowCount: 12,
    zoneCount: 6,
    rowStartY: 114,
    rowSpacing: 39,
    seatWidth: 37,
    seatHeight: 29,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 70, aisleIndex: 0),
      SeatColumnLayout(label: 'B', centerX: 116, aisleIndex: 0),
      SeatColumnLayout(label: 'C', centerX: 244, aisleIndex: 0),
      SeatColumnLayout(label: 'D', centerX: 290, aisleIndex: 0),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 180,
        width: 32,
        capacity: 12,
        minimumSpacingRows: 0.85,
        entryIntervalSeconds: 0.20,
        walkingSpeedRowsPerSecond: 5.5,
        turnDurationSeconds: 0.24,
        entranceRow: -0.9,
        floorTop: 89,
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
      height: 548,
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
    entranceDoorY: 77,
    entranceDoorHeight: 13,
  );
}
