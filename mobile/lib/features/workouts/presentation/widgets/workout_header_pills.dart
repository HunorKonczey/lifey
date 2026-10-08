import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';

/// One round pill of the workout screen's live readouts: an icon with an
/// optional value ("12:34", "142"). Icon-only when there is no [text]; the
/// [tooltip] is still its label for accessibility.
class WorkoutHeaderPill extends StatelessWidget {
  const WorkoutHeaderPill(
      {super.key,
      required this.icon,
      required this.iconColor,
      this.text,
      this.tooltip});

  final IconData icon;
  final Color iconColor;
  final String? text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pill = Container(
      height: 44,
      padding: EdgeInsets.symmetric(horizontal: text == null ? 12 : 14),
      decoration: BoxDecoration(color: p.nested, borderRadius: AppRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: iconColor, semanticLabel: tooltip),
          if (text != null) ...[
            const SizedBox(width: 6),
            Text(
              text!,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.text,
                  fontFeatures: AppType.tabular),
            ),
          ],
        ],
      ),
    );
    return tooltip == null ? pill : Tooltip(message: tooltip!, child: pill);
  }
}

/// What a connected watch reports while it measures — the "measuring" mark, the
/// near-live heart rate and the calories burned (docs/40-watch-app-plan.md
/// §12.4 B14) — as a row under the screen's header.
///
/// These used to sit in the header beside the timer. Four pills there left the
/// title a few dozen dp, which it shrank to fit until it was unreadable, and a
/// three-digit calorie value overflowed the row (LIF-130). Here they have the
/// whole width and wrap onto a second line instead of squeezing anything.
class WorkoutLiveStrip extends StatelessWidget {
  const WorkoutLiveStrip({
    super.key,
    required this.measuringOnWatch,
    this.heartRate,
    this.calories,
    this.measuringLabel,
  });

  final bool measuringOnWatch;
  final int? heartRate;
  final int? calories;

  /// The tooltip / semantics label of the watch mark.
  final String? measuringLabel;

  /// Whether there is anything to show — the caller leaves the strip out
  /// altogether otherwise, so it takes no height.
  bool get hasContent =>
      measuringOnWatch || heartRate != null || calories != null;

  @override
  Widget build(BuildContext context) {
    final mc = context.metricColors;
    // Full width, so the pills sit under the header's timer rather than
    // shrink-wrapping and floating in the middle of a Column.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          if (measuringOnWatch)
            WorkoutHeaderPill(
              icon: Icons.watch_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
              tooltip: measuringLabel,
            ),
          if (heartRate != null)
            WorkoutHeaderPill(
                icon: Icons.favorite_rounded,
                iconColor: mc.heart,
                text: '$heartRate'),
          if (calories != null)
            WorkoutHeaderPill(
                icon: Icons.local_fire_department_rounded,
                iconColor: mc.calories,
                text: '$calories'),
        ],
      ),
    );
  }
}
