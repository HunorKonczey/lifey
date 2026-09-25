import 'package:flutter/material.dart';

import '../../../../core/format/lifey_format.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Confirmation dialog shown before duplicating a meal. Lets the user pick
/// the date/time the copy should be logged at (defaults to now). Returns the
/// chosen [DateTime], or null if the user cancelled.
///
/// Built like the other v2 dialogs (`LogoutDialog`): the theme's dialog
/// surface, a 48 px tinted icon holder, the dialog text styles and a Cancel /
/// action button pair that stacks at large text sizes
/// (docs/redesign/77-mobile-redesign-plan.md R2.3).
Future<DateTime?> showDuplicateMealDialog(BuildContext context) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => const _DuplicateMealDialog(),
  );
}

class _DuplicateMealDialog extends StatefulWidget {
  const _DuplicateMealDialog();

  @override
  State<_DuplicateMealDialog> createState() => _DuplicateMealDialogState();
}

class _DuplicateMealDialogState extends State<_DuplicateMealDialog> {
  static const double _stackAboveTextScale = 1.15;

  DateTime _dateTime = DateTime.now();

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 2),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (!mounted) return;
    setState(() {
      _dateTime = DateTime(
        date.year, date.month, date.day,
        time?.hour ?? _dateTime.hour,
        time?.minute ?? _dateTime.minute,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final p = context.palette;
    final f = LifeyFormat.of(context);
    final primary = theme.colorScheme.primary;
    final stack = MediaQuery.textScalerOf(context).scale(1) > _stackAboveTextScale;

    final cancel = OutlinedButton(
      onPressed: () => Navigator.of(context).pop(),
      child: Text(l10n.cancelButton),
    );
    final confirm = FilledButton(
      onPressed: () => Navigator.of(context).pop(_dateTime),
      child: Text(l10n.duplicateMenuItem),
    );

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: AppSpacing.s24),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(Icons.content_copy_rounded, size: 24, color: primary),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(l10n.duplicateMealQuestionTitle, style: theme.dialogTheme.titleTextStyle),
            ),
            const SizedBox(height: 14),
            Text(l10n.duplicateMealConfirmMessage, style: theme.dialogTheme.contentTextStyle),
            const SizedBox(height: AppSpacing.s16),
            // Date/time tile — the same row as the meal editor's.
            Material(
              color: p.nested,
              borderRadius: BorderRadius.circular(AppRadius.control),
              child: InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(AppRadius.control),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 20, color: p.text2),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Text(
                            '${f.shortDayLabel(_dateTime)} · ${f.time(_dateTime)}',
                            style: theme.textTheme.titleMedium!.copyWith(fontSize: 15, color: p.text),
                          ),
                        ),
                        Icon(Icons.expand_more_rounded, size: 22, color: p.text2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (stack) ...[
              confirm,
              const SizedBox(height: 10),
              cancel,
            ] else
              Row(
                children: [
                  Expanded(child: cancel),
                  const SizedBox(width: 10),
                  Expanded(child: confirm),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
