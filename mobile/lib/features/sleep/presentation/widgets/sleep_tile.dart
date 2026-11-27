import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/health/health_controller.dart';
import '../../../../core/health/sleep_import_controller.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/metric_bar.dart';
import '../../../../shared/widgets/ds/metric_tile.dart';
import '../../application/sleep_session_controller.dart';
import '../../domain/sleep_session.dart';

/// "7:30 h" — a sleep duration on a tile or a list row.
String sleepDurationValue(Duration duration) {
  final minutes = (duration.inSeconds / 60).round();
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
}

/// The Today screen's sleep tile (docs/integrations/89 G2.5, D-G7): last
/// night's main sleep, the longest session that ended today.
///
/// Three states:
/// - **Stages:** the duration, the bedtime–wake-up line and a stage bar with
///   its legend (deep, light, REM, awake).
/// - **Duration only** (a source without stages): the duration and the
///   bedtime–wake-up line.
/// - **No data:** "—" and a line saying nothing was recorded last night.
///
/// The duration is time in bed, start to end, as the source reported the
/// session.
class SleepTile extends StatelessWidget {
  const SleepTile({super.key, required this.night, this.onTap});

  /// Last night's main sleep, or null when none ended today.
  final SleepSession? night;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final mc = context.metricColors;
    final night = this.night;

    if (night == null) {
      return MetricTile(
        icon: Icons.bedtime_rounded,
        label: l10n.sleepTileLabel,
        value: '—',
        color: mc.sleep,
        subline: l10n.sleepTileNoDataSubline,
        onTap: onTap,
      );
    }

    final range = l10n.sleepTimeRange(f.time(night.startedAt.toLocal()), f.time(night.endedAt.toLocal()));
    return MetricTile(
      icon: Icons.bedtime_rounded,
      label: l10n.sleepTileLabel,
      value: sleepDurationValue(night.duration),
      unit: l10n.durationHoursAbbrev,
      color: mc.sleep,
      subline: range,
      footer: night.hasStages ? SleepStageBar(night: night) : null,
      onTap: onTap,
    );
  }
}

/// A night's stages as one segmented bar with a legend under it: deep, light,
/// REM and awake, in that order.
class SleepStageBar extends StatelessWidget {
  const SleepStageBar({super.key, required this.night});

  final SleepSession night;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final stages = sleepStageColors(context);
    final parts = [
      (label: l10n.sleepStageDeepLabel, minutes: night.deepMinutes ?? 0, color: stages.deep),
      (label: l10n.sleepStageLightLabel, minutes: night.lightMinutes ?? 0, color: stages.light),
      (label: l10n.sleepStageRemLabel, minutes: night.remMinutes ?? 0, color: stages.rem),
      (label: l10n.sleepStageAwakeLabel, minutes: night.awakeMinutes ?? 0, color: stages.awake),
    ];
    final p = context.palette;
    final legendStyle = Theme.of(context).textTheme.bodySmall!.copyWith(color: p.text2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RatioBar(segments: [for (final s in parts) (value: s.minutes.toDouble(), color: s.color)]),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s4,
          children: [
            for (final s in parts)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('${s.label} ${sleepDurationValue(Duration(minutes: s.minutes))}', style: legendStyle),
              ]),
          ],
        ),
      ],
    );
  }
}

/// The four stage colours, all from the sleep hue except REM (the steps
/// violet) and awake (the muted text colour), so the bar reads deep → light
/// at a glance.
({Color deep, Color light, Color rem, Color awake}) sleepStageColors(BuildContext context) {
  final mc = context.metricColors;
  return (
    deep: mc.sleep,
    light: mc.sleep.withValues(alpha: 0.5),
    rem: mc.steps,
    awake: context.palette.text3,
  );
}

/// The sleep tile as the Today screen places it: last night's main sleep
/// from [sleepSessionControllerProvider], with 16 dp under it.
///
/// Hidden for a user who neither imports sleep nor has any: a tile stuck on
/// "nothing recorded" would only be noise. With the import on but no night
/// yet, it shows the no-data state, so the user sees where sleep will land.
class TodaySleepTile extends ConsumerWidget {
  const TodaySleepTile({super.key, this.onTap, this.now});

  final VoidCallback? onTap;

  /// The clock, for "today" — injectable for tests.
  final DateTime Function()? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sleepSessionControllerProvider).value ?? const <SleepSession>[];
    final healthOn = ref.watch(healthControllerProvider).value ?? false;
    final importOn = healthOn && (ref.watch(sleepImportControllerProvider).value?.enabled ?? false);
    if (!importOn && sessions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: SleepTile(night: mainSleepFor(sessions, (now ?? DateTime.now)()), onTap: onTap),
    );
  }
}
