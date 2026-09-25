import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/format/cardio_formatter.dart';
import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/app_type.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/ds/list_group.dart';
import '../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../../shared/widgets/sync_status_indicator.dart';
import '../../../settings/domain/user_settings.dart';
import '../../domain/activity_type.dart';
import '../../domain/workout_session.dart';
import 'route_painter.dart';

/// How a row dates its session: not at all (it sits under "Today"), by weekday
/// and time ("Wed 17:30", this and last week) or by date and time
/// ("Sep 8 · 18:00", older weeks).
enum SessionRowDate { none, weekday, date }

/// One workout in the Sessions list — strength and cardio share the anatomy
/// (docs/redesign/77-mobile-redesign-plan.md R3.3; canvas Lifey 3 › 3.1): an
/// icon holder, the title with the record chip, a metrics line
/// ("58 min · 11 sets · 4 280 kg" / "Tue 07:45 · 5.21 km · 5:19 /km · 156
/// bpm"), and a details line (the exercises, or where the heart rate came
/// from). Every line wraps instead of being cut, and the metrics wrap only at
/// the dots.
class SessionRow extends StatelessWidget {
  const SessionRow({
    super.key,
    required this.session,
    required this.unitSystem,
    required this.prCount,
    required this.date,
    required this.onTap,
    required this.onLongPress,
  });

  final WorkoutSession session;
  final UnitSystem unitSystem;
  final int prCount;
  final SessionRowDate date;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const _nbsp = ' ';

  /// "Health Connect" on Android, "Apple Health" on iOS — the platform's own
  /// names, so they are not translated.
  static String get _healthSource {
    if (kIsWeb) return 'Health Connect';
    return Platform.isIOS ? 'Apple Health' : 'Health Connect';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);
    final p = context.palette;
    final mc = context.metricColors;
    final t = Theme.of(context).textTheme;
    final primary = Theme.of(context).colorScheme.primary;

    final started = session.startedAt!.toLocal();
    final isCardio = session.isCardio;
    final title = isCardio
        ? activityTypeLabel(l10n, session.activityType!)
        : (session.templateName?.trim().isNotEmpty ?? false)
            ? session.templateName!.trim()
            : l10n.activityTypeStrength;

    final leading = isCardio
        ? ListIconHolder(
            icon: activityTypeIcon(session.activityType!),
            color: activityTypeColor(session.activityType!, context),
          )
        : ListIconHolder(icon: Icons.fitness_center_rounded, color: primary);

    // ── metrics ─────────────────────────────────────────────────────────────
    final parts = <List<InlineSpan>>[];
    void add(String text, {Color? color}) {
      parts.add([TextSpan(text: text.replaceAll(' ', _nbsp), style: color == null ? null : TextStyle(color: color))]);
    }

    switch (date) {
      case SessionRowDate.none:
        break;
      case SessionRowDate.weekday:
        add(f.weekdayTime(started));
      case SessionRowDate.date:
        add('${f.shortDate(started)} ${f.time(started)}');
    }

    if (session.inProgress) {
      // The status is the whole story of a running session.
    } else if (isCardio) {
      final meters = session.cardio?.distanceMeters;
      final duration = session.effectiveDuration;
      final imperial = unitSystem == UnitSystem.imperial;
      if (session.family == ActivityFamily.distance && meters != null && meters > 0) {
        add('${f.decimal(imperial ? meters / 1609.344 : meters / 1000, 2)} ${imperial ? 'mi' : 'km'}');
        if (duration != null) {
          final activity = session.activityType;
          if (activity == 'RUNNING') {
            final pace = CardioFormatter.pace(meters, duration, unitSystem);
            if (pace != null) add(pace);
          } else if (activity == 'CYCLING') {
            final speed = CardioFormatter.speed(meters, duration, unitSystem);
            if (speed != null) add(speed);
          }
        }
      } else if (duration != null) {
        add(CardioFormatter.duration(duration));
      }
      final hr = session.averageHeartRate;
      if (hr != null) add('${f.integer(hr)} bpm', color: mc.heart);
    } else {
      final duration = session.effectiveDuration;
      if (duration != null) add('${duration.inMinutes} min');
      if (session.sets.isNotEmpty) add(l10n.setsCountLabel(session.sets.length));
      final volumeKg = session.sets.fold<double>(0, (sum, s) => sum + s.weight * s.reps);
      if (volumeKg > 0) {
        add(unitSystem == UnitSystem.imperial
            ? '${f.integer(volumeKg / 0.45359237)} lb'
            : '${f.integer(volumeKg)} kg');
      }
    }

    final metrics = <InlineSpan>[
      for (final (i, part) in parts.indexed) ...[
        if (i > 0) const TextSpan(text: '$_nbsp·​ '),
        ...part,
      ],
    ];

    // ── details ─────────────────────────────────────────────────────────────
    String? details;
    if (isCardio) {
      if (session.enrichedFromWatch && session.averageHeartRate != null) {
        details = l10n.sessionHeartRateFromSource(_healthSource);
      }
    } else {
      final names = session.sets.map((s) => s.exerciseName).toSet().take(4).join(', ');
      if (names.isNotEmpty) details = names;
    }

    // Trailing route thumbnail of a finished distance session that recorded a
    // GPS trail (C4a.6).
    final polyline = isCardio && session.family == ActivityFamily.distance ? session.cardio?.routePolyline : null;

    final metricStyle = t.bodyMedium!.copyWith(fontSize: 14, height: 1.4, fontWeight: FontWeight.w600, color: p.text);
    final detailStyle = t.bodySmall!.copyWith(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500, color: p.text2);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium!.copyWith(fontSize: 16, height: 1.25, color: p.text),
                        ),
                      ),
                      SyncStatusIndicator(clientId: session.clientId),
                      if (prCount > 0) ...[
                        const SizedBox(width: AppSpacing.s8),
                        TintedChip(
                          label: l10n.sessionPrChip(prCount),
                          color: mc.record,
                          icon: Icons.emoji_events_rounded,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (session.inProgress)
                    Wrap(
                      spacing: AppSpacing.s8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (metrics.isNotEmpty) Text.rich(TextSpan(children: metrics), style: metricStyle),
                        TintedChip(label: l10n.inProgressLabel, color: mc.calories),
                      ],
                    )
                  else if (metrics.isNotEmpty)
                    Text.rich(
                      TextSpan(children: metrics, style: const TextStyle(fontFeatures: AppType.tabular)),
                      style: metricStyle,
                    ),
                  if (details != null) ...[
                    const SizedBox(height: 5),
                    Text(details, maxLines: 2, overflow: TextOverflow.ellipsis, style: detailStyle),
                  ],
                ],
              ),
            ),
            if (polyline != null && polyline.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.s8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.tag),
                child: RouteThumbnail(polyline: polyline),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
