import SwiftUI

/// Below this many seconds remaining, the rest ring switches to
/// `LifeyColors.negative` (docs/40-watch-app-plan.md §12.1 B1, mirrors
/// Android's `REST_RING_NEGATIVE_THRESHOLD_MS`).
private let restRingNegativeThresholdSeconds = 5

/// Total on-screen time for the rest-end "GO" flash (§3.4: "1–2 s flash/transition"),
/// mirrors Android's `GO_FLASH_HOLD_MS`.
private let goFlashHoldSeconds: TimeInterval = 1.3


/// Live workout screen — a two-page `TabView` (docs/40-watch-app-plan.md
/// §12.1 B7, mirrors the Apple Workout app's own paging pattern and canvas
/// frames AW 02–04): the metrics page (elapsed time, heart rate, calories,
/// current exercise/set counter, rest-timer countdown) and a separate
/// controls page (Pause/Resume + End), rather than cramming the buttons
/// under the metrics on one screen. Styling (§12.1 B6) follows
/// `docs/watch/design/Lifey Watch Design.dc.html`'s Apple Watch frames
/// pixel-for-pixel where practical — colors/icons/copy match exactly; literal
/// canvas px offsets don't, since §12.1 B4 already committed this app to
/// percent-of-screen layout instead. The rest-end haptic is scheduled
/// independently in `WorkoutManager`, not here — it needs to fire even while
/// this view isn't on screen.
struct ActiveWorkoutView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  @State private var showGoFlash = false
  @State private var selectedPage = 0
  /// Mirrors `selectedPage` as a `Double` for `.digitalCrownRotation`, which
  /// needs its own continuous binding rather than the page `Int` itself —
  /// kept in sync with `selectedPage` in both directions so a crown turn and
  /// a swipe agree on where the "next" turn should land.
  @State private var crownRotation: Double = 0

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction

      ZStack {
        TabView(selection: $selectedPage) {
          MetricsPage(isCompact: isCompact, padding: padding).tag(0)
          ControlsPage(isCompact: isCompact, padding: padding).tag(1)
        }
        .tabViewStyle(.page)
        .digitalCrownRotation(
          $crownRotation, from: 0, through: 1, by: 1,
          sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crownRotation) { _, newValue in
          selectedPage = Int(newValue.rounded())
        }
        .onChange(of: selectedPage) { _, newValue in
          crownRotation = Double(newValue)
        }
        if showGoFlash {
          GoFlashView()
        }
      }
    }
    .background(LifeyColors.trueBlack)
    .task(id: workoutManager.restDeadlineUptime) {
      await runGoFlashCycle()
    }
  }

  /// Rest-end haptic moment's visual half (docs/40-watch-app-plan.md §12.1
  /// B2 / 41-watch-design-prompt.md §3.4), mirrors Android's
  /// `LaunchedEffect(metadata.restDeadlineElapsedRealtimeMs)` + `GoFlash`:
  /// waits until the deadline (this device's own monotonic clock, like
  /// `MetricsPage.restRemainingSeconds()`), then shows the flash for
  /// `goFlashHoldSeconds` before letting the view fall back to the plain
  /// metrics. `.task(id:)` cancels and restarts this whenever
  /// `restDeadlineUptime` changes, so a rest that's skipped/replaced before
  /// naturally reaching zero never flashes — the haptic itself still fires
  /// independently in `WorkoutManager`, this is purely decorative. Lives on
  /// the top-level view (not `MetricsPage`) so it still overlays both pages
  /// regardless of which one is currently swiped into view.
  private func runGoFlashCycle() async {
    guard let deadline = workoutManager.restDeadlineUptime else {
      showGoFlash = false
      return
    }
    let delaySeconds = deadline - ProcessInfo.processInfo.systemUptime
    if delaySeconds > 0 {
      try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
    }
    guard !Task.isCancelled else { return }
    showGoFlash = true
    try? await Task.sleep(nanoseconds: UInt64(goFlashHoldSeconds * 1_000_000_000))
    guard !Task.isCancelled else { return }
    showGoFlash = false
  }
}

