import 'package:flutter/material.dart';

enum TutorialStep {
  bigIdea,        // Step 2 — full-screen: how the game works
  anatomyBoarded, // Step 3a — dim cabin, point at BOARDED counter
  anatomyTime,    // Step 3b — dim cabin, point at TIME
  anatomyBest,    // Step 3c — dim cabin, point at BEST
  anatomyZones,   // Step 3d — dim cabin, point at zone chips
  anatomySeats,   // Step 3e — dim cabin, point at seat grid
  paintZoneA,     // Step 4 — cabin interactive, gate ≥4 Zone A seats
  paintZoneB,     // Step 5 — cabin interactive, gate ≥3 Zone B seats
  boardNow,       // Step 6 — passthrough, BOARD NOW pulses
  debrief,        // Step 7 — post-boarding debrief
  graduation,     // Step 8 — graduation screen
}

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.step,
    required this.zoneACnt,
    required this.zoneBCnt,
    this.boardingTimeMs,
    this.highlightRect,
    required this.onDismiss,
    required this.onReplay,
  });

  final TutorialStep step;
  final int zoneACnt;
  final int zoneBCnt;
  final int? boardingTimeMs;
  final Rect? highlightRect;
  final VoidCallback onDismiss;
  final VoidCallback onReplay;

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay> {
  static const _accent = Color(0xFFFFB930);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _scrim => _isDark ? const Color(0xFF060A1C) : const Color(0xFFF0F5FF);

  @override
  Widget build(BuildContext context) {
    switch (widget.step) {
      // ── Full-cover steps ───────────────────────────────────────────────
      case TutorialStep.bigIdea:
        return _buildFullCover(
          title: 'How this game works',
          body:
              '1. You paint seats into boarding groups (zones)\n'
              '2. Tap BOARD NOW — passengers board in your zone order automatically\n'
              '3. Your goal: the fastest possible total boarding time\n\n'
              'You are the crew manager — not the passenger.',
          cta: "Show me around →",
          onCta: widget.onDismiss,
        );

      case TutorialStep.graduation:
        return _buildGraduationCover();

      // ── Anatomy steps (semi-transparent scrim) ─────────────────────────
      case TutorialStep.anatomyBoarded:
        return _buildAnatomyCard(
          icon: Icons.airline_seat_recline_normal_rounded,
          label: 'BOARDED',
          body: 'Tracks how many passengers have found their seat.\n'
              'When this reaches 12 / 12, boarding is complete!',
          arrowEdge: _ArrowEdge.top,
        );

      case TutorialStep.anatomyTime:
        return _buildAnatomyCard(
          icon: Icons.timer_outlined,
          label: 'TIME',
          body: 'Starts the moment you tap BOARD NOW. '
              'Try to beat the target time shown before each flight.',
          arrowEdge: _ArrowEdge.top,
        );

      case TutorialStep.anatomyBest:
        return _buildAnatomyCard(
          icon: Icons.emoji_events_outlined,
          label: 'BEST',
          body: 'Your personal record for this aircraft. '
              'Improve it by planning smarter zones.',
          arrowEdge: _ArrowEdge.top,
        );

      case TutorialStep.anatomyZones:
        return _buildAnatomyCard(
          icon: Icons.grid_view_rounded,
          label: 'ZONE SELECTOR',
          body: 'Tap a zone chip to select it, then paint seats below. '
              'Each chip is a boarding group — you control the order.',
          arrowEdge: _ArrowEdge.top,
        );

      case TutorialStep.anatomySeats:
        return _buildAnatomyCard(
          icon: Icons.event_seat_rounded,
          label: 'SEAT GRID',
          body: 'This is your aircraft cabin. '
              'Tap or drag across seats to paint them into the selected zone.',
          arrowEdge: _ArrowEdge.bottom,
          anchorTop: true,
        );

      // ── Floating cabin steps ───────────────────────────────────────────
      case TutorialStep.paintZoneA:
        final ready = widget.zoneACnt >= 4;
        return _buildFloating(
          title: 'Paint Zone A',
          body:
              'Zone A boards first. Tap the BACK rows to assign those seats to Zone A.\n\n'
              'Paint at least 4 seats to continue.',
          cta: 'NEXT →',
          ctaEnabled: ready,
          onCta: widget.onDismiss,
          showMaya: true,
          progress: _buildZoneProgress(widget.zoneACnt, 4),
        );

      case TutorialStep.paintZoneB:
        final ready = widget.zoneBCnt >= 3;
        final chipRect = widget.highlightRect;
        return Stack(
          children: [
            _buildFloating(
              title: 'Paint Zone B',
              body: 'Tap Zone B in the selector above, then paint at least 3 more seats.',
              cta: 'NEXT →',
              ctaEnabled: ready,
              onCta: widget.onDismiss,
              progress: _buildZoneProgress(widget.zoneBCnt, 3),
            ),
            if (chipRect != null)
              Positioned(
                left: chipRect.center.dx - 56,
                top: chipRect.top - 66,
                child: const IgnorePointer(child: _BouncingPointer()),
              ),
          ],
        );

      case TutorialStep.boardNow:
        return _buildFloating(
          title: "Your plan is set!",
          body:
              'Tap BOARD NOW below and watch the passengers board in your zone order. '
              'The timer starts the moment you tap!',
          passthrough: true,
          showPointer: true,
        );

      case TutorialStep.debrief:
        return _buildDebrief();
    }
  }

  // ─── Full-cover (bigIdea, zoneNaming) ────────────────────────────────────

  Widget _buildFullCover({
    required String title,
    required String body,
    required String cta,
    required VoidCallback onCta,
    Widget? extra,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: _scrim,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/maya.png', height: 155, fit: BoxFit.contain),
                    const SizedBox(height: 16),
                    _CoachCard(
                      title: title,
                      body: body,
                      cta: cta,
                      ctaEnabled: true,
                      onTap: onCta,
                      extra: extra,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Anatomy cards (spotlight scrim, visible cabin) ──────────────────────

  Widget _buildAnatomyCard({
    required IconData icon,
    required String label,
    required String body,
    required _ArrowEdge arrowEdge,
    bool anchorTop = false,
  }) {
    final card = _AnatomyTooltip(
      icon: icon,
      label: label,
      body: body,
      arrowEdge: arrowEdge,
      isDark: _isDark,
      onNext: widget.onDismiss,
    );

    final cardWithMaya = anchorTop
        ? card // no space above the card when anchored to the top
        : Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned(
                top: -88,
                left: 8,
                child: IgnorePointer(
                  child: Image.asset('assets/maya.png', height: 108, fit: BoxFit.contain),
                ),
              ),
            ],
          );

    final highlight = widget.highlightRect;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: highlight != null
                  ? CustomPaint(painter: _SpotlightPainter(highlight: highlight))
                  : ColoredBox(color: Colors.black.withValues(alpha: 0.72)),
            ),
            if (anchorTop)
              Positioned(top: 24, left: 16, right: 16, child: cardWithMaya)
            else
              Positioned(bottom: 24, left: 16, right: 16, child: cardWithMaya),
          ],
        ),
      ),
    );
  }

  // ─── Floating card (paintZoneA/B, boardNow) ──────────────────────────────

  Widget _buildFloating({
    required String title,
    required String body,
    String? cta,
    bool ctaEnabled = false,
    VoidCallback? onCta,
    bool passthrough = false,
    bool showMaya = false,
    bool showPointer = false,
    Widget? progress,
  }) {
    final card = _CoachCard(
      title: title,
      body: body,
      cta: cta,
      ctaEnabled: ctaEnabled,
      onTap: onCta,
      extra: progress,
    );

    final cardWithMaya = showMaya
        ? Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned(
                top: -88,
                left: 8,
                child: IgnorePointer(
                  child: Image.asset('assets/maya.png', height: 108, fit: BoxFit.contain),
                ),
              ),
            ],
          )
        : card;

    return Stack(
      children: [
        Positioned(
          bottom: passthrough ? 78 : 8,
          left: 16,
          right: 16,
          child: cardWithMaya,
        ),
        if (showPointer)
          const Positioned(
            bottom: 58,
            right: 72,
            child: IgnorePointer(child: _BouncingPointer()),
          ),
      ],
    );
  }

  // ─── Debrief ─────────────────────────────────────────────────────────────

  Widget _buildDebrief() {
    final isDark = _isDark;
    final timeStr = widget.boardingTimeMs != null
        ? _fmtMs(widget.boardingTimeMs!)
        : '—';
    final titleColor = isDark ? Colors.white : const Color(0xFF0A1628);
    final bodyColor = isDark ? const Color(0xFFB0B8CC) : const Color(0xFF5A6A8A);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: _scrim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Image.asset('assets/maya.png', height: 140, fit: BoxFit.contain),
                const SizedBox(height: 12),
                // Time highlight
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2840)
                        : const Color(0xFFE8F0FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'YOUR BOARDING TIME',
                        style: TextStyle(
                          color: _accent.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "That's your first time!\n\nUse REPLAY to try a smarter zone strategy and improve it.",
                  style: TextStyle(color: bodyColor, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onReplay,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: titleColor,
                          side: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : const Color(0xFF0A1628).withValues(alpha: 0.25),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'REPLAY',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
                          foregroundColor: const Color(0xFF0A0E1A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          "I GET IT →",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Graduation ───────────────────────────────────────────────────────────

  Widget _buildGraduationCover() {
    final isDark = _isDark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0A1628);
    final bodyColor = isDark ? const Color(0xFFB0B8CC) : const Color(0xFF5A6A8A);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: _scrim,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Image.asset('assets/maya.png', height: 150, fit: BoxFit.contain),
                const SizedBox(height: 12),
                const Icon(Icons.check_circle_rounded, color: _accent, size: 52),
                const SizedBox(height: 12),
                Text(
                  "You're ready!",
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'The real fleet is unlocked. Each aircraft has a target time — beat it to unlock the next one. Come back and beat your best times!',
                  style: TextStyle(color: bodyColor, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onDismiss,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF0A0E1A),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'GOT IT — TAKE ME TO THE FLEET',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Zone progress indicator ──────────────────────────────────────────────

  Widget _buildZoneProgress(int current, int required) {
    final isDark = _isDark;
    final filled = _accent;
    final empty = isDark
        ? const Color(0xFF2A3550)
        : const Color(0xFFD8E2F5);
    return Row(
      children: [
        Text(
          '$current / $required seats',
          style: TextStyle(
            color: current >= required ? _accent : (isDark ? const Color(0xFF6B7A99) : const Color(0xFF8898B8)),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (current / required).clamp(0.0, 1.0),
              backgroundColor: empty,
              color: filled,
              minHeight: 5,
            ),
          ),
        ),
      ],
    );
  }

  String _fmtMs(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
  }
}

// ─── Anatomy tooltip card ─────────────────────────────────────────────────────

enum _ArrowEdge { top, bottom }

class _AnatomyTooltip extends StatelessWidget {
  const _AnatomyTooltip({
    required this.icon,
    required this.label,
    required this.body,
    required this.arrowEdge,
    required this.isDark,
    required this.onNext,
  });

  final IconData icon;
  final String label;
  final String body;
  final _ArrowEdge arrowEdge;
  final bool isDark;
  final VoidCallback onNext;

  static const _accent = Color(0xFFFFB930);

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF12192E) : Colors.white;
    final inkColor = isDark ? Colors.white : const Color(0xFF0A1628);
    final bodyColor = isDark ? const Color(0xFFB0B8CC) : const Color(0xFF5A6A8A);

    final arrow = CustomPaint(
      size: const Size(32, 16),
      painter: _ArrowPainter(
        pointing: arrowEdge == _ArrowEdge.top ? _ArrowEdge.top : _ArrowEdge.bottom,
        color: _accent,
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (arrowEdge == _ArrowEdge.top) ...[
          Center(child: arrow),
          const SizedBox(height: 2),
        ],
        Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _accent.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(icon, color: _accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: inkColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: TextStyle(color: bodyColor, fontSize: 13, height: 1.45),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: onNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: const Color(0xFF0A0E1A),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    child: const Text('NEXT →'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (arrowEdge == _ArrowEdge.bottom) ...[
          const SizedBox(height: 2),
          Center(child: arrow),
        ],
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  const _ArrowPainter({required this.pointing, required this.color});
  final _ArrowEdge pointing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (pointing == _ArrowEdge.top) {
      // Triangle pointing UP (arrow at top of card points toward header)
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      // Triangle pointing DOWN
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter old) => old.color != color;
}

// ─── Spotlight painter ────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({required this.highlight});
  final Rect highlight;

  static const _border = Color(0xFFFFB930);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.72);
    final hr = highlight.inflate(6);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, hr.top), paint);
    canvas.drawRect(Rect.fromLTRB(0, hr.bottom, size.width, size.height), paint);
    canvas.drawRect(Rect.fromLTRB(0, hr.top, hr.left, hr.bottom), paint);
    canvas.drawRect(Rect.fromLTRB(hr.right, hr.top, size.width, hr.bottom), paint);
    final border = Paint()
      ..color = _border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(hr, const Radius.circular(8)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => old.highlight != highlight;
}

// ─── Coach card ───────────────────────────────────────────────────────────────

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    required this.title,
    required this.body,
    this.cta,
    this.ctaEnabled = false,
    this.onTap,
    this.extra,
  });

  final String title;
  final String body;
  final String? cta;
  final bool ctaEnabled;
  final VoidCallback? onTap;
  final Widget? extra;

  static const _accent = Color(0xFFFFB930);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF12192E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0A1628);
    final bodyColor = isDark ? const Color(0xFFB0B8CC) : const Color(0xFF5A6A8A);
    final disabledBg = isDark ? const Color(0xFF2A3550) : const Color(0xFFE4EAF4);
    final disabledFg = isDark ? const Color(0xFF6B7A99) : const Color(0xFFAAB4C8);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accent.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MAYA  ·  Crew Trainer',
              style: TextStyle(
                color: _accent.withValues(alpha: 0.75),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(color: bodyColor, fontSize: 13, height: 1.45),
            ),
            if (extra != null) ...[const SizedBox(height: 14), extra!],
            if (cta != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ctaEnabled ? _accent : disabledBg,
                    foregroundColor:
                        ctaEnabled ? const Color(0xFF0A0E1A) : disabledFg,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: ctaEnabled ? onTap : null,
                  child: Text(cta!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Bouncing pointer image ───────────────────────────────────────────────────

class _BouncingPointer extends StatefulWidget {
  const _BouncingPointer();

  @override
  State<_BouncingPointer> createState() => _BouncingPointerState();
}

class _BouncingPointerState extends State<_BouncingPointer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0, end: 10)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
      builder: (_, _) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Image.asset('assets/pointing.png', height: 72),
      ),
    );
  }
}
