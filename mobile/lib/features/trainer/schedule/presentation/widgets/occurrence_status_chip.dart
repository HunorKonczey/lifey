import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/tinted_chip.dart';
import '../../domain/schedule.dart';

/// The status of one occurrence, in the colour language the rest of the
/// trainer view already uses (frame F1: "a meglévő státusz-nyelv, változatlanul").
///
/// Colour carries the status and nothing else — there is deliberately no
/// per-client colour coding on the calendar, because with a dozen clients
/// that becomes a legend nobody memorises. The client is named by their
/// monogram instead.
class OccurrenceStatusChip extends StatelessWidget {
  const OccurrenceStatusChip({super.key, required this.status});

  final OccurrenceStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (status) {
      OccurrenceStatus.upcoming => l10n.trainerOccurrenceUpcomingLabel,
      OccurrenceStatus.done => l10n.trainerOccurrenceDoneLabel,
      OccurrenceStatus.missed => l10n.trainerOccurrenceMissedLabel,
      OccurrenceStatus.cancelled => l10n.trainerOccurrenceCancelledLabel,
    };
    return TintedChip(label: label, color: occurrenceStatusColor(context, status));
  }
}

/// The colour of a status — the chip's tint and the dot that marks a day
/// carrying occurrences in the week strip and the month overview. Upcoming is
/// the primary colour, done the improvement green, missed the warning orange
/// (the same one the client card's "Missed 2 sessions" uses) and cancelled a
/// neutral grey.
Color occurrenceStatusColor(BuildContext context, OccurrenceStatus status) {
  final mc = context.metricColors;
  return switch (status) {
    OccurrenceStatus.upcoming => Theme.of(context).colorScheme.primary,
    OccurrenceStatus.done => mc.improvement,
    OccurrenceStatus.missed => mc.calories,
    OccurrenceStatus.cancelled => context.palette.text3,
  };
}
