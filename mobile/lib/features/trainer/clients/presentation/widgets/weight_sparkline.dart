import 'package:flutter/material.dart';

import '../../domain/trainer_client.dart';

/// The very faint weight trend along the bottom of a client card (frame B1,
/// following the web client card's sparkline).
///
/// Decoration, not a chart: no axes, no labels, no tap target. Two points is
/// the minimum — a single reading has no trend to draw, and drawing one
/// anyway would be a claim the data doesn't support.
class WeightSparkline extends StatelessWidget {
  const WeightSparkline({super.key, required this.points, this.height = 22});

  final List<WeightTrendPoint> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    // Decorative: the numbers it hints at are on the weight tab, and a
    // screen reader has nothing useful to say about a 22-pixel trend line.
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparklinePainter(
            points: points,
            color: Theme.of(context).colorScheme.tertiary,
          ),
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

    final path = Path();
    for (var i = 0; i < weights.length; i++) {
      final x = size.width * (i / (weights.length - 1));
      // A flat run has no range to normalise against — draw it down the
      // middle instead of dividing by zero.
      final normalised = span == 0 ? 0.5 : (weights[i] - min) / span;
      final y = size.height - (normalised * size.height);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.color != color;
}
