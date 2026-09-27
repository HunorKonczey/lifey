import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../domain/trainer_client.dart';

/// The weight line at the top right of a client card (canvas Lifey 6 › 9.1):
/// no axes, no labels, no tap target, in the weight blue.
///
/// Decoration, not a chart. Two points is the minimum — a single reading has
/// no trend to draw, and drawing one anyway would be a claim the data doesn't
/// support.
class WeightSparkline extends StatelessWidget {
  const WeightSparkline({super.key, required this.points, this.height = 34, this.width = 88});

  final List<WeightTrendPoint> points;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    // Decorative: the numbers it hints at are in the Weight KPI and on the
    // weight tab, and a screen reader has nothing useful to say about a
    // 34-pixel line.
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: width,
        child: CustomPaint(
          painter: _SparklinePainter(points: points, color: context.metricColors.weight),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<WeightTrendPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final weights = points.map((p) => p.weightKg).toList();
    final min = weights.reduce((a, b) => a < b ? a : b);
    final max = weights.reduce((a, b) => a > b ? a : b);
    final span = max - min;

    // Keeps the stroke off the box's edge.
    const inset = 2.0;
    final path = Path();
    for (var i = 0; i < weights.length; i++) {
      final x = inset + (size.width - 2 * inset) * (i / (weights.length - 1));
      // A flat run has no range to normalise against — draw it down the
      // middle instead of dividing by zero.
      final normalised = span == 0 ? 0.5 : (weights[i] - min) / span;
      final y = size.height - inset - normalised * (size.height - 2 * inset);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
