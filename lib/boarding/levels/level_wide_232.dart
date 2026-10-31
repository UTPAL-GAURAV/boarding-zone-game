import '../aircraft_layout.dart';

/// Shared 2-3-2 wide-body cabin (7 abreast, 2 aisles) for A330/787/777-200ER family.
abstract final class LevelWide232 {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_wide_232',
    designWidth: 380,
    designHeight: 750,
    rowCount: 20,
    zoneCount: 6,
    rowStartY: 114,
    rowSpacing: 29,
    seatWidth: 28,
    seatHeight: 24,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 40,  aisleIndex: 0, seatType: SeatType.window),
      SeatColumnLayout(label: 'B', centerX: 72,  aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'C', centerX: 124, aisleIndex: 1, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'D', centerX: 156, aisleIndex: 1, seatType: SeatType.middle),
      SeatColumnLayout(label: 'E', centerX: 188, aisleIndex: 1, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'F', centerX: 240, aisleIndex: 2, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'G', centerX: 272, aisleIndex: 2, seatType: SeatType.window),
    ],
    rowDefaultZones: [
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
      5, 5, 5, 5, 5, 5, 5, 5, 5, 5,
    ],
    aisles: [
      BoardingAisleLayout(
        id: 'left',
        centerX: 96,
        width: 30,
        capacity: 10,
        minimumSpacingRows: 0.85,
        entryIntervalSeconds: 0.24,
        walkingSpeedRowsPerSecond: 5.0,
        turnDurationSeconds: 0.26,
        entranceRow: -0.9,
        floorTop: 89,
      ),
      BoardingAisleLayout(
        id: 'right',
        centerX: 256,
        width: 30,
        capacity: 10,
        minimumSpacingRows: 0.85,
        entryIntervalSeconds: 0.24,
        walkingSpeedRowsPerSecond: 5.0,
        turnDurationSeconds: 0.26,
        entranceRow: -0.9,
        floorTop: 89,
      ),
    ],
    seatBlocks: [
      SeatBlockLayout(left: 24, right: 88),
      SeatBlockLayout(left: 108, right: 204),
      SeatBlockLayout(left: 224, right: 288),
    ],
    windowCentersX: [12, 300],
    cabinShell: CabinRegion(
      left: 10,
      top: 38,
      width: 360,
      height: 680,
      cornerRadius: 58,
    ),
    flightDeck: CabinRegion(
      left: 130,
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
