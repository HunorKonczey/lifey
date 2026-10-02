import SwiftUI
import WatchKit

/// Total on-screen time for the rest-end "GO" flash (§3.4: "1–2 s flash/transition"),
/// mirrors Android's `GO_FLASH_HOLD_MS`.
let goFlashHoldSeconds: TimeInterval = 1.3

/// Live workout screen — a three-page `TabView` (docs/40-watch-app-plan.md
/// §12.1 B7, mirrors the Apple Workout app's own paging pattern and canvas
/// frames AW 02–04, extended by AW 08/09/11 — docs/watch/
/// 43-watch-f5-set-logging-plan.md §3.1 decision (b)): the log-set page
/// (leftmost — one swipe/crown-turn from the default), the metrics page
/// (default — elapsed time, heart rate, calories, current exercise/set
/// counter, rest-timer countdown), and a separate controls page
/// (Pause/Resume + End) — deliberately three single-purpose pages rather
/// than cramming buttons under the metrics on one screen. Styling (§12.1 B6)
/// follows `docs/watch/design/Lifey Watch Design.dc.html`'s Apple Watch
/// frames pixel-for-pixel where practical — colors/icons/copy match exactly;
/// literal canvas px offsets don't, since §12.1 B4 already committed this
/// app to percent-of-screen layout instead. The rest-end haptic is scheduled
/// independently in `WorkoutManager`, not here — it needs to fire even while
/// this view isn't on screen.
struct ActiveWorkoutView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  @State private var showGoFlash = false
  /// Starts on the metrics page (tag 1) — the calorie/HR/exercise readout is
  /// what a glance should land on; the log-set page is one swipe away.
  @State private var selectedPage = 1
  /// Whether `ExerciseListView` is showing instead of the pager (docs/watch/
  /// 49-watch-f6b-template-sync-plan.md §3.5, D-F6b.8) — opened from
  /// the "Gyakorlatok" chip on either the log or the controls page, only ever
  /// true during a template-backed standalone session.
  @State private var showExerciseList = false

  var body: some View {
    // A cardio session gets its own, much simpler pager (docs/cardio/
    // 55-cardio-watch-plan.md §4.2, C5.5) — no `LogPage`/`AdjustPage`/
    // `ExerciseListView` swap, none of which mean anything without sets to
    // log or an exercise plan to pick from. `ControlsPage` alone is reused
    // as-is: `canChooseExercise` already evaluates `false` for a cardio
    // session (`activePlanExercises` is empty, `isStandalone` is false),
    // so its "Gyakorlatok" chip already stays hidden without any change
    // there — only `HeaderChip`'s own cardio-awareness (above) was needed
    // to make it look right.
    if workoutManager.isCardio {
      CardioActiveContent()
    } else {
      strengthContent
    }
  }

  private var strengthContent: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction

      ZStack {
        // The adjust stepper *replaces* the pager rather than layering over
        // it (docs/watch/48-watch-f5b-set-adjust-plan.md §3.1): both want the
        // digital crown, and swapping the view means only one
        // `.digitalCrownRotation` binding exists at a time — no focus fight.
        // `selectedPage` is @State, so the pager comes back exactly where it
        // was left.
        if let adjust = workoutManager.logAdjustState {
          AdjustPage(state: adjust, isCompact: isCompact, padding: padding)
        } else if showExerciseList {
          ExerciseListView(
            isCompact: isCompact, padding: padding, onBack: { showExerciseList = false })
        } else {
          TabView(selection: $selectedPage) {
            LogPage(
              isCompact: isCompact, padding: padding, screenWidth: geometry.size.width,
              onOpenExerciseList: { showExerciseList = true }
            ).tag(0)
            MetricsPage(
              isCompact: isCompact, padding: padding,
              onOpenExerciseList: { showExerciseList = true }
            ).tag(1)
            ControlsPage(
              isCompact: isCompact, padding: padding, onOpenExerciseList: { showExerciseList = true }
            ).tag(2)
          }
          .tabViewStyle(.page)
          // The crown does not page (D-X0.9): no accidental paging with a sweaty hand. Every active page
          // fits without scrolling, so the crown only steps values (stepper, effort) and scrolls lists.
        }
        if showGoFlash {
          GoFlash()
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

/// Weight display for the adjust stepper (docs/watch/48-watch-f5b-set-adjust-plan.md
/// §5): whole numbers stay whole ("60"), anything else gets a single decimal
/// ("62,5"), and the decimal separator follows the device locale. Kept in one
/// place rather than formatted inline at each call site, and behind a cached
/// formatter since view bodies re-render often.
let weightFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  formatter.minimumFractionDigits = 0
  formatter.maximumFractionDigits = 1
  return formatter
}()

func formatWeight(_ weight: Double) -> String {
  weightFormatter.string(from: NSNumber(value: weight)) ?? "\(Int(weight))"
}

/// mm:ss — the **rest timer's** format, and only that: a cardio duration goes
/// through `formatCardioDuration` instead, which rolls over into hours (a
/// 90-minute walk reading "90:00" is exactly what that split avoids).
func formatSeconds(_ totalSeconds: Int) -> String {
  String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
}

#Preview {
  ActiveWorkoutView()
}
