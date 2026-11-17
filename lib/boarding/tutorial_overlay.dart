import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum TutorialStep {
  mayaIntro,      // Step 1 — Maya introduces herself
  anatomyBoarded, // Step 2a — dim cabin, point at BOARDED counter
  anatomyTime,    // Step 2b — dim cabin, point at TIME
  anatomyBest,    // Step 2c — dim cabin, point at BEST
  anatomyZones,   // Step 2d — dim cabin, point at zone chips
  paintZoneA,     // Step 3 — cabin interactive, gate ≥4 Zone A seats
  paintZoneB,     // Step 4 — cabin interactive, gate ≥3 Zone B seats
  boardNow,       // Step 5 — passthrough, BOARD NOW pulses
  watching,       // Step 6 — non-interactive toast while boarding runs
  graduation,     // Step 7 — graduation screen
}

class TutorialOverlay extends StatefulWidget {
  const TutorialOverlay({
    super.key,
    required this.step,
    required this.zoneACnt,
    required this.zoneBCnt,
    required this.selectedZone,
    this.highlightRect,
    required this.onDismiss,
    required this.onReplay,
    this.boardingTimeMs,
  });

  final TutorialStep step;
  final int zoneACnt;
  final int zoneBCnt;
  final int selectedZone;
  final Rect? highlightRect;
  final VoidCallback onDismiss;
  final VoidCallback onReplay;
  final int? boardingTimeMs;

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
      case TutorialStep.mayaIntro:
        return _buildMayaIntro();

      case TutorialStep.graduation:
        return _buildGraduationCover();

      // ── Anatomy steps (semi-transparent scrim) ─────────────────────────
      case TutorialStep.anatomyBoarded:
        return _buildAnatomyCard(
          icon: Icons.airline_seat_recline_normal_rounded,
          label: 'SEATED',
          body: 'Tracks how many passengers have found their seat.\n'
              'When this reaches 12 / 12, boarding is complete!',
          arrowEdge: _ArrowEdge.top,
        );

      case TutorialStep.anatomyTime:
        return _buildAnatomyCard(
          icon: Icons.timer_outlined,
          label: 'TIME',
          body: 'Starts the moment you tap START BOARDING. '
              'Try to beat the target time shown before each flight.',
          arrowEdge: _ArrowEdge.top,
        );

