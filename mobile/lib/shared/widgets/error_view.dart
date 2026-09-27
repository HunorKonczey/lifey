import 'package:flutter/material.dart';

import '../../core/network/error_message.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/app_localizations.dart';
import 'ds/lifey_card.dart';
import 'scroll_fill.dart';

/// Error state — the design system's "HIBAÁLLAPOT" card (docs/redesign/
/// 77-mobile-redesign-plan.md R0.12): a card with a soft red ring, a 40 px
/// red-tinted icon holder, a 15/700 title, the explanation in secondary
/// text and a "Try again" text action.
///
/// The message defaults to `friendlyError(error)`; pass [message] (and
/// [title]) for a situation the design words specifically — "AI features
/// need a connection. Your recipes and logs still work offline." Stays
/// scrollable (inside [ScrollFill]) so it works under pull-to-refresh.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
    this.message,
    this.icon = Icons.cloud_off_rounded,
  });

  final Object error;
  final VoidCallback? onRetry;

  /// Overrides the generic "Something went wrong".
  final String? title;

  /// Overrides the message derived from [error].
  final String? message;

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final red = context.metricColors.heart;
    return ScrollFill(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        child: Container(
          foregroundDecoration: BoxDecoration(
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: red.withValues(alpha: 0.3)),
          ),
          child: LifeyCard(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: red.withValues(alpha: 0.16),
                    borderRadius: AppRadius.controlAll,
                  ),
                  child: Icon(icon, size: 22, color: red),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title ?? l10n.somethingWentWrongTitle,
                          style: t.bodyMedium!.copyWith(fontWeight: FontWeight.w700, height: 1.3, color: p.text),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        message ?? friendlyError(error),
                        style: t.titleSmall!.copyWith(fontWeight: FontWeight.w500, height: 1.45, color: p.text2),
                      ),
                      if (onRetry != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s4),
                          child: TextButton(
                            onPressed: onRetry,
                            style: TextButton.styleFrom(
                              // Flush with the text above; 48 dp target kept.
                              padding: const EdgeInsets.symmetric(horizontal: 0),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Text(l10n.retryButton),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
