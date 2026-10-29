import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../boarding/boarding_game_page.dart';
import 'aircraft.dart';
import 'aircraft_level_registry.dart';
import 'local_profile_store.dart';
import 'manufacturer_brand_assets.dart';

const _navy = Color(0xFF101923);
const _panel = Color(0xFF1A2633);
const _panelLight = Color(0xFF223242);
const _muted = Color(0xFF9BAAB8);
const _accent = Color(0xFF5EB8E8);

class BoardingHomeShell extends StatefulWidget {
  const BoardingHomeShell({super.key, this.store});

  final LocalProfileStore? store;

  @override
  State<BoardingHomeShell> createState() => _BoardingHomeShellState();
}

class _BoardingHomeShellState extends State<BoardingHomeShell> {
  late final LocalProfileStore _store;
  late final Future<PlayerProfile> _profileFuture;
  PlayerProfile? _profile;
  Map<String, int?> _bestTimes = {};
  Set<String> _unlockedAircraftIds = {};
  Set<String> _premiumOwnedAircraftIds = {};
  String _selectedId = 'cessna-grand-caravan-ex';
  int _destination = 0;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? LocalProfileStore();
    _profileFuture = _loadProfile();
  }

  Future<PlayerProfile> _loadProfile() async {
    await AircraftCatalog.load();
    final profile = await _store.loadProfile();
    final progress = await _store.loadFleetProgress(AircraftCatalog.all);
    final bestTimes = {
      for (final entry in progress.entries)
        entry.key: entry.value.bestTimeSeconds,
    };
    if (mounted) {
      setState(() {
        _profile = profile;
        _bestTimes = bestTimes;
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
    return profile;
  }

  bool _isUnlocked(Aircraft aircraft) {
    return aircraft.unlockType == AircraftUnlockType.free ||
        _unlockedAircraftIds.contains(aircraft.id) ||
        _premiumOwnedAircraftIds.contains(aircraft.id);
  }

  Future<void> _editCrewName() async {
    final current = _profile;
    if (current == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _ProfileDialog(initialName: current.displayName),
    );
    if (name == null || name.trim().isEmpty) return;
    await _store.saveDisplayName(name);
    if (mounted) setState(() => _profile = current.copyWith(displayName: name));
  }

  Future<void> _launchAircraft(Aircraft aircraft) async {
    final layout = AircraftLevelRegistry.resolve(aircraft);
    if (!_isUnlocked(aircraft)) {
      if (aircraft.unlockType == AircraftUnlockType.premium) {
        setState(() => _destination = 2);
      } else {
        _showLockedRequirement(aircraft);
      }
      return;
    }
    if (layout == null) {
      _showComingSoon(aircraft);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Theme(
          data: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF2F4F8),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3676CF),
            ),
            fontFamily: 'sans-serif',
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarIconBrightness: Brightness.dark,
              systemNavigationBarColor: Color(0xFFF2F4F8),
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: BoardingGamePage(
              layout: layout,
              onCompleted: (seconds) => _recordBestTime(aircraft, seconds),
            ),
          ),
        ),
      ),
    );
    await _reloadFleetProgress();
  }

  Future<void> _recordBestTime(Aircraft aircraft, int seconds) async {
    final progress = await _store.recordBoardingCompletion(
      aircraftId: aircraft.id,
      seconds: seconds,
      fleet: AircraftCatalog.all,
    );
    _applyFleetProgress(progress);
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
          entry.key: entry.value.bestTimeSeconds,
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
        title: Text(
          aircraft.displayName,
          style: const TextStyle(color: Colors.white),
        ),
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
        title: Text(
          aircraft.displayName,
          style: const TextStyle(color: Colors.white),
        ),
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
                    setState(() => _destination = 2);
                  } else {
                    _showLockedRequirement(aircraft);
                  }
                },
              ),
              _RankingsTab(
                crewName: crewMember.displayName,
                bestTimes: _bestTimes,
              ),
              _ShopTab(
                onPurchaseTap: (aircraft) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Purchases are not available yet.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFF151F2A),
          indicatorColor: _accent.withValues(alpha: 0.18),
          selectedIndex: _destination,
          onDestinationSelected: (value) =>
              setState(() => _destination = value),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.flight_outlined),
              selectedIcon: Icon(Icons.flight_rounded),
              label: 'Fleet',
            ),
            NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events_rounded),
              label: 'Rankings',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront_rounded),
              label: 'Shop',
            ),
          ],
        ),
      );
    },
  );
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.initialName});

  final String initialName;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: _panel,
    title: const Text('Crew profile', style: TextStyle(color: Colors.white)),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 24,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        labelText: 'Display name',
        labelStyle: TextStyle(color: _muted),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: _accent),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}

