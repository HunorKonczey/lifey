import SwiftUI
import WatchKit

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
  /// Mirrors `selectedPage` as a `Double` for `.digitalCrownRotation`, which
  /// needs its own continuous binding rather than the page `Int` itself —
  /// kept in sync with `selectedPage` in both directions so a crown turn and
  /// a swipe agree on where the "next" turn should land. Must start equal to
  /// `selectedPage`, since `onChange(of:)` doesn't fire for the initial value.
  @State private var crownRotation: Double = 1
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

// MARK: - Cardio (docs/cardio/55-cardio-watch-plan.md §4, C5.5)

/// SF Symbol per `ActivityType` (docs/cardio/55-cardio-watch-plan.md §2's
/// table doesn't cover SF Symbols — this mirrors the mobile app's Material
/// icons instead, `activity_type.dart`'s `activityTypeIcon`:
/// `directions_run`→`figure.run`, `directions_walk`→`figure.walk`,
/// `hiking`→`figure.hiking`, `pedal_bike`→`bicycle`,
/// `sports_basketball`→`basketball.fill`, `sports_soccer`→`soccerball`). An
/// unrecognized code (a future activity type this build predates) falls back
/// to `figure.mixed.cardio`, the same generic glyph `OTHER_CARDIO` itself
/// uses. `internal` (this target's default), not `private` — shared with
/// `StandalonePickerView`'s `CardioRow`, unlike the near-identical table in
/// `Runner/WatchBridge.swift`, which really can't share a source file with
/// this target (C5.4's "tudatosan duplikálva" only applies cross-target).
func cardioActivityIcon(for activityType: String) -> String {
  switch activityType {
  case "RUNNING": return "figure.run"
  case "WALKING": return "figure.walk"
  case "HIKING": return "figure.hiking"
  case "INDOOR_BIKE": return "bicycle"
  case "BASKETBALL": return "basketball.fill"
  case "FOOTBALL": return "soccerball"
  default: return "figure.mixed.cardio"
  }
}

/// Mirrors the mobile app's `activityTypeColor` (`activity_type.dart`) — see
/// `LifeyColors`'s "Cardio activity-type accents" section for which mobile
/// `MetricColors` token each hex reuses.
func cardioActivityTint(for activityType: String) -> Color {
  switch activityType {
  case "RUNNING": return LifeyColors.calories
  case "WALKING": return LifeyColors.cardioWalking
  case "HIKING": return LifeyColors.tertiary
  case "INDOOR_BIKE": return LifeyColors.cardioIndoorBike
  case "BASKETBALL": return LifeyColors.cardioBasketball
  case "FOOTBALL": return LifeyColors.cardioFootball
  default: return LifeyColors.onSurfaceVariant
  }
}

