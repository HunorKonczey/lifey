import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/app_localizations.dart';

const _kScrim = Color(0x72080906);

/// Confirmation dialog shown before duplicating a meal. Lets the user pick
/// the date/time the copy should be logged at (defaults to now). Returns the
/// chosen [DateTime], or null if the user cancelled.
Future<DateTime?> showDuplicateMealDialog(BuildContext context) {
  return showDialog<DateTime>(
    context: context,
    barrierColor: _kScrim,
    builder: (_) => const _DuplicateMealDialog(),
  );
}

class _DuplicateMealDialog extends StatefulWidget {
  const _DuplicateMealDialog();

  @override
  State<_DuplicateMealDialog> createState() => _DuplicateMealDialogState();
}

class _DuplicateMealDialogState extends State<_DuplicateMealDialog> {
  static final _dateTimeLabel = DateFormat('EEE, MMM d · HH:mm');

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
    const dialogBg = Color(0xFF22241B);
    const titleColor = Color(0xFFF1F0E4);
    const subtitleColor = Color(0xFFA8A899);
    const cancelBg = Color(0xFF161611);
    final accent = Theme.of(context).colorScheme.primary;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon badge
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.copy_rounded, size: 32, color: accent),
            ),
            const SizedBox(height: 18),
            // Title
            Text(
              l10n.duplicateMealQuestionTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: titleColor,
                letterSpacing: -0.3,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 8),
            // Message
            Text(
              l10n.duplicateMealConfirmMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
                height: 1.55,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 18),
            // Date/time picker tile
            GestureDetector(
              onTap: _pickDateTime,
              behavior: HitTestBehavior.opaque,
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.schedule, size: 20, color: accent),
                    const SizedBox(width: 9),
                    Text(
                      _dateTimeLabel.format(_dateTime),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_dateTime),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(l10n.duplicateMenuItem),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: cancelBg,
                      foregroundColor: titleColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(l10n.cancelButton),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