class _HomeTab extends StatelessWidget {
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
  Widget build(BuildContext context) => CustomScrollView(
    key: const PageStorageKey('fleet-scroll'),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        sliver: SliverList.list(
          children: [
            _HomeHeader(crewName: crewName, onTap: onProfileTap),
            const SizedBox(height: 36),
            const _PageTitle(kicker: 'SELECT YOUR AIRCRAFT', title: 'Fleet'),
            const SizedBox(height: 8),
            const Text(
              'Swipe through the hangar to choose your next flight.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 324,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: AircraftCatalog.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final aircraft = AircraftCatalog.all[index];
                  final unlocked = isUnlocked(aircraft);
                  return _AircraftTile(
                    aircraft: aircraft,
                    selected: aircraft.id == selected.id,
                    unlocked: unlocked,
                    bestSeconds: bestTimes[aircraft.id],
                    onTap: () {
                      if (aircraft.unlockType == AircraftUnlockType.premium &&
                          !unlocked) {
                        onLockedTap(aircraft);
                      } else if (unlocked) {
                        onSelect(aircraft);
                      } else {
                        onLockedTap(aircraft);
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
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
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
                          selected.displayName,
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
                    onPressed: isUnlocked(selected)
                        ? () => onPlay(selected)
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text('START FLIGHT'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: _navy,
                      disabledBackgroundColor: _panelLight,
                      disabledForegroundColor: _muted,
                      textStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
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
        child: const Icon(
          Icons.flight_takeoff_rounded,
          color: _accent,
          size: 23,
        ),
      ),
      const SizedBox(width: 11),
      const Expanded(
        child: Text(
          'Boarding Zone',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
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
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 19,
                backgroundColor: _panelLight,
                child: const Icon(
                  Icons.person_rounded,
                  color: _accent,
                  size: 21,
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
    required this.bestSeconds,
    required this.onTap,
  });

  final Aircraft aircraft;
  final bool selected;
  final bool unlocked;
  final int? bestSeconds;
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
        : bestSeconds != null
        ? 'COMPLETED'
        : 'AVAILABLE';
    final statusColor = premium ? const Color(0xFFF0B963) : _accent;
    final detail = !unlocked
        ? aircraft.unlockRequirement ?? aircraft.priceLabel ?? 'Locked aircraft'
        : !hasLevel
        ? 'LEVEL ${aircraft.level}  ·  ${aircraft.typicalSeats} SEATS  ·  IN DEVELOPMENT'
        : bestSeconds != null
        ? 'PERSONAL BEST  ${_formatTime(bestSeconds!)}'
        : 'LEVEL ${aircraft.level}  ·  ${aircraft.typicalSeats} SEATS  ·  TARGET ${_formatTime(aircraft.targetSeconds)}';

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
                color: selected
                    ? _accent
                    : Colors.white.withValues(alpha: 0.08),
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(22),
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
                      if (!unlocked) const _LockedPhotoOverlay(),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _Pill(
                          label: status,
                          icon: premium
                              ? Icons.workspace_premium_rounded
                              : !unlocked
                              ? Icons.lock_rounded
                              : bestSeconds != null
                              ? Icons.check_rounded
                              : Icons.flight_takeoff_rounded,
                          color: premium
                              ? statusColor
                              : !unlocked
                              ? Colors.white
                              : _accent,
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: _ManufacturerLogoBadge(
                          manufacturer: aircraft.manufacturer,
                        ),
                      ),
                      if (!unlocked)
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
                        Text(
                          aircraft.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                        const Spacer(),
                        Text(
                          detail,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unlocked ? _accent : Colors.white70,
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
  const _RankingsTab({required this.crewName, required this.bestTimes});
  final String crewName;
  final Map<String, int?> bestTimes;

  @override
  State<_RankingsTab> createState() => _RankingsTabState();
}

class _RankingsTabState extends State<_RankingsTab> {
  String _selectedId = 'cessna-grand-caravan-ex';

  static const _sampleRows = <String, List<(String, String)>>{
    'airbus-a320': [
      ('CloudRunner', '07:42'),
      ('JetLagZero', '08:06'),
      ('AeroAce', '08:19'),
      ('SkywardSam', '08:44'),
    ],
    'boeing-737': [
      ('RunwayRanger', '07:35'),
      ('NorthStar', '08:12'),
      ('WingSpan', '08:27'),
      ('TaxiwayTom', '08:58'),
    ],
    'airbus-a350': [
      ('LongHaulLee', '11:08'),
      ('CloudRunner', '11:31'),
      ('SeatbeltSam', '11:57'),
      ('AeroAce', '12:20'),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final aircraft = AircraftCatalog.byId(_selectedId);
    final samples =
        _sampleRows[_selectedId] ??
        const [
          ('SkywardSam', '09:12'),
          ('CloudRunner', '09:38'),
          ('AeroAce', '10:04'),
          ('RunwayRanger', '10:27'),
        ];
    final localTime = widget.bestTimes[_selectedId];
    return CustomScrollView(
      key: const PageStorageKey('rankings-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
          sliver: SliverList.list(
            children: [
              const _PageTitle(kicker: 'COMPETE', title: 'World Rankings'),
              const SizedBox(height: 8),
              const Text(
                'Boarding times are ranked separately for every aircraft.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF23384A),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: _accent, size: 17),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'PREVIEW DATA · Sample rankings only, not live results',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                      onSelected: (_) => setState(() => _selectedId = item.id),
                      selectedColor: _accent,
                      backgroundColor: _panel,
                      labelStyle: TextStyle(
                        color: active ? _navy : Colors.white70,
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
                      'PREVIEW LIST',
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
              for (var index = 0; index < samples.length; index++)
                _RankRow(
                  rank: index + 1,
                  name: samples[index].$1,
                  time: samples[index].$2,
                ),
              if (localTime != null) ...[
                const SizedBox(height: 10),
                _RankRow(
                  rank: null,
                  name: '${widget.crewName} · Your local best',
                  time: _formatTime(localTime),
                  highlighted: true,
                ),
              ],
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
      color: highlighted ? const Color(0xFF244257) : _panel,
      borderRadius: BorderRadius.circular(14),
      border: highlighted
          ? Border.all(color: _accent.withValues(alpha: 0.5))
          : null,
    ),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            rank == null ? 'YOU' : '#${rank!}',
            style: TextStyle(
              color: highlighted ? _accent : _muted,
              fontSize: rank == null ? 9 : 12,
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
              color: highlighted ? Colors.white : Colors.white70,
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

class _ShopTab extends StatelessWidget {
  const _ShopTab({required this.onPurchaseTap});
  final ValueChanged<Aircraft> onPurchaseTap;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: const PageStorageKey('shop-scroll'),
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
        sliver: SliverList.list(
          children: [
            const _PageTitle(kicker: 'HANGAR STORE', title: 'Aircraft Shop'),
            const SizedBox(height: 8),
            const Text(
              'Premium aircraft are optional. Purchases are not enabled in this build.',
              style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            for (final aircraft in AircraftCatalog.all.where(
              (item) => item.unlockType == AircraftUnlockType.premium,
            ))
              _ShopAircraftCard(
                aircraft: aircraft,
                onTap: () => onPurchaseTap(aircraft),
              ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Purchased aircraft will appear as Owned here.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: () => _showPhotoCredits(context),
                icon: const Icon(Icons.copyright_rounded, size: 15),
                label: const Text('Aircraft photo credits'),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

void _showPhotoCredits(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: _panel,
      title: const Text('Aircraft photo credits'),
      content: const SingleChildScrollView(
        child: SelectableText(
          'Airbus A320-200 — Ezbolor, CC BY-SA 3.0.\n'
          'commons.wikimedia.org/wiki/File:Airbus_A320-200.jpg\n\n'
          'Boeing 737-500 — MaxEddi, released to the public domain.\n'
          'commons.wikimedia.org/wiki/File:Boeing_B737.jpg\n\n'
          'Airbus A350-900 — pjs2005, CC BY-SA 2.0.\n'
          'commons.wikimedia.org/wiki/File:Airbus_A350_(28227541585).jpg\n\n'
          'The A320 and A350 photo files were resized for the game. Full license details are in assets/aircraft/ATTRIBUTION.md.',
          style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class _ShopAircraftCard extends StatelessWidget {
  const _ShopAircraftCard({required this.aircraft, required this.onTap});
  final Aircraft aircraft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(20),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 174,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AircraftPhoto(aircraft: aircraft),
              const _LockedPhotoOverlay(),
              Positioned(
                top: 13,
                right: 13,
                child: _Pill(
                  label: 'PREMIUM',
                  icon: Icons.workspace_premium_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                aircraft.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                aircraft.subtitle,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      aircraft.priceLabel ?? 'PRICE NOT SET',
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.lock_outline_rounded, size: 15),
                    label: const Text('Unlock'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
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
          fontWeight: FontWeight.w800,
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

String _formatTime(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
