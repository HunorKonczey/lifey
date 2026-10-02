import SwiftUI
import WatchKit

// MARK: - Stepper (redesign X1.7 — AW1.10, AW1.11)

/// Plain data behind the adjust stepper.
struct AdjustModel {
  var field: LogAdjustField
  /// The big number: "8" or "62,5".
  var valueText: String
  /// "ism. · 62,5 kg" / "kg · 8 ism." (`log_adjust_caption_*`).
  var captionText: String
  /// "8 ismétlés naplózása" (`log_adjust_confirm`).
  var confirmText: String
  var canDecrement = true
  var canIncrement = true
}

/// The stepper (docs/watch/48-watch-f5b-set-adjust-plan.md §3.3): only the header is clay ("MÓDOSÍTÁS"), a
/// segmented switch "Ismétlés | Súly", ± 44 pt circles either side of the value, a caption with the other
/// field, and a full-width primary confirm pill that may wrap to two lines.
struct AdjustContent: View {
  let model: AdjustModel
  var onStep: (Int) -> Void = { _ in }
  var onToggleField: () -> Void = {}
  var onConfirm: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        WatchHeaderChip(icon: "slider.horizontal.3", label: String(localized: "log_adjust_title"), accent: LifeyColors.clay)
        Spacer(minLength: 0)
      }
      segmentedSwitch.padding(.top, LifeySpacing.xs)
      // The one row that reaches back into the side margin: at the vertical centre the round display is at
      // its widest, so ± can sit "inside the margin" and the number keeps the width.
      HStack(spacing: LifeySpacing.sm) {
        stepButton("minus", steps: -1, enabled: model.canDecrement, a11y: "log_adjust_decrement_a11y")
        Text(verbatim: model.valueText)
          .lifeyHero(metrics)
          .foregroundColor(LifeyColors.text)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .frame(maxWidth: .infinity)
        stepButton("plus", steps: 1, enabled: model.canIncrement, a11y: "log_adjust_increment_a11y")
      }
      .padding(.horizontal, -metrics.sideMargin * 0.5)
      .padding(.top, LifeySpacing.md)
      Text(verbatim: model.captionText)
        .lifeyBody(metrics)
        .foregroundColor(LifeyColors.text2)
        .lineLimit(1)
        .padding(.top, LifeySpacing.xs)
      Spacer(minLength: LifeySpacing.xs)
      Button(action: onConfirm) {
        Text(verbatim: model.confirmText)
          .lifeyBodyBold(metrics)
          .foregroundColor(LifeyColors.onPrimary)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.85)
          .padding(.horizontal, LifeySpacing.lg)
          .frame(maxWidth: .infinity, minHeight: metrics.minTouchTarget)
          .background(LifeyColors.primary, in: Capsule())
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, metrics.sideMargin)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var segmentedSwitch: some View {
    HStack(spacing: 0) {
      segment(String(localized: "log_adjust_reps"), active: model.field == .reps)
      segment(String(localized: "log_adjust_weight"), active: model.field == .weight)
    }
    .padding(3)
    .background(LifeyColors.card, in: Capsule())
  }

  private func segment(_ title: String, active: Bool) -> some View {
    Text(verbatim: title)
      .lifeyBody(metrics)
      .fontWeight(active ? .bold : .semibold)
      .foregroundColor(active ? LifeyColors.text : LifeyColors.text2)
      .lineLimit(1)
      .minimumScaleFactor(0.8)
      .frame(maxWidth: .infinity, minHeight: 30)
      .background(active ? LifeyColors.raised : Color.clear, in: Capsule())
      .contentShape(Capsule())
      .onTapGesture { if !active { onToggleField() } }
  }

  /// A tap gesture on a shaped view rather than a `Button`: the live page holds the crown focus and a
  /// focusable `Button` inside it would compete for that focus. Ghosted (not hidden) at the end of the range.
  private func stepButton(_ systemName: String, steps: Int, enabled: Bool, a11y: String) -> some View {
    Image(systemName: systemName)
      .font(.system(size: 18, weight: .bold))
      .foregroundColor(enabled ? LifeyColors.text : LifeyColors.ghost)
      .frame(width: metrics.minTouchTarget, height: metrics.minTouchTarget)
      .background(enabled ? LifeyColors.control : LifeyColors.card, in: Circle())
      .contentShape(Circle())
      .onTapGesture {
        guard enabled else { return }
        LifeyHaptics.stepperTick()
        onStep(steps)
      }
      .accessibilityLabel(Text(LocalizedStringKey(a11y)))
  }
}

/// The live stepper — replaces the pager while it is up (both want the crown), reached from the "Módosítás"
/// circle. Everything stays in `WorkoutManager`: steps, bounds, clamping, the 3 s idle dismiss. The crown here
/// is `.high` (one detent = one step).
struct AdjustPage: View {
  @ObservedObject private var workoutManager = WorkoutManager.shared
  let state: LogAdjustState
  let isCompact: Bool
  let padding: CGFloat

  /// Crown position as a free-running value; only its *delta* is used (D-F5b.5).
  @State private var crownValue: Double = 0
  @FocusState private var isCrownFocused: Bool

  var body: some View {
    AdjustContent(
      model: model,
      onStep: { workoutManager.stepLogAdjust(by: $0) },
      onToggleField: { workoutManager.toggleLogAdjustField() },
      onConfirm: { workoutManager.confirmLogAdjust() }
    )
    .focusable(true)
    .focused($isCrownFocused)
    .digitalCrownRotation(
      $crownValue, from: -1000, through: 1000, by: 1,
      sensitivity: .high, isContinuous: false, isHapticFeedbackEnabled: true)
    .onChange(of: crownValue) { oldValue, newValue in
      let steps = Int((newValue - oldValue).rounded())
      if steps != 0 {
        workoutManager.stepLogAdjust(by: steps)
      } else {
        // A sub-unit movement still counts as activity — resets the idle-dismiss timer.
        workoutManager.noteLogAdjustActivity()
      }
    }
    .onAppear { isCrownFocused = true }
  }

  private var model: AdjustModel {
    let value: String
    let caption: String
    switch state.field {
    case .reps:
      value = "\(state.reps)"
      caption = String(format: String(localized: "log_adjust_caption_reps"), formatWeight(state.weight))
    case .weight:
      value = formatWeight(state.weight)
      caption = String(format: String(localized: "log_adjust_caption_weight"), state.reps)
    }
    return AdjustModel(
      field: state.field, valueText: value, captionText: caption,
      confirmText: String(format: String(localized: "log_adjust_confirm"), state.reps),
      canDecrement: state.canDecrement, canIncrement: state.canIncrement)
  }
}
