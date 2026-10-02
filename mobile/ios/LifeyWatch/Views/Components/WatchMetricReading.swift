import SwiftUI

/// Metric reading (frame 04/02): icon + number (+ optional unit) at `metric` level (heart rate) or
/// `value` level (kcal). Number and icon both carry the metric colour (canvas AW1.1: 121 in heart, 87 in
/// calories); the unit is CAPS `label` in `text2`.
struct WatchMetricReading: View {
  enum Level { case metric, value }

  let icon: String
  let iconTint: Color
  let number: String
  var unit: String? = nil
  var level: Level = .value
  var accessibilityText: String? = nil

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    HStack(spacing: LifeySpacing.xs) {
      Image(systemName: icon)
        .font(.system(size: level == .metric ? metrics.metric * 0.7 : metrics.value * 0.8))
        .foregroundColor(iconTint)
      LifeyNumber(
        number: number, unit: unit?.uppercased(), style: level == .metric ? .metric : .value,
        color: iconTint, accessibilityText: accessibilityText ?? [number, unit].compactMap { $0 }.joined(separator: " "))
    }
  }
}
