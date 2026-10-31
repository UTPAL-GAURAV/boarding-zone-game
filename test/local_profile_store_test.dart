import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:boarding_bluster/home/aircraft.dart';
import 'package:boarding_bluster/home/local_profile_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists crew identity, display name, and best time locally', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalProfileStore();
    final first = await store.loadProfile();
    expect(first.internalId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(first.displayName, startsWith('Crew '));

    await store.saveDisplayName('Captain Nova');
    await store.saveBestTime('airbus-a320', 487000);
    await store.saveBestTime('airbus-a320', 512000);

    final restored = await store.loadProfile();
    expect(restored.internalId, first.internalId);
    expect(restored.displayName, 'Captain Nova');
    expect(await store.bestTimeMilliseconds('airbus-a320'), 487000);
  });

  test(
    'migrates legacy second scores into millisecond personal bests',
    () async {
      SharedPreferences.setMockInitialValues({
        'aircraft.best_seconds.cessna-grand-caravan-ex': 299,
      });
      final store = LocalProfileStore();
      await AircraftCatalog.load();
      final progress = await store.loadFleetProgress(AircraftCatalog.all);
      expect(
        await store.bestTimeMilliseconds(AircraftCatalog.all.first.id),
        299000,
      );
      expect(
        progress[AircraftCatalog.all.first.id]!.bestTimeMilliseconds,
        299000,
      );
      expect(progress[AircraftCatalog.all[1].id]!.unlocked, isTrue);
    },
  );

  test('persists per-aircraft seat boarding zones locally', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalProfileStore();
    const zones = [0, 1, 2, 3, 4, 5];
    await store.saveSeatZones('cessna-grand-caravan-ex', zones);

    expect(
      await store.loadSeatZones(
        'cessna-grand-caravan-ex',
        seatCount: zones.length,
        zoneCount: 6,
      ),
      zones,
    );
    expect(
      await store.loadSeatZones(
        'cessna-grand-caravan-ex',
        seatCount: zones.length + 1,
        zoneCount: 6,
      ),
      isNull,
    );
  });

  test(
    'migrates Pilot defaults without changing the internal player ID',
    () async {
      SharedPreferences.setMockInitialValues({
        'player.internal_id': 'stable-player-uuid',
        'player.display_name': 'Pilot Bluebird4322',
      });

      final profile = await LocalProfileStore().loadProfile();
      expect(profile.internalId, 'stable-player-uuid');
      expect(profile.displayName, 'Crew Bluebird4322');
    },
  );

  test(
    'persists best times, permanent unlocks, and premium ownership',
    () async {
      SharedPreferences.setMockInitialValues({});
      await AircraftCatalog.load();
      final fleet = AircraftCatalog.all;
      final store = LocalProfileStore();
      final first = fleet.first;
      final second = fleet[1];

      final initial = await store.loadFleetProgress(fleet);
      expect(initial[first.id]!.unlocked, isTrue);
      expect(initial[second.id]!.unlocked, isFalse);

      final afterQualifyingRun = await store.recordBoardingCompletion(
        aircraftId: first.id,
        milliseconds: first.targetSeconds * 1000 - 1,
        fleet: fleet,
      );
      expect(
        afterQualifyingRun[first.id]!.bestTimeMilliseconds,
        first.targetSeconds * 1000 - 1,
      );
      expect(afterQualifyingRun[second.id]!.unlocked, isTrue);

      final afterSlowerRun = await store.recordBoardingCompletion(
        aircraftId: first.id,
        milliseconds: (first.targetSeconds + 20) * 1000,
        fleet: fleet,
      );
      expect(
        afterSlowerRun[first.id]!.bestTimeMilliseconds,
        first.targetSeconds * 1000 - 1,
      );
      expect(afterSlowerRun[second.id]!.unlocked, isTrue);

      final premium = fleet.firstWhere(
        (aircraft) => aircraft.unlockType == AircraftUnlockType.premium,
      );
      final afterPurchase = await store.grantPremiumOwnership(
        aircraftId: premium.id,
        fleet: fleet,
      );
      expect(afterPurchase[premium.id]!.unlocked, isTrue);
      expect(afterPurchase[premium.id]!.premiumOwned, isTrue);

      final restored = await store.loadFleetProgress(fleet);
      expect(restored[second.id]!.unlocked, isTrue);
      expect(restored[premium.id]!.premiumOwned, isTrue);
    },
  );
}
