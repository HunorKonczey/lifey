import SwiftUI

/// Below this many seconds remaining, the rest ring switches to
/// `LifeyColors.negative` (docs/40-watch-app-plan.md §12.1 B1, mirrors
/// Android's `REST_RING_NEGATIVE_THRESHOLD_MS`).
private let restRingNegativeThresholdSeconds = 5

/// Total on-screen time for the rest-end "GO" flash (§3.4: "1–2 s flash/transition"),
/// mirrors Android's `GO_FLASH_HOLD_MS`.
private let goFlashHoldSeconds: TimeInterval = 1.3


/// Live workout screen — a three-page `TabView` (docs/40-watch-app-plan.md
/// §12.1 B7, mirrors the Apple Workout app's own paging pattern and canvas
/// frames AW 02–04, extended by AW 08/09/11 — docs/watch/
/// 43-watch-f5-set-logging-plan.md §3.1 decision (b)): the log-set page
/// (leftmost/default — a wrist-raise mid-set lands directly on it), the
/// metrics page (elapsed time, heart rate, calories, current exercise/set
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
        // The adjust stepper *replaces* the pager rather than layering over
        // it (docs/watch/48-watch-f5b-set-adjust-plan.md §3.1): both want the
        // digital crown, and swapping the view means only one
        // `.digitalCrownRotation` binding exists at a time — no focus fight.
        // `selectedPage` is @State, so the pager comes back on the log page
        // exactly where it was left.
        if let adjust = workoutManager.logAdjustState {
          AdjustPage(state: adjust, isCompact: isCompact, padding: padding)
        } else {
          TabView(selection: $selectedPage) {
            LogPage(isCompact: isCompact, padding: padding, screenWidth: geometry.size.width).tag(0)
            MetricsPage(isCompact: isCompact, padding: padding).tag(1)
            ControlsPage(isCompact: isCompact, padding: padding).tag(2)
          }
          .tabViewStyle(.page)
          .digitalCrownRotation(
            $crownRotation, from: 0, through: 2, by: 1,
            sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
          .onChange(of: crownRotation) { _, newValue in
            selectedPage = Int(newValue.rounded())
          }
          .onChange(of: selectedPage) { _, newValue in
            crownRotation = Double(newValue)
          }
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
  /// Standalone mode indicator (docs/watch/44-watch-f6-standalone-plan.md
  /// §3.4, design canvas AW 14/W 13) — a quiet glyph, no chip/background/
  /// copy of its own ("mode, not alarm"), so every page's header carries it
  /// consistently rather than singling out the metrics page's "STRENGTH"
  /// label alone.
  let isStandalone: Bool

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
      if isStandalone {
        Image(systemName: "iphone.slash")
          .font(.system(size: isCompact ? 14 : 16))
          .foregroundColor(LifeyColors.standaloneIndicator)
          .accessibilityLabel(Text("standalone_badge"))
      }
    }
  }
}

/// One icon + number metric reading (HR or kcal, canvas AW 02) — no unit
/// suffix next to the number; the icon itself already disambiguates HR vs.
/// kcal, and dropping the unit keeps the reading compact on a small dial.
/// Used for the compact row under [RestHeroView]'s ring, not the main
/// metrics-page hero readings (see [HeroMetricRow] for those).
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

/// A full-width, stacked icon + value + unit row for [MetricsPage]'s primary
/// HR/kcal readings (canvas AW 02) — one reading per row rather than
/// squeezed side by side, with its unit label back (a row this size has
/// plenty of width for it, unlike [RestHeroView]'s compact under-ring
/// variant).
private struct HeroMetricRow: View {
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
private struct ExerciseCard: View {
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

/// The leftmost/default `TabView` page (docs/watch/
/// 43-watch-f5-set-logging-plan.md §3.1 decision (b), canvas AW 08/09/11): a
/// single large circular "+1 SET" control that fills nearly the whole safe
/// area — a dedicated page turns the entire tap target into one ~5×-minimum
/// circle, with zero mis-tap risk near End/Pause (that's why `MetricsPage`
/// stays deliberately button-free, §12.1 B4/B6 heritage). `WorkoutManager
/// .logSetState` (docs/watch/43-watch-f5-set-logging-plan.md §3.2) drives
/// four visuals — `.ready` (primary ring + context line), `.pending`
/// (ghosted + "Logging…"), `.confirmed` (check + "Set n of total" + "Logged"
/// pill), `.failed` (ghosted + red toast) — plus a fifth, independent
/// ghosted state when `WorkoutManager.isPhoneReachable` is false: a tap
/// can't even start a `.pending` round-trip with no phone to answer it.
private struct LogPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  let screenWidth: CGFloat

