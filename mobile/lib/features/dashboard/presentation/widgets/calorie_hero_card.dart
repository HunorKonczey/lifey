import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/animated_number.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/metric_bar.dart';
import '../../../../shared/widgets/ds/metric_value.dart';
import '../../../../shared/widgets/ds/progress_ring.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../settings/domain/user_settings.dart';
import '../../domain/daily_stats.dart';

/// The one hero of the Today screen: what is left of today's calories, and
/// how the three macros are doing (docs/redesign/77-mobile-redesign-plan.md
/// R1.3; canvas Lifey 1 "Egy hős kártya öt egyforma helyett").
///
/// Left: a 144 px ring in the calorie colour with the **remaining** kcal as
/// its number — the figure the "what can I still eat" decision needs — and
/// "Eaten · Goal" as the smaller line under it. Right: three macro rows
/// (label, `value / goal g`, a 7 px bar), with a protein-coloured "100 g to
/// go" chip under the protein bar. Past the goal the ring closes and runs a
/// second lap, and the number becomes the overage ("212 kcal over").
///
/// Without a calorie goal there is nothing to be left of: the ring stays
/// empty, the number is what was eaten, and the "Eaten · Goal" line is
/// dropped. Macros without a goal show just their value, without a bar.
///
/// Every animation comes from the ds primitives, so after logging a meal
/// only the difference animates (count-up, ring and bars), never from 0.
class CalorieHeroCard extends StatelessWidget {
  const CalorieHeroCard({
    super.key,
    required this.stats,
    required this.settings,
    this.onTap,
  });

  final DailyStats stats;
  final UserSettings settings;
  final VoidCallback? onTap;

  /// The ring's own size — the canvas' 144.
  static const double ringSize = 144;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final mc = context.metricColors;

    final goal = settings.dailyCalorieGoal;
    final hasGoal = goal != null && goal > 0;
    final eaten = stats.calories;
    final over = hasGoal && eaten > goal;

    // The big number: what is left, the overage, or (no goal) what was eaten.
    final double bigNumber = hasGoal ? (goal - eaten).abs() : eaten;
    final caption = !hasGoal
        ? l10n.dashboardHeroKcalEaten
        : over
            ? l10n.dashboardHeroKcalOver
            : l10n.dashboardHeroKcalLeft;
    String semantics(String value) => !hasGoal
        ? l10n.dashboardHeroKcalEatenSemantics(value)
        : over
            ? l10n.dashboardHeroKcalOverSemantics(value)
            : l10n.dashboardHeroKcalLeftSemantics(value);

    final macros = <_Macro>[
      _Macro(l10n.proteinLabel, stats.protein, settings.dailyProteinGoal, mc.protein, toGoChip: true),
      _Macro(l10n.carbsLabel, stats.carbs, settings.dailyCarbsGoal, mc.carbs),
      _Macro(l10n.fatLabel, stats.fat, settings.dailyFatGoal, mc.fat),
    ];

    return LifeyCard.hero(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Ring(
            progress: hasGoal ? eaten / goal : 0,
            number: bigNumber,
            caption: caption,
            captionColor: over ? mc.negative : null,
            semantics: semantics,
            eatenGoal: hasGoal ? (eaten: f.kcal(eaten), goal: f.kcal(goal)) : null,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, macro) in macros.indexed) ...[
                  if (i > 0) const SizedBox(height: 14),
                  _MacroRow(macro: macro, index: i),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.progress,
    required this.number,
    required this.caption,
    required this.captionColor,
    required this.semantics,
    required this.eatenGoal,
  });

  final double progress;
  final double number;
  final String caption;
  final Color? captionColor;
  final String Function(String value) semantics;
  final ({String eaten, String goal})? eatenGoal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final l10n = AppLocalizations.of(context)!;
    final mc = context.metricColors;

    final captionStyle = Theme.of(context).textTheme.labelSmall!.copyWith(
          fontWeight: FontWeight.w600,
          height: 1.2,
          color: captionColor ?? p.text2,
        );

    return SizedBox(
      width: CalorieHeroCard.ringSize,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProgressRing(
            progress: progress,
            color: mc.calories,
            size: CalorieHeroCard.ringSize,
            child: Padding(
              // Keeps the number clear of the stroke.
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedNumber(
                      value: number,
                      semanticsLabel: semantics(f.kcal(number)),
                      builder: (context, v) => MetricValue(value: f.kcal(v), size: 34),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      caption,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: captionStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (eatenGoal != null) ...[
            const SizedBox(height: 10),
            Text.rich(
              _boldNumbers(
                l10n.dashboardHeroEatenGoal(_eatenMark, _goalMark),
                eatenGoal!,
                bold: captionStyle.copyWith(color: p.text, fontWeight: FontWeight.w700),
              ),
              textAlign: TextAlign.center,
              style: captionStyle.copyWith(height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  // Placeholders for the two numbers: the ARB string is rendered with these
  // markers first and then split, so translators keep one sentence with real
  // placeholders while the numbers can be set in bold.
  static const _eatenMark = '\u0001';
  static const _goalMark = '\u0002';

  static TextSpan _boldNumbers(
    String template,
    ({String eaten, String goal}) numbers, {
    required TextStyle bold,
  }) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }

    for (final rune in template.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == _eatenMark || ch == _goalMark) {
        flush();
        spans.add(TextSpan(text: ch == _eatenMark ? numbers.eaten : numbers.goal, style: bold));
      } else {
        buffer.write(ch);
      }
    }
    flush();
    return TextSpan(children: spans);
  }
}

class _Macro {
  const _Macro(this.label, this.value, this.goal, this.color, {this.toGoChip = false});

  final String label;
  final double value;
  final int? goal;
  final Color color;

  /// Show the "N g to go" chip under the bar while the goal is not reached.
  final bool toGoChip;

  bool get hasGoal => goal != null && goal! > 0;
}

/// Label on the left, `29 / 129 g` on the right, a 7 px bar under it. The
/// canvas' Hungarian rule: when "Szénhidrát" and "88 / 313 g" no longer fit
/// side by side (dynamic type), the value drops under the label instead of
/// truncating — a [Wrap] does exactly that.
class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.macro, required this.index});

  final _Macro macro;
  final int index;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final l10n = AppLocalizations.of(context)!;
    final t = Theme.of(context).textTheme;

    final value = f.grams(macro.value);
    final left = macro.hasGoal ? macro.goal! - macro.value : 0.0;
    final showChip = macro.toGoChip && macro.hasGoal && left > 0 && f.grams(left) != '0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 6,
          runSpacing: 2,
          children: [
            Text(
              macro.label,
              style: t.bodySmall!.copyWith(fontWeight: FontWeight.w600, height: 1.2, color: p.text2),
            ),
            Text.rich(
              TextSpan(
                text: value,
                style: t.titleSmall!.copyWith(
                    fontWeight: FontWeight.w800, height: 1, color: p.text, fontFeatures: AppType.tabular),
                children: [
                  TextSpan(
                    text: macro.hasGoal ? ' / ${f.grams(macro.goal!)} g' : ' g',
                    style: t.labelSmall!.copyWith(fontWeight: FontWeight.w600, height: 1, color: p.text2),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (macro.hasGoal) ...[
          const SizedBox(height: 6),
          MetricBar(
            progress: macro.value / macro.goal!,
            color: macro.color,
            delay: AppMotion.staggered(index),
          ),
        ],
        if (showChip) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TintedChip(
              label: l10n.dashboardHeroProteinToGo(f.grams(left)),
              color: macro.color,
            ),
          ),
        ],
      ],
    );
  }
}
