import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
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
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    final title = session.isCardio
        ? activityTypeLabel(l10n, session.activityType ?? 'OTHER_CARDIO')
        : (session.templateName?.isNotEmpty ?? false)
            ? session.templateName!
            : l10n.trainerFreeWorkoutLabel;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: AppRadius.cardAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    session.isCardio ? Icons.directions_run : Icons.fitness_center,
                    size: 18,
                    color: scheme.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat.MMMd(locale).format(session.startedAt.toLocal()),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                summaryLine(l10n, session),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (session.rpe != null ||
                  (session.feedbackNote ?? '').isNotEmpty ||
                  session.hasTrainerComment) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (session.rpe != null)
                      _Chip(
                        icon: Icons.speed,
                        label: l10n.trainerRpeShortLabel(session.rpe!),
                        background: scheme.surfaceContainerHighest,
                        foreground: scheme.onSurfaceVariant,
                      ),
                    if ((session.feedbackNote ?? '').isNotEmpty)
                      _Chip(
                        icon: Icons.sticky_note_2_outlined,
                        label: l10n.trainerClientNoteLabel,
                        background: scheme.surfaceContainerHighest,
                        foreground: scheme.onSurfaceVariant,
                      ),
                    if (session.hasTrainerComment)
                      _Chip(
                        icon: Icons.chat_bubble,
                        label: l10n.trainerYourCommentLabel,
                        background: scheme.tertiaryContainer,
                        foreground: scheme.onTertiaryContainer,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "5 exercises · 18 sets · 52 min", or the cardio equivalent. Public so the
/// detail sheet can head itself with the same line the card carried.
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

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: AppRadius.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: foreground),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
