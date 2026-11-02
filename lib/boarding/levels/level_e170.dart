import '../aircraft_layout.dart';

/// 4-abreast (W-A-B-C-D): 18 rows, 72 seats. Embraer E170.
abstract final class LevelE170 {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_4abreast_18row_e170',
    designWidth: 360,
    designHeight: 758,
    rowCount: 18,
    zoneCount: 6,
    rowStartY: 104,
    rowSpacing: 34,
    seatWidth: 37,
    seatHeight: 28,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 145, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'B', centerX: 187, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'C', centerX: 229, aisleIndex: 0, seatType: SeatType.middle),
      SeatColumnLayout(label: 'D', centerX: 271, aisleIndex: 0, seatType: SeatType.window),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 107,
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
      SeatBlockLayout(left: 126, right: 290),
    ],
    windowCentersX: [31, 302],
    cabinShell: CabinRegion(
      left: 20,
      top: 28,
      width: 320,
      height: 690,
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
    seatLayout: ['W', 'A', 'B', 'C', 'D'],
    blockerRules: {'A': [], 'B': ['A'], 'C': ['A', 'B'], 'D': ['A', 'B', 'C']},
  );
}
