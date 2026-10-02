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
  case "CYCLING": return LifeyColors.clay  // mirrors mobile's colorScheme.secondary
  case "INDOOR_BIKE": return LifeyColors.cardioIndoorBike
  case "BASKETBALL": return LifeyColors.cardioBasketball
  case "FOOTBALL": return LifeyColors.cardioFootball
  default: return LifeyColors.text2
  }
}

/// The cardio counterpart of `ActiveWorkoutView`'s STRENGTH `TabView` — two pages (`CardioMetricsPage`, then the
/// reused `ControlsPage`).
///
/// **`onCourt` is two-way synced** (docs/cardio/55-cardio-watch-plan.md §7, W-9) and lives on `WorkoutManager`:
/// a tap here reaches the phone and the phone's own switch reaches this screen. Benched minutes stop counting
/// towards playing time while gross time keeps running.
struct CardioActiveContent: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  @State private var selectedPage = 0

  /// The bench rim: the watch equivalent of the phone's top rail — readable in half a second on wrist raise.
  private var isBenched: Bool { workoutManager.cardioFamily == .game && !workoutManager.isOnCourt }

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction
      TabView(selection: $selectedPage) {
        CardioMetricsPage(isCompact: isCompact, padding: padding).tag(0)
        ControlsPage(isCompact: isCompact, padding: padding, onOpenExerciseList: {}).tag(1)
      }
      .tabViewStyle(.page)
      // Drawn over the pager, ignoring its own safe area, so the stroke hugs the physical screen edge.
      .overlay { if isBenched { BenchFrame() } }
    }
    .background(LifeyColors.bg)
  }
}

// MARK: - Cardio metrics (redesign X2.7 – X2.9 — AW2.11 … AW2.16)

/// Plain data behind every cardio metrics layout (distance, machine, team sport).
struct CardioModel {
  var activityType: String
  var headerLabel: String
  var showsStandaloneMark = false
  var markTapped = false
  /// "TÁVOLSÁG" / "MOZGÁSIDŐ" / "JÁTÉKIDŐ" — phone-supplied.
  var primaryLabel: String
  var primaryValue: String
  var heartRateBpm: Int?
  /// Stacked field rows under the HR slot (phone-supplied labels, two lines at most).
  var fields: [(value: String, label: String)] = []
  /// Team sport only.
  var isGame = false
  var onCourt = true
  /// Gross time, shown in the HR row on the right while on court and in clay on the bench.
  var gross: (value: String, label: String)? = nil
  var toggleTitle = ""
}

/// One layout for the three cardio families (D1): the workout's unit is the hero in **white** (the accent moves
/// to the header chip), HR sits in the same slot and size as on strength, phone-supplied fields stack under it.
/// Team sport: dense hero, gross time in the HR row, a 46 pt toggle button; on the bench the play time is
/// stopped (`text3`), the gross time clay, and the rim (`BenchFrame`) is drawn by the page.
struct CardioContent: View {
  let model: CardioModel
  var onMarkTap: () -> Void = {}
  var onToggle: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  private var accent: Color { model.isGame && !model.onCourt ? LifeyColors.clay : cardioActivityTint(for: model.activityType) }
  private var icon: String {
    model.isGame && !model.onCourt ? "figure.seated.side.right" : cardioActivityIcon(for: model.activityType)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      WatchHeaderChip(
        icon: icon, label: model.headerLabel, accent: accent,
        standaloneMark: model.showsStandaloneMark ? (model.markTapped ? .tapped : .idle) : nil,
        onMarkTap: onMarkTap)
      Text(verbatim: model.primaryLabel)
        .lifeyLabel(metrics, caps: true)
        .foregroundColor(model.isGame && !model.onCourt ? LifeyColors.text3 : LifeyColors.text2)
        .lineLimit(1)
        .padding(.top, LifeySpacing.xs)
      Text(verbatim: model.primaryValue)
        .lifeyHero(metrics, dense: model.isGame)
        .foregroundColor(model.isGame && !model.onCourt ? LifeyColors.text3 : LifeyColors.text)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      hrRow.padding(.top, LifeySpacing.md)
      VStack(spacing: LifeySpacing.xs) {
        ForEach(Array(model.fields.enumerated()), id: \.offset) { _, field in
          CardioField(value: field.value, label: field.label)
        }
      }
      .padding(.top, LifeySpacing.sm)
      Spacer(minLength: LifeySpacing.xs)
      if model.isGame { toggleButton }
    }
    .padding(.horizontal, metrics.sideMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
  }

