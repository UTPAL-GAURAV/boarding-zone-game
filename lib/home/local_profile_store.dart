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
    this.bestTimeMilliseconds,
  });

  final String aircraftId;
  final int? bestTimeMilliseconds;
  final bool unlocked;
  final bool premiumOwned;

  AircraftProgressRecord copyWith({
    int? bestTimeMilliseconds,
    bool? unlocked,
    bool? premiumOwned,
  }) => AircraftProgressRecord(
    aircraftId: aircraftId,
    bestTimeMilliseconds: bestTimeMilliseconds ?? this.bestTimeMilliseconds,
    unlocked: unlocked ?? this.unlocked,
    premiumOwned: premiumOwned ?? this.premiumOwned,
  );

  Map<String, Object?> toJson() => {
    'aircraftId': aircraftId,
    'bestTimeMilliseconds': bestTimeMilliseconds,
    'unlocked': unlocked,
    'premiumOwned': premiumOwned,
  };

  factory AircraftProgressRecord.fromJson(Map<String, dynamic> json) =>
      AircraftProgressRecord(
        aircraftId: json['aircraftId'] as String,
        bestTimeMilliseconds:
            (json['bestTimeMilliseconds'] as int?) ??
            ((json['bestTimeSeconds'] as int?) == null
                ? null
                : (json['bestTimeSeconds'] as int) * 1000),
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
  static const _bestPrefix = 'aircraft.best_milliseconds.';
  static const _legacyBestPrefix = 'aircraft.best_seconds.';
  static const _seatZonesPrefix = 'aircraft.seat_zones.v1.';
  static const _fleetProgressKey = 'fleet.aircraft_progress.v1';
  static const _soundEnabledKey = 'settings.sound_enabled';
  static const _tutorialCompletedKey = 'player.tutorial_completed';
  static const _crewNames = [
    'Falcon',
    'Skyhawk',
    'Comet',
    'Orion',
    'Bluebird',
    'Jetstar',
    'Nimbus',
    'Zephyr',
    'Stratos',
    'Vortex',
    'Cirrus',
    'Altair',
    'Solaris',
    'Tempest',
    'Quasar',
    'Aether',
    'Boreal',
    'Cygnus',
    'Dawnjet',
    'Equinox',
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
          '${_crewNames[_random.nextInt(_crewNames.length)]}'
          '${100 + _random.nextInt(900)}';
      await preferences.setString(_displayNameKey, name);
    }
    return PlayerProfile(internalId: playerId, displayName: name);
  }

  Future<void> saveDisplayName(String name) async {
    await (await _preferences).setString(_displayNameKey, name.trim());
  }

  Future<bool> loadSoundEnabled() async {
    return (await _preferences).getBool(_soundEnabledKey) ?? true;
  }

  Future<void> saveSoundEnabled(bool value) async {
    await (await _preferences).setBool(_soundEnabledKey, value);
  }

  Future<bool> isTutorialCompleted() async {
    return (await _preferences).getBool(_tutorialCompletedKey) ?? false;
  }

  Future<void> setTutorialCompleted() async {
    await (await _preferences).setBool(_tutorialCompletedKey, true);
  }

  Future<int?> bestTimeMilliseconds(String aircraftId) async {
    final preferences = await _preferences;
    final stored = preferences.getInt('$_bestPrefix$aircraftId');
    if (stored != null) return stored;
    final legacySeconds = preferences.getInt('$_legacyBestPrefix$aircraftId');
    return legacySeconds == null ? null : legacySeconds * 1000;
  }

  Future<void> saveBestTime(String aircraftId, int milliseconds) async {
    final preferences = await _preferences;
    final previous = await bestTimeMilliseconds(aircraftId);
    if (previous == null || milliseconds < previous) {
      await preferences.setInt('$_bestPrefix$aircraftId', milliseconds);
      final progress = await loadFleetProgress(AircraftCatalog.all);
      final record = progress[aircraftId];
      if (record != null) {
        progress[aircraftId] = record.copyWith(
          bestTimeMilliseconds: milliseconds,
        );
        await _saveFleetProgress(progress.values);
      }
    }
  }

  Future<List<int>?> loadSeatZones(
    String aircraftId, {
    required int seatCount,
    required int zoneCount,
  }) async {
    final raw = (await _preferences).getString('$_seatZonesPrefix$aircraftId');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      if (decoded.length != seatCount ||
          decoded.any((value) => value is! int)) {
        return null;
      }
      final zones = decoded.cast<int>();
      if (zones.any((zone) => zone < 0 || zone >= zoneCount)) return null;
      return zones;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> saveSeatZones(String aircraftId, List<int> zones) async {
    await (await _preferences).setString(
      '$_seatZonesPrefix$aircraftId',
      jsonEncode(zones),
    );
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
      final legacyMilliseconds = preferences.getInt(
        '$_bestPrefix${aircraft.id}',
      );
      final legacySeconds = preferences.getInt(
        '$_legacyBestPrefix${aircraft.id}',
      );
      final best =
          oldRecord?.bestTimeMilliseconds ??
          legacyMilliseconds ??
          (legacySeconds == null ? null : legacySeconds * 1000);
      final premiumOwned = oldRecord?.premiumOwned ?? false;
      progress[aircraft.id] = AircraftProgressRecord(
        aircraftId: aircraft.id,
        bestTimeMilliseconds: best,
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
          previousProgress.bestTimeMilliseconds != null &&
          previousProgress.bestTimeMilliseconds! <
              previous.targetSeconds * 1000) {
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
    required int milliseconds,
    required List<Aircraft> fleet,
  }) async {
    final progress = await loadFleetProgress(fleet);
    final aircraft = fleet.firstWhere((item) => item.id == aircraftId);
    final record = progress[aircraftId]!;
    final best =
        record.bestTimeMilliseconds == null ||
            milliseconds < record.bestTimeMilliseconds!
        ? milliseconds
        : record.bestTimeMilliseconds!;
    progress[aircraftId] = record.copyWith(bestTimeMilliseconds: best);
    final index = fleet.indexOf(aircraft);
    if (best < aircraft.targetSeconds * 1000) {
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
