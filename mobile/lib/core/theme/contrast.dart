import 'dart:ui';

/// WCAG 2.x contrast ratio between [foreground] and [background]. A
/// translucent [foreground] is composited onto [background] first, the way
/// it renders. Used by the contrast tests and the debug design gallery.
double contrastRatio(Color foreground, Color background) {
  final fg = Color.alphaBlend(foreground, background).computeLuminance();
  final bg = background.computeLuminance();
  final hi = fg > bg ? fg : bg;
  final lo = fg > bg ? bg : fg;
  return (hi + 0.05) / (lo + 0.05);
}

/// The fill a tinted chip draws: [color] at [alpha] over [surface].
Color tintOver(Color color, double alpha, Color surface) =>
    Color.alphaBlend(color.withValues(alpha: alpha), surface);
