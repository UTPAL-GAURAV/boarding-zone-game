import 'dart:convert';

import 'package:flutter/services.dart';

enum AircraftUnlockType { free, progression, premium }

class CabinLayoutData {
  const CabinLayoutData({
    required this.rows,
    required this.seatBlocks,
    required this.aisleCount,
    required this.aisleCapacity,
  });

  final int rows;

  /// Seat columns in each block, listed from left to right.
  final List<int> seatBlocks;
  final int aisleCount;

  /// Maximum passengers occupying the walking aisle, for level tuning.
  final int aisleCapacity;

  factory CabinLayoutData.fromJson(Map<String, dynamic> json) =>
      CabinLayoutData(
        rows: json['rows'] as int,
        seatBlocks: (json['seatBlocks'] as List).cast<int>(),
        aisleCount: json['aisleCount'] as int,
        aisleCapacity: json['aisleCapacity'] as int,
      );
}

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
    required this.cabin,
    this.unlockRequirement,
    this.priceLabel,
    this.gameLayoutId,
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
  final CabinLayoutData cabin;
  final String? unlockRequirement;
  final String? priceLabel;

  /// Stable key resolved by the boarding-level registry.
  final String? gameLayoutId;

  String get displayName => '$manufacturer $model';
  String get subtitle => description;

  factory Aircraft.fromJson(Map<String, dynamic> json) {
    final unlock = AircraftUnlockType.values.firstWhere(
      (value) => value.name == json['unlockType'],
      orElse: () => throw FormatException(
        'Unknown unlockType for aircraft ${json['id']}',
      ),
    );
    return Aircraft(
      id: json['id'] as String,
      level: json['level'] as int,
      manufacturer: json['manufacturer'] as String,
      model: json['model'] as String,
      description: json['description'] as String,
      imageAsset: json['imageAsset'] as String,
      typicalSeats: json['typicalSeats'] as int,
      unlockType: unlock,
      targetSeconds: json['targetSeconds'] as int,
      cabin: CabinLayoutData.fromJson(json['cabin'] as Map<String, dynamic>),
      unlockRequirement: json['unlockRequirement'] as String?,
      priceLabel: json['priceLabel'] as String?,
      gameLayoutId: json['gameLayoutId'] as String?,
    );
  }
}

/// Reads the bundled, source-authored aircraft catalog once at app startup.
abstract final class AircraftCatalog {
  static List<Aircraft> all = const [];

  static Future<void> load() async {
    if (all.isNotEmpty) return;
    final decoded = jsonDecode(
      await rootBundle.loadString('assets/data/aircraft_fleet.json'),
    ) as List<dynamic>;
    final aircraft = decoded
        .map((entry) => Aircraft.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
    _validate(aircraft);
    all = aircraft;
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
      if (item.cabin.rows < 1 ||
          item.cabin.seatBlocks.isEmpty ||
          item.cabin.aisleCount < 1 ||
          item.cabin.aisleCapacity < 1) {
        throw FormatException('Invalid cabin data for ${item.displayName}');
      }
    }
  }
}
