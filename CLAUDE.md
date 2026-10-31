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
| Payments | razorpay_flutter ^1.3.6 (test mode) |
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
      level_one.dart               — L04-06 shared layout (2×2 narrow-body)
      level_two.dart               — L07-09 shared layout (3×3 narrow-body)
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
  aircraft/                        — aircraft photos
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
- **Levels 31–42:** `unlockType: premium` — require the Premium Fleet Pass purchase (₹499)

### Playable game layouts (levels with a cabin game implemented)

| Levels | Layout ID | Aircraft |
|---|---|---|
| 1 | level_c208 | Cessna Grand Caravan EX |
| 2 | level_skycourier | Cessna SkyCourier |
| 3 | level_saab340 | Saab 340B |
| 4–6 | level_one | ATR 42-600, ERJ-145, Saab 2000 |
| 7–9 | level_two | Il-114-300, CRJ-700, ATR 72-600 |

**Levels 10–42 have no game layout yet** — they show "Coming Soon" in-app.

### Seat block configs (real-world economy layouts)

| Layout | seatBlocks | Aircraft examples |
|---|---|---|
| Single-file | [1,1] | L1–3 (tiny turboprops) |
| 4-abreast | [2,2] | L4–9 |
| 5-abreast | [2,3] | L13–22 |
| 6-abreast | [3,3] | L20–30 (single-aisle mainline) |
| 7-abreast | [2,3,2] | L31–37 (767, A330, 787, 777-200ER) |
| 9-abreast | [3,3,3] | L38–42 (A350, 777-300ER, 747, A380) |

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

## Payment flow

```
Tap "Unlock with Google"
  → Google Sign-In (one tap)
  → Razorpay sheet (₹499 / 49900 paise)
  → _onPaymentSuccess → ShopService.recordPurchase → Supabase purchases table
  → setState(_premiumUnlocked = true) → all L31-42 aircraft unlocked
```

Restore flow: "Restore purchase" → Google Sign-In → `ShopService.restorePurchase` → Supabase lookup → unlock locally.

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

1. **Sentry DSN** — replace `'SENTRY_DSN_PLACEHOLDER'` in `lib/main.dart:12` with the real DSN from sentry.io (org: nordiclabsdev, project: boarding-zone-game).

2. **Razorpay go-live** — after Play Store publication and Razorpay account verification:
   - Replace `rzp_test_SpygPfgyLGh3TU` in `lib/config/secrets.dart` with the live key from dashboard.razorpay.com
   - Tighten Supabase RLS on `purchases` table to verify payment server-side (currently permissive)

3. **Game package name finalisation** — `com.nordiclabs.boardingbluster` is set. Update Google OAuth client in Cloud Console if package name changes again.

4. **Google OAuth — Android client** — verify the registered OAuth client (ID above) is type **Android** (not Web). Android type doesn't use a client secret.

### Medium priority

5. **Game layouts for levels 10–42** — 33 aircraft currently show "Coming Soon". Each needs an `AircraftLayout` implementation in `lib/boarding/levels/` and a `gameLayoutId` entry in `aircraft_fleet.json` + `AircraftLevelRegistry`.

6. **Promo banner in Shop tab** — `_PromoBanner` widget in `boarding_home_shell.dart` is a placeholder. Add real URLs/names for developer websites when ready. Use `url_launcher` (already a dependency).

7. **`publishableKey` migration** — replace `anonKey:` with `publishableKey:` in `Supabase.initialize()` in `lib/main.dart`.

8. **Release signing config** — `build.gradle.kts` still uses debug keys for release builds. Create a proper keystore and signing config before publishing.

### Low priority

9. **Cross-device purchase restore UX** — after reinstall, user must manually tap "Restore purchase". Consider auto-checking on app start if a cached Google ID exists.

10. **Leaderboard player matching** — currently matches by `displayName + bestMilliseconds`. If two players share the same name and time, highlighting may be wrong. Consider matching by `player_id` instead (requires adding `player_id` to the `leaderboard` view).

11. **Game name in pubspec** — `name: boarding_bluster` is set. The git repo folder is still named `boarding-zone-game` — rename the folder/repo on GitHub when convenient.

---

## Developer notes

- **Never commit `lib/config/secrets.dart`** — it's gitignored. Use `secrets.template.dart` as reference.
- `unawaited()` is used intentionally for fire-and-forget Supabase calls (score submission, profile upsert) so the game UI doesn't block on network.
- The `leaderboard` Supabase view is read-only; scores are written to the `scores` table directly.
- Player UUID is generated client-side (`_newUuid()` in `LocalProfileStore`) — not tied to any auth system for anonymous play.
- `_premiumUnlocked` in `_BoardingHomeShellState` is the single source of truth for premium access. It's loaded from `ShopService.isPremiumUnlocked()` (local cache) on startup and set to `true` after a successful payment.
