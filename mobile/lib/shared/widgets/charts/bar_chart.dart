import 'package:flutter/material.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../ds/animated_fill.dart';
import 'chart_math.dart';

/// One bar of a [LifeyBarChart].
class BarDatum {
  const BarDatum({
    required this.label,
    required this.value,
    this.highlighted = false,
    this.semanticsLabel,
  });

  /// X-axis label — a weekday letter ("T" / "Cs") or a date ("Sep 24").
  final String label;

  /// null = no data for that slot (drawn as an empty column).
  final double? value;

  /// "Today" / the current week: full colour and a bold label; the other
  /// bars are drawn at 45 %.
  final bool highlighted;

  /// What a screen reader says for this bar, e.g. "Monday, 1 680 kcal".
  final String? semanticsLabel;
}

/// The v2 bar chart (canvas: dashboard "This week", stats "Workouts · last
/// 30 days"; docs/redesign/77-mobile-redesign-plan.md R0.13, D-R0.9).
///
/// A 34 px Y axis with three labels (nice max, half, 0 — "2.4k / 1.2k / 0"),
/// bars with 6 px top corners in the metric [color] (45 % except the
/// highlighted one), an optional dashed [goal] line in the same colour, a
/// hairline baseline and the X labels under it — the highlighted one bold.
/// Bars grow in on first appearance and animate only by the difference
/// later. Custom-painted, no chart library (D-R0.9).
class LifeyBarChart extends StatelessWidget {
  const LifeyBarChart({
    super.key,
    required this.bars,
    required this.color,
    this.goal,
    this.height = 96,
    this.barGap = 8,
    this.integer = false,
    this.semanticsLabel,
  });

  final List<BarDatum> bars;
  final Color color;
  final double? goal;

  /// Plot height: 96 on the dashboard, 150 on the stats screen.
  final double height;

  /// 8 for 7 daily bars, 14 for 5 weekly bars on the canvases.
  final double barGap;

  /// Whole-number data (counts): axis headroom for small peaks.
  final bool integer;

  /// Summary for screen readers, e.g. "This week, average 1 631 kcal".
  final String? semanticsLabel;

  static const double axisWidth = 34;

  /// More bars than this and the X labels are sparse (see [BarDatum.label]).
  static const int sparseThreshold = 12;

  bool get _sparse => bars.length > sparseThreshold;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final dataMax =
        bars.fold<double>(0, (m, b) => (b.value ?? 0) > m ? b.value! : m);
    final ticks = yAxisTicks(dataMax, goal: goal, integer: integer);
    final top = ticks.first;
    final labelStyle = Theme.of(context).textTheme.labelSmall!.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1,
          color: p.text3,
        );

    String tick(double v) {
      if (v >= 1000) return f.compactAxis(v);
      if (v == v.roundToDouble()) return f.integer(v);
      return f.decimal(v, 1);
    }

    final chart = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Y axis: labels centred on the top line, the middle and the baseline.
        // Not read out — "2.4k, 1.2k, 0" means nothing on its own; the bars'
        // own labels and the chart summary carry the data.
        ExcludeSemantics(
          child: SizedBox(
            width: axisWidth,
            height: height,
            child: Stack(clipBehavior: Clip.none, children: [
              for (final (i, v) in ticks.indexed)
                Positioned(
                  right: 0,
                  left: 0,
                  top: height * i / 2 - 6,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(tick(v),
                        style: labelStyle, textAlign: TextAlign.right),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: height,
                child: AnimatedFill(
                  values: [
                    for (final b in bars) ((b.value ?? 0) / top).clamp(0.0, 1.0)
                  ],
                  builder: (context, fractions) => CustomPaint(
                    painter: _BarsPainter(
                      fractions: fractions,
                      highlighted: [for (final b in bars) b.highlighted],
                      goalFraction:
                          goal == null ? null : (goal! / top).clamp(0.0, 1.0),
                      color: color,
                      baseline: p.hairline,
                      gap: barGap,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                for (final (i, b) in bars.indexed) ...[
                  if (i > 0) SizedBox(width: barGap),
                  Expanded(
                    child: Semantics(
                      label: b.semanticsLabel,
                      excludeSemantics: b.semanticsLabel != null,
                      child: _sparse
                          // Many slim bars: the few labelled ones are centred on
                          // their bar and may be wider than it (empty labels
                          // draw nothing) — scaling "Sep 10" down into a 6 px
                          // slot would make it unreadable.
                          ? SizedBox(
                              height: 14,
                              child: OverflowBox(
                              maxWidth: 64,
                              // The end labels hug the chart's edges instead
                              // of hanging past them.
                              alignment: i == 0
                                  ? Alignment.topLeft
                                  : (i == bars.length - 1 ? Alignment.topRight : Alignment.topCenter),
                              child: Text(
                                b.label,
                                maxLines: 1,
                                softWrap: false,
                                style: b.highlighted
                                    ? labelStyle.copyWith(fontWeight: FontWeight.w800, color: p.text)
                                    : labelStyle,
                              ),
                            ),
                            )
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                b.label,
                                maxLines: 1,
                                style: b.highlighted
                                    ? labelStyle.copyWith(fontWeight: FontWeight.w800, color: p.text)
                                    : labelStyle,
                              ),
                            ),
                    ),
                  ),
                ],
              ]),
            ],
          ),
        ),
      ],
    );

    if (semanticsLabel == null) return chart;
    // explicitChildNodes keeps each bar's own label instead of merging it
    // into the summary.
    return Semantics(
        label: semanticsLabel,
        container: true,
        explicitChildNodes: true,
        child: chart);
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.fractions,
    required this.highlighted,
    required this.goalFraction,
    required this.color,
    required this.baseline,
    required this.gap,
  });

  final List<double> fractions;
  final List<bool> highlighted;
  final double? goalFraction;
  final Color color;
  final Color baseline;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final n = fractions.length;
    if (n > 0) {
      final barWidth = (size.width - gap * (n - 1)) / n;
      for (var i = 0; i < n; i++) {
        final h = size.height * fractions[i];
        if (h <= 0) continue;
        final left = i * (barWidth + gap);
        final rect = Rect.fromLTWH(left, size.height - h, barWidth, h);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(6),
            topRight: const Radius.circular(6),
            bottomLeft: const Radius.circular(2),
            bottomRight: const Radius.circular(2),
          ),
          Paint()
            ..color = highlighted[i]
                ? color
                : color.withValues(alpha: color.a * 0.45),
        );
      }
    }

    // Hairline baseline.
    canvas.drawLine(
      Offset(0, size.height - 0.5),
      Offset(size.width, size.height - 0.5),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    // Dashed goal line (canvas: 1.5 px, metric colour at 70 %).
    if (goalFraction != null) {
      final y = size.height * (1 - goalFraction!);
      final paint = Paint()
        ..color = color.withValues(alpha: color.a * 0.7)
        ..strokeWidth = 1.5;
      const dash = 5.0, space = 4.0;
      for (var x = 0.0; x < size.width; x += dash + space) {
        canvas.drawLine(
            Offset(x, y), Offset((x + dash).clamp(0, size.width), y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.fractions != fractions ||
      old.goalFraction != goalFraction ||
      old.color != color ||
      old.baseline != baseline ||
      old.gap != gap;
}