  /// 300 ms tap-debounce (docs/watch/43-watch-f5-set-logging-plan.md §4.2) —
  /// belt-and-braces alongside `logSet()`'s own `logSetState == .ready`
  /// guard (the primary defense, since the button also visually disables
  /// the instant state leaves `.ready`): this just also swallows a
  /// double-tap landing in the same frame, before that state change has
  /// propagated back into `.disabled(_:)`.
  @State private var lastTapAt: Date?
  private let tapDebounceSeconds: TimeInterval = 0.3

  private var circleDiameter: CGFloat { screenWidth * DynamicSizing.logCircleDiameterFraction }
  private var canTap: Bool { workoutManager.logSetState == .ready && workoutManager.isPhoneReachable }
  /// The adjust stepper is a phone-mastered-only path in F5b — standalone
  /// still logs a fixed reps count (D-F6.8), and binding the stepper there
  /// is F6b's job (D-F5b.8). `WorkoutManager.beginLogAdjust()` guards this
  /// too; mirrored here so the `tune` hint glyph isn't advertised when the
  /// gesture would do nothing.
  private var canAdjust: Bool { canTap && !workoutManager.isStandalone }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      VStack(spacing: isCompact ? 10 : 16) {
        HStack {
          HeaderChip(
            icon: "dumbbell", label: elapsedText(now: context.date), isCompact: isCompact,
            isStandalone: workoutManager.isStandalone)
          Spacer()
        }
        Spacer(minLength: 0)
        // Not a `Button`: a Button's action fires *alongside* an attached
        // long-press, so opening the adjust view would also log a set with
        // the old values. `ExclusiveGesture` with the long press first makes
        // the long press win outright (docs/watch/48-watch-f5b-set-adjust-plan.md
        // D-F5b.1's implementation trap).
        circleContent
          .contentShape(Circle())
          .gesture(
            ExclusiveGesture(
              LongPressGesture(minimumDuration: 0.5).onEnded { _ in handleLongPress() },
              TapGesture().onEnded { handleTap() }
            )
          )
          .accessibilityLabel(Text("log_set_button_a11y"))
          // VoiceOver can't perform a long press, so the adjust path is
          // exposed as a named custom action instead of hiding behind the
          // gesture.
          .accessibilityAction(named: Text("log_adjust_open_a11y")) { handleLongPress() }
        belowCircleContent
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
    workoutManager.logSet()
  }

  private func handleLongPress() {
    guard canAdjust else { return }
    workoutManager.beginLogAdjust()
  }

  private func elapsedText(now: Date) -> String {
    guard let startedAt = workoutManager.startedAt else { return "00:00" }
    return formatSeconds(Int(max(0, now.timeIntervalSince(startedAt))))
  }

  private var checkmarkFont: Font { isCompact ? .system(size: 40, weight: .bold) : .system(size: 48, weight: .bold) }
  /// The "+1 set" wordmark's font — same visual weight as `RestHeroView`'s
  /// countdown number, this page's closest equivalent focal point.
  private var logSetButtonFont: Font { isCompact ? .system(.title2, design: .rounded) : .system(.largeTitle, design: .rounded) }

