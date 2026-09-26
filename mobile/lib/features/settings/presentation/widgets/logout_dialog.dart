import 'package:flutter/material.dart';

import '../../../../core/sync/logout_preflight.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../l10n/app_localizations.dart';

/// Asks before logging out. Resolves `true` only when the user confirms.
///
/// Logout wipes the local database, so the copy says what happens to the
/// changes that have not synced yet: they are uploaded first, or — offline —
/// counted as lost (docs/redesign/77-mobile-redesign-plan.md R1.1, R5.6).
Future<bool> showLogoutDialog(BuildContext context, {LogoutPlan plan = const LogoutPlan(unsynced: 0, online: true)}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => LogoutDialog(plan: plan),
  );
  return confirmed ?? false;
}

/// The canvas "Log out · confirm" dialog (Lifey 5): 30 px radius (the dialog
/// theme), 24 px padding, a 48 px heart-tinted icon holder, a 22/800 title,
/// a 15/500 text-2 body and a Cancel / Log out button pair.
class LogoutDialog extends StatelessWidget {
  const LogoutDialog({super.key, this.plan = const LogoutPlan(unsynced: 0, online: true)});

  /// What the logout will do to unsynced changes; picks the body text.
  final LogoutPlan plan;

  // The two buttons sit side by side like the canvas, but at large text sizes
  // "Kijelentkezés" no longer fits half a dialog, so they stack instead of
  // shrinking or truncating (no ellipsis on labels, D-R0 principle 4).
  static const double _stackAboveTextScale = 1.15;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final palette = context.palette;
    final heart = context.metricColors.heart;
    final dark = theme.brightness == Brightness.dark;
    // Canvas: dark text on the light-red fill (#2A0F0C — the heart hue at
    // 10 % lightness); the light theme's heart is dark enough for white.
    final onHeart = dark
        ? HSLColor.fromColor(heart).withLightness(0.10).toColor()
        : palette.card;
    final stack = MediaQuery.textScalerOf(context).scale(1) > _stackAboveTextScale;

    final cancel = OutlinedButton(
      onPressed: () => Navigator.of(context).pop(false),
      child: Text(l10n.cancelButton),
    );
    final confirm = FilledButton(
      onPressed: () => Navigator.of(context).pop(true),
      style: FilledButton.styleFrom(
        backgroundColor: heart,
        foregroundColor: onHeart,
        textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w800),
      ),
      child: Text(l10n.logOutLabel),
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
                color: heart.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Icon(Icons.logout_rounded, size: 24, color: heart),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(l10n.logOutDialogTitle, style: theme.dialogTheme.titleTextStyle),
            ),
            const SizedBox(height: 14),
            Text(
              plan.willLose
                  ? l10n.logOutDialogMessageLoss(plan.unsynced)
                  : plan.willUpload
                      ? l10n.logOutDialogMessageUpload(plan.unsynced)
                      : l10n.logOutDialogMessage,
              // Losing changes is the one case that is not routine: the body
              // takes the warning colour.
              style: theme.dialogTheme.contentTextStyle?.copyWith(color: plan.willLose ? heart : null),
            ),
            const SizedBox(height: 20),
            if (stack)
              // Stacked, each button takes the dialog's full width.
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [confirm, const SizedBox(height: 10), cancel],
              )
            else
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
