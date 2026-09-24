import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/app_type.dart';

// The snackbar is an *inverse* surface: the v2 dark palette in both themes
// (as Material's inverse snackbar), so it reads as a transient layer above
// light content too. Tones are the dark metric set — success is the
// `positive` green (not brand olive, which is for controls), error the heart
// red, info the water blue (docs/redesign/77-mobile-redesign-plan.md R0.8).
const _p = AppPalette.dark;
const _m = AppMetricColors.dark;
final _kGreen = _m.positive;
final _kRed = _m.heart;
final _kBlue = _m.water;

/// Styled snackbar helper matching the Lifey Snackbar & Dialog design.
///
/// Usage:
///   AppSnackbar.showSuccess(context, title: 'Template deleted');
///   AppSnackbar.showError(context, title: 'Could not save');
///   AppSnackbar.showInfo(context, title: 'Reminder set');
abstract final class AppSnackbar {
  static void showSuccess(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      title: title,
      subtitle: subtitle,
      icon: Icons.check_circle_rounded,
      iconColor: _kGreen,
      borderColor: _kGreen.withValues(alpha: 0.18),
      actionLabel: actionLabel,
      actionColor: _kGreen,
      actionBg: _kGreen.withValues(alpha: 0.12),
      onAction: onAction,
    );
  }

  static void showError(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      title: title,
      subtitle: subtitle,
      icon: Icons.error_rounded,
      iconColor: _kRed,
      borderColor: _kRed.withValues(alpha: 0.22),
      actionLabel: actionLabel,
      actionColor: _kRed,
      actionBg: _kRed.withValues(alpha: 0.12),
      onAction: onAction,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      title: title,
      subtitle: subtitle,
      icon: Icons.info_rounded,
      iconColor: _kBlue,
      borderColor: _kBlue.withValues(alpha: 0.20),
      actionLabel: actionLabel,
      actionColor: _kBlue,
      actionBg: _kBlue.withValues(alpha: 0.12),
      onAction: onAction,
    );
  }

  static void _show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    String? actionLabel,
    Color? actionColor,
    Color? actionBg,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: EdgeInsets.zero,
        duration: const Duration(seconds: 4),
        content: _SnackbarContent(
          title: title,
          subtitle: subtitle,
          icon: icon,
          iconColor: iconColor,
          borderColor: borderColor,
          actionLabel: actionLabel,
          actionColor: actionColor,
          actionBg: actionBg,
          onAction: onAction,
          onDismiss: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Internal content widget
// ---------------------------------------------------------------------------

class _SnackbarContent extends StatelessWidget {
  const _SnackbarContent({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    this.actionLabel,
    this.actionColor,
    this.actionBg,
    this.onAction,
    required this.onDismiss,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final String? actionLabel;
  final Color? actionColor;
  final Color? actionBg;
  final VoidCallback? onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _p.control,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: borderColor),
        boxShadow: context.elevation.e3,
      ),
      // Tight vertical padding: the trailing action / close button carries
      // its own 48 dp touch target.
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, 6, 6, 6),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.nested(AppRadius.card, 12)),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.s12),
            // Text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppType.fontFamily,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: _p.text,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontFamily: AppType.fontFamily,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: _p.text2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            // Action button or close icon — both 48 dp targets.
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: actionColor,
                  backgroundColor: actionBg,
                  minimumSize: const Size(48, 36),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
                  textStyle: const TextStyle(fontFamily: AppType.fontFamily, fontSize: 13.5, fontWeight: FontWeight.w800),
                ),
                child: Text(actionLabel!),
              )
            else
              IconButton(
                onPressed: onDismiss,
                icon: Icon(Icons.close_rounded, size: 20, color: _p.text2),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              ),
          ],
        ),
      ),
    );
  }
}
