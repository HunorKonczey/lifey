import SwiftUI
import WatchKit

// MARK: - Log page (redesign X1.5 + X1.6 — AW1.5 … AW1.9, AW1.12)

/// What the "+1" circle and the bottom slot show (docs/watch/43-watch-f5-set-logging-plan.md §3.2).
enum LogPageState: Equatable {
  case ready
  case pending
  case confirmed
  case failed
  /// Phone-driven only: the phone cannot answer, so a tap would never round-trip.
  case unreachable
}

/// Plain data behind the log page, so the gallery can render every canvas state.
struct LogModel {
  var elapsedSeconds: Int
  /// "Fekvenyomás" and " · 3/4 szett" (the second part in `text2`).
  var contextName: String
  var contextSuffix: String
  var state: LogPageState = .ready
  /// "3/4" or "3 szett" inside the success circle.
  var confirmedCounter: String = ""
  var canAdjust = true
  var canChooseExercise = false
  var showsStandaloneMark = false
  var markTapped = false
}

/// The log page: next-set line, the primary "+1" circle and the raised "Módosítás" circle, and one status
/// slot at the bottom (pill, or the "Gyakorlatok" chip when there is nothing to report).
struct LogContent: View {
  let model: LogModel
  var onLog: () -> Void = {}
  var onAdjust: () -> Void = {}
  var onMarkTap: () -> Void = {}
  var onOpenExerciseList: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  private var isGhosted: Bool { model.state == .pending || model.state == .failed || model.state == .unreachable }
  /// The label under the "+1": the localized "+1 szett" without the "+1" ("szett").
  private var logLabel: String {
    String(localized: "log_set_button").replacingOccurrences(of: "+1", with: "")
      .trimmingCharacters(in: .whitespaces)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        WatchHeaderChip(
          icon: "timer", label: formatSeconds(model.elapsedSeconds),
          standaloneMark: model.showsStandaloneMark ? (model.markTapped ? .tapped : .idle) : nil,
          onMarkTap: onMarkTap)
        Spacer(minLength: 0)
      }
      (Text(verbatim: model.contextName).foregroundColor(LifeyColors.text)
        + Text(verbatim: model.contextSuffix).foregroundColor(LifeyColors.text2))
        .lifeyBodyBold(metrics)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, LifeySpacing.xs)
      HStack(alignment: .top, spacing: 10) {
        logCircle
        CircleButton(
          style: .raised, icon: "slider.horizontal.3", label: String(localized: "log_adjust_title"),
          iconTint: LifeyColors.clay, isGhosted: isGhosted || !model.canAdjust, action: onAdjust)
      }
      .padding(.top, LifeySpacing.lg)
      Spacer(minLength: LifeySpacing.xs)
      statusSlot
    }
    .padding(.horizontal, metrics.sideMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder private var logCircle: some View {
    switch model.state {
    case .confirmed:
      CircleButton(
        style: .successTint, icon: "checkmark", centerText: model.confirmedCounter, label: logLabel,
        action: {})
    case .ready:
      CircleButton(style: .primary, centerText: "+1", label: logLabel, action: onLog)
    case .pending, .failed, .unreachable:
      CircleButton(style: .primary, centerText: "+1", label: logLabel, isGhosted: true, action: {})
    }
  }

  /// One pill at a time in the same bottom slot (priority failed › unreachable › pending › logged); the
  /// "Gyakorlatok" chip yields to it for as long as it shows.
  @ViewBuilder private var statusSlot: some View {
    switch model.state {
    case .failed: StatusPill(kind: .failed, text: String(localized: "log_set_failed"))
    case .unreachable: StatusPill(kind: .unreachable, text: String(localized: "phone_unreachable"))
    case .pending: StatusPill(kind: .pending, text: String(localized: "log_set_pending"))
    case .confirmed: StatusPill(kind: .logged, text: String(localized: "log_set_logged"))
    case .ready:
      if model.canChooseExercise {
        CompactChip(title: String(localized: "standalone_exercise_list_title"), icon: "list.bullet", action: onOpenExerciseList)
      }
    }
  }
}

/// The live log page (docs/watch/43-watch-f5-set-logging-plan.md §3.1): builds a `LogModel` from
/// `WorkoutManager` and keeps the tap rules — `canTap`, the prefill check that opens the stepper instead of
/// logging an empty set, the standalone exemption from the reachability gate. The 300 ms double-tap guard
/// now lives inside `CircleButton`.
struct LogPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  let screenWidth: CGFloat
  /// Opens `ExerciseListView` in place of the pager — the same callback `ControlsPage` gets.
  let onOpenExerciseList: () -> Void

  /// Standalone logging is local — gating on reachability would disable the control in exactly the situation
  /// F6a exists for (docs/watch/44-watch-f6-standalone-plan.md §11/8).
  private var requiresPhone: Bool { !workoutManager.isStandalone }
  private var canTap: Bool {
    workoutManager.logSetState == .ready && (workoutManager.isPhoneReachable || !requiresPhone)
  }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      LogContent(
        model: model(now: context.date),
        onLog: handleTap,
        onAdjust: handleAdjustTap,
        onMarkTap: { workoutManager.retryAdoption() },
        onOpenExerciseList: onOpenExerciseList)
    }
  }

  private func handleTap() {
    guard canTap else { return }
    // Nothing known to log for this exercise (`hasLogSetPrefill`): a plain tap would record an empty set, so
    // open the stepper on the defaults and let the user dial in the first values.
    guard workoutManager.hasLogSetPrefill else {
      workoutManager.beginLogAdjust()
      return
    }
    workoutManager.logSet()
  }

  private func handleAdjustTap() {
    guard canTap else { return }
    workoutManager.beginLogAdjust()
  }

  private func model(now: Date) -> LogModel {
    let display = workoutManager.activeExerciseDisplay
    let (name, suffix) = contextParts(display)
    var state: LogPageState
    switch workoutManager.logSetState {
    case .ready: state = (requiresPhone && !workoutManager.isPhoneReachable) ? .unreachable : .ready
    case .pending: state = .pending
    case .confirmed: state = .confirmed
    case .failed: state = .failed
    }
    var counter = ""
    if let free = display.freeFormatSets {
      counter = String(format: String(localized: "standalone_exercise_sets_done"), free.count)
    } else if let done = display.setsDone, let total = display.setsTotal {
      counter = "\(done)/\(total)"
    }
    return LogModel(
      elapsedSeconds: workoutManager.startedAt.map { Int(max(0, now.timeIntervalSince($0))) } ?? 0,
      contextName: name, contextSuffix: suffix, state: state, confirmedCounter: counter,
      canAdjust: canTap, canChooseExercise: workoutManager.canChooseExercise,
      showsStandaloneMark: workoutManager.showsStandaloneBadge, markTapped: workoutManager.isRetryingAdoption)
  }

  /// "<exercise> · Set <n> of <total>" — the *next* set number (`min(setsDone + 1, setsTotal)`), split into the
  /// name and the dim suffix.
  private func contextParts(_ display: ActiveExerciseDisplay) -> (String, String) {
    guard let setsDone = display.setsDone, let setsTotal = display.setsTotal else { return (display.name, "") }
    let full = String(
      format: String(localized: "log_set_context_format"), display.name, min(setsDone + 1, setsTotal), setsTotal)
    if full.hasPrefix(display.name) { return (display.name, String(full.dropFirst(display.name.count))) }
    return (full, "")
  }
}
