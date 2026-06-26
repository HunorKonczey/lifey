import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

const _kDeleteRed = Color(0xFFD66B5A);
const _kScrim = Color(0x72080906);

/// Styled delete-confirm dialog matching the Lifey Snackbar & Dialog design.
/// Returns `true` only when the user taps the delete button.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    barrierColor: _kScrim,
    builder: (ctx) => _AppDialog(
      icon: Icons.delete_rounded,
      iconColor: _kDeleteRed,
      title: title,
      message: message,
      confirmLabel: l10n.deleteButton,
      cancelLabel: l10n.cancelButton,
      confirmColor: _kDeleteRed,
    ),
  );
  return result ?? false;
}

/// Generic confirm dialog with configurable icon/color/labels.
/// Returns `bool?`: true = confirmed, false = cancelled, null = dismissed.
Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  IconData icon = Icons.help_outline_rounded,
  Color? accentColor,
  bool barrierDismissible = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  final color = accentColor ?? scheme.primary;
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: _kScrim,
    builder: (ctx) => _AppDialog(
      icon: icon,
      iconColor: color,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmColor: color,
    ),
  );
}

// ---------------------------------------------------------------------------
// Internal dialog widget
// ---------------------------------------------------------------------------

class _AppDialog extends StatelessWidget {
  const _AppDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.confirmColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    const dialogBg = Color(0xFF22241B);
    const titleColor = Color(0xFFF1F0E4);
    const subtitleColor = Color(0xFFA8A899);
    const cancelBg = Color(0xFF161611);

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
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 18),
            // Title
            Text(
              title,
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
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
                height: 1.55,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 24),
            // Buttons
            Column(
              children: [
                // Confirm (destructive / accent)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
                const SizedBox(height: 10),
                // Cancel
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: FilledButton.styleFrom(
                      backgroundColor: cancelBg,
                      foregroundColor: titleColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(cancelLabel),
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
