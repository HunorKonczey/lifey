import SwiftUI
import WatchKit

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
  // Outdoor cycling (docs/cardio/62-cardio-cycling-plan.md A6) — distinct
  // from INDOOR_BIKE's "bicycle" below. Apple's own Fitness app uses this
  // exact symbol for outdoor cycling workouts (verified to resolve via
  // `NSImage(systemSymbolName:)`, not guessed).
  case "CYCLING": return "figure.outdoor.cycle"
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
  case "HIKING": return LifeyColors.cardioHiking
  case "CYCLING": return LifeyColors.secondary // mirrors mobile's colorScheme.secondary
  case "INDOOR_BIKE": return LifeyColors.cardioIndoorBike
  case "BASKETBALL": return LifeyColors.cardioBasketball
  case "FOOTBALL": return LifeyColors.cardioFootball
  default: return LifeyColors.onSurfaceVariant
  }
}

/// The cardio counterpart of `ActiveWorkoutView`'s STRENGTH `TabView` — two
/// pages only (`CardioMetricsPage`, then the reused `ControlsPage`), no
/// crown-driven page indicator beyond what `.tabViewStyle(.page)` draws on
/// its own.
///
/// **`onCourt` is two-way synced** (docs/cardio/55-cardio-watch-plan.md §7,
/// W-9) and therefore lives on `WorkoutManager`, not in a view-local
/// `@State`: a tap here reaches the phone (`PhoneConnector.sendCourtChanged`
/// → `CardioSessionScreen._setOnCourt`), and the phone's own switch reaches
/// this screen on its next state push. It is a real accounting switch on
/// both sides now — benched minutes stop counting towards playing time,
/// while gross time keeps running — not just a choice between AW 19's and
/// AW 20's layouts.
struct CardioActiveContent: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  @State private var selectedPage = 0
  /// Read from `WorkoutManager`, not a `@State` of this view's own: the phone
  /// shows the same switch and either side can flip it (W-9), so the state
  /// has to live where a pushed update can reach it too.
  private var onCourt: Bool { workoutManager.isOnCourt }

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
        CardioMetricsPage(isCompact: isCompact, padding: padding).tag(0)
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

  private var onCourt: Bool { workoutManager.isOnCourt }
  private var activityType: String { workoutManager.cardioActivityType ?? "OTHER_CARDIO" }
  private var family: CardioActivityFamily { workoutManager.cardioFamily ?? .distance }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { _ in
      Group {
        if family == .game {
          GameMetricsContent(isCompact: isCompact, activityType: activityType)
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
struct DistanceMachineMetricsContent: View {
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
      if let metrics = workoutManager.activeCardioMetrics {
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
    family == .distance
      ? metrics.primaryValue
      : formatCardioDuration(workoutManager.currentCardioMovingSeconds())
  }
}

/// AW 19 (on court) / AW 20 (on bench) — a dot+label primary caption instead
/// of the plain grey one `DistanceMachineMetricsContent` uses (both
/// families' primary is *always* the ticking moving/game time, unlike
/// `DISTANCE`, so there's no swap to reason about here), a single "bruttó"
/// box (GAME's `tertiaryValue` is a placeholder the phone never fills — see
/// `CardioLiveMetrics`'s Dart doc — so only `secondaryLabel`/`Value` renders),
/// and the pályán/padon toggle. See `CardioActiveContent`'s doc for where
/// `onCourt` lives and why.
struct GameMetricsContent: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let activityType: String

  private var onCourt: Bool { workoutManager.isOnCourt }

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
      if let metrics = workoutManager.activeCardioMetrics {
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
        Text(formatCardioDuration(workoutManager.currentCardioMovingSeconds()))
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
    Button(action: { workoutManager.setOnCourt(!onCourt) }) {
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
struct CardioHeartRateRow: View {
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
struct CardioMetricBox: View {
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
