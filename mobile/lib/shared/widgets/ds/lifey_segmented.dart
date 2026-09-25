import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/app_localizations.dart';

/// A pill segmented control — "7 days / 30 days / 90 days / All" (design
/// system canvas "SZEGMENTÁLT VÁLTÓ"; docs/redesign/77-mobile-redesign-plan.md
/// R0.8).
///
/// A card-coloured pill track with a hairline ring and 4 px padding; the
/// selected segment is a surface-3 pill with a small shadow that slides to
/// the new choice (48 tall in all: a 40 pill in a 4 px track). Material's `SegmentedButton` draws joined segments with
/// shared borders and can't produce the floating selected pill, hence a
/// widget instead of a theme. Labels shrink to fit rather than
/// truncate.
class LifeySegmented<T> extends StatelessWidget {
  const LifeySegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.locked = const {},
  }) : assert(segments.length >= 2);

  /// Value → label, in display order.
  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Segments that need Pro: they stay tappable (the caller decides what a tap
  /// does — open the paywall) and carry a small lock before the label.
  final Set<T> locked;

  static const double _pad = 4;
  static const double _segmentHeight = 40;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final index = segments.indexWhere((s) => s.$1 == selected);
    // Dark: the selected pill is a lighter surface with light text. Light: the
    // brand green with white text (canvases 4.2 / 5 light).
    final light = Theme.of(context).brightness == Brightness.light;
    final scheme = Theme.of(context).colorScheme;
    final pillColor = light ? scheme.primary : p.control;
    final selectedText = light ? scheme.onPrimary : p.text;
    return Container(
      padding: const EdgeInsets.all(_pad),
      decoration: BoxDecoration(color: p.card, borderRadius: AppRadius.pill),
      // The hairline ring is a foreground decoration, like the canvas's inset
      // box-shadow: a real border would add 2 px to the layout.
      foregroundDecoration: BoxDecoration(
        borderRadius: AppRadius.pill,
        border: Border.all(color: context.elevation.border),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth / segments.length;
        return SizedBox(
          height: _segmentHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (index >= 0)
                AnimatedPositioned(
                  duration: AppMotion.of(context, AppMotion.page),
                  curve: AppMotion.standard,
                  left: width * index,
                  width: width,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: pillColor,
                      borderRadius: AppRadius.pill,
                      boxShadow: Theme.of(context).brightness == Brightness.dark
                          ? const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 8)]
                          : context.elevation.e1,
                    ),
                  ),
                ),
              Row(children: [
                for (final (value, label) in segments)
                  Expanded(
                    child: Semantics(
                      selected: value == selected,
                      button: true,
                      inMutuallyExclusiveGroup: true,
                      // "90 days — Pro required" instead of just the label: the
                      // lock is a glyph, and a gate must not rest on that alone
                      // (`69` §8).
                      label: locked.contains(value)
                          ? AppLocalizations.of(context)!.statRangeLockedSemanticsLabel(label)
                          : null,
                      excludeSemantics: locked.contains(value),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(value),
                        child: SizedBox(
                          height: _segmentHeight,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (locked.contains(value)) ...[
                                      Icon(Icons.lock_rounded, size: 14, color: p.text3),
                                      const SizedBox(width: AppSpacing.s4),
                                    ],
                                    Text(
                                      label,
                                      maxLines: 1,
                                      style: t.labelLarge!.copyWith(
                                        fontWeight: value == selected ? FontWeight.w700 : FontWeight.w600,
                                        color: value == selected ? selectedText : p.text2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ],
          ),
        );
      }),
    );
  }
}

/// The canvas's 48 px square icon button on surface-2 ("content_copy" next to
/// the FAB). For icon-only actions that sit beside buttons; toolbar icons
/// stay plain `IconButton`s.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.onPressed, required this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(48),
        backgroundColor: p.nested,
        foregroundColor: p.text,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.controlAll),
      ),
    );
  }
}
