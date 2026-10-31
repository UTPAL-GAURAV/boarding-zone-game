import '../aircraft_layout.dart';

/// Seventeen-row regional cabin for the 34-seat Saab 340 mission.
abstract final class LevelSaab340 {
  static const AircraftLayout aircraft = AircraftLayout(
    id: 'level_saab_340b_34_seat',
    designWidth: 360,
    designHeight: 810,
    rowCount: 17,
    zoneCount: 6,
    rowStartY: 110,
    rowSpacing: 37,
    seatWidth: 39,
    seatHeight: 30,
    seatColumns: [
      SeatColumnLayout(label: 'A', centerX: 111, aisleIndex: 0),
      SeatColumnLayout(label: 'B', centerX: 249, aisleIndex: 0),
    ],
    rowDefaultZones: [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
    aisles: [
      BoardingAisleLayout(
        id: 'main',
        centerX: 180,
        width: 60,
        capacity: 10,
        minimumSpacingRows: 0.85,
        entryIntervalSeconds: 0.20,
        walkingSpeedRowsPerSecond: 5.5,
        turnDurationSeconds: 0.24,
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
      height: 740,
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
