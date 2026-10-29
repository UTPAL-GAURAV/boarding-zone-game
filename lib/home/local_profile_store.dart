import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'aircraft.dart';

class PlayerProfile {
  const PlayerProfile({required this.internalId, required this.displayName});

  final String internalId;
  final String displayName;

  PlayerProfile copyWith({String? displayName}) => PlayerProfile(
    internalId: internalId,
    displayName: displayName ?? this.displayName,
  );
}

class AircraftProgressRecord {
  const AircraftProgressRecord({
    required this.aircraftId,
    required this.unlocked,
    required this.premiumOwned,
    this.bestTimeSeconds,
  });

  final String aircraftId;
  final int? bestTimeSeconds;
  final bool unlocked;
  final bool premiumOwned;

  AircraftProgressRecord copyWith({
    int? bestTimeSeconds,
    bool? unlocked,
    bool? premiumOwned,
  }) => AircraftProgressRecord(
    aircraftId: aircraftId,
    bestTimeSeconds: bestTimeSeconds ?? this.bestTimeSeconds,
    unlocked: unlocked ?? this.unlocked,
    premiumOwned: premiumOwned ?? this.premiumOwned,
  );

  Map<String, Object?> toJson() => {
    'aircraftId': aircraftId,
    'bestTimeSeconds': bestTimeSeconds,
    'unlocked': unlocked,
    'premiumOwned': premiumOwned,
  };

  factory AircraftProgressRecord.fromJson(Map<String, dynamic> json) =>
      AircraftProgressRecord(
        aircraftId: json['aircraftId'] as String,
        bestTimeSeconds: json['bestTimeSeconds'] as int?,
        unlocked: json['unlocked'] as bool? ?? false,
        premiumOwned: json['premiumOwned'] as bool? ?? false,
      );
}

/// Offline profile and personal-best storage. No identity or score is sent online.
class LocalProfileStore {
  LocalProfileStore({SharedPreferences? preferences})
    : _providedPreferences = preferences;

  final SharedPreferences? _providedPreferences;
  static const _playerIdKey = 'player.internal_id';
  static const _displayNameKey = 'player.display_name';
  static const _bestPrefix = 'aircraft.best_seconds.';
  static const _fleetProgressKey = 'fleet.aircraft_progress.v1';
  static const _crewNames = [
    'Falcon',
    'Skyhawk',
    'Comet',
    'Orion',
    'Jetstream',
    'Bluebird',
  ];
  static final Random _random = Random.secure();

  Future<SharedPreferences> get _preferences async =>
      _providedPreferences ?? SharedPreferences.getInstance();

  Future<PlayerProfile> loadProfile() async {
    final preferences = await _preferences;
    var playerId = preferences.getString(_playerIdKey);
    if (playerId == null || playerId.isEmpty) {
      playerId = _newUuid();
      await preferences.setString(_playerIdKey, playerId);
    }
    var name = preferences.getString(_displayNameKey);
    if (name == null || name.trim().isEmpty) {
      name =
          'Crew ${_crewNames[_random.nextInt(_crewNames.length)]}'
          '${1000 + _random.nextInt(9000)}';
      await preferences.setString(_displayNameKey, name);
    } else if (name.startsWith('Pilot ')) {
      name = 'Crew${name.substring('Pilot'.length)}';
      await preferences.setString(_displayNameKey, name);
    }
    return PlayerProfile(internalId: playerId, displayName: name);
  }

  Future<void> saveDisplayName(String name) async {
    await (await _preferences).setString(_displayNameKey, name.trim());
  }

  Future<int?> bestTimeSeconds(String aircraftId) async =>
      (await _preferences).getInt('$_bestPrefix$aircraftId');

  Future<void> saveBestTime(String aircraftId, int seconds) async {
    final preferences = await _preferences;
    final previous = preferences.getInt('$_bestPrefix$aircraftId');
    if (previous == null || seconds < previous) {
      await preferences.setInt('$_bestPrefix$aircraftId', seconds);
      final progress = await loadFleetProgress(AircraftCatalog.all);
      final record = progress[aircraftId];
      if (record != null) {
        progress[aircraftId] = record.copyWith(bestTimeSeconds: seconds);
        await _saveFleetProgress(progress.values);
      }
    }
  }

