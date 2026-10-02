import CoreGraphics

/// Corner-radius scale of Design System v2 (frame 03): tag 8 · control 14 · card 22 · hero 30, plus
/// pill/circle via SwiftUI's `Capsule()` / `Circle()`. A nested element's radius is its parent's minus
/// the padding between them (`nested(parent:padding:)`: 22 − 8 = 14).
enum LifeyShapes {
  static let tag: CGFloat = 8
  static let control: CGFloat = 14
  static let card: CGFloat = 22
  static let hero: CGFloat = 30

  /// The radius of an element inset by `padding` inside a parent of radius `parent`.
  static func nested(parent: CGFloat, padding: CGFloat) -> CGFloat {
    max(parent - padding, 0)
  }
}
