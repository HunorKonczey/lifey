import SwiftUI
import WatchKit

// MARK: - Controls page (redesign X1.10 — AW1.17, AW1.18)

/// Plain data behind the controls page.
struct ControlsModel {
  /// The header icon and accent follow the activity on a cardio session ("dumbbell", `nil` accent = text2).
  var headerIcon = "dumbbell"
  var headerAccent: Color? = nil
  var elapsedText: String
  var isPaused = false
  var canChooseExercise = false
  var showsStandaloneMark = false
  var markTapped = false
}

/// Two 78 pt circles side by side: "Vége" (error tint, `stop.fill`) and "Szünet" (control, `pause.fill`).
/// Paused: "Folytatás" becomes the **primary** circle (`play.fill`), the header chip turns clay, and the
/// "Gyakorlatok" compact chip sits at the bottom when there is more than one exercise. Cardio reuses the
/// page with the activity icon in the header.
struct ControlsContent: View {
  let model: ControlsModel
  var onEnd: () -> Void = {}
  var onPauseResume: () -> Void = {}
  var onMarkTap: () -> Void = {}
  var onOpenExerciseList: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        WatchHeaderChip(
          icon: model.headerIcon, label: model.elapsedText, accent: model.headerAccent, isPaused: model.isPaused,
          standaloneMark: model.showsStandaloneMark ? (model.markTapped ? .tapped : .idle) : nil,
          onMarkTap: onMarkTap)
        Spacer(minLength: 0)
      }
      Spacer(minLength: LifeySpacing.xs)
      HStack(alignment: .top, spacing: 10) {
        CircleButton(
          style: .errorTint, icon: "stop.fill", label: String(localized: "active_end_button"), action: onEnd)
        if model.isPaused {
          CircleButton(
            style: .primary, icon: "play.fill", label: String(localized: "active_resume_button"),
            action: onPauseResume)
        } else {
          CircleButton(
            style: .control, icon: "pause.fill", label: String(localized: "active_pause_button"),
            action: onPauseResume)
        }
      }
      Spacer(minLength: LifeySpacing.xs)
      if model.canChooseExercise {
        CompactChip(title: String(localized: "standalone_exercise_list_title"), icon: "list.bullet", action: onOpenExerciseList)
      }
    }
    .padding(.horizontal, metrics.sideMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// The live controls page. The End button opens the effort selector; only *asking* the phone to close the
/// session happens once that is confirmed or skipped (§8.2 decision (b)) — this never calls
/// `finishAndSendSummary()` itself.
struct ControlsPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  /// Opens `ExerciseListView` in place of the pager — only shown when there is something to switch to.
  let onOpenExerciseList: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      ControlsContent(
        model: model(now: context.date),
        onEnd: { workoutManager.beginEffortSelection() },
        onPauseResume: {
          if workoutManager.isPaused { workoutManager.resume() } else { workoutManager.pause() }
        },
        onMarkTap: { workoutManager.retryAdoption() },
        onOpenExerciseList: onOpenExerciseList)
    }
  }

  private func model(now: Date) -> ControlsModel {
    var icon = "dumbbell"
    var accent: Color? = nil
    if workoutManager.isCardio, let type = workoutManager.cardioActivityType {
      icon = cardioActivityIcon(for: type)
      accent = cardioActivityTint(for: type)
    }
    let elapsed = workoutManager.startedAt.map { Int(max(0, now.timeIntervalSince($0))) } ?? 0
    return ControlsModel(
      headerIcon: icon, headerAccent: accent, elapsedText: formatSeconds(elapsed),
      isPaused: workoutManager.isPaused, canChooseExercise: workoutManager.canChooseExercise,
      showsStandaloneMark: workoutManager.showsStandaloneBadge, markTapped: workoutManager.isRetryingAdoption)
  }
}
