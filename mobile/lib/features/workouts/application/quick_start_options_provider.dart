import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/activity_type.dart';
import '../domain/workout_template.dart';
import 'activity_ranking.dart';
import 'workout_session_controller.dart';
import 'workout_template_controller.dart';

/// A ranked [QuickStartEntry] joined against the user's actual templates —
/// [QuickStartEntry.templateClientId] on its own doesn't carry a name.
/// Mirrors `recommended_template_provider.dart`'s split (a pure ranking
/// function, then a Riverpod layer that resolves ids against real objects):
/// [rankQuickStartEntries] stays widget/Riverpod-free, this is the join.
///
/// [template] is non-null exactly when [entry] is a specific (non-freeform)
/// strength template *and* that template still exists — `null` with a
/// non-null [QuickStartEntry.templateClientId] means it was deleted after
/// being ranked; `quick_start_sheet.dart` falls back to a generic label for
/// that case rather than crashing on a stale id.
typedef ResolvedQuickStartEntry = ({QuickStartEntry entry, WorkoutTemplate? template});

/// The quick-start sheet's tiles (docs/cardio/59-cardio-implementation-plan.md
/// C2.7) — top entries by [rankQuickStartEntries], each resolved against
/// [workoutTemplateControllerProvider] for display.
///
/// Recomputes only when the session list or template list actually changes,
/// not on every rebuild — satisfying docs/cardio/53-cardio-mobile-plan.md
/// §3.4's "a rangsor csak session-befejezéskor... számolódik újra" for free:
/// a `Provider` only re-runs when a watched dependency emits a new value,
/// and neither controller stream emits without a real underlying change.
final quickStartEntriesProvider = Provider<List<ResolvedQuickStartEntry>>((ref) {
  final sessions = ref.watch(workoutSessionControllerProvider).value ?? const [];
  final templates = ref.watch(workoutTemplateControllerProvider).value ?? const [];
  final templatesById = {for (final t in templates) t.clientId: t};
  return [
    for (final entry in rankQuickStartEntries(sessions, now: DateTime.now()))
      (entry: entry, template: templatesById[entry.templateClientId]),
  ];
});

/// The display title for a [ResolvedQuickStartEntry] — the quick-start
/// sheet tile's headline (`quick_start_sheet.dart`), and (C2.11a) the
/// Android dynamic app-shortcut's `shortLabel` / the home-screen widget's
/// quick-start button text, so a shortcut or widget button always names the
/// exact same thing the sheet would have shown for that rank. Lives here
/// (application layer) rather than in the presentation-layer sheet so
/// core-layer consumers (`WidgetSnapshotWriter`, the shortcuts updater)
/// don't have to import a widget file to get it.
///
/// A deleted template (ranked once, since removed) falls back to the
/// generic "Strength" label — tapping starts an empty workout instead,
/// there's nothing left to start "from".
String quickStartEntryTitle(AppLocalizations l10n, ResolvedQuickStartEntry resolved) {
  final entry = resolved.entry;
  if (entry.isCardio) return activityTypeLabel(l10n, entry.activityType!);
  final template = resolved.template;
  if (template != null) return template.name;
  if (entry.templateClientId == null) return l10n.emptyWorkoutLabel;
  return l10n.activityTypeStrength;
}

/// Below this many completed sessions, the ranking hasn't seen enough usage
/// to mean anything yet — the quick-start sheet shows an explanatory banner
/// instead of presenting the (still mostly default-order) list as if it
/// were personalized. Matches the `design/Lifey Cardio Design.dc.html` M02
/// frame note: "amíg nincs elég adat a rangsorhoz (≥3 edzés)".
const quickStartColdStartThreshold = 3;

/// Whether the quick-start sheet should show the cold-start explainer.
final isQuickStartColdStartProvider = Provider<bool>((ref) {
  final sessions = ref.watch(workoutSessionControllerProvider).value ?? const [];
  final completed = sessions.where((s) => s.finishedAt != null).length;
  return completed < quickStartColdStartThreshold;
});
