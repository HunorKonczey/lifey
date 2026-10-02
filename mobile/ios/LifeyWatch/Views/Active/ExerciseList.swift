import SwiftUI
import WatchKit

/// The "which exercise am I logging against" picker (docs/watch/
/// 49-watch-f6b-template-sync-plan.md §3.5, D-F6b.8) — opened from
/// `ExerciseListChip`, on either `LogPage` or `ControlsPage`; only ever
/// shown during a template-backed standalone session. Replaces the pager the same way
/// `AdjustPage` does (see `ActiveWorkoutView.body`), not a sheet/modal —
/// this app has no other modal presentation, and the pager coming right
/// back underneath once this closes matches `AdjustPage`'s own precedent.
/// Visually the exact shape `StandalonePickerView`'s rows already
/// established (T4) — a scrolling list of `surface`-background cards, the
/// selected one highlighted `containerHigh` — not a new component language.
///
/// Tapping a row **jumps** straight to that exercise, not a "Next" stepper
/// (D-F6b.8's own reasoning: a one-way Next either silently wraps back to
/// exercise 1, logging wrong data, or dead-ends at the last exercise with
/// no way back). No confirmation: this is fully reversible — a mis-tap
/// costs one more tap to undo, not a lost set. Already-logged sets keep
/// whatever `exerciseIndex` they were logged with, permanently; selecting
/// here only changes what the *next* tap counts against.
struct ExerciseListView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  let onBack: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
        HStack(spacing: 6) {
          Button(action: onBack) {
            Image(systemName: "chevron.left")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(LifeyColors.onSurfaceVariant)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(Text("effort_selector_back"))
          Text("standalone_exercise_list_title")
            .font(isCompact ? .title3 : .title2)
            .fontWeight(.heavy)
            .foregroundColor(LifeyColors.onSurface)
          Spacer(minLength: 0)
        }
        // The phone's live session plan when it has pushed one, the cached
        // template otherwise (F6c) — `activePlanExercises` is the same list
        // every other "which exercise" decision reads, so what's on screen and
        // what a tap logs into can't drift apart.
        do {
          // Enumerated *before* filtering, so a row keeps the position the
          // logged sets are attributed by — in the template fallback this list
          // only ever hides an entry the phone removed from the session, it
          // never renumbers (see `WorkoutManager.removedExerciseIndexes`); a
          // session plan has nothing to hide, it simply lacks removed ones.
          ForEach(
            Array(workoutManager.activePlanExercises.enumerated())
              .filter { !workoutManager.standaloneExerciseIsRemoved($0.offset) },
            id: \.offset
          ) { index, exercise in
            ExerciseListRow(
              exercise: exercise, isCompact: isCompact,
              isCurrent: exercise.exerciseId == workoutManager.currentExerciseId,
              // `standaloneSetsDone(at:)`, not a count of this watch's own set
              // list: a watch-started workout is logged into from the phone
              // too, and only the phone's row holds both halves. Counting
              // locally showed a lower number here than the phone had — and a
              // different number than the active page, which already reconciles
              // the two.
              setsDone: workoutManager.standaloneSetsDone(at: index)
            ) {
              workoutManager.selectExercise(at: index)
              onBack()
            }
          }
        }
      }
      .padding(.horizontal, padding)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// One exercise row (canvas-less — see `ExerciseListView`'s doc comment for
/// why this reuses `StandalonePickerView`'s `TemplateRow` visual language
/// rather than inventing a new one).
struct ExerciseListRow: View {
  let exercise: CachedTemplateExercise
  let isCompact: Bool
  let isCurrent: Bool
  let setsDone: Int
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 1) {
        Text(exercise.name)
          .font(.body)
          .fontWeight(.bold)
          .foregroundColor(LifeyColors.onSurface)
          .lineLimit(1)
          .truncationMode(.tail)
        if let targetSets = exercise.targetSets {
          Text(String(format: String(localized: "active_sets_format"), setsDone, targetSets))
            .font(.caption2)
            .foregroundColor(LifeyColors.onSurfaceVariant)
        } else {
          Text(String(format: String(localized: "standalone_exercise_sets_done"), setsDone))
            .font(.caption2)
            .foregroundColor(LifeyColors.onSurfaceVariant)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
    .buttonStyle(.plain)
    .background(isCurrent ? LifeyColors.containerHigh : LifeyColors.surface)
    .clipShape(RoundedRectangle(cornerRadius: LifeyShapes.card))
  }
}
