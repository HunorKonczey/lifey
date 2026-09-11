import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/app_snackbar.dart';
import '../../../../chat/data/chat_repository.dart';
import '../../../../workouts/domain/activity_type.dart' show activityTypeLabel;
import '../../application/client_sessions_controller.dart';
import '../../domain/client_workout_session.dart';
import 'session_card.dart';
import 'session_comment_sheet.dart';

/// One session, in full (frame D2), with the trainer's comment on it and the
/// way over to the chat (frame D4).
///
/// Set weights are shown in kilograms, which is what the rest of the app
/// does for strength work — the unit setting only reaches onboarding and
/// cardio distances today, and inventing a conversion here would make the
/// trainer's numbers disagree with the client's own screen.
class SessionDetailSheet extends ConsumerWidget {
  const SessionDetailSheet({
    super.key,
    required this.clientId,
    required this.sessionId,
  });

  final int clientId;
  final int sessionId;

  static Future<void> show(
    BuildContext context, {
    required int clientId,
    required int sessionId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: SessionDetailSheet(clientId: clientId, sessionId: sessionId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    // Read by id, not by value: the comment sheet replaces this row in the
    // controller, and the detail behind it has to show the new text without
    // being reopened.
    final session = ref
        .watch(clientSessionsControllerProvider(clientId))
        .sessions
        .where((s) => s.id == sessionId)
        .firstOrNull;

    if (session == null) return const SizedBox.shrink();

    final title = session.isCardio
        ? activityTypeLabel(l10n, session.activityType ?? 'OTHER_CARDIO')
        : (session.templateName?.isNotEmpty ?? false)
            ? session.templateName!
            : l10n.trainerFreeWorkoutLabel;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          '${DateFormat.yMMMEd(locale).format(session.startedAt.toLocal())}'
          ' · ${summaryLine(l10n, session)}',
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),

        // ── What the client said about it ───────────────────────────────
        if (session.rpe != null || (session.feedbackNote ?? '').isNotEmpty) ...[
          _Block(
            icon: Icons.record_voice_over_outlined,
            title: l10n.trainerClientFeedbackTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (session.rpe != null)
                  Text(
                    l10n.trainerRpeLabel(session.rpe!),
                    style: theme.textTheme.bodyMedium,
                  ),
                if ((session.feedbackNote ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      session.feedbackNote!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // ── What they actually did ──────────────────────────────────────
        if (!session.isCardio) ...[
          for (final exercise in session.performedExercises)
            _ExerciseBlock(
              exercise: exercise,
              sets: session.setsOf(exercise.exerciseId),
            ),
          if (session.performedExercises.isEmpty)
            Text(
              l10n.trainerNoSessionDetailsLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 6),
        ],

        // ── The trainer's half of the loop ──────────────────────────────
        _CommentBlock(clientId: clientId, session: session),
        const SizedBox(height: 12),
        _MessageThemButton(clientId: clientId, session: session),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise with its sets
// ---------------------------------------------------------------------------

class _ExerciseBlock extends StatelessWidget {
  const _ExerciseBlock({required this.exercise, required this.sets});

  final ClientSessionExercise exercise;
  final List<ClientSessionSet> sets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: AppRadius.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            exercise.exerciseName,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (sets.isEmpty)
            Text(
              l10n.trainerNoSetsLoggedLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            for (var i = 0; i < sets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text(
                        '${i + 1}.',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Text(
                      l10n.trainerSetLabel(
                        sets[i].reps ?? 0,
                        (sets[i].weight ?? 0).toStringAsFixed(1),
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trainer comment
// ---------------------------------------------------------------------------

class _CommentBlock extends ConsumerWidget {
  const _CommentBlock({required this.clientId, required this.session});

  final int clientId;
  final ClientWorkoutSession session;

  Future<void> _edit(BuildContext context, AppLocalizations l10n) async {
    final outcome = await SessionCommentSheet.show(
      context,
      clientId: clientId,
      session: session,
    );
    if (outcome == null || !context.mounted) return;

    // Said, not assumed — and the "they were notified" line only where a push
    // actually went out (docs/31 B3: creation, never an edit).
    AppSnackbar.showSuccess(
      context,
      title: switch (outcome) {
        CommentSaveOutcome.created => l10n.trainerCommentSavedNotifiedMessage,
        CommentSaveOutcome.updated => l10n.trainerCommentSavedMessage,
        CommentSaveOutcome.removed => l10n.trainerCommentDeletedMessage,
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();

    return _Block(
      icon: Icons.chat_bubble_outline,
      title: l10n.trainerYourCommentLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (session.hasTrainerComment) ...[
            Text(session.trainerComment!, style: theme.textTheme.bodyMedium),
            if (session.trainerCommentAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat.yMMMd(locale)
                      .add_Hm()
                      .format(session.trainerCommentAt!.toLocal()),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _edit(context, l10n),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.trainerEditCommentTitle),
              ),
            ),
          ] else ...[
            Text(
              l10n.trainerNoCommentYetMessage,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => _edit(context, l10n),
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: Text(l10n.trainerAddCommentTitle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Over to the chat (frame D4)
// ---------------------------------------------------------------------------

class _MessageThemButton extends ConsumerStatefulWidget {
  const _MessageThemButton({required this.clientId, required this.session});

  final int clientId;
  final ClientWorkoutSession session;

  @override
  ConsumerState<_MessageThemButton> createState() => _MessageThemButtonState();
}

class _MessageThemButtonState extends ConsumerState<_MessageThemButton> {
  bool _busy = false;

  Future<void> _open() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    // The session the trainer is looking at, named in the draft — otherwise
    // "about your workout" lands in the client's thread with no idea which.
    final draft = l10n.trainerSessionChatDraft(
      DateFormat.yMMMd(locale).format(widget.session.startedAt.toLocal()),
    );
    try {
      final conversationId = await ref
          .read(chatRepositoryProvider)
          .openConversationWith(widget.clientId);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/chat/$conversationId', extra: draft);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        AppSnackbar.showError(context, title: friendlyError(error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      onPressed: _busy ? null : _open,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.forum_outlined, size: 18),
      label: Text(l10n.trainerMessageThemTooAction),
    );
  }
}

// ---------------------------------------------------------------------------

class _Block extends StatelessWidget {
  const _Block({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
