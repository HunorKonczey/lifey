import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One split's worth of the chart (docs/cardio/61 §2 M33).
class PaceBar {
  const PaceBar({
    required this.durationSeconds,
    required this.label,
    this.partial = false,
  });

  final int durationSeconds;

  /// What the value label reads when this bar turns out to be the fastest
  /// (e.g. `5:02`) — pre-formatted by the caller, since only it knows the
  /// unit system.
  final String label;

  /// The run's last, sub-kilometer piece. Drawn, but **excluded from the
  /// evaluation**: it isn't scored, scaled, labelled, or averaged. Its
  /// duration is short simply because its distance is, so letting it into
  /// the scale would crown it the fastest split of the run.
  final bool partial;
}

/// Per-split pace as discrete bars, **taller = faster** (docs/cardio/61 §2
/// M33). Deliberately bars and not an area chart: splits are discrete units
/// (one km = one bar), an area would assert a continuity that isn't there,
/// and an area can't be tapped section by section.
///
/// Selection is owned by the caller, not by this widget: the same index also
/// highlights a row in the split list next to it, and the two are one datum
/// in two views (M33's own words). Painted by hand, like every other chart
/// in this app — no chart dependency.
class PaceBarChart extends StatelessWidget {
  const PaceBarChart({
    super.key,
    required this.bars,
    required this.accent,
    this.selectedIndex,
    this.onBarTap,
    this.height = 150,
  });

