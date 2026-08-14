import 'dart:math' as math;

import '../domain/activity_type.dart';
import '../domain/workout_session.dart';

/// One key in the quick-start ranking — either a specific strength template
/// (or the "freeform strength" bucket when [templateClientId] is null), or
/// a cardio activity type. Never both at once (see the named constructors).
///
/// This is the single ranking unit shared by every consumer
/// (docs/cardio/53-cardio-mobile-plan.md §3.4, D-C.8): the quick-start sheet
/// (C2.7), the Android/iOS app-shortcut updater (C2.11), and the watch
/// picker payload (docs/cardio/55-cardio-watch-plan.md §3, C5.3). None of
/// them duplicate the ranking logic — they all call [rankQuickStartEntries].
class QuickStartEntry {
  const QuickStartEntry.strength([this.templateClientId]) : activityType = null;
  const QuickStartEntry.cardio(String this.activityType) : templateClientId = null;

  /// Strength only (`activityType == null`). `null` here means the
  /// freeform "no template" bucket — every template-less strength session
  /// collapses into this single entry, same as
  /// `activityTypeLabel(l10n, 'STRENGTH')`'s existing mixed-list sentinel.
  final String? templateClientId;

  /// Cardio only — one of [kActivityTypes]; `null` for a strength entry.
  final String? activityType;

  bool get isCardio => activityType != null;

  @override
  bool operator ==(Object other) =>
      other is QuickStartEntry &&
      other.templateClientId == templateClientId &&
      other.activityType == activityType;

  @override
  int get hashCode => Object.hash(templateClientId, activityType);

  @override
  String toString() => isCardio
      ? 'QuickStartEntry.cardio($activityType)'
      : 'QuickStartEntry.strength(${templateClientId ?? "freeform"})';
}

/// A workout done this many days ago counts for half of one done today
/// (docs/cardio/53-cardio-mobile-plan.md §3.4) — the list follows the
/// user's *current* routine instead of freezing on whatever they did most a
/// year ago.
const _halfLifeDays = 21.0;

/// The default fill order for a cold start (too little history to rank
/// [max] real entries) — matches the `design/Lifey Cardio Design.dc.html`
/// M02 frame (C2.7's assigned frame) exactly for its first four tiles:
/// running and walking first, *then* freeform strength, then the indoor
/// bike — M02's own rationale is "a két GPS-es típus előre, mert azokat nem
/// lehet utólag rekonstruálni" (the two GPS types come first, because they
/// can't be reconstructed after the fact). The remaining cardio types
/// (never shown in the M02 mockup — it only has 4 tiles) fill in after,
/// in the same GPS-first spirit: hiking is still a DISTANCE/GPS type, the
/// GAME types least so.
///
/// This is a **different** list from [_cardioTiebreakIndex] on purpose:
/// this one is what the UI shows when there's no real usage to rank yet;
/// that one is what breaks a genuine tie between two keys that *do* both
/// have real usage. Nothing requires them to agree, and per the M02 frame
/// they don't (strength sits 3rd here, but always wins a real tie against
/// cardio).
final List<QuickStartEntry> _defaultOrder = [
  const QuickStartEntry.cardio('RUNNING'),
  const QuickStartEntry.cardio('WALKING'),
  const QuickStartEntry.strength(),
  const QuickStartEntry.cardio('INDOOR_BIKE'),
  const QuickStartEntry.cardio('HIKING'),
  const QuickStartEntry.cardio('BASKETBALL'),
  const QuickStartEntry.cardio('FOOTBALL'),
  const QuickStartEntry.cardio('OTHER_CARDIO'),
];

QuickStartEntry _keyOf(WorkoutSession session) => session.isCardio
    ? QuickStartEntry.cardio(session.activityType!)
    : QuickStartEntry.strength(session.templateClientId);

/// The deep link a [QuickStartEntry] starts from — one gesture, no
/// intermediate screen (docs/cardio/59-cardio-implementation-plan.md
/// C2.11a/b, D-C2.2). Consumed by the Android dynamic app-shortcuts bridge,
/// the home-screen widget's quick-start buttons, and (C2.11b) iOS's
/// `UIApplicationShortcutItem`s — all three just need a URI, not the ranking
/// logic itself. `go_router`'s `onException` in `app_router.dart` parses it
/// back with [quickStartEntryFromDeepLinkUri].
///
/// `'STRENGTH'` for [QuickStartEntry.activityType] is a query-string
/// sentinel local to this URI shape, not a real [kActivityTypes] value
/// (mirrors the existing `'STRENGTH'` sentinel `activityTypeLabel` etc.
/// already accept) — chosen so a single `activity` param unambiguously
/// selects the cardio/strength branch without a separate `kind` param.
Uri quickStartDeepLinkUri(QuickStartEntry entry) {
  return Uri(
    scheme: 'lifey',
    host: 'workout',
    path: '/start',
    queryParameters: {
      'activity': entry.isCardio ? entry.activityType! : 'STRENGTH',
      if (entry.templateClientId != null) 'template': entry.templateClientId!,
    },
  );
}

