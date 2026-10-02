import SwiftUI
import WatchKit

/// The leftmost `TabView` page (docs/watch/
/// 43-watch-f5-set-logging-plan.md §3.1 decision (b), canvas AW 08/09/11):
/// two same-sized circular controls side by side — "+1" on the left, the
/// adjust stepper's launcher on the right (replaces the original single
/// big circle + long-press-to-adjust design: the long press went
/// undiscovered in practice, so a plain-tap-reachable second button
/// replaces it entirely — no more `LongPressGesture`). `WorkoutManager
/// .logSetState` (docs/watch/43-watch-f5-set-logging-plan.md §3.2) drives
/// the "+1" circle's four visuals — `.ready` (primary ring + context line),
/// `.pending` (ghosted + "Logging…"), `.confirmed` (check + "Set n of
/// total" + "Logged" pill), `.failed` (ghosted + red toast) — plus a
/// fifth, independent ghosted state when `WorkoutManager.isPhoneReachable`
/// is false: a tap can't even start a `.pending` round-trip with no phone
/// to answer it. The adjust button shares the same `.ready`-only enabled
/// gate (`canAdjust`), since it starts the same `logSetState` round trip
/// once confirmed.
struct LogPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  let screenWidth: CGFloat
  /// Opens `ExerciseListView` in place of the pager — the same callback
  /// `ControlsPage` gets, so both entry points land on one screen and one
  /// piece of state (`ActiveWorkoutView.showExerciseList`).
  let onOpenExerciseList: () -> Void

  /// 300 ms tap-debounce (docs/watch/43-watch-f5-set-logging-plan.md §4.2) —
  /// belt-and-braces alongside `logSet()`'s own `logSetState == .ready`
  /// guard (the primary defense, since the button also visually disables
  /// the instant state leaves `.ready`): this just also swallows a
  /// double-tap landing in the same frame, before that state change has
  /// propagated back into `.disabled(_:)`.
  @State private var lastTapAt: Date?
  private let tapDebounceSeconds: TimeInterval = 0.3

  private var buttonDiameter: CGFloat { screenWidth * DynamicSizing.logButtonPairDiameterFraction }
  /// Standalone logging is local — there is no phone to reach, and gating on
  /// reachability would disable the control in exactly the situation F6a
  /// exists for (docs/watch/44-watch-f6-standalone-plan.md §11/8). Only the
  /// phone-mastered path needs a reachable phone, since that one's tap is a
  /// round-trip.
  private var requiresPhone: Bool { !workoutManager.isStandalone }
  private var canTap: Bool {
    workoutManager.logSetState == .ready && (workoutManager.isPhoneReachable || !requiresPhone)
  }
  /// The adjust stepper is available in standalone too (its values just log
  /// locally like a plain tap does, via `WorkoutManager.beginLocalLogSet`) —
  /// gated on `canTap` alone, same as the plain tap itself.
  private var canAdjust: Bool { canTap }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      // Tightened from 10/16 to make room for the exercise-list chip below
      // without shrinking either circle — the whole stack simply rides up.
      VStack(spacing: isCompact ? 8 : 12) {
        HStack {
          HeaderChip(
            icon: "dumbbell", label: elapsedText(now: context.date), isCompact: isCompact,
            isStandalone: workoutManager.showsStandaloneBadge)
          Spacer()
        }
        Spacer(minLength: 0)
        HStack(spacing: isCompact ? 10 : 14) {
          circleContent
            .contentShape(Circle())
            .onTapGesture { handleTap() }
            .accessibilityLabel(Text("log_set_button_a11y"))
          adjustButtonContent
            .contentShape(Circle())
            .onTapGesture { handleAdjustTap() }
            .accessibilityLabel(Text("log_adjust_open_a11y"))
        }
        belowCircleContent
        // Directly under the "<exercise> · Set 2 of 2" line — that line is
        // where the user notices they've finished an exercise, so the way to
        // switch belongs next to it, not two swipes away on `ControlsPage`.
        // The two circles above ride up by the page's own spacing to make
        // room; nothing here is pinned to the dial.
        // Standalone as before, and now a phone-mastered session too once the
        // phone has pushed its exercise list (F6c §7) — but never for a
        // single-exercise list, where there is nothing to switch to.
        if workoutManager.canChooseExercise {
          ExerciseListChip(isCompact: isCompact, action: onOpenExerciseList)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, padding)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func handleTap() {
    guard canTap else { return }
    let now = Date()
    if let lastTapAt, now.timeIntervalSince(lastTapAt) < tapDebounceSeconds { return }
    lastTapAt = now
    // Nothing known to log for this exercise — no planned values, no history,
    // no earlier set this session (`WorkoutManager.hasLogSetPrefill`). A plain
    // tap would record a set with nothing in it, so open the stepper on the
    // defaults and let the user dial in the first values; every later tap for
    // this exercise then has that set to carry forward.
    guard workoutManager.hasLogSetPrefill else {
      workoutManager.beginLogAdjust()
      return
    }
    workoutManager.logSet()
  }

  private func handleAdjustTap() {
    guard canAdjust else { return }
    workoutManager.beginLogAdjust()
  }

  private func elapsedText(now: Date) -> String {
    guard let startedAt = workoutManager.startedAt else { return "00:00" }
    return formatSeconds(Int(max(0, now.timeIntervalSince(startedAt))))
  }

  private var checkmarkFont: Font { isCompact ? .system(size: 24, weight: .bold) : .system(size: 28, weight: .bold) }
  /// The "+1 set" wordmark's font — sized for the smaller of the two
  /// side-by-side buttons (was the page's single hero circle before the
  /// two-button redesign).
  private var logSetButtonFont: Font { isCompact ? .system(.callout, design: .rounded) : .system(.title3, design: .rounded) }

  @ViewBuilder
  private var circleContent: some View {
    switch workoutManager.logSetState {
    case .confirmed:
      ZStack {
        Circle()
          .fill(LifeyColors.primary.opacity(0.18))
          .overlay(Circle().strokeBorder(LifeyColors.primary, lineWidth: 3))
        VStack(spacing: 2) {
          Image(systemName: "checkmark")
            .font(checkmarkFont)
            .foregroundColor(LifeyColors.primary)
          // Mirrors ExerciseCard's own free-format-vs-n/of/total branch
          // (docs/watch/49-watch-f6b-template-sync-plan.md §3.4) — both read
          // off the same WorkoutManager.activeExerciseDisplay, so the
          // confirmed circle never disagrees with the exercise card below it.
          if let freeFormatSets = workoutManager.activeExerciseDisplay.freeFormatSets {
            Text(
              String(
                format: String(localized: "active_sets_free_format"),
                freeFormatSets.count, freeFormatSets.totalReps)
            )
            .font(isCompact ? .caption2 : .caption)
            .fontWeight(.bold)
            .foregroundColor(LifeyColors.onSurface)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          } else if let setsDone = workoutManager.activeExerciseDisplay.setsDone,
            let setsTotal = workoutManager.activeExerciseDisplay.setsTotal
          {
            Text(String(format: String(localized: "active_sets_format"), setsDone, setsTotal))
              .font(isCompact ? .caption2 : .caption)
              .fontWeight(.bold)
              .foregroundColor(LifeyColors.onSurface)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
        }
      }
      .frame(width: buttonDiameter, height: buttonDiameter)
    case .pending, .failed:
      ghostedCircle
    case .ready where requiresPhone && !workoutManager.isPhoneReachable:
      ghostedCircle
    case .ready:
      ZStack {
        Circle()
          .fill(LifeyColors.container)
          .overlay(Circle().strokeBorder(LifeyColors.primary.opacity(0.55), lineWidth: 3))
        logSetButtonLabel(color: LifeyColors.primary)
      }
      .frame(width: buttonDiameter, height: buttonDiameter)
    }
  }

  private var ghostedCircle: some View {
    ZStack {
      Circle()
        .fill(LifeyColors.surface)
        .overlay(Circle().strokeBorder(LifeyColors.outline, lineWidth: 3))
      logSetButtonLabel(color: LifeyColors.ghostedOnSurface)
    }
    .opacity(0.75)
    .frame(width: buttonDiameter, height: buttonDiameter)
  }

  /// The right-hand button that opens the adjust stepper (`AdjustPage`) —
  /// same enabled/ghosted split as `circleContent`'s `.ready`/ghosted cases,
  /// tinted `secondary` (brown) to read as the side path, matching
  /// `AdjustPage`'s own header tint.
  private var adjustButtonContent: some View {
    ZStack {
      Circle()
        .fill(LifeyColors.container)
        .overlay(
          Circle().strokeBorder(
            (canAdjust ? LifeyColors.secondary : LifeyColors.outline).opacity(canAdjust ? 0.55 : 1),
            lineWidth: 3)
        )
      VStack(spacing: 4) {
        Image(systemName: "slider.horizontal.3")
          .font(.system(size: isCompact ? 20 : 24, weight: .semibold))
        Text(String(localized: "log_adjust_title"))
          .font(isCompact ? .caption2 : .caption)
          .fontWeight(.bold)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .foregroundColor(canAdjust ? LifeyColors.secondary : LifeyColors.ghostedOnSurface)
    }
    .frame(width: buttonDiameter, height: buttonDiameter)
    .opacity(canAdjust ? 1 : 0.75)
  }

  /// `log_set_button` ("+1 set" / "+1 szett", §3.4) as a single localized
  /// wordmark — the canvas mockup renders "+1" and "SET" as two separately
  /// sized lines, but that split isn't reproducible from one localized
  /// string without parsing it apart, which is fragile across locales; one
  /// bold centered line reads just as clearly on a page this uncluttered.
  private func logSetButtonLabel(color: Color) -> some View {
    Text(String(localized: "log_set_button"))
      .font(logSetButtonFont)
      .fontWeight(.heavy)
      .multilineTextAlignment(.center)
      .lineLimit(2)
      .minimumScaleFactor(0.7)
      .foregroundColor(color)
  }

  @ViewBuilder
  private var belowCircleContent: some View {
    switch workoutManager.logSetState {
    // Not shown in standalone: the header already carries the standalone
    // badge, and repeating "phone not reachable" there would read as an
    // error during a deliberately phone-less workout (§11/8).
    case .ready where requiresPhone && !workoutManager.isPhoneReachable:
      logStatusPill(
        icon: "wifi.slash", text: String(localized: "phone_unreachable"),
        tint: LifeyColors.onSurfaceVariant, background: LifeyColors.container)
    case .ready:
      Text(contextLine)
        .font(isCompact ? .caption2 : .caption)
        .foregroundColor(LifeyColors.onSurfaceVariant)
        .lineLimit(1)
        .truncationMode(.tail)
    case .pending:
      Text("log_set_pending")
        .font(isCompact ? .caption2 : .caption)
        .foregroundColor(LifeyColors.onSurfaceVariant)
    case .confirmed:
      logStatusPill(
        icon: nil, text: String(localized: "log_set_logged"), tint: LifeyColors.primary,
        background: LifeyColors.primary.opacity(0.14))
    case .failed:
      logStatusPill(
        icon: nil, text: String(localized: "log_set_failed"), tint: LifeyColors.onErrorContainer,
        background: LifeyColors.errorContainer)
    }
  }

  private func logStatusPill(icon: String?, text: String, tint: Color, background: Color) -> some View {
    HStack(spacing: 6) {
      if let icon {
        Image(systemName: icon)
          .font(.system(size: isCompact ? 13 : 15))
          .foregroundColor(tint)
      }
      Text(text)
        .font(isCompact ? .caption2 : .caption)
        .fontWeight(.semibold)
        .foregroundColor(tint)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(background)
    .clipShape(Capsule())
  }

  /// "<exercise> · Set <n> of <total>" (`log_set_context_format`, §3.4) — the
  /// *next* set number, mirroring `RestHeroView`'s identical
  /// `min(setsDone + 1, setsTotal)` "what's coming up" arithmetic, not
  /// `setsDone` itself (which would read one set behind what a tap is about
  /// to log).
  private var contextLine: String {
    // Reuses WorkoutManager.activeExerciseDisplay for all three cases
    // (Quick strength / template / phone-mastered) — for the latter two
    // this reproduces the pre-F6b logic exactly; a template exercise with a
    // targetSets now also gets the "next set of total" preview, matching
    // the phone-mastered format it's borrowing (docs/watch/
    // 49-watch-f6b-template-sync-plan.md §3.4).
    let display = workoutManager.activeExerciseDisplay
    guard let setsDone = display.setsDone, let setsTotal = display.setsTotal else {
      return display.name
    }
    return String(
      format: String(localized: "log_set_context_format"), display.name,
      min(setsDone + 1, setsTotal), setsTotal)
  }
}
