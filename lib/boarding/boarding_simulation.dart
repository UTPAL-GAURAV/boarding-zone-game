import 'dart:math' as math;

import 'aircraft_layout.dart';
import 'levels/level_one.dart';

enum PassengerPhase { walking, turning, stowing, seated }

class BoardingSeat {
  BoardingSeat({
    required this.row,
    required this.column,
    required this.label,
    required this.aisleIndex,
    required this.zone,
  });

  final int row;
  final int column;
  final String label;
  final int aisleIndex;
  int zone;
}

class BoardingPassenger {
  BoardingPassenger(this.seat, {required this.rowPosition});

  final BoardingSeat seat;
  PassengerPhase phase = PassengerPhase.walking;
  double rowPosition;
  double turnProgress = 0;
  double stowRemaining = 0;
  double animationTime = 0;
}

class _AisleRuntime {
  _AisleRuntime(this.layout);

  final BoardingAisleLayout layout;
  final List<BoardingPassenger> manifest = [];
  final List<BoardingPassenger> passengers = [];
  int manifestIndex = 0;
  double entryClock = 0;
}

/// Boarding rules and run state, independent of Flame rendering/animation.
class BoardingSimulation {
  BoardingSimulation({
    this.layout = LevelOne.aircraft,
    this.luggageStowSeconds = 0.45,
    this.shuffleSeed,
  }) : seats = [
         for (final spec in layout.seatSpecs())
           BoardingSeat(
             row: spec.row,
             column: spec.columnIndex,
             label: spec.label,
             aisleIndex: spec.aisleIndex,
             zone: spec.defaultZone,
           ),
       ],
       _aisles = [for (final aisle in layout.aisles) _AisleRuntime(aisle)];

  final AircraftLayout layout;
  final double luggageStowSeconds;
  final int? shuffleSeed;
  final List<BoardingSeat> seats;
  final List<_AisleRuntime> _aisles;
  final List<BoardingPassenger> seatedPassengers = [];
  final math.Random _random = math.Random();
  int boardedCount = 0;
  double elapsedSeconds = 0;
  bool isBoarding = false;

  int get passengerCount => seats.length;
  int get enteredCount =>
      _aisles.fold(0, (sum, aisle) => sum + aisle.manifestIndex);
  int get waitingCount => _aisles.fold(
    0,
    (sum, aisle) => sum + aisle.manifest.length - aisle.manifestIndex,
  );
  int? get currentEntryZone {
    final zones = [
      for (final aisle in _aisles)
        if (aisle.manifestIndex < aisle.manifest.length)
          aisle.manifest[aisle.manifestIndex].seat.zone,
    ];
    return zones.isEmpty ? null : zones.reduce(math.min);
  }

  bool get isComplete => isBoarding && boardedCount == passengerCount;
  List<BoardingPassenger> get aislePassengers => [
    for (final aisle in _aisles) ...aisle.passengers,
  ];
  List<BoardingSeat> get boardingOrder => List.unmodifiable([
    for (final aisle in _aisles)
      for (final passenger in aisle.manifest) passenger.seat,
  ]);

  void cycleZone(BoardingSeat seat) {
    if (isBoarding) return;
    seat.zone = (seat.zone + 1) % layout.zoneCount;
  }

  void start() {
    if (isBoarding) return;
    isBoarding = true;
    boardedCount = 0;
    elapsedSeconds = 0;
    seatedPassengers.clear();
    final random = shuffleSeed == null ? _random : math.Random(shuffleSeed);
    for (var aisleIndex = 0; aisleIndex < _aisles.length; aisleIndex++) {
      final aisle = _aisles[aisleIndex]
        ..manifest.clear()
        ..passengers.clear()
        ..manifestIndex = 0
        ..entryClock = _aisles[aisleIndex].layout.entryIntervalSeconds;
      for (var zone = 0; zone < layout.zoneCount; zone++) {
        final zoneSeats = seats
            .where((seat) => seat.aisleIndex == aisleIndex && seat.zone == zone)
            .toList();
        zoneSeats.shuffle(random);
        aisle.manifest.addAll(
          zoneSeats.map(
            (seat) =>
                BoardingPassenger(seat, rowPosition: aisle.layout.entranceRow),
          ),
        );
      }
      _tryEnterNextPassenger(aisle);
    }
  }

  void reset() {
    isBoarding = false;
    boardedCount = 0;
    elapsedSeconds = 0;
    seatedPassengers.clear();
    for (final aisle in _aisles) {
      aisle.passengers.clear();
      aisle.manifest.clear();
      aisle.manifestIndex = 0;
      aisle.entryClock = 0;
    }
  }

  void update(double dt) {
    if (!isBoarding || isComplete) return;
    final delta = math.min(dt, 0.08);
    elapsedSeconds += delta;
    for (final aisle in _aisles) {
      final seatedThisFrame = <BoardingPassenger>[];
      for (var index = 0; index < aisle.passengers.length; index++) {
        final passenger = aisle.passengers[index];
        passenger.animationTime += delta;
        switch (passenger.phase) {
          case PassengerPhase.walking:
            final furthestAllowed = index == 0
                ? double.infinity
                : aisle.passengers[index - 1].rowPosition -
                      aisle.layout.minimumSpacingRows;
            passenger.rowPosition = math.min(
              passenger.seat.row.toDouble(),
              math.min(
                passenger.rowPosition +
                    delta * aisle.layout.walkingSpeedRowsPerSecond,
                furthestAllowed,
              ),
            );
            if (passenger.rowPosition >= passenger.seat.row) {
              passenger.phase = PassengerPhase.turning;
            }
          case PassengerPhase.turning:
            passenger.turnProgress = math.min(
              1,
              passenger.turnProgress + delta / aisle.layout.turnDurationSeconds,
            );
            if (passenger.turnProgress >= 1) {
              passenger.phase = PassengerPhase.stowing;
              passenger.stowRemaining = luggageStowSeconds;
            }
          case PassengerPhase.stowing:
            passenger.stowRemaining -= delta;
            if (passenger.stowRemaining <= 0) {
              passenger.phase = PassengerPhase.seated;
              seatedThisFrame.add(passenger);
            }
          case PassengerPhase.seated:
            break;
        }
      }
      if (seatedThisFrame.isNotEmpty) {
        aisle.passengers.removeWhere(seatedThisFrame.contains);
        seatedPassengers.addAll(seatedThisFrame);
        boardedCount += seatedThisFrame.length;
      }
      aisle.entryClock = math.min(
        aisle.layout.entryIntervalSeconds,
        aisle.entryClock + delta,
      );
      if (aisle.entryClock >= aisle.layout.entryIntervalSeconds &&
          _tryEnterNextPassenger(aisle)) {
        aisle.entryClock = 0;
      }
    }
  }

  bool _tryEnterNextPassenger(_AisleRuntime aisle) {
    if (aisle.manifestIndex >= aisle.manifest.length ||
        aisle.passengers.length >= aisle.layout.capacity) {
      return false;
    }
    if (aisle.passengers.isNotEmpty &&
        aisle.passengers.last.rowPosition - aisle.layout.entranceRow <
            aisle.layout.minimumSpacingRows) {
      return false;
    }
    aisle.passengers.add(aisle.manifest[aisle.manifestIndex]);
    aisle.manifestIndex++;
    return true;
  }
}
