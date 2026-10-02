import SwiftUI
import WatchKit

// MARK: - Exercise picker (redesign X1.11 — AW1.19)

/// One row of the picker as plain data.
struct ExerciseRowModel: Identifiable {
  let id: Int
  var name: String
  var setsDone: Int
  /// `nil` = free format: "n szett" instead of a bar.
  var setsTotal: Int?
  var isCurrent: Bool
}

/// The "which exercise am I logging against" list (docs/watch/49-watch-f6b-template-sync-plan.md §3.5,
/// D-F6b.8). A scrolling list of rows, each with the exercise name (two lines) and a `SetSegmentBar`; the
/// selected one is `control` + a check. The back button is the watchOS 10 navigation bar's own (32 pt
/// visible, 44 pt target), not an 8 pt arrow. The crown scrolls.
struct ExerciseListContent: View {
  let rows: [ExerciseRowModel]
  var onSelect: (Int) -> Void = { _ in }
  var onBack: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: LifeySpacing.sm) {
          Text("standalone_exercise_list_title")
            .lifeyTitle(metrics)
            .foregroundColor(LifeyColors.text)
          ForEach(rows) { row in
            Button { onSelect(row.id) } label: { rowView(row) }
              .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, metrics.sideMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(action: onBack) { Image(systemName: "chevron.left") }
            .accessibilityLabel(Text("effort_selector_back"))
        }
      }
    }
  }

  private func rowView(_ row: ExerciseRowModel) -> some View {
    HStack(alignment: .top, spacing: LifeySpacing.sm) {
      Group {
        if let total = row.setsTotal {
          SetSegmentBar(title: row.name, done: row.setsDone, total: total)
        } else {
          SetSegmentBar(
            title: row.name, done: 0, total: 0,
            freeFormText: String(format: String(localized: "standalone_exercise_sets_done"), row.setsDone))
        }
      }
      if row.isCurrent {
        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(LifeyColors.text)
      }
    }
    .padding(.horizontal, LifeySpacing.lg)
    .padding(.vertical, LifeySpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(row.isCurrent ? LifeyColors.control : LifeyColors.card, in: RoundedRectangle(cornerRadius: LifeyShapes.card))
    .contentShape(RoundedRectangle(cornerRadius: LifeyShapes.card))
  }
}

/// The live picker. Tapping a row **jumps** straight to that exercise (no confirmation — fully reversible);
/// already-logged sets keep the `exerciseIndex` they were logged with, selecting only changes what the next
/// tap counts against.
struct ExerciseListView: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  let onBack: () -> Void

  var body: some View {
    ExerciseListContent(
      rows: rows,
      onSelect: { index in
        workoutManager.selectExercise(at: index)
        onBack()
      },
      onBack: onBack)
  }

  /// The phone's live session plan when it has pushed one, the cached template otherwise (F6c). Enumerated
  /// *before* filtering, so a row keeps the position its logged sets are attributed by; the template fallback
  /// only hides an entry the phone removed, it never renumbers.
  private var rows: [ExerciseRowModel] {
    Array(workoutManager.activePlanExercises.enumerated())
      .filter { !workoutManager.standaloneExerciseIsRemoved($0.offset) }
      .map { index, exercise in
        ExerciseRowModel(
          id: index, name: exercise.name,
          // `standaloneSetsDone(at:)`, not a count of this watch's own set list: the phone logs into the same
          // session too, and only that row holds both halves.
          setsDone: workoutManager.standaloneSetsDone(at: index), setsTotal: exercise.targetSets,
          isCurrent: exercise.exerciseId == workoutManager.currentExerciseId)
      }
  }
}
