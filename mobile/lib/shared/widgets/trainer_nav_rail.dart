import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import 'adaptive_bottom_nav.dart' show AdaptiveNavDestination;

/// The trainer's navigation on a tablet (canvas Lifey 6 › "Trainer tablet"): a
/// 96 dp rail down the left edge instead of the floating bottom bar — the
/// brand tile on top, then one item per destination, each a 56 × 36 pill with
/// its icon and the label under it in 11/700. The active pill is filled in the
/// primary colour; the others are bare icons in the secondary text colour.
///
/// Labels stay visible for every destination (unlike the phone bar, where only
/// the active one is named) because a rail has the room, and a trainer switching
/// between four screens all day should not have to guess an icon.
class TrainerNavRail extends StatelessWidget {
  const TrainerNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AdaptiveNavDestination> destinations;

  static const double width = 96;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      decoration: BoxDecoration(border: Border(right: BorderSide(color: p.hairline))),
      child: SafeArea(
        right: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
          child: Column(
            children: [
              // The app's mark. Decorative: the screen title says where you are.
              ExcludeSemantics(
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: AppRadius.controlAll),
                  child: Text(
                    'L',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimary,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s32),
              for (final (i, destination) in destinations.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.s12),
                _RailItem(
                  destination: destination,
                  selected: i == selectedIndex,
                  onTap: () => onDestinationSelected(i),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.destination, required this.selected, required this.onTap});

  final AdaptiveNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.labelSmall!.copyWith(
          fontWeight: FontWeight.w700,
          color: selected ? p.text : p.text2,
        );

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: ExcludeSemantics(
        child: InkResponse(
          onTap: onTap,
          radius: 40,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? scheme.primary : Colors.transparent,
                    borderRadius: AppRadius.pill,
                  ),
                  child: Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 22,
                    color: selected ? scheme.onPrimary : p.text2,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                  child: Text(destination.label, textAlign: TextAlign.center, style: labelStyle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