      case TutorialStep.anatomyBest:
        return _buildAnatomyCard(
          icon: Icons.emoji_events_outlined,
          label: 'BEST',
          body: 'Your personal record for this aircraft. '
              'Improve it with a better zone plan.',
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


      // ── Floating cabin steps ───────────────────────────────────────────
      case TutorialStep.paintZoneA:
        final ready = widget.zoneACnt >= 4;
        return _buildFloating(
          title: 'Paint Zone A',
          body: 'Each seat in the cabin can be painted into a boarding zone. '
              'Zone A boards first — tap or drag the back rows to start.\n\n'
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
            if (chipRect != null && widget.selectedZone != 1 && widget.zoneBCnt < 3)
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
              'Tap START BOARDING below and watch the passengers board in your zone order. '
              'The timer starts the moment you tap!',
          passthrough: true,
          showPointer: true,
        );

      case TutorialStep.watching:
        return _buildWatching();

    }
  }

  // ─── Maya intro ──────────────────────────────────────────────────────────

  Widget _buildMayaIntro() {
    final isDark = _isDark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0A1628);
    final bodyColor = isDark ? const Color(0xFFB0B8CC) : const Color(0xFF5A6A8A);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: _scrim,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mayaH = constraints.maxHeight < 520 ? 130.0 : 180.0;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/maya.png', height: mayaH, fit: BoxFit.contain),
                      const SizedBox(height: 20),
                      Text(
                        "I'm Maya.",
                        style: GoogleFonts.rajdhani(
                          color: titleColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'I run boarding operations around here.\nLet me show you how this works.',
                        style: GoogleFonts.barlow(
                          color: bodyColor,
                          fontSize: 15,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.onDismiss,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: const Color(0xFF0A0E1A),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          child: const Text("LET'S GO →"),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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

    // Maya floats above the card at -88dp. On short screens the card sits at
    // bottom: 24 so Maya's top edge is roughly (screenH - cardH - 88). We add
    // top padding equal to Maya's height so it is never clipped by the SafeArea.
    final cardWithMaya = anchorTop
        ? card
        : Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned(
                top: -88,
                left: 8,
                child: IgnorePointer(
                  child: Image.asset('assets/maya.png', height: 84, fit: BoxFit.contain),
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
              // Extra top inset ensures the -88dp Maya never renders above the
              // safe area on devices with tall status bars.
              Positioned(bottom: 24, top: 96, left: 16, right: 16,
                child: Align(alignment: Alignment.bottomCenter, child: cardWithMaya)),
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

    final screenH = MediaQuery.of(context).size.height;
    final screenW = MediaQuery.of(context).size.width;
    const cardDesignW = 360.0;
    final availableW = screenW - 32;

    // Reserve vertical space for the Maya image that floats -80dp above the
    // card, so FittedBox scales the whole unit (Maya + card) uniformly instead
    // of clipping Maya at the top.
    const mayaOverhang = 86.0;

    Widget cardWithMaya = showMaya
        ? Padding(
            padding: const EdgeInsets.only(top: mayaOverhang),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                Positioned(
                  top: -mayaOverhang,
                  left: 8,
                  child: IgnorePointer(
                    child: Image.asset('assets/maya.png', height: 90, fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
          )
        : card;

    if (availableW < cardDesignW) {
      cardWithMaya = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomCenter,
        child: SizedBox(width: cardDesignW, child: cardWithMaya),
      );
    }

    return Stack(
      children: [
        Positioned(
          bottom: passthrough ? 78 : 8,
          left: 16,
          right: 16,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: screenH * 0.65),
            child: SingleChildScrollView(child: cardWithMaya),
          ),
        ),
        // Pointer centered above the START BOARDING button.
        if (showPointer)
          Positioned(
            bottom: 58,
            left: 0,
            right: 0,
            child: Center(
              child: IgnorePointer(child: _BouncingPointer()),
            ),
          ),
      ],
    );
  }

  // ─── Watching toast (boarding in progress) ──────────────────────────────

  Widget _buildWatching() {
    final isDark = _isDark;
    final bg = isDark ? const Color(0xFF12192E) : Colors.white;
    final bodyColor = isDark ? const Color(0xFFB0B8CC) : const Color(0xFF5A6A8A);

    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
            child: Container(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _accent.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.visibility_outlined, color: _accent, size: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Sit back and watch — your zones are doing the work.',
                      style: GoogleFonts.barlow(
                        color: bodyColor,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Graduation ───────────────────────────────────────────────────────────

  String _fmtMs(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}.${(ms % 1000).toString().padLeft(3, '0')}';
  }

  Widget _buildGraduationCover() {
    final isDark = _isDark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0A1628);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF4A5568);
    final timeMs = widget.boardingTimeMs;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        color: _scrim,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mayaH = constraints.maxHeight < 520 ? 90.0 : 120.0;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/maya.png', height: mayaH, fit: BoxFit.contain),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          "You're ready.",
                          style: GoogleFonts.rajdhani(
                            color: titleColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Board passengers in minimum possible time.',
                        style: GoogleFonts.barlow(
                          color: subtitleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (timeMs != null) ...[
                        const SizedBox(height: 20),
                        _buildTimeCard(timeMs, isDark),
                      ],
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: widget.onDismiss,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: const Color(0xFF0A0E1A),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: GoogleFonts.rajdhani(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          child: const Text(
                            "I'M READY — LET'S GO →",
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard(int ms, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1A2540) : const Color(0xFFEEF2FF);
    final borderColor = _accent.withValues(alpha: 0.6);
    final labelColor = _accent;
    final timeColor = isDark ? Colors.white : const Color(0xFF0A1628);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            'YOUR BOARDING TIME',
            style: GoogleFonts.rajdhani(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmtMs(ms),
            style: GoogleFonts.spaceMono(
              color: timeColor,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
          style: GoogleFonts.rajdhani(
            color: current >= required
                ? _accent
                : (isDark ? const Color(0xFF6B7A99) : const Color(0xFF8898B8)),
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
                      style: GoogleFonts.rajdhani(
                        color: inkColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  style: GoogleFonts.barlow(
                    color: bodyColor,
                    fontSize: 13,
                    height: 1.45,
                  ),
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
                      textStyle: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
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
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
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
              'MAYA  ·  Chief Boarding Officer',
              style: GoogleFonts.rajdhani(
                color: _accent.withValues(alpha: 0.75),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.rajdhani(
                color: titleColor,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: GoogleFonts.barlow(
                color: bodyColor,
                fontSize: 13,
                height: 1.45,
              ),
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
                    textStyle: GoogleFonts.rajdhani(
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
