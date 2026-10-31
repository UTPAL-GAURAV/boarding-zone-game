import 'dart:math' as math;

import 'aircraft_layout.dart';
import 'levels/level_one.dart';

enum PassengerPhase { walking, turning, stowing, seatSliding, shuffleWait, seated }

/// Serial shuffle steps for a blocker passenger:
///   none → exitingToAisle → waitingInAisle (held here until inner seated) → returningToSeat → none
enum ShufflePhase { none, exitingToAisle, waitingInAisle, returningToSeat }

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

  // Phased shuffle animation for blockers.
  ShufflePhase shufflePhase = ShufflePhase.none;
  double shufflePhaseProgress = 0; // 0→1 within current sub-phase

  // For shuffleWait incoming passenger: 0→1 slide from aisle to seat.
  // Only starts once ALL blockers are fully stopped in the aisle (waitingInAisle,
  // progress=1). Blockers only start returning AFTER this reaches 1.
  double seatSlideProgress = 0;
}

class _AisleRuntime {
  _AisleRuntime(this.layout);

  final BoardingAisleLayout layout;
  final List<BoardingPassenger> manifest = [];
  final List<BoardingPassenger> passengers = [];
  int manifestIndex = 0;
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

  // Serial shuffle step durations.
  static const double _shuffleExitSeconds = 1.0;   // blocker walks out to aisle
  static const double _shuffleReturnSeconds = 1.0; // blocker walks back to seat
  static const double _seatSlideSeconds = 0.9;     // inner passenger slides to seat

  final AircraftLayout layout;
  final double luggageStowSeconds;
  final int? shuffleSeed;
  final List<BoardingSeat> seats;
  final List<_AisleRuntime> _aisles;
  final List<BoardingPassenger> seatedPassengers = [];

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

  bool get isComplete =>
      isBoarding &&
      boardedCount == passengerCount &&
      seatedPassengers.every((p) => p.shufflePhase == ShufflePhase.none);

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
        ..manifestIndex = 0;
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

    // Advance blocker animations.
    // exitingToAisle / returningToSeat advance on their own timer.
    // waitingInAisle is held until the incoming shuffleWait passenger seats —
    // BUT if nobody is waiting for this blocker (they seated before we arrived),
    // release the blocker immediately so it doesn't get stuck.
    for (final p in seatedPassengers) {
      if (p.shufflePhase == ShufflePhase.none) continue;
      if (p.shufflePhase == ShufflePhase.waitingInAisle) {
        // Check if any aisle passenger is still waiting for this blocker.
        final hasWaiter = _aisles.any((aisle) => aisle.passengers.any(
          (q) => q.phase == PassengerPhase.shuffleWait &&
                 _findWaitingBlockers(q.seat).contains(p),
        ));
        if (!hasWaiter) {
          // Nobody waiting — return immediately.
          p.shufflePhase = ShufflePhase.returningToSeat;
          p.shufflePhaseProgress = 0;
        }
        continue;
      }
      p.shufflePhaseProgress = math.min(
        1,
        p.shufflePhaseProgress + delta / _phaseDuration(p.shufflePhase),
      );
      if (p.shufflePhaseProgress >= 1) {
        _advanceBlockerPhase(p);
      }
    }

    for (final aisle in _aisles) {
      final blockRow = _aisleBlockRow(aisle);

      final seatedThisFrame = <BoardingPassenger>[];
      for (var index = 0; index < aisle.passengers.length; index++) {
        final passenger = aisle.passengers[index];
        passenger.animationTime += delta;
        switch (passenger.phase) {
          case PassengerPhase.walking:
            double prevLimit = double.infinity;
            if (index > 0) {
              final ahead = aisle.passengers[index - 1];
              // Block behind any non-seated passenger ahead — use their seat row
              // as the position once they've stopped walking (turning/stowing/sliding).
              final aheadPos = (ahead.phase == PassengerPhase.walking)
                  ? ahead.rowPosition
                  : ahead.seat.row.toDouble();
              prevLimit = aheadPos - aisle.layout.minimumSpacingRows;
            }
            final shuffleLimit = blockRow - aisle.layout.minimumSpacingRows;
            // Never push backwards — only cap forward progress.
            final cap = math.max(
              passenger.rowPosition,
              math.min(prevLimit, shuffleLimit),
            );
            passenger.rowPosition = math.min(
              passenger.seat.row.toDouble(),
              math.min(
                passenger.rowPosition +
                    delta * aisle.layout.walkingSpeedRowsPerSecond,
                cap,
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
              _transitionToSeatedOrShuffle(passenger, seatedThisFrame);
            }
          case PassengerPhase.seatSliding:
            // No blockers — slide directly from aisle to seat.
            passenger.seatSlideProgress = math.min(
              1,
              passenger.seatSlideProgress + delta / _seatSlideSeconds,
            );
            if (passenger.seatSlideProgress >= 1) {
              _finallySeated(passenger, seatedThisFrame);
            }
          case PassengerPhase.shuffleWait:
            // Only start sliding once every blocker has fully reached the aisle
            // (exitingToAisle progress == 1, i.e. now in waitingInAisle).
            if (_allBlockersFullyInAisle(passenger.seat)) {
              passenger.seatSlideProgress = math.min(
                1,
                passenger.seatSlideProgress + delta / _seatSlideSeconds,
              );
              if (passenger.seatSlideProgress >= 1) {
                _finallySeated(passenger, seatedThisFrame);
              }
            }
          case PassengerPhase.seated:
            break;
        }
      }
      if (seatedThisFrame.isNotEmpty) {
        aisle.passengers.removeWhere(seatedThisFrame.contains);
        seatedPassengers.addAll(seatedThisFrame);
        boardedCount += seatedThisFrame.length;
        if (isComplete) return;
      }
      while (_tryEnterNextPassenger(aisle)) {}
    }
  }

