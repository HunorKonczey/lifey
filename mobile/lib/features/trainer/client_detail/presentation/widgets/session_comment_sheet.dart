import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/client_sessions_controller.dart';
import '../../domain/client_workout_session.dart';

/// The trainer's comment on one session — the first thing this surface ever
/// writes (frame D3).
///
/// Three rules, all from the plan: **no optimistic UI** (the sheet stays open
/// and disabled until the server answers, then reports what happened), the
/// result is stated rather than assumed, and a *new* comment says out loud
/// that the client's phone was rung — because it was, and the trainer should
/// know that before they write again to fix a typo (docs/31 B3: push fires on
/// creation only).
class SessionCommentSheet extends ConsumerStatefulWidget {
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
    return showModalBottomSheet<CommentSaveOutcome>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SessionCommentSheet(clientId: clientId, session: session),
    );
  }

  @override
  ConsumerState<SessionCommentSheet> createState() => _SessionCommentSheetState();
}

/// The backend caps the comment at 2000 characters (`SessionCommentRequest`).
/// Enforced here too so the limit is visible while typing rather than
/// arriving as a validation error after a round trip.
const _commentMaxLength = 2000;

class _SessionCommentSheetState extends ConsumerState<SessionCommentSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.session.trainerComment ?? '');

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run(Future<CommentSaveOutcome> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await action();
      if (mounted) Navigator.of(context).pop(outcome);
    } catch (error) {
      // The sheet stays open with the text intact: a failed save must not
      // look like a successful one, and must not cost the trainer their
      // words either.
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(error);
        });
      }
    }
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _run(() => ref
        .read(clientSessionsControllerProvider(widget.clientId).notifier)
        .saveComment(widget.session.id, text));
  }

  void _delete() {
    _run(() => ref
        .read(clientSessionsControllerProvider(widget.clientId).notifier)
        .deleteComment(widget.session.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final hasExisting = widget.session.hasTrainerComment;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            hasExisting
                ? l10n.trainerEditCommentTitle
                : l10n.trainerAddCommentTitle,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.trainerCommentSheetSubtitle,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            enabled: !_busy,
            autofocus: !hasExisting,
            maxLines: 5,
            minLines: 3,
            maxLength: _commentMaxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.trainerCommentHint,
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (hasExisting)
                TextButton.icon(
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(l10n.deleteButton),
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                ),
              const Spacer(),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(l10n.saveButton),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
