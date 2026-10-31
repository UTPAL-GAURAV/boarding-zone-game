import '../aircraft_layout.dart';

/// Tutorial flight — 4-abreast, 3 rows (12 seats), 2 zones.
/// Kept intentionally tiny so new players can see the full effect quickly.
abstract final class LevelTutorial {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_tutorial',
    designWidth: 360,
    designHeight: 320,
    rowCount: 3,
    zoneCount: 2,
    rowStartY: 140,
    rowSpacing: 44,
    seatWidth: 37,
    seatHeight: 27,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 70,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 116, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 244, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 290, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [1, 1, 1],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 180,
        width: 32,
        capacity: 10,
        minimumSpacingRows: 0.4,
        entryIntervalSeconds: 0.30,
        walkingSpeedRowsPerSecond: 2.0,
        turnDurationSeconds: 0.68,
        entranceRow: -4.0,
        floorTop: 115,
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
      height: 240,
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
    entranceDoorY: 103,
    entranceDoorHeight: 13,
    seatLayout: ['A', 'B', 'W', 'C', 'D'],
    blockerRules: {'A': ['B'], 'B': [], 'C': [], 'D': ['C']},
  );
}