  double _phaseDuration(ShufflePhase phase) {
    switch (phase) {
      case ShufflePhase.exitingToAisle:
        return _shuffleExitSeconds;
      case ShufflePhase.waitingInAisle:
        return double.infinity; // held manually — never auto-advances
      case ShufflePhase.returningToSeat:
        return _shuffleReturnSeconds;
      case ShufflePhase.none:
        return 1;
    }
  }

  void _advanceBlockerPhase(BoardingPassenger blocker) {
    switch (blocker.shufflePhase) {
      case ShufflePhase.exitingToAisle:
        // Arrived at aisle — wait here until inner passenger has seated.
        blocker.shufflePhase = ShufflePhase.waitingInAisle;
        blocker.shufflePhaseProgress = 0;
      case ShufflePhase.returningToSeat:
        blocker.shufflePhase = ShufflePhase.none;
        blocker.shufflePhaseProgress = 0;
      case ShufflePhase.waitingInAisle:
      case ShufflePhase.none:
        break;
    }
  }

  /// Row of the nearest seatSliding/shuffleWait passenger — walking passengers stop before it.
  double _aisleBlockRow(_AisleRuntime aisle) {
    for (final p in aisle.passengers) {
      if (p.phase == PassengerPhase.shuffleWait ||
          p.phase == PassengerPhase.seatSliding) return p.rowPosition;
    }
    return double.infinity;
  }

  /// True when every blocker for [seat] has fully exited to the aisle
  /// (shufflePhase == waitingInAisle with progress reached 1, meaning they
  /// True when every blocker for [seat] has fully arrived and stopped in the aisle.
  bool _allBlockersFullyInAisle(BoardingSeat seat) {
    // Include blockers that are still exiting — they haven't stopped yet.
    final exiting = _findBlockersWhere(
      seat,
      (p) => p.shufflePhase == ShufflePhase.exitingToAisle,
    );
    if (exiting.isNotEmpty) return false;
    // Also check at least one is actually waiting (not all done and gone).
    final waiting = _findWaitingBlockers(seat);
    return waiting.isNotEmpty || _findActiveBlockers(seat).isEmpty;
  }

  void _transitionToSeatedOrShuffle(
    BoardingPassenger passenger,
    List<BoardingPassenger> seatedThisFrame,
  ) {
    final blockers = _findActiveBlockers(passenger.seat);
    if (blockers.isEmpty) {
      // No blockers — slide directly to seat.
      passenger.phase = PassengerPhase.seatSliding;
      passenger.seatSlideProgress = 0;
      return;
    }
    passenger.phase = PassengerPhase.shuffleWait;
    passenger.shuffleWaitRemaining = 0;
    for (final blocker in blockers) {
      if (blocker.shufflePhase == ShufflePhase.none) {
        blocker.shufflePhase = ShufflePhase.exitingToAisle;
        blocker.shufflePhaseProgress = 0;
      }
    }
  }

  void _finallySeated(
    BoardingPassenger passenger,
    List<BoardingPassenger> seatedThisFrame,
  ) {
    passenger.phase = PassengerPhase.seated;
    _occupiedSlots['${passenger.seat.row},${passenger.seat.column}'] = passenger;
    seatedThisFrame.add(passenger);
    // Inner passenger is now fully seated — tell blockers to return.
    // Use _findAllBlockers here (includes those in waitingInAisle).
    final blockers = _findWaitingBlockers(passenger.seat);
    for (final b in blockers) {
      if (b.shufflePhase == ShufflePhase.waitingInAisle) {
        b.shufflePhase = ShufflePhase.returningToSeat;
        b.shufflePhaseProgress = 0;
      }
    }
  }

  /// Blockers that are seated and idle — eligible to be asked to stand.
  List<BoardingPassenger> _findActiveBlockers(BoardingSeat seat) {
    return _findBlockersWhere(
      seat,
      (p) => p.phase == PassengerPhase.seated && p.shufflePhase == ShufflePhase.none,
    );
  }

  /// Blockers currently standing in the aisle waiting to return.
  List<BoardingPassenger> _findWaitingBlockers(BoardingSeat seat) {
    return _findBlockersWhere(
      seat,
      (p) => p.shufflePhase == ShufflePhase.waitingInAisle,
    );
  }

  /// Look up blocker labels from the hardcoded layout rule, then find
  /// the matching seated passengers in this row.
  List<BoardingPassenger> _findBlockersWhere(
    BoardingSeat seat,
    bool Function(BoardingPassenger) test,
  ) {
    final seatLabel = layout.seatColumns[seat.column].label;
    final blockerLabels = layout.blockerRules[seatLabel] ?? [];
    if (blockerLabels.isEmpty) return [];

    final blockers = <BoardingPassenger>[];
    for (var col = 0; col < layout.seatColumns.length; col++) {
      if (!blockerLabels.contains(layout.seatColumns[col].label)) continue;
      final occupant = _occupiedSlots['${seat.row},$col'];
      if (occupant != null && test(occupant)) blockers.add(occupant);
    }
    return blockers;
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
