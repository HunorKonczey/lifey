import SwiftUI
import WatchKit

/// Makes whatever it wraps open the exercise list — but only while there is
/// something to switch to (`canChooseExercise`), so a Quick strength session
/// or a phone that hasn't pushed its list keeps a plain, non-interactive
/// readout instead of a control that opens an empty screen.
struct ExercisePickerTarget<Content: View>: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let onOpenExerciseList: () -> Void
  @ViewBuilder let content: Content

  var body: some View {
    if workoutManager.canChooseExercise {
      Button(action: onOpenExerciseList) { content }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("standalone_exercise_list_title"))
    } else {
      content
    }
  }
}

// MARK: - Metrics page (redesign X1.2 — AW1.1 … AW1.4)

/// Plain data behind the strength metrics page, so the debug gallery can render every canvas state without
/// a `WorkoutManager`. Built from the manager by `MetricsPage` once a second.
struct MetricsModel {
  var headerLabel: String
  var showsStandaloneMark = false
  var markTapped = false
  var isPaused = false
  var elapsedSeconds: Int
  var heartRateBpm: Int?
  var calories: Int?
  var exerciseName: String
  var setsDone: Int?
  var setsTotal: Int?
  /// Quick strength: no plan, so no bar — "3. szett · 24 ism."
  var freeFormText: String?
  var justLoggedIndex: Int?
  var canChooseExercise = false
}

/// One hero, one level two, one level three (frame D1): elapsed time (white, `hero`) › heart rate (`metric`,
/// heart colour, fixed slot) › kcal (`value`). The exercise card with its segment bar sits at the bottom.
struct MetricsContent: View {
  let model: MetricsModel
  /// Always-On (reduced luminance): outlined chip, minutes instead of seconds, HR at 60 %, one quiet exercise
  /// line; kcal, card and buttons are gone and nothing is filled (frame 08, D-X0.15).
  var isAOD = false
  var onMarkTap: () -> Void = {}
  var onOpenExerciseList: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  /// The card's corner radius follows the display margin (nested rule): 22 − 6 = 16, compact 22 − 8 = 14.
  private var cardRadius: CGFloat { LifeyShapes.nested(parent: LifeyShapes.card, padding: metrics.isCompact ? 8 : 6) }

  var body: some View {
    if isAOD { aodBody } else { fullBody }
  }

  private var aodBody: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: LifeySpacing.xs) {
        Image(systemName: LifeyAOD.symbol(model.isPaused ? "pause.fill" : "dumbbell"))
          .font(.system(size: 13))
        Text(verbatim: model.isPaused ? String(localized: "active_paused_indicator") : model.headerLabel)
          .lifeyLabel(metrics, caps: true).lineLimit(1)
      }
      .foregroundColor(model.isPaused ? LifeyAOD.metricTint(LifeyColors.clay) : LifeyAOD.numberColor)
      Text(verbatim: LifeyAOD.elapsed(model.elapsedSeconds))
        .lifeyAodNumber(metrics)
        .lineLimit(1)
        .padding(.top, LifeySpacing.xs)
      if let bpm = model.heartRateBpm {
        HStack(spacing: LifeySpacing.xs) {
          Image(systemName: LifeyAOD.symbol("heart.fill")).font(.system(size: metrics.metric * 0.6))
          Text(verbatim: "\(bpm)").lifeyMetric(metrics)
        }
        .foregroundColor(LifeyAOD.metricTint(LifeyColors.heart))
        .padding(.top, LifeySpacing.md)
      }
      Spacer(minLength: LifeySpacing.xs)
      Text(verbatim: model.setsTotal.map { "\(model.exerciseName) · \(model.setsDone ?? 0)/\($0)" } ?? model.exerciseName)
        .lifeyBody(metrics)
        .foregroundColor(LifeyAOD.numberColor)
        .lineLimit(1)
    }
    .padding(.horizontal, metrics.sideMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(LifeyColors.bg)
  }

  private var fullBody: some View {
    VStack(alignment: .leading, spacing: 0) {
      WatchHeaderChip(
        icon: "dumbbell", label: model.headerLabel, isPaused: model.isPaused,
        standaloneMark: model.showsStandaloneMark ? (model.markTapped ? .tapped : .idle) : nil,
        onMarkTap: onMarkTap)
      Text(verbatim: formatSeconds(model.elapsedSeconds))
        .lifeyHero(metrics)
        .foregroundColor(model.isPaused ? LifeyColors.text3 : LifeyColors.text)
        .lineLimit(1)
        .padding(.top, LifeySpacing.xs)
      HeartRateSlot(bpm: model.heartRateBpm)
        .padding(.top, LifeySpacing.md)
      if let calories = model.calories {
        WatchMetricReading(
          icon: "flame.fill", iconTint: LifeyColors.calories, number: "\(calories)",
          unit: String(localized: "active_calories_unit"), level: .value)
          .padding(.top, LifeySpacing.sm)
      }
      Spacer(minLength: LifeySpacing.xs)
      exerciseCard
    }
    .padding(.horizontal, metrics.sideMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  @ViewBuilder private var exerciseCard: some View {
    let card = SetSegmentBar(
      title: model.exerciseName, done: model.setsDone ?? 0, total: model.setsTotal ?? 0,
      justLoggedIndex: model.justLoggedIndex, freeFormText: model.freeFormText)
      .padding(.horizontal, 11)
      .padding(.vertical, 9)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(LifeyColors.card, in: RoundedRectangle(cornerRadius: cardRadius))
    if model.canChooseExercise {
      Button(action: onOpenExerciseList) { card }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("standalone_exercise_list_title"))
    } else {
      card
    }
  }
}

