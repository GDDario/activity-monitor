import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:app/domain/use_cases/tracking_metrics.dart';

class MetricChart extends StatelessWidget {
  const MetricChart({
    super.key,
    required this.points,
    required this.description,
  });
  final List<MetricPoint> points;
  final String description;
  @override
  Widget build(BuildContext context) => Semantics(
    label: description,
    image: true,
    child: SizedBox(
      height: 100,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(points, Theme.of(context).colorScheme.primary),
      ),
    ),
  );
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter(this.points, this.color);
  final List<MetricPoint> points;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final low = points.map((p) => p.value).reduce(math.min),
        high = points.map((p) => p.value).reduce(math.max),
        span = high == low ? 1.0 : high - low;
    final start = points.first.at.millisecondsSinceEpoch,
        end = points.last.at.millisecondsSinceEpoch;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x =
          8 +
          (end == start
                  ? .5
                  : (points[i].at.millisecondsSinceEpoch - start) /
                        (end - start)) *
              (size.width - 16);
      final y =
          size.height - 8 - (points[i].value - low) / span * (size.height - 16);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points || old.color != color;
}