/// The cardio counterpart of `ActiveWorkoutView`'s STRENGTH `TabView` — two
/// pages only (`CardioMetricsPage`, then the reused `ControlsPage`), no
/// crown-driven page indicator beyond what `.tabViewStyle(.page)` draws on
/// its own. `onCourt` lives here, not inside `CardioMetricsPage` itself, so
/// swiping to `ControlsPage` and back doesn't reset it (a fresh `@State` in
/// a page `TabView` re-creates on reappear the same way `ActiveWorkoutView`'s
/// own `showExerciseList`/`selectedPage` are already hoisted to their
/// parent for exactly this reason).
///
/// **`onCourt` is watch-local only** — not sent to the phone, not read from
/// it (docs/cardio/59-cardio-implementation-plan.md's C5.5 progress note).
/// This mirrors `CardioSessionScreen._onCourt`'s *own*, already-shipped
/// design on the phone side (C2.4): "Local-only... never synced, never read
/// back" — a benched *phone*-mastered session doesn't actually change
/// anything about what `WorkoutManager.cardioMetrics` receives, so toggling
/// this here only switches which of AW 19/AW 20's two layouts is on screen,
/// not any real gross-vs-playing-time accounting (there is no separate
/// ticking checkpoint for gross time to switch between, see
/// `CardioActiveMetrics`'s own doc). Making the toggle **actually** pause
/// this watch's contribution to the session's playing time — and telling the
/// phone about it — is `C5.7`'s "GAME pályán/padon kapcsoló kétirányú
/// szinkronja" (docs/cardio/55-cardio-watch-plan.md §7, W-9).
struct CardioActiveContent: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  @State private var selectedPage = 0
  @State private var onCourt = true

  /// AW 20's edge border: the watch equivalent of the phone's top rail
  /// (M07/M09) — "csuklóemeléskor, fél másodperc alatt is látszik, hogy a
  /// mérés pihen". Only GAME has a benched state to signal.
  private var isBenched: Bool {
    workoutManager.cardioFamily == .game && !onCourt
  }

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction
      TabView(selection: $selectedPage) {
        CardioMetricsPage(isCompact: isCompact, padding: padding, onCourt: $onCourt).tag(0)
        ControlsPage(isCompact: isCompact, padding: padding, onOpenExerciseList: {}).tag(1)
      }
      .tabViewStyle(.page)
      // Drawn over the pager, ignoring its own safe area, so the stroke hugs
      // the physical screen edge on every case size instead of insetting
      // with the content.
      .overlay {
        if isBenched {
          RoundedRectangle(cornerRadius: geometry.size.width * 0.28)
            .strokeBorder(LifeyColors.secondary, lineWidth: 5)
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
      }
    }
    .background(LifeyColors.trueBlack)
  }
}

/// The family-dispatching cardio metrics page (canvas AW 17–20) — `GAME`
/// gets its own layout (`GameMetricsContent`, the pályán/padon toggle and
/// its single "bruttó" box), everything else shares `DistanceMachineMetricsContent`
/// (two boxes, no toggle). Ticks once a second via `TimelineView` purely to
/// re-evaluate `WorkoutManager.currentCardioMovingSeconds()` — every other
/// value here (`cardioMetrics`'s pre-formatted strings, `heartRateBpm`) is
/// `@Published` and already re-renders on its own.
struct CardioMetricsPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat
  @Binding var onCourt: Bool

  private var activityType: String { workoutManager.cardioActivityType ?? "OTHER_CARDIO" }
  private var family: CardioActivityFamily { workoutManager.cardioFamily ?? .distance }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { _ in
      Group {
        if family == .game {
          GameMetricsContent(isCompact: isCompact, activityType: activityType, onCourt: $onCourt)
        } else {
          DistanceMachineMetricsContent(isCompact: isCompact, family: family, activityType: activityType)
        }
      }
      .padding(.horizontal, padding)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
  }
}