  /// Loads the offline per-aircraft state, migrating older best-time keys.
  Future<Map<String, AircraftProgressRecord>> loadFleetProgress(
    List<Aircraft> fleet,
  ) async {
    final preferences = await _preferences;
    final saved = <String, AircraftProgressRecord>{};
    final raw = preferences.getString(_fleetProgressKey);
    if (raw != null) {
      try {
        final entries = jsonDecode(raw) as List<dynamic>;
        for (final entry in entries) {
          final record = AircraftProgressRecord.fromJson(
            entry as Map<String, dynamic>,
          );
          saved[record.aircraftId] = record;
        }
      } on FormatException {
        // Rebuild a valid snapshot from supported legacy best-time keys.
      }
    }

    final progress = <String, AircraftProgressRecord>{};
    for (final aircraft in fleet) {
      final oldRecord = saved[aircraft.id];
      final legacyBest = preferences.getInt('$_bestPrefix${aircraft.id}');
      final best = oldRecord?.bestTimeSeconds ?? legacyBest;
      final premiumOwned = oldRecord?.premiumOwned ?? false;
      progress[aircraft.id] = AircraftProgressRecord(
        aircraftId: aircraft.id,
        bestTimeSeconds: best,
        unlocked:
            oldRecord?.unlocked == true ||
            aircraft.unlockType == AircraftUnlockType.free ||
            premiumOwned,
        premiumOwned: premiumOwned,
      );
    }

    // One-time migration: qualifying legacy scores become permanent unlocks.
    for (var index = 1; index < fleet.length; index++) {
      final aircraft = fleet[index];
      if (aircraft.unlockType != AircraftUnlockType.progression) continue;
      var previousIndex = index - 1;
      while (previousIndex > 0 &&
          fleet[previousIndex].unlockType == AircraftUnlockType.premium) {
        previousIndex--;
      }
      final previous = fleet[previousIndex];
      final previousProgress = progress[previous.id]!;
      if (previousProgress.unlocked &&
          previousProgress.bestTimeSeconds != null &&
          previousProgress.bestTimeSeconds! < previous.targetSeconds) {
        progress[aircraft.id] = progress[aircraft.id]!.copyWith(unlocked: true);
      }
    }

    await _saveFleetProgress(progress.values);
    return progress;
  }

  /// Records a run and permanently unlocks the next progression aircraft when
  /// the best time meets this aircraft's target.
  Future<Map<String, AircraftProgressRecord>> recordBoardingCompletion({
    required String aircraftId,
    required int seconds,
    required List<Aircraft> fleet,
  }) async {
    final progress = await loadFleetProgress(fleet);
    final aircraft = fleet.firstWhere((item) => item.id == aircraftId);
    final record = progress[aircraftId]!;
    final best =
        record.bestTimeSeconds == null || seconds < record.bestTimeSeconds!
        ? seconds
        : record.bestTimeSeconds!;
    progress[aircraftId] = record.copyWith(bestTimeSeconds: best);
    final index = fleet.indexOf(aircraft);
    if (best < aircraft.targetSeconds) {
      final nextIndex = _nextProgressionIndex(fleet, index + 1);
      if (nextIndex != null) {
        final next = fleet[nextIndex];
        progress[next.id] = progress[next.id]!.copyWith(unlocked: true);
      }
    }

    final preferences = await _preferences;
    await preferences.setInt('$_bestPrefix$aircraftId', best);
    await _saveFleetProgress(progress.values);
    return progress;
  }

  /// Called after a successful store purchase; this does not process payment.
  Future<Map<String, AircraftProgressRecord>> grantPremiumOwnership({
    required String aircraftId,
    required List<Aircraft> fleet,
  }) async {
    final aircraft = fleet.firstWhere((item) => item.id == aircraftId);
    if (aircraft.unlockType != AircraftUnlockType.premium) {
      throw ArgumentError.value(aircraftId, 'aircraftId', 'Not premium');
    }
    final progress = await loadFleetProgress(fleet);
    progress[aircraftId] = progress[aircraftId]!.copyWith(
      unlocked: true,
      premiumOwned: true,
    );
    await _saveFleetProgress(progress.values);
    return progress;
  }

  int? _nextProgressionIndex(List<Aircraft> fleet, int start) {
    for (var index = start; index < fleet.length; index++) {
      if (fleet[index].unlockType == AircraftUnlockType.progression) {
        return index;
      }
    }
    return null;
  }

  Future<void> _saveFleetProgress(
    Iterable<AircraftProgressRecord> records,
  ) async {
    await (await _preferences).setString(
      _fleetProgressKey,
      jsonEncode(records.map((record) => record.toJson()).toList()),
    );
  }

  static String _newUuid() {
    String hex(int count) => List.generate(
      count,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();

    final variant = (8 + _random.nextInt(4)).toRadixString(16);
    return '${hex(8)}-${hex(4)}-4${hex(3)}-$variant${hex(3)}-${hex(12)}';
  }
}
