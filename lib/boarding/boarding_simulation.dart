import 'dart:math' as math;

import 'aircraft_layout.dart';
import 'levels/level_4abreast.dart';

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

  // The seat this blocker is serving — set when exitingToAisle begins.
  // Used to chain the next blocker and trigger return without searching the aisle list.
  BoardingSeat? shuffleTargetSeat;

  // For shuffleWait incoming passenger: 0→1 slide from aisle to seat.
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
    this.layout = Level4Abreast.aircraft,
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
        // Still waiting for the inner passenger to slide in, OR for a chained
        // blocker ahead of us to finish exiting first — check both.
        final targetSeat = p.shuffleTargetSeat;
        if (targetSeat != null) {
          // Check if the inner passenger is still in the aisle (shuffleWait).
          final innerStillWaiting = _aisles.any((aisle) => aisle.passengers.any(
            (q) => q.seat == targetSeat && q.phase == PassengerPhase.shuffleWait,
          ));
          // Check if a later blocker in the chain is still exiting.
          final chainPending = seatedPassengers.any(
            (q) => q != p &&
                   q.seat.row == p.seat.row &&
                   q.seat.aisleIndex == p.seat.aisleIndex &&
                   q.shufflePhase == ShufflePhase.exitingToAisle,
          );
          if (!innerStillWaiting && !chainPending) {
            // Inner is seated and chain is done — start returning (innermost first).
            _startNextBlockerReturnForRow(p.seat.row, p.seat.aisleIndex);
            // If _startNextBlockerReturn didn't pick us (already picked an inner one),
            // we'll be triggered when that inner one finishes. If it did pick us, good.
          }
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
        blocker.shufflePhase = ShufflePhase.waitingInAisle;
        blocker.shufflePhaseProgress = 0;
        // Chain the next blocker (one step further from aisle) to start exiting.
        if (blocker.shuffleTargetSeat != null) {
          _startNextBlockerExit(blocker.shuffleTargetSeat!);
        }
      case ShufflePhase.returningToSeat:
        blocker.shufflePhase = ShufflePhase.none;
        blocker.shufflePhaseProgress = 0;
        blocker.shuffleTargetSeat = null;
        // Chain the next blocker (one step closer to window) to start returning.
        // _startNextBlockerReturn finds the next waitingInAisle blocker for the same row.
        _startNextBlockerReturnForRow(blocker.seat.row, blocker.seat.aisleIndex);
      case ShufflePhase.waitingInAisle:
      case ShufflePhase.none:
        break;
    }
  }

  /// Starts the next still-idle blocker exiting for [targetSeat], aisle-first order.
  /// Skips blockers already in motion. Sets shuffleTargetSeat on the started blocker.
  void _startNextBlockerExit(BoardingSeat targetSeat) {
    final blockerLabels = layout.blockerRules[layout.seatColumns[targetSeat.column].label] ?? [];
    for (final label in blockerLabels) {
      for (var col = 0; col < layout.seatColumns.length; col++) {
        if (layout.seatColumns[col].label != label) continue;
        final occupant = _occupiedSlots['${targetSeat.row},$col'];
        if (occupant == null) continue;
        if (occupant.shufflePhase == ShufflePhase.none &&
            occupant.phase == PassengerPhase.seated) {
          occupant.shufflePhase = ShufflePhase.exitingToAisle;
          occupant.shufflePhaseProgress = 0;
          occupant.shuffleTargetSeat = targetSeat;
          return;
        }
      }
    }
  }

  /// Starts the innermost waitingInAisle blocker returning for [row]/[aisleIndex],
  /// in reverse blocker-label order (window-side first, then toward aisle).
  void _startNextBlockerReturnForRow(int row, int aisleIndex) {
    // Find any seated passenger in this row that has waitingInAisle blockers.
    for (final p in seatedPassengers) {
      if (p.seat.row != row || p.seat.aisleIndex != aisleIndex) continue;
      final blockerLabels = layout.blockerRules[layout.seatColumns[p.seat.column].label] ?? [];
      for (final label in blockerLabels.reversed) {
        for (var col = 0; col < layout.seatColumns.length; col++) {
          if (layout.seatColumns[col].label != label) continue;
          final occupant = _occupiedSlots['$row,$col'];
          if (occupant == null) continue;
          if (occupant.shufflePhase == ShufflePhase.waitingInAisle) {
            occupant.shufflePhase = ShufflePhase.returningToSeat;
            occupant.shufflePhaseProgress = 0;
            return;
          }
        }
      }
    }
  }

  /// Row that blocks walking passengers behind it.
  /// Holds until the shuffling passenger is done AND all their blockers are back seated.
  double _aisleBlockRow(_AisleRuntime aisle) {
    for (final p in aisle.passengers) {
      if (p.phase == PassengerPhase.shuffleWait ||
          p.phase == PassengerPhase.seatSliding) {
        return p.rowPosition;
      }
    }
    // Also block while blockers for a recently-seated passenger are still shuffling.
    for (final p in seatedPassengers) {
      if (p.shufflePhase != ShufflePhase.none &&
          p.seat.aisleIndex == _aisles.indexOf(aisle)) {
        return p.seat.row.toDouble();
      }
    }
    return double.infinity;
  }

  /// True when every blocker for [seat] has fully exited to the aisle
  void _transitionToSeatedOrShuffle(
    BoardingPassenger passenger,
    List<BoardingPassenger> seatedThisFrame,
  ) {
    final blockers = _findActiveBlockers(passenger.seat);
    if (blockers.isEmpty) {
      passenger.phase = PassengerPhase.seatSliding;
      passenger.seatSlideProgress = 0;
      return;
    }
    passenger.phase = PassengerPhase.shuffleWait;
    passenger.shuffleWaitRemaining = 0;
    // Start only the first (aisle-side) blocker — it chains the rest sequentially.
    _startNextBlockerExit(passenger.seat);
  }

  void _finallySeated(
    BoardingPassenger passenger,
    List<BoardingPassenger> seatedThisFrame,
  ) {
    passenger.phase = PassengerPhase.seated;
    _occupiedSlots['${passenger.seat.row},${passenger.seat.column}'] = passenger;
    seatedThisFrame.add(passenger);
    // Trigger innermost waiting blocker to start returning (chains outward).
    _startNextBlockerReturnForRow(passenger.seat.row, passenger.seat.aisleIndex);
  }

  /// True only when ALL blockers for [seat] are in waitingInAisle (none still exiting,
  /// none still idle-but-pending). With sequential exit, this means every blocker
  /// in the chain has finished exiting.
  bool _allBlockersFullyInAisle(BoardingSeat seat) {
    final blockerLabels = layout.blockerRules[layout.seatColumns[seat.column].label] ?? [];
    if (blockerLabels.isEmpty) return true;
    for (final label in blockerLabels) {
      for (var col = 0; col < layout.seatColumns.length; col++) {
        if (layout.seatColumns[col].label != label) continue;
        final occupant = _occupiedSlots['${seat.row},$col'];
        if (occupant == null) continue;
        // Any blocker not yet in waitingInAisle means we're not ready.
        if (occupant.shufflePhase != ShufflePhase.waitingInAisle) return false;
      }
    }
    return true;
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
