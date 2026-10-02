import SwiftUI
import WatchKit

/// Below this many seconds remaining the rest countdown turns to the warning colour (frame 04/06). Kept for
/// the callers that still name it; the component owns the real constant (`RestCountdown.warningSeconds`).
let restRingNegativeThresholdSeconds = RestCountdown.warningSeconds

// MARK: - Rest (redesign X1.8 — AW1.13, AW1.14, AW1.16)

/// Plain data behind the rest state.
struct RestModel {
  var remainingSeconds: Int
  var totalSeconds: Int?
  /// "Következő · Fekvenyomás — 3/4. szett" — already formatted (one of the two `rest_hero_next_*` keys).
  var nextLine: String
  var heartRateBpm: Int?
  var calories: Int?
  var showsStandaloneMark = false
  var markTapped = false
}

/// The rest countdown takes the metric page's hero slot (D1): header chip "PIHENŐ", the countdown number over
/// a white bar, the "Következő" line (two lines, on long names "— 3/4. szett" falls to line two), and a small
/// HR + kcal row. Last 5 s: number and fill in the calories colour, 1 Hz pulse (inside `RestCountdown`).
struct RestContent: View {
  let model: RestModel
  var onMarkTap: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      WatchHeaderChip(
        icon: "timer", label: String(localized: "rest_hero_label"),
        standaloneMark: model.showsStandaloneMark ? (model.markTapped ? .tapped : .idle) : nil,
        onMarkTap: onMarkTap)
      RestCountdown(remainingSeconds: model.remainingSeconds, totalSeconds: model.totalSeconds ?? 0)
        .padding(.top, LifeySpacing.sm)
      Text(verbatim: model.nextLine)
        .lifeyBody(metrics)
        .foregroundColor(LifeyColors.text2)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .padding(.top, LifeySpacing.md)
      Spacer(minLength: LifeySpacing.xs)
      HStack(spacing: LifeySpacing.lg) {
        if let bpm = model.heartRateBpm {
          WatchMetricReading(icon: "heart.fill", iconTint: LifeyColors.heart, number: "\(bpm)", level: .value)
        }
        if let calories = model.calories {
          WatchMetricReading(icon: "flame.fill", iconTint: LifeyColors.calories, number: "\(calories)", level: .value)
        }
      }
    }
    .padding(.horizontal, metrics.sideMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }
}

/// The live rest state, built from `WorkoutManager` values `MetricsPage` already reads.
struct RestHeroView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let remainingSeconds: Int
  let totalSeconds: Int?
  let exerciseName: String
  let setsDone: Int?
  let setsTotal: Int?
  let isCompact: Bool

  var body: some View {
    RestContent(
      model: RestModel(
        remainingSeconds: remainingSeconds, totalSeconds: totalSeconds, nextLine: nextLine,
        heartRateBpm: workoutManager.heartRateBpm.map { Int($0.rounded()) },
        calories: workoutManager.activeCalories.map { Int($0.rounded()) },
        showsStandaloneMark: workoutManager.showsStandaloneBadge,
        markTapped: workoutManager.isRetryingAdoption),
      onMarkTap: { workoutManager.retryAdoption() })
  }

  private var nextLine: String {
    if let setsDone, let setsTotal {
      return String(
        format: String(localized: "rest_hero_next_with_sets_format"), exerciseName,
        min(setsDone + 1, setsTotal), setsTotal)
    }
    return String(format: String(localized: "rest_hero_next_format"), exerciseName)
  }
}
