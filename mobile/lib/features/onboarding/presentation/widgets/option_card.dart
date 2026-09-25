import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/ds/list_group.dart';

/// A short choice tile — gender, primary goal (canvas Lifey 5 › 6, "PRIMARY
/// GOAL" row): the icon over the label on the card surface; the chosen one
/// takes the primary tint and ring.
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: active,
      inMutuallyExclusiveGroup: true,
      excludeSemantics: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.page),
          curve: AppMotion.standard,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: active ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.16), p.card) : p.card,
            borderRadius: AppRadius.cardAll,
            border: Border.all(
              color: active ? scheme.primary : context.elevation.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: active ? scheme.primary : p.text2),
              const SizedBox(height: AppSpacing.s12),
              Text(label, style: t.titleMedium!.copyWith(color: p.text)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One answer of a single-choice question as a card: icon holder, title,
/// description and a radio mark on the right (canvas: "How active are you?").
/// A list of these replaces the two-column grid, where the descriptions ran to
/// three lines and the fifth card hung alone.
class RadioOptionRow extends StatelessWidget {
  const RadioOptionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      excludeSemantics: true,
      label: '$title, $description',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.of(context, AppMotion.page),
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: AppSpacing.s12),
          decoration: BoxDecoration(
            color: selected ? Color.alphaBlend(scheme.primary.withValues(alpha: 0.16), p.card) : p.card,
            borderRadius: AppRadius.cardAll,
            border: Border.all(
              color: selected ? scheme.primary : context.elevation.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              ListIconHolder(icon: icon, color: selected ? scheme.primary : p.text2),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium!.copyWith(color: p.text)),
                    const SizedBox(height: 2),
                    Text(description, style: t.bodyMedium!.copyWith(color: p.text2)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              _RadioMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.page),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.transparent,
        border: Border.all(color: selected ? scheme.primary : context.palette.text3, width: 2),
      ),
      child: selected ? Icon(Icons.check_rounded, size: 16, color: scheme.onPrimary) : null,
    );
  }
}