/// AW 17 (DISTANCE) / AW 18 (MACHINE) — header, primary label+value (tinted,
/// the ticking moving-time slot per [tickingSlot]), the heart-rate row
/// (`CardioHeartRateRow`), and up to two supporting boxes.
private struct DistanceMachineMetricsContent: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let family: CardioActivityFamily
  let activityType: String

  private var heroFont: Font {
    isCompact ? .system(.title, design: .rounded) : .system(.largeTitle, design: .rounded)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
      HeaderChip(
        icon: cardioActivityIcon(for: activityType), label: workoutManager.activeHeaderLabel,
        isCompact: isCompact, isStandalone: workoutManager.showsStandaloneBadge)
      if let metrics = workoutManager.cardioMetrics {
        Text(primaryLabel(metrics))
          .font(isCompact ? .caption2 : .caption)
          .fontWeight(.bold)
          .tracking(1)
          .textCase(.uppercase)
          .foregroundColor(LifeyColors.onSurfaceVariant)
        Text(primaryValue(metrics))
          .font(heroFont)
          .fontWeight(.heavy)
          .foregroundColor(cardioActivityTint(for: activityType))
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        CardioHeartRateRow(isCompact: isCompact)
        HStack(spacing: isCompact ? 8 : 10) {
          // MACHINE's own `family == .distance` primary/secondary swap
          // (`DISTANCE` ticks its *secondary* box, not the primary) means the
          // secondary box shown here is `metrics.secondaryLabel`/`Value`
          // as-is for every family except the one already spent on ticking
          // it above — see `primaryLabel`/`primaryValue` below.
          if family != .distance, let secondaryLabel = metrics.secondaryLabel {
            CardioMetricBox(
              label: secondaryLabel, value: metrics.secondaryValue ?? "—", isCompact: isCompact)
          }
          if let tertiaryLabel = metrics.tertiaryLabel {
            CardioMetricBox(
              label: tertiaryLabel, value: metrics.tertiaryValue ?? "—", isCompact: isCompact)
          }
        }
        .padding(.top, isCompact ? 4 : 8)
      } else {
        // No `cardio` push has landed yet — right after `startWorkout`, the
        // watch's own `HKWorkoutSession` can start before the first
        // `updateState` arrives. Degrades to just the header + heart rate,
        // never a blank/zero-valued distance or a crash on a force-unwrap.
        CardioHeartRateRow(isCompact: isCompact)
      }
      Spacer(minLength: 0)
    }
  }

  /// `DISTANCE` shows the phone's own `primaryLabel` (distance doesn't tick
  /// locally — it only changes on a fresh GPS fix, so the last string the
  /// phone pushed is always current); `MACHINE` ticks the primary itself
  /// (moving time), so its label is fixed to `primaryLabel` regardless —
  /// only the *value* below switches to the local ticking one.
  private func primaryLabel(_ metrics: CardioActiveMetrics) -> String { metrics.primaryLabel }

  /// The moving-time duration ticks locally (`WorkoutManager
  /// .currentCardioMovingSeconds()`) rather than showing whatever string the
  /// phone last pushed — `MACHINE`'s primary slot IS that duration; `DISTANCE`'s
  /// is the distance itself, which is only as fresh as the last GPS fix
  /// (i.e. always current on its own, no ticking needed).
  private func primaryValue(_ metrics: CardioActiveMetrics) -> String {
    family == .distance ? metrics.primaryValue : formatSeconds(workoutManager.currentCardioMovingSeconds())
  }
}

