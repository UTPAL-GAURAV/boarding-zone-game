import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../audio/app_audio.dart';
import 'boarding_simulation.dart';
import 'cabin_game.dart';
import 'aircraft_layout.dart';
import 'levels/level_4abreast.dart';
import 'tutorial_overlay.dart';

// ─── Adaptive color tokens ─────────────────────────────────────────────────

class _C {
  _C._(this._dark);
  final bool _dark;

  Color get bg => _dark ? const Color(0xFF060A1C) : const Color(0xFFEDF3FF);
  Color get surface => _dark ? const Color(0xFF152240) : const Color(0xFFFFFFFF);
  Color get surfaceElevated =>
      _dark ? const Color(0xFF1A2B4E) : const Color(0xFFF0F5FF);
  Color get border =>
      _dark ? const Color(0xFF2A4070) : const Color(0xFFCDD7F0);
  Color get ink => _dark ? const Color(0xFFE8F0FF) : const Color(0xFF0A1628);
  Color get muted => _dark ? const Color(0xFF6A85AA) : const Color(0xFF7A8BAA);
  Color get dimPanel =>
      _dark ? const Color(0xFF0C1428) : const Color(0xFFD8E4F8);

  // Accents stay the same in both modes.
  static const Color accent = Color(0xFFFFB930);
  static const Color accentBlue = Color(0xFF4A9EFF);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFFF4C4C);
}

// ─── Main page widget ───────────────────────────────────────────────────────

class BoardingGamePage extends StatefulWidget {
  const BoardingGamePage({
    super.key,
    required this.aircraftName,
    this.aircraftImageAsset,
    this.layout = Level4Abreast.aircraft,
    this.initialZones,
    this.onZonesChanged,
    this.onCompleted,
    this.onNext,
    this.previewOnly = false,
    this.onUnlockTap,
    this.previousBestMilliseconds,
    this.tutorialMode = false,
    this.targetSeconds,
  });

  final String aircraftName;
  final String? aircraftImageAsset;
  final AircraftLayout layout;
  final List<int>? initialZones;
  final Future<void> Function(List<int> zones)? onZonesChanged;
  final Future<void> Function(int milliseconds)? onCompleted;
  final Future<void> Function()? onNext;
  final bool previewOnly;
  final VoidCallback? onUnlockTap;
  final int? previousBestMilliseconds;
  final bool tutorialMode;
  final int? targetSeconds;

  @override
  State<BoardingGamePage> createState() => _BoardingGamePageState();
}

