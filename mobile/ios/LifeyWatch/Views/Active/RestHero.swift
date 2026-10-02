import SwiftUI
import WatchKit

/// Below this many seconds remaining, the rest ring switches to
/// `LifeyColors.negative` (docs/40-watch-app-plan.md §12.1 B1, mirrors
/// Android's `REST_RING_NEGATIVE_THRESHOLD_MS`).
let restRingNegativeThresholdSeconds = 5

/// Rest-as-hero state (docs/40-watch-app-plan.md §12.1 B1 / 41-watch-design-
/// prompt.md §3.3, canvas AW 03): a drain-down progress ring takes the
/// metrics page's hero slot instead of the countdown being a small caption
/// line, with a "of <total>" target below it, a "Next · <exercise> — Set n
/// of total" line for what resumes once rest ends, and a small HR/kcal
/// reading underneath (rest doesn't mean the metrics disappear, just
/// shrink). Color shifts to `LifeyColors.negative` for the final 5 seconds,
/// matching the haptic that fires at 0 (`WorkoutManager`'s independently-
/// scheduled vibration).
struct RestHeroView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let remainingSeconds: Int
  let totalSeconds: Int?
  let exerciseName: String
  let setsDone: Int?
  let setsTotal: Int?
  let isCompact: Bool

  private var progress: Double {
    guard let totalSeconds, totalSeconds > 0 else { return 1 }
    return min(1, max(0, Double(remainingSeconds) / Double(totalSeconds)))
  }

  private var ringColor: Color {
    remainingSeconds <= restRingNegativeThresholdSeconds ? LifeyColors.negative : LifeyColors.primary
  }

  private var labelFont: Font { isCompact ? .caption2 : .caption }
  private var ringNumberFont: Font { isCompact ? .system(.title, design: .rounded) : .system(.largeTitle, design: .rounded) }
  private var nextLineFont: Font { isCompact ? .caption2 : .caption }
  // Shrunk from caption/title3 (overflow fix, mirrors MetricsPage's row) —
  // same 3-digit clipping risk for the small HR/kcal reading under the ring.
  private var smallMetricFont: Font { isCompact ? .caption2 : .body }
  private var smallMetricIconSize: CGFloat { isCompact ? 14 : 16 }
  /// A wide, short bar rather than a ring (a round dial leaves the ring's
  /// corners empty; a full-width bar uses that space and reads bigger at a
  /// glance) — docs/40-watch-app-plan.md §12.1 B1 follow-up feedback.
  private var barHeight: CGFloat { isCompact ? 60 : 78 }

  var body: some View {
    VStack(spacing: 4) {
      HeaderChip(
        icon: "timer", label: String(localized: "rest_hero_label"), isCompact: isCompact,
        isStandalone: workoutManager.showsStandaloneBadge)
      GeometryReader { barGeometry in
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: LifeyShapes.cardLarge)
            .fill(LifeyColors.container)
          RoundedRectangle(cornerRadius: LifeyShapes.cardLarge)
            .fill(ringColor)
            .frame(width: barGeometry.size.width * progress)
        }
        .overlay(
          Text(formatSeconds(remainingSeconds))
            .font(ringNumberFont)
            .foregroundColor(LifeyColors.onSurface)
            .monospacedDigit()
        )
      }
      .frame(height: barHeight)
      .padding(.top, 8)
      if let totalSeconds {
        Text(String(format: String(localized: "rest_hero_total_format"), formatSeconds(totalSeconds)))
          .font(labelFont)
          .foregroundColor(LifeyColors.onSurfaceVariant)
      }
      if let setsDone, let setsTotal {
        Text(
          String(
            format: String(localized: "rest_hero_next_with_sets_format"), exerciseName,
            min(setsDone + 1, setsTotal), setsTotal)
        )
        .font(nextLineFont)
        .foregroundColor(LifeyColors.onSurfaceVariant)
        .lineLimit(1)
        .truncationMode(.tail)
      } else {
        Text(String(format: String(localized: "rest_hero_next_format"), exerciseName))
          .font(nextLineFont)
          .foregroundColor(LifeyColors.onSurfaceVariant)
          .lineLimit(1)
          .truncationMode(.tail)
      }
      HStack(spacing: isCompact ? 8 : 14) {
        if let heartRate = workoutManager.heartRateBpm {
          MetricReading(
            icon: "heart.fill", iconTint: LifeyColors.heart, value: "\(Int(heartRate.rounded()))",
            iconSize: smallMetricIconSize, valueFont: smallMetricFont)
        }
        if let calories = workoutManager.activeCalories {
          MetricReading(
            icon: "flame.fill", iconTint: LifeyColors.calories, value: "\(Int(calories.rounded()))",
            iconSize: smallMetricIconSize, valueFont: smallMetricFont)
        }
      }
      .padding(.top, 8)
    }
  }
}

/// The GO flash itself (docs/40-watch-app-plan.md §12.1 B2): a brief
/// primary-color fill pulse with a "GO" wordmark covering the whole dial,
/// mirroring Android's `GoFlash` animation timing (150ms fade in, 250ms
/// hold, 700ms fade out). The haptic fires independently in
/// `WorkoutManager` — this is purely decorative.
struct GoFlashView: View {
  @State private var opacity: Double = 0

  var body: some View {
    ZStack {
      LifeyColors.primary.opacity(opacity)
      Text("rest_go_label")
        .font(.system(.title, design: .rounded))
        .foregroundColor(LifeyColors.onPrimary.opacity(opacity))
    }
    .ignoresSafeArea()
    .onAppear {
      withAnimation(.easeInOut(duration: 0.15)) { opacity = 1 }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        withAnimation(.easeInOut(duration: 0.7)) { opacity = 0 }
      }
    }
  }
}