/// AW 19 (on court) / AW 20 (on bench) — a dot+label primary caption instead
/// of the plain grey one `DistanceMachineMetricsContent` uses (both
/// families' primary is *always* the ticking moving/game time, unlike
/// `DISTANCE`, so there's no swap to reason about here), a single "bruttó"
/// box (GAME's `tertiaryValue` is a placeholder the phone never fills — see
/// `CardioLiveMetrics`'s Dart doc — so only `secondaryLabel`/`Value` renders),
/// and the pályán/padon toggle. See `CardioActiveContent`'s doc for why
/// [onCourt] is watch-local only.
private struct GameMetricsContent: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let activityType: String
  @Binding var onCourt: Bool

  private var tint: Color { onCourt ? cardioActivityTint(for: activityType) : LifeyColors.secondary }
  private var heroFont: Font {
    isCompact ? .system(.title, design: .rounded) : .system(.largeTitle, design: .rounded)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: isCompact ? 4 : 6) {
      HeaderChip(
        icon: onCourt ? cardioActivityIcon(for: activityType) : "figure.seated.side.right",
        label: onCourt ? workoutManager.activeHeaderLabel : String(localized: "cardio_on_bench_header_label"),
        isCompact: isCompact, isStandalone: workoutManager.showsStandaloneBadge)
      if let metrics = workoutManager.cardioMetrics {
        HStack(spacing: 7) {
          if onCourt {
            Circle().fill(LifeyColors.primary).frame(width: 8, height: 8)
          }
          Text(onCourt ? metrics.primaryLabel : String(localized: "cardio_game_paused_primary_label"))
            .font(isCompact ? .caption2 : .caption)
            .fontWeight(.bold)
            .tracking(1)
            .textCase(.uppercase)
            .foregroundColor(onCourt ? LifeyColors.primary : LifeyColors.secondary)
        }
        Text(formatSeconds(workoutManager.currentCardioMovingSeconds()))
          .font(heroFont)
          .fontWeight(.heavy)
          .foregroundColor(onCourt ? tint : LifeyColors.onSurfaceVariant)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        CardioHeartRateRow(isCompact: isCompact)
        if let secondaryLabel = metrics.secondaryLabel {
          CardioMetricBox(
            label: secondaryLabel, value: metrics.secondaryValue ?? "—", isCompact: isCompact,
            tint: onCourt ? nil : LifeyColors.secondary)
          .padding(.top, isCompact ? 4 : 8)
        }
        Spacer(minLength: 0)
        toggleButton
      } else {
        CardioHeartRateRow(isCompact: isCompact)
        Spacer(minLength: 0)
      }
    }
  }

  private var toggleButton: some View {
    Button(action: { onCourt.toggle() }) {
      HStack(spacing: 10) {
        Image(systemName: onCourt ? "figure.seated.side.right" : "figure.run")
          .font(.system(size: isCompact ? 22 : 26))
        // A ternary of two string literals infers as `String`, not
        // `LocalizedStringKey` — `Text(_:)` would then pick its verbatim
        // overload and show the raw key. `String(localized:)` first, like
        // `ControlsPage`'s own `active_resume_button`/`active_pause_button`
        // toggle a few lines below in this same file.
        Text(String(localized: onCourt ? "cardio_go_to_bench_button" : "cardio_back_to_court_button"))
          .font(isCompact ? .body : .title3)
          .fontWeight(.bold)
      }
      .foregroundColor(onCourt ? LifeyColors.onPrimary : LifeyColors.onSurface)
      .frame(maxWidth: .infinity)
      .frame(height: isCompact ? 56 : 66)
    }
    .buttonStyle(.plain)
    .background(onCourt ? LifeyColors.primary : LifeyColors.secondary)
    .clipShape(RoundedRectangle(cornerRadius: LifeyShapes.cardLarge))
  }
}

