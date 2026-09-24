import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'animated_fill.dart';

/// A horizontal progress bar in a metric colour — the macro rows of the
/// dashboard hero and the metric tiles (design system v2; 7 px, fully
/// rounded, surface-3 track; docs/redesign/77-mobile-redesign-plan.md R0.9).
///
/// [progress] is value / goal, clamped to the bar; an over-goal state is the
/// caller's text ("212 kcal over"), not a longer bar. Fills in on first
/// appearance and animates only the difference after that.
class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.progress,
    required this.color,
    this.height = 7,
    this.delay = Duration.zero,
  });

  final double progress;
  final Color color;
  final double height;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final target = progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: height,
        child: ColoredBox(
          color: context.palette.control,
          child: AnimatedFill(
            values: [target],
            delay: delay,
            builder: (context, v) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: v.single.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: radius)),
            ),
          ),
        ),
      ),
    );
  }
}

/// One coloured part of a [RatioBar].
typedef RatioSegment = ({double value, Color color});

/// A segmented bar of parts in their metric colours, 3 px apart — the
/// nutrition day budget's P / C / F bar and the macros tab's daily split
/// (10 px, radius 5, surface-3 track).
///
/// With [total] (the day's calorie goal) each segment is `value / total` of
/// the width and the rest of the track is what's left of the budget; past the
/// total the segments are scaled down together to fill the bar. Without
/// [total] the segments split the whole bar by their share (100 %).
class RatioBar extends StatelessWidget {
  const RatioBar({
    super.key,
    required this.segments,
    this.total,
    this.height = 10,
    this.gap = 3,
  });

  final List<RatioSegment> segments;
  final double? total;
  final double height;
  final double gap;

  /// Width fractions of each segment (0–1, summing to ≤ 1). Negative and NaN
  /// values count as 0.
  static List<double> fractions(List<double> values, double? total) {
    final clean = [for (final v in values) (v.isNaN || v < 0) ? 0.0 : v];
    final sum = clean.fold<double>(0, (a, b) => a + b);
    if (sum == 0) return List.filled(clean.length, 0);
    final denominator = (total == null || total <= 0 || sum > total) ? sum : total;
    return [for (final v in clean) v / denominator];
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final target = fractions([for (final s in segments) s.value], total);
    return ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: context.palette.control,
        child: SizedBox(
          height: height,
          child: AnimatedFill(
            values: target,
            builder: (context, f) => LayoutBuilder(builder: (context, constraints) {
              final visible = [for (var i = 0; i < f.length; i++) if (f[i] > 0) i];
              final gaps = visible.isEmpty ? 0 : gap * (visible.length - 1);
              final usable = (constraints.maxWidth - gaps).clamp(0.0, double.infinity);
              return Row(children: [
                for (final (n, i) in visible.indexed) ...[
                  if (n > 0) SizedBox(width: gap),
                  SizedBox(width: usable * f[i], child: ColoredBox(color: segments[i].color)),
                ],
              ]);
            }),
          ),
        ),
      ),
    );
  }
}
