# Boarding Bluster — Claude Context

## Project overview

Flutter mobile game (Android-first) where players board aircraft as fast as possible.
Built with the Flame engine. Each aircraft is a timed puzzle — zone seats, board passengers, beat the target time to unlock the next aircraft.

**App name:** Boarding Bluster  
**Package:** `com.nordiclabs.boardingbluster`  
**Pubspec name:** `boarding_bluster`  
**Version:** 1.0.0+1

---

## Tech stack

| Layer | Technology |
|---|---|
| UI + game | Flutter 3.x + Flame ^1.38.2 |
| Local storage | shared_preferences ^2.5.6 |
| Backend | Supabase (project ID: `zfzbbvtdgwkhrbtlvjmm`, region: eu-west-1) |
| HTTP (Android) | cronet_http ^1.3.0 via `CronetClient.defaultCronetEngine()` |
| Error reporting | sentry_flutter ^8.0.0 (DSN placeholder — needs replacing) |
| Auth | google_sign_in ^6.2.1 (triggered only at purchase) |
| Payments | razorpay_flutter ^1.3.6 (test mode — not yet live) |
| URL launch | url_launcher ^6.3.0 |

---

## Repository structure

```
lib/
  main.dart                        — app entry, Sentry init, Supabase init, CronetClient
  config/
    secrets.dart                   — GITIGNORED — Razorpay key lives here
    secrets.template.dart          — committed template, copy to secrets.dart
  boarding/
    aircraft_layout.dart           — AircraftLayout data model
    boarding_game_page.dart        — game screen (Flutter wrapper around Flame)
    boarding_simulation.dart       — boarding algorithm / simulation logic
    cabin_game.dart                — Flame game component
    levels/
      level_c208.dart              — L01 Cessna Grand Caravan EX
      level_skycourier.dart        — L02 Cessna SkyCourier
      level_saab340.dart           — L03 Saab 340B
      level_one.dart               — L04-06 shared layout (4-abreast narrow-body), 13 rows
      level_two.dart               — L07-09 shared layout (4-abreast narrow-body), 18 rows
      level_767.dart               — L31-37 wide-body 2-4-2 (8 abreast), 30 rows
      level_wide_232.dart          — wide-body 2-3-2 (7 abreast, A330/787), 36 rows
      level_wide_333.dart          — wide-body 3-3-3 (9 abreast, A350/777/747), 40 rows
      level_a380.dart              — L42 A380 3-4-3 (10 abreast), 46 rows
  home/
    aircraft.dart                  — Aircraft model + AircraftCatalog (loads fleet JSON)
    aircraft_level_registry.dart   — maps gameLayoutId → AircraftLayout
    boarding_home_shell.dart       — main shell: Fleet / Rankings / Shop tabs
    local_profile_store.dart       — offline profile, best times, fleet progress
    manufacturer_brand_assets.dart — manufacturer logo asset paths
    rankings_service.dart          — Supabase leaderboard read/write
    shop_service.dart              — Google Sign-In + Supabase purchase record/restore
assets/
  data/aircraft_fleet.json         — 42 aircraft definitions (source of truth)
  aircraft/                        — aircraft photos (filenames must match imageAsset in JSON)
  manufacturers/                   — manufacturer logos
android/
  app/
    build.gradle.kts               — applicationId, namespace, ProGuard config
    proguard-rules.pro             — Razorpay + Google Sign-In ProGuard rules
    src/main/
      AndroidManifest.xml          — INTERNET permission, Google OAuth client ID meta-data
      kotlin/com/nordiclabs/boardingbluster/MainActivity.kt
```

---

## Supabase schema

**Project URL:** `https://zfzbbvtdgwkhrbtlvjmm.supabase.co`  
**Anon key:** in `lib/main.dart` (deprecation warning: rename `anonKey` → `publishableKey`)

### Tables

