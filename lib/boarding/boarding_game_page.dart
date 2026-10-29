import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'boarding_simulation.dart';
import 'cabin_game.dart';
import 'aircraft_layout.dart';
import 'levels/level_one.dart';

class BoardingGamePage extends StatefulWidget {
  const BoardingGamePage({
    super.key,
    this.layout = LevelOne.aircraft,
    this.onCompleted,
  });

  final AircraftLayout layout;
  final ValueChanged<int>? onCompleted;

  @override
  State<BoardingGamePage> createState() => _BoardingGamePageState();
}

class _BoardingGamePageState extends State<BoardingGamePage> {
  late final BoardingSimulation _simulation;
  late final CabinGame _game;
  bool _reportedCompletion = false;

  static const _zones = CabinGame.zoneColors;
  static const _ink = Color(0xFF172B45);
  static const _muted = Color(0xFF73849A);

  @override
  void initState() {
    super.initState();
    _simulation = BoardingSimulation(layout: widget.layout);
    _game = CabinGame(simulation: _simulation, onChanged: _refresh);
  }

  void _refresh() {
    if (_simulation.isComplete && !_reportedCompletion) {
      _reportedCompletion = true;
      widget.onCompleted?.call(_simulation.elapsedSeconds.floor());
    }
    if (mounted) setState(() {});
  }

  void _reset() {
    _simulation.reset();
    _refresh();
  }

  String get _timer {
    final seconds = _simulation.elapsedSeconds.floor();
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
  }

  String get _boardingStatus {
    if (!_simulation.isBoarding) return 'Tap a seat to change its zone';
    final zone = _simulation.currentEntryZone;
    if (zone != null) {
      return 'Zone ${zone + 1} boarding · ${_simulation.waitingCount} waiting';
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
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4789DD), Color(0xFF245AAE)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x28446EAA),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.flight_takeoff_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Boarding Zone',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'PLAN A FASTER BOARDING',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _reset,
              borderRadius: BorderRadius.circular(14),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.restart_alt_rounded, color: _ink, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
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
            label: 'FLIGHT',
            value: '${_simulation.layout.rowCount} rows',
            icon: Icons.airplanemode_active_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildZoneLegend() {
    return SizedBox(
      height: 30,
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
          const SizedBox(width: 10),
          for (var zone = 0; zone < _simulation.layout.zoneCount; zone++) ...[
            if (zone > 0) const SizedBox(width: 6),
            _ZonePill(zone: zone + 1, color: _zones[zone]),
          ],
          const Spacer(),
          const Icon(Icons.touch_app_rounded, color: _muted, size: 15),
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => _game.tapAt(event.localPosition),
              child: GameWidget(game: _game),
            ),
            if (complete) _buildCompletionCard(),
          ],
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
              decoration: const BoxDecoration(
                color: Color(0xFFE8F7EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF39A674),
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
            const SizedBox(height: 7),
            Text(
              'Every passenger is seated in $_timer.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.4),
            ),
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
              'Ready to plan another flight?',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(bool complete) {
    final boarding = _simulation.isBoarding;
    final label = complete
        ? 'FLIGHT COMPLETE'
        : boarding
        ? 'BOARDING…'
        : 'START BOARDING';
    return SizedBox(
      height: 48,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: boarding || complete
                ? [const Color(0xFF7E8FA4), const Color(0xFF61758E)]
                : [const Color(0xFF3479D0), const Color(0xFF245BB1)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: boarding || complete
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
          onPressed: boarding
              ? null
              : () {
                  _simulation.start();
                  _refresh();
                },
          icon: Icon(
            complete
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
  const _ZonePill({required this.zone, required this.color});

  final int zone;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$zone',
          style: TextStyle(
            color: color.withValues(alpha: 0.95),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
