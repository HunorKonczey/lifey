import SwiftUI

/// The pre-start picker (docs/watch/44-watch-f6-standalone-plan.md §3.1,
/// §3.3, design canvas AW 13) — in F6a this is always the "empty/stale
/// cache" variant: just the "Quick strength" card + `standalone_empty_hint`,
/// since there's no template sync yet (F6b adds the synced-plan rows above
/// the hint). Tapping the card starts `WorkoutManager.startStandalone()`
/// directly; this view disappears on its own once `phase` moves off
/// `.idle` (`ContentView`'s switch re-renders), so there's no need to also
/// flip `onBack`'s owning `showStandalonePicker` flag on success — only the
/// explicit back tap and a failed start (which leaves `phase == .idle`)
/// need it.
struct StandalonePickerView: View {
  let onBack: () -> Void

  /// Debounces the "Quick strength" tap and disables the card while a start
  /// attempt is in flight — mirrors `LogPage`'s tap-debounce
  /// (docs/watch/43-watch-f5-set-logging-plan.md §4.2). Reset once
  /// `startStandalone()` returns *if* it left `phase == .idle` (a silent
  /// failure, e.g. another app owns the sensors) — a successful start or a
  /// `.healthDenied` transition both move `phase` off `.idle`, unmounting
  /// this view before the reset would matter.
  @State private var isStarting = false

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction

      ZStack(alignment: .topLeading) {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
          Text("standalone_picker_title")
            .font(isCompact ? .title3 : .title2)
            .fontWeight(.heavy)
            .foregroundColor(LifeyColors.onSurface)
            .padding(.top, isCompact ? 20 : 26)
          quickStrengthCard
          Text("standalone_empty_hint")
            .font(.caption2)
            .foregroundColor(LifeyColors.onSurfaceVariant)
            .multilineTextAlignment(.leading)
          Spacer(minLength: 0)
        }
        .padding(.horizontal, padding)
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)

        // No back affordance in the design frame itself, but F6a's picker
        // has exactly one actionable row — without this, a user who opened
        // the picker by mistake would be stuck here. Reuses
        // effort_selector_back's string (a plain "Back"/"Vissza"), which
        // reads correctly here too rather than adding a picker-scoped key
        // for one word.
        Button(action: onBack) {
          Image(systemName: "chevron.left")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(LifeyColors.onSurfaceVariant)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("effort_selector_back"))
        .padding(.top, isCompact ? 4 : 6)
        .padding(.leading, 2)
      }
      .background(LifeyColors.trueBlack)
    }
  }

  private var quickStrengthCard: some View {
    Button(action: startTapped) {
      HStack(spacing: 13) {
        ZStack {
          RoundedRectangle(cornerRadius: LifeyShapes.button)
            .fill(LifeyColors.containerHigh)
            .frame(width: 44, height: 44)
          Image(systemName: "bolt.fill")
            .foregroundColor(LifeyColors.primary)
        }
        VStack(alignment: .leading, spacing: 1) {
          Text("standalone_quick_start")
            .font(.body)
            .fontWeight(.bold)
            .foregroundColor(LifeyColors.onSurface)
          Text("standalone_quick_caption")
            .font(.caption2)
            .foregroundColor(LifeyColors.onSurfaceVariant)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
    .buttonStyle(.plain)
    .disabled(isStarting)
    .background(LifeyColors.container)
    .clipShape(RoundedRectangle(cornerRadius: LifeyShapes.card))
  }

  private func startTapped() {
    guard !isStarting else { return }
    isStarting = true
    Task {
      await WorkoutManager.shared.startStandalone()
      if WorkoutManager.shared.phase == .idle {
        isStarting = false
      }
    }
  }
}

#Preview {
  StandalonePickerView(onBack: {})
}
