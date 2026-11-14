import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'boarding_simulation.dart';
import 'aircraft_layout.dart';

class CabinGame extends FlameGame {
  CabinGame({
    required this.simulation,
    required this.onChanged,
    bool isDark = true,
  }) : _isDark = isDark;

  @override
  bool paused = false;
  bool _isDark;
  ui.Image? _noseLightImage;
  ui.Image? _noseDarkImage;
  ui.Image? _tailLightImage;
  ui.Image? _tailDarkImage;

  /// Update the light/dark theme without recreating the game.
  set isDark(bool value) => _isDark = value;

  final BoardingSimulation simulation;
  AircraftLayout get layout => simulation.layout;
  final VoidCallback onChanged;
  double _notifyClock = 0;
  Offset? _lastPaintPosition;

  static const List<Color> zoneColors = [
    Color(0xFF4A9EFF), // A — electric blue
    Color(0xFFFF8C42), // B — vivid orange
    Color(0xFF3DD68C), // C — emerald
    Color(0xFFBF6EEA), // D — violet
    Color(0xFFFF5C7A), // E — coral pink
    Color(0xFFFFD60A), // F — vivid yellow (distinct from C emerald)
  ];

  @override
  Color backgroundColor() =>
      _isDark ? const Color(0xFF0D1428) : const Color(0xFFEDF3FF);

  Future<ui.Image> _loadImage(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _noseLightImage = await _loadImage('assets/plane_nose_light.png');
    _noseDarkImage  = await _loadImage('assets/plane_nose_dark.png');
    _tailLightImage = await _loadImage('assets/plane_tail_light.png');
    _tailDarkImage  = await _loadImage('assets/plane_tail_dark.png');
  }

  @override
  void update(double dt) {
    // Cap dt to 50 ms to prevent first-frame teleport on slower devices.
    final safeDt = dt.clamp(0.0, 0.05);
    super.update(safeDt);
    if (!paused) simulation.update(safeDt);
    if (simulation.isBoarding) {
      _notifyClock += safeDt;
      if (_notifyClock >= 0.12) {
        _notifyClock = 0;
        onChanged();
      }
    }
  }

  bool beginPaintingAt(Offset point, int zone) {
    _lastPaintPosition = point;
    return _paintAt(point, zone);
  }

  void continuePaintingAt(Offset point, int zone) {
    final previous = _lastPaintPosition;
    if (previous == null) {
      beginPaintingAt(point, zone);
      return;
    }
    final distance = (point - previous).distance;
    final steps = (distance / 6).ceil().clamp(1, 240).toInt();
    for (var step = 1; step <= steps; step++) {
      _paintAt(Offset.lerp(previous, point, step / steps)!, zone);
    }
    _lastPaintPosition = point;
  }

  void endPainting() => _lastPaintPosition = null;

