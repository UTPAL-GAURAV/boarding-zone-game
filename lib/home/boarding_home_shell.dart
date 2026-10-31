import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../audio/app_audio.dart';
import '../boarding/boarding_game_page.dart';
import 'aircraft.dart';
import 'aircraft_level_registry.dart';
import 'local_profile_store.dart';
import 'manufacturer_brand_assets.dart';
import 'rankings_service.dart';
import 'shop_service.dart';

const _navy = Color(0xFF0A0E1A);
const _panel = Color(0xFF151C2E);
const _panelLight = Color(0xFF1E2840);
const _muted = Color(0xFF6B7A99);
const _accent = Color(0xFFFFB930);
const _accentGlow = Color(0x33FFB930);

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
  late final Razorpay _razorpay;
  late final Future<PlayerProfile> _profileFuture;
  PlayerProfile? _profile;
  Map<String, int?> _bestTimes = {};
  Set<String> _unlockedAircraftIds = {};
  Set<String> _premiumOwnedAircraftIds = {};
  bool _premiumUnlocked = false;
  bool _soundEnabled = true;
  String _selectedId = 'cessna-grand-caravan-ex';
  int _destination = 0;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? LocalProfileStore();
    _rankings = RankingsService();
    _shop = ShopService();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<PlayerProfile> _loadProfile() async {
    await AircraftCatalog.load();
    final profile = await _store.loadProfile();
    final progress = await _store.loadFleetProgress(AircraftCatalog.all);
    final soundEnabled = await _store.loadSoundEnabled();
    bool premiumUnlocked = await _shop.isPremiumUnlocked();

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
    }
    unawaited(AppAudio.instance.init(enabled: soundEnabled));
    return profile;
  }

  bool _isUnlocked(Aircraft aircraft) {
    if (aircraft.unlockType == AircraftUnlockType.free) return true;
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
    if (result == null) return;
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
  }

  Future<GoogleSignInAccount?> _signInForShop() => _shop.signIn();

  Future<void> _onPaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? 'unknown';
    final googleId = (await _shop.cachedGoogleId()) ?? '';
    Sentry.addBreadcrumb(Breadcrumb(
      message: 'Payment success: $paymentId',
      category: 'shop',
      level: SentryLevel.info,
    ));

    // Re-get google ID from sign-in account if cache is empty
    String resolvedGoogleId = googleId;
    if (resolvedGoogleId.isEmpty) {
      final account = await _shop.signIn();
      resolvedGoogleId = account?.id ?? '';
    }

    if (resolvedGoogleId.isNotEmpty) {
      await _shop.recordPurchase(
        googleId: resolvedGoogleId,
        paymentId: paymentId,
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
    final layout = AircraftLevelRegistry.resolve(aircraft);
    if (!_isUnlocked(aircraft)) {
      if (aircraft.unlockType == AircraftUnlockType.premium) {
        if (layout == null) {
          // No layout yet for this premium aircraft — nothing to preview.
          _showComingSoon(aircraft);
          return;
        }
        // Show seat layout in preview mode; boarding is disabled.
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Theme(
              data: ThemeData(
                useMaterial3: true,
                brightness: Brightness.dark,
                scaffoldBackgroundColor: const Color(0xFF0A0E1A),
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFFFFB930),
                  brightness: Brightness.dark,
                ),
                fontFamily: 'sans-serif',
              ),
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                value: const SystemUiOverlayStyle(
                  statusBarIconBrightness: Brightness.light,
                  systemNavigationBarColor: Color(0xFF0A0E1A),
                  systemNavigationBarIconBrightness: Brightness.light,
                ),
                child: BoardingGamePage(
                  aircraftName: aircraft.displayName,
                  aircraftImageAsset: aircraft.imageAsset,
                  layout: layout,
                  previewOnly: true,
                  onUnlockTap: () => setState(() => _destination = 2),
                ),
              ),
            ),
          ),
        );
        return;
      } else {
        _showLockedRequirement(aircraft);
      }
      return;
    }
    if (layout == null) {
      _showComingSoon(aircraft);
      return;
    }
    final initialZones = await _store.loadSeatZones(
      aircraft.id,
      seatCount: layout.passengerCount,
      zoneCount: layout.zoneCount,
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0A0E1A),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFB930),
              brightness: Brightness.dark,
            ),
            fontFamily: 'sans-serif',
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarIconBrightness: Brightness.light,
              systemNavigationBarColor: Color(0xFF0A0E1A),
              systemNavigationBarIconBrightness: Brightness.light,
            ),
            child: BoardingGamePage(
              aircraftName: aircraft.displayName,
              aircraftImageAsset: aircraft.imageAsset,
              layout: layout,
              initialZones: initialZones,
              previousBestMilliseconds: _bestTimes[aircraft.id],
              onZonesChanged: (zones) =>
                  _store.saveSeatZones(aircraft.id, zones),
              onCompleted: (milliseconds) =>
                  _recordBestTime(aircraft, milliseconds),
              onNext: () => _selectNextAircraft(aircraft),
            ),
          ),
        ),
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
    }
  }

  Future<void> _selectNextAircraft(Aircraft aircraft) async {
    await _reloadFleetProgress();
    if (!mounted) return;
    final index = AircraftCatalog.all.indexOf(aircraft);
    final next = AircraftCatalog.all[(index + 1) % AircraftCatalog.all.length];
    setState(() => _selectedId = next.id);
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
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        icon: const Icon(Icons.lock_rounded, color: _accent),
        title: Text(aircraft.displayName, style: const TextStyle(color: Colors.white)),
        content: Text(
          aircraft.unlockRequirement ?? 'Complete the previous mission.',
          style: const TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(Aircraft aircraft) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        icon: const Icon(Icons.construction_rounded, color: _accent),
        title: Text(aircraft.displayName, style: const TextStyle(color: Colors.white)),
        content: const Text(
          'This aircraft is unlocked. Its boarding level is coming soon.',
          style: TextStyle(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<PlayerProfile>(
    future: _profileFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done ||
          _profile == null) {
        return const Scaffold(
          backgroundColor: _navy,
          body: Center(child: CircularProgressIndicator(color: _accent)),
        );
      }
      final crewMember = _profile!;
      return Scaffold(
        backgroundColor: _navy,
        body: SafeArea(
          child: IndexedStack(
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
              ),
              _RankingsTab(
                crewName: crewMember.displayName,
                playerId: crewMember.internalId,
                rankings: _rankings,
              ),
              _ShopTab(
                premiumUnlocked: _premiumUnlocked,
                signIn: _signInForShop,
                onRestore: _restorePurchase,
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: _panel,
          indicatorColor: _accentGlow,
          selectedIndex: _destination,
          onDestinationSelected: (value) =>
              setState(() => _destination = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.flight_outlined, color: _muted),
              selectedIcon: Icon(Icons.flight_rounded, color: _accent),
              label: 'Fleet',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined, color: _muted),
              selectedIcon: Icon(Icons.emoji_events_rounded, color: _accent),
              label: 'Rankings',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined, color: _muted),
              selectedIcon: Icon(Icons.storefront_rounded, color: _accent),
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _soundEnabled = widget.initialSoundEnabled;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    child: Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CREW PROFILE',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Your callsign & settings',
                        style: TextStyle(
                          color: Colors.white,
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
                const Text(
                  'CALLSIGN',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: 12,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter callsign…',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontWeight: FontWeight.w500,
                    ),
                    counterStyle: const TextStyle(color: _muted, fontSize: 10),
                    filled: true,
                    fillColor: _panelLight,
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
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sound toggle row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _panelLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: _soundEnabled ? _accent : _muted,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Sound',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _soundEnabled
                                  ? 'Music & effects on'
                                  : 'Music & effects off',
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _soundEnabled,
                        onChanged: (value) =>
                            setState(() => _soundEnabled = value),
                        activeThumbColor: _accent,
                        activeTrackColor: _accent.withValues(alpha: 0.3),
                        inactiveThumbColor: _muted,
                        inactiveTrackColor: _panelLight,
                      ),
                    ],
                  ),
                ),
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
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _muted,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
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
                      (name: _controller.text.trim(), soundEnabled: _soundEnabled),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
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
  });

  final String crewName;
  final Aircraft selected;
  final Map<String, int?> bestTimes;
  final bool Function(Aircraft) isUnlocked;
  final VoidCallback onProfileTap;
  final ValueChanged<Aircraft> onSelect;
  final ValueChanged<Aircraft> onPlay;
  final ValueChanged<Aircraft> onLockedTap;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static const _cardExtent = 312.0;
  late final ScrollController _fleetController;

  int get _selectedIndex => AircraftCatalog.all
      .indexWhere((aircraft) => aircraft.id == widget.selected.id)
      .clamp(0, AircraftCatalog.all.length - 1);

  @override
  void initState() {
    super.initState();
    _fleetController = ScrollController(
      initialScrollOffset: _selectedIndex * _cardExtent,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelected(animate: false);
    });
  }

  void _scrollToSelected({required bool animate}) {
    if (!_fleetController.hasClients) return;
    final position = _fleetController.position;
    final target =
        (_selectedIndex * _cardExtent - (position.viewportDimension - 300) / 2)
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
    if (oldWidget.selected.id != widget.selected.id) {
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
  Widget build(BuildContext context) => CustomScrollView(
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
            const Text(
              'Swipe the hangar and tap an aircraft to enter its cabin.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 324,
              child: ListView.separated(
                controller: _fleetController,
                scrollDirection: Axis.horizontal,
                itemCount: AircraftCatalog.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final aircraft = AircraftCatalog.all[index];
                  final unlocked = widget.isUnlocked(aircraft);
                  return _AircraftTile(
                    aircraft: aircraft,
                    selected: aircraft.id == widget.selected.id,
                    unlocked: unlocked,
                    bestMilliseconds: widget.bestTimes[aircraft.id],
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
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: _panel,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _accent.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SELECTED AIRCRAFT',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.selected.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: widget.isUnlocked(widget.selected)
                        ? () => widget.onPlay(widget.selected)
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('START ONBOARDING'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: _navy,
                      disabledBackgroundColor: _panelLight,
                      disabledForegroundColor: _muted,
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.55,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.crewName, required this.onTap});

  final String crewName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(
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
            'assets/boarding_bluster_logo.png',
            width: 42,
            height: 42,
            fit: BoxFit.cover,
          ),
        ),
      ),
      const SizedBox(width: 11),
      const Expanded(
        child: Text(
          'Boarding Bluster',
          style: TextStyle(
            color: Colors.white,
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
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
              const SizedBox(width: 6),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _panelLight,
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

class _AircraftTile extends StatelessWidget {
  const _AircraftTile({
    required this.aircraft,
    required this.selected,
    required this.unlocked,
    required this.bestMilliseconds,
    required this.onTap,
  });

  final Aircraft aircraft;
  final bool selected;
  final bool unlocked;
  final int? bestMilliseconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final premium = aircraft.unlockType == AircraftUnlockType.premium;
    final hasLevel = AircraftLevelRegistry.resolve(aircraft) != null;
    final status = premium
        ? unlocked
              ? 'OWNED'
              : 'PREMIUM'
        : !unlocked
        ? 'LOCKED'
        : !hasLevel
        ? 'COMING SOON'
        : bestMilliseconds != null
        ? 'COMPLETED'
        : 'AVAILABLE';
    final statusColor = premium ? const Color(0xFFF0B963) : _accent;
    final detail = !unlocked
        ? aircraft.unlockRequirement ?? aircraft.priceLabel ?? 'Locked aircraft'
        : !hasLevel
        ? 'LEVEL ${aircraft.level}  ·  ${aircraft.typicalSeats} SEATS  ·  IN DEVELOPMENT'
        : bestMilliseconds != null
        ? 'PERSONAL BEST  ${_formatTime(bestMilliseconds!)}'
        : 'LEVEL ${aircraft.level}  ·  ${aircraft.typicalSeats} SEATS  ·  TARGET ${_formatTime(aircraft.targetSeconds * 1000)}';

    return SizedBox(
      width: 300,
      child: Material(
        color: _panel,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? _accent : Colors.white.withValues(alpha: 0.06),
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
                  height: 184,
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
                              color: _navy,
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
                          style: const TextStyle(
                            color: Colors.white,
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
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 11,
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
                          style: TextStyle(
                            color: unlocked ? _accent : _muted,
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
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: _panelLight,
        child: Center(
          child: Icon(Icons.flight_rounded, color: Colors.white38, size: 38),
        ),
      ),
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
                  style: const TextStyle(
                    color: _navy,
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
                    style: const TextStyle(
                      color: _navy,
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
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: AircraftCatalog.all.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = AircraftCatalog.all[index];
                    final active = item.id == _selectedId;
                    return ChoiceChip(
                      label: Text(item.model),
                      selected: active,
                      onSelected: (_) => _selectAircraft(item.id),
                      selectedColor: _accent,
                      backgroundColor: _panel,
                      labelStyle: TextStyle(
                        color: active ? _navy : _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      side: BorderSide.none,
                    );
                  },
                ),
              ),
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
                        style: const TextStyle(
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
              const Row(
                children: [
                  Expanded(
                    child: Text(
                      'WORLD RANKINGS',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    'BEST TIME',
                    style: TextStyle(
                      color: _muted,
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
                          icon: const Icon(Icons.refresh_rounded, color: _accent),
                          label: const Text(
                            'Retry',
                            style: TextStyle(color: _accent),
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
                          style: TextStyle(color: _muted, fontSize: 13),
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
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    decoration: BoxDecoration(
      color: highlighted ? _accentGlow : _panel,
      borderRadius: BorderRadius.circular(14),
      border: highlighted
          ? Border.all(color: _accent.withValues(alpha: 0.5))
          : Border.all(color: Colors.white.withValues(alpha: 0.04)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            rank == null ? 'YOU' : '#${rank!}',
            style: TextStyle(
              color: highlighted ? _accent : _muted,
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
            style: TextStyle(
              color: highlighted ? Colors.white : _muted,
              fontSize: 12,
              fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            fontFeatures: [],
          ),
        ),
      ],
    ),
  );
}

class _ShopTab extends StatefulWidget {
  const _ShopTab({
    required this.premiumUnlocked,
    required this.signIn,
    required this.onRestore,
  });
  final bool premiumUnlocked;
  final Future<GoogleSignInAccount?> Function() signIn;
  final VoidCallback onRestore;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.rocket_launch_rounded, color: _accent, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Coming soon — payments aren\'t live yet. Stay tuned!',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: _panel,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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
              const _PageTitle(kicker: 'HANGAR STORE', title: 'Shop'),
              const SizedBox(height: 20),

              _PremiumPackCard(
                aircraftList: premiumAircraft,
                unlocked: widget.premiumUnlocked,
                signedInAccount: _account,
                signingIn: _signingIn,
                onSignIn: _handleSignIn,
                onPurchase: _handlePurchase,
                onRestore: widget.onRestore,
              ),

              const SizedBox(height: 20),
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
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _navy,
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
                        const Text(
                          'PREMIUM FLEET PASS',
                          style: TextStyle(
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
                            child: const Row(
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
                                  style: TextStyle(
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
                      style: const TextStyle(
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
                    const Text(
                      '\$5.99',
                      style: TextStyle(
                        color: Colors.white,
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
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
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
                                color: _navy,
                              ),
                            )
                          : const Icon(Icons.login_rounded, size: 18),
                      label: Text(signingIn ? 'Signing in…' : 'Sign in with Google'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
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
                      color: _panelLight,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'Signed in',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
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
                      label: const Text('CLAIM YOUR SEAT'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
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
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF66BB6A),
                        size: 38,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You own all premium aircraft.',
                        style: TextStyle(
                          color: Colors.white,
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

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: _accent, size: 16),
      const SizedBox(width: 10),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.kicker, required this.title});
  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        kicker,
        style: const TextStyle(
          color: _accent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    ],
  );
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
          style: TextStyle(
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

String _formatTime(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  final fraction = milliseconds % 1000;
  return '${seconds.toString().padLeft(3, '0')}.${fraction.toString().padLeft(3, '0')}';
}
