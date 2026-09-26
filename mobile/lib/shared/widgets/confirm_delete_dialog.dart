import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../l10n/app_localizations.dart';

/// Delete-confirm dialog on the design system's dialog (the canvas "Log out ·
/// confirm" pattern: heart-tinted icon holder, title, body, Cancel / Delete).
/// Returns `true` only when the user taps the delete button.
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _AppDialog(
      icon: Icons.delete_rounded,
      // The destructive colour is the theme's own (the heart hue), so it reads
      // in light and dark alike.
      iconColor: context.metricColors.heart,
      title: title,
      message: message,
      confirmLabel: l10n.deleteButton,
      cancelLabel: l10n.cancelButton,
      confirmColor: context.metricColors.heart,
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

/// The canvas confirm dialog (Lifey 5, "Log out · confirm"): the dialog theme's
/// surface, 30 px radius and title / body styles, a 48 dp tinted icon holder,
/// and a Cancel / confirm button pair — stacked instead of side by side once the
/// text is large, so a Hungarian label never truncates.
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

  static const double _stackAboveTextScale = 1.15;

  /// Text on the confirm button: the theme's on-primary for the brand colour,
  /// otherwise dark ink on the light-red fill in dark and the card colour in
  /// light — the same rule the log-out dialog uses.
  Color _onAccent(BuildContext context) {
    final theme = Theme.of(context);
    if (confirmColor == theme.colorScheme.primary) return theme.colorScheme.onPrimary;
    return theme.brightness == Brightness.dark
        ? HSLColor.fromColor(confirmColor).withLightness(0.10).toColor()
        : context.palette.card;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stack = MediaQuery.textScalerOf(context).scale(1) > _stackAboveTextScale;

    final cancel = OutlinedButton(
      onPressed: () => Navigator.of(context).pop(false),
      child: Text(cancelLabel),
    );
    final confirm = FilledButton(
      onPressed: () => Navigator.of(context).pop(true),
      style: FilledButton.styleFrom(
        backgroundColor: confirmColor,
        foregroundColor: _onAccent(context),
        textStyle: theme.textTheme.labelLarge!.copyWith(fontWeight: FontWeight.w800),
      ),
      child: Text(confirmLabel),
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
                color: iconColor.withValues(alpha: 0.16),
                borderRadius: AppRadius.controlAll,
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(height: 14),
            Semantics(header: true, child: Text(title, style: theme.dialogTheme.titleTextStyle)),
            const SizedBox(height: 14),
            Text(message, style: theme.dialogTheme.contentTextStyle),
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
