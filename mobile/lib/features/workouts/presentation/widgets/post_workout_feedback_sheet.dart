import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Result of the post-workout feedback sheet: a difficulty rating (1-10,
/// RPE-style) and an optional note. Returned via [Navigator.pop]; a null
/// pop result means the user skipped rating entirely.
typedef PostWorkoutFeedback = ({int rpe, String? feedbackNote});

/// Bottom sheet asking "how hard was this workout?" — a 1-10 chip selector
/// plus an optional note field. Fully skippable (see [PostWorkoutFeedback]).
/// Pass [initialRpe]/[initialNote] to pre-fill when editing a rating that
/// was already saved (see the inline section on the finished-session view).
class PostWorkoutFeedbackSheet extends StatefulWidget {
  const PostWorkoutFeedbackSheet({super.key, this.initialRpe, this.initialNote});

  final int? initialRpe;
  final String? initialNote;

  @override
  State<PostWorkoutFeedbackSheet> createState() => _PostWorkoutFeedbackSheetState();
}

class _PostWorkoutFeedbackSheetState extends State<PostWorkoutFeedbackSheet> {
  late int? _rpe = widget.initialRpe;
  late final _note = TextEditingController(text: widget.initialNote ?? '');

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final rpe = _rpe;
    if (rpe == null) return;
    final note = _note.text.trim();
    Navigator.of(context).pop<PostWorkoutFeedback>((
      rpe: rpe,
      feedbackNote: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.postWorkoutFeedbackTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              for (var value = 1; value <= 10; value++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _RpeChip(
                      value: value,
                      selected: _rpe == value,
                      onTap: () => setState(() => _rpe = value),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.postWorkoutFeedbackAnchorEasy, style: theme.textTheme.bodySmall),
              Text(l10n.postWorkoutFeedbackAnchorMax, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.postWorkoutFeedbackNoteHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop<PostWorkoutFeedback?>(null),
                  child: Text(l10n.postWorkoutFeedbackSkipButton),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _rpe == null ? null : _save,
                  child: Text(l10n.saveButton),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RpeChip extends StatelessWidget {
  const _RpeChip({required this.value, required this.selected, required this.onTap});

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
    final fg = selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(
          '$value',
          style: theme.textTheme.labelLarge?.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Shows [PostWorkoutFeedbackSheet] and returns its result, or null if
/// skipped/dismissed.
Future<PostWorkoutFeedback?> showPostWorkoutFeedbackSheet(
  BuildContext context, {
  int? initialRpe,
  String? initialNote,
}) {
  return showModalBottomSheet<PostWorkoutFeedback>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => PostWorkoutFeedbackSheet(initialRpe: initialRpe, initialNote: initialNote),
  );
}
