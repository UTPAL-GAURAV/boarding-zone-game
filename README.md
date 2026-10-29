# Boarding Zone

## Fleet catalog

Aircraft metadata is authored in `assets/data/aircraft_fleet.json` and loaded
offline through `AircraftCatalog`. Keep entries in ascending `typicalSeats`
order and assign `level` values consecutively. Each entry includes its unique
description, expected image path, target time, unlock type, and cabin sketch
(row count, seat blocks, aisle count, and aisle capacity). `typicalSeats` is a
representative passenger configuration; it can differ slightly from the
simplified cabin sketch used to plan a level.

Aircraft photos are optional during catalog authoring. Add a photo at the
entry's `imageAsset` path when ready; missing photos fall back to
`assets/aircraft/a320.jpg`. Player unlocks and best times remain local save
data; JSON stores only the unlock rule type and requirement text. `gameLayoutId`
connects an entry to an implemented game level. The first four catalog entries
reuse the prototype's 48-seat and 72-seat layouts; aircraft without this key
are catalog data for future levels and are not playable yet.

A portrait Flutter + Flame boarding strategy game. The home screen contains the aircraft fleet carousel, local crew profile, per-aircraft ranking previews, and the premium hangar. Boarding simulation and cabin rendering remain in their existing modules.

## Home page

- Fleet metadata and ordering are authored in `assets/data/aircraft_fleet.json`; typed parsing and validation live in `lib/home/aircraft.dart`.
- The catalog contains 42 passenger aircraft ordered by representative seat count, from 14 to 525, including Cessna, Saab, Ilyushin, Sukhoi, Tupolev, COMAC, Embraer, Bombardier, ATR, Antonov, Airbus, and Boeing. The Cessna Grand Caravan EX is configured for 14 occupants and SkyCourier for 19. [Grand Caravan](https://cessna.txtav.com/en/caravan) · [SkyCourier](https://cessna.txtav.com/en/turboprop/skycourier-passenger)
- The current first four missions have dedicated layouts for Cessna Grand Caravan EX, Cessna SkyCourier, Saab 340B, and ATR 42-600. Other entries are future level data. The ATR 42-600 uses 48 seats and ATR 72-600 uses 72 seats in standard configurations. [ATR 42-600](https://www.atr-aircraft.com/wp-content/uploads/2022/06/ATR_Fiche42-600-3.pdf) · [ATR 72-600](https://www.atr-aircraft.com/regional-mobility/regional-aircraft/atr-72-600/)
- Aircraft-specific image paths are already listed in the JSON. Add the image files manually; missing images show the bundled A320 photo. Existing photo sources and licenses are listed in [`assets/aircraft/ATTRIBUTION.md`](assets/aircraft/ATTRIBUTION.md).
- Unlock rules are in the catalog; whether progression aircraft are unlocked depends on the crew's local best time. The A350-900 remains premium placeholder content; purchase buttons do not unlock it.
- Per-aircraft progress is stored locally as a versioned record with best time, permanent unlocked state, and premium ownership. Existing best-time keys are migrated into this record. A completed qualifying run unlocks the next progression aircraft; premium ownership has a grant API for a future purchase flow, but purchases are not implemented.
- Rankings are separate by aircraft model and are labeled preview/sample data. No network or ranking service is connected.
- A random UUID and crew-style display name are created locally on first launch. Legacy default names are migrated from “Pilot” to “Crew” without changing the internal ID. The display name and best boarding time are stored in `shared_preferences`; the internal ID is never shown.
- No score synchronization or account system exists yet. A future sync service can read the local best-time records without blocking offline play.

## Run on Android

```sh
flutter doctor --android-licenses
flutter doctor
flutter emulators
flutter emulators --launch <emulator_id>
flutter devices
flutter run -d <device_id>
```

## Run on iOS

Install full Xcode and CocoaPods, open the iOS Simulator, then run:

```sh
open -a Simulator
flutter doctor
flutter devices
flutter run -d <simulator_id>
```

## Checks

```sh
dart format lib test
flutter analyze
flutter test
```
