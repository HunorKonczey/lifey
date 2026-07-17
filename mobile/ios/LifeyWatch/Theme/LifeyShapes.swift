import CoreGraphics

/// Corner-radius scale (41-watch-design-prompt.md §1 "Shape & motion"):
/// 8 for chips/tags, 16 for buttons, 20 for cards, 24 for large cards
/// (docs/40-watch-app-plan.md §12.1 B6) — mirrors Android's `LifeyShapes.kt`.
/// Pill/circular shapes use SwiftUI's `Capsule()`/`Circle()` directly rather
/// than a radius constant.
enum LifeyShapes {
  static let chip: CGFloat = 8
  static let button: CGFloat = 16
  static let card: CGFloat = 20
  static let cardLarge: CGFloat = 24
}
