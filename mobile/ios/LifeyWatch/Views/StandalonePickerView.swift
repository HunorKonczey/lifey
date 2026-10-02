import SwiftUI

/// The pre-start picker (docs/watch/44-watch-f6-standalone-plan.md §3.1,
/// §3.3, design canvas AW 13; unified with cardio entries by
/// docs/cardio/55-cardio-watch-plan.md §3, canvas AW 16 — C5.4). "Quick
/// strength" is always first and always works with zero phone contact
/// (D-C5.3: the pinned card stays above the ranked list, never part of it);
/// below it, up to 8 ranked entries from `StandaloneSessionStore` — synced
/// templates (title + exercise count, D-F6b.7) and cardio activity types
/// (icon + title) interleaved in whatever order the phone already ranked
/// them (§3.1: "nem talál ki saját rendezést") — or, with an empty/stale
/// cache, just `standalone_empty_hint` (F6a's only variant, still the
/// fallback here). Tapping the quick-strength card starts
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
///
/// A **cardio** row (`CardioRow`) starts a standalone cardio session
/// directly, the same way `templateTapped`/`startTapped` do — via
/// `WorkoutManager.startStandalone(activityType:)`'s own
/// `HKWorkoutConfiguration` mapping and `kind: 'CARDIO'` closing payload
/// (docs/cardio/55-cardio-watch-plan.md §5/§7, W-8).
///
/// Below the ranked list sits one more row, opening `AllActivityTypesView`
/// — every activity type the phone knows, not just the ones that ranked.
/// The ranked list is capped at 8 rows *shared* between templates and cardio
/// and ordered purely by usage, so a user who trains 8 templates regularly
/// gets no cardio row in it at all; without this screen, the watch would
/// then have no way whatsoever to start a cardio session on its own.
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
  @State private var entries: [WatchQuickStartEntry] = []

  /// Every activity type the phone knows, pre-localized — the "all activity
  /// types" screen's data, read at the same moment and with the same
  /// point-in-time contract as [entries]. Empty until a phone build that
  /// sends `allCardio` has synced once, which is when the row that opens the
  /// screen simply isn't shown.
  @State private var allCardio: [CachedActivityType] = []

  /// Whether the "all activity types" list is showing instead of the picker
  /// — local UI navigation, mirroring `ContentView`'s own
  /// `showStandalonePicker` flag rather than a `NavigationStack` this app
  /// doesn't otherwise use.
  @State private var showAllTypes = false

  var body: some View {
    if showAllTypes {
      AllActivityTypesView(
        entries: allCardio, isDisabled: isStarting, onBack: { showAllTypes = false },
        onTap: cardioTapped)
    } else {
      picker
    }
  }

  private var picker: some View {
    PickerContent(
      model: PickerModel(entries: entries.map(PickerEntry.init), hasAllTypes: !allCardio.isEmpty, isStarting: isStarting),
      onBack: onBack,
      onQuick: startTapped,
      onTemplate: { index in
        if case .template(let template) = entries[index] { templateTapped(template) }
      },
      onCardio: cardioTapped,
      onAllTypes: { showAllTypes = true }
    )
    .onAppear {
      entries = StandaloneSessionStore.shared.quickStartEntries()
      allCardio = StandaloneSessionStore.shared.allCardio()
    }
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

  /// [title] is the row's own pre-localized activity name, handed straight
  /// through to the session so its header reads "Walking", not the generic
  /// STRENGTH label — see `WorkoutManager.startStandalone`.
  private func cardioTapped(_ activityType: String, title: String) {
    guard !isStarting else { return }
    isStarting = true
    Task {
      await WorkoutManager.shared.startStandalone(activityType: activityType, title: title)
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

// MARK: - Picker (redesign X2.2 / X2.3 — AW2.2 … AW2.5)

/// One ranked row of the picker as plain data (a template or a cardio type).
enum PickerEntry {
  case template(title: String, exerciseCount: Int)
  case cardio(activityType: String, title: String)

  init(_ entry: WatchQuickStartEntry) {
    switch entry {
    case .template(let template): self = .template(title: template.title, exerciseCount: template.exercises.count)
    case .cardio(let type, let title): self = .cardio(activityType: type, title: title)
    }
  }
}

struct PickerModel {
  var entries: [PickerEntry]
  var hasAllTypes: Bool
  var isStarting = false
}

/// The standalone picker (docs/watch/44-watch-f6-standalone-plan.md §3.1): `ListRow` everywhere (22 radius).
/// Quick strength is highlighted (`nested`, 36 pt `bolt.fill` holder — one line, three before); templates show
/// "5 gyakorlat" and a chevron; cardio rows a tinted icon circle; "Minden edzéstípus" only when the type list
/// is synced; the empty state is a `sync` icon with a `text2` footnote. The crown scrolls.
struct PickerContent: View {
  let model: PickerModel
  var onBack: () -> Void = {}
  var onQuick: () -> Void = {}
  var onTemplate: (Int) -> Void = { _ in }
  var onCardio: (String, String) -> Void = { _, _ in }
  var onAllTypes: () -> Void = {}

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: LifeySpacing.sm) {
          ListRow(
            title: String(localized: "standalone_quick_start"), onClick: onQuick,
            subtitle: String(localized: "standalone_quick_caption"), leading: .holder(icon: "bolt.fill"),
            isHighlighted: true)
          if model.entries.isEmpty {
            HStack(alignment: .top, spacing: LifeySpacing.sm) {
              Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 13))
              Text("standalone_empty_hint").lifeyLabel(metrics).multilineTextAlignment(.leading)
            }
            .foregroundColor(LifeyColors.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, LifeySpacing.lg)
          } else {
            // Index-keyed: a ranked entry has no stable id of its own and the list is a point-in-time snapshot.
            ForEach(Array(model.entries.enumerated()), id: \.offset) { index, entry in
              switch entry {
              case .template(let title, let count):
                ListRow(
                  title: title, onClick: { onTemplate(index) },
                  subtitle: String(format: String(localized: "standalone_plan_exercises"), count), showsChevron: true,
                  isDisabled: model.isStarting)
              case .cardio(let type, let title):
                ListRow(
                  title: title, onClick: { onCardio(type, title) },
                  leading: .tintedCircle(icon: cardioActivityIcon(for: type), accent: cardioActivityTint(for: type)),
                  isDisabled: model.isStarting)
              }
            }
          }
          if model.hasAllTypes {
            ListRow(
              title: String(localized: "standalone_all_types"), onClick: onAllTypes,
              leading: .controlCircle(icon: "square.grid.2x2.fill"), showsChevron: true, isDisabled: model.isStarting)
          }
        }
        .padding(.horizontal, metrics.sideMargin)
      }
      .navigationTitle(Text("standalone_picker_title"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(action: onBack) { Image(systemName: "chevron.left") }
            .accessibilityLabel(Text("effort_selector_back"))
        }
      }
    }
  }
}