  bool _paintAt(Offset point, int zone) {
    if (simulation.isBoarding || size.x == 0 || size.y == 0) return false;
    final scale = size.x / layout.designWidth;
    const left = 0.0;
    const top = 0.0;
    final x = (point.dx - left) / scale;
    final y = (point.dy - top) / scale;
    for (final seat in simulation.seats) {
      if (_seatRect(seat.row, seat.column).inflate(4).contains(Offset(x, y))) {
        if (simulation.assignZone(seat, zone)) onChanged();
        return true;
      }
    }
    return false;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0 || size.y <= 0) return;
    canvas.save();
    final scale = size.x / layout.designWidth;
    canvas.translate(
      0,
      0,
    );
    canvas.scale(scale);
    _drawCabin(canvas);
    // Clip passengers to the cabin body — nothing above entranceDoorY.
    canvas.clipRect(Rect.fromLTWH(
      0,
      layout.entranceDoorY.toDouble(),
      layout.designWidth,
      layout.designHeight - layout.entranceDoorY,
    ));
    for (final passenger in simulation.seatedPassengers) {
      _drawPassenger(canvas, passenger);
    }
    for (final passenger in simulation.aislePassengers) {
      _drawPassenger(canvas, passenger);
    }
    canvas.restore();
  }

  Rect _seatRect(int row, int column) {
    return Rect.fromCenter(
      center: Offset(
        layout.seatColumns[column].centerX,
        layout.rowStartY + row * layout.rowSpacing,
      ),
      width: layout.seatWidth,
      height: layout.seatHeight,
    );
  }

  void _drawCabin(Canvas canvas) {
    // Outer shadow
    final shadow = Paint()
      ..color = Color(_isDark ? 0x22000000 : 0x18000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          layout.cabinShell.left + 4,
          layout.cabinShell.top + 10,
          layout.cabinShell.width - 8,
          layout.cabinShell.height - 8,
        ),
        Radius.circular(layout.cabinShell.cornerRadius),
      ),
      shadow,
    );

    // Nose image first — fuselage fill painted on top covers artifacts.
    _drawNose(canvas);

    // Bottom = just below the last seat row, no extra space, square corners.
    final bodyBottom = layout.rowStartY +
        (layout.rowCount - 1) * layout.rowSpacing +
        layout.seatHeight / 2 + 14;

    // Fuselage fill — starts at entranceDoorY so the nose image shows through.
    final shell = Paint()
      ..color = _isDark ? const Color(0xFF111C36) : const Color(0xFFFFFFFF);
    canvas.drawRect(
      Rect.fromLTWH(
        layout.cabinShell.left,
        layout.entranceDoorY.toDouble(),
        layout.cabinShell.width,
        bodyBottom - layout.entranceDoorY,
      ),
      shell,
    );

    // Side border — measured from nose image: 4px opaque strip, ~3px inset from
    // content edge (fraction of 417px nose content width). Same color both modes.
    final nosBorderStrokeW = (4.0 / 417.0) * layout.cabinShell.width;
    final nosInset = (3.0 / 417.0) * layout.cabinShell.width;
    final lBorder = layout.cabinShell.left + nosInset;
    final rBorder = layout.cabinShell.left + layout.cabinShell.width - nosInset;
    final borderPaint = Paint()
      ..color = const Color(0xFFB6C7E5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = nosBorderStrokeW
      ..strokeCap = StrokeCap.square;
    // Extend lines 4 units past bodyBottom so the tail image (drawn after) covers
    // the overlap and eliminates any sub-pixel gap at the junction.
    final sideOverlap = bodyBottom + 4.0;
    final sidePath = Path()
      ..moveTo(lBorder, layout.entranceDoorY.toDouble())
      ..lineTo(lBorder, sideOverlap)
      ..moveTo(rBorder, layout.entranceDoorY.toDouble())
      ..lineTo(rBorder, sideOverlap);
    canvas.drawPath(sidePath, borderPaint);

    // Tail image drawn below the cabin body.
    _drawTail(canvas, bodyBottom);

    _drawCockpit(canvas);
    _drawEntrance(canvas);
    _drawAisle(canvas);
    _drawWindows(canvas);
    _drawRows(canvas);
  }

  void _drawNose(Canvas canvas) {
    final img = _isDark ? _noseDarkImage : _noseLightImage;
    if (img == null) return;

    const imgW = 583.0;
    const imgH = 428.0;
    const contentLeft = 83.0;
    const contentWidth = 417.0;
    const contentTop = 15.0;
    const contentHeight = 412.0;

    final scale = layout.cabinShell.width / contentWidth;
    final destW = imgW * scale;
    final destH = imgH * scale;
    final destLeft = layout.cabinShell.left - contentLeft * scale;
    final destTop = layout.entranceDoorY - (contentTop + contentHeight) * scale;

    // Paint background color over the full image rect first so any
    // semi-transparent artifact pixels outside the nose outline are invisible.
    canvas.drawRect(
      Rect.fromLTWH(destLeft, destTop, destW, destH),
      Paint()..color = _isDark ? const Color(0xFF0D1428) : const Color(0xFFEDF3FF),
    );

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(destLeft, destTop, destW, destH),
      Paint(),
    );
  }

  void _drawTail(Canvas canvas, double bodyBottom) {
    final img = _isDark ? _tailDarkImage : _tailLightImage;
    if (img == null) return;

    const imgW = 583.0;
    const imgH = 428.0;
    // Border centers at top of tail image: left=148.5, right=433.0 (span=284.5px).
    // contentLeft/contentWidth chosen so border centers map to the same design x as
    // the straight side-border lines (inset 3/417 of cabinShell.width from each edge).
    // Exact solution: contentWidth=288.65, contentLeft=146.42 → rounded to 289/146.
    const contentLeft = 146.0;
    const contentWidth = 289.0;

    final scale = layout.cabinShell.width / contentWidth;
    final destW = imgW * scale;
    final destH = imgH * scale;
    final destLeft = layout.cabinShell.left - contentLeft * scale;
    // Start the tail image at lastRowBottom (bodyBottom - 14) so its white interior
    // overlaps the empty cabin margin, removing the visible white gap.
    final destTop = bodyBottom - 14.0;

    // Background color under the tail to hide transparent-edge artifacts.
    canvas.drawRect(
      Rect.fromLTWH(destLeft, destTop, destW, destH),
      Paint()
        ..color = _isDark ? const Color(0xFF0D1428) : const Color(0xFFEDF3FF),
    );

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, imgW, imgH),
      Rect.fromLTWH(destLeft, destTop, destW, destH),
      Paint(),
    );
  }

  void _drawCockpit(Canvas canvas) {
    final fill = Paint()
      ..color = _isDark ? const Color(0xFF0F1828) : const Color(0xFFDDE8F4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          layout.flightDeck.left,
          layout.flightDeck.top,
          layout.flightDeck.width,
          layout.flightDeck.height,
        ),
        Radius.circular(layout.flightDeck.cornerRadius),
      ),
      fill,
    );
    _text(
      canvas,
      'FLIGHT DECK',
      Offset(
        layout.flightDeck.left + layout.flightDeck.width / 2,
        layout.flightDeck.top + layout.flightDeck.height / 2,
      ),
      9,
      _isDark ? const Color(0xFF7A9BBF) : const Color(0xFF5A7A9A),
      bold: true,
    );
  }

  void _drawEntrance(Canvas canvas) {
    final doorway = Paint()
      ..color = _isDark ? const Color(0xFF152B45) : const Color(0xFFCCDEF0);
    final glow = Paint()..color = const Color(0xFF74C4E8);
    for (final lane in layout.aisles) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            lane.centerX - lane.width / 2,
            layout.entranceDoorY,
            lane.width,
            layout.entranceDoorHeight,
          ),
          const Radius.circular(6),
        ),
        doorway,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            lane.centerX - lane.width / 2 + 4,
            layout.entranceDoorY + 2,
            lane.width - 8,
            4,
          ),
          const Radius.circular(2),
        ),
        glow,
      );
    }
    final labelColor = _isDark ? const Color(0xFF7A9BBF) : const Color(0xFF5A7A9A);
    _text(
      canvas,
      'BOARDING GATE',
      Offset(layout.designWidth / 2, layout.gateLabelY),
      10,
      labelColor,
      bold: true,
    );
    final arrow = Paint()
      ..color = labelColor
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (final lane in layout.aisles) {
      final center = lane.centerX;
      canvas.drawLine(
        Offset(center, layout.entranceDoorY - 10),
        Offset(center, layout.entranceDoorY - 4),
        arrow,
      );
      canvas.drawLine(
        Offset(center - 3, layout.entranceDoorY - 7),
        Offset(center, layout.entranceDoorY - 4),
        arrow,
      );
      canvas.drawLine(
        Offset(center + 3, layout.entranceDoorY - 7),
        Offset(center, layout.entranceDoorY - 4),
        arrow,
      );
    }
  }

  void _drawAisle(Canvas canvas) {
    for (final lane in layout.aisles) {
      // Aisle floor
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            lane.centerX - lane.width / 2,
            lane.floorTop,
            lane.width,
            layout.rowStartY +
                (layout.rowCount - 1) * layout.rowSpacing +
                21 -
                lane.floorTop,
          ),
          Radius.circular(lane.width / 2),
        ),
        Paint()
          ..color = _isDark ? const Color(0xFF08101E) : const Color(0xFFDDE8F4),
      );
      // Center runner line
      final dash = Paint()
        ..color = _isDark ? const Color(0xFF1E3058) : const Color(0xFFB8CCE4)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      for (var row = 0; row < layout.rowCount; row++) {
        final y = layout.rowStartY + row * layout.rowSpacing;
        canvas.drawLine(
          Offset(lane.centerX, y + 5),
          Offset(lane.centerX, y + 13),
          dash,
        );
      }
    }
  }

  void _drawWindows(Canvas canvas) {
    for (var row = 0; row < layout.rowCount; row++) {
      final y = layout.rowStartY - 7 + row * layout.rowSpacing;
      for (final x in layout.windowCentersX) {
        // Outer porthole ring
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 11, height: 22),
            const Radius.circular(6),
          ),
          Paint()
            ..color = _isDark ? const Color(0xFF7AAEE8) : const Color(0xFF8AAED8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        // Window glass
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 8, height: 18),
            const Radius.circular(4),
          ),
          Paint()
            ..color = _isDark ? const Color(0xFF5BA3D8) : const Color(0xFF5A9ED0),
        );
        // Window shine
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(x - 1.5, y - 3), width: 3, height: 6),
            const Radius.circular(2),
          ),
          Paint()..color = _isDark ? const Color(0x66B8D8FF) : const Color(0x334A9EFF),
        );
      }
    }
  }

  void _drawRows(Canvas canvas) {
    for (var row = 0; row < layout.rowCount; row++) {
      final y = layout.rowStartY + row * layout.rowSpacing;

      // Draw seats
      for (var column = 0; column < layout.seatsPerRow; column++) {
        final seat = simulation.seats[row * layout.seatsPerRow + column];
        _drawSeat(canvas, _seatRect(row, column), seat.zone, '${row + 1}${seat.label}');
      }
    }
  }

  void _drawSeat(Canvas canvas, Rect rect, int zone, String label) {
    final color = zoneColors[zone];
    // Light mode needs a more opaque fill so seats pop against the bright fuselage
    final fillAlpha = _isDark ? 0.20 : 0.22;
    final base = Paint()..color = color.withValues(alpha: fillAlpha);
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(shape, base);

    // Outline — full opacity in light mode for better definition
    final outlineAlpha = _isDark ? 0.85 : 1.0;
    final outline = Paint()
      ..color = color.withValues(alpha: outlineAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(shape, outline);

    // Headrest bar
    final headrest = Paint()..color = color.withValues(alpha: _isDark ? 0.55 : 0.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 3.5, rect.top + 2.5, rect.width - 7, 5.5),
        const Radius.circular(3),
      ),
      headrest,
    );

    // In light mode all labels are dark so they're legible regardless of zone color.
    // In dark mode the vivid zone color reads well against the dark tinted seat.
    _text(
      canvas,
      label,
      Offset(rect.center.dx, rect.center.dy + 4),
      6,
      _isDark ? color.withValues(alpha: 0.9) : const Color(0x9A000000),
      bold: true,
    );
  }

  void _drawPassenger(Canvas canvas, BoardingPassenger? passenger) {
    if (passenger == null) return;
    final seatRect = _seatRect(passenger.seat.row, passenger.seat.column);
    final seated = passenger.phase == PassengerPhase.seated;
    final sliding = passenger.phase == PassengerPhase.seatSliding ||
        passenger.phase == PassengerPhase.shuffleWait;
    final aisleLayout = layout.aisles[passenger.seat.aisleIndex];
    final aisleX = aisleLayout.centerX;
    final rowY = layout.rowStartY + passenger.rowPosition * layout.rowSpacing;

    double shuffleOffsetX = 0;
    if (passenger.shufflePhase != ShufflePhase.none) {
      final toAisle = aisleX - seatRect.center.dx;
      final double fraction;
      switch (passenger.shufflePhase) {
        case ShufflePhase.exitingToAisle:
          fraction = passenger.shufflePhaseProgress;
        case ShufflePhase.waitingInAisle:
          fraction = 1.0;
        case ShufflePhase.returningToSeat:
          fraction = 1.0 - passenger.shufflePhaseProgress;
        case ShufflePhase.none:
          fraction = 0;
      }
      shuffleOffsetX = toAisle * fraction;
    }

    double x;
    double y;
    if (seated) {
      x = seatRect.center.dx;
      y = seatRect.center.dy + 1;
    } else if (sliding) {
      final eased = passenger.seatSlideProgress * passenger.seatSlideProgress *
          (3 - 2 * passenger.seatSlideProgress);
      x = ui.lerpDouble(aisleX, seatRect.center.dx, eased)!;
      y = ui.lerpDouble(rowY, seatRect.center.dy + 1, eased)!;
    } else {
      x = aisleX;
      y = rowY;
    }

    final isWalking = passenger.phase == PassengerPhase.walking;
    final bob = isWalking ? math.sin(passenger.animationTime * 16) * 1.6 : 0.0;
    final center = Offset(x + shuffleOffsetX, y + bob);

    final alpha = (passenger.phase == PassengerPhase.shuffleWait &&
            passenger.seatSlideProgress == 0)
        ? 0.55
        : sliding
            ? ui.lerpDouble(0.55, 1.0, passenger.seatSlideProgress)!
            : 1.0;

    final zoneColor = zoneColors[passenger.seat.zone];

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: center + const Offset(0, 10), width: 18, height: 6),
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.22 * alpha),
    );

    // Luggage
    final bagRect = Rect.fromCenter(
      center: center + const Offset(-7, 2),
      width: 6,
      height: 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bagRect, const Radius.circular(2)),
      Paint()..color = Color.fromRGBO(180, 100, 60, alpha),
    );
    // Bag handle
    canvas.drawLine(
      Offset(bagRect.left + 1.5, bagRect.top),
      Offset(bagRect.right - 1.5, bagRect.top),
      Paint()
        ..color = Color.fromRGBO(130, 70, 40, alpha)
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round,
    );

    // Body — zone-colored with slight gradient feel via inner highlight
    final bodyColor = zoneColor.withValues(alpha: alpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 11, height: 15),
        const Radius.circular(5.5),
      ),
      Paint()..color = bodyColor,
    );
    // Body highlight strip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center + const Offset(0, -2), width: 4, height: 8),
        const Radius.circular(2),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18 * alpha),
    );

    // Head
    canvas.drawCircle(
      center + const Offset(0, -9.5),
      5.0,
      Paint()..color = Color.fromRGBO(250, 210, 175, alpha),
    );
    // Eyes
    canvas.drawCircle(center + const Offset(-1.6, -9.8), 0.7,
        Paint()..color = Color.fromRGBO(70, 50, 40, alpha));
    canvas.drawCircle(center + const Offset(1.6, -9.8), 0.7,
        Paint()..color = Color.fromRGBO(70, 50, 40, alpha));

    // Legs
    final legPaint = Paint()
      ..color = Color.fromRGBO(55, 72, 100, alpha)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final stride = isWalking ? math.sin(passenger.animationTime * 16) * 2.2 : 0.0;
    canvas.drawLine(center + const Offset(-2.5, 6.5),
        center + Offset(-3.5 - stride, 11), legPaint);
    canvas.drawLine(center + const Offset(2.5, 6.5),
        center + Offset(3.5 + stride, 11), legPaint);
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    double fontSize,
    Color color, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'sans-serif',
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color,
          letterSpacing: bold ? 0.5 : 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }
}
