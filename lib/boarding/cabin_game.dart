import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'boarding_simulation.dart';
import 'aircraft_layout.dart';

class CabinGame extends FlameGame {
  CabinGame({required this.simulation, required this.onChanged});

  final BoardingSimulation simulation;
  AircraftLayout get layout => simulation.layout;
  final VoidCallback onChanged;
  double _notifyClock = 0;
  Offset? _lastPaintPosition;

  static const List<Color> zoneColors = [
    Color(0xFF4E91E5),
    Color(0xFFF2A64A),
    Color(0xFF56B991),
    Color(0xFFAD7BE0),
    Color(0xFFE56B6F),
    Color(0xFF49A9B7),
  ];

  @override
  Color backgroundColor() => const Color(0xFFF0F3F7);

  @override
  void update(double dt) {
    super.update(dt);
    simulation.update(dt);
    if (simulation.isBoarding) {
      _notifyClock += dt;
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
    final scale = math.min(
      size.x / layout.designWidth,
      size.y / layout.designHeight,
    );
    final left = (size.x - layout.designWidth * scale) / 2;
    final top = (size.y - layout.designHeight * scale) / 2;
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
    final scale = math.min(
      size.x / layout.designWidth,
      size.y / layout.designHeight,
    );
    canvas.translate(
      (size.x - layout.designWidth * scale) / 2,
      (size.y - layout.designHeight * scale) / 2,
    );
    canvas.scale(scale);
    _drawCabin(canvas);
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
    final shadow = Paint()
      ..color = const Color(0x18202D40)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          layout.cabinShell.left + 4,
          layout.cabinShell.top + 9,
          layout.cabinShell.width - 8,
          layout.cabinShell.height - 8,
        ),
        Radius.circular(layout.cabinShell.cornerRadius - 2),
      ),
      shadow,
    );

    final shell = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          layout.cabinShell.left,
          layout.cabinShell.top,
          layout.cabinShell.width,
          layout.cabinShell.height,
        ),
        Radius.circular(layout.cabinShell.cornerRadius),
      ),
      shell,
    );
    final outline = Paint()
      ..color = const Color(0xFFD8E0E9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          layout.cabinShell.left,
          layout.cabinShell.top,
          layout.cabinShell.width,
          layout.cabinShell.height,
        ),
        Radius.circular(layout.cabinShell.cornerRadius),
      ),
      outline,
    );

    _drawCockpit(canvas);
    _drawEntrance(canvas);
    _drawAisle(canvas);
    _drawWindows(canvas);
    _drawRows(canvas);
  }

  void _drawCockpit(Canvas canvas) {
    final fill = Paint()..color = const Color(0xFFEAF3FA);
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
      const Color(0xFF72869B),
      bold: true,
    );
  }

  void _drawEntrance(Canvas canvas) {
    final doorway = Paint()..color = const Color(0xFF152B45);
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
    _text(
      canvas,
      'BOARDING GATE',
      Offset(layout.designWidth / 2, layout.gateLabelY),
      10,
      const Color(0xFF536B83),
      bold: true,
    );
    final arrow = Paint()
      ..color = const Color(0xFF82A0B8)
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
    final aisle = Paint()..color = const Color(0xFFF2F5F7);
    for (final lane in layout.aisles) {
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
        aisle,
      );
    }
    final dash = Paint()
      ..color = const Color(0xFFDCE4EA)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final lane in layout.aisles) {
      for (var row = 0; row < layout.rowCount; row++) {
        final y = layout.rowStartY + row * layout.rowSpacing;
        canvas.drawLine(
          Offset(lane.centerX, y + 4),
          Offset(lane.centerX, y + 14),
          dash,
        );
      }
    }
  }

  void _drawWindows(Canvas canvas) {
    final window = Paint()..color = const Color(0xFFD9EFF8);
    final windowBorder = Paint()
      ..color = const Color(0xFFBBD8E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var row = 0; row < layout.rowCount; row++) {
      final y = layout.rowStartY - 7 + row * layout.rowSpacing;
      for (final x in layout.windowCentersX) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 9, height: 20),
          const Radius.circular(5),
        );
        canvas.drawRRect(rect, window);
        canvas.drawRRect(rect, windowBorder);
      }
    }
  }

  void _drawRows(Canvas canvas) {
    for (var row = 0; row < layout.rowCount; row++) {
      final y = layout.rowStartY + row * layout.rowSpacing;
      _text(
        canvas,
        '${row + 1}',
        Offset(layout.seatBlocks.first.left - 3, y),
        9,
        const Color(0xFF95A3B1),
        bold: true,
      );
      _text(
        canvas,
        '${row + 1}',
        Offset(layout.seatBlocks.last.right + 3, y),
        9,
        const Color(0xFF95A3B1),
        bold: true,
      );

      // Slim overhead-bin panels frame each row and make the cabin read as a plane.
      final binPaint = Paint()..color = const Color(0xFFF5F7F9);
      for (final block in layout.seatBlocks) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(block.left, y - 17, block.right - block.left, 4),
            const Radius.circular(2),
          ),
          binPaint,
        );
      }
      for (var column = 0; column < layout.seatsPerRow; column++) {
        final seat = simulation.seats[row * layout.seatsPerRow + column];
        _drawSeat(canvas, _seatRect(row, column), seat.zone, seat.label);
      }
    }
  }

  void _drawSeat(Canvas canvas, Rect rect, int zone, String label) {
    final color = zoneColors[zone];
    final base = Paint()..color = color.withValues(alpha: 0.18);
    final outline = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(7));
    canvas.drawRRect(shape, base);
    canvas.drawRRect(shape, outline);
    final headrest = Paint()..color = color.withValues(alpha: 0.44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(rect.left + 4, rect.top + 3, rect.width - 8, 5),
        const Radius.circular(3),
      ),
      headrest,
    );
    _text(
      canvas,
      label,
      Offset(rect.center.dx, rect.center.dy + 4),
      7,
      const Color(0xFF44566A),
      bold: true,
    );
  }

  void _drawPassenger(Canvas canvas, BoardingPassenger? passenger) {
    if (passenger == null) return;
    final seatRect = _seatRect(passenger.seat.row, passenger.seat.column);
    final seated = passenger.phase == PassengerPhase.seated;
    final waiting = passenger.phase == PassengerPhase.shuffleWait;
    final aisleLayout = layout.aisles[passenger.seat.aisleIndex];
    final aisleX = aisleLayout.centerX;
    final rowY = layout.rowStartY + passenger.rowPosition * layout.rowSpacing;
    var x = (seated || waiting) ? seatRect.center.dx : aisleX;
    var y = (seated || waiting) ? seatRect.center.dy + 1 : rowY;

    // Smooth slide from aisle to seat during turning/stowing.
    if (!seated && !waiting &&
        (passenger.phase == PassengerPhase.turning ||
            passenger.phase == PassengerPhase.stowing)) {
      final eased =
          passenger.turnProgress *
          passenger.turnProgress *
          (3 - 2 * passenger.turnProgress);
      x = ui.lerpDouble(aisleX, seatRect.center.dx, eased)!;
      y = ui.lerpDouble(rowY, seatRect.center.dy + 10, eased)!;
    }

    // Shuffle animation: seated blocker slides toward aisle then returns.
    double shuffleOffsetX = 0;
    if (passenger.isShuffling) {
      // sin(0→π) gives 0→1→0 arc; scale by distance to aisle.
      final arc = math.sin(passenger.shuffleProgress * math.pi);
      final toAisle = aisleX - seatRect.center.dx;
      shuffleOffsetX = toAisle * arc * 0.55;
    }

    final bob = !seated && !waiting && passenger.phase == PassengerPhase.walking
        ? math.sin(passenger.animationTime * 16) * 1.6
        : 0.0;
    final center = Offset(x + shuffleOffsetX, y + bob);

    // Dim passengers who are waiting in their seat for blockers to move.
    final alpha = waiting ? 0.45 : 1.0;

    final shadow = Paint()..color = Color.fromRGBO(13, 34, 56, 0.19 * alpha);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + const Offset(0, 10),
        width: 19,
        height: 7,
      ),
      shadow,
    );
    final bag = Paint()..color = Color.fromRGBO(202, 112, 78, alpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + const Offset(-6, 2),
          width: 7,
          height: 12,
        ),
        const Radius.circular(3),
      ),
      bag,
    );
    final bodyColor = zoneColors[passenger.seat.zone].withValues(alpha: alpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 12, height: 16),
        const Radius.circular(6),
      ),
      Paint()..color = bodyColor,
    );
    canvas.drawCircle(
      center + const Offset(0, -9),
      5.2,
      Paint()..color = Color.fromRGBO(255, 213, 179, alpha),
    );
    canvas.drawCircle(
      center + const Offset(-1.8, -10),
      0.7,
      Paint()..color = Color.fromRGBO(81, 59, 50, alpha),
    );
    canvas.drawCircle(
      center + const Offset(1.8, -10),
      0.7,
      Paint()..color = Color.fromRGBO(81, 59, 50, alpha),
    );
    final legs = Paint()
      ..color = Color.fromRGBO(64, 81, 104, alpha)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final stride = !seated && !waiting && passenger.phase == PassengerPhase.walking
        ? math.sin(passenger.animationTime * 16) * 2
        : 0.0;
    canvas.drawLine(
      center + const Offset(-3, 7),
      center + Offset(-4 - stride, 11),
      legs,
    );
    canvas.drawLine(
      center + const Offset(3, 7),
      center + Offset(4 + stride, 11),
      legs,
    );
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
