import '../boarding/aircraft_layout.dart';

enum AircraftUnlockType { free, progression, premium }

class Aircraft {
  const Aircraft({
    required this.id,
    required this.level,
    required this.manufacturer,
    required this.model,
    required this.description,
    required this.imageAsset,
    required this.typicalSeats,
    required this.unlockType,
    required this.targetSeconds,
    this.layout,
    this.unlockRequirement,
    this.priceLabel,
  });

  final String id;
  final int level;
  final String manufacturer;
  final String model;
  final String description;
  final String imageAsset;
  final int typicalSeats;
  final AircraftUnlockType unlockType;
  final int targetSeconds;

  /// The game layout for this aircraft. Null for coming-soon aircraft.
  final AircraftLayout? layout;

  final String? unlockRequirement;
  final String? priceLabel;

  String get displayName => '$manufacturer $model';
  String get subtitle => description;

  /// Passenger count from the layout if available, otherwise typicalSeats.
  int get passengerCount => layout?.passengerCount ?? typicalSeats;
}

/// Source-authored aircraft catalog. Call [register] once at app startup.
abstract final class AircraftCatalog {
  static List<Aircraft> all = [];

  static void register(List<Aircraft> fleet) {
    _validate(fleet);
    all = fleet;
  }

  static Aircraft byId(String id) =>
      all.firstWhere((aircraft) => aircraft.id == id);

  static void _validate(List<Aircraft> aircraft) {
    if (aircraft.isEmpty) throw const FormatException('Fleet catalog is empty');
    final ids = <String>{};
    for (var index = 0; index < aircraft.length; index++) {
      final item = aircraft[index];
      if (!ids.add(item.id)) {
        throw FormatException('Duplicate aircraft id: ${item.id}');
      }
      if (item.typicalSeats < 10) {
        throw FormatException('${item.displayName} has fewer than 10 seats');
      }
      if (index > 0 && aircraft[index - 1].typicalSeats > item.typicalSeats) {
        throw FormatException('Fleet is not ordered by typical seat count');
      }
      final layout = item.layout;
      if (layout != null) {
        if (layout.rowCount < 1 ||
            layout.seatColumns.isEmpty ||
            layout.aisles.isEmpty) {
          throw FormatException('Invalid layout data for ${item.displayName}');
        }
      }
    }
  }
}