/// The "STRENGTH"/"REST" (or, on `ControlsPage`, the elapsed time) uppercase
/// icon+label row that anchors the top of each page (canvas AW 02–04) — the
/// one bit of letter-spacing tracking the design calls for (41-watch-design-
/// prompt.md §1: "uppercase labels tracked +0.5") is applied here directly.
private struct HeaderChip: View {
  let icon: String
  let label: String
  let isCompact: Bool

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.system(size: isCompact ? 16 : 18))
        .foregroundColor(LifeyColors.primary)
      Text(label)
        .font(isCompact ? .caption2 : .caption)
        .foregroundColor(LifeyColors.primary)
        .tracking(0.5)
        .lineLimit(1)
    }
  }
}

/// One icon + number metric reading (HR or kcal, canvas AW 02) — no unit
/// suffix next to the number; the icon itself already disambiguates HR vs.
/// kcal, and dropping the unit keeps the reading compact on a small dial.
private struct MetricReading: View {
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

/// The exercise-name + set-counter card (canvas AW 02's `surface`-bg pill
/// under the metrics), including the per-set dot row (filled `primary` for
/// done sets, `containerHighest` for remaining) that the canvas frame shows
/// alongside the "Set n of total" text.
private struct ExerciseCard: View {
  let exerciseName: String
  let setsDone: Int?
  let setsTotal: Int?
  let isCompact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(exerciseName)
        .font(isCompact ? .body : .title3)
        .foregroundColor(LifeyColors.onSurface)
        .lineLimit(1)
        .truncationMode(.tail)
      if let setsDone, let setsTotal {
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

/// First `TabView` page (docs/40-watch-app-plan.md §12.1 B7, canvas AW 02):
/// elapsed/rest time, exercise/set counter, heart rate and calories — no
/// controls here, those live on `ControlsPage`.
private struct MetricsPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat

  private var heroFont: Font { isCompact ? .system(.title3, design: .rounded) : .system(.title2, design: .rounded) }
  private var captionFont: Font { isCompact ? .caption2 : .caption }
  // Shrunk from title3/title2 (overflow fix) — at title2, two 3-digit
  // readings (HR + kcal both >= 100) side by side clipped against the
  // round bezel instead of fitting on one line.
  private var metricValueFont: Font { isCompact ? .body : .title3 }
  private var metricIconSize: CGFloat { isCompact ? 14 : 18 }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(spacing: 4) {
        if let remainingSeconds = restRemainingSeconds() {
          RestHeroView(
            remainingSeconds: remainingSeconds,
            totalSeconds: workoutManager.restTotalSeconds,
            exerciseName: workoutManager.exerciseName ?? String(localized: "active_default_exercise"),
            setsDone: workoutManager.setsDone,
            setsTotal: workoutManager.setsTotal,
            isCompact: isCompact)
        } else {
          HeaderChip(icon: "dumbbell", label: String(localized: "active_header_label"), isCompact: isCompact)
          Text(elapsedText(now: context.date))
            .font(heroFont)
            .foregroundColor(LifeyColors.primary)
            .monospacedDigit()
          if workoutManager.isPaused {
            Text("active_paused_indicator")
              .font(captionFont)
              .foregroundColor(LifeyColors.negative)
          }
          HStack(spacing: isCompact ? 8 : 14) {
            if let heartRate = workoutManager.heartRateBpm {
              MetricReading(
                icon: "heart.fill", iconTint: LifeyColors.heart, value: "\(Int(heartRate.rounded()))",
                iconSize: metricIconSize, valueFont: metricValueFont)
            }
            if let calories = workoutManager.activeCalories {
              MetricReading(
                icon: "flame.fill", iconTint: LifeyColors.calories, value: "\(Int(calories.rounded()))",
                iconSize: metricIconSize, valueFont: metricValueFont)
            }
          }
          ExerciseCard(
            exerciseName: workoutManager.exerciseName ?? String(localized: "active_default_exercise"),
            setsDone: workoutManager.setsDone, setsTotal: workoutManager.setsTotal, isCompact: isCompact)
        }
      }
      .padding(.horizontal, padding)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// Second `TabView` page (docs/40-watch-app-plan.md §12.1 B7, canvas AW 04):
/// two large circular buttons — End (negative-tinted) and Pause/Resume
/// (container-tinted) — under a header chip showing the ticking elapsed
/// time instead of "STRENGTH". The End button opens `EffortSelectorView`
/// rather than closing anything itself — only *asking* the phone to close
/// the session (§8.2 decision (b)) happens once that's confirmed/skipped;
/// this button never calls `WorkoutManager.finishAndSendSummary()` directly.
private struct ControlsPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack {
        HStack {
          HeaderChip(icon: "dumbbell", label: elapsedText(now: context.date), isCompact: isCompact)
          Spacer()
        }
        Spacer()
        HStack(spacing: isCompact ? 24 : 34) {
          ControlButton(
            icon: "stop.fill",
            label: String(localized: "active_end_button"),
            iconTint: LifeyColors.negative,
            backgroundTint: LifeyColors.negative.opacity(0.18),
            labelColor: LifeyColors.onSurface,
            isCompact: isCompact
          ) {
            workoutManager.beginEffortSelection()
          }
          ControlButton(
            icon: workoutManager.isPaused ? "play.fill" : "pause.fill",
            label: String(localized: workoutManager.isPaused ? "active_resume_button" : "active_pause_button"),
            iconTint: LifeyColors.onSurface,
            backgroundTint: LifeyColors.container,
            labelColor: LifeyColors.onSurfaceVariant,
            isCompact: isCompact
          ) {
            if workoutManager.isPaused {
              workoutManager.resume()
            } else {
              workoutManager.pause()
            }
          }
        }
        Spacer()
      }
      .padding(.horizontal, padding)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func elapsedText(now: Date) -> String {
    guard let startedAt = workoutManager.startedAt else { return "00:00" }
    return formatSeconds(Int(max(0, now.timeIntervalSince(startedAt))))
  }
}

/// A large circular icon button with a label underneath (canvas AW 04's End
/// / Pause pair).
private struct ControlButton: View {
  let icon: String
  let label: String
  let iconTint: Color
  let backgroundTint: Color
  let labelColor: Color
  let isCompact: Bool
  let action: () -> Void

