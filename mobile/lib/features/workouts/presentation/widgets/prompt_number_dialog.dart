import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../l10n/app_localizations.dart';

/// A single-field numeric-entry dialog — shared by every manual cardio
/// metric edit, live (`CardioSessionScreen`, C2.2/C2.3) or after finishing
/// (`CardioSummaryScreen`, C2.8). `TextFormField` — not a manually-owned
/// `TextEditingController` — so its own State disposes it; a controller
/// disposed by hand right as `showDialog` resolves can still be attached to
/// the outgoing route's closing transition for a frame, throwing "used
/// after being disposed".
Future<double?> promptNumber(
  BuildContext context,
  AppLocalizations l10n, {
  required String title,
  required String? suffix,
  required String initialText,
}) {
  var enteredText = initialText;
  return showDialog<double>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: enteredText,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
        onChanged: (value) => enteredText = value,
        decoration: InputDecoration(suffixText: suffix, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.cancelButton),
        ),
        FilledButton(
          onPressed: () {
            final parsed = double.tryParse(enteredText.replaceAll(',', '.').trim());
            Navigator.of(dialogContext).pop(parsed);
          },
          child: Text(l10n.saveButton),
        ),
      ],
    ),
  );
}