/// "Minden edzéstípus" (AW2.5): the full list of cardio types as a large title in the content that collapses
/// into the navigation bar on scroll; rows are never clipped ("Egyéb kardió" has a `text2` icon).
struct AllTypesContent: View {
  let entries: [(activityType: String, title: String)]
  var isDisabled = false
  var onBack: () -> Void = {}
  var onTap: (String, String) -> Void = { _, _ in }

  @Environment(\.watchMetrics) private var metrics

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: LifeySpacing.sm) {
          // Keyed by activity type, which really is unique here (the phone builds the list from kActivityTypes).
          ForEach(entries, id: \.activityType) { entry in
            ListRow(
              title: entry.title, onClick: { onTap(entry.activityType, entry.title) },
              leading: .tintedCircle(icon: cardioActivityIcon(for: entry.activityType), accent: cardioActivityTint(for: entry.activityType)),
              isDisabled: isDisabled)
          }
        }
        .padding(.horizontal, metrics.sideMargin)
      }
      .navigationTitle(Text("standalone_all_types"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(action: onBack) { Image(systemName: "chevron.left") }
            .accessibilityLabel(Text("effort_selector_back"))
        }
      }
    }
  }
}

struct AllActivityTypesView: View {
  let entries: [CachedActivityType]
  let isDisabled: Bool
  let onBack: () -> Void
  let onTap: (String, String) -> Void

  var body: some View {
    AllTypesContent(
      entries: entries.map { ($0.activityType, $0.title) }, isDisabled: isDisabled, onBack: onBack, onTap: onTap)
  }
}

#Preview {
  StandalonePickerView(onBack: {})
}
