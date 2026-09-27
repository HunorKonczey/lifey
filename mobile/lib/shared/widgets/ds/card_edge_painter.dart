import 'package:flutter/rendering.dart';

/// The 1 px top light edge of a dark-theme card (design system v2 elevation,
/// docs/redesign/77-mobile-redesign-plan.md R0.2).
///
/// The canvas draws it as CSS `box-shadow: inset 0 1px 0 <color>`: the part
/// of the card's rounded rect *not* covered by the same rect shifted down by
/// [width]. That gives a hairline along the top that follows the corner
/// radius and thins out towards the sides — which a Flutter `Border` can't
/// draw (a border with differing sides can't have a radius). Use as a
/// `foregroundPainter`; a fully transparent [color] (the light theme) paints
/// nothing.
class CardEdgePainter extends CustomPainter {
  const CardEdgePainter({
    required this.color,
    required this.borderRadius,
    this.width = 1,
  });

  final Color color;
  final BorderRadius borderRadius;
  final double width;

  /// The band that gets painted, in the painter's coordinate space.
  static Path edgePath(Size size, BorderRadius borderRadius, double width) {
    final card = Path()..addRRect(borderRadius.toRRect(Offset.zero & size));
    return Path.combine(PathOperation.difference, card, card.shift(Offset(0, width)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0 || size.isEmpty) return;
    canvas.drawPath(
      edgePath(size, borderRadius, width),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(CardEdgePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.width != width;
}
