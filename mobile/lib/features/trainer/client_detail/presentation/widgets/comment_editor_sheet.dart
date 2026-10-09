import 'package:flutter/material.dart';

import '../../../../../core/network/error_message.dart';
import '../../../../../core/theme/app_tokens.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/client_sessions_controller.dart' show CommentSaveOutcome;

/// The backend caps a trainer comment at 2000 characters (`SessionCommentRequest`, shared by the session and the meal
/// comment). Enforced here too so the limit is visible while typing rather than arriving as a validation error after a
/// round trip.
const trainerCommentMaxLength = 2000;

/// What goes inside the sheet where a trainer writes a comment — on a session or on a meal; the frame (title, handle,
/// keyboard inset) comes from `showLifeySheet`.
///
/// Three rules, all from the plan: **no optimistic UI** (the sheet stays open and disabled until the server answers,
/// then reports what happened), the result is stated rather than assumed, and a *new* comment says out loud that the
/// client's phone was rung (docs/31 B3: push fires on creation only).
class CommentEditorSheet extends StatefulWidget {
  const CommentEditorSheet({
    super.key,
    required this.initialComment,
    required this.subtitle,
    required this.hint,
    required this.onSave,
    required this.onDelete,
  });

  /// The comment as it stands, or null when there is none yet (the delete button then stays away).
  final String? initialComment;
  final String subtitle;
  final String hint;
  final Future<CommentSaveOutcome> Function(String text) onSave;
  final Future<CommentSaveOutcome> Function() onDelete;

  @override
  State<CommentEditorSheet> createState() => _CommentEditorSheetState();
}

class _CommentEditorSheetState extends State<CommentEditorSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialComment ?? '');

  bool _busy = false;
  String? _error;

  bool get _hasExisting => widget.initialComment != null && widget.initialComment!.trim().isNotEmpty;

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
      // The sheet stays open with the text intact: a failed save must not look like a successful one, and must not
      // cost the trainer their words either.
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
    _run(() => widget.onSave(text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.subtitle, style: theme.textTheme.bodySmall?.copyWith(color: context.palette.text2)),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          enabled: !_busy,
          autofocus: !_hasExisting,
          maxLines: 5,
          minLines: 3,
          maxLength: trainerCommentMaxLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: widget.hint, errorText: _error),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (_hasExisting)
              TextButton.icon(
                onPressed: _busy ? null : () => _run(widget.onDelete),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(l10n.deleteButton),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
              ),
            const Spacer(),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.saveButton)),
          ],
        ),
      ],
    );
  }
}
