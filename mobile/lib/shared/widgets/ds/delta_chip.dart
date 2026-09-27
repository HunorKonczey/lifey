import 'package:flutter/material.dart';

import '../../../core/format/lifey_format.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'tinted_chip.dart';

/// A signed change as a tinted chip (design system v2; docs/redesign/
/// 77-mobile-redesign-plan.md R0.7). Two canvas styles:
///
/// - [DeltaChip.arrow] — "↓ 0.1 kg", "↓ 1.4 in 30 d": the direction is the
///   arrow, the number is unsigned (weight tile, weight hero).
/// - [DeltaChip.signed] — "−0.1", "+0.3": a real minus sign, no arrow
///   (weight history rows).
///
/// Colour follows the direction — down = `decrease` (weight blue), up =
/// `increase` (calorie orange), no change = neutral — unless [color] says
/// otherwise, e.g. protein green when the change is progress toward a goal
/// (the weight hero's 30-day chip on the canvas).
class DeltaChip extends StatelessWidget {
  const DeltaChip.arrow({
    super.key,
    required this.value,
    this.unit,
    this.suffix,
    this.digits = 1,
    this.color,
  }) : withArrow = true;

  const DeltaChip.signed({
    super.key,
    required this.value,
    this.unit,
    this.suffix,
    this.digits = 1,
    this.color,
  }) : withArrow = false;

  final num value;

  /// e.g. "kg"; appended after the number.
  final String? unit;

  /// e.g. "today", "in 30 d" — already localized, appended after the unit.
  final String? suffix;

  /// Decimals shown; a change that rounds to zero is neutral and unsigned.
  final int digits;

  /// Overrides the direction colour.
  final Color? color;

  final bool withArrow;

  @override
  Widget build(BuildContext context) {
    final f = LifeyFormat.of(context);
    final l10n = AppLocalizations.of(context)!;
    final rounded = num.parse(value.abs().toStringAsFixed(digits));
    final direction = rounded == 0 ? 0 : value.sign.toInt();
    final m = context.metricColors;
    final tone = color ??
        switch (direction) {
          < 0 => m.decrease,
          > 0 => m.increase,
          _ => context.palette.text2,
        };

    final number = withArrow ? f.decimal(value.abs().toDouble(), digits) : f.signedDelta(value, digits: digits);
    String join(List<String?> parts) => parts.whereType<String>().join(' ');
    final magnitude = join([f.decimal(value.abs().toDouble(), digits), unit]);
    final text = join([number, unit, suffix]);
    final spoken = switch (direction) {
      < 0 => l10n.deltaDownSemantics(magnitude),
      > 0 => l10n.deltaUpSemantics(magnitude),
      _ => magnitude,
    };

    return TintedChip(
      label: text,
      color: tone,
      icon: withArrow && direction != 0 ? (direction < 0 ? Icons.south_rounded : Icons.north_rounded) : null,
      semanticsLabel: suffix == null ? spoken : '$spoken $suffix',
    );
  }
}

/// 🏆 personal record — always the carbs gold (`record`), on the list, in
/// the log and in the celebration alike.
class RecordChip extends StatelessWidget {
  const RecordChip({super.key, required this.label, this.semanticsLabel});

  final String label;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => TintedChip(
        label: label,
        color: context.metricColors.record,
        icon: Icons.emoji_events_rounded,
        semanticsLabel: semanticsLabel,
      );
}

/// ↑ better than last time — always the protein green (`improvement`).
class ImprovementChip extends StatelessWidget {
  const ImprovementChip({super.key, required this.label, this.semanticsLabel});

  final String label;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) => TintedChip(
        label: label,
        color: context.metricColors.improvement,
        icon: Icons.arrow_upward_rounded,
        semanticsLabel: semanticsLabel,
      );
}