```sql
profiles      (id text PK, display_name text)
scores        (id uuid PK, player_id text, aircraft_id text, milliseconds int, created_at timestamptz)
purchases     (google_id text PK, payment_id text, purchased_at timestamptz)
```

### Views

```sql
leaderboard   — best score per player per aircraft, joined with display_name
```

RLS is enabled on all tables. `purchases` currently has a permissive policy (allow all) — tighten before production by verifying payment server-side.

---

## Aircraft fleet

42 aircraft across levels 1–42, defined in `assets/data/aircraft_fleet.json`.

- **Levels 1–30:** `unlockType: progression` — unlock by beating the previous aircraft's target time
- **Levels 31–42:** `unlockType: premium` — require the Premium Fleet Pass purchase ($5.99)

### Playable game layouts

| Levels | Layout ID | Aircraft |
|---|---|---|
| 1 | level_c208 | Cessna Grand Caravan EX |
| 2 | level_skycourier | Cessna SkyCourier |
| 3 | level_saab340 | Saab 340B |
| 4–6 | level_one | ATR 42-600, ERJ-145, Saab 2000 |
| 7–9 | level_two | Il-114-300, CRJ-700, ATR 72-600 |
| 31–37 | level_767 | Wide-body 2-4-2 (Boeing 767 family) |
| 38–41 (2-3-2) | level_wide_232 | A330/787/777-200ER |
| 38–41 (3-3-3) | level_wide_333 | A350/777-300ER/747 |
| 42 | level_a380 | Airbus A380-800 |

**Levels 10–30 have no game layout yet** — they show "Coming Soon" in-app.  
Levels 31–42 have layouts but are premium-locked.

### Seat layout configs (real-world economy layouts)

`seatLayout` in `AircraftLayout` and `aircraft_fleet.json` is the ground truth for blocker logic. It is a flat left-to-right string array where seat labels are letters and `"W"` marks a walking aisle.

| Layout | seatLayout | Aircraft examples |
|---|---|---|
| Single-file | `["A","W","B"]` | L1–3 (tiny turboprops) |
| 4-abreast | `["A","B","W","C","D"]` | L4–9 |
| 5-abreast | `["A","B","W","C","D","E"]` | L13–22 |
| 6-abreast | `["A","B","C","W","D","E","F"]` | L20–30 (single-aisle mainline) |
| 7-abreast (2-3-2) | `["A","B","W","C","D","E","W","F","G"]` | L31–37 (767, A330, 787) |
| 8-abreast (2-4-2) | `["A","B","W","C","D","E","F","W","G","H"]` | 767 variant |
| 9-abreast (3-3-3) | `["A","B","C","W","D","E","F","W","G","H","J"]` | L38–41 (A350, 747, 777) |
| 10-abreast (3-4-3) | `["A","B","C","W","D","E","F","G","W","H","J","K"]` | L42 (A380) |

`seatBlocks` in `AircraftLayout` is render-only (used to draw overhead bin panels and row numbers) and is separate from `seatLayout`.

### Row counts (real-world economy cabin rows)

| Layout | Row count | Basis |
|---|---|---|
| level_c208 | 5 | Cessna 208 (9 seats) |
| level_skycourier | 9 | Cessna SkyCourier (19 seats) |
| level_saab340 | 17 | Saab 340B (35 seats) |
| level_one | 13 | ATR 42 / ERJ-145 / Saab 2000 |
| level_two | 18 | CRJ-700 / ATR 72 |
| level_767 | 30 | Boeing 767-300ER |
| level_wide_232 | 36 | A330-200 / Boeing 787 |
| level_wide_333 | 40 | A350 / Boeing 777-300ER |
| level_a380 | 46 | Airbus A380-800 |

---

## Key services

