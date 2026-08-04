import SwiftUI

/// The pre-start picker (docs/watch/44-watch-f6-standalone-plan.md §3.1,
/// §3.3, design canvas AW 13). "Quick strength" is always first and always
/// works with zero phone contact; below it, up to 5 synced templates from
/// `StandaloneSessionStore` (title + exercise count, D-F6b.7) — or, with an
/// empty/stale cache, just `standalone_empty_hint` (F6a's only variant,
/// still the fallback here). Tapping the quick-strength card starts
/// `WorkoutManager.startStandalone()` directly; this view disappears on its
/// own once `phase` moves off `.idle` (`ContentView`'s switch re-renders),
/// so there's no need to also flip `onBack`'s owning `showStandalonePicker`
/// flag on success — only the explicit back tap and a failed start (which
/// leaves `phase == .idle`) need it.
///
/// A template row starts a session the same direct way — `WorkoutManager
/// .startStandalone(template:)` with the row's own already-read
/// `CachedTemplate` value handed straight through (docs/watch/
/// 49-watch-f6b-template-sync-plan.md §3.3, T6). No callback out to
/// `ContentView`: that would just be indirection for something this view
/// already does for Quick strength one line above it. (T4.2 originally
/// exposed an `onTemplateTapped` callback here as a placeholder — replaced
/// now that the real behavior is known, rather than kept for its own sake.)
struct StandalonePickerView: View {
  let onBack: () -> Void

  /// Debounces both the "Quick strength" tap and a template row's tap, and
  /// disables every row while a start attempt is in flight — mirrors
  /// `LogPage`'s tap-debounce (docs/watch/43-watch-f5-set-logging-plan.md
  /// §4.2). Reset once `startStandalone(template:)` returns *if* it left
  /// `phase == .idle` (a silent failure, e.g. another app owns the sensors)
  /// — a successful start or a `.healthDenied` transition both move `phase`
  /// off `.idle`, unmounting this view before the reset would matter.
  @State private var isStarting = false

  /// Read once per appearance, not observed live — matches
  /// `StandaloneSessionStore`'s existing "read is a point-in-time snapshot"
  /// contract everywhere else it's used (S9's recovery load, S11's summary
  /// pending-count). A sync landing while this exact screen is already on
  /// screen updates on the next time it's shown, not instantly — an
  /// acceptable staleness window for a picker the user only glances at
  /// before tapping something.
  @State private var templates: [CachedTemplate] = []

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction

      // A ScrollView, not a fixed-height VStack: with up to 5 synced
      // templates the content is taller than any watch face, and without a
      // scrollable container neither the Digital Crown nor a finger swipe
      // can reach the rows below the fold. The design called for this from
      // the start ("watchOS lista-carousel", 44-doc §3.1) — the F6a picker
      // only got away with a plain VStack because it had exactly one card.
      ScrollView {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
          // Back affordance sits *in* the scrolling flow, next to the
          // title, rather than floating over it in a ZStack: a floating
          // button would keep swallowing taps in the top-left corner as
          // rows scroll underneath it. Not in the design frame itself, but
          // the picker needs a way out — reuses effort_selector_back's
          // string (a plain "Back"/"Vissza") rather than adding a
          // picker-scoped key for one word.
          HStack(spacing: 6) {
            Button(action: onBack) {
              Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(LifeyColors.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("effort_selector_back"))
            Text("standalone_picker_title")
              .font(isCompact ? .title3 : .title2)
              .fontWeight(.heavy)
              .foregroundColor(LifeyColors.onSurface)
            Spacer(minLength: 0)
          }
          quickStrengthCard
          if templates.isEmpty {
            Text("standalone_empty_hint")
              .font(.caption2)
              .foregroundColor(LifeyColors.onSurfaceVariant)
              .multilineTextAlignment(.leading)
          } else {
            ForEach(templates, id: \.templateId) { template in
              TemplateRow(template: template, isCompact: isCompact, isDisabled: isStarting) {
                templateTapped(template)
              }
            }
          }
        }
        .padding(.horizontal, padding)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(LifeyColors.trueBlack)
    }
    .onAppear { templates = StandaloneSessionStore.shared.templates() }
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

  private func templateTapped(_ template: CachedTemplate) {
    guard !isStarting else { return }
    isStarting = true
    Task {
      await WorkoutManager.shared.startStandalone(template: template)
      if WorkoutManager.shared.phase == .idle {
        isStarting = false
      }
    }
  }
}

/// One synced-template row (canvas AW 13) — plain `surface` background,
/// unlike `quickStrengthCard`'s highlighted `container`/icon treatment
/// (D-F6b.7: quick-strength is the one always-works option, these are
/// secondary). No icon, matching the canvas exactly — just title + the
/// existing `standalone_plan_exercises` count string (added in F6a's S1,
/// unused until now).
private struct TemplateRow: View {
  let template: CachedTemplate
  let isCompact: Bool
  let isDisabled: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 1) {
        Text(template.title)
          .font(.body)
          .fontWeight(.bold)
          .foregroundColor(LifeyColors.onSurface)
          .lineLimit(1)
          .truncationMode(.tail)
        Text(String(format: String(localized: "standalone_plan_exercises"), template.exercises.count))
          .font(.caption2)
          .foregroundColor(LifeyColors.onSurfaceVariant)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .background(LifeyColors.surface)
    .clipShape(RoundedRectangle(cornerRadius: LifeyShapes.card))
  }
}

#Preview {
  StandalonePickerView(onBack: {})
}
