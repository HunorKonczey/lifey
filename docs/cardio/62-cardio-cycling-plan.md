# 62 – Cardio: Outdoor Cycling

Status: **A1–A6 and B1–B3 done — both milestones complete.**
Scope: backend · mobile · watch (Wear OS + watchOS)
Depends on: [51-cardio-overview-plan.md](51-cardio-overview-plan.md) (the `DISTANCE`/`MACHINE`/`GAME`
family model — shipped), [52](52-cardio-domain-backend-plan.md)/[53](53-cardio-mobile-plan.md)/
[54](54-cardio-gps-route-plan.md)/[55](55-cardio-watch-plan.md) (backend, mobile, GPS, watch — all
shipped, C0–C5), [60-cardio-sport-specifics-plan.md](60-cardio-sport-specifics-plan.md) (precedent for
type-specific decisions like PR eligibility and dominant-metric choice).

> **Not to be confused with C7 / `INDOOR_BIKE`.** [51 §3.3](51-cardio-overview-plan.md) and
> [60 §4](60-cardio-sport-specifics-plan.md)'s C7 cover the **stationary** bike (`MACHINE` family:
> power, cadence, resistance, an interval editor — no GPS). This doc is a **new, seventh
> `ActivityType`** — outdoor/road/city cycling — joining the `DISTANCE` family alongside running,
> walking and hiking. The two share the "bicikli" name in Hungarian and nothing else in the schema.

---

## 1. What we're building

A `CYCLING` activity type, added to the existing `DISTANCE` family. A user can start, live-track,
and log a plain outdoor bike ride from the same infrastructure C0–C5 already built for running:
quick-start, `CardioSessionScreen`'s distance layout, GPS route recording, km-splits, elevation
gain, heart-rate zones and best-effort windows all apply to `CYCLING` **the moment the enum value
exists** — they're already generic over the `DISTANCE` family, not `RUNNING`-specific (verified in
code: `cardio_session_screen.dart`'s `isDistanceFamily` gate at the splits/best-effort call site,
not an `activityType == 'RUNNING'` one).

Two real gaps do **not** come for free and this plan closes them:

