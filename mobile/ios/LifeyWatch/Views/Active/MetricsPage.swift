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

/// One icon + number metric reading (HR or kcal, canvas AW 02) — no unit
/// suffix next to the number; the icon itself already disambiguates HR vs.
/// kcal, and dropping the unit keeps the reading compact on a small dial.
/// Used for the compact row under [RestHeroView]'s ring, not the main
/// metrics-page hero readings (see [HeroMetricRow] for those).
struct MetricReading: View {
  let icon: String
  let iconTint: Color
  let value: String
  let iconSize: CGFloat
  let valueFont: Font

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.system(size: iconSize))
        .foregroundColor(iconTint)
      Text(value)
        .font(valueFont)
        .foregroundColor(LifeyColors.onSurface)
        .monospacedDigit()
        .lineLimit(1)
    }
  }
}

/// A full-width, stacked icon + value + unit row for [MetricsPage]'s primary
/// HR/kcal readings (canvas AW 02) — one reading per row rather than
/// squeezed side by side, with its unit label back (a row this size has
/// plenty of width for it, unlike [RestHeroView]'s compact under-ring
/// variant).
struct HeroMetricRow: View {
  let icon: String
  let iconTint: Color
  let value: String
  let unit: String
  let isCompact: Bool

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: isCompact ? 20 : 24))
        .foregroundColor(iconTint)
      Text(value)
        .font(isCompact ? .title3 : .title2)
        .fontWeight(.bold)
        .foregroundColor(LifeyColors.onSurface)
        .monospacedDigit()
        .lineLimit(1)
      Text(unit)
        .font(isCompact ? .caption2 : .caption)
        .foregroundColor(LifeyColors.onSurfaceVariant)
        .textCase(.uppercase)
    }
  }
}

/// The exercise-name + set-counter card (canvas AW 02's `surface`-bg pill
/// under the metrics), including the per-set dot row (filled `primary` for
/// done sets, `containerHighest` for remaining) that the canvas frame shows
/// alongside the "Set n of total" text.
struct ExerciseCard: View {
  let exerciseName: String
  let setsDone: Int?
  let setsTotal: Int?
  let isCompact: Bool
  /// Standalone's set-count line (docs/watch/44-watch-f6-standalone-plan.md
  /// §3.4, D-F6.3) — no plan, so no dot row or "n of total"; just how many
  /// sets and their combined reps. Nil for phone-mastered sessions, which
  /// use `setsDone`/`setsTotal` instead.
  var freeFormatSets: (count: Int, totalReps: Int)? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(exerciseName)
        .font(isCompact ? .body : .title3)
        .foregroundColor(LifeyColors.onSurface)
        .lineLimit(1)
        .truncationMode(.tail)
      if let freeFormatSets {
        Text(
          String(
            format: String(localized: "active_sets_free_format"), freeFormatSets.count,
            freeFormatSets.totalReps)
        )
        .font(isCompact ? .caption2 : .caption)
        .foregroundColor(LifeyColors.onSurfaceVariant)
      } else if let setsDone, let setsTotal {
        HStack {
          Text(String(format: String(localized: "active_sets_format"), setsDone, setsTotal))
            .font(isCompact ? .caption2 : .caption)
            .foregroundColor(LifeyColors.onSurfaceVariant)
          Spacer()
          HStack(spacing: 6) {
            ForEach(0..<setsTotal, id: \.self) { index in
              Circle()
                .fill(index < setsDone ? LifeyColors.primary : LifeyColors.containerHighest)
                .frame(width: 6, height: 6)
            }
          }
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(maxWidth: .infinity)
    .background(LifeyColors.surface)
    .clipShape(RoundedRectangle(cornerRadius: LifeyShapes.cardLarge))
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

struct MetricsPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  /// The exercise name + set counter on this page is where the user notices
  /// they're on the wrong exercise, so it opens the picker itself — the chip
  /// on the log/controls pages is two swipes away from here (F6c §7).
  let onOpenExerciseList: () -> Void

  private var heroFont: Font { isCompact ? .system(.title3, design: .rounded) : .system(.title2, design: .rounded) }
  private var captionFont: Font { isCompact ? .caption2 : .caption }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      Group {
        if let remainingSeconds = restRemainingSeconds() {
          VStack(spacing: 4) {
            // Same activeExerciseDisplay as the other pages — the "Next"
            // line now names the current template exercise (not a generic
            // fallback) and gets a real set count when it has a targetSets
            // (docs/watch/49-watch-f6b-template-sync-plan.md §3.4).
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
          }
        } else {
          // Left-aligned column (canvas AW 02) rather than centered — a
          // `Spacer()` between the readings and the exercise card lets the
          // card settle near the bottom instead of everything bunching in
          // the middle.
          VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
            HeaderChip(
              icon: "dumbbell", label: workoutManager.activeHeaderLabel, isCompact: isCompact,
              isStandalone: workoutManager.showsStandaloneBadge)
            Text(elapsedText(now: context.date))
              .font(heroFont)
              .fontWeight(.bold)
              .foregroundColor(LifeyColors.primary)
              .monospacedDigit()
            if workoutManager.isPaused {
              Text("active_paused_indicator")
                .font(captionFont)
                .foregroundColor(LifeyColors.negative)
            }
            VStack(alignment: .leading, spacing: isCompact ? 4 : 8) {
              if let heartRate = workoutManager.heartRateBpm {
                HeroMetricRow(
                  icon: "heart", iconTint: LifeyColors.heart, value: "\(Int(heartRate.rounded()))",
                  unit: String(localized: "active_heart_rate_unit"), isCompact: isCompact)
              }
              if let calories = workoutManager.activeCalories {
                HeroMetricRow(
                  icon: "flame.fill", iconTint: LifeyColors.calories, value: "\(Int(calories.rounded()))",
                  unit: String(localized: "active_calories_unit"), isCompact: isCompact)
              }
            }
            .padding(.top, 4)
            Spacer(minLength: 4)
            // One call site for all three cases (Quick strength / template /
            // phone-mastered) — see WorkoutManager.activeExerciseDisplay's
            // doc comment (docs/watch/49-watch-f6b-template-sync-plan.md §3.4).
            let display = workoutManager.activeExerciseDisplay
            ExercisePickerTarget(onOpenExerciseList: onOpenExerciseList) {
              ExerciseCard(
                exerciseName: display.name, setsDone: display.setsDone, setsTotal: display.setsTotal,
                isCompact: isCompact, freeFormatSets: display.freeFormatSets)
            }
          }
        }
      }
      .padding(.horizontal, padding)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }

  private func elapsedText(now: Date) -> String {
    guard let startedAt = workoutManager.startedAt else { return "00:00" }
    return formatSeconds(Int(max(0, now.timeIntervalSince(startedAt))))
  }

  /// Seconds left in the current rest, computed against this device's own
  /// monotonic clock (`workoutManager.restDeadlineUptime` — see its doc
  /// comment) — nil once it naturally counts down to zero, which is what
  /// drops this view out of the rest-hero state without waiting for the
  /// next phone sync (mirrors Android's `resting = restRemainingMs > 0`).
  private func restRemainingSeconds() -> Int? {
    guard let restDeadlineUptime = workoutManager.restDeadlineUptime else { return nil }
    let remaining = Int((restDeadlineUptime - ProcessInfo.processInfo.systemUptime).rounded())
    return remaining > 0 ? remaining : nil
  }
}