/// The heart-rate row every cardio layout shares — a real reading when
/// `WorkoutManager.heartRateBpm` has one (this watch's own `HKWorkoutSession`,
/// same sensor the STRENGTH `MetricsPage` already reads), or the degraded
/// "—" / `cardio_no_heart_rate_label` / strap hint (canvas AW 22) when it
/// doesn't. Unlike `MetricsPage`'s STRENGTH-side `HeroMetricRow`, which is
/// simply omitted when `heartRateBpm` is nil, this row's **space is always
/// reserved** — the design's own reasoning for M10's GPS chip applies here
/// too: "a hely megmarad, hogy az elrendezés ne ugráljon, és látszódjon,
/// hogy hiányzik."
private struct CardioHeartRateRow: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: isCompact ? 6 : 8) {
      HStack(spacing: isCompact ? 8 : 12) {
        Image(systemName: "heart.fill")
          .font(.system(size: isCompact ? 24 : 30))
          .foregroundColor(workoutManager.heartRateBpm == nil ? LifeyColors.ghostedOnSurface : LifeyColors.heart)
        if let heartRate = workoutManager.heartRateBpm {
          Text("\(Int(heartRate.rounded()))")
            .font(isCompact ? .system(.title2, design: .rounded) : .system(.title, design: .rounded))
            .fontWeight(.heavy)
            .foregroundColor(LifeyColors.onSurface)
            .monospacedDigit()
        } else {
          Text("—")
            .font(isCompact ? .system(.title2, design: .rounded) : .system(.title, design: .rounded))
            .fontWeight(.heavy)
            .foregroundColor(LifeyColors.ghostedOnSurface)
          Text("cardio_no_heart_rate_label")
            .font(isCompact ? .caption2 : .caption)
            .foregroundColor(LifeyColors.onSurfaceVariant)
            .lineLimit(2)
        }
      }
      if workoutManager.heartRateBpm == nil {
        Text("cardio_no_heart_rate_hint")
          .font(.caption2)
          .foregroundColor(LifeyColors.onSurfaceVariant)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

/// One of `DistanceMachineMetricsContent`/`GameMetricsContent`'s supporting
/// boxes (canvas AW 17/18's two-box row, AW 19/20's single "bruttó" one) —
/// [tint] overrides the value's color for GAME's on-bench state (muted
/// `secondary` instead of the default `onSurface`), `nil` everywhere else.
private struct CardioMetricBox: View {
  let label: String
  let value: String
  let isCompact: Bool
  var tint: Color? = nil

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(isCompact ? .callout : .title3)
        .fontWeight(.heavy)
        .foregroundColor(LifeyColors.onSurface)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(label)
        .font(.caption2)
        .foregroundColor(tint ?? LifeyColors.onSurfaceVariant)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, isCompact ? 10 : 14)
    .padding(.vertical, isCompact ? 8 : 12)
    // AW 20 tints the whole box, not just its text: benched, this is the one
    // clock still running, and it has to read that way at a glance.
    .background(tint == nil ? LifeyColors.surface : tint!.opacity(0.16))
    .clipShape(RoundedRectangle(cornerRadius: LifeyShapes.card))
  }
}

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
private struct HeaderChip: View {
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
        //
        // **Status only, not a button, during a cardio session**: there is no
        // adoption to ask for (`WorkoutManager.sendAdoptionRequest()` never
        // sends one for cardio — the phone would mirror a run as a strength
        // workout), so the badge tells the truth — this workout reaches the
        // phone when it ends — and a tap that could only do nothing is left
        // out rather than acknowledged with a spinner.
        Image(systemName: workoutManager.isRetryingAdoption ? "arrow.triangle.2.circlepath" : "iphone.slash")
          .font(.system(size: isCompact ? 14 : 16))
          .foregroundColor(LifeyColors.standaloneIndicator)
          .padding(.vertical, 6)
          .padding(.horizontal, 4)
          .contentShape(Rectangle())
          .onTapGesture { workoutManager.retryAdoption() }
          .disabled(workoutManager.isCardio)
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
private struct LogPage: View {
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

/// Middle `TabView` page and the pager's default (`selectedPage = 1` above)
/// — `LogPage`'s original AW 02–04 home before the F5 log page took the
/// leftmost slot (docs/40-watch-app-plan.md §12.1 B7, canvas AW 02): elapsed/
/// rest time, exercise/set counter, heart rate and calories — no controls
/// here, those live on `ControlsPage`.
/// The adjust stepper (canvas AW 10, docs/watch/48-watch-f5b-set-adjust-plan.md
/// §3.3) — reached by tapping the dedicated adjust button next to the log
/// control (`LogPage`'s `adjustButtonContent`), never by the one-tap "+1"
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
      // −  value  + (docs/watch/48-watch-f5b-set-adjust-plan.md §3.3
      // follow-up): the crown alone left the stepper undiscoverable by touch,
      // so both buttons sit permanently either side of the number, one step
      // per tap through the same `stepLogAdjust(by:)` the crown drives — so
      // clamping and the idle-timer reset come along unchanged. The number
      // takes the remaining width rather than hugging the buttons, so the two
      // tap targets stay put instead of shifting as its digit count changes.
      HStack(spacing: isCompact ? 6 : 10) {
        stepButton(
          systemName: "minus", steps: -1, enabled: state.canDecrement,
          a11yLabel: String(localized: "log_adjust_decrement_a11y"))
        Text(bigValueText)
          .font(bigValueFont)
          .fontWeight(.heavy)
          .foregroundColor(LifeyColors.onSurface)
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .frame(maxWidth: .infinity)
        stepButton(
          systemName: "plus", steps: 1, enabled: state.canIncrement,
          a11yLabel: String(localized: "log_adjust_increment_a11y"))
      }
      // The one row that reaches back into the screen padding (~60% of it, on
      // both sides): it sits at the vertical center of the dial, where the
      // round screen is at its widest and that safety margin isn't earning
      // anything — and with the buttons fixed-size, every point reclaimed
      // goes to the number between them. Mirrors Android's
      // `ADJUST_ROW_WIDTH_FRACTION`.
      .padding(.horizontal, -padding * 0.6)
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
    // `.high`, not `.low` — this is a discrete 1-detent-per-step control, so
    // it needs the crown's most direct 1:1 mapping. `.low` required several
    // physical detents to accumulate a whole `crownValue` unit, and since
    // that accumulation isn't perfectly linear, the number of detents needed
    // per step varied — the exact "one scroll should be one jump, but isn't
    // consistent" symptom reported in practice.
    .digitalCrownRotation(
      $crownValue, from: -1000, through: 1000, by: 1,
      sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
    .onChange(of: crownValue) { oldValue, newValue in
      let steps = Int((newValue - oldValue).rounded())
      if steps != 0 {
        workoutManager.stepLogAdjust(by: steps)
      } else {
        // A sub-unit crown movement that didn't round to a whole step still
        // counts as activity — resets the idle-dismiss timer on its own so
        // the screen can't disappear mid-turn just because no individual
        // delta happened to cross a rounding boundary.
        workoutManager.noteLogAdjustActivity()
      }
    }
    .onAppear { isCrownFocused = true }
  }

