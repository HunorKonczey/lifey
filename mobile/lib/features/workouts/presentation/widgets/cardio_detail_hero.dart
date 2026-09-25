import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import 'cardio_live_cards.dart';

/// The head of a finished distance session (canvas Lifey 3 › 3.3): the
/// distance as a 52 px hero on the left, the duration on the right — "5.21 km"
/// and "27:40 / duration". Tapping the distance edits it; a hand-entered one
/// carries an "Edited" tag.
class CardioDetailHero extends StatelessWidget {
  const CardioDetailHero({
    super.key,
    required this.distance,
    required this.duration,
    required this.durationLabel,
    this.edited = false,
    this.editedLabel,
    this.onEditDistance,
  });

  /// "5.21 km" — the unit after the last space; "—" when there is none.
  final String distance;

  /// "27:40".
  final String duration;

  /// "Duration", drawn under the time (sentence case).
  final String durationLabel;
  final bool edited;
  final String? editedLabel;
  final VoidCallback? onEditDistance;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final space = distance.lastIndexOf(' ');
    final number = space > 0 ? distance.substring(0, space) : distance;
    final unit = space > 0 ? distance.substring(space + 1) : null;
    final noScale = AppType.noScale(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: InkWell(
            onTap: onEditDistance,
            borderRadius: AppRadius.controlAll,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: number,
                          style: AppType.number(52, color: p.text)),
                      if (unit != null)
                        TextSpan(
                            text: ' $unit',
                            style: AppType.unit(52, color: p.text2)
                                .copyWith(fontSize: 22)),
                    ]),
                    maxLines: 1,
                    textScaler: noScale,
                  ),
                ),
                if (edited && editedLabel != null) ...[
                  const SizedBox(height: AppSpacing.s8),
                  TintedChip(
                      label: editedLabel!,
                      color: p.text2,
                      icon: Icons.edit_rounded),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(duration,
                style: AppType.number(28, color: p.text), textScaler: noScale),
            const SizedBox(height: AppSpacing.s4),
            Text(
              durationLabel,
              style: t.bodyMedium!.copyWith(
                  fontSize: 15, fontWeight: FontWeight.w500, color: p.text2),
            ),
          ],
        ),
      ],
    );
  }
}

/// One cell of [CardioMetricStrip].
class CardioStripMetric {
  const CardioStripMetric(
      {required this.label, required this.value, this.color});

  final String label;

  /// With its unit after the last space — "5:19 /km", "156 bpm".
  final String value;

  /// Tints the number ("156 bpm" in the heart colour, "323 kcal" in the
  /// calories colour); null is the primary text colour.
  final Color? color;
}

/// The row of secondary numbers under the hero — pace, elevation, average heart
/// rate, calories — in one card with the same label style under every number
/// (canvas Lifey 3 › 3.3: "uniform labels"). Four across on a wide phone, two
/// by two on a narrow one or at a large text size, so a number is never
/// squeezed to a smudge.
class CardioMetricStrip extends StatelessWidget {
  const CardioMetricStrip({super.key, required this.metrics});

  final List<CardioStripMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LifeyCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final perRow = metrics.length <= 3 ||
                  (constraints.maxWidth >= 340 && scale <= 1.15)
              ? metrics.length.clamp(1, 4)
              : 2;
          final rows = <Widget>[];
          for (var i = 0; i < metrics.length; i += perRow) {
            final chunk = metrics.skip(i).take(perRow).toList();
            rows.add(IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < perRow; c++)
                    Expanded(
                        child: c < chunk.length
                            ? _Cell(metric: chunk[c])
                            : const SizedBox.shrink()),
                ],
              ),
            ));
            if (i + perRow < metrics.length) {
              rows.add(const SizedBox(height: AppSpacing.s16));
            }
          }
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.metric});

  final CardioStripMetric metric;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final space = metric.value.lastIndexOf(' ');
    final number = space > 0 ? metric.value.substring(0, space) : metric.value;
    final unit = space > 0 ? metric.value.substring(space + 1) : null;
    final color = metric.color ?? p.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // A fixed-height slot, so a number that had to shrink to fit doesn't
        // lift its label out of line with the neighbours'.
        SizedBox(
          height: 28,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: number, style: AppType.number(24, color: color)),
                if (unit != null)
                  TextSpan(
                      text: ' $unit',
                      style: AppType.unit(24, color: color)
                          .copyWith(fontSize: 14)),
              ]),
              maxLines: 1,
              textScaler: AppType.noScale(context),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          labelCase(context, metric.label),
          style: t.bodyMedium!.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.2,
              color: p.text2),
        ),
      ],
    );
  }
}