class _BoardingGamePageState extends State<BoardingGamePage>
    with SingleTickerProviderStateMixin {
  late final BoardingSimulation _simulation;
  late final CabinGame _game;
  late final ScrollController _cabinScrollController;
  late final ScrollController _cabinHScrollController;
  late final AnimationController _pulseController;
  late List<int> _lastSavedZones;
  Future<void>? _completionSave;
  int _selectedZone = 0;
  bool _reportedCompletion = false;
  bool _isNewRecord = false;
  bool _timedOut = false;
  bool _paintPointerActive = false;
  double _lastPointerGlobalY = 0;
  double _lastPointerGlobalX = 0;
  int? _currentBestMilliseconds;
  int? _previousBestMilliseconds;
  int _tutorialStep = 0;
  int _tutZoneACnt = 0;
  int _tutZoneBCnt = 0;
  int? _tutBoardingTimeMs;
  double _cabinNoseSpacerH = 0;
  final _stackKey = GlobalKey();
  final _timerCardKey = GlobalKey();
  final _boardedPillKey = GlobalKey();
  final _bestPillKey = GlobalKey();
  final _zoneRowKey = GlobalKey();
  final _zoneBChipKey = GlobalKey();
  final _cabinKey = GlobalKey();
  Map<TutorialStep, Rect> _anatomyRects = {};

  static const _zones = CabinGame.zoneColors;

  @override
  void initState() {
    super.initState();
    _selectedZone = 0;
    _cabinScrollController = ScrollController();
    _cabinHScrollController = ScrollController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _simulation = BoardingSimulation(
      layout: widget.layout,
      initialZones: widget.initialZones,
    );
    _currentBestMilliseconds = widget.previousBestMilliseconds;
    _previousBestMilliseconds = widget.previousBestMilliseconds;
    _lastSavedZones = _zoneSnapshot();
    _game = CabinGame(simulation: _simulation, onChanged: _refresh);
    if (widget.tutorialMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _computeAnatomyRects());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.isDark = Theme.of(context).brightness == Brightness.dark;
  }

  @override
  void dispose() {
    _cabinScrollController.dispose();
    _cabinHScrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  _C get _c =>
      _C._(Theme.of(context).brightness == Brightness.dark);

  void _refresh() {
    _saveZonesWhenChanged();
    if (widget.tutorialMode) {
      final step = _tutorialStep < TutorialStep.values.length
          ? TutorialStep.values[_tutorialStep]
          : null;
      if (step == TutorialStep.boardNow && _simulation.isBoarding) {
        // Boarding started — dismiss overlay so simulation runs unobstructed.
        setState(() => _tutorialStep = TutorialStep.values.length);
      }
      if (step == null && _simulation.isComplete) {
        final ms = (_simulation.elapsedSeconds * 1000).round();
        setState(() {
          _tutBoardingTimeMs = ms;
          _tutorialStep = TutorialStep.debrief.index;
        });
      }
    }
    if (_simulation.isComplete && !_reportedCompletion) {
      _reportedCompletion = true;
      final ms = (_simulation.elapsedSeconds * 1000).round();
      final prev = _currentBestMilliseconds;
      _previousBestMilliseconds = prev;
      _isNewRecord = prev == null || ms < prev;
      if (_isNewRecord) _currentBestMilliseconds = ms;
      if (!widget.tutorialMode) _completionSave = widget.onCompleted?.call(ms);
    }
    if (_simulation.isBoarding &&
        !_simulation.isComplete &&
        !_timedOut &&
        _simulation.elapsedSeconds >= 600) {
      _timedOut = true;
      _game.paused = true;
    }
    if (mounted) setState(() {});
  }

  void _reset() {
    _simulation.resetToDefaultZones();
    _selectedZone = 0;
    _refresh();
  }

  void _replay() {
    _simulation.reset();
    _reportedCompletion = false;
    _isNewRecord = false;
    _timedOut = false;
    _game.paused = false;
    _completionSave = null;
    if (mounted) setState(() => _selectedZone = 0);
  }

  void _advanceTutorial() {
    if (!widget.tutorialMode) return;
    final step = TutorialStep.values[_tutorialStep];
    if (step == TutorialStep.paintZoneA && _tutZoneACnt < 4) return;
    if (step == TutorialStep.paintZoneB && _tutZoneBCnt < 3) return;
    final next = _tutorialStep + 1;
    if (next >= TutorialStep.values.length) {
      _finishTutorial();
      return;
    }
    setState(() => _tutorialStep = next);
    // When entering anatomySeats or paintZoneA, scroll cabin to show seat rows.
    final nextStep = TutorialStep.values[next];
    if (nextStep == TutorialStep.anatomySeats ||
        nextStep == TutorialStep.paintZoneA) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_cabinScrollController.hasClients) {
          final max = _cabinScrollController.position.maxScrollExtent;
          // Use noseSpacerH if already captured, else fall back to 55% of max.
          final target = _cabinNoseSpacerH > 0
              ? (_cabinNoseSpacerH + 60).clamp(0.0, max)
              : (max * 0.55).clamp(0.0, max);
          _cabinScrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _tutorialReplay() {
    _replay();
    setState(() {
      _tutorialStep = TutorialStep.paintZoneA.index;
      _tutZoneACnt = 0;
      _tutZoneBCnt = 0;
      _tutBoardingTimeMs = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cabinScrollController.hasClients) {
        final max = _cabinScrollController.position.maxScrollExtent;
        final target = _cabinNoseSpacerH > 0
            ? (_cabinNoseSpacerH + 60).clamp(0.0, max)
            : (max * 0.55).clamp(0.0, max);
        _cabinScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _finishTutorial() {
    widget.onCompleted?.call(0);
    Navigator.of(context).pop();
  }

  List<int> _zoneSnapshot() => [for (final s in _simulation.seats) s.zone];

  void _saveZonesWhenChanged() {
    final zones = _zoneSnapshot();
    if (zones.length == _lastSavedZones.length &&
        List.generate(zones.length, (i) => i)
            .every((i) => zones[i] == _lastSavedZones[i])) return;
    _lastSavedZones = zones;
    if (widget.tutorialMode) {
      final zoneA = zones.where((z) => z == 0).length;
      final zoneB = zones.where((z) => z == 1).length;
      if (zoneA != _tutZoneACnt || zoneB != _tutZoneBCnt) {
        setState(() {
          _tutZoneACnt = zoneA;
          _tutZoneBCnt = zoneB;
        });
      }
    }
    final cb = widget.onZonesChanged;
    if (cb != null) unawaited(cb(List.unmodifiable(zones)));
  }

  void _computeAnatomyRects() {
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;
    Rect? getRect(GlobalKey key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return null;
      final pos = box.localToGlobal(Offset.zero, ancestor: stackBox);
      return pos & box.size;
    }
    final rects = <TutorialStep, Rect>{};
    final timer = getRect(_timerCardKey);
    if (timer != null) rects[TutorialStep.anatomyTime] = timer;
    final boarded = getRect(_boardedPillKey);
    if (boarded != null) rects[TutorialStep.anatomyBoarded] = boarded;
    final best = getRect(_bestPillKey);
    if (best != null) rects[TutorialStep.anatomyBest] = best;
    final zones = getRect(_zoneRowKey);
    if (zones != null) rects[TutorialStep.anatomyZones] = zones;
    final cabin = getRect(_cabinKey);
    if (cabin != null) rects[TutorialStep.anatomySeats] = cabin;
    final zoneB = getRect(_zoneBChipKey);
    if (zoneB != null) rects[TutorialStep.paintZoneB] = zoneB;
    if (mounted) setState(() => _anatomyRects = rects);
  }

  Future<void> _backToFleet() async {
    await widget.onZonesChanged?.call(List.unmodifiable(_zoneSnapshot()));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _nextFlight() async {
    await _completionSave;
    await widget.onZonesChanged?.call(List.unmodifiable(_zoneSnapshot()));
    await widget.onNext?.call();
    if (mounted) Navigator.of(context).pop();
  }

  String _zoneLabel(int index) => String.fromCharCode(65 + index);

  String get _timer {
    final ms = (_simulation.elapsedSeconds * 1000).floor();
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
  }

  bool get _isOverTarget {
    final t = widget.targetSeconds;
    if (t == null) return false;
    return (_simulation.elapsedSeconds * 1000).floor() > t * 1000;
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
  }

  double get _boardingProgress =>
      _simulation.passengerCount == 0
          ? 0
          : _simulation.boardedCount / _simulation.passengerCount;

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final complete = _simulation.isComplete;
    final tutStep = widget.tutorialMode && _tutorialStep < TutorialStep.values.length
        ? TutorialStep.values[_tutorialStep]
        : null;

    // Scale the top panel and bottom bar down proportionally on small screens.
    final screenW = MediaQuery.of(context).size.width;
    // Design baseline is 411dp; clamp scale to [0.82, 1.0].
    final uiScale = (screenW / 411.0).clamp(0.82, 1.0);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                _ScaledSection(
                  scale: uiScale,
                  child: Column(
                    children: [
                      _buildHeader(c),
                      _buildTimerHero(c),
                      _buildZoneSelector(c),
                    ],
                  ),
                ),
                Expanded(child: _buildCabin(c, complete)),
                _ScaledSection(
                  scale: uiScale,
                  child: _buildBottomBar(c, complete),
                ),
              ],
            ),
            if (tutStep != null)
              Positioned.fill(
                child: TutorialOverlay(
                  step: tutStep,
                  zoneACnt: _tutZoneACnt,
                  zoneBCnt: _tutZoneBCnt,
                  boardingTimeMs: _tutBoardingTimeMs,
                  highlightRect: _anatomyRects[tutStep],
                  onDismiss: tutStep == TutorialStep.graduation
                      ? _finishTutorial
                      : _advanceTutorial,
                  onReplay: _tutorialReplay,
                ),
              ),
            if (complete && !widget.tutorialMode)
              Positioned.fill(child: _buildCompletionOverlay(c)),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(_C c) {
    final imageAsset = widget.aircraftImageAsset;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _IconButton(
            icon: Icons.arrow_back_rounded,
            c: c,
            onTap: () => unawaited(_backToFleet()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.aircraftName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.rajdhani(
                color: c.ink,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (widget.targetSeconds != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _C.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _C.accent.withValues(alpha: 0.35), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded,
                      size: 11, color: _C.accent.withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  Text(
                    _formatMs(widget.targetSeconds! * 1000),
                    style: GoogleFonts.spaceMono(
                      color: _C.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (imageAsset != null) ...[
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.asset(
                  imageAsset,
                  width: 54,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _e, _st) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          _IconButton(
            icon: Icons.restart_alt_rounded,
            c: c,
            onTap: _reset,
            tooltip: 'Reset zones',
          ),
        ],
      ),
    );
  }

  // ─── Timer hero ──────────────────────────────────────────────────────────

  Widget _buildTimerHero(_C c) {
    final boarding = _simulation.isBoarding;
    final timerColor = _isOverTarget
        ? _C.danger
        : boarding
            ? c.ink
            : c.muted;

    final best = _currentBestMilliseconds;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Column(
        children: [
          // ── Full-width timer ──────────────────────────────────────────────
          Container(
            key: _timerCardKey,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: boarding
                    ? (_isOverTarget
                        ? _C.danger.withValues(alpha: 0.6)
                        : _C.accentBlue.withValues(alpha: 0.45))
                    : c.border,
                width: boarding ? 1.5 : 1,
              ),
              boxShadow: boarding
                  ? [
                      BoxShadow(
                        color: (_isOverTarget ? _C.danger : _C.accentBlue)
                            .withValues(alpha: 0.15),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: boarding
                      ? (_isOverTarget ? _C.danger : _C.accentBlue)
                      : c.muted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TIME',
                        style: GoogleFonts.rajdhani(
                          color: c.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                      Text(
                        _timer,
                        style: GoogleFonts.spaceMono(
                          color: timerColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (boarding && _simulation.currentEntryZone != null)
                  _ZoneBadge(
                    label: _zoneLabel(_simulation.currentEntryZone!),
                    color: CabinGame.zoneColors[_simulation.currentEntryZone!],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // ── Two stat pills ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                key: _boardedPillKey,
                child: _StatPill(
                  icon: Icons.airline_seat_recline_normal_rounded,
                  iconColor: _C.accent,
                  label: 'SEATED',
                  value:
                      '${_simulation.boardedCount} / ${_simulation.passengerCount}',
                  progress: _boardingProgress,
                  c: c,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                key: _bestPillKey,
                child: _StatPill(
                  icon: Icons.emoji_events_outlined,
                  iconColor: _C.accent,
                  label: 'BEST',
                  value: best != null ? _formatMs(best) : '—',
                  valueColor: best != null ? _C.accent : null,
                  c: c,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Zone selector ───────────────────────────────────────────────────────

  Widget _buildZoneSelector(_C c) {
    return Padding(
      key: _zoneRowKey,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          Text(
            'ZONE',
            style: GoogleFonts.rajdhani(
              color: c.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                for (var z = 0; z < _simulation.layout.zoneCount; z++)
                  Expanded(
                    key: z == 1 ? _zoneBChipKey : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _ZoneChip(
                        label: _zoneLabel(z),
                        color: _zones[z],
                        selected: z == _selectedZone,
                        onTap: () {
                          if (widget.tutorialMode &&
                              _tutorialStep < TutorialStep.paintZoneA.index) {
                            return;
                          }
                          setState(() => _selectedZone = z);
                        },
                        darkMode: Theme.of(context).brightness == Brightness.dark,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cabin ───────────────────────────────────────────────────────────────

  Widget _buildCabin(_C c, bool complete) {
    return Padding(
      key: _cabinKey,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final designW = _simulation.layout.designWidth;
              final designH = _simulation.layout.designHeight;
              final cabinShellW = _simulation.layout.cabinShell.width;
              final entranceDoorY = _simulation.layout.entranceDoorY;
              final noseScale = cabinShellW / 417.0;
              final noseAboveDesign = ((15.0 + 412.0) * noseScale - entranceDoorY).clamp(0.0, double.infinity);
              final scale = designW > constraints.maxWidth
                  ? 1.0
                  : constraints.maxWidth / designW;
              final contentW = designW * scale;
              final contentH = designH * scale;
              final noseSpacerH = noseAboveDesign * scale;
              // Extra scroll space below the game canvas for the tail image
              final tailScale = cabinShellW / 289.0;
              final bodyBottomDesign = _simulation.layout.rowStartY +
                  (_simulation.layout.rowCount - 1) * _simulation.layout.rowSpacing +
                  _simulation.layout.seatHeight / 2.0 +
                  14.0;
              // Tail image starts 14 units before bodyBottom (at lastRowBottom)
              final tailTopDesign = bodyBottomDesign - 14.0;
              final tailDestHDesign = 428.0 * tailScale;
              final tailBelowDesign = (tailTopDesign + tailDestHDesign - designH).clamp(0.0, double.infinity);
              final tailSpacerH = tailBelowDesign * scale;
              final needsHScroll = contentW > constraints.maxWidth + 1;
              final needsVScroll = contentH + noseSpacerH + tailSpacerH > constraints.maxHeight + 1;
              // Capture nose spacer height for tutorial scroll targeting (no setState — read-only).
              if (_cabinNoseSpacerH != noseSpacerH) _cabinNoseSpacerH = noseSpacerH;
              return Stack(
                fit: StackFit.expand,
                children: [
                  SingleChildScrollView(
                    controller: _cabinHScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      width: contentW,
                      child: Scrollbar(
                        controller: _cabinScrollController,
                        thumbVisibility: needsVScroll,
                        child: SingleChildScrollView(
                          controller: _cabinScrollController,
                          physics: const NeverScrollableScrollPhysics(),
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (e) {
                              if (widget.tutorialMode &&
                                  _tutorialStep < TutorialStep.paintZoneA.index) {
                                return;
                              }
                              final gameY = e.localPosition.dy - noseSpacerH;
                              _paintPointerActive = _game.beginPaintingAt(
                                  Offset(e.localPosition.dx, gameY), _selectedZone);
                              _lastPointerGlobalY = e.position.dy;
                              _lastPointerGlobalX = e.position.dx;
                            },
                            onPointerMove: (e) {
                              if (widget.tutorialMode &&
                                  _tutorialStep < TutorialStep.paintZoneA.index) {
                                return;
                              }
                              final gameY = e.localPosition.dy - noseSpacerH;
                              if (_paintPointerActive) {
                                _game.continuePaintingAt(
                                    Offset(e.localPosition.dx, gameY), _selectedZone);
                              } else {
                                if (_cabinScrollController.hasClients) {
                                  final dy = _lastPointerGlobalY - e.position.dy;
                                  _cabinScrollController.jumpTo(
                                    (_cabinScrollController.offset + dy).clamp(
                                        0.0,
                                        _cabinScrollController.position.maxScrollExtent),
                                  );
                                }
                                if (needsHScroll && _cabinHScrollController.hasClients) {
                                  final dx = _lastPointerGlobalX - e.position.dx;
                                  _cabinHScrollController.jumpTo(
                                    (_cabinHScrollController.offset + dx).clamp(
                                        0.0,
                                        _cabinHScrollController.position.maxScrollExtent),
                                  );
                                }
                              }
                              _lastPointerGlobalY = e.position.dy;
                              _lastPointerGlobalX = e.position.dx;
                            },
                            onPointerUp: (_) {
                              _paintPointerActive = false;
                              _game.endPainting();
                            },
                            onPointerCancel: (_) {
                              _paintPointerActive = false;
                              _game.endPainting();
                            },
                            child: SizedBox(
                              width: contentW,
                              height: contentH + noseSpacerH + tailSpacerH,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned(
                                    top: noseSpacerH,
                                    left: 0,
                                    width: contentW,
                                    height: contentH + tailSpacerH,
                                    child: GameWidget(game: _game),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_timedOut) _buildTimeoutOverlay(c),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Bottom bar ──────────────────────────────────────────────────────────

  Widget _buildBottomBar(_C c, bool complete) {
    final boarding = _simulation.isBoarding;
    final preview = widget.previewOnly;
    final tutorialBlocked = widget.tutorialMode &&
        _tutorialStep < TutorialStep.values.indexOf(TutorialStep.boardNow);

    final inactive = boarding || complete || _timedOut || tutorialBlocked || preview;

    String label;
    IconData icon;
    if (preview) {
      label = 'PREMIUM — UNLOCK TO BOARD';
      icon = Icons.lock_rounded;
    } else if (complete) {
      label = 'FLIGHT COMPLETE';
      icon = Icons.check_circle_outline_rounded;
    } else if (_timedOut) {
      label = 'BOARDING FAILED';
      icon = Icons.block_rounded;
    } else if (boarding) {
      label = 'BOARDING IN PROGRESS…';
      icon = Icons.flight_rounded;
    } else {
      label = 'START BOARDING';
      icon = Icons.flight_takeoff_rounded;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_simulation.isBoarding && !complete && !_timedOut) ...[
            Text(
              'Tap or drag seats to paint · Zone ${_zoneLabel(_selectedZone)} active',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.rajdhani(
                color: c.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ] else if (_simulation.isBoarding && !complete) ...[
            Text(
              _simulation.currentEntryZone != null
                  ? 'Zone ${_zoneLabel(_simulation.currentEntryZone!)} boarding · ${_simulation.waitingCount} waiting'
                  : 'Final passengers seating…',
              style: GoogleFonts.rajdhani(
                color: c.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
          ],
          SizedBox(
            height: 52,
            width: double.infinity,
            child: inactive
                ? _InactiveButton(
                    label: label,
                    icon: icon,
                    c: c,
                    onTap: (preview && !tutorialBlocked)
                        ? () {
                            Navigator.of(context).pop();
                            widget.onUnlockTap?.call();
                          }
                        : null,
                  )
                : _ActiveButton(
                    label: label,
                    icon: icon,
                    onTap: () {
                      _simulation.start();
                      unawaited(AppAudio.instance.playBleep());
                      _refresh();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Completion overlay ──────────────────────────────────────────────────

  Widget _buildCompletionOverlay(_C c) {
    return Container(
      color: (c._dark ? Colors.black : c.bg).withValues(alpha: c._dark ? 0.72 : 0.80),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isOverTarget
                  ? _C.danger.withValues(alpha: 0.4)
                  : _isNewRecord
                      ? _C.accent.withValues(alpha: 0.5)
                      : _C.success.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isOverTarget
                        ? _C.danger
                        : _isNewRecord
                            ? _C.accent
                            : _C.success)
                    .withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _CompletionContent(
            isOverTarget: _isOverTarget,
            isNewRecord: _isNewRecord,
            timer: _timer,
            previousBest: _previousBestMilliseconds,
            currentBest: _currentBestMilliseconds,
            passengerCount: _simulation.passengerCount,
            formatMs: _formatMs,
            onReplay: _replay,
            onNext: () => unawaited(_nextFlight()),
            c: c,
          ),
        ),
      ),
    );
  }

  // ─── Timeout overlay ─────────────────────────────────────────────────────

  Widget _buildTimeoutOverlay(_C c) {
    final remaining = _simulation.passengerCount - _simulation.boardedCount;
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
        color: (c._dark ? Colors.black : c.bg).withValues(alpha: c._dark ? 0.70 : 0.80),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _C.danger.withValues(alpha: 0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _C.danger.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ResultIcon(
                    icon: Icons.flight_land_rounded,
                    color: _C.danger,
                    bgColor: _C.danger.withValues(alpha: 0.12)),
                const SizedBox(height: 12),
                Text(
                  'BOARDING FAILED',
                  style: GoogleFonts.rajdhani(
                    color: _C.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You made boarding impossible!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.rajdhani(
                    color: c.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$remaining passenger${remaining == 1 ? '' : 's'} missed their flight.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  'The captain has filed a strongly-worded complaint.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _OutlineBtn(
                        label: 'TRY AGAIN',
                        icon: Icons.replay_rounded,
                        c: c,
                        onTap: _replay,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: _PrimaryBtn(
                        label: 'NEXT FLIGHT',
                        icon: Icons.skip_next_rounded,
                        onTap: () => widget.onNext?.call(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Completion content (extracted for cleanliness) ──────────────────────────

class _CompletionContent extends StatelessWidget {
  const _CompletionContent({
    required this.isOverTarget,
    required this.isNewRecord,
    required this.timer,
    required this.previousBest,
    required this.currentBest,
    required this.passengerCount,
    required this.formatMs,
    required this.onReplay,
    required this.onNext,
    required this.c,
  });

  final bool isOverTarget;
  final bool isNewRecord;
  final String timer;
  final int? previousBest;
  final int? currentBest;
  final int passengerCount;
  final String Function(int) formatMs;
  final VoidCallback onReplay;
  final VoidCallback onNext;
  final _C c;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: (isOverTarget ? _C.danger : isNewRecord ? _C.accent : _C.success)
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: (isOverTarget
                      ? _C.danger
                      : isNewRecord
                          ? _C.accent
                          : _C.success)
                  .withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOverTarget
                    ? Icons.warning_amber_rounded
                    : isNewRecord
                        ? Icons.emoji_events_rounded
                        : Icons.check_circle_rounded,
                size: 13,
                color: isOverTarget
                    ? _C.danger
                    : isNewRecord
                        ? _C.accent
                        : _C.success,
              ),
              const SizedBox(width: 5),
              Text(
                isOverTarget
                    ? 'OVER TARGET'
                    : previousBest == null
                        ? 'FIRST RUN'
                        : isNewRecord
                            ? 'NEW RECORD'
                            : 'COMPLETED',
                style: GoogleFonts.rajdhani(
                  color: isOverTarget
                      ? _C.danger
                      : isNewRecord
                          ? _C.accent
                          : _C.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ResultIcon(
          icon: isOverTarget
              ? Icons.sentiment_very_dissatisfied_rounded
              : isNewRecord
                  ? Icons.emoji_events_rounded
                  : Icons.check_rounded,
          color: isOverTarget
              ? _C.danger
              : isNewRecord
                  ? _C.accent
                  : _C.success,
          bgColor: (isOverTarget
                  ? _C.danger
                  : isNewRecord
                      ? _C.accent
                      : _C.success)
              .withValues(alpha: 0.12),
        ),
        const SizedBox(height: 14),
        Text(
          isOverTarget ? 'Over time!' : 'All aboard!',
          style: GoogleFonts.rajdhani(
            color: c.ink,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isOverTarget
              ? 'Everyone seated — but the captain isn\'t happy.'
              : 'Every passenger is seated.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        // Time display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: c.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Column(
                  children: [
                    Text(
                      'YOUR TIME',
                      style: GoogleFonts.rajdhani(
                        color: c.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        timer,
                        style: GoogleFonts.spaceMono(
                          color: isOverTarget ? _C.danger : c.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (currentBest != null && !isOverTarget) ...[
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  color: c.border,
                ),
                Flexible(
                  child: Column(
                    children: [
                      Text(
                        'BEST',
                        style: GoogleFonts.rajdhani(
                          color: c.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatMs(currentBest!),
                          style: GoogleFonts.spaceMono(
                            color: _C.accent,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isOverTarget) ...[
          const SizedBox(height: 6),
          Text(
            'Adjust your zones and go again.',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        if (isOverTarget)
          SizedBox(
            width: double.infinity,
            child: _OutlineBtn(
              label: 'TRY AGAIN',
              icon: Icons.replay_rounded,
              c: c,
              onTap: onReplay,
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _OutlineBtn(
                  label: 'REPLAY',
                  icon: Icons.replay_rounded,
                  c: c,
                  onTap: onReplay,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _PrimaryBtn(
                  label: 'NEXT FLIGHT',
                  icon: Icons.arrow_forward_rounded,
                  onTap: onNext,
                ),
              ),
            ],
          ),
      ],
      ),
    );
  }
}

// ─── Shared UI atoms ─────────────────────────────────────────────────────────

class _ResultIcon extends StatelessWidget {
  const _ResultIcon({
    required this.icon,
    required this.color,
    required this.bgColor,
  });
  final IconData icon;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) => Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Icon(icon, color: color, size: 34),
      );
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.c,
    required this.onTap,
    this.tooltip,
  });
  final IconData icon;
  final _C c;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border),
              ),
              child: Icon(icon, color: c.ink, size: 20),
            ),
          ),
        ),
      );
}

class _ZoneChip extends StatelessWidget {
  const _ZoneChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.darkMode,
  });
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    // High-luminance colors (e.g. yellow) are near-invisible against a light
    // background. In light mode, darken them to 30 % HSL lightness so the
    // chip border and label are always readable.
    final displayColor = !darkMode && color.computeLuminance() > 0.6
        ? HSLColor.fromColor(color).withLightness(0.30).toColor()
        : color;
    return Semantics(
        button: true,
        selected: selected,
        label: 'Zone $label',
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 38,
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.22)
                  : color.withValues(alpha: darkMode ? 0.07 : 0.1),
              border: Border.all(
                color: selected ? displayColor : displayColor.withValues(alpha: 0.45),
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: displayColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    color: selected ? displayColor : displayColor.withValues(alpha: 0.75),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (selected)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      color: displayColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
  }
}

class _ActiveButton extends StatelessWidget {
  const _ActiveButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD060), Color(0xFFFFAA00)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55FFB930),
              blurRadius: 16,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF1A0A00),
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

class _InactiveButton extends StatelessWidget {
  const _InactiveButton({
    required this.label,
    required this.icon,
    required this.c,
    this.onTap,
  });
  final String label;
  final IconData icon;
  final _C c;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.rajdhani(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: c.muted,
            shadowColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.c,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final _C c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.rajdhani(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: c.ink,
          side: BorderSide(color: c.border, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD060), Color(0xFFFFAA00)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: GoogleFonts.rajdhani(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.8,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: const Color(0xFF1A0A00),
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}

// ─── _StatPill ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.c,
    this.progress,
    this.valueColor,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final _C c;
  final double? progress;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: iconColor),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: GoogleFonts.rajdhani(
                    color: c.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: GoogleFonts.spaceMono(
                  color: valueColor ?? c.ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: c.dimPanel,
                  valueColor: AlwaysStoppedAnimation(iconColor),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      );
}

// ─── _ZoneBadge ───────────────────────────────────────────────────────────────

class _ZoneBadge extends StatelessWidget {
  const _ZoneBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ZONE',
              style: GoogleFonts.rajdhani(
                color: color.withValues(alpha: 0.7),
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.rajdhani(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      );
}

/// Scales [child] uniformly by [scale], reclaiming the reduced layout height
/// so the surrounding Column sees the shrunken size, not the original.
class _ScaledSection extends StatelessWidget {
  const _ScaledSection({required this.scale, required this.child});
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale >= 1.0) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth / scale,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
