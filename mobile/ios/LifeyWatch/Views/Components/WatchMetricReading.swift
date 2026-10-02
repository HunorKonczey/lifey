import SwiftUI

/// Metric reading (frame 04/02): icon + number (+ optional unit) at `metric` level (heart rate) or
/// `value` level (kcal). The number is PJS, tabular, in `text`; the icon carries the metric colour.
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
        number: number, unit: unit, style: level == .metric ? .metric : .value,
        accessibilityText: accessibilityText)
    }
  }
}
