import 'package:flutter/material.dart';

/// Y positions of a sparkline's [values] inside a box of [height]: the
/// highest value at the top, the lowest at the bottom, both inset by [pad] so
/// the stroke and the end dot are never cut off. A flat series sits in the
/// middle. Pure so it is unit-testable.
List<double> sparklineYs(List<double> values, double height, {double pad = 4.5}) {
  if (values.isEmpty) return const [];
  final lo = values.reduce((a, b) => a < b ? a : b);
  final hi = values.reduce((a, b) => a > b ? a : b);
  final span = hi - lo;
  final usable = height - 2 * pad;
  if (span == 0) return [for (final _ in values) height / 2];
  return [for (final v in values) pad + (hi - v) / span * usable];
}

/// A small line of recent values with a dot on the last one — the weight
/// tile's trend (design system v2, canvas Lifey 1: 120 × 56, 2.5 px round
/// stroke, r 4.5 end dot; docs/redesign/77-mobile-redesign-plan.md R1.4).
///
/// Decorative: it carries no axis, so the value it sits next to is what a
/// screen reader gets. Needs at least two values; with fewer it draws nothing.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.size = const Size(120, 56),
  });

  /// Oldest first.
  final List<double> values;
  final Color color;
  final Size size;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox.fromSize(size: size);
    return ExcludeSemantics(
      child: CustomPaint(
        size: size,
        painter: _SparklinePainter(values: values, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  static const double _stroke = 2.5;
  static const double _dot = 4.5;

  @override
  void paint(Canvas canvas, Size size) {
    final ys = sparklineYs(values, size.height, pad: _dot);
    // The last point sits on the right edge; the dot may overhang the box.
    final dx = size.width / (values.length - 1);
    final path = Path()..moveTo(0, ys.first);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(dx * i, ys[i]);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.drawCircle(Offset(size.width, ys.last), _dot, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.color != color || old.values != values;
}
