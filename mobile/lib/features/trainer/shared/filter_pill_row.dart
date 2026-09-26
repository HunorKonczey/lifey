import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// One choice in a [FilterPillRow].
typedef FilterPill = ({String label, bool selected, VoidCallback onTap});

/// A horizontally scrolling row of pill filters (canvas Lifey 6: the chosen one
/// filled in the primary colour, the rest a card with a hairline). Shared by the
/// clients' sort pills and the assignments' type / client filters, so a choice
/// looks the same wherever the trainer makes one.
///
/// Not Material's `ChoiceChip`: the pill is 44 dp tall with a 20 dp side
/// padding, sized for a thumb rather than a mouse.
class FilterPillRow extends StatelessWidget {
  const FilterPillRow({super.key, required this.pills});

  final List<FilterPill> pills;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
        itemCount: pills.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
        itemBuilder: (context, index) {
          final pill = pills[index];
          final on = pill.selected;
          return Semantics(
            button: true,
            selected: on,
            label: pill.label,
            excludeSemantics: true,
            child: Material(
              color: on ? scheme.primary : p.card,
              shape: StadiumBorder(side: BorderSide(color: on ? scheme.primary : context.elevation.border)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: pill.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
                  child: Center(
                    child: Text(
                      pill.label,
                      maxLines: 1,
                      style: t.labelLarge!.copyWith(
                        fontWeight: on ? FontWeight.w800 : FontWeight.w700,
                        color: on ? scheme.onPrimary : p.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