  /// The HR slot, with the gross time on the right for team sport.
  private var hrRow: some View {
    HStack(alignment: .center, spacing: LifeySpacing.md) {
      HeartRateSlot(bpm: model.heartRateBpm)
      if let gross = model.gross {
        Spacer(minLength: 0)
        VStack(alignment: .trailing, spacing: 0) {
          Text(verbatim: gross.value).lifeyValue(metrics)
            .foregroundColor(model.onCourt ? LifeyColors.text : LifeyColors.clay)
          Text(verbatim: gross.label).lifeyLabel(metrics, caps: true).foregroundColor(LifeyColors.text2).lineLimit(1)
        }
      }
    }
  }

  /// "Padra" / "Vissza a pályára": 46 pt (44 on the compact dial) — under the thumb, not the old 66 pt block.
  private var toggleButton: some View {
    Button(action: onToggle) {
      HStack(spacing: LifeySpacing.md) {
        Image(systemName: model.onCourt ? "figure.seated.side.right" : "figure.run")
        Text(verbatim: model.toggleTitle).lineLimit(1).minimumScaleFactor(0.8)
      }
      .lifeyBodyBold(metrics)
      .foregroundColor(model.onCourt ? LifeyColors.text : LifeyColors.onPrimary)
      .frame(maxWidth: .infinity, minHeight: metrics.isCompact ? 44 : 46)
      .background(model.onCourt ? LifeyColors.control : LifeyColors.primary, in: Capsule())
    }
    .buttonStyle(.plain)
  }
}

/// The live cardio metrics page. Ticks once a second via `TimelineView` purely to re-evaluate
/// `WorkoutManager.currentCardioMovingSeconds()` — every other value is `@Published` and re-renders on its own.
struct CardioMetricsPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let isCompact: Bool
  let padding: CGFloat

  private var activityType: String { workoutManager.cardioActivityType ?? "OTHER_CARDIO" }
  private var family: CardioActivityFamily { workoutManager.cardioFamily ?? .distance }

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { _ in
      CardioContent(
        model: model(),
        onMarkTap: { workoutManager.retryAdoption() },
        onToggle: { workoutManager.setOnCourt(!workoutManager.isOnCourt) })
    }
  }

  private func model() -> CardioModel {
    let hr = workoutManager.heartRateBpm.map { Int($0.rounded()) }
    let onCourt = workoutManager.isOnCourt
    var model = CardioModel(
      activityType: activityType, headerLabel: workoutManager.activeHeaderLabel,
      showsStandaloneMark: workoutManager.showsStandaloneBadge, markTapped: workoutManager.isRetryingAdoption,
      primaryLabel: "", primaryValue: "—", heartRateBpm: hr)
    // No `cardio` push has landed yet (the watch's own session can start before the first update): only the
    // header and the HR slot, never a zero-valued distance or a force-unwrap.
    guard let metrics = workoutManager.activeCardioMetrics else { return model }
    model.primaryLabel = metrics.primaryLabel
    switch family {
    case .distance:
      // Distance only changes on a fresh GPS fix, so the last string the phone pushed is always current.
      model.primaryValue = metrics.primaryValue
      if let label = metrics.tertiaryLabel { model.fields = [(metrics.tertiaryValue ?? "—", label)] }
    case .machine:
      model.primaryValue = formatCardioDuration(workoutManager.currentCardioMovingSeconds())
      if let label = metrics.secondaryLabel { model.fields.append((metrics.secondaryValue ?? "—", label)) }
      if let label = metrics.tertiaryLabel { model.fields.append((metrics.tertiaryValue ?? "—", label)) }
    case .game:
      model.isGame = true
      model.onCourt = onCourt
      model.headerLabel = onCourt ? workoutManager.activeHeaderLabel : String(localized: "cardio_on_bench_header_label")
      model.primaryLabel = onCourt ? metrics.primaryLabel : String(localized: "cardio_game_paused_primary_label")
      model.primaryValue = formatCardioDuration(workoutManager.currentCardioMovingSeconds())
      if let label = metrics.secondaryLabel { model.gross = (metrics.secondaryValue ?? "—", label) }
      model.toggleTitle = String(localized: onCourt ? "cardio_go_to_bench_button" : "cardio_back_to_court_button")
    }
    return model
  }
}
