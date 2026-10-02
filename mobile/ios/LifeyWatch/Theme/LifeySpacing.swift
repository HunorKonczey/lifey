import CoreGraphics

/// Spacing scale of the watch design system (frame 03): 2 / 4 / 6 / 8 / 12 pt. Side margins are not here —
/// they are a fraction of the dial (`WatchMetrics.sideMargin`).
enum LifeySpacing {
  static let xxs: CGFloat = 2
  static let xs: CGFloat = 4
  static let sm: CGFloat = 6
  static let md: CGFloat = 8
  static let lg: CGFloat = 12
}
