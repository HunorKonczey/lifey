import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';

/// A metric number with its unit beside it — "1 739 kcal", "64.5 kg".
///
/// Design system v2 rules (docs/redesign/77-mobile-redesign-plan.md D-R0.7,
/// D-R0.8): the number is the hero — display family, tabular figures, and it
/// does not grow with dynamic type; the unit sits on the same baseline at
/// ~42 % of the number's size in the secondary text colour, because it is
/// only an explanation. Takes already formatted strings; formatting is the
/// caller's job.
class MetricValue extends StatelessWidget {
  const MetricValue({
    super.key,
    required this.value,
    this.unit,
    this.size = 34,
    this.color,
    this.unitColor,
    this.semanticsLabel,
  });

  /// The formatted number, e.g. "1 739".
  final String value;

  /// e.g. "kcal"; null draws the number alone.
  final String? unit;

  /// Font size of the number; the unit follows at [AppType.unitScale].
  final double size;

  /// Number colour; defaults to the primary text colour.
  final Color? color;

  /// Unit colour; defaults to the secondary text colour.
  final Color? unitColor;

  /// What a screen reader says instead of the two spans, e.g.
  /// "1739 kilocalories left". Defaults to [value] and [unit] joined by a
  /// space.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Text.rich(
      TextSpan(
        style: AppType.number(size, color: color ?? palette.text),
        children: [
          TextSpan(text: value),
          if (unit != null)
            TextSpan(
              text: ' $unit',
              style: AppType.unit(size, color: unitColor ?? palette.text2),
            ),
        ],
      ),
      textScaler: AppType.noScale(context),
      maxLines: 1,
      softWrap: false,
      semanticsLabel: semanticsLabel ?? (unit == null ? value : '$value $unit'),
    );
  }
}
