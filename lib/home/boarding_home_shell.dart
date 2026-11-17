import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../audio/app_audio.dart';
import '../boarding/boarding_game_page.dart';
import '../boarding/levels/level_tutorial.dart';
import '../main.dart' show appThemeMode;
import 'aircraft.dart';
import 'aircraft_catalog.dart';
import 'local_profile_store.dart';
import 'manufacturer_brand_assets.dart';
import 'notification_service.dart';
import 'rankings_service.dart';
import 'shop_service.dart';

const _accent = Color(0xFF2F8FFF);
const _amber = Color(0xFFFFB930);
const _accentGlow = Color(0x332F8FFF);

/// Adaptive color helper — reads brightness from MaterialApp's current theme.
class _HC {
  _HC._(this._dark);

  factory _HC.from(BuildContext context) =>
      _HC._(Theme.of(context).brightness == Brightness.dark);

  final bool _dark;

  Color get bg => _dark ? const Color(0xFF0D0F14) : const Color(0xFFEDF3FF);
  Color get surface => _dark ? const Color(0xFF141820) : const Color(0xFFFFFFFF);
  Color get surfaceElevated =>
      _dark ? const Color(0xFF1C2030) : const Color(0xFFF0F5FF);
  Color get muted =>
      _dark ? const Color(0xFF6B7A99) : const Color(0xFF5A6A8A);
  Color get ink => _dark ? Colors.white : const Color(0xFF0A1628);
  Color get border => _dark
      ? Colors.white.withValues(alpha: 0.08)
      : const Color(0xFF0A1628).withValues(alpha: 0.10);
  Color get divider =>
      _dark ? const Color(0xFF1C2030) : const Color(0xFFCDD7F0);

  /// Text/icon color that always reads well on the amber _accent button.
  static const Color onAccent = Colors.white;
}

class BoardingHomeShell extends StatefulWidget {
  const BoardingHomeShell({super.key, this.store});

  final LocalProfileStore? store;

  @override
  State<BoardingHomeShell> createState() => _BoardingHomeShellState();
}