### LocalProfileStore (`lib/home/local_profile_store.dart`)
- Generates a UUID player ID on first launch (stored in SharedPreferences)
- Auto-generates display names: `<Word><3-digit number>` e.g. `Falcon847` — max 12 chars
- 20 word pool: Falcon, Skyhawk, Comet, Orion, Bluebird, Jetstar, Nimbus, Zephyr, Stratos, Vortex, Cirrus, Altair, Solaris, Tempest, Quasar, Aether, Boreal, Cygnus, Dawnjet, Equinox
- Stores best times, fleet progress, seat zone configs offline

### RankingsService (`lib/home/rankings_service.dart`)
- `upsertProfile` — syncs display name to Supabase `profiles`
- `submitScore` — inserts to `scores` (retry ×3, 800ms delay)
- `fetchLeaderboard(aircraftId)` — top 50 by best time
- `fetchPlayerBest(aircraftId, playerId)` — current player's rank
- All errors reported to Sentry via `captureException`, app never crashes

### ShopService (`lib/home/shop_service.dart`)
- `signIn()` — Google Sign-In (silent first, then picker)
- `recordPurchase(googleId, paymentId)` — writes to Supabase `purchases` + caches locally
- `restorePurchase(googleId)` — checks Supabase, restores local cache
- `isPremiumUnlocked()` — reads local cache (instant, no network)

---

## Payment flow (current — not yet live)

```
Shop tab → "Sign in with Google"
  → Google Sign-In (silent first, then picker)
  → Shows signed-in account chip + "CLAIM YOUR SEAT" button
  → Tap "CLAIM YOUR SEAT" → SnackBar: "Coming soon — payments aren't live yet"
```

**When Razorpay goes live**, replace the SnackBar stub in `_ShopTabState._handlePurchase()` with:
```
Razorpay sheet (₹499 / 49900 paise)
  → _onPaymentSuccess → ShopService.recordPurchase → Supabase purchases table
  → setState(_premiumUnlocked = true) → all L31-42 aircraft unlocked
```

Restore flow: "Restore purchase" → Google Sign-In → `ShopService.restorePurchase` → Supabase lookup → unlock locally.

---

## Game screen — `BoardingGamePage`

Key parameters:
- `aircraftName` — shown in header
- `aircraftImageAsset` — thumbnail shown after the name in the header
- `layout` — `AircraftLayout` (required)
- `previewOnly` — disables boarding, shows cabin preview only (for locked premium aircraft)
- `previousBestMilliseconds` — best time at navigation time (seeded into `_currentBestMilliseconds`)
- `onCompleted(ms)` — called with final time when boarding completes
- `onNext()` — called when user taps "NEXT FLIGHT"

Header layout: `← | Aircraft Name | [photo thumbnail] | ↺`

Completion popup shows:
- `REPLAY` (outlined) — calls `_replay()`, resets simulation without resetting zone paint
- `NEXT FLIGHT` (filled, 2× width) — calls `_nextFlight()`

`_currentBestMilliseconds` is mutable state (not `widget.previousBestMilliseconds`) — updates in-session so BEST shows correctly after replaying.

---

## Error reporting (Sentry)

Sentry SDK is fully wired in `lib/main.dart`:
- `FlutterError.onError` — Flutter framework errors
- `PlatformDispatcher.instance.onError` — unhandled async Dart errors

All `RankingsService` and `ShopService` methods add breadcrumbs and capture exceptions.
App never crashes on network failure — errors are swallowed after 3 retries and reported.

**DSN:** currently `'SENTRY_DSN_PLACEHOLDER'` in `lib/main.dart:12`  
**Sentry org:** `nordiclabsdev`, **project:** `boarding-zone-game`

---

## Android config

- **Min SDK:** 26 (raised from flutter default to satisfy `sentry_flutter ^10.x` and `google_sign_in ^7.x`)
- **OAuth client ID:** `284949944908-2j3p30poivtnbpn6f2q55i6hsru54ijo.apps.googleusercontent.com`
- **Debug SHA-1:** `08:6C:AA:5A:DE:68:A0:93:64:BF:3F:1E:C8:1C:E1:AB:DF:55:D6:C9`
- ProGuard enabled for release builds (`proguard-rules.pro`)
- `cronet_http` used instead of `dart:io` HttpClient to work around Android network issues