  final List<PaceBar> bars;
  final Color accent;
  final int? selectedIndex;
  final ValueChanged<int>? onBarTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final geometry = PaceBarGeometry(bars, size);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: onBarTap == null
                ? null
                : (details) {
                    final index = geometry.indexAt(details.localPosition.dx);
                    if (index != null) onBarTap!(index);
                  },
            child: CustomPaint(
              size: size,
              painter: _PaceBarPainter(
                geometry: geometry,
                accent: accent,
                trackColor: scheme.surfaceContainerHighest,
                mutedColor: scheme.outlineVariant,
                averageLineColor: scheme.outlineVariant,
                selectedIndex: selectedIndex,
                textDirection: Directionality.of(context),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Where each bar sits and how tall it is. Split out from the painter so the
/// tap handler runs the identical maths without painting — and public so the
/// two rules that would fail silently (taller = faster, and the partial tail
/// staying out of the scale) can be unit-tested as plain arithmetic instead
/// of inferred from pixels.
class PaceBarGeometry {
  PaceBarGeometry(this.bars, this.size);

  final List<PaceBar> bars;
  final Size size;

  /// Room above the tallest bar for the fastest split's value label.
  static const double _labelBand = 16;

  /// M33's bar width, and the narrower one it falls back to from 15 splits up.
  static const double _maxBarWidth = 26;
  static const double _denseBarWidth = 14;

  double get _slotWidth => bars.isEmpty ? 0 : size.width / bars.length;

  double get barWidth {
    final target = bars.length >= 15 ? _denseBarWidth : _maxBarWidth;
    return math.min(target, math.max(4, _slotWidth - 4));
  }

  /// The bars that count: everything but the partial tail (see [PaceBar.partial]).
  Iterable<PaceBar> get _scored => bars.where((b) => !b.partial);

  int? get slowestSeconds => _scored.isEmpty
      ? null
      : _scored.map((b) => b.durationSeconds).reduce(math.max);

  int? get fastestSeconds => _scored.isEmpty
      ? null
      : _scored.map((b) => b.durationSeconds).reduce(math.min);

  /// The index of the single fastest scored bar — the only one that gets a
  /// value label. Null when nothing is scored.
  int? get fastestIndex {
    int? best;
    for (var i = 0; i < bars.length; i++) {
      if (bars[i].partial) continue;
      if (best == null || bars[i].durationSeconds < bars[best].durationSeconds) best = i;
    }
    return best;
  }

  /// Maps a duration to a 0..1 bar height, inverted so the *quickest* split
  /// is the *tallest* bar. A run of identical splits has no span to spread
  /// over, so every bar lands on the same mid-height rather than dividing by
  /// zero or all shooting to full height.
  double _heightFractionFor(int seconds) {
    final slowest = slowestSeconds;
    final fastest = fastestSeconds;
    if (slowest == null || fastest == null) return 0.5;
    final span = slowest - fastest;
    if (span <= 0) return 0.72;
    final speed = ((slowest - seconds) / span).clamp(0.0, 1.0);
    return 0.35 + 0.65 * speed;
  }

  /// The partial tail is drawn short and flat — it carries no comparable
  /// pace, so any height would be a claim about speed.
  static const double _partialHeightFraction = 0.22;

  double get _plotHeight => math.max(0, size.height - _labelBand);

  Rect barRect(int index) {
    final bar = bars[index];
    final fraction =
        bar.partial ? _partialHeightFraction : _heightFractionFor(bar.durationSeconds);
    final barHeight = _plotHeight * fraction;
    final left = index * _slotWidth + (_slotWidth - barWidth) / 2;
    return Rect.fromLTWH(left, size.height - barHeight, barWidth, barHeight);
  }

  /// The dashed reference line's Y, at the mean of the scored durations —
  /// mapped through the same inverted scale as the bars.
  double? get averageLineY {
    if (_scored.isEmpty) return null;
    final mean =
        _scored.map((b) => b.durationSeconds).reduce((a, b) => a + b) / _scored.length;
    final fraction = _heightFractionFor(mean.round());
    return size.height - _plotHeight * fraction;
  }

  int? indexAt(double dx) {
    if (bars.isEmpty || _slotWidth <= 0) return null;
    final index = (dx / _slotWidth).floor();
    if (index < 0 || index >= bars.length) return null;
    return index;
  }
}

class _PaceBarPainter extends CustomPainter {
  _PaceBarPainter({
    required this.geometry,
    required this.accent,
    required this.trackColor,
    required this.mutedColor,
    required this.averageLineColor,
    required this.selectedIndex,
    required this.textDirection,
  });

  final PaceBarGeometry geometry;
  final Color accent;
  final Color trackColor;
  final Color mutedColor;
  final Color averageLineColor;
  final int? selectedIndex;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.bars.isEmpty) return;
    _paintAverageLine(canvas, size);

    final radius = Radius.circular(math.min(7, geometry.barWidth / 2));
    for (var i = 0; i < geometry.bars.length; i++) {
      final bar = geometry.bars[i];
      final rect = geometry.barRect(i);
      final selected = i == selectedIndex;
      final paint = Paint()
        ..color = bar.partial
            ? mutedColor
            : (selected ? accent : accent.withValues(alpha: 0.62));
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }

    _paintFastestLabel(canvas, size);
  }

  void _paintAverageLine(Canvas canvas, Size size) {
    final y = geometry.averageLineY;
    if (y == null) return;
    final paint = Paint()
      ..color = averageLineColor
      ..strokeWidth = 1;
    // M33's `dash 3 5`.
    const dash = 3.0;
    const gap = 5.0;
    for (var x = 0.0; x < size.width; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + dash, size.width), y), paint);
    }
  }

  /// Only the fastest split gets a number on the chart — every other value is
  /// one tap away in the list, and labelling them all would out-shout the
  /// shape the chart exists to show.
  void _paintFastestLabel(Canvas canvas, Size size) {
    final index = geometry.fastestIndex;
    if (index == null) return;
    final rect = geometry.barRect(index);
    final painter = TextPainter(
      text: TextSpan(
        text: geometry.bars[index].label,
        style: TextStyle(
          color: accent,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: textDirection,
    )..layout();
    final left = (rect.center.dx - painter.width / 2).clamp(0.0, size.width - painter.width);
    painter.paint(canvas, Offset(left, math.max(0, rect.top - painter.height - 3)));
  }

  @override
  bool shouldRepaint(_PaceBarPainter oldDelegate) =>
      oldDelegate.geometry.bars != geometry.bars ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.accent != accent;
}