  @ViewBuilder
  private var circleContent: some View {
    switch workoutManager.logSetState {
    case .confirmed:
      ZStack {
        Circle()
          .fill(LifeyColors.primary.opacity(0.18))
          .overlay(Circle().strokeBorder(LifeyColors.primary, lineWidth: 3))
        VStack(spacing: 4) {
          Image(systemName: "checkmark")
            .font(checkmarkFont)
            .foregroundColor(LifeyColors.primary)
          if workoutManager.isStandalone {
            // No plan/total to report against (docs/watch/
            // 44-watch-f6-standalone-plan.md §3.4) — reuses
            // active_sets_free_format (count + combined reps) rather than a
            // bare "Set n" label, matching the exercise card's own line
            // instead of introducing a third, narrower string just for
            // this confirmed-state readout.
            Text(
              String(
                format: String(localized: "active_sets_free_format"),
                workoutManager.standaloneSets.count,
                workoutManager.standaloneSets.reduce(0) { $0 + $1.reps })
            )
            .font(isCompact ? .body : .title3)
            .fontWeight(.bold)
            .foregroundColor(LifeyColors.onSurface)
          } else if let setsDone = workoutManager.setsDone, let setsTotal = workoutManager.setsTotal {
            Text(String(format: String(localized: "active_sets_format"), setsDone, setsTotal))
              .font(isCompact ? .body : .title3)
              .fontWeight(.bold)
              .foregroundColor(LifeyColors.onSurface)
          }
        }
      }
      .frame(width: circleDiameter, height: circleDiameter)
    case .pending, .failed:
      ghostedCircle
    case .ready where !workoutManager.isPhoneReachable:
      ghostedCircle
    case .ready:
      ZStack {
        Circle()
          .fill(LifeyColors.container)
          .overlay(Circle().strokeBorder(LifeyColors.primary.opacity(0.55), lineWidth: 3))
        VStack(spacing: 6) {
          logSetButtonLabel(color: LifeyColors.primary)
          if canAdjust {
            // The long-press affordance (D-F5b.1): a small, non-interactive
            // hint in the same secondary brown the adjust view uses for its
            // own header, so the two read as one side path. It costs no tap
            // area — the whole circle stays the target.
            Image(systemName: "slider.horizontal.3")
              .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
              .foregroundColor(LifeyColors.secondary)
              .accessibilityHidden(true)
          }
        }
      }
      .frame(width: circleDiameter, height: circleDiameter)
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
    .frame(width: circleDiameter, height: circleDiameter)
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
    case .ready where !workoutManager.isPhoneReachable:
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
    if workoutManager.isStandalone {
      // No plan, so no "next set of total" to preview — just names the
      // session (docs/watch/44-watch-f6-standalone-plan.md §3.4), matching
      // the exercise card's own title below.
      return String(localized: "standalone_quick_start")
    }
    let exerciseName = workoutManager.exerciseName ?? String(localized: "active_default_exercise")
    guard let setsDone = workoutManager.setsDone, let setsTotal = workoutManager.setsTotal else {
      return exerciseName
    }
    return String(
      format: String(localized: "log_set_context_format"), exerciseName,
      min(setsDone + 1, setsTotal), setsTotal)
  }
}

/// Middle `TabView` page — `LogPage`'s original AW 02–04 home before the F5
/// log page took the leftmost slot (docs/40-watch-app-plan.md §12.1 B7,
/// canvas AW 02): elapsed/rest time, exercise/set counter, heart rate and
/// calories — no controls here, those live on `ControlsPage`.
/// The adjust stepper (canvas AW 10, docs/watch/48-watch-f5b-set-adjust-plan.md
/// §3.3) — reached by long-pressing the log control, never by the one-tap
/// flow. Replaces the pager while it's up (see `ActiveWorkoutView.body`), so
/// the digital crown drives the value here instead of paging. Everything is
/// tinted `LifeyColors.secondary` (brown) to mark it as the side path, and
/// nothing is logged until "Log {n} reps" is tapped (0.5).
private struct AdjustPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let state: LogAdjustState
  let isCompact: Bool
  let padding: CGFloat

  /// Crown position tracked as a free-running value; only its *delta* is
  /// used, since `WorkoutManager` owns the steps, bounds and clamping
  /// (D-F5b.5). A wide range keeps the crown from hitting an end stop.
  @State private var crownValue: Double = 0
  @FocusState private var isCrownFocused: Bool

  private var bigValueFont: Font {
    isCompact ? .system(.largeTitle, design: .rounded) : .system(size: 56, weight: .bold, design: .rounded)
  }