  private var diameter: CGFloat { isCompact ? 64 : 76 }

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        ZStack {
          Circle().fill(backgroundTint)
          Image(systemName: icon)
            .font(.system(size: isCompact ? 26 : 30))
            .foregroundColor(iconTint)
        }
        .frame(width: diameter, height: diameter)
        Text(label)
          .font(isCompact ? .caption : .body)
          .foregroundColor(labelColor)
      }
    }
    .buttonStyle(.plain)
  }
}

/// Rest-as-hero state (docs/40-watch-app-plan.md §12.1 B1 / 41-watch-design-
/// prompt.md §3.3, canvas AW 03): a drain-down progress ring takes the
/// metrics page's hero slot instead of the countdown being a small caption
/// line, with a "of <total>" target below it, a "Next · <exercise> — Set n
/// of total" line for what resumes once rest ends, and a small HR/kcal
/// reading underneath (rest doesn't mean the metrics disappear, just
/// shrink). Color shifts to `LifeyColors.negative` for the final 5 seconds,
/// matching the haptic that fires at 0 (`WorkoutManager`'s independently-
/// scheduled vibration).
private struct RestHeroView: View {
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
      HeaderChip(icon: "timer", label: String(localized: "rest_hero_label"), isCompact: isCompact)
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
private struct GoFlashView: View {
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

private func formatSeconds(_ totalSeconds: Int) -> String {
  String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
}

#Preview {
  ActiveWorkoutView()
}