class _BoardingHomeShellState extends State<BoardingHomeShell> {
  late final LocalProfileStore _store;
  late final RankingsService _rankings;
  late final ShopService _shop;
  late final NotificationService _notifications;
  late final Razorpay _razorpay;
  late final Future<PlayerProfile> _profileFuture;
  PlayerProfile? _profile;
  Map<String, int?> _bestTimes = {};
  Set<String> _unlockedAircraftIds = {};
  Set<String> _premiumOwnedAircraftIds = {};
  bool _premiumUnlocked = false;
  bool _tutorialCompleted = false;
  bool _soundEnabled = true;
  bool _notifPromptShown = false;
  int _fleetScrollVersion = 0;
  String _selectedId = 'cessna-grand-caravan-ex';
  int _destination = 0;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? LocalProfileStore();
    _rankings = RankingsService();
    _shop = ShopService();
    _notifications = NotificationService();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _razorpay.clear();
    AppAudio.instance.dispose();
    super.dispose();
  }

  Future<PlayerProfile> _loadProfile() async {
    registerAircraftCatalog();
    final profile = await _store.loadProfile();
    final progress = await _store.loadFleetProgress(AircraftCatalog.all);
    final soundEnabled = await _store.loadSoundEnabled();
    final themeModeStr = await _store.loadThemeMode();
    bool premiumUnlocked = await _shop.isPremiumUnlocked();
    final tutorialCompleted = await _store.isTutorialCompleted();

    // Auto-restore: if premium is not locally cached but a Google ID is stored,
    // silently check Supabase to recover after reinstall.
    if (!premiumUnlocked) {
      final cachedId = await _shop.cachedGoogleId();
      if (cachedId != null && cachedId.isNotEmpty) {
        premiumUnlocked = await _shop.restorePurchase(cachedId);
      }
    }

    final newestUnlocked = AircraftCatalog.all.lastWhere(
      (aircraft) => progress[aircraft.id]?.unlocked == true,
      orElse: () => AircraftCatalog.all.first,
    );
    final bestTimes = {
      for (final entry in progress.entries)
        entry.key: entry.value.bestTimeMilliseconds,
    };
    if (mounted) {
      setState(() {
        _profile = profile;
        _selectedId = newestUnlocked.id;
        _bestTimes = bestTimes;
        _premiumUnlocked = premiumUnlocked;
        _tutorialCompleted = tutorialCompleted;
        _soundEnabled = soundEnabled;
        _unlockedAircraftIds = {
          for (final entry in progress.entries)
            if (entry.value.unlocked) entry.key,
        };
        _premiumOwnedAircraftIds = {
          for (final entry in progress.entries)
            if (entry.value.premiumOwned) entry.key,
        };
      });
      // Apply persisted theme (main.dart already loaded it before first frame,
      // but this ensures shell-level init is consistent if ever loaded later).
      appThemeMode.value = switch (themeModeStr) {
        'light' => ThemeMode.light,
        'system' => ThemeMode.system,
        _ => ThemeMode.dark,
      };
      // First launch: go straight into the tutorial.
      if (!tutorialCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _launchTutorial());
      }
    }
    unawaited(AppAudio.instance.init(enabled: soundEnabled).then((_) {
      AppAudio.instance.startBgMusic();
    }));

    // Ensure profile row exists in Supabase from first launch onwards
    unawaited(_rankings.upsertProfile(
      playerId: profile.internalId,
      displayName: profile.displayName,
    ));

    // Sync FCM token if notification permission is already granted
    unawaited(_notifications.requestPermissionIfNeeded().then((granted) {
      if (granted) _notifications.syncToken(profile.internalId);
    }));

    return profile;
  }

  bool _isUnlocked(Aircraft aircraft) {
    if (aircraft.unlockType == AircraftUnlockType.free) {
      return _tutorialCompleted;
    }
    if (aircraft.unlockType == AircraftUnlockType.premium && _premiumUnlocked) {
      return true;
    }
    return _unlockedAircraftIds.contains(aircraft.id) ||
        _premiumOwnedAircraftIds.contains(aircraft.id);
  }

  Future<void> _editCrewName() async {
    final current = _profile;
    if (current == null) return;
    final result = await showDialog<({String name, bool soundEnabled})>(
      context: context,
      builder: (_) => _ProfileDialog(
        initialName: current.displayName,
        initialSoundEnabled: _soundEnabled,
      ),
    );
    if (result == null) {
      AppAudio.instance.setEnabled(_soundEnabled);
      return;
    }
    final name = result.name.trim();
    final newSound = result.soundEnabled;
    if (name.isNotEmpty) {
      await _store.saveDisplayName(name);
      if (mounted) setState(() => _profile = current.copyWith(displayName: name));
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'Display name updated',
        category: 'profile',
        level: SentryLevel.info,
      ));
      unawaited(
        _rankings.upsertProfile(
          playerId: current.internalId,
          displayName: name,
        ),
      );
    }
    if (newSound != _soundEnabled) {
      await _store.saveSoundEnabled(newSound);
      AppAudio.instance.setEnabled(newSound);
      if (mounted) setState(() => _soundEnabled = newSound);
    }
    // Persist whatever theme mode the toggle left us at.
    await _store.saveThemeMode(_themeModeKey(appThemeMode.value));
  }

  String _themeModeKey(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.system => 'system',
    _ => 'dark',
  };

  Future<GoogleSignInAccount?> _signInForShop() async {
    final account = await _shop.signIn();
    if (account == null) return null;

    final profile = _profile;
    if (profile == null) return account;

    // Check if this Google account is already linked to a different player in Supabase.
    final existing = await _rankings.fetchProfileByGoogleId(account.id);

    if (existing != null && existing.playerId != profile.internalId) {
      // Returning player on a new install — restore their cloud data locally.
      await _restoreCloudData(
        tempPlayerId: profile.internalId,
        cloudPlayerId: existing.playerId,
        cloudDisplayName: existing.displayName,
        googleId: account.id,
      );
    } else {
      // New Google sign-in for this device player — link them.
      unawaited(_rankings.linkGoogleId(
        playerId: profile.internalId,
        displayName: profile.displayName,
        googleId: account.id,
        email: account.email,
      ));
    }

    return account;
  }

  /// Pulls purchases and best scores from Supabase for a returning player and
  /// applies them to local storage so no progress is lost after a reinstall.
  /// Also merges any scores the temp UUID accumulated into the canonical UUID.
  Future<void> _restoreCloudData({
    required String tempPlayerId,
    required String cloudPlayerId,
    required String cloudDisplayName,
    required String googleId,
  }) async {
    // Merge any scores the temp UUID played into the canonical cloud player.
    // Fire-and-forget — UI shouldn't block on this.
    unawaited(_rankings.mergeScoresIntoPlayer(
      fromPlayerId: tempPlayerId,
      intoPlayerId: cloudPlayerId,
    ));

    // Switch local UUID to the canonical cloud player ID and restore display name.
    await _store.overridePlayerId(cloudPlayerId);
    await _store.saveDisplayName(cloudDisplayName);
    await _shop.saveLinkedPlayerId(cloudPlayerId);

    // Restore cloud best scores locally (take best of cloud vs local).
    final cloudScores = await _rankings.fetchBestScoresByPlayerId(cloudPlayerId);
    for (final entry in cloudScores.entries) {
      await _store.saveBestTime(entry.key, entry.value);
    }

    // Restore premium purchase if present.
    final hasPremium = await _shop.restorePurchase(googleId);

    // Reload fleet progress so UI reflects the restored data.
    final progress = await _store.loadFleetProgress(AircraftCatalog.all);
    final bestTimes = {
      for (final e in progress.entries) e.key: e.value.bestTimeMilliseconds,
    };

    if (mounted) {
      setState(() {
        // Update the in-memory profile to use the canonical player ID and cloud name.
        if (_profile != null) {
          _profile = PlayerProfile(
            internalId: cloudPlayerId,
            displayName: cloudDisplayName,
          );
        }
        if (hasPremium) _premiumUnlocked = true;
        _bestTimes = bestTimes;
        _unlockedAircraftIds = {
          for (final e in progress.entries)
            if (e.value.unlocked) e.key,
        };
        _premiumOwnedAircraftIds = {
          for (final e in progress.entries)
            if (e.value.premiumOwned) e.key,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Welcome back, $cloudDisplayName! '
            'Your progress from your previous install has been restored.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _openRazorpay(GoogleSignInAccount account) {
    unawaited(_shop.logPurchaseIntent(
      googleId: account.id,
      email: account.email,
    ));
    const key = String.fromEnvironment('RAZORPAY_KEY');
    final options = <String, dynamic>{
      'key': key,
      'amount': 49900, // ₹499 in paise
      'name': 'Boarding Bluster',
      'description': 'Premium Fleet Pass',
      'prefill': {
        'contact': '',
        'email': account.email,
      },
      'external': {
        'wallets': ['paytm'],
      },
    };
    try {
      _razorpay.open(options);
    } catch (e, st) {
      Sentry.captureException(
        e,
        stackTrace: st,
        hint: Hint.withMap({'place': '_openRazorpay'}),
      );
    }
  }

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? 'unknown';
    final googleId = (await _shop.cachedGoogleId()) ?? '';
    final email = (await _shop.cachedEmail()) ?? '';
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Payment success: $paymentId googleId: $googleId',
      category: 'shop',
      level: SentryLevel.info,
    ));

    if (googleId.isNotEmpty) {
      await _shop.recordPurchase(
        googleId: googleId,
        email: email,
        paymentId: paymentId,
      );
    } else {
      // Should never happen — google ID is cached at sign-in time
      await Sentry.captureMessage(
        'Payment success but no cached googleId — paymentId: $paymentId',
        level: SentryLevel.error,
      );
    }

    if (mounted) {
      setState(() => _premiumUnlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All premium aircraft unlocked!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    }
  }

  void _onPaymentError(PaymentFailureResponse response) {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Payment error: ${response.code} ${response.message}',
      category: 'shop',
      level: SentryLevel.warning,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response.message?.isNotEmpty == true
              ? response.message!
              : 'Payment failed. Please try again.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restorePurchase() async {
    final account = await _shop.signIn();
    if (!mounted) return;
    if (account == null) return;
    final restored = await _shop.restorePurchase(account.id);
    if (!mounted) return;
    if (restored) {
      setState(() => _premiumUnlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchase restored successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No purchase found for this account.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }


  Future<void> _launchAircraft(Aircraft aircraft) async {
    final layout = aircraft.layout;
    if (!_isUnlocked(aircraft)) {
      if (aircraft.unlockType == AircraftUnlockType.premium) {
        if (layout == null) return;
        // Show seat layout in preview mode; boarding is disabled.
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) {
              final dark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: SystemUiOverlayStyle(
                  statusBarIconBrightness:
                      dark ? Brightness.light : Brightness.dark,
                  systemNavigationBarColor: dark
                      ? const Color(0xFF0D0F14)
                      : const Color(0xFFEDF3FF),
                  systemNavigationBarIconBrightness:
                      dark ? Brightness.light : Brightness.dark,
                ),
                child: BoardingGamePage(
                  aircraftName: aircraft.displayName,
                  aircraftImageAsset: aircraft.imageAsset,
                  layout: layout,
                  previewOnly: true,
                  onUnlockTap: () => setState(() => _destination = 2),
                ),
              );
            },
          ),
        );
        return;
      } else {
        _showLockedRequirement(aircraft);
      }
      return;
    }
    if (layout == null) return;
    final initialZones = await _store.loadSeatZones(
      aircraft.id,
      seatCount: layout.passengerCount,
      zoneCount: layout.zoneCount,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor:
                  dark ? const Color(0xFF0D0F14) : const Color(0xFFEDF3FF),
              systemNavigationBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
            ),
            child: BoardingGamePage(
              aircraftName: aircraft.displayName,
              aircraftImageAsset: aircraft.imageAsset,
              layout: layout,
              initialZones: initialZones,
              previousBestMilliseconds: _bestTimes[aircraft.id],
              targetSeconds: aircraft.targetSeconds,
              aircraftId: aircraft.id,
              rankingsService: _rankings,
              onZonesChanged: (zones) =>
                  _store.saveSeatZones(aircraft.id, zones),
              onCompleted: (milliseconds) =>
                  _recordBestTime(aircraft, milliseconds),
              onNext: () => _selectNextAircraft(aircraft),
            ),
          );
        },
      ),
    );
    await _reloadFleetProgress();
  }

  Future<void> _recordBestTime(Aircraft aircraft, int milliseconds) async {
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Boarding completed: ${aircraft.id} ${milliseconds}ms',
      category: 'game',
      level: SentryLevel.info,
      data: {
        'aircraft_id': aircraft.id,
        'milliseconds': milliseconds,
        'has_profile': _profile != null,
      },
    ));
    final progress = await _store.recordBoardingCompletion(
      aircraftId: aircraft.id,
      milliseconds: milliseconds,
      fleet: AircraftCatalog.all,
    );
    _applyFleetProgress(progress);
    final profile = _profile;
    if (profile != null) {
      unawaited(
        _rankings.submitScore(
          playerId: profile.internalId,
          displayName: profile.displayName,
          aircraftId: aircraft.id,
          milliseconds: milliseconds,
        ),
      );
      // First good run after a new best — ask for notification permission.
      // The moment is contextual: player just did well and is on the completion card.
      final targetMs = aircraft.targetSeconds * 1000;
      final beatTarget = targetMs > 0 && milliseconds <= targetMs;
      if (beatTarget && !_notifPromptShown) {
        _notifPromptShown = true;
        unawaited(_notifications.requestPermissionIfNeeded().then((granted) {
          if (granted) _notifications.syncToken(profile.internalId);
        }));
      }
    }
  }

  Future<void> _selectNextAircraft(Aircraft aircraft) async {
    await _reloadFleetProgress();
    if (!mounted) return;
    final index = AircraftCatalog.all.indexOf(aircraft);
    final next = AircraftCatalog.all[(index + 1) % AircraftCatalog.all.length];
    setState(() => _selectedId = next.id);
  }

  Future<void> _launchTutorial() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor:
                  dark ? const Color(0xFF0D0F14) : const Color(0xFFEDF3FF),
              systemNavigationBarIconBrightness:
                  dark ? Brightness.light : Brightness.dark,
            ),
            child: BoardingGamePage(
              aircraftName: 'Tutorial Flight',
              layout: LevelTutorial.aircraft,
              tutorialMode: true,
              onCompleted: (_) async => _store.setTutorialCompleted(),
            ),
          );
        },
      ),
    );
    // After returning from tutorial, check if completed.
    if (!mounted) return;
    final completed = await _store.isTutorialCompleted();
    if (completed && !_tutorialCompleted) {
      setState(() {
        _tutorialCompleted = true;
        _fleetScrollVersion++;
      });
      await _reloadFleetProgress();
    }
  }

  Future<void> _reloadFleetProgress() async {
    final progress = await _store.loadFleetProgress(AircraftCatalog.all);
    _applyFleetProgress(progress);
  }

  void _applyFleetProgress(Map<String, AircraftProgressRecord> progress) {
    if (!mounted) return;
    setState(() {
      _bestTimes = {
        for (final entry in progress.entries)
          entry.key: entry.value.bestTimeMilliseconds,
      };
      _unlockedAircraftIds = {
        for (final entry in progress.entries)
          if (entry.value.unlocked) entry.key,
      };
      _premiumOwnedAircraftIds = {
        for (final entry in progress.entries)
          if (entry.value.premiumOwned) entry.key,
      };
    });
  }

  void _showLockedRequirement(Aircraft aircraft) {
    String message;
    if (!_tutorialCompleted && aircraft.unlockType == AircraftUnlockType.free) {
      message =
          'Complete the Training Flight first — swipe left in the fleet to find it!';
    } else if (aircraft.unlockType == AircraftUnlockType.progression) {
      final all = AircraftCatalog.all;
      final prevIndex = all.indexWhere((a) => a.id == aircraft.id) - 1;
      if (prevIndex >= 0) {
        final prev = all[prevIndex];
        message = 'Complete ${prev.displayName} under ${_formatTarget(prev.targetSeconds)}';
      } else {
        message = 'Complete the previous flight.';
      }
    } else {
      message = aircraft.unlockRequirement ?? aircraft.priceLabel ?? 'Locked aircraft';
    }
    showDialog<void>(
      context: context,
      builder: (context) {
        final hc = _HC.from(context);
        return AlertDialog(
          backgroundColor: hc.surface,
          icon: const Icon(Icons.lock_rounded, color: _amber),
          title: Text(aircraft.displayName,
              style: GoogleFonts.rajdhani(color: hc.ink)),
          content: Text(
            message,
            style: GoogleFonts.rajdhani(color: hc.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PlayerProfile>(
    future: _profileFuture,
    builder: (context, snapshot) {
      final hc = _HC.from(context);
      if (snapshot.connectionState != ConnectionState.done ||
          _profile == null) {
        return Scaffold(
          backgroundColor: hc.bg,
          body: const Center(child: CircularProgressIndicator(color: _accent)),
        );
      }
      final crewMember = _profile!;
      return Scaffold(
        backgroundColor: hc.bg,
        body: SafeArea(
          child: Stack(
            children: [
              IndexedStack(
                index: _destination,
                children: [
              _HomeTab(
                crewName: crewMember.displayName,
                selected: AircraftCatalog.byId(_selectedId),
                bestTimes: _bestTimes,
                isUnlocked: _isUnlocked,
                onProfileTap: _editCrewName,
                onSelect: (aircraft) =>
                    setState(() => _selectedId = aircraft.id),
                onPlay: _launchAircraft,
                onLockedTap: (aircraft) {
                  if (aircraft.unlockType == AircraftUnlockType.premium) {
                    unawaited(_launchAircraft(aircraft));
                  } else {
                    _showLockedRequirement(aircraft);
                  }
                },
                onHowToPlay: _launchTutorial,
                scrollVersion: _fleetScrollVersion,
              ),
              _RankingsTab(
                crewName: crewMember.displayName,
                playerId: crewMember.internalId,
                rankings: _rankings,
              ),
              _ShopTab(
                premiumUnlocked: _premiumUnlocked,
                signIn: _signInForShop,
                onPurchase: _openRazorpay,
                onRestore: _restorePurchase,
                playerId: crewMember.internalId,
              ),
            ],
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: hc.surface,
          indicatorColor: _accentGlow,
          selectedIndex: _destination,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? _accent : hc.muted,
            );
          }),
          onDestinationSelected: (value) =>
              setState(() => _destination = value),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.flight_outlined, color: hc.muted),
              selectedIcon: const Icon(Icons.flight_rounded, color: _accent),
              label: 'Fleet',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined, color: hc.muted),
              selectedIcon: const Icon(Icons.emoji_events_rounded, color: _accent),
              label: 'Rankings',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined, color: hc.muted),
              selectedIcon:
                  const Icon(Icons.storefront_rounded, color: _accent),
              label: 'Shop',
            ),
          ],
        ),
      );
    },
  );
}


