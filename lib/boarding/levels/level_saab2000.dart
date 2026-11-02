import '../aircraft_layout.dart';

/// Asymmetric 4-abreast cabin (A-W-B-C-D): 13 rows, 52 seats.
/// Left: single window seat A. Right: B=aisle, C=middle, D=window.
/// Used by Saab 2000.
abstract final class LevelSaab2000 {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_saab2000_13row',
    designWidth: 360,
    designHeight: 580,
    rowCount: 13,
    zoneCount: 6,
    rowStartY: 108,
    rowSpacing: 33,
    seatWidth: 37,
    seatHeight: 27,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 90, aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 196, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 242, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'D', centerX: 288, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 143,
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
      SeatBlockLayout(left: 71, right: 109),
      SeatBlockLayout(left: 177, right: 307),
    ],
    windowCentersX: [51, 319],
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
    seatLayout: ['A', 'W', 'B', 'C', 'D'],
    blockerRules: {'A': [], 'B': [], 'C': ['B'], 'D': ['B', 'C']},
  );
}
