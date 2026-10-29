import '../aircraft_layout.dart';

/// Hard-coded 72-seat single-aisle cabin used by the second prototype layout.
abstract final class LevelTwo {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_2_single_aisle',
    designWidth: 360,
    designHeight: 620,
    rowCount: 12,
    zoneCount: 6,
    rowStartY: 114,
    rowSpacing: 39,
    seatWidth: 29,
    seatHeight: 29,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 55, aisleIndex: 0),
      SeatColumnLayout(label: 'B', centerX: 94, aisleIndex: 0),
      SeatColumnLayout(label: 'C', centerX: 133, aisleIndex: 0),
      SeatColumnLayout(label: 'D', centerX: 227, aisleIndex: 0),
      SeatColumnLayout(label: 'E', centerX: 266, aisleIndex: 0),
      SeatColumnLayout(label: 'F', centerX: 305, aisleIndex: 0),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 180,
        width: 34,
        capacity: 14,
        minimumSpacingRows: 0.85,
        entryIntervalSeconds: 0.36,
        walkingSpeedRowsPerSecond: 5.5,
        turnDurationSeconds: 0.24,
        entranceRow: -0.9,
        floorTop: 89,
      ),
    ],
    seatBlocks: [
      SeatBlockLayout(left: 39, right: 148),
      SeatBlockLayout(left: 212, right: 321),
    ],
    windowCentersX: [27, 333],
    cabinShell: CabinRegion(
      left: 16,
      top: 38,
      width: 328,
      height: 548,
      cornerRadius: 52,
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