  var body: some View {
    VStack(spacing: isCompact ? 6 : 10) {
      HStack(spacing: 6) {
        Image(systemName: "slider.horizontal.3")
          .font(.system(size: isCompact ? 14 : 16))
          .foregroundColor(LifeyColors.secondary)
        Text("log_adjust_title")
          .font(isCompact ? .caption2 : .caption)
          .foregroundColor(LifeyColors.secondary)
          .tracking(0.5)
          .lineLimit(1)
        Spacer()
      }
      HStack(spacing: 6) {
        fieldSegment(.reps, label: String(localized: "log_adjust_reps"))
        fieldSegment(.weight, label: String(localized: "log_adjust_weight"))
      }
      Text(bigValueText)
        .font(bigValueFont)
        .fontWeight(.heavy)
        .foregroundColor(LifeyColors.onSurface)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(captionText)
        .font(isCompact ? .caption2 : .caption)
        .foregroundColor(LifeyColors.onSurfaceVariant)
        .lineLimit(1)
      Button {
        workoutManager.confirmLogAdjust()
      } label: {
        Text(String(format: String(localized: "log_adjust_confirm"), state.reps))
          .font(isCompact ? .caption : .body)
          .fontWeight(.bold)
          .foregroundColor(LifeyColors.onPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .padding(.horizontal, 16)
          .padding(.vertical, isCompact ? 8 : 10)
          .frame(maxWidth: .infinity)
          .background(LifeyColors.primary)
          .clipShape(Capsule())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, padding)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .focusable(true)
    .focused($isCrownFocused)
    .digitalCrownRotation(
      $crownValue, from: -1000, through: 1000, by: 1,
      sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
    .onChange(of: crownValue) { oldValue, newValue in
      let steps = Int((newValue - oldValue).rounded())
      if steps != 0 { workoutManager.stepLogAdjust(by: steps) }
    }
    .onAppear { isCrownFocused = true }
  }

  private func fieldSegment(_ field: LogAdjustField, label: String) -> some View {
    let isActive = state.field == field
    return Text(label)
      .font(isCompact ? .caption2 : .caption)
      .fontWeight(isActive ? .bold : .regular)
      .foregroundColor(isActive ? LifeyColors.onSurface : LifeyColors.onSurfaceVariant)
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(isActive ? LifeyColors.containerHighest : Color.clear)
      .overlay(
        Capsule().strokeBorder(isActive ? Color.clear : LifeyColors.outline, lineWidth: 1)
      )
      .clipShape(Capsule())
      .contentShape(Capsule())
      .onTapGesture { workoutManager.toggleLogAdjustField() }
  }

  private var bigValueText: String {
    switch state.field {
    case .reps: return "\(state.reps)"
    case .weight: return formatWeight(state.weight)
    }
  }

  /// The value *not* currently being edited, prefixed by the big number's own
  /// unit — the design's "reps · 60 kg" (0.4). Two separate keys because the
  /// order flips with the active field (§11/2).
  private var captionText: String {
    switch state.field {
    case .reps:
      return String(format: String(localized: "log_adjust_caption_reps"), formatWeight(state.weight))
    case .weight:
      return String(format: String(localized: "log_adjust_caption_weight"), state.reps)
    }
  }
}

private struct MetricsPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat

  private var heroFont: Font { isCompact ? .system(.title3, design: .rounded) : .system(.title2, design: .rounded) }
  private var captionFont: Font { isCompact ? .caption2 : .caption }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      Group {
        if let remainingSeconds = restRemainingSeconds() {
          VStack(spacing: 4) {
            RestHeroView(
              remainingSeconds: remainingSeconds,
              totalSeconds: workoutManager.restTotalSeconds,
              exerciseName: restExerciseName,
              setsDone: workoutManager.setsDone,
              setsTotal: workoutManager.setsTotal,
              isCompact: isCompact)
          }
        } else {
          // Left-aligned column (canvas AW 02) rather than centered — a
          // `Spacer()` between the readings and the exercise card lets the
          // card settle near the bottom instead of everything bunching in
          // the middle.
          VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
            HeaderChip(
              icon: "dumbbell", label: String(localized: "active_header_label"), isCompact: isCompact,
              isStandalone: workoutManager.isStandalone)
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
            if workoutManager.isStandalone {
              ExerciseCard(
                exerciseName: String(localized: "standalone_quick_start"), setsDone: nil, setsTotal: nil,
                isCompact: isCompact,
                freeFormatSets: (
                  workoutManager.standaloneSets.count,
                  workoutManager.standaloneSets.reduce(0) { $0 + $1.reps }
                ))
            } else {
              ExerciseCard(
                exerciseName: workoutManager.exerciseName ?? String(localized: "active_default_exercise"),
                setsDone: workoutManager.setsDone, setsTotal: workoutManager.setsTotal, isCompact: isCompact)
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

  /// `RestHeroView`'s "Next · <name>" label — standalone has no plan/exercise
  /// name, so the fallback is `standalone_quick_start` rather than the
  /// generic `active_default_exercise` (docs/watch/
  /// 44-watch-f6-standalone-plan.md §3.5).
  private var restExerciseName: String {
    workoutManager.exerciseName
      ?? String(
        localized: workoutManager.isStandalone ? "standalone_quick_start" : "active_default_exercise")
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

/// Third/last `TabView` page (docs/40-watch-app-plan.md §12.1 B7, canvas AW 04):
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
          HeaderChip(
            icon: "dumbbell", label: elapsedText(now: context.date), isCompact: isCompact,
            isStandalone: workoutManager.isStandalone)
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
      HeaderChip(
        icon: "timer", label: String(localized: "rest_hero_label"), isCompact: isCompact,
        isStandalone: workoutManager.isStandalone)
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

/// Weight display for the adjust stepper (docs/watch/48-watch-f5b-set-adjust-plan.md
/// §5): whole numbers stay whole ("60"), anything else gets a single decimal
/// ("62,5"), and the decimal separator follows the device locale. Kept in one
/// place rather than formatted inline at each call site, and behind a cached
/// formatter since view bodies re-render often.
private let weightFormatter: NumberFormatter = {
  let formatter = NumberFormatter()
  formatter.numberStyle = .decimal
  formatter.minimumFractionDigits = 0
  formatter.maximumFractionDigits = 1
  return formatter
}()

private func formatWeight(_ weight: Double) -> String {
  weightFormatter.string(from: NSNumber(value: weight)) ?? "\(Int(weight))"
}

private func formatSeconds(_ totalSeconds: Int) -> String {
  String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
}

#Preview {
  ActiveWorkoutView()
}
