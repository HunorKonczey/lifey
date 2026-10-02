import SwiftUI

/// Size-class values computed once from the real dial width (D-X0.5, frame 03). At the two reference
/// widths (45 mm = 198 pt, 41 mm = 176 pt) the canvas table is returned exactly; at any other width the
/// class's table value is scaled by `width / referenceWidth`. Touch targets are never scaled below 44 pt.
///
/// Mirrors Android's `WatchMetrics.kt` (Wear columns); keep the formulas line-for-line equal.
struct WatchMetrics: Equatable {
  /// Below this width (40 mm SE 162 pt, 42 mm 187 pt) the compact class applies — the existing threshold.
  static let compactWidthThreshold: CGFloat = 190
  static let regularReferenceWidth: CGFloat = 198
  static let compactReferenceWidth: CGFloat = 176
  /// Minimum touch target, never undercut (frame 03).
  static let minTouchTarget: CGFloat = 44

  let width: CGFloat

  var isCompact: Bool { width < Self.compactWidthThreshold }

  private var scale: CGFloat {
    width / (isCompact ? Self.compactReferenceWidth : Self.regularReferenceWidth)
  }

  private func scaled(regular: CGFloat, compact: CGFloat) -> CGFloat {
    ((isCompact ? compact : regular) * scale).rounded()
  }

  // Type sizes (frame 02)
  var hero: CGFloat { scaled(regular: 48, compact: 42) }
  /// Dense screens (team sport): hero − 2 on compact.
  var heroDense: CGFloat { scaled(regular: 48, compact: 40) }
  var metric: CGFloat { scaled(regular: 28, compact: 25) }
  var value: CGFloat { scaled(regular: 19, compact: 17) }

  // Controls
  var circleButton: CGFloat { max(scaled(regular: 78, compact: 70), Self.minTouchTarget) }
  var buttonHeight: CGFloat { max(scaled(regular: 48, compact: 44), Self.minTouchTarget) }
  var minTouchTarget: CGFloat { Self.minTouchTarget }

  /// Side margin: 8 % of the width (≈ 14 pt on the compact reference).
  var sideMargin: CGFloat { (width * 0.08).rounded() }
}

private struct WatchMetricsKey: EnvironmentKey {
  static let defaultValue = WatchMetrics(width: WatchMetrics.regularReferenceWidth)
}

extension EnvironmentValues {
  var watchMetrics: WatchMetrics {
    get { self[WatchMetricsKey.self] }
    set { self[WatchMetricsKey.self] = newValue }
  }
}

extension View {
  /// Injects `WatchMetrics` from the width of the space this view is laid out in. Applied once, at the
  /// root (`ContentView`).
  func watchMetricsFromWidth() -> some View {
    GeometryReader { proxy in
      self
        .environment(\.watchMetrics, WatchMetrics(width: proxy.size.width))
        .frame(width: proxy.size.width, height: proxy.size.height)
    }
  }
}
