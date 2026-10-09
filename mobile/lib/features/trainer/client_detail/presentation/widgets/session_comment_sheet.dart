import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/ds/lifey_sheet.dart';
import '../../application/client_sessions_controller.dart';
import '../../domain/client_workout_session.dart';
import 'comment_editor_sheet.dart';

/// The trainer's comment on one session — the first thing this surface ever wrote (frame D3). The editor itself,
/// shared with the meal comment, is [CommentEditorSheet]; this wires it to the session's controller.
class SessionCommentSheet extends ConsumerWidget {
  const SessionCommentSheet({
    super.key,
    required this.clientId,
    required this.session,
  });

  final int clientId;
  final ClientWorkoutSession session;

  /// Returns the outcome once the server has confirmed it, or null if the
  /// trainer backed out.
  static Future<CommentSaveOutcome?> show(
    BuildContext context, {
    required int clientId,
    required ClientWorkoutSession session,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showLifeySheet<CommentSaveOutcome>(
      context: context,
      title: session.hasTrainerComment ? l10n.trainerEditCommentTitle : l10n.trainerAddCommentTitle,
      useRootNavigator: true,
      builder: (_) => SessionCommentSheet(clientId: clientId, session: session),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = clientSessionsControllerProvider(clientId);
    return CommentEditorSheet(
      initialComment: session.trainerComment,
      subtitle: l10n.trainerCommentSheetSubtitle,
      hint: l10n.trainerCommentHint,
      onSave: (text) => ref.read(controller.notifier).saveComment(session.id, text),
      onDelete: () => ref.read(controller.notifier).deleteComment(session.id),
    );
  }
}
