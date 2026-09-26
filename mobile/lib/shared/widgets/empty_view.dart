import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'ds/lifey_card.dart';
import 'scroll_fill.dart';

/// Empty state — the design system's "ÜRES ÁLLAPOT" card (docs/redesign/
/// 77-mobile-redesign-plan.md R0.12): a 56 px tinted icon holder, a 17/700
/// title, one or two lines of secondary text, and up to two actions — the
/// main one filled, the other a secondary button ("Add meal" / "Copy a day").
///
/// Stays scrollable (inside [ScrollFill]) so it works under pull-to-refresh.
/// Pass the actions as ready buttons; [action] alone keeps the v1 call sites
/// working unchanged.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.secondaryAction,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Main call to action, usually a `FilledButton`.
  final Widget? action;

  /// Second action, usually an `OutlinedButton` (the canvas "Secondary").
  final Widget? secondaryAction;

  /// Tint of the icon holder; defaults to brand olive. Pass a metric colour
  /// when the empty state belongs to one metric.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ScrollFill(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: EmptyStateCard(
          icon: icon,
          title: title,
          subtitle: subtitle,
          action: action,
          secondaryAction: secondaryAction,
          color: color,
        ),
      ),
    );
  }
}

/// The card of an [EmptyView] on its own, for an empty section inside a
/// screen that has content above it (the Meals tab's day with no meals).
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.secondaryAction,
    this.color,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget? secondaryAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final tint = color ?? Theme.of(context).colorScheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LifeyCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: dark ? 0.14 : 0.12),
              borderRadius: AppRadius.controlAll,
            ),
            child: Icon(icon, size: 28, color: tint),
          ),
          const SizedBox(height: AppSpacing.s12),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: t.titleMedium!.copyWith(height: 1.3, color: p.text),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: t.titleSmall!.copyWith(fontWeight: FontWeight.w500, height: 1.45, color: p.text2),
              ),
            ),
          ],
          if (action != null || secondaryAction != null) ...[
            const SizedBox(height: AppSpacing.s16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                if (action != null) action!,
                if (secondaryAction != null) secondaryAction!,
              ],
            ),
          ],
        ],
      ),
    );
  }
}
