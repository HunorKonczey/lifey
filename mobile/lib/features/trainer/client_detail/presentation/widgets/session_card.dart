import 'package:flutter/material.dart';

import '../../../../../core/format/lifey_format.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_card.dart';
import '../../../../../shared/widgets/ds/list_group.dart';
import '../../../../../shared/widgets/ds/tinted_chip.dart';
import '../../../../workouts/domain/activity_type.dart' show activityTypeLabel;
import '../../domain/client_workout_session.dart';

/// One finished session in the trainer's list (frame D1).
///
/// Carries three signals beyond the bare facts: how hard the client said it
/// was, whether they wrote anything, and whether this trainer has already
/// answered. The last one is what stops the trainer re-reading the same
/// session every day.
class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.session, this.onTap});

  final ClientWorkoutSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = context.palette;
    final mc = context.metricColors;
    final l10n = AppLocalizations.of(context)!;
    final f = LifeyFormat.of(context);

    return LifeyCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ListIconHolder(
                icon: session.isCardio ? Icons.directions_run_rounded : Icons.fitness_center_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sessionTitle(l10n, session), maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      summaryLine(l10n, session),
                      style: theme.textTheme.bodySmall?.copyWith(color: p.text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                f.shortDate(session.startedAt.toLocal()),
                style: theme.textTheme.labelSmall?.copyWith(color: p.text2),
              ),
            ],
          ),
          if (session.rpe != null || (session.feedbackNote ?? '').isNotEmpty || session.hasTrainerComment) ...[
            const SizedBox(height: AppSpacing.s12),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                if (session.rpe != null)
                  TintedChip(icon: Icons.speed_rounded, label: l10n.trainerRpeShortLabel(session.rpe!), color: mc.heart),
                if ((session.feedbackNote ?? '').isNotEmpty)
                  TintedChip(icon: Icons.sticky_note_2_outlined, label: l10n.trainerClientNoteLabel, color: p.text2),
                // The trainer's own words: the one chip in the primary colour,
                // so "already answered" reads at a glance down the list.
                if (session.hasTrainerComment)
                  TintedChip(
                    icon: Icons.chat_bubble_rounded,
                    label: l10n.trainerYourCommentLabel,
                    color: theme.colorScheme.primary,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// What a session is called on a card and in its sheet: the activity for
/// cardio, the template for strength, "Free workout" when there is none.
String sessionTitle(AppLocalizations l10n, ClientWorkoutSession session) => session.isCardio
    ? activityTypeLabel(l10n, session.activityType ?? 'OTHER_CARDIO')
    : (session.templateName?.isNotEmpty ?? false)
        ? session.templateName!
        : l10n.trainerFreeWorkoutLabel;

String summaryLine(AppLocalizations l10n, ClientWorkoutSession session) {
  final parts = <String>[];
  if (session.isCardio) {
    final distance = session.distanceMeters;
    if (distance != null && distance > 0) {
      parts.add(l10n.trainerKmValue((distance / 1000).toStringAsFixed(2)));
    }
    final movingSeconds = session.movingSeconds;
    if (movingSeconds != null && movingSeconds > 0) {
      parts.add(formatSessionDuration(l10n, Duration(seconds: movingSeconds)));
    }
  } else {
    parts.add(l10n.trainerExerciseCountLabel(session.exerciseCount));
    if (session.sets.isNotEmpty) {
      parts.add(l10n.trainerSetCountLabel(session.sets.length));
    }
  }
  final duration = session.duration;
  if (duration != null && duration.inMinutes > 0 && !session.isCardio) {
    parts.add(formatSessionDuration(l10n, duration));
  }
  return parts.isEmpty ? l10n.trainerNoSessionDetailsLabel : parts.join(' · ');
}

/// "52 min", or "1 h 12 min" once it passes the hour.
String formatSessionDuration(AppLocalizations l10n, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return l10n.trainerDurationMinutesLabel(duration.inMinutes);
  return l10n.trainerDurationHoursMinutesLabel(hours, minutes);
}
