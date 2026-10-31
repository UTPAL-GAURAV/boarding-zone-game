import 'dart:math' as math;

import 'aircraft_layout.dart';
import 'levels/level_one.dart';

enum PassengerPhase { walking, turning, stowing, shuffleWait, seated }

class BoardingSeat {
  BoardingSeat({
    required this.row,
    required this.column,
    required this.label,
    required this.aisleIndex,
    required this.zone,
    required this.seatType,
  });

  final int row;
  final int column;
  final String label;
  final int aisleIndex;
  final SeatType seatType;
  int zone;
}

class BoardingPassenger {
  BoardingPassenger(this.seat, {required this.rowPosition});

  final BoardingSeat seat;
  PassengerPhase phase = PassengerPhase.walking;
  double rowPosition;
  double turnProgress = 0;
  double stowRemaining = 0;
  double shuffleWaitRemaining = 0;
  double animationTime = 0;

  // Shuffle animation: 0→1 over the wait duration, drives blocker slide
  bool isShuffling = false;
  double shuffleProgress = 0;
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
    this.luggageStowSeconds = 1.2,
    this.shuffleSeed,
    List<int>? initialZones,
  }) : seats = [
         for (final spec in layout.seatSpecs())
           BoardingSeat(
             row: spec.row,
             column: spec.columnIndex,
             label: spec.label,
             aisleIndex: spec.aisleIndex,
             zone: spec.defaultZone,
             seatType: spec.seatType,
           ),
       ],
       _aisles = [for (final aisle in layout.aisles) _AisleRuntime(aisle)] {
    if (initialZones?.length == seats.length) {
      for (var index = 0; index < seats.length; index++) {
        final zone = initialZones![index];
        if (zone >= 0 && zone < layout.zoneCount) seats[index].zone = zone;
      }
    }
  }

  // Time each blocking passenger needs to stand up and resit.
  static const double _shuffleStandSeconds = 0.35;
  static const double _shuffleResitSeconds = 0.30;

  final AircraftLayout layout;
  final double luggageStowSeconds;
  final int? shuffleSeed;
  final List<BoardingSeat> seats;
  final List<_AisleRuntime> _aisles;
  final List<BoardingPassenger> seatedPassengers = [];

  // Tracks which passenger occupies each (row, column) slot after seating.
  final Map<String, BoardingPassenger> _occupiedSlots = {};

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

  bool assignZone(BoardingSeat seat, int zone) {
    if (isBoarding ||
        zone < 0 ||
        zone >= layout.zoneCount ||
        seat.zone == zone) {
      return false;
    }
    seat.zone = zone;
    return true;
  }

  void start() {
    if (isBoarding) return;
    isBoarding = true;
    boardedCount = 0;
    elapsedSeconds = 0;
    seatedPassengers.clear();
    _occupiedSlots.clear();
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
    _occupiedSlots.clear();
    for (final aisle in _aisles) {
      aisle.passengers.clear();
      aisle.manifest.clear();
      aisle.manifestIndex = 0;
      aisle.entryClock = 0;
    }
  }

  void resetToDefaultZones() {
    reset();
    for (final seat in seats) {
      seat.zone = layout.zoneCount - 1;
    }
  }

  void update(double dt) {
    if (!isBoarding || isComplete) return;
    final delta = math.min(dt, 0.08);
    elapsedSeconds += delta;

    // Advance shuffle animations on all seated passengers.
    for (final p in seatedPassengers) {
      if (p.isShuffling) {
        p.shuffleProgress = math.min(1, p.shuffleProgress + delta / ((_shuffleStandSeconds + _shuffleResitSeconds)));
      }
    }

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
              _transitionToSeatedOrShuffle(passenger, aisle, seatedThisFrame);
            }
          case PassengerPhase.shuffleWait:
            passenger.shuffleWaitRemaining -= delta;
            if (passenger.shuffleWaitRemaining <= 0) {
              _finallySeated(passenger, seatedThisFrame);
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

  void _transitionToSeatedOrShuffle(
    BoardingPassenger passenger,
    _AisleRuntime aisle,
    List<BoardingPassenger> seatedThisFrame,
  ) {
    final blockers = _findBlockers(passenger.seat);
    if (blockers.isEmpty) {
      _finallySeated(passenger, seatedThisFrame);
      return;
    }
    // Shuffle penalty: each blocker must stand, let them past, then resit.
    final waitTime = blockers.length * (_shuffleStandSeconds + _shuffleResitSeconds);
    passenger.phase = PassengerPhase.shuffleWait;
    passenger.shuffleWaitRemaining = waitTime;
    for (final blocker in blockers) {
      blocker.isShuffling = true;
      blocker.shuffleProgress = 0;
    }
  }

  void _finallySeated(
    BoardingPassenger passenger,
    List<BoardingPassenger> seatedThisFrame,
  ) {
    // Reset any blockers that were shuffling for this passenger.
    final blockers = _findBlockers(passenger.seat);
    for (final b in blockers) {
      b.isShuffling = false;
      b.shuffleProgress = 0;
    }
    passenger.phase = PassengerPhase.seated;
    _occupiedSlots['${passenger.seat.row},${passenger.seat.column}'] = passenger;
    seatedThisFrame.add(passenger);
  }

  /// Returns already-seated passengers in the same row who are inner than [seat].
  /// A window seat is blocked by aisle and middle.
  /// A middle seat is blocked by aisle only.
  List<BoardingPassenger> _findBlockers(BoardingSeat seat) {
    if (seat.seatType == SeatType.aisle) return [];
    final blockers = <BoardingPassenger>[];
    final seatsPerRow = layout.seatsPerRow;
    final rowStart = seat.row * seatsPerRow;
    for (var col = 0; col < seatsPerRow; col++) {
      final other = seats[rowStart + col];
      if (other.column == seat.column) continue;
      if (other.aisleIndex != seat.aisleIndex) continue;
      final isInnerThan = _isInnerThan(other.seatType, seat.seatType);
      if (!isInnerThan) continue;
      final occupant = _occupiedSlots['${other.row},${other.column}'];
      if (occupant != null && occupant.phase == PassengerPhase.seated) {
        blockers.add(occupant);
      }
    }
    return blockers;
  }

  /// Returns true if [candidateType] is closer to the aisle than [targetType].
  bool _isInnerThan(SeatType candidateType, SeatType targetType) {
    const order = [SeatType.aisle, SeatType.middle, SeatType.window];
    return order.indexOf(candidateType) < order.indexOf(targetType);
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
