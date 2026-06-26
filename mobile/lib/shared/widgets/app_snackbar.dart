import 'package:flutter/material.dart';

// Design tokens from Lifey Snackbar & Dialog.dc.html
const _kGreen = Color(0xFF9DAE6B);
const _kRed = Color(0xFFD66B5A);
const _kBlue = Color(0xFF6FA8C4);
const _kBg = Color(0xFF2A2C20);
const _kTitle = Color(0xFFF1F0E4);
const _kSubtitle = Color(0xFFA8A899);
const _kIconDim = Color(0xFF777264);

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
        color: _kBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 21, color: iconColor),
          ),
          const SizedBox(width: 12),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kTitle,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _kSubtitle,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action button or close icon
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: actionBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: actionColor,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, size: 20, color: _kIconDim),
            ),
        ],
      ),
    );
  }
}
