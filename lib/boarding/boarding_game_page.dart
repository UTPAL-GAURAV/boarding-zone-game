import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'boarding_simulation.dart';
import 'cabin_game.dart';
import 'aircraft_layout.dart';
import 'levels/level_one.dart';

class BoardingGamePage extends StatefulWidget {
  const BoardingGamePage({
    super.key,
    required this.aircraftName,
    this.layout = LevelOne.aircraft,
    this.initialZones,
    this.onZonesChanged,
    this.onCompleted,
    this.onNext,
    this.previewOnly = false,
    this.onUnlockTap,
    this.previousBestMilliseconds,
  });

  final String aircraftName;
  final AircraftLayout layout;
  final List<int>? initialZones;
  final Future<void> Function(List<int> zones)? onZonesChanged;
  final Future<void> Function(int milliseconds)? onCompleted;
  final Future<void> Function()? onNext;
  /// When true the seat layout is visible but boarding cannot be started.
  final bool previewOnly;
  /// Called when the user taps "PREMIUM — UNLOCK TO BOARD" in preview mode.
  final VoidCallback? onUnlockTap;
  /// Personal best from previous runs, null if this is the first run.
  final int? previousBestMilliseconds;

  @override
  State<BoardingGamePage> createState() => _BoardingGamePageState();
}

class _BoardingGamePageState extends State<BoardingGamePage> {
  late final BoardingSimulation _simulation;
  late final CabinGame _game;
  late final ScrollController _cabinScrollController;
  late final ScrollController _cabinHScrollController;
  late List<int> _lastSavedZones;
  Future<void>? _completionSave;
  int _selectedZone = 5;
  bool _reportedCompletion = false;
  bool _isNewRecord = false;
  bool _paintPointerActive = false;
  double _lastPointerGlobalY = 0;
  double _lastPointerGlobalX = 0;

  static const _zones = CabinGame.zoneColors;
  static const _ink = Color(0xFF172B45);
  static const _muted = Color(0xFF73849A);

  @override
  void initState() {
    super.initState();
    _selectedZone = widget.layout.zoneCount - 1;
    _cabinScrollController = ScrollController();
    _cabinHScrollController = ScrollController();
    _simulation = BoardingSimulation(
      layout: widget.layout,
      initialZones: widget.initialZones,
    );
    _lastSavedZones = _zoneSnapshot();
    _game = CabinGame(simulation: _simulation, onChanged: _refresh);
  }

  void _refresh() {
    _saveZonesWhenChanged();
    if (_simulation.isComplete && !_reportedCompletion) {
      _reportedCompletion = true;
      final ms = (_simulation.elapsedSeconds * 1000).round();
      final prev = widget.previousBestMilliseconds;
      _isNewRecord = prev == null || ms < prev;
      _completionSave = widget.onCompleted?.call(ms);
    }
    if (mounted) setState(() {});
  }

  void _reset() {
    _simulation.resetToDefaultZones();
    _selectedZone = widget.layout.zoneCount - 1;
    _refresh();
  }

  @override
  void dispose() {
    _cabinScrollController.dispose();
    _cabinHScrollController.dispose();
    super.dispose();
  }

  List<int> _zoneSnapshot() => [
    for (final seat in _simulation.seats) seat.zone,
  ];

  void _saveZonesWhenChanged() {
    final zones = _zoneSnapshot();
    if (zones.length == _lastSavedZones.length &&
        List<int>.generate(
          zones.length,
          (index) => index,
        ).every((index) => zones[index] == _lastSavedZones[index])) {
      return;
    }
    _lastSavedZones = zones;
    final callback = widget.onZonesChanged;
    if (callback != null) unawaited(callback(List.unmodifiable(zones)));
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
    final milliseconds = (_simulation.elapsedSeconds * 1000).floor();
    final seconds = milliseconds ~/ 1000;
    final fraction = milliseconds % 1000;
    return '${seconds.toString().padLeft(3, '0')}.${fraction.toString().padLeft(3, '0')}';
  }