class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({
    required this.initialName,
    required this.initialSoundEnabled,
  });

  final String initialName;
  final bool initialSoundEnabled;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _controller;
  late bool _soundEnabled;
  late bool _darkMode;
  late final ThemeMode _initialThemeMode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _soundEnabled = widget.initialSoundEnabled;
    _initialThemeMode = appThemeMode.value;
    _darkMode = _initialThemeMode != ThemeMode.light;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appThemeMode,
      builder: (context, _) {
        final hc = _HC.from(context);
        return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: hc.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: hc.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: hc.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.airline_seat_recline_normal_rounded,
                    color: _accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CREW PROFILE',
                        style: GoogleFonts.rajdhani(
                          color: _accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Settings',
                        style: GoogleFonts.rajdhani(
                          color: hc.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CALLSIGN',
                  style: GoogleFonts.rajdhani(
                    color: hc.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: false,
                  maxLength: 12,
                  style: GoogleFonts.rajdhani(
                    color: hc.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter callsign…',
                    hintStyle: GoogleFonts.rajdhani(
                      color: hc.muted.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                    counterStyle: GoogleFonts.rajdhani(color: hc.muted, fontSize: 10),
                    filled: true,
                    fillColor: hc.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: hc.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sound toggle row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: hc.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: hc.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: _soundEnabled ? _accent : hc.muted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sound',
                              style: GoogleFonts.rajdhani(
                                color: hc.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _soundEnabled
                                  ? 'Music & effects on'
                                  : 'Music & effects off',
                              style: GoogleFonts.rajdhani(
                                color: hc.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _soundEnabled,
                        onChanged: (value) {
                          setState(() => _soundEnabled = value);
                          AppAudio.instance.setEnabled(value);
                        },
                        activeThumbColor: _accent,
                        activeTrackColor: _accent.withValues(alpha: 0.3),
                        inactiveThumbColor: hc.muted,
                        inactiveTrackColor: hc.surfaceElevated,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Theme toggle row
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: hc.surfaceElevated,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: hc.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _darkMode
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: _darkMode ? _accent : const Color(0xFF8AAAF0),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Appearance',
                              style: GoogleFonts.rajdhani(
                                color: hc.ink,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _darkMode ? 'Dark mode' : 'Light mode',
                              style: GoogleFonts.rajdhani(
                                color: hc.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _darkMode,
                        onChanged: (value) {
                          setState(() => _darkMode = value);
                          final mode =
                              value ? ThemeMode.dark : ThemeMode.light;
                          appThemeMode.value = mode;
                        },
                        activeThumbColor: _accent,
                        activeTrackColor: _accent.withValues(alpha: 0.3),
                        inactiveThumbColor: const Color(0xFF8AAAF0),
                        inactiveTrackColor:
                            const Color(0xFF8AAAF0).withValues(alpha: 0.25),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      AppAudio.instance.setEnabled(widget.initialSoundEnabled);
                      appThemeMode.value = _initialThemeMode;
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: hc.muted,
                      side: BorderSide(color: hc.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      (
                        name: _controller.text.trim(),
                        soundEnabled: _soundEnabled
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: _HC.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
        );
      },
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.crewName,
    required this.selected,
    required this.bestTimes,
    required this.isUnlocked,
    required this.onProfileTap,
    required this.onSelect,
    required this.onPlay,
    required this.onLockedTap,
    required this.onHowToPlay,
    this.scrollVersion = 0,
  });

  final String crewName;
  final Aircraft selected;
  final Map<String, int?> bestTimes;
  final bool Function(Aircraft) isUnlocked;
  final VoidCallback onProfileTap;
  final ValueChanged<Aircraft> onSelect;
  final ValueChanged<Aircraft> onPlay;
  final ValueChanged<Aircraft> onLockedTap;
  final VoidCallback onHowToPlay;
  final int scrollVersion;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static const _cardBaseWidth = 300.0;
  static const _cardSeparator = 12.0;
  late final ScrollController _fleetController;
  double _tileScale = 1.0;

  double get _cardExtent => _cardBaseWidth * _tileScale + _cardSeparator;

  // +1 because index 0 is the tutorial card; real aircraft start at 1.
  int get _selectedIndex =>
      AircraftCatalog.all
          .indexWhere((aircraft) => aircraft.id == widget.selected.id)
          .clamp(0, AircraftCatalog.all.length - 1) +
      1;

  @override
  void initState() {
    super.initState();
    _fleetController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected(animate: false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sw = MediaQuery.of(context).size.width;
    _tileScale = (sw / 411.0).clamp(0.90, 1.0);
  }

  void _scrollToSelected({required bool animate}) {
    if (!_fleetController.hasClients) return;
    final position = _fleetController.position;
    final cardWidth = _cardBaseWidth * _tileScale;
    final target =
        (_selectedIndex * _cardExtent - (position.viewportDimension - cardWidth) / 2)
            .clamp(0.0, position.maxScrollExtent);
    if (animate) {
      _fleetController.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _fleetController.jumpTo(target);
    }
  }

  @override
  void didUpdateWidget(covariant _HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected.id != widget.selected.id ||
        oldWidget.scrollVersion != widget.scrollVersion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelected(animate: true);
      });
    }
  }

  @override
  void dispose() {
    _fleetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return CustomScrollView(
    key: const PageStorageKey('fleet-scroll'),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        sliver: SliverList.list(
          children: [
            _HomeHeader(crewName: widget.crewName, onTap: widget.onProfileTap),
            const SizedBox(height: 36),
            const _PageTitle(kicker: 'SELECT YOUR AIRCRAFT', title: 'Fleet'),
            const SizedBox(height: 8),
            Text(
              'Swipe to browse the fleet and tap an aircraft to board.',
              style: GoogleFonts.barlow(color: hc.muted, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Builder(builder: (context) {
              final tileScale = _tileScale;
              return SizedBox(
              height: 324 * tileScale,
              child: ListView.separated(
                controller: _fleetController,
                scrollDirection: Axis.horizontal,
                itemCount: AircraftCatalog.all.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _TutorialTile(onTap: widget.onHowToPlay, scale: tileScale);
                  }
                  final aircraft = AircraftCatalog.all[index - 1];
                  final unlocked = widget.isUnlocked(aircraft);
                  return _AircraftTile(
                    aircraft: aircraft,
                    selected: aircraft.id == widget.selected.id,
                    unlocked: unlocked,
                    bestMilliseconds: widget.bestTimes[aircraft.id],
                    scale: tileScale,
                    onTap: () {
                      if (aircraft.unlockType == AircraftUnlockType.premium &&
                          !unlocked) {
                        widget.onLockedTap(aircraft);
                      } else if (unlocked) {
                        widget.onSelect(aircraft);
                        widget.onPlay(aircraft);
                      } else {
                        widget.onLockedTap(aircraft);
                      }
                    },
                  );
                },
              ),
            );}),
          ],
        ),
      ),
    ],
  );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.crewName, required this.onTap});

  final String crewName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/boarding_bluster_logo.jpg',
            width: 42,
            height: 42,
            fit: BoxFit.cover,
          ),
        ),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Text(
          'Boarding Bluster',
          style: GoogleFonts.rajdhani(
            color: hc.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
      Semantics(
        button: true,
        label: 'Crew profile, $crewName',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              Text(
                crewName,
                style: GoogleFonts.rajdhani(color: hc.muted, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: hc.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: _accent.withValues(alpha: 0.4)),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/passenger_avatar.png',
                    width: 38,
                    height: 38,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  }
}

class _TutorialTile extends StatelessWidget {
  const _TutorialTile({required this.onTap, this.scale = 1.0});

  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 300 * scale,
      child: Material(
        color: hc.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: _amber.withValues(alpha: 0.55), width: 2),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _amber.withValues(alpha: 0.10),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner area with Maya
                SizedBox(
                  height: 184 * scale,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [const Color(0xFF0A1628), const Color(0xFF1C2E4A)]
                                : [const Color(0xFFD8E8F8), const Color(0xFFEBF3FF)],
                          ),
                        ),
                      ),
                      // Maya portrait — centered
                      Positioned.fill(
                        child: Image.asset(
                          'assets/maya.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                      // HOW TO PLAY badge
                      const Positioned(
                        left: 12,
                        top: 12,
                        child: _Pill(
                          label: 'HOW TO PLAY',
                          icon: Icons.school_rounded,
                          color: _amber,
                        ),
                      ),
                      // FREE badge
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB87A).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: const Color(0xFF1DB87A), width: 1),
                          ),
                          child: const Text(
                            'FREE',
                            style: TextStyle(
                              color: Color(0xFF1DB87A),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Info area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Training Flight',
                          style: GoogleFonts.rajdhani(
                            color: hc.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your first flight. Learn the system, then own it.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                          style: GoogleFonts.barlow(
                            color: hc.muted,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "MAYA'S CREW TRAINING  ·  ~2 MIN",
                          style: GoogleFonts.rajdhani(
                            color: _amber,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AircraftTile extends StatelessWidget {
  const _AircraftTile({
    required this.aircraft,
    required this.selected,
    required this.unlocked,
    required this.bestMilliseconds,
    required this.onTap,
    this.scale = 1.0,
  });

  final Aircraft aircraft;
  final bool selected;
  final bool unlocked;
  final int? bestMilliseconds;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    final premium = aircraft.unlockType == AircraftUnlockType.premium;
    final hasLevel = aircraft.layout != null;
    final status = premium
        ? unlocked
              ? 'OWNED'
              : 'PREMIUM'
        : !unlocked
        ? 'LOCKED'
        : bestMilliseconds != null
        ? 'COMPLETED'
        : 'AVAILABLE';
    final statusColor = premium ? const Color(0xFFF0B963) : _amber;
    final detail = !hasLevel && !unlocked
        ? aircraft.unlockRequirement ?? aircraft.priceLabel ?? 'Locked aircraft'
        : bestMilliseconds != null
        ? 'PERSONAL BEST  ${_formatTime(bestMilliseconds!)}'
        : 'LEVEL ${aircraft.level}  ·  ${aircraft.typicalSeats} SEATS  ·  TARGET ${_formatTarget(aircraft.targetSeconds)}';

    return SizedBox(
      width: 300 * scale,
      child: Material(
        color: hc.surface,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? _accent : hc.border,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.18),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 184 * scale,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AircraftPhoto(aircraft: aircraft),
                      if (!unlocked && !premium) const _LockedPhotoOverlay(),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _Pill(
                          label: status,
                          icon: premium
                              ? Icons.workspace_premium_rounded
                              : !unlocked
                              ? Icons.lock_rounded
                              : bestMilliseconds != null
                              ? Icons.check_rounded
                              : Icons.flight_takeoff_rounded,
                          color: premium
                              ? statusColor
                              : !unlocked
                              ? Colors.white
                              : _accent,
                        ),
                      ),
                      if (!unlocked && !premium)
                        const Center(
                          child: Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 34,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 8),
                            ],
                          ),
                        ),
                      if (selected && unlocked)
                        Positioned(
                          right: 12,
                          top: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: _HC.onAccent,
                              size: 15,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          aircraft.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rajdhani(
                            color: hc.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                aircraft.subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                softWrap: true,
                                style: GoogleFonts.barlow(
                                  color: hc.muted,
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Opacity(
                              opacity: 0.58,
                              child: _ManufacturerLogoBadge(
                                manufacturer: aircraft.manufacturer,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.rajdhani(
                            color: unlocked ? _amber : hc.muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedPhotoOverlay extends StatelessWidget {
  const _LockedPhotoOverlay();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0x997D858D),
    child: Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, color: Colors.white, size: 17),
      ),
    ),
  );
}

class AircraftPhoto extends StatelessWidget {
  const AircraftPhoto({required this.aircraft, super.key});

  final Aircraft aircraft;

  @override
  Widget build(BuildContext context) => Image.asset(
    aircraft.imageAsset,
    fit: BoxFit.cover,
    alignment: Alignment.center,
    errorBuilder: (context, error, stackTrace) => Image.asset(
      'assets/aircraft/a320.jpg',
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (context, error, stackTrace) {
        final hc = _HC.from(context);
        return ColoredBox(
          color: hc.surfaceElevated,
          child: const Center(
            child: Icon(Icons.flight_rounded, color: Colors.white38, size: 38),
          ),
        );
      },
    ),
  );
}

class _ManufacturerLogoBadge extends StatelessWidget {
  const _ManufacturerLogoBadge({required this.manufacturer});

  final String manufacturer;

  @override
  Widget build(BuildContext context) {
    final logo = ManufacturerBrandAssets.logoFor(manufacturer);
    return Semantics(
      label: '$manufacturer manufacturer logo',
      image: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 38, maxWidth: 86),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: logo == null
            ? Center(
                child: Text(
                  ManufacturerBrandAssets.monogramFor(manufacturer),
                  maxLines: 1,
                  style: GoogleFonts.rajdhani(
                    color: _HC.onAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              )
            : Image.asset(
                logo,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    ManufacturerBrandAssets.monogramFor(manufacturer),
                    style: GoogleFonts.rajdhani(
                      color: _HC.onAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _RankingsTab extends StatefulWidget {
  const _RankingsTab({
    required this.crewName,
    required this.playerId,
    required this.rankings,
  });
  final String crewName;
  final String playerId;
  final RankingsService rankings;

  @override
  State<_RankingsTab> createState() => _RankingsTabState();
}

class _RankingsTabState extends State<_RankingsTab> {
  String _selectedId = 'cessna-grand-caravan-ex';
  late Future<(List<LeaderboardEntry>, LeaderboardEntry?)> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _fetch(_selectedId);
  }

  Future<(List<LeaderboardEntry>, LeaderboardEntry?)> _fetch(String id) =>
      Future.wait([
        widget.rankings.fetchLeaderboard(id),
        widget.rankings.fetchPlayerBest(id, widget.playerId),
      ]).then((results) => (
            results[0] as List<LeaderboardEntry>,
            results[1] as LeaderboardEntry?,
          ));

  void _selectAircraft(String id) {
    setState(() {
      _selectedId = id;
      _dataFuture = _fetch(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    final aircraft = AircraftCatalog.byId(_selectedId);
    return CustomScrollView(
      key: const PageStorageKey('rankings-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          sliver: SliverList.list(
            children: [
              const _PageTitle(kicker: 'COMPETE', title: 'World Rankings'),
              const SizedBox(height: 18),
              Builder(builder: (context) {
                final playable = AircraftCatalog.all
                    .where((a) => a.layout != null)
                    .toList();
                return SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: playable.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final item = playable[index];
                      final active = item.id == _selectedId;
                      return ChoiceChip(
                        label: Text(item.model),
                        selected: active,
                        onSelected: (_) => _selectAircraft(item.id),
                        selectedColor: _accent,
                        backgroundColor: hc.surface,
                        labelStyle: GoogleFonts.rajdhani(
                          color: active ? _HC.onAccent : hc.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide.none,
                      );
                    },
                  ),
                );
              }),
              const SizedBox(height: 17),
              ClipRRect(
                borderRadius: BorderRadius.circular(19),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 136,
                      width: double.infinity,
                      child: AircraftPhoto(aircraft: aircraft),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xE8101923)],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      bottom: 15,
                      child: Text(
                        '${aircraft.displayName} · LEVEL ${aircraft.level}',
                        style: GoogleFonts.rajdhani(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'WORLD RANKINGS',
                      style: GoogleFonts.rajdhani(
                        color: hc.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    'BEST TIME',
                    style: GoogleFonts.rajdhani(
                      color: hc.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FutureBuilder<(List<LeaderboardEntry>, LeaderboardEntry?)>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _accent,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () => setState(
                            () => _dataFuture = _fetch(_selectedId),
                          ),
                          icon: const Icon(Icons.refresh_rounded,
                              color: _accent),
                          label: Text(
                            'Retry',
                            style: GoogleFonts.rajdhani(color: _accent),
                          ),
                        ),
                      ),
                    );
                  }
                  final entries = snapshot.data?.$1 ?? const [];
                  final playerBest = snapshot.data?.$2;
                  final playerInTop =
                      playerBest != null &&
                      entries.any((e) => e.playerId == playerBest.playerId);
                  if (entries.isEmpty && playerBest == null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No scores yet — be the first!',
                          style: GoogleFonts.barlow(color: hc.muted, fontSize: 13),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < entries.length; i++)
                        _RankRow(
                          rank: i + 1,
                          name: entries[i].displayName,
                          time: _formatTime(entries[i].bestMilliseconds),
                          highlighted: playerBest != null &&
                              entries[i].playerId == playerBest.playerId,
                        ),
                      if (playerBest != null && !playerInTop) ...[
                        const SizedBox(height: 4),
                        _RankRow(
                          rank: entries.length + 1,
                          name: playerBest.displayName,
                          time: _formatTime(playerBest.bestMilliseconds),
                          highlighted: true,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.time,
    this.highlighted = false,
  });
  final int? rank;
  final String name;
  final String time;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    decoration: BoxDecoration(
      color: highlighted ? _amber.withValues(alpha: 0.12) : hc.surface,
      borderRadius: BorderRadius.circular(14),
      border: highlighted
          ? Border.all(color: _amber.withValues(alpha: 0.5))
          : Border.all(color: hc.border),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            rank == null ? 'YOU' : '#${rank!}',
            style: GoogleFonts.rajdhani(
              color: highlighted ? _amber : hc.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rajdhani(
              color: highlighted ? hc.ink : hc.muted,
              fontSize: 12,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          time,
          style: GoogleFonts.rajdhani(
            color: hc.ink,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFeatures: const [],
          ),
        ),
      ],
    ),
  );
  }
}

class _ShopTab extends StatefulWidget {
  const _ShopTab({
    required this.premiumUnlocked,
    required this.signIn,
    required this.onPurchase,
    required this.onRestore,
    required this.playerId,
  });
  final bool premiumUnlocked;
  final Future<GoogleSignInAccount?> Function() signIn;
  final void Function(GoogleSignInAccount) onPurchase;
  final VoidCallback onRestore;
  final String playerId;

  @override
  State<_ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<_ShopTab> {
  GoogleSignInAccount? _account;
  bool _signingIn = false;

  Future<void> _handleSignIn() async {
    setState(() => _signingIn = true);
    final account = await widget.signIn();
    if (!mounted) return;
    if (account == null) {
      setState(() => _signingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign-in cancelled.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _account = account;
      _signingIn = false;
    });
  }

  void _handlePurchase() {
    final account = _account;
    if (account == null) return;
    widget.onPurchase(account);
  }

  @override
  Widget build(BuildContext context) {
    final premiumAircraft = AircraftCatalog.all
        .where((a) => a.unlockType == AircraftUnlockType.premium)
        .toList();

    return CustomScrollView(
      key: const PageStorageKey('shop-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          sliver: SliverList.list(
            children: [
              const _PageTitle(kicker: 'FLEET STORE', title: 'Shop'),
              const SizedBox(height: 20),

              _PremiumPackCard(
                aircraftList: premiumAircraft,
                unlocked: widget.premiumUnlocked,
                signedInAccount: _account,
                signingIn: _signingIn,
                onSignIn: _handleSignIn,
                onPurchase: _account != null ? _handlePurchase : null,
                onRestore: widget.onRestore,
              ),

              const SizedBox(height: 20),
              const _VentuoirBanner(),
              const SizedBox(height: 20),
              _ShopFooter(playerId: widget.playerId),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _PremiumPackCard extends StatelessWidget {
  const _PremiumPackCard({
    required this.aircraftList,
    required this.unlocked,
    required this.signedInAccount,
    required this.signingIn,
    required this.onSignIn,
    required this.onPurchase,
    required this.onRestore,
  });

  final List<Aircraft> aircraftList;
  final bool unlocked;
  final GoogleSignInAccount? signedInAccount;
  final bool signingIn;
  final VoidCallback onSignIn;
  final VoidCallback? onPurchase;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Container(
    decoration: BoxDecoration(
      color: hc.bg,
      borderRadius: BorderRadius.circular(24),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header gradient banner
        Container(
          height: 120,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A3A5C), Color(0xFF0D1E2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Subtle aircraft silhouette strip
              Positioned.fill(
                child: Opacity(
                  opacity: 0.08,
                  child: Image.asset(
                    'assets/aircraft/a380-800.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.workspace_premium_rounded,
                          color: Color(0xFFF0B963),
                          size: 18,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'PREMIUM FLEET PASS',
                          style: GoogleFonts.rajdhani(
                            color: Color(0xFFF0B963),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        if (unlocked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 13,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'UNLOCKED',
                                  style: GoogleFonts.rajdhani(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Unlock All ${aircraftList.length} Premium Aircraft',
                      style: GoogleFonts.rajdhani(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Aircraft thumbnail strip
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: aircraftList.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) => ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 88,
                child: AircraftPhoto(aircraft: aircraftList[index]),
              ),
            ),
          ),
        ),

        // Perks list
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Perk(
                icon: Icons.all_inclusive_rounded,
                label: 'One-time payment — yours forever',
              ),
              const SizedBox(height: 8),
              _Perk(
                icon: Icons.devices_rounded,
                label: 'Linked to your Google account',
              ),
              const SizedBox(height: 8),
              _Perk(
                icon: Icons.restore_rounded,
                label: 'Restore anytime after reinstall',
              ),
              const SizedBox(height: 20),

              // Price + CTA
              if (!unlocked) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$5.99',
                      style: GoogleFonts.rajdhani(
                        color: hc.ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        'one-time',
                        style: GoogleFonts.rajdhani(
                          color: hc.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Step 1 — sign in (show when not yet signed in)
                if (signedInAccount == null) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: signingIn ? null : onSignIn,
                      icon: signingIn
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _HC.onAccent,
                              ),
                            )
                          : const Icon(Icons.login_rounded, size: 18),
                      label: Text(signingIn ? 'Signing in…' : 'Sign in with Google'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _HC.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: GoogleFonts.rajdhani(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Step 2 — signed in, show account + purchase button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: hc.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF66BB6A),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            signedInAccount!.displayName ?? signedInAccount!.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.rajdhani(
                              color: hc.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'Signed in',
                          style: GoogleFonts.rajdhani(
                            color: hc.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onPurchase,
                      icon: const Icon(Icons.flight_takeoff_rounded, size: 18),
                      label: Text('UNLOCK THE FLEET'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _HC.onAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: GoogleFonts.rajdhani(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: onRestore,
                    child: Text(
                      'Restore purchase',
                      style: GoogleFonts.rajdhani(
                        color: hc.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF66BB6A),
                        size: 38,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'You own all premium aircraft.',
                        style: GoogleFonts.rajdhani(
                          color: hc.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Row(
    children: [
      Icon(icon, color: _accent, size: 16),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          label,
          style: GoogleFonts.rajdhani(
            color: hc.ink.withValues(alpha: 0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.kicker, required this.title});
  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        kicker,
        style: GoogleFonts.rajdhani(
          color: _accent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        title,
        style: GoogleFonts.rajdhani(
          color: hc.ink,
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    ],
  );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xC8101923),
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.rajdhani(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ],
    ),
  );
}

String _formatTarget(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ─────────────────────────────────────────────────────────────────────────────
// Venturoir ad banner
// ─────────────────────────────────────────────────────────────────────────────

class _VentuoirBanner extends StatefulWidget {
  const _VentuoirBanner();

  @override
  State<_VentuoirBanner> createState() => _VentuoirBannerState();
}

class _VentuoirBannerState extends State<_VentuoirBanner>
    with SingleTickerProviderStateMixin {
  static const _url = 'https://www.venturoir.com/';
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: 0, end: -7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _float.value),
        child: child,
      ),
      child: Material(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => launchUrl(
            Uri.parse(_url),
            mode: LaunchMode.externalApplication,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: hc.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                    'Are you a Traveller?',
                    style: GoogleFonts.playfairDisplay(
                      color: hc.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Capture the soulful stories of travel.',
                    style: GoogleFonts.barlow(
                      color: hc.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1723 / 913,
                    child: Image.asset(
                      'assets/ads/venturoir.png',
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shop footer — Privacy Policy + Contact Us
// ─────────────────────────────────────────────────────────────────────────────

class _ShopFooter extends StatelessWidget {
  const _ShopFooter({required this.playerId});
  final String playerId;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: hc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: hc.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: hc.muted, size: 14),
              const SizedBox(width: 6),
              Text(
                'NordicLabs · Boarding Bluster',
                style: GoogleFonts.rajdhani(
                  color: hc.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _FooterLinkButton(
                  icon: Icons.lock_outline_rounded,
                  label: 'Privacy Policy',
                  onTap: () => _showPrivacyPolicy(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _FooterLinkButton(
                  icon: Icons.mail_outline_rounded,
                  label: 'Contact Us',
                  onTap: () => _showContactSheet(context, playerId),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterLinkButton extends StatelessWidget {
  const _FooterLinkButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Material(
      color: hc.surfaceElevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: hc.muted, size: 15),
              const SizedBox(width: 7),
              Text(
                label,
                style: GoogleFonts.rajdhani(
                  color: hc.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showPrivacyPolicy(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PrivacyPolicySheet(),
  );
}

void _showContactSheet(BuildContext context, String playerId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ContactSheet(playerId: playerId),
  );
}

// ─── Privacy Policy Sheet ───────────────────────────────────────────────────

class _PrivacyPolicySheet extends StatelessWidget {
  const _PrivacyPolicySheet();

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_outline_rounded,
                          color: _accent, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Policy',
                          style: GoogleFonts.rajdhani(
                            color: hc.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Effective 1 November 2026',
                          style: GoogleFonts.rajdhani(color: hc.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(color: hc.divider, height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  children: const [
                    _PpSummaryCard(),
                    SizedBox(height: 24),
                    _PpSection(
                      title: 'Information We Collect',
                      children: [
                        _PpSubheading('Automatically (all users)'),
                        _PpBullet('A random anonymous player ID (UUID generated on your device)'),
                        _PpBullet('An auto-generated display name (e.g. Falcon847) for the leaderboard'),
                        _PpBullet('Your best boarding times per aircraft'),
                        SizedBox(height: 10),
                        _PpSubheading('Only if you use Google Sign-In'),
                        _PpBullet('Your Google account ID — used solely to record and restore your purchase'),
                        _PpBullet('Your Google email address — stored to identify your account and support data deletion requests'),
                        _PpBullet('We do not access your name, profile photo, or any other Google data'),
                        SizedBox(height: 10),
                        _PpSubheading('Only if you grant notification permission'),
                        _PpBullet('A Firebase Cloud Messaging (FCM) token identifying your device — used only to deliver push notifications such as leaderboard rank alerts'),
                        _PpBullet('You can revoke permission at any time in your device notification settings; your token will no longer be used'),
                        SizedBox(height: 10),
                        _PpSubheading('Crash & error data'),
                        _PpBullet('Device type, OS version, app version, and stack traces sent to Sentry'),
                        _PpBullet('No personally identifiable information in crash reports'),
                      ],
                    ),
                    SizedBox(height: 24),
                    _PpSection(
                      title: 'How We Use Your Information',
                      children: [
                        _PpTableRow(key_: 'Anonymous player ID', value: 'Identify your scores on the leaderboard'),
                        _PpTableRow(key_: 'Display name', value: 'Show your name on global rankings'),
                        _PpTableRow(key_: 'Best times', value: 'Power the global leaderboard'),
                        _PpTableRow(key_: 'Google account ID', value: 'Record and restore your Premium Fleet purchase'),
                        _PpTableRow(key_: 'Google email', value: 'Account identification and data deletion requests'),
                        _PpTableRow(key_: 'FCM token', value: 'Send push notifications (leaderboard rank alerts) to your device'),
                        _PpTableRow(key_: 'Crash data', value: 'Fix bugs and improve app stability'),
                      ],
                    ),
                    SizedBox(height: 24),
                    _PpSection(
                      title: 'Third-Party Services',
                      children: [
                        _PpBullet('Supabase — leaderboard and purchase storage (EU: eu-west-1)'),
                        _PpBullet('Sentry — crash reporting (EU-hosted)'),
                        _PpBullet('Google Sign-In — optional authentication for purchases'),
                        _PpBullet('Firebase Cloud Messaging (FCM) — push notification delivery (only if permission granted)'),
                      ],
                    ),
                    SizedBox(height: 24),
                    _PpSection(
                      title: 'Data Retention & Deletion',
                      children: [
                        _PpBullet('Anonymous scores and display names are retained to maintain leaderboard history'),
                        _PpBullet('Purchase records are retained to allow you to restore Premium Fleet access after reinstallation'),
                        _PpBullet('You may request deletion of all your data at any time by emailing us from the Contact Us section — we will process requests within 30 days'),
                      ],
                    ),
                    SizedBox(height: 24),
                    _PpSection(
                      title: "Children's Privacy",
                      children: [
                        _PpBullet('Boarding Bluster does not knowingly collect personal information from children under 13'),
                        _PpBullet('If you believe a child has provided personal data, contact us and we will delete it promptly'),
                      ],
                    ),
                    SizedBox(height: 24),
                    _PpSection(
                      title: 'Security',
                      children: [
                        _PpBullet('We use industry-standard practices to protect your data'),
                        _PpBullet('No method of internet transmission is 100% secure — we cannot guarantee absolute security'),
                      ],
                    ),
                    SizedBox(height: 24),
                    _PpSection(
                      title: 'Changes to This Policy',
                      children: [
                        _PpBullet('We may update this policy from time to time'),
                        _PpBullet('Changes take effect immediately upon posting — review this page periodically'),
                      ],
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PpSummaryCard extends StatelessWidget {
  const _PpSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TL;DR',
            style: GoogleFonts.rajdhani(
                color: _accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          const _PpBullet('Anonymous play — no account required'),
          const _PpBullet('Google Sign-In only if you buy the Premium Fleet'),
          const _PpBullet('Your email is stored when you sign in with Google'),
          const _PpBullet('Your scores & display name go on the leaderboard'),
          const _PpBullet('No ads. No data sold. Ever.'),
        ],
      ),
    );
  }
}

class _PpSection extends StatelessWidget {
  const _PpSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.rajdhani(
            color: hc.ink,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }
}

class _PpSubheading extends StatelessWidget {
  const _PpSubheading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        text,
        style: GoogleFonts.rajdhani(
          color: _accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PpBullet extends StatelessWidget {
  const _PpBullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: CircleAvatar(radius: 2.5, backgroundColor: hc.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style:
                  GoogleFonts.barlow(color: hc.muted, fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _PpTableRow extends StatelessWidget {
  const _PpTableRow({required this.key_, required this.value});
  final String key_;
  final String value;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              key_,
              style: GoogleFonts.rajdhani(
                  color: hc.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.barlow(color: hc.muted, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contact Sheet ───────────────────────────────────────────────────────────

class _ContactSheet extends StatelessWidget {
  const _ContactSheet({required this.playerId});
  final String playerId;

  static const _email = 'nordiclabsdev@gmail.com';

  Future<void> _launchEmail(BuildContext context) async {
    final subject = Uri.encodeComponent('Boarding Bluster — Feedback / Support');
    final uri = Uri.parse('mailto:$_email?subject=$subject');
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open mail app. Email us at $_email')),
        );
      }
    }
  }

  Future<void> _launchDeleteEmail(BuildContext context) async {
    final subject = Uri.encodeComponent('Boarding Bluster — Data Deletion Request');
    final body = Uri.encodeComponent(
      'Hi NordicLabs,\n\nPlease delete all data associated with my account.\n\nPlayer ID: $playerId\nGoogle email (if signed in): \nPlayer display name: \n',
    );
    final uri = Uri.parse('mailto:$_email?subject=$subject&body=$body');
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open mail app. Email us at $_email')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: hc.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            children: [
              _SheetHandle(),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mail_outline_rounded,
                        color: _accent, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Contact Us',
                    style: GoogleFonts.rajdhani(
                      color: hc.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Have a question, found a bug, or want to share feedback? We\'d love to hear from you.',
                style: GoogleFonts.barlow(color: hc.muted, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              _ContactActionTile(
                icon: Icons.mail_rounded,
                iconColor: _accent,
                title: 'Send us an email',
                subtitle: _email,
                onTap: () => unawaited(_launchEmail(context)),
              ),
              const SizedBox(height: 12),
              _ContactActionTile(
                icon: Icons.delete_outline_rounded,
                iconColor: const Color(0xFFFF6B6B),
                title: 'Request data deletion',
                subtitle: 'We\'ll delete all your data within 30 days',
                onTap: () => unawaited(_launchDeleteEmail(context)),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: hc.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: hc.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.business_rounded, color: hc.muted, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'NordicLabs · nordiclabsdev@gmail.com',
                        style: GoogleFonts.barlow(color: hc.muted, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactActionTile extends StatelessWidget {
  const _ContactActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Material(
      color: hc.surfaceElevated,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.rajdhani(color: hc.ink, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.barlow(color: hc.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: hc.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final hc = _HC.from(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          width: 38,
          height: 4,
          decoration: BoxDecoration(
            color: hc.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

String _formatTime(int milliseconds) {
  final totalSeconds = milliseconds ~/ 1000;
  final m = totalSeconds ~/ 60;
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  final ms = (milliseconds % 1000).toString().padLeft(3, '0');
  return '$m:$s.$ms';
}
