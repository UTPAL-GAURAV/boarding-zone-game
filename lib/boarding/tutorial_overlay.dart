import 'package:flutter/material.dart';

enum TutorialStep {
  selectZone,
  paintSeats,
  startBoarding,
  watchBoard,
  done,
}

class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({
    super.key,
    required this.step,
    required this.onDismiss,
  });

  final TutorialStep step;
  final VoidCallback onDismiss;

  static const _accent = Color(0xFFFFB930);

  @override
  Widget build(BuildContext context) {
    if (step == TutorialStep.done) return _buildDoneCard(context);
    return _buildCoachBubble(context);
  }

  Widget _buildCoachBubble(BuildContext context) {
    final config = _stepConfig(step);
    final size = MediaQuery.of(context).size;

    // Arrow indicator pointing to a UI element
    Widget? arrowIndicator;
    if (config.arrowDirection != null) {
      arrowIndicator = Positioned(
        bottom: config.arrowFromBottom,
        left: size.width / 2 - 12,
        child: _PulsingArrow(direction: config.arrowDirection!),
      );
    }

    // Card can be anchored to top or bottom depending on the step
    final Positioned card;
    if (config.cardBottom != null) {
      card = Positioned(
        bottom: config.cardBottom,
        left: 16,
        right: 16,
        child: _CoachCard(
          title: config.title,
          body: config.body,
          cta: config.cta,
          onTap: config.ctaIsAuto ? null : onDismiss,
        ),
      );
    } else {
      card = Positioned(
        top: config.cardTop,
        left: 16,
        right: 16,
        child: _CoachCard(
          title: config.title,
          body: config.body,
          cta: config.cta,
          onTap: config.ctaIsAuto ? null : onDismiss,
        ),
      );
    }

    return IgnorePointer(
      // Allow touches through everywhere except the card itself
      ignoring: false,
      child: Stack(
        children: [
          if (arrowIndicator != null) arrowIndicator,
          card,
        ],
      ),
    );
  }

  Widget _buildDoneCard(BuildContext context) {
    const bg = Color(0xFF0A0E1A);
    return Container(
      color: bg.withValues(alpha: 0.88),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: _accent, size: 64),
              const SizedBox(height: 20),
              const Text(
                "You're ready to fly!",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'You know how to zone seats and board passengers.\nNow try it for real on Level 1!',
                style: TextStyle(color: Color(0xFFB0B8CC), fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: bg,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: onDismiss,
                  child: const Text(
                    'GO TO FLEET',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StepConfig _stepConfig(TutorialStep s) {
    switch (s) {
      case TutorialStep.selectZone:
        return _StepConfig(
          title: 'Pick a boarding zone',
          body: 'Tap one of the coloured zone pills to select it. Zone A boards first — Zone F boards last.',
          cta: 'GOT IT',
          cardTop: 0,
          cardBottom: 72,
          arrowDirection: _ArrowDir.up,
          arrowFromBottom: 220,
          ctaIsAuto: false,
        );
      case TutorialStep.paintSeats:
        return _StepConfig(
          title: 'Assign seats to zones',
          body: 'Drag your finger over the seats in the cabin to paint them with the selected zone colour.',
          cta: 'GOT IT',
          cardTop: 0,
          cardBottom: 72,
          arrowDirection: null,
          arrowFromBottom: null,
          ctaIsAuto: false,
        );
      case TutorialStep.startBoarding:
        return _StepConfig(
          title: 'Start boarding!',
          body: 'Tap the START BOARDING button below to let passengers on.',
          cta: null,
          cardTop: 0,
          cardBottom: 72,
          arrowDirection: _ArrowDir.down,
          arrowFromBottom: 64,
          ctaIsAuto: true,
        );
      case TutorialStep.watchBoard:
        return _StepConfig(
          title: 'Watch them board',
          body: 'Passengers board in zone order — back rows first. When everyone is seated the flight is done!',
          cta: 'OK',
          cardTop: 0,
          cardBottom: 72,
          arrowDirection: null,
          arrowFromBottom: null,
          ctaIsAuto: false,
        );
      case TutorialStep.done:
        return _StepConfig(
          title: '', body: '', cta: null,
          cardTop: 0, arrowDirection: null,
          arrowFromBottom: null, ctaIsAuto: false,
        );
    }
  }
}

// ─── Internal helpers ────────────────────────────────────────────────────────

enum _ArrowDir { down, up }

class _StepConfig {
  const _StepConfig({
    required this.title,
    required this.body,
    required this.cta,
    required this.cardTop,
    this.cardBottom,
    required this.arrowDirection,
    required this.arrowFromBottom,
    required this.ctaIsAuto,
  });
  final String title;
  final String body;
  final String? cta;
  final double cardTop;
  final double? cardBottom;
  final _ArrowDir? arrowDirection;
  final double? arrowFromBottom;
  final bool ctaIsAuto;
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  final String title;
  final String body;
  final String? cta;
  final VoidCallback? onTap;

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
            if (cta != null && onTap != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: onTap,
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
  const _PulsingArrow({required this.direction});
  final _ArrowDir direction;

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
        offset: Offset(0, widget.direction == _ArrowDir.up ? -_anim.value : _anim.value),
        child: Icon(
          widget.direction == _ArrowDir.up
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: const Color(0xFFFFB930),
          size: 32,
        ),
      ),
    );
  }
}
