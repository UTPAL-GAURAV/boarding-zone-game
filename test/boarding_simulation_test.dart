import 'package:flutter_test/flutter_test.dart';

import 'package:boarding_zone_game/boarding/boarding_simulation.dart';

void main() {
  group('BoardingSimulation', () {
    test('builds seats from the hard-coded aircraft level', () {
      final simulation = BoardingSimulation();
      expect(simulation.layout.rowCount, 12);
      expect(simulation.seats, hasLength(48));

      final seat = simulation.seats.first;
      expect(seat.zone, 0);
      for (var zone = 1; zone < simulation.layout.zoneCount; zone++) {
        simulation.cycleZone(seat);
        expect(seat.zone, zone);
      }
      simulation.cycleZone(seat);
      expect(seat.zone, 0);
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
      expect(simulation.currentEntryZone, 0);

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
