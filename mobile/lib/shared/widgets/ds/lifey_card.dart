import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import 'card_edge_painter.dart';
import 'pressable.dart';

/// The three surface roles of design system v2
/// (docs/redesign/77-mobile-redesign-plan.md R0.7).
enum LifeyCardVariant {
  /// Regular card — surface-1, radius 22, padding 16, e1.
  card,

  /// The one hero of a screen — surface-1, radius 30, padding 20.
  hero,

  /// Something grouped inside a card or sheet — surface-2, radius 14 by
  /// default, no shadow.
  nested,
}

/// A design-system card. Related data goes in **one** card, split by row
/// dividers — never a card inside a card (the design's "fewer boxes, more
/// groups" rule); use [LifeyCardVariant.nested] only for a genuinely separate
/// block inside a sheet or hero.
///
/// Depth follows the canvases: in dark a 1 px top light edge (no drop shadow
/// — the dashboard hero has none either, although the design-system page
/// labels heroes "e2"); in light white cards with a soft warm shadow. With
/// [onTap] / [onLongPress] the card gets the 0.98 tap scale, not a ripple.
class LifeyCard extends StatelessWidget {
  const LifeyCard({
    super.key,
    required this.child,
    this.variant = LifeyCardVariant.card,
    this.padding,
    this.radius,
    this.color,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
    this.clip = false,
  });

  const LifeyCard.hero({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
    this.clip = false,
  })  : variant = LifeyCardVariant.hero,
        radius = null,
        color = null;

  const LifeyCard.nested({
    super.key,
    required this.child,
    this.padding,
    this.radius,
    this.color,
    this.onTap,
    this.onLongPress,
    this.semanticsLabel,
    this.clip = false,
  }) : variant = LifeyCardVariant.nested;

  final Widget child;
  final LifeyCardVariant variant;

  /// Overrides the variant's padding (16 card, 20 hero, 12 nested). Use
  /// `EdgeInsets.zero` for a card of edge-to-edge list rows.
  final EdgeInsetsGeometry? padding;

  /// Overrides the variant's radius. For a nested block, pass
  /// `AppRadius.nested(parentRadius, parentPadding)` so the corners stay
  /// concentric.
  final double? radius;

  /// Overrides the surface colour (e.g. a tinted empty-state card).
  final Color? color;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticsLabel;

  /// Clip the child to the rounded shape (images, edge-to-edge highlights).
  final bool clip;

  double get _radius =>
      radius ??
      switch (variant) {
        LifeyCardVariant.card => AppRadius.card,
        LifeyCardVariant.hero => AppRadius.hero,
        LifeyCardVariant.nested => AppRadius.control,
      };

  EdgeInsetsGeometry get _padding =>
      padding ??
      switch (variant) {
        LifeyCardVariant.card => const EdgeInsets.all(AppSpacing.s16),
        LifeyCardVariant.hero => const EdgeInsets.all(AppSpacing.s20),
        LifeyCardVariant.nested => const EdgeInsets.all(AppSpacing.s12),
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = context.elevation;
    final borderRadius = BorderRadius.circular(_radius);
    final nested = variant == LifeyCardVariant.nested;

    Widget content = Padding(padding: _padding, child: child);
    if (clip) content = ClipRRect(borderRadius: borderRadius, child: content);

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? (nested ? p.nested : p.card),
        borderRadius: borderRadius,
        boxShadow: nested ? null : e.e1,
      ),
      child: CustomPaint(
        foregroundPainter:
            nested ? null : CardEdgePainter(color: e.cardEdge, borderRadius: borderRadius),
        child: content,
      ),
    );

    if (onTap == null && onLongPress == null) return card;
    return Pressable(
      onTap: onTap,
      onLongPress: onLongPress,
      semanticsLabel: semanticsLabel,
      child: card,
    );
  }
}
