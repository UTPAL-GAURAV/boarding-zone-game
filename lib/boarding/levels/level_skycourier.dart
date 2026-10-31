import '../aircraft_layout.dart';

/// Ten-row single-aisle cabin for the 19-seat Cessna SkyCourier mission.
abstract final class LevelSkyCourier {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_skycourier_19_seat',
    designWidth: 360,
    designHeight: 620,
    rowCount: 10,
    zoneCount: 6,
    rowStartY: 132,
    rowSpacing: 36,
    seatWidth: 39,
    seatHeight: 29,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 111, aisleIndex: 0, seatType: SeatType.aisle),
      SeatColumnLayout(label: 'B', centerX: 249, aisleIndex: 0, seatType: SeatType.aisle),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 180,
        width: 60,
        capacity: 7,
        minimumSpacingRows: 0.4,
        entryIntervalSeconds: 0.20,
        walkingSpeedRowsPerSecond: 2.66,
        turnDurationSeconds: 0.68,
        entranceRow: -0.9,
        floorTop: 89,
      ),
    ],
    seatBlocks: [
      SeatBlockLayout(left: 88, right: 134),
      SeatBlockLayout(left: 226, right: 272),
    ],
    windowCentersX: [55, 305],
    cabinShell: CabinRegion(
      left: 30,
      top: 38,
      width: 300,
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
    seatLayout: ['A', 'W', 'B'],
  );
}
