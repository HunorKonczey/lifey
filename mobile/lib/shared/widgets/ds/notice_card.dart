import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'lifey_card.dart';
import 'list_group.dart';

/// A contextual card on a main screen — "Finish your profile", "Your weekly
/// recap is ready", "Up next: Push day", the trainer-Pro-ended notice
/// (design system v2; docs/redesign/77-mobile-redesign-plan.md R1.8: "→
/// LifeyCard with primary / clay accents").
///
/// One card, no border: the accent tints the surface (12 %) and colours the
/// 44 px icon holder and the action; the text stays in the ordinary text
/// colours so it keeps its contrast in both themes. Layout is a row of
/// [icon holder | text column | dismiss]; the [actionLabel] sits under the
/// text (a 48 dp text button) instead of squeezing in beside it, so a
/// Hungarian label at 130 % wraps rather than truncates. Give it an
/// [onTap] for a card that is one big button, a [trailing] widget for
/// something at its end (the recommended workout's play icon), and an
/// [onDismiss] for the close button.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.overline,
    this.accent,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.dismissTooltip,
    this.onTap,
    this.trailing,
  })  : assert((actionLabel == null) == (onAction == null), 'actionLabel and onAction go together'),
        assert(onDismiss == null || dismissTooltip != null, 'an icon-only close needs a tooltip');

  final IconData icon;
  final String title;
  final String? body;

  /// A small sentence-case label above the title ("Recommended workout").
  final String? overline;

  /// Brand olive by default; `context.palette.role` (clay) for anything that
  /// comes from a trainer.
  final Color? accent;

  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final String? dismissTooltip;

  /// Makes the whole card tappable (0.98 press scale, no ripple).
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final tone = accent ?? Theme.of(context).colorScheme.primary;
    final tint = Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.10;

    return LifeyCard(
      color: Color.alphaBlend(tone.withValues(alpha: tint), p.card),
      padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s16, AppSpacing.s8, AppSpacing.s16),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListIconHolder(icon: icon, color: tone),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: AppSpacing.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overline != null) ...[
                    Text(overline!, style: t.labelSmall!.copyWith(fontWeight: FontWeight.w700, color: tone)),
                    const SizedBox(height: 2),
                  ],
                  Text(title, style: t.titleMedium!.copyWith(fontSize: 15, height: 1.3, color: p.text)),
                  if (body != null) ...[
                    const SizedBox(height: 3),
                    Text(body!, style: t.bodySmall!.copyWith(height: 1.4, color: p.text2)),
                  ],
                  if (actionLabel != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: tone,
                          minimumSize: const Size(48, 48),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          textStyle: t.labelLarge!.copyWith(fontSize: 13),
                        ),
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (trailing != null) Padding(padding: const EdgeInsets.only(right: AppSpacing.s8), child: trailing),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              tooltip: dismissTooltip,
              icon: Icon(Icons.close_rounded, size: 20, color: p.text2),
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
        ],
      ),
    );
  }
}
