import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// One counted stat in the box score.
class BoxScoreColumn {
  const BoxScoreColumn({
    required this.label,
    required this.value,
    required this.onStep,
  });

  final String label;
  final int value;

  /// Called with **+1 or -1**, never with an absolute value. Deliberately a
  /// delta: [value] is whatever the last build saw, so two taps landing in
  /// the same frame would both compute `value + 1` and one basket would go
  /// missing. A delta is applied to the owner's *current* state instead, so
  /// the count survives however fast the taps come.
  final ValueChanged<int> onStep;
}

/// M44's box-score stepper: two or three columns, each `−` value `+`.
///
/// **The `+` is 1.4× wider than the `−`** ([_plusWidth] / [_minusWidth]) and
/// 44 px high. Adding is the frequent act — a basket just went in — and
/// correcting is the rare one, so the two are deliberately not the same
/// target: the common tap is the one you can hit without looking.
///
/// Three columns for basketball (points · rebounds · assists), **the same
/// component with two** for football (goals · assists) — rebounds is not a
/// concept there, so the column is absent rather than shown at zero.
class BoxScoreStepper extends StatelessWidget {
  const BoxScoreStepper({
    super.key,
    required this.columns,
    required this.enabled,
    required this.onInteraction,
  });

  final List<BoxScoreColumn> columns;
  final bool enabled;

  /// Fired on every tap so the owner can restart the 6 s idle timer — the
  /// panel measures *idle* time, not time-since-open, so a stepper being
  /// actively used never closes under the user's thumb.
  final VoidCallback onInteraction;

  static const double _minusWidth = 40;
  static const double _plusWidth = 56; // 1.4 × 40
  static const double _buttonHeight = 44;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.scoreboard, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.boxScoreCircleLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                l10n.boxScoreAutoCloseHint,
                style: TextStyle(fontSize: 10, color: scheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (index, column) in columns.indexed) ...[
                if (index > 0) const SizedBox(width: 10),
                Expanded(child: _Column(column: column, stepper: this)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({required this.column, required this.stepper});

  final BoxScoreColumn column;
  final BoxScoreStepper stepper;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canDecrement = stepper.enabled && column.value > 0;

    void bump(int delta) {
      stepper.onInteraction();
      column.onStep(delta);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          column.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _StepButton(
              icon: Icons.remove,
              width: BoxScoreStepper._minusWidth,
              onPressed: canDecrement ? () => bump(-1) : null,
            ),
            Expanded(
              child: Text(
                '${column.value}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              width: BoxScoreStepper._plusWidth,
              emphasized: true,
              onPressed: stepper.enabled ? () => bump(1) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.width,
    required this.onPressed,
    this.emphasized = false,
  });

  final IconData icon;
  final double width;
  final VoidCallback? onPressed;

  /// The `+`: filled rather than outlined, on top of being wider.
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null;
    return SizedBox(
      width: width,
      height: BoxScoreStepper._buttonHeight,
      child: Material(
        color: emphasized
            ? scheme.primary.withValues(alpha: disabled ? 0.25 : 1)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Icon(
            icon,
            size: 20,
            color: emphasized
                ? scheme.onPrimary
                : (disabled ? scheme.outline : scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// M44's one-time offer (Q-D2). A card in the live body, deliberately **not a
/// dialog**: a modal over a running match is the very thing the hidden-by-
/// default stepper exists to avoid.
class BoxScoreOfferCard extends StatelessWidget {
  const BoxScoreOfferCard({
    super.key,
    required this.onAccept,
    required this.onDecline,
  });

  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.scoreboard, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.boxScoreOfferTitle,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.boxScoreOfferBody,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          // A Wrap, not a Row: the two labels plus Material's own button
          // padding overflow a 400 px screen in English, and a clipped
          // "won't ask again" promise is the last thing that should be cut.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton(onPressed: onDecline, child: Text(l10n.boxScoreOfferDecline)),
              FilledButton(onPressed: onAccept, child: Text(l10n.boxScoreOfferAccept)),
            ],
          ),
        ],
      ),
    );
  }
}