/// The inverse of [quickStartDeepLinkUri] — `null` for anything that isn't a
/// recognized quick-start URI (wrong scheme/host/path, missing/unknown
/// `activity`), so the router can fall back to its normal "unrecognized
/// deep link" handling instead of crashing on a malformed or stale one (an
/// app-shortcut or widget button can outlive an app update that renamed
/// something).
QuickStartEntry? quickStartEntryFromDeepLinkUri(Uri uri) {
  if (uri.scheme != 'lifey' || uri.host != 'workout' || uri.path != '/start') {
    return null;
  }
  final activity = uri.queryParameters['activity'];
  if (activity == null) return null;
  if (activity == 'STRENGTH') {
    return QuickStartEntry.strength(uri.queryParameters['template']);
  }
  if (!kActivityTypes.contains(activity)) return null;
  return QuickStartEntry.cardio(activity);
}

/// Cardio-vs-cardio tie-break order (docs/cardio/53-cardio-mobile-plan.md
/// §3.4: "ha az is egyezik, a `kActivityTypes` megjelenítési sorrend") — a
/// strength entry always wins a tie against any cardio entry (`-1` sorts
/// first). Neither doc nor either frame (M01/M02) shows two *tied* entries
/// where one is strength, so that half of the rule is this file's own,
/// intentionally simple extrapolation, not a documented requirement.
int _cardioTiebreakIndex(QuickStartEntry entry) =>
    entry.isCardio ? kActivityTypes.indexOf(entry.activityType!) : -1;

/// Last-resort tiebreak so the result is fully deterministic even when two
/// *different* real templates end up with an identical score and an
/// identical last-used instant (score and recency are both real-world
/// values with no natural ordering between two distinct template ids) —
/// not something the doc specifies, but `List.sort` isn't guaranteed
/// stable, so leaving a genuine tie unresolved would make the ranking
/// nondeterministic between runs on the exact same input.
String _identityTiebreak(QuickStartEntry entry) =>
    '${entry.templateClientId ?? ''} ${entry.activityType ?? ''}';

/// Recency-weighted usage ranking over the user's sessions, newest first.
/// Half-life: 21 days (see [_halfLifeDays]).
///
/// - **Key**: [_keyOf] — the cardio activity type, or the strength
///   template's clientId (`null` = freeform, one shared bucket).
/// - **Score**: `Σ 0.5^(days / 21)` over that key's *completed*
///   ([WorkoutSession.finishedAt] non-null) sessions — an in-progress
///   session carries no usage signal yet.
/// - **Tie-break**: more recent last use wins; still tied →
///   [_cardioTiebreakIndex]; still tied (only possible between two
///   distinct real templates) → [_identityTiebreak], purely for
///   determinism.
/// - **Cold start**: if real usage yields fewer than [max] entries, the
///   list is padded from [_defaultOrder] (skipping anything already
///   ranked) so it's never shorter than the caller asked for while any
///   default entries remain.
///
/// [sessionsDesc] order doesn't matter — every session is scored
/// independently by its own [WorkoutSession.finishedAt], not by list
/// position. The name matches [WorkoutSessionController]'s existing
/// newest-first convention, the shape every real caller already has.
List<QuickStartEntry> rankQuickStartEntries(
  List<WorkoutSession> sessionsDesc, {
  required DateTime now,
  int max = 8,
}) {
  final scores = <QuickStartEntry, double>{};
  final lastUsed = <QuickStartEntry, DateTime>{};

  for (final session in sessionsDesc) {
    final finishedAt = session.finishedAt;
    if (finishedAt == null) continue;
    final key = _keyOf(session);
    final days = math.max(0.0, now.difference(finishedAt).inMilliseconds / Duration.millisecondsPerDay);
    final weight = math.pow(0.5, days / _halfLifeDays).toDouble();
    scores[key] = (scores[key] ?? 0) + weight;
    final currentLast = lastUsed[key];
    if (currentLast == null || finishedAt.isAfter(currentLast)) {
      lastUsed[key] = finishedAt;
    }
  }

  final ranked = scores.keys.toList()
    ..sort((a, b) {
      final byScore = scores[b]!.compareTo(scores[a]!);
      if (byScore != 0) return byScore;
      final byRecency = lastUsed[b]!.compareTo(lastUsed[a]!);
      if (byRecency != 0) return byRecency;
      final byTiebreak = _cardioTiebreakIndex(a).compareTo(_cardioTiebreakIndex(b));
      if (byTiebreak != 0) return byTiebreak;
      return _identityTiebreak(a).compareTo(_identityTiebreak(b));
    });

  for (final entry in _defaultOrder) {
    if (ranked.length >= max) break;
    if (!ranked.contains(entry)) ranked.add(entry);
  }

  return ranked.take(max).toList();
}
