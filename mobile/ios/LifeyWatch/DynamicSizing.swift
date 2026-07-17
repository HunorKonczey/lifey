import CoreGraphics

/// watchOS dynamic-sizing helpers (docs/40-watch-app-plan.md §12.1 B4 /
/// 41-watch-design-prompt.md canvas "Dynamic sizing" row): paddings and the
/// hero/hero-adjacent type scale are derived from the actual dial size
/// (`GeometryReader`-fractions) rather than fixed pt values tuned for one
/// screen, checked against both the ~40/41mm (compact) and ~45/49mm
/// (regular) round watchOS size classes. Mirrors Android's `DynamicSizing.kt`.
enum DynamicSizing {
  static let screenPaddingFraction: CGFloat = 0.08

  /// Below this, treat the display as the compact (~40/41mm, ~162–176pt
  /// wide) size class rather than regular (~45/49mm, ~198–205pt wide).
  static let compactScreenWidth: CGFloat = 190

  static func isCompact(width: CGFloat) -> Bool {
    width < compactScreenWidth
  }
}
