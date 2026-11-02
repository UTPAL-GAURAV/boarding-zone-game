import 'package:flutter/material.dart';

import 'cabin_game.dart';

enum TutorialStep {
  strategy,      // D1 — what the game is about
  learnZones,    // D2 — show A–F zone pills, explain order
  paintSeats,    // D3 — gated until ≥1 seat is painted
  startBoarding, // D4 — explain timer + arrow to START BOARDING, passthrough
  done,          // boarding complete — Replay + Back to Home
}

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.step,
    required this.seatsHaveBeenPainted,
    required this.onDismiss,
    required this.onReplay,
  });

  final TutorialStep step;
  final bool seatsHaveBeenPainted;
  final VoidCallback onDismiss;
  final VoidCallback onReplay;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  static const _accent = Color(0xFFFFB930);
  static const _bg = Color(0xFF0A0E1A);

  @override
  Widget build(BuildContext context) {
    switch (widget.step) {
      case TutorialStep.strategy:
        return _buildDialog(
          title: 'Your mission',
          body:
              "You're a ground crew chief. Paint seats into boarding zones — passengers board Zone A first, Zone F last. Beat the target time to unlock the next aircraft.",
          cta: "Let's go",
          ctaEnabled: true,
          onCta: widget.onDismiss,
          showArrow: false,
        );

      case TutorialStep.learnZones:
        return _buildDialog(
          title: 'Boarding zones',
          body:
              'Passengers board in zone order. Zone A boards first — seats at the back. Zone F boards last — seats near the door. Assign wisely!',
          cta: 'Understood',
          ctaEnabled: true,
          onCta: widget.onDismiss,
          showArrow: false,
          anchorTop: true,
          extra: _buildZonePills(),
        );

      case TutorialStep.paintSeats:
        return _buildDialog(
          title: 'Paint your seats',
          body:
              'Select a zone then tap or drag across seats to paint them. Passengers in the same zone board together — try putting Zone A at the back!',
          cta: 'NEXT',
          ctaEnabled: widget.seatsHaveBeenPainted,
          onCta: widget.onDismiss,
          showArrow: false,
        );

      case TutorialStep.startBoarding:
        return _buildDialog(
          title: 'Ready for boarding?',
          body:
              'Tap START BOARDING below. Watch the timer at the top — better zones mean a faster time!',
          cta: null,
          ctaEnabled: false,
          onCta: null,
          showArrow: false,
          passthrough: true,
        );

      case TutorialStep.done:
        return _buildDoneDialog();
    }
  }

  Widget _buildDialog({
    required String title,
    required String body,
    required String? cta,
    required bool ctaEnabled,
    required VoidCallback? onCta,
    required bool showArrow,
    bool arrowUp = false,
    bool passthrough = false,
    bool anchorTop = false,
    Widget? extra,
  }) {
    final size = MediaQuery.of(context).size;
    final Positioned card;
    if (anchorTop) {
      card = Positioned(
        top: 80,
        left: 16,
        right: 16,
        child: _CoachCard(
          title: title,
          body: body,
          cta: cta,
          ctaEnabled: ctaEnabled,
          onTap: onCta,
          extra: extra,
        ),
      );
    } else {
      card = Positioned(
        bottom: passthrough ? 80 : 72,
        left: 16,
        right: 16,
        child: _CoachCard(
          title: title,
          body: body,
          cta: cta,
          ctaEnabled: ctaEnabled,
          onTap: onCta,
          extra: extra,
        ),
      );
    }

    return Stack(
      children: [
        if (showArrow)
          Positioned(
            bottom: arrowUp ? 220.0 : 64.0,
            left: size.width / 2 - 12,
            child: IgnorePointer(child: _PulsingArrow(up: arrowUp)),
          ),
        card,
      ],
    );
  }

  Widget _buildZonePills() {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(6, (i) {
        final color = CabinGame.zoneColors[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Zone ${labels[i]}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDoneDialog() {
    return Container(
      color: _bg.withValues(alpha: 0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: _accent, size: 64),
              const SizedBox(height: 20),
              const Text(
                'Boarding complete!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Great job! This is how the real game works — zone your seats, board fast, beat the target time.',
                style: TextStyle(color: Color(0xFFB0B8CC), fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onReplay,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'REPLAY',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: widget.onDismiss,
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: _bg,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'BACK TO HOME',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Internal helpers ────────────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.title,
    required this.body,
    required this.cta,
    required this.ctaEnabled,
    required this.onTap,
    this.extra,
  });

  final String title;
  final String body;
  final String? cta;
  final bool ctaEnabled;
  final VoidCallback? onTap;
  final Widget? extra;

  static const _accent = Color(0xFFFFB930);
  static const _panel = Color(0xFF1E2840);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: _panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.school_rounded, color: _accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(color: Color(0xFFB0B8CC), fontSize: 13),
            ),
            if (extra != null) ...[
              const SizedBox(height: 12),
              extra!,
            ],
            if (cta != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: ctaEnabled ? _accent : const Color(0xFF6B7A99),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: ctaEnabled ? onTap : null,
                  child: Text(
                    '$cta →',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PulsingArrow extends StatefulWidget {
  const _PulsingArrow({required this.up});
  final bool up;

  @override
  State<_PulsingArrow> createState() => _PulsingArrowState();
}

class _PulsingArrowState extends State<_PulsingArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 10).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, widget.up ? -_anim.value : _anim.value),
        child: Icon(
          widget.up
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: const Color(0xFFFFB930),
          size: 32,
        ),
      ),
    );
  }
}
