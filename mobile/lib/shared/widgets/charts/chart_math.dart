import 'dart:math' as math;

/// Pure helpers behind the v2 charts (docs/redesign/77-mobile-redesign-plan.md
/// R0.13, D-R0.9). Kept free of widgets so they are unit-tested on their own.

/// The top of a chart's Y axis for data peaking at [max].
///
/// Rounds up to two significant digits — 2 360 → 2 400, 12 612 → 13 000, the
/// canvases' axes — so the three labels (top, half, 0) read cleanly. For
/// [integer] data that peaks below 10 (workouts per week) the axis gets one
/// step of headroom, so the tallest bar isn't flush with the top: a peak of
/// 6 gives 7, as the stats canvas draws it. An empty chart gets 1.
double niceAxisMax(double max, {bool integer = false}) {
  if (max.isNaN || max <= 0) return 1;
  final digits = (math.log(max) / math.ln10).floor() + 1;
  var step = math.pow(10, digits - 2).toDouble();
  if (integer && step < 1) step = 1;
  final top = (max / step).ceil() * step;
  if (integer && max < 10 && top == max) return top + step;
  return top;
}

/// The three Y-axis values drawn by the charts, top to bottom: the nice
/// max, its half, and 0. The half is exact (3.5 for 7) — the label
/// formatter decides the decimals.
List<double> yAxisTicks(double dataMax, {double? goal, bool integer = false}) {
  final peak = math.max(dataMax, goal ?? 0);
  final top = niceAxisMax(peak, integer: integer);
  return [top, top / 2, 0];
}

/// The average of daily values **without today's partial day** — a
/// half-logged today would drag every morning's weekly average down (plan §9
/// risk 5). Days with no value are skipped; with [ignoreZero] so are zero
/// days (for calories a 0 means "nothing logged", not "ate nothing").
/// Returns null when no complete day is left.
double? averageExcludingPartialToday(
  List<({DateTime day, double? value})> points,
  DateTime now, {
  bool ignoreZero = false,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final values = [
    for (final p in points)
      if (p.value != null &&
          DateTime(p.day.year, p.day.month, p.day.day).isBefore(today) &&
          !(ignoreZero && p.value == 0))
        p.value!,
  ];
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}
