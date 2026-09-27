import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'animated_fill.dart';

/// Split of a progress value into the two arcs a ring draws: the first lap
/// (0–1) and, past the goal, the overflow lap (0–1) drawn on top of it.
/// Negative and NaN progress count as 0; a second overflow lap is never drawn
/// (a ring at 300 % shows one full overflow lap), so no arc sweeps past 360°.
({double lap, double overflow}) ringSweeps(double progress) {
  final p = progress.isNaN ? 0.0 : progress;
  if (p <= 0) return (lap: 0, overflow: 0);
  if (p <= 1) return (lap: p, overflow: 0);
  return (lap: 1, overflow: math.min(p - 1, 1));
}

/// A circular progress ring (design system v2 — dashboard hero 144, macro
/// rings 88, week-strip rings 30; docs/redesign/77-mobile-redesign-plan.md
/// R0.9).
///
/// Starts at 12 o'clock, round caps, the track in surface-3, the fill in
/// the metric colour. Stroke defaults to 15/160 of the size, the canvases'
/// proportion. Fills in from 0 on first appearance (900 ms, enter curve,
/// optional stagger [delay]); later changes animate only the difference.
///
/// **Past the goal** the ring completes and a second lap starts over it in
/// the same colour, with a soft shadow under its leading end so the overlap
/// reads — no extra colour, so "colour means data" holds. [overColor]
/// recolours the overflow lap when a screen wants the warning louder. The
/// [child] sits in the centre (e.g. a MetricValue).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.color,
    this.size = 144,
    this.strokeWidth,
    this.overColor,
    this.delay = Duration.zero,
    this.child,
    this.semanticsLabel,
  });

  /// value / goal; 1 = goal reached, > 1 = over.
  final double progress;
  final Color color;
  final double size;
  final double? strokeWidth;
  final Color? overColor;
  final Duration delay;
  final Widget? child;

  /// e.g. "Calories, 26 % of goal". Without it the ring is decorative and
  /// only [child] is read.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final stroke = strokeWidth ?? size * 15 / 160;
    final track = context.palette.control;
    final ring = AnimatedFill(
      values: [progress.isNaN ? 0 : progress],
      delay: delay,
      builder: (context, v) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(
          progress: v.single,
          color: color,
          overColor: overColor ?? color,
          track: track,
          stroke: stroke,
        ),
        child: SizedBox.square(dimension: size, child: child == null ? null : Center(child: child)),
      ),
    );
    // Holds its own size even under tight constraints (a stretched Column):
    // the ring is centred instead of its canvas and child being widened.
    final sized = Align(widthFactor: 1, heightFactor: 1, child: SizedBox.square(dimension: size, child: ring));
    if (semanticsLabel == null) return sized;
    return Semantics(label: semanticsLabel, child: sized);
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.overColor,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color overColor;
  final Color track;
  final double stroke;

  static const double _start = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    Paint arc(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, arc(track));

    final (:lap, :overflow) = ringSweeps(progress);
    if (lap <= 0) return;
    if (lap >= 1) {
      canvas.drawCircle(center, radius, arc(color)); // closed ring, no cap seam
    } else {
      canvas.drawArc(rect, _start, lap * 2 * math.pi, false, arc(color));
    }

    if (overflow > 0) {
      final sweep = overflow * 2 * math.pi;
      final end = _start + sweep;
      final tip = center + Offset(math.cos(end), math.sin(end)) * radius;
      // Shadow under the overflow lap's leading end, so the second lap reads
      // as lying on top of the first.
      canvas.drawCircle(
        tip,
        stroke / 2,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke / 3),
      );
      canvas.drawArc(rect, _start, sweep, false, arc(overColor));
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.overColor != overColor ||
      old.track != track ||
      old.stroke != stroke;
}