/// The live page: builds a `MetricsModel` from `WorkoutManager` every second and shows the rest hero in
/// place of the readout while a rest is running.
struct MetricsPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  /// The exercise card on this page is where the user notices they are on the wrong exercise, so it opens
  /// the picker itself (F6c §7).
  let onOpenExerciseList: () -> Void

  var body: some View {
    MinuteTimeline { date, isAOD in
      Group {
        if let remainingSeconds = restRemainingSeconds() {
          let display = workoutManager.activeExerciseDisplay
          ExercisePickerTarget(onOpenExerciseList: onOpenExerciseList) {
            RestHeroView(
              remainingSeconds: remainingSeconds,
              totalSeconds: workoutManager.restTotalSeconds,
              exerciseName: display.name,
              setsDone: display.setsDone,
              setsTotal: display.setsTotal,
              isCompact: isCompact, isAOD: isAOD)
          }
        } else {
          MetricsContent(
            model: model(now: date), isAOD: isAOD,
            onMarkTap: { workoutManager.retryAdoption() },
            onOpenExerciseList: onOpenExerciseList)
        }
      }
    }
  }

  private func model(now: Date) -> MetricsModel {
    let display = workoutManager.activeExerciseDisplay
    var freeForm: String?
    if let free = display.freeFormatSets {
      freeForm = String(format: String(localized: "active_sets_free_format"), free.count, free.totalReps)
    }
    return MetricsModel(
      headerLabel: workoutManager.activeHeaderLabel,
      showsStandaloneMark: workoutManager.showsStandaloneBadge,
      markTapped: workoutManager.isRetryingAdoption,
      isPaused: workoutManager.isPaused,
      elapsedSeconds: elapsed(now: now),
      heartRateBpm: workoutManager.heartRateBpm.map { Int($0.rounded()) },
      calories: workoutManager.activeCalories.map { Int($0.rounded()) },
      exerciseName: display.name,
      setsDone: display.setsDone,
      setsTotal: display.setsTotal,
      freeFormText: freeForm,
      canChooseExercise: workoutManager.canChooseExercise)
  }

  private func elapsed(now: Date) -> Int {
    guard let startedAt = workoutManager.startedAt else { return 0 }
    return Int(max(0, now.timeIntervalSince(startedAt)))
  }

  /// Seconds left in the current rest on this device's own monotonic clock (`restDeadlineUptime`) — nil
  /// once it counts down to zero, which drops the view out of the rest state without waiting for the phone.
  private func restRemainingSeconds() -> Int? {
    guard let restDeadlineUptime = workoutManager.restDeadlineUptime else { return nil }
    let remaining = Int((restDeadlineUptime - ProcessInfo.processInfo.systemUptime).rounded())
    return remaining > 0 ? remaining : nil
  }
}
