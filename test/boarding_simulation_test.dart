import 'package:flutter_test/flutter_test.dart';

import 'package:boarding_bluster/boarding/boarding_simulation.dart';

void main() {
  group('BoardingSimulation', () {
    test('builds seats from the hard-coded aircraft level', () {
      final simulation = BoardingSimulation();
      expect(simulation.layout.rowCount, 12);
      expect(simulation.seats, hasLength(48));
      expect(simulation.seats.every((seat) => seat.zone == 5), isTrue);

      final seat = simulation.seats.first;
      expect(seat.zone, 5);
      expect(simulation.layout.zoneCount, 6);
      for (var zone = 0; zone < simulation.layout.zoneCount; zone++) {
        expect(simulation.assignZone(seat, zone), isTrue);
        expect(seat.zone, zone);
      }
      expect(simulation.assignZone(seat, 6), isFalse);
      expect(simulation.assignZone(seat, 5), isFalse);
    });

    test('restores initial seat zones', () {
      final defaults = BoardingSimulation();
      final zones = defaults.seats.map((seat) => seat.zone).toList();
      zones[0] = 5;
      zones[1] = 4;
      final restored = BoardingSimulation(initialZones: zones);

      expect(restored.seats[0].zone, 5);
      expect(restored.seats[1].zone, 4);
    });

    test('reset restores every seat to Zone F', () {
      final simulation = BoardingSimulation();
      simulation.assignZone(simulation.seats.first, 2);
      simulation.start();

      simulation.resetToDefaultZones();

      expect(simulation.isBoarding, isFalse);
      expect(simulation.seats.every((seat) => seat.zone == 5), isTrue);
    });

    test(
      'randomizes seat order within each boarding zone deterministically',
      () {
        final simulation = BoardingSimulation(shuffleSeed: 17);
        final originalByZone = {
          for (var zone = 0; zone < simulation.layout.zoneCount; zone++)
            zone: simulation.seats.where((seat) => seat.zone == zone).toList(),
        };
        simulation.start();

        final order = simulation.boardingOrder;
        expect(
          order.map((seat) => seat.zone).toList(),
          orderedEquals(order.map((seat) => seat.zone).toList()..sort()),
        );
        for (var zone = 0; zone < simulation.layout.zoneCount; zone++) {
          if (originalByZone[zone]!.isEmpty) continue;
          final zoneOrder = order.where((seat) => seat.zone == zone).toList();
          expect(zoneOrder.toSet(), originalByZone[zone]!.toSet());
          expect(zoneOrder, isNot(orderedEquals(originalByZone[zone]!)));
        }
        expect(
          order.take(12).map((seat) => seat.row).toSet().length,
          greaterThan(1),
        );
        expect(simulation.aislePassengers, hasLength(1));
      },
    );

    test('uses aisle spacing while continuously boarding and lets followers advance', () {
      final simulation = BoardingSimulation(
        luggageStowSeconds: 0.2,
        shuffleSeed: 4,
      );
      simulation.start();
      expect(simulation.currentEntryZone, 5);

      var maxAisleOccupancy = simulation.aislePassengers.length;
      for (var frame = 0; frame < 30000 && !simulation.isComplete; frame++) {
        simulation.update(1 / 60);
        maxAisleOccupancy =
            maxAisleOccupancy > simulation.aislePassengers.length
            ? maxAisleOccupancy
            : simulation.aislePassengers.length;
        _expectAisleSpacing(simulation);
      }

      expect(simulation.isComplete, isTrue);
      expect(simulation.boardedCount, simulation.passengerCount);
      expect(simulation.seatedPassengers, hasLength(simulation.passengerCount));
      expect(simulation.aislePassengers, isEmpty);
      expect(maxAisleOccupancy, greaterThan(1));

      simulation.reset();
      expect(simulation.isBoarding, isFalse);
      expect(simulation.boardedCount, 0);
      expect(simulation.elapsedSeconds, 0);
      expect(simulation.aislePassengers, isEmpty);
      expect(simulation.seatedPassengers, isEmpty);
    });
  });
}

void _expectAisleSpacing(BoardingSimulation simulation) {
  final passengers = simulation.aislePassengers;
  for (var index = 1; index < passengers.length; index++) {
    final passengerAhead = passengers[index - 1];
    final passengerBehind = passengers[index];
    final aisle = simulation.layout.aisles[passengerAhead.seat.aisleIndex];
    expect(
      passengerAhead.rowPosition - passengerBehind.rowPosition,
      greaterThanOrEqualTo(aisle.minimumSpacingRows - 1e-9),
    );
  }
}
