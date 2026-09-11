import 'package:flutter/material.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final (label, background, foreground) = switch (status) {
      OccurrenceStatus.upcoming => (
          l10n.trainerOccurrenceUpcomingLabel,
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      OccurrenceStatus.done => (
          l10n.trainerOccurrenceDoneLabel,
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      OccurrenceStatus.missed => (
          l10n.trainerOccurrenceMissedLabel,
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      OccurrenceStatus.cancelled => (
          l10n.trainerOccurrenceCancelledLabel,
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.pill),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// The dot that marks a day carrying occurrences, in the week strip and the
/// month overview. Same colour language, minus the words.
Color occurrenceStatusColor(BuildContext context, OccurrenceStatus status) {
  final scheme = Theme.of(context).colorScheme;
  return switch (status) {
    OccurrenceStatus.upcoming => scheme.tertiary,
    OccurrenceStatus.done => scheme.secondary,
    OccurrenceStatus.missed => scheme.error,
    OccurrenceStatus.cancelled => scheme.outlineVariant,
  };
}