  /// One of the stepper's two −/+ buttons. A tap gesture on a shaped `ZStack`
  /// rather than a `Button` — matching `LogPage`'s own circles — because this
  /// page holds the crown focus (`isCrownFocused`) and a focusable `Button`
  /// inside it would compete for that focus. Ghosted (not hidden) once the
  /// active field sits at the end of its range, so the row keeps its shape at
  /// a bound. `.click` replaces the haptic the crown gets for free from
  /// `isHapticFeedbackEnabled`, mirroring Android's per-step tick.
  private func stepButton(systemName: String, steps: Int, enabled: Bool, a11yLabel: String)
    -> some View
  {
    let diameter: CGFloat = isCompact ? 40 : 48
    return ZStack {
      Circle()
        .fill(LifeyColors.container)
        .overlay(
          Circle().strokeBorder(
            enabled ? LifeyColors.secondary.opacity(0.55) : LifeyColors.outline, lineWidth: 2)
        )
      Image(systemName: systemName)
        .font(.system(size: isCompact ? 18 : 22, weight: .bold))
        .foregroundColor(enabled ? LifeyColors.secondary : LifeyColors.ghostedOnSurface)
    }
    .frame(width: diameter, height: diameter)
    .opacity(enabled ? 1 : 0.5)
    .contentShape(Circle())
    .onTapGesture {
      guard enabled else { return }
      WKInterfaceDevice.current().play(.click)
      workoutManager.stepLogAdjust(by: steps)
    }
    .accessibilityLabel(Text(a11yLabel))
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

/// Makes whatever it wraps open the exercise list — but only while there is
/// something to switch to (`canChooseExercise`), so a Quick strength session
/// or a phone that hasn't pushed its list keeps a plain, non-interactive
/// readout instead of a control that opens an empty screen.
private struct ExercisePickerTarget<Content: View>: View {
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

private struct MetricsPage: View {
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
private struct ExerciseListChip: View {
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
private struct ExerciseListView: View {
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
private struct ExerciseListRow: View {
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
        isStandalone: workoutManager.showsStandaloneBadge)
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