1. **The GPS speed filter would silently break cycling.** `track_filter.dart`'s `DISTANCE`-family
   default caps plausible speed at 30 km/h (running's ceiling) — ordinary road-cycling speed
   exceeds that on flats, let alone descents. Every fix above the cap gets rejected as an
   implausible jump, which quietly under-counts distance exactly the way
   [54](54-cardio-gps-route-plan.md)'s own opening comment warns an unfiltered stream can
   over-count it — same failure mode, opposite direction, and just as silent.
2. **Pace doesn't mean anything on a bike.** Every `DISTANCE`-family session shows pace (min/km)
   today — including walking and hiking, where a `CardioFormatter.speed()` function already exists
   in the codebase for exactly this purpose but is never called anywhere. Cycling needs speed
   (km/h) as its live/summary readout; this is the plan's excuse to finally wire that function up,
   scoped to `CYCLING` only.

**V1 boundary — what happens if this ships and nothing further does:** cadence (rpm) and power (W)
stay unavailable for outdoor cycling, the same as they are for running today — the app has no
sensor-pairing story for any activity yet, indoor bike included (its rpm/W are keyboard-entered,
see [51 §3.3](51-cardio-overview-plan.md)). Best efforts reuse running's 1/5/10 km windows rather
than cycling-native distances. Both are explicit non-goals below, not oversights.

---

## 2. Key design decisions

### 2.1 `CYCLING` joins `DISTANCE`, not a new family

| Option | Evaluation |
|---|---|
| **A**: a fourth family (`CYCLING_OUTDOOR`) with its own metric set/layout | Would need a new `CardioSessionScreen` layout, a new design pass, new live-metrics branches everywhere `ActivityFamily` is switched over (7+ call sites). Nothing about outdoor cycling actually needs different metrics than running: time, distance, route, splits, elevation, HR zones all apply unchanged. |
| **B**: `CYCLING` is a fifth `DISTANCE` member | **This decision.** Reuses every C0–C5 screen, calculator and sync path pixel-for-pixel. Cost is one enum line plus taxonomy-map entries (§4 Cyc-A), not a design-canvas round-trip — unlike C6–C9, this plan needs no new frames because it introduces no new UI shape. |

### 2.2 Speed (km/h), not pace (min/km), is cycling's headline number

`CardioFormatter.speed()` (`mobile/lib/core/format/cardio_formatter.dart:92`) already exists,
already documents itself as "the DISTANCE/MACHINE alternative to pace, used for walking/hiking/the
indoor bike" — and is called from **nowhere** in the app. Every current pace display
(`cardio_session_screen.dart:1038`, `:1812`, `:2360`; `cardio_summary_screen.dart:862`, `:886`,
`:1274`, `:1570`) runs off `CardioFormatter.pace()` uniformly for the whole `DISTANCE` family,
walking and hiking included. That's a pre-existing simplification this plan does not fix — RUNNING/
WALKING/HIKING keep exactly their current behavior. `CYCLING` is the one type that gets branched
onto `.speed()`, because at cycling speeds pace reads as a nonsensical small number (a 25 km/h ride
is "2:24 /km", not a readout anyone parses at a glance) where the walking/hiking case at least
produces a plausible-looking, if arguably wrong, number.

### 2.3 Best efforts and PR eligibility: extend the existing gate, don't build cycling-native ones

`computeBestEfforts(trail)` already runs for every `DISTANCE` session
(`cardio_session_screen.dart:1436`'s `isDistanceFamily` gate) — `CYCLING` gets `best1k/5k/10kSeconds`
populated the moment the enum exists, no new column, no new migration. The only place that
currently *narrows* this to running is the PR-celebration eligibility check,
`cardio_personal_record.dart:68`:

```dart
fastest1k || fastest5k || fastest10k => session.activityType == 'RUNNING',
```

**Decision:** widen this one line to `session.activityType == 'RUNNING' || session.activityType ==
'CYCLING'`. A 1/5/10 km best effort is a meaningful number for a casual/commuter cyclist too. What
this deliberately does **not** do: touch `WALKING` or `HIKING` (unchanged — they still store best
efforts but never celebrate them, matching today's behavior), or add cycling-native benchmark
distances (10/20/40 km time-trial splits) — real, but separate work (§5 Non-goals).

### 2.4 A dedicated `TrackFilterProfile` for `CYCLING`

`track_filter.dart:43`'s `trackFilterProfileFor` falls through to the running/hiking default (30
km/h ceiling, 20 m accuracy) for any unmatched code today — which is exactly the branch `CYCLING`
would silently hit without this step. **Decision:** an explicit `CYCLING` case with a higher speed
ceiling (proposed **70 km/h** — covers ordinary descents with headroom, without being so loose it
stops filtering GPS jump artifacts) and the same 20 m accuracy threshold as running.

### 2.5 The `cardioAvgPace` statistics metric is not touched, on purpose

`stat_chart_data.dart:126`/`:266` gates that metric on an explicit `activityType == 'RUNNING' ||
activityType == 'WALKING'` allowlist — not on `ActivityFamily`. Adding `CYCLING` to the taxonomy
does **not** silently pull it into this average (unlike a family-based gate would have). A
cycling-relevant average-speed statistic is real future work, but it's a new `StatMetric`, not a
widened allowlist on this one — mixing bike and foot speeds into one number would misrepresent
both.

---

## 3. Icon, color, string

- Icon: `Icons.directions_bike` — distinct from indoor bike's `Icons.pedal_bike`
  (`activity_type.dart:86`).
- Color: `colorScheme.secondary` (warm brown), **not** `mc.protein` as originally proposed here —
  implementation found `AppMetricColors.light.protein` (`app_tokens.dart:93`) is the exact same hex
  as `app_theme.dart`'s `inversePrimary` (`0xFF586E38`), i.e. `protein` *is* the app's primary
  accent. That's precisely the collision the existing code comment already documents hiking
  avoiding by using `colorScheme.tertiary` instead — cycling hits the same wall and takes the same
  way out, borrowing `colorScheme.secondary` since every `AppMetricColors` slot is otherwise
  already claimed (`calories`→running, `steps`→walking, `tertiary`→hiking, `carbs`→indoor bike,
  `fat`→basketball, `water`→football, `weight`→strength).
- l10n keys: `activityTypeCycling` — HU "Kerékpározás", EN "Cycling". Add via the
  `localization` skill (both ARB files, ICU-consistent with the existing `activityType*` keys).

---

## 4. Order of work

Two independently mergeable milestones. Cyc-A alone is a working, shippable feature — cycling would
just display pace (an odd number, not a broken one) until Cyc-B lands.

### Milestone Cyc-A — Outdoor cycling exists end to end

| # | Step | Files | Done-when |
|---|---|---|---|
| **A1** ✅ | Backend: add `CYCLING(ActivityFamily.DISTANCE)` | `backend/.../cardio/ActivityType.java:15-29` | **Done.** No migration needed, as predicted. `WorkoutSessionServiceImplTest` extended with `create_cyclingSession_persistsActivityTypeAsCyclingInDistanceFamily`; full suite green (45/45). |
| **A2** ✅ | Mobile taxonomy: add `'CYCLING'` everywhere `activity_type.dart` switches by code | `mobile/lib/features/workouts/domain/activity_type.dart`: `kActivityTypes` (27-35), `activityFamilyOf` (42-49, → `distance`), `activityTypeLabel` (66-77), `activityTypeIcon` (81-92), `activityTypeColor` (104-117), `locationTrackingProfileFor` (56-60, → `precise`, same as running/hiking) | **Done.** Also caught and fixed: `_defaultOrder`-style position-dependent test finders (`activity_picker_screen_test.dart`, `log_cardio_sheet_test.dart`) that assumed `Basketball`/`STRENGTH TEMPLATES` were within a lazy `ListView`'s initial build/cache extent — CYCLING's insertion pushed them one slot further and broke `ensureVisible`, which (unlike `scrollUntilVisible`) requires the target `Element` to already exist. Fixed by scrolling explicitly instead of assuming visibility (see Edge cases). `activity_type_test.dart`, `activity_picker_screen_test.dart`, `log_cardio_sheet_test.dart` all green; `flutter analyze` clean. |
| **A3** ✅ | Mobile GPS: `CYCLING` branch in the speed/accuracy filter | `mobile/lib/features/workouts/domain/track_filter.dart:43-77` | **Done.** 70 km/h ceiling, 20 m accuracy (same as running). `track_filter_test.dart` got a profile test plus a paired regression case: a ~45 km/h / 4 s segment is retained under `CYCLING` and, in a second test, explicitly shown to be **rejected** under `RUNNING`'s ceiling — proving both that the fix works and what the silent failure would have looked like without it. Full `test/features/workouts/` suite green (844/844); `flutter analyze` clean. |
| **A4** ✅ | Mobile quick-start: add `CYCLING` to the cold-start default order | `mobile/lib/features/workouts/application/activity_ranking.dart:68-79` (`_defaultOrder`) | **Done.** Placed right after `HIKING` (both "still DISTANCE/GPS" per the file's own ordering rationale), before the GAME types. `activity_ranking_test.dart` got a dedicated cold-start test asserting the padded order through `CYCLING`; a stale comment in the `completion` test (claiming `BASKETBALL` was "6th" in the default order) was also fixed to "7th" now that `CYCLING` sits ahead of it. Full `test/features/workouts/` + `test/core/home_screen_widget/` suites green (851/851); `flutter analyze` clean. |
| **A5** ✅ | Watch — Wear OS: activity-type, family, icon, and color maps | `ExerciseService.kt:524-535` (`cardioExerciseType`, `"CYCLING" -> ExerciseType.BIKING`), `SessionStateHolder.kt:36-40` (`cardioActivityFamily` comment only — the `else -> DISTANCE` default already covered `CYCLING` correctly), `ui/ActiveWorkoutScreen.kt:275-299` (`cardioActivityIcon`/`cardioActivityTint`), `ui/theme/LifeyColors.kt:71-87` | **Done.** `ExerciseType.BIKING` confirmed to exist in `health-services-client:1.0.0` (`javap` against the resolved `.aar`, distinct from `INDOOR_BIKE`'s `BIKING_STATIONARY`). Icon/color maps also needed a `CYCLING` entry — missed by the original plan, which only listed the exercise-type map — mirroring the mobile Flutter taxonomy: `Icons.AutoMirrored.Filled.DirectionsBike` (not `Icons.Filled.DirectionsBike`, which turned out to be **hidden**, not just deprecated, in `material-icons-extended:1.7.8` — a genuine "unresolved reference" compile error, not a style nit) and `LifeyColors.secondary` (reusing the existing warm-brown constant, mirroring the mobile `colorScheme.secondary` decision from A2). No unit-test harness exists for this module (confirmed — no test sources under `android/wear/`); verified instead with `./gradlew :wear:compileDebugKotlin` (BUILD SUCCESSFUL, no new warnings). On-device/emulator verification of the actual recorded `ExerciseType` remains manual, as originally planned. |
| **A6** ✅ | Watch — watchOS (Mac-required): activity-type + location-type maps in both duplicated tables, **plus** the icon/tint maps A5's Wear-OS equivalent turned out to need | `mobile/ios/LifeyWatch/WorkoutManager.swift:64-107`, `mobile/ios/Runner/WatchBridge.swift:336-369` (`cardioWorkoutActivityType`/`cardioLocationType`, both files), `mobile/ios/LifeyWatch/Views/ActiveWorkoutView.swift:160-185` (`cardioActivityIcon`/`cardioActivityTint`), `mobile/ios/LifeyWidgets/WorkoutLiveActivity.swift:207-217` (`cardioActivitySymbol`, the Live Activity's own third copy), `mobile/ios/LifeyWatch/Theme/LifeyColors.swift:77-87` | **Done.** `CYCLING` and `INDOOR_BIKE` **share** `HKWorkoutActivityType.cycling` — HealthKit has no separate outdoor-cycling constant (confirmed: Apple's own `.cycling` case covers both), so only `cardioLocationType`'s `.outdoor` case tells them apart — unlike Wear OS, where Health Services genuinely does have two distinct `ExerciseType` constants (A5's `BIKING` vs `BIKING_STATIONARY`). Icon: `figure.outdoor.cycle` (not `bicycle`, which stays `INDOOR_BIKE`'s) — verified to actually resolve via a standalone `NSImage(systemSymbolName:)` check (`swift /tmp/sfcheck.swift`) before use, not guessed; it's the same symbol Apple's own Fitness app uses for outdoor cycling. Color: `LifeyColors.secondary` (`0xC49A6C`), reusing the same existing constant as the Flutter/Wear-OS decisions. All three touched targets built clean: `xcodebuild -target LifeyWatch -sdk watchsimulator`, `-target LifeyWidgets -sdk iphonesimulator`, and the full `Runner` scheme via `-workspace Runner.xcworkspace -scheme Runner -sdk iphonesimulator` — **BUILD SUCCEEDED** on all three, no new warnings. |

### Milestone Cyc-B — Cycling reads right, not just runs right

| # | Step | Files | Done-when |
|---|---|---|---|
| **B1** ✅ | Wire `CardioFormatter.speed()` into the live session screen, `CYCLING`-only | `mobile/lib/features/workouts/presentation/cardio_session_screen.dart` — `_cardioLiveMetrics`'s `ActivityFamily.distance` case (Live Activity payload), `_distanceBody` (the on-screen pace/speed tile, weak-signal blanking kept for both), `_finishSummaryLine` (the M12 finish-confirmation line) | **Done.** New ARB key `speedLabel` ("SPEED"/"SEBESSÉG"). Widget test added to `cardio_session_screen_distance_test.dart`: a `CYCLING` session shows "SPEED"/"30.0 km/h", never "PACE"/"/km"; every existing `RUNNING`/`WALKING`/`HIKING` assertion in the file still passes unchanged. |
| **B2** ✅ | Same swap on the summary screen | `mobile/lib/features/workouts/presentation/cardio_summary_screen.dart` — the metric-grid pace tile, the best-effort section's per-row value, **and** the km-split chart's section header + average-line (`_averagePaceLabel`) — a fourth site the original plan's four line numbers pointed at but didn't fully account for: swapping the value alone would have left a "PACE PER SPLIT" header captioning a chart full of km/h numbers | **Done.** New ARB key `speedSectionLabel` ("SPEED PER SPLIT"/"SEBESSÉG SZAKASZONKÉNT") alongside `speedLabel`. Three widget tests added to `cardio_summary_screen_test.dart`: metric-grid speed display, split-chart header + `"avg 18.0 km/h"` average line, both with an explicit `findsNothing` check against the pace wording they replace. |
| **B3** ✅ | Extend PR eligibility to `CYCLING` (§2.3) | `mobile/lib/features/workouts/domain/cardio_personal_record.dart:68` | **Done.** Traced the full call graph first (`detectCardioPrs`, `CardioPrBaseline.fromSessions`/`.extend`) to confirm this one-line `appliesTo` gate is the *only* place eligibility is decided — the PR-celebration value formatter already showed `fastest1k/5k/10k` as a plain duration ("3:12"), not a pace string, so it needed no change at all. `cardio_personal_record_test.dart` got a positive case ("cycling sets these records too... unlike walking/hiking above") placed right next to the existing walk/hike negative cases it's meant to contrast with. |

---

## 5. Non-goals (deferred)

- **Cadence (rpm) or power (W) for outdoor cycling.** No sensor-pairing exists for any activity in
  this app yet, indoor bike's rpm/W included (keyboard-entered per [51 §3.3](51-cardio-overview-plan.md)).
  HealthKit does expose `.cyclingCadence` (noted in [60](60-cardio-sport-specifics-plan.md)'s C6.5
  writeup, where it's why *running* cadence had to be step-derived instead) but that only helps once
  there's a live source to read from — a later iteration, not this one.
- **Cycling-native best-effort distances** (10/20/40 km time trials) — real value for a road
  cyclist, but a new calculator + new columns, not a reuse of running's 1/5/10 km windows.
- **A cycling-specific average-speed statistics metric/chart** (§2.5) — `cardioAvgPace` stays
  untouched; a `cardioAvgSpeed` `StatMetric` is separate, later work.
- **Sub-typing** (road / gravel / mountain / e-bike) — one `CYCLING` type covers all outdoor biking
  for V1, the same granularity `RUNNING` gets.
- **Retrofitting speed-not-pace to `WALKING`/`HIKING`** — out of scope here, called out only because
  the dead `CardioFormatter.speed()` code half-implies someone once intended it. A separate decision
  if it happens.

---

## Edge cases

- **Indoor bike and outdoor cycling both map to `HKWorkoutActivityType.cycling`** — only
  `locationType` (`.indoor` vs `.outdoor`) tells them apart on watchOS. Missing `CYCLING` from
  either half of A6's two switches doesn't crash; it silently mislabels location context, not type
  (or vice versa) — see Risk checkpoints.
- **GPS denied on a `CYCLING` start.** Falls back to manual distance entry exactly like running
  does today — this is a family-level behavior ([D-C.5](51-cardio-overview-plan.md#2-alapdöntések-d-c1--d-c9)),
  not new state to build for cycling specifically.
- **A pre-A6 watch app** (already installed, not yet updated) receiving a `CYCLING` session from a
  post-A2 phone: hits the existing "any future/unknown code" fallback both watch platforms already
  established for forward-compatibility (`CardioActivityFamily.init`'s `default: self = .distance`
  on watchOS, `ExerciseType.WORKOUT` on Wear OS) — verify this path still holds rather than assuming
  it does, since A6 changes the same switch statements.
- **Any `kActivityTypes`-driven scrollable list gets one slot longer.** Discovered while doing A2:
  a widget test that finds a chip/row by text/type without scrolling only works because it happens
  to land within the list's initial build/cache extent — a plain `ListView` (including
  `.separated`/horizontal ones, like `log_cardio_sheet.dart`'s type-chip row) only builds `Element`s
  for what's visible plus a small cache margin, *even when its `children` are a literal list, not
  `.builder`*. Adding `CYCLING` pushed `BASKETBALL` and the strength-templates section one slot
  past that margin in two existing tests, and `ensureVisible` (which needs the element to already
  exist) started throwing "No element" where `scrollUntilVisible` (which scrolls first, then
  re-queries) does not. Any future `kActivityTypes` addition should expect the same class of
  failure in whichever tests assume a fixed position near the edge of a picker's default viewport.
- **A session logged as `CYCLING` before Cyc-B ships**, viewed after Cyc-B ships: its live/summary
  numbers are computed at render time from stored distance/duration, not stored as
  pre-formatted pace — so existing `CYCLING` sessions display correctly in speed once B1/B2 land,
  with no backfill needed.

---

## Test plan

- **Backend:** `WorkoutSessionServiceImplTest` — a `CYCLING` session creates, updates, and reads back
  with the same DTO shape as `RUNNING`.
- **`track_filter_test.dart`:** new `CYCLING`-profile case with a >30 km/h, <70 km/h segment,
  asserting it survives filtering (the direct regression test for §2.4).
- **`activity_type_test.dart`:** `CYCLING` covered by every label/icon/color/family switch —
  extend whatever exhaustiveness pattern the existing six cases already use.
- **`activity_ranking_test.dart`:** `CYCLING` present in the cold-start default order (§A4).
- **`cardio_personal_record_test.dart`:** `CYCLING` best effort produces a PR; `WALKING`/`HIKING`
  with identical numbers does not (§B3, negative case matters as much as the positive one).
- **Widget tests:** live session screen and summary screen for a `CYCLING` session render "km/h",
  not "min/km" (§B1/B2); a `RUNNING` session's rendering is byte-identical to its current snapshot
  (regression, not just "still shows something").
- **Watch:** manual device/emulator check for Wear OS (A5, Windows-capable); watchOS simulator build
  + manual check for A6 (Mac-required, the plan's only Mac step).

---

## Suggested PR split

1. **Milestone Cyc-A** as one PR — backend enum, mobile taxonomy, GPS profile, cold-start order, and
   both watch platforms. Every piece is a mechanical extension of an already-established six-way
   pattern, not new design; splitting it further would just fragment one coherent taxonomy change.
2. **Milestone Cyc-B** as a second, independent PR — speed display + PR eligibility. Depends on
   Cyc-A existing (needs `CYCLING` sessions to exist) but ships whenever convenient after it.

---

## Risk checkpoints — where a bug would be silent

- **§2.4 / A3 — GPS speed ceiling.** Get the cap wrong (too low) and nothing errors: distance just
  quietly under-counts on fast segments, the same failure mode [54](54-cardio-gps-route-plan.md)'s
  own opening comment already warns an unfiltered stream produces in the *other* direction. A wrong
  number in a ride summary, not a crash.
- **§A6 — the two duplicated watchOS tables (closed).** `cardioWorkoutActivityType`'s `default:` branch
  returns `.traditionalStrengthTraining`; `cardioLocationType`'s `default:` branch returns `.indoor`.
  Leaving `CYCLING` out of either switch in either file produces a **valid-looking** HealthKit
  workout with the wrong type or wrong location — not a crash, and not something a screenshot review
  would catch. Both files must move together; [60](60-cardio-sport-specifics-plan.md)'s C6.5 writeup
  is the precedent for what a missed HealthKit-side gap costs to find later.
- **§A4 — cold-start quick-start order.** Omitting `CYCLING` from `_defaultOrder` doesn't crash the
  picker; cycling simply never appears as a suggested quick-start entry until a user has already
  logged enough rides for usage-based ranking to surface it — close to "never," for a brand-new
  type, and the kind of gap that only shows up as "why can't I find cycling" support noise.
- **§2.3 / B3 — PR eligibility.** If this gate is ever widened by family instead of by the explicit
  `RUNNING || CYCLING` allowlist, `WALKING` and `HIKING` sessions would silently start producing PR
  celebrations from best-effort windows never intended to be compared for those activities — a
  product regression that reads as a new feature, not a bug, until someone asks why a walk got a
  "personal record."

---

## After implementation

- Update this doc's `Status:` line, and add a one-row entry to [cardio/README.md](README.md)'s
  reading-order table pointing here.
- If Cyc-B's speed/pace decision (§2.2) prompts a broader look at walking/hiking's own pace display,
  open that as its own doc rather than folding it in here retroactively.