---

## Known issues / limitations

- **Corporate VPN (SAP)** blocks HTTPS to `supabase.co` on the Android emulator. Rankings and score submission only work on a real device or without the VPN. This is not a code bug.
- **`anonKey` deprecation warning** in `lib/main.dart` — rename to `publishableKey` when upgrading `supabase_flutter`.

---

## Pending / TODO

### High priority

1. **Razorpay go-live** — after Play Store publication and Razorpay account verification:
   - Replace the SnackBar "coming soon" stub in `_ShopTabState._handlePurchase()` with the actual Razorpay `open()` call
   - Replace `rzp_test_SpygPfgyLGh3TU` in `lib/config/secrets.dart` with the live key
   - Tighten Supabase RLS on `purchases` table to verify payment server-side (currently permissive)

### Medium priority

2. **Game layouts for levels 10–30** — 21 aircraft currently show "Coming Soon". Each needs an `AircraftLayout` in `lib/boarding/levels/` and a `gameLayoutId` in `aircraft_fleet.json` + `AircraftLevelRegistry`.

### Low priority

3. **Promo banner / developer links** — Shop tab has no external links yet. Wire up `url_launcher` when developer site is ready.

---

## Developer notes

- **Never commit `lib/config/secrets.dart`** — it's gitignored. Use `secrets.template.dart` as reference.
- `unawaited()` is used intentionally for fire-and-forget Supabase calls (score submission, profile upsert) so the game UI doesn't block on network.
- The `leaderboard` Supabase view is read-only; scores are written to the `scores` table directly.
- Player UUID is generated client-side (`_newUuid()` in `LocalProfileStore`) — not tied to any auth system for anonymous play.
- `_premiumUnlocked` in `_BoardingHomeShellState` is the single source of truth for premium access. It's loaded from `ShopService.isPremiumUnlocked()` (local cache) on startup and set to `true` after a successful payment.
- Profile avatar icon: `Icons.airline_seat_recline_normal_rounded` (passenger icon, not person).
- Aircraft image assets: filenames are as they appear in `aircraft_fleet.json` under `imageAsset`. Extension is `.jpeg` for some (e.g. `a380-800.jpeg`), `.jpg` for others — check the actual file before adding new entries.

### Boarding simulation architecture

`BoardingSimulation` is pure Dart (no Flame). `CabinGame` reads its state each frame and renders.

**`PassengerPhase` enum** (progression per passenger):
```
walking → turning → stowing → seatSliding → seated
                            ↘ shuffleWait → seated
```
- `seatSliding`: no blockers — passenger slides directly from aisle to seat after stowing
- `shuffleWait`: blocker(s) needed to stand first — passenger waits in aisle until all blockers are in `waitingInAisle`, then slides to seat

**`ShufflePhase` enum** (for seated blocker passengers):
```
none → exitingToAisle → waitingInAisle → returningToSeat → none
```
- `waitingInAisle` has **no auto-timer** — blocker is held there until `_finallySeated` explicitly triggers return, guaranteeing strict serial order: outer exits → inner slides in and seats → outer returns.
- If a blocker reaches `waitingInAisle` but no `shuffleWait` passenger is waiting for it (passenger seated before blocker arrived), the blocker self-releases to `returningToSeat` on the next frame.

**Blocker detection** uses `seatLayout` string array — scans left/right from the target seat label to find the nearest `"W"`, then any occupied seats between that `W` and the target are blockers. `_findBlockersWhere` is the single implementation; `_findActiveBlockers` and `_findWaitingBlockers` are filtered wrappers.

**Walking collision**: passengers only block the one directly behind them while both are `walking`. Passengers in `turning`/`stowing`/`seatSliding`/`shuffleWait` have stepped into their row and no longer block the aisle. Forward limit is never applied backwards (uses `math.max(rowPosition, cap)`).