  String _formatMs(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final fraction = milliseconds % 1000;
    return '${seconds.toString().padLeft(3, '0')}.${fraction.toString().padLeft(3, '0')}';
  }

  String get _boardingStatus {
    if (!_simulation.isBoarding) {
      return 'Zone ${_zoneLabel(_selectedZone)} selected · tap or swipe seats to paint';
    }
    final zone = _simulation.currentEntryZone;
    if (zone != null) {
      return 'Zone ${_zoneLabel(zone)} boarding · ${_simulation.waitingCount} waiting';
    }
    return _simulation.isComplete
        ? 'All passengers seated'
        : 'Final passengers in cabin';
  }

  @override
  Widget build(BuildContext context) {
    final complete = _simulation.isComplete;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildStats(),
              const SizedBox(height: 10),
              _buildZoneLegend(),
              const SizedBox(height: 8),
              Expanded(child: _buildCabin(complete)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _boardingStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStartButton(complete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          Tooltip(
            message: 'Back to fleet',
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => unawaited(_backToFleet()),
                borderRadius: BorderRadius.circular(14),
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.arrow_back_rounded, color: _ink, size: 22),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.aircraftName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _reset,
              borderRadius: BorderRadius.circular(14),
              child: const Tooltip(
                message: 'Reset to default zones',
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(Icons.restart_alt_rounded, color: _ink, size: 22),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final best = widget.previousBestMilliseconds;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'TIME',
            value: _timer,
            icon: Icons.timer_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'BOARDED',
            value:
                '${_simulation.boardedCount} / ${_simulation.passengerCount}',
            icon: Icons.airline_seat_recline_normal_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            label: 'BEST',
            value: best != null ? _formatMs(best) : '—',
            icon: Icons.emoji_events_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildZoneLegend() {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          const Text(
            'ZONES',
            style: TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                for (var zone = 0; zone < _simulation.layout.zoneCount; zone++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _ZonePill(
                        zone: _zoneLabel(zone),
                        color: _zones[zone],
                        selected: zone == _selectedZone,
                        onTap: () => setState(() => _selectedZone = zone),
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

  Widget _buildCabin(bool complete) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0F6),
          border: Border.all(color: const Color(0xFFE1E7EE)),
          borderRadius: BorderRadius.circular(28),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final designW = _simulation.layout.designWidth;
            final designH = _simulation.layout.designHeight;
            // For narrow layouts fit to screen width; for wide ones use native
            // design width so seats stay the same physical size.
            final scale = designW > constraints.maxWidth
                ? 1.0
                : constraints.maxWidth / designW;
            final contentW = designW * scale;
            final contentH = designH * scale;
            final needsHScroll = contentW > constraints.maxWidth + 1;
            final needsVScroll = contentH > constraints.maxHeight + 1;
            return Stack(
              fit: StackFit.expand,
              children: [
                // Horizontal scroll wraps vertical scroll.
                SingleChildScrollView(
                  controller: _cabinHScrollController,
                  scrollDirection: Axis.horizontal,
                  // Physics controlled via pointer handling below.
                  physics: const NeverScrollableScrollPhysics(),
                  child: SizedBox(
                    width: contentW,
                    child: Scrollbar(
                      controller: _cabinScrollController,
                      thumbVisibility: needsVScroll,
                      child: SingleChildScrollView(
                        controller: _cabinScrollController,
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          width: contentW,
                          height: contentH,
                          child: Listener(
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: (event) {
                              _paintPointerActive = _game.beginPaintingAt(
                                event.localPosition,
                                _selectedZone,
                              );
                              _lastPointerGlobalY = event.position.dy;
                              _lastPointerGlobalX = event.position.dx;
                            },
                            onPointerMove: (event) {
                              if (_paintPointerActive) {
                                _game.continuePaintingAt(
                                  event.localPosition,
                                  _selectedZone,
                                );
                              } else {
                                // Vertical scroll
                                if (needsVScroll &&
                                    _cabinScrollController.hasClients) {
                                  final dy =
                                      _lastPointerGlobalY - event.position.dy;
                                  _cabinScrollController.jumpTo(
                                    (_cabinScrollController.offset + dy).clamp(
                                      0.0,
                                      _cabinScrollController
                                          .position.maxScrollExtent,
                                    ),
                                  );
                                }
                                // Horizontal scroll
                                if (needsHScroll &&
                                    _cabinHScrollController.hasClients) {
                                  final dx =
                                      _lastPointerGlobalX - event.position.dx;
                                  _cabinHScrollController.jumpTo(
                                    (_cabinHScrollController.offset + dx)
                                        .clamp(
                                          0.0,
                                          _cabinHScrollController
                                              .position.maxScrollExtent,
                                        ),
                                  );
                                }
                              }
                              _lastPointerGlobalY = event.position.dy;
                              _lastPointerGlobalX = event.position.dx;
                            },
                            onPointerUp: (_) {
                              _paintPointerActive = false;
                              _game.endPainting();
                            },
                            onPointerCancel: (_) {
                              _paintPointerActive = false;
                              _game.endPainting();
                            },
                            child: GameWidget(game: _game),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (complete) _buildCompletionCard(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCompletionCard() {
    return Container(
      color: const Color(0xA8172B45),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x4020334D),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: _isNewRecord
                    ? const Color(0xFFFFF8E1)
                    : const Color(0xFFE8F7EF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isNewRecord ? Icons.emoji_events_rounded : Icons.check_rounded,
                color: _isNewRecord
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF39A674),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'All aboard!',
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 25,
                letterSpacing: -0.5,
              ),
            ),
            if (_isNewRecord) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFF59E0B), size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.previousBestMilliseconds == null
                          ? 'FIRST RUN!'
                          : 'NEW RECORD!',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 7),
            Text(
              'Every passenger is seated in $_timer.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.4),
            ),
            if (!_isNewRecord && widget.previousBestMilliseconds != null) ...[
              const SizedBox(height: 4),
              Text(
                'Your best: ${_formatMs(widget.previousBestMilliseconds!)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
            if (_isNewRecord && widget.previousBestMilliseconds != null) ...[
              const SizedBox(height: 4),
              Text(
                'Previous best: ${_formatMs(widget.previousBestMilliseconds!)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            Text(
              '${_simulation.passengerCount} passengers boarded',
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ready for your next flight?',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => unawaited(_nextFlight()),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('NEXT FLIGHT'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3479D0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(bool complete) {
    final boarding = _simulation.isBoarding;
    final preview = widget.previewOnly;
    final label = preview
        ? 'PREMIUM — UNLOCK TO BOARD'
        : complete
        ? 'FLIGHT COMPLETE'
        : boarding
        ? 'BOARDING…'
        : 'START BOARDING';
    final inactive = boarding || complete;
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: inactive
                ? [const Color(0xFF7E8FA4), const Color(0xFF61758E)]
                : [const Color(0xFF3479D0), const Color(0xFF245BB1)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: inactive
              ? const []
              : const [
                  BoxShadow(
                    color: Color(0x30336EB8),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
        ),
        child: ElevatedButton.icon(
          onPressed: boarding || preview
              ? (preview
                  ? () {
                      Navigator.of(context).pop();
                      widget.onUnlockTap?.call();
                    }
                  : null)
              : () {
                  _simulation.start();
                  _refresh();
                },
          icon: Icon(
            preview
                ? Icons.lock_rounded
                : complete
                ? Icons.check_circle_outline_rounded
                : Icons.flight_takeoff_rounded,
            size: 18,
          ),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.65,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.transparent,
            disabledForegroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF5481B5), size: 17),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: Color(0xFF8B99A9),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.85,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF172B45),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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

class _ZonePill extends StatelessWidget {
  const _ZonePill({
    required this.zone,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String zone;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    selected: selected,
    label: 'Zone $zone${selected ? ', selected' : ''}',
    onTap: onTap,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.25 : 0.09),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.18),
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 3),
              Text(
                zone,
                style: TextStyle(
                  color: color.withValues(alpha: 0.95),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 2),
                Icon(Icons.check_rounded, color: color, size: 11),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
