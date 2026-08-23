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
          if entries.isEmpty {
            Text("standalone_empty_hint")
              .font(.caption2)
              .foregroundColor(LifeyColors.onSurfaceVariant)
              .multilineTextAlignment(.leading)
          } else {
            // Index-keyed, not by a natural id: a `WatchQuickStartEntry` has
            // none of its own (a cardio row isn't even backed by a stable
            // server id, just an activity-type code that could repeat if the
            // phone ever ranked one twice), and the list is a point-in-time
            // snapshot re-read on every appearance anyway (see `entries`'
            // own doc comment) — nothing here needs SwiftUI's identity-
            // preserving diffing across in-place updates.
            ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
              switch entry {
              case .template(let template):
                TemplateRow(template: template, isCompact: isCompact, isDisabled: isStarting) {
                  templateTapped(template)
                }
              case .cardio(let activityType, let title):
                CardioRow(
                  activityType: activityType, title: title, isCompact: isCompact,
                  isDisabled: isStarting
                ) {
                  cardioTapped(activityType)
                }
              }
            }
          }
          // The ranked list above is capped at 8 rows shared between
          // templates and cardio, so a user who trains that many templates
          // regularly can end up with no cardio row at all — this is the way
          // to every type regardless of what the ranking fit. Hidden, not
          // disabled, while the cache is empty (a phone that hasn't synced
          // one yet): a row that opens an empty screen is worse than no row.
          if !allCardio.isEmpty {
            AllTypesRow(isDisabled: isStarting) { showAllTypes = true }
          }
        }
        .padding(.horizontal, padding)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(LifeyColors.trueBlack)
    }
    .onAppear {
      entries = StandaloneSessionStore.shared.quickStartEntries()
      allCardio = StandaloneSessionStore.shared.allCardio()
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

  private func cardioTapped(_ activityType: String) {
    guard !isStarting else { return }
    isStarting = true
    Task {
      await WorkoutManager.shared.startStandalone(activityType: activityType)
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

/// One ranked cardio activity-type row (canvas AW 16) — an icon circle
/// tinted per activity type (`cardioActivityIcon`/`cardioActivityTint`,
/// `Views/ActiveWorkoutView.swift` — shared with that file's own cardio
/// pages, C5.5), `TemplateRow`'s plain `surface` card and tap-to-start
/// behavior otherwise (C5.7b) — a `Button`, same as `TemplateRow`, unlike
/// the C5.4/C5.5-era version of this row.
private struct CardioRow: View {
  let activityType: String
  let title: String
  let isCompact: Bool
  let isDisabled: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 13) {
        ZStack {
          Circle()
            .fill(cardioActivityTint(for: activityType).opacity(0.18))
            .frame(width: 40, height: 40)
          Image(systemName: cardioActivityIcon(for: activityType))
            .foregroundColor(cardioActivityTint(for: activityType))
        }
        Text(title)
          .font(.body)
          .fontWeight(.bold)
          .foregroundColor(LifeyColors.onSurface)
          .lineLimit(1)
          .truncationMode(.tail)
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .background(LifeyColors.surface)
    .clipShape(RoundedRectangle(cornerRadius: LifeyShapes.card))
  }
}

/// The row that opens the "all activity types" screen — deliberately the
/// quietest card on the picker (no accent fill, a chevron instead of an
/// icon circle): the ranked list above is the fast path, this is the
/// completeness guarantee behind it.
private struct AllTypesRow: View {
  let isDisabled: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 13) {
        Text("standalone_all_types")
          .font(.body)
          .foregroundColor(LifeyColors.onSurfaceVariant)
          .lineLimit(1)
        Spacer(minLength: 0)
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(LifeyColors.onSurfaceVariant)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .background(LifeyColors.surface)
    .clipShape(RoundedRectangle(cornerRadius: LifeyShapes.card))
  }
}

/// Every activity type the phone offers, in its display order — the picker's
/// second page. Renders the same `CardioRow` and starts a session the same
/// way (`onTap` is `StandalonePickerView.cardioTapped` itself), so a type
/// reached here behaves identically to one that happened to rank into the
/// list on the previous screen.
///
/// No "Quick strength" card and no ranked entries: this screen answers
/// exactly one question ("what else can I start?"), and repeating the
/// picker's own rows would just make the two pages ambiguous.
private struct AllActivityTypesView: View {
  let entries: [CachedActivityType]
  let isDisabled: Bool
  let onBack: () -> Void
  let onTap: (String) -> Void

  var body: some View {
    GeometryReader { geometry in
      let isCompact = DynamicSizing.isCompact(width: geometry.size.width)
      let padding = geometry.size.width * DynamicSizing.screenPaddingFraction

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
            Text("standalone_all_types")
              .font(isCompact ? .title3 : .title2)
              .fontWeight(.heavy)
              .foregroundColor(LifeyColors.onSurface)
            Spacer(minLength: 0)
          }
          // Keyed by activity type, which really is unique here (the phone
          // builds this list from `kActivityTypes` itself), unlike the ranked
          // list's index keying.
          ForEach(entries, id: \.activityType) { entry in
            CardioRow(
              activityType: entry.activityType, title: entry.title, isCompact: isCompact,
              isDisabled: isDisabled
            ) {
              onTap(entry.activityType)
            }
          }
        }
        .padding(.horizontal, padding)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .background(LifeyColors.trueBlack)
    }
  }
}

#Preview {
  StandalonePickerView(onBack: {})
}
