import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/format/cardio_formatter.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/activity_chip.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/domain/user_settings.dart';
import '../domain/activity_type.dart';
import '../domain/workout_session.dart';

/// One (label, value) tile for the secondary-metrics section.
typedef _MetricEntry = (String label, String value);

/// Read-only view of a saved cardio session — manually logged via
/// `LogCardioSheet` (C1.8/C1.9) today; the live C2 flow will land its own
/// editable summary later (M15, C2.8) rather than growing this screen into
/// one, per docs/cardio/59-cardio-implementation-plan.md C1.9's kész-ha:
/// "a mentett edzés megnyitható és olvasható" — openable and readable, no
/// editing.
class CardioSummaryScreen extends ConsumerWidget {
  const CardioSummaryScreen({super.key, required this.session});

  final WorkoutSession session;

  static final _dateLabel = DateFormat('EEE, MMM d · HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unitSystem =
        (ref.watch(settingsControllerProvider).value ?? const UserSettings.defaults())
            .unitSystem;

    final activityType = session.activityType!;
    final family = session.family!;
    final cardio = session.cardio;
    final duration = session.effectiveDuration;

    final (primaryLabel, primaryValue) =
        _primaryMetric(l10n, family, cardio, duration, unitSystem);
    final secondary = _secondaryMetrics(l10n, family, cardio, duration, unitSystem);

    return Scaffold(
      appBar: AppBar(title: Text(activityTypeLabel(l10n, activityType))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Row(
            children: [
              ActivityChip(activityType: activityType, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activityTypeLabel(l10n, activityType),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (session.startedAt != null)
                      Text(
                        _dateLabel.format(session.startedAt!.toLocal()),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  primaryValue,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (label, value) in secondary)
                  _MetricTile(label: label, value: value, scheme: scheme, theme: theme),
              ],
            ),
          ],
          if (session.isRated) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.card),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration:
                        BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Text(
                      '${session.rpe}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.postWorkoutFeedbackSectionTitle,
                            style: theme.textTheme.labelLarge),
                        if (session.feedbackNote != null && session.feedbackNote!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              session.feedbackNote!,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static (String, String) _primaryMetric(
    AppLocalizations l10n,
    ActivityFamily family,
    CardioMetrics? cardio,
    Duration? duration,
    UnitSystem unitSystem,
  ) {
    final durationLabel = l10n.durationSectionLabel;
    final durationValue = duration == null ? '—' : CardioFormatter.duration(duration);
    switch (family) {
      case ActivityFamily.distance:
        final meters = cardio?.distanceMeters;
        if (meters != null && meters > 0) {
          return (l10n.distanceFieldLabel, CardioFormatter.distance(meters, unitSystem));
        }
        return (durationLabel, durationValue);
      case ActivityFamily.machine:
        return (l10n.movingTimeLabel, durationValue);
      case ActivityFamily.game:
        return (l10n.playingTimeLabel, durationValue);
    }
  }

  static List<_MetricEntry> _secondaryMetrics(
    AppLocalizations l10n,
    ActivityFamily family,
    CardioMetrics? cardio,
    Duration? duration,
    UnitSystem unitSystem,
  ) {
    final entries = <_MetricEntry>[];
    switch (family) {
      case ActivityFamily.distance:
        final meters = cardio?.distanceMeters;
        // Duration is the primary number only when there's no distance;
        // when distance *is* primary, duration belongs here as a secondary.
        if (meters != null && meters > 0) {
          if (duration != null) {
            entries.add((l10n.durationSectionLabel, CardioFormatter.duration(duration)));
            final pace = CardioFormatter.pace(meters, duration, unitSystem);
            if (pace != null) entries.add((l10n.paceLabel, pace));
          }
        }
        final elevation = cardio?.elevationGainMeters;
        if (elevation != null) {
          entries.add((l10n.elevationGainFieldLabel, CardioFormatter.elevation(elevation, unitSystem)));
        }
      case ActivityFamily.machine:
        final meters = cardio?.distanceMeters;
        if (meters != null && meters > 0) {
          entries.add((l10n.distanceFieldLabel, CardioFormatter.distance(meters, unitSystem)));
        }
        final watts = cardio?.avgWatts;
        if (watts != null) entries.add((l10n.avgWattsFieldLabel, '${watts.round()} W'));
        final cadence = cardio?.avgCadence;
        if (cadence != null) entries.add((l10n.avgCadenceFieldLabel, '${cadence.round()} rpm'));
        final resistance = cardio?.resistanceLevel;
        if (resistance != null) entries.add((l10n.resistanceLevelFieldLabel, '$resistance'));
        final calories = cardio?.deviceCalories;
        if (calories != null) {
          entries.add((l10n.deviceCaloriesFieldLabel, '${calories.round()} kcal'));
        }
      case ActivityFamily.game:
        final venue = cardio?.venue;
        if (venue != null) {
          entries.add((
            l10n.venueSectionLabel,
            venue == 'INDOOR' ? l10n.venueIndoorLabel : l10n.venueOutdoorLabel,
          ));
        }
        final intensity = cardio?.intensity;
        if (intensity != null) entries.add((l10n.intensitySectionLabel, '$intensity/5'));
        final score = cardio?.scorePoints;
        if (score != null) entries.add((l10n.scorePointsFieldLabel, '$score'));
    }
    return entries;
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.scheme,
    required this.theme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
