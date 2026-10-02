import SwiftUI

/// Ghosted (disabled) is a token pair, not opacity (D-X0.10): background `card` + content `ghost`.
/// On black, opacity turns primary into a "dirty green" with unpredictable contrast.
extension View {
  /// Applies the ghosted pair when `isGhosted`; otherwise leaves the view as is. The caller supplies the
  /// shape of the background.
  func ghosted<S: Shape>(_ isGhosted: Bool = true, in shape: S) -> some View {
    self
      .foregroundColor(isGhosted ? LifeyColors.ghost : nil)
      .background(isGhosted ? LifeyColors.card : Color.clear, in: shape)
      .allowsHitTesting(!isGhosted)
  }
}

/// Double-tap guard (docs/watch/43-watch-f5-set-logging-plan.md §4.2): taps within `seconds` of the last
/// accepted tap are swallowed. Moved out of `LogPage` so every circle button shares it.
struct DoubleTapGuard {
  var seconds: TimeInterval = 0.3
  private var lastTapAt: Date?

  /// True if this tap should run; records it.
  mutating func accept(at now: Date = Date()) -> Bool {
    if let lastTapAt, now.timeIntervalSince(lastTapAt) < seconds { return false }
    lastTapAt = now
    return true
  }
}
