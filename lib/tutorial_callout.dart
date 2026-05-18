part of 'app.dart';

Offset? _targetCenterInOverlay({
  required BuildContext overlayContext,
  required GlobalKey targetKey,
}) {
  final targetContext = targetKey.currentContext;
  if (targetContext == null) return null;
  final targetRender = targetContext.findRenderObject();
  final overlayRender = overlayContext.findRenderObject();
  if (targetRender is! RenderBox || overlayRender is! RenderBox) return null;
  final centerGlobal = targetRender.localToGlobal(
    targetRender.size.center(Offset.zero),
  );
  return overlayRender.globalToLocal(centerGlobal);
}

Offset _anchorPointOnRect(Rect rect, Offset toward) {
  final dx = toward.dx - rect.center.dx;
  final dy = toward.dy - rect.center.dy;
  if (dy.abs() >= dx.abs()) {
    return Offset(
      toward.dx.clamp(rect.left + 12, rect.right - 12).toDouble(),
      dy >= 0 ? rect.bottom : rect.top,
    );
  }
  return Offset(
    dx >= 0 ? rect.right : rect.left,
    toward.dy.clamp(rect.top + 12, rect.bottom - 12).toDouble(),
  );
}

class _TutorialCurvedArrow extends StatelessWidget {
  const _TutorialCurvedArrow({required this.start, required this.end});

  final Offset start;
  final Offset end;
  final Color color = const Color(0xFF6EE7FF);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _TutorialCurvedArrowPainter(
          start: start,
          end: end,
          color: color,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _TutorialCurvedArrowPainter extends CustomPainter {
  const _TutorialCurvedArrowPainter({
    required this.start,
    required this.end,
    required this.color,
  });

  final Offset start;
  final Offset end;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(start.dx, start.dy);
    final bend = (end.dy - start.dy).abs().clamp(40.0, 140.0);
    final c1 = Offset(start.dx, start.dy + bend * 0.35);
    final c2 = Offset(end.dx, end.dy - bend * 0.45);
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);

    final tangent = path.computeMetrics().isEmpty
        ? null
        : path.computeMetrics().first.getTangentForOffset(
            path.computeMetrics().first.length,
          );
    if (tangent == null) return;
    final angle = tangent.angle;
    const headLength = 13.0;
    const headAngle = 0.52;
    final p1 = end;
    final p2 = Offset(
      end.dx - headLength * math.cos(angle - headAngle),
      end.dy - headLength * math.sin(angle - headAngle),
    );
    final p3 = Offset(
      end.dx - headLength * math.cos(angle + headAngle),
      end.dy - headLength * math.sin(angle + headAngle),
    );
    final head = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TutorialCurvedArrowPainter oldDelegate) {
    return oldDelegate.start != start ||
        oldDelegate.end != end ||
        oldDelegate.color != color;
  }
}
