import SwiftUI
import WatchKit

/// Third/last `TabView` page (docs/40-watch-app-plan.md §12.1 B7, canvas AW 04):
/// two large circular buttons — End (negative-tinted) and Pause/Resume
/// (container-tinted) — under a header chip showing the ticking elapsed
/// time instead of "STRENGTH". The End button opens `EffortSelectorView`
/// rather than closing anything itself — only *asking* the phone to close
/// the session (§8.2 decision (b)) happens once that's confirmed/skipped;
/// this button never calls `WorkoutManager.finishAndSendSummary()` directly.
struct ControlsPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  /// Opens `ExerciseListView` in place of the pager (docs/watch/
  /// 49-watch-f6b-template-sync-plan.md §3.5, D-F6b.8) — only ever called
  /// from the chip below, which itself only shows during a template-backed
  /// standalone session.
  let onOpenExerciseList: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack {
        HStack {
          HeaderChip(
            icon: "dumbbell", label: elapsedText(now: context.date), isCompact: isCompact,
            isStandalone: workoutManager.showsStandaloneBadge)
          Spacer()
        }
        Spacer()
        // Tightened from 24/34 — that far apart, End and Pause read as two
        // unrelated buttons instead of one action pair (user report).
        HStack(spacing: isCompact ? 12 : 18) {
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
        // Only during a template-backed session (docs/watch/
        // 49-watch-f6b-template-sync-plan.md §3.5) — quick-strength and
        // phone-mastered sessions have nothing to switch between.
        // Standalone as before, and now a phone-mastered session too once the
        // phone has pushed its exercise list (F6c §7) — but never for a
        // single-exercise list, where there is nothing to switch to.
        if workoutManager.canChooseExercise {
          ExerciseListChip(isCompact: isCompact, action: onOpenExerciseList)
            .padding(.top, 10)
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

/// The "Gyakorlatok" chip that opens `ExerciseListView` (docs/watch/
/// 49-watch-f6b-template-sync-plan.md §3.5, D-F6b.8). Shown on both
/// `ControlsPage` and `LogPage` — the log page is where the user actually
/// notices they're on the wrong exercise ("Set 2 of 2" sits right above it),
/// so making them swipe two pages to fix it was the wrong place to hide it.
/// One view rather than two copies, so the two pages can't drift apart.
/// Only ever rendered during a template-backed standalone session; a
/// quick-strength or phone-mastered one has nothing to switch between.
struct ExerciseListChip: View {
  let isCompact: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: "list.bullet")
          .font(.system(size: isCompact ? 12 : 14))
        Text("standalone_exercise_list_title")
          .font(isCompact ? .caption2 : .caption)
          .fontWeight(.semibold)
          .lineLimit(1)
      }
      .foregroundColor(LifeyColors.onSurfaceVariant)
      .padding(.horizontal, 14)
      .padding(.vertical, 6)
    }
    .buttonStyle(.plain)
    .background(LifeyColors.container)
    .clipShape(Capsule())
  }
}

/// A large circular icon button with a label underneath (canvas AW 04's End
/// / Pause pair).
struct ControlButton: View {
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
