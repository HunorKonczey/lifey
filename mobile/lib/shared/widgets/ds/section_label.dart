import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_type.dart';

/// The caps label above a group — "TODAY'S MEALS" — with an optional
/// trailing action such as "See all" (design system v2, dashboard canvas;
/// docs/redesign/77-mobile-redesign-plan.md R0.7).
///
/// The only place ALL CAPS is used: 12/16 · 700 · +8 %, secondary text
/// colour. Inside cards labels stay in sentence case. [label] is passed in
/// sentence case and upper-cased here, so the same ARB string also works
/// where it isn't a section label. Screen readers get it as a header.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.label, {
    super.key,
    this.actionLabel,
    this.onAction,
  }) : assert((actionLabel == null) == (onAction == null),
            'actionLabel and onAction go together');

  final String label;

  /// e.g. "See all" — already localized.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                label.toUpperCase(),
                style: AppType.sectionLabel(color: p.text2),
                semanticsLabel: label,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                // Keeps a 48 dp touch target while the text sits flush with
                // the label's baseline.
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
