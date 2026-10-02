import SwiftUI
import WatchKit

/// The "STRENGTH"/"REST" (or, on `ControlsPage`, the elapsed time) uppercase
/// icon+label row that anchors the top of each page (canvas AW 02–04) — the
/// one bit of letter-spacing tracking the design calls for (41-watch-design-
/// prompt.md §1: "uppercase labels tracked +0.5") is applied here directly.
///
/// **Cardio-aware** (docs/cardio/55-cardio-watch-plan.md §4.2, C5.5): the
/// passed-in [icon] and the primary tint both give way to the activity's own
/// icon/accent whenever `workoutManager.isCardio` — "a domináns szám az
/// aktivitás akcentjét viseli... nem a primaryt" applies to the whole header
/// row, not just `CardioMetricsPage`'s own big number, so `ControlsPage`
/// (the only other page a cardio session's `TabView` has, see
/// `CardioActiveContent`) shows the right icon/color too instead of a
/// STRENGTH-flavored dumbbell mid-run. `.textCase(.uppercase)` is new here
/// too — safe for every existing caller (an already-uppercase
/// `active_header_label`, or a numeric elapsed-time string neither case
/// affects) and what turns the phone's sentence-case `title` ("Futás") into
/// the design's uppercase header treatment without a second, watch-only
/// activity-name string table.
struct HeaderChip: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let icon: String
  let label: String
  let isCompact: Bool
  /// Standalone mode indicator (docs/watch/44-watch-f6-standalone-plan.md
  /// §3.4, design canvas AW 14/W 13) — a quiet glyph, no chip/background/
  /// copy of its own ("mode, not alarm"), so every page's header carries it
  /// consistently rather than singling out the metrics page's "STRENGTH"
  /// label alone.
  let isStandalone: Bool

  private var effectiveIcon: String {
    guard workoutManager.isCardio, let activityType = workoutManager.cardioActivityType else { return icon }
    return cardioActivityIcon(for: activityType)
  }
  private var effectiveTint: Color {
    guard workoutManager.isCardio, let activityType = workoutManager.cardioActivityType else {
      return LifeyColors.primary
    }
    return cardioActivityTint(for: activityType)
  }

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: effectiveIcon)
        .font(.system(size: isCompact ? 16 : 18))
        .foregroundColor(effectiveTint)
      Text(label)
        .font(isCompact ? .caption2 : .caption)
        .foregroundColor(effectiveTint)
        .tracking(0.5)
        .textCase(.uppercase)
        .lineLimit(1)
      if isStandalone {
        // The badge doubles as a "sync with my phone now" button — the state
        // it reports (this workout has no phone behind it) is exactly the one
        // the user wants to act on, so making them hunt for a separate
        // control would be busywork. Most useful when the phone app simply
        // wasn't running at start: one tap sends the whole snapshot,
        // already-logged sets included, and the phone opens the workout.
        // Tap target padded out to something findable on a wrist — the glyph
        // itself is ~16pt.
        // A cardio session's badge does the same thing, and means the same
        // thing: the phone joins the walk/run live (its own
        // `CardioSessionScreen`, GPS and all) instead of only importing it
        // once it ends.
        Image(systemName: workoutManager.isRetryingAdoption ? "arrow.triangle.2.circlepath" : "iphone.slash")
          .font(.system(size: isCompact ? 14 : 16))
          .foregroundColor(LifeyColors.standaloneIndicator)
          .padding(.vertical, 6)
          .padding(.horizontal, 4)
          .contentShape(Rectangle())
          .onTapGesture { workoutManager.retryAdoption() }
          .accessibilityLabel(Text("standalone_sync_retry_a11y"))
      }
    }
  }
}

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
  var onMarkTap: () -> Void = {}
  var onOpenExerciseList: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  /// The card's corner radius follows the display margin (nested rule): 22 − 6 = 16, compact 22 − 8 = 14.
  private var cardRadius: CGFloat { LifeyShapes.nested(parent: LifeyShapes.card, padding: metrics.isCompact ? 8 : 6) }

  var body: some View {
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
    TimelineView(.periodic(from: .now, by: 1)) { context in
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
              isCompact: isCompact)
          }
          .padding(.horizontal, padding)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
          MetricsContent(
            model: model(now: context.date),
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
