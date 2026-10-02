import SwiftUI
import WatchKit

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
struct AdjustPage: View {
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
      LifeyHaptics.stepperTick()
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
