import 'package:flutter/material.dart';

/// A row of `min..max` numbered chips for a subjective effort/intensity
/// rating — extracted from `PostWorkoutFeedbackSheet` (docs/cardio/
/// 59-cardio-implementation-plan.md C1.9 "RPE/jegyzet újrahasznosítás") so
/// `LogCardioSheet` can reuse the same control at a different range: 1-10 for
/// the universal post-workout RPE, 1-5 for the GAME family's subjective
/// intensity (`CardioMetrics.intensity`) — two different fields, same widget.
class RpeSelector extends StatelessWidget {
  const RpeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
    this.lowAnchorLabel,
    this.highAnchorLabel,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  /// Optional labels under the low/high ends of the scale (e.g. "Very easy" /
  /// "Maximal effort"). Omitted entirely when null — the GAME intensity scale
  /// (`design/Lifey Cardio Design.dc.html` M18) has no anchor text at all.
  final String? lowAnchorLabel;
  final String? highAnchorLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var v = min; v <= max; v++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _RpeChip(
                    value: v,
                    selected: value == v,
                    onTap: () => onChanged(v),
                  ),
                ),
              ),
          ],
        ),
        if (lowAnchorLabel != null && highAnchorLabel != null) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lowAnchorLabel!, style: theme.textTheme.bodySmall),
              Text(highAnchorLabel!, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ],
    );
  }
}

class _RpeChip extends StatelessWidget {
  const _RpeChip({required this.value, required this.selected, required this.onTap});

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest;
    final fg = selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(
          '$value',
          style: theme.textTheme.labelLarge?.copyWith(
            color: fg,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
