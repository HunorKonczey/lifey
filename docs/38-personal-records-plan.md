# Personal Records (PR) Plan (Roadmap #3)

Goal: detect a new personal record the moment a set is saved during a
session — max weight, max reps at a weight, estimated 1RM — celebrate it
with the existing workout-success pop-up pattern, and list the PR history
on the exercise detail screen.

Guiding constraint: **no backend changes, no schema changes, no sync
changes, no persisted PR state**. Every set already lives in the local
Drift `exercise_sets` table (full history arrives with the initial pull),
so records are **pure derivations recomputed from set history on every
read** — same philosophy as `37-streaks-weekly-recap-plan.md`. Derivation
is self-healing: an edited or deleted old set, or another device's sets
landing via sync, silently corrects the record; a persisted PR row could
silently go stale.

## Current state

* The exercise detail screen already computes and shows a "personal
  record" stat card: best estimated 1RM over all sets via the Epley
  formula (`_epley` in `exercise_detail_screen.dart:112`, card at :220).
  What's missing there is the **history** (when records were broken), not
  the current record.
* Set saving is incremental: marking a row done stamps `doneAt`
  (`log_session_screen.dart:390`) and triggers `_persist()` (auto-save).
  This is the natural PR-detection moment — not session finish.
* The celebration pattern exists: `computeWorkoutProgress` +
  `WorkoutSuccessDialog` (`workout_success_dialog.dart`), shown from
  `_finishWorkout` when the user improved in ≥ 2 metrics vs the previous
  session. It already renders per-exercise rows with green gain chips and
  a confetti burst — PRs slot into it as a new row type.
* Per-exercise history lookup precedent:
  `WorkoutSessionRepository.getPreviousPerformance` joins `exercise_sets`
  × `workout_sessions` with an `excludeSessionClientId` filter — the PR
  baseline query follows the same shape.
* `ExerciseBlock.previousSets` is filled asynchronously per block after
  the screen builds (`_loadPreviousPerformance`) — the PR baseline piggy-
  backs on the same load so no extra lifecycle is needed.

## PR definitions

For a single exercise, comparing a candidate set against all **earlier**
sets (see Baseline below):

| Record             | New PR when                                                            |
|--------------------|------------------------------------------------------------------------|
| Max weight         | `weight` > highest weight ever lifted (any reps ≥ 1)                    |
| Reps at weight     | `reps` > most reps ever done at this **exact** weight                   |
| Estimated 1RM      | Epley `weight × (1 + reps / 30)` > best e1RM ever                       |

Rules:

* **Epley moves to the domain layer** (`domain/one_rep_max.dart` or on the
  PR engine) and the detail screen's private `_epley` is replaced with it —
  one formula, one owner.
* **Reps-at-weight requires prior sets at that exact weight** — otherwise
  every never-before-used weight would trivially be a "reps PR". Exact
  double equality is fine: weights come from the same parsed text inputs,
  not arithmetic.
* **Weight-0 (bodyweight) sets** are excluded from max-weight and e1RM
  records (a 0 kg e1RM is meaningless); reps-at-weight still applies
  (most push-ups at 0 kg is a real record).
* **No baseline → no PR.** The first session ever logged for an exercise
  celebrates nothing: with an empty history every set is trivially a
  "record", which is noise, not motivation. Concretely: a record type
  only fires when the corresponding baseline value exists.
* One set can break several record types at once — that is **one** PR
  moment with multiple type chips, not three celebrations.

### Baseline

`PrBaseline` per exercise = best max-weight / best e1RM / reps-by-weight
map over all sets **excluding the current session** (same exclusion
mechanic as `getPreviousPerformance`). Within the session, a candidate
set is compared against `max(baseline, best earlier done set in this
session)` — so 100 kg then 105 kg in one workout are two PR moments, but
logging 100 kg twice is one.

## Mobile plan

Everything lives in the existing `lib/features/workouts/` feature — PRs
are a workout concern, not a new feature folder.

### M1 — PR engine (domain)

* `domain/personal_record.dart`:
  * `enum PrType { maxWeight, repsAtWeight, estimatedOneRm }`
  * `class PrBaseline { final double? maxWeight; final double? bestOneRm;
    final Map<double, int> maxRepsByWeight; }` with
    `PrBaseline.fromSets(Iterable<({double weight, int reps})>)` and a
    `merge`/`extend(set)` so the in-session running baseline is cheap.
  * `List<PrType> detectPrs(PrBaseline baseline, {required double weight,
    required int reps})` — pure, applies every rule above.
  * `List<PrEvent> computePrHistory(List<sets sorted by performedAt asc>)`
    — single forward pass appending an event whenever a record type's
    running best increases; feeds M5. `PrEvent = (PrType, weight, reps,
    performedAt)`.
* Epley extracted here; `exercise_detail_screen.dart` rewired to it.
* Fully unit-testable with synthetic sets, no DB/clock dependency.

### M2 — Baseline query (data)

* `WorkoutSessionRepository.getPrBaseline({required String
  exerciseClientId, String? excludeSessionClientId})` → `PrBaseline`.
  Reuses the `exercise_sets` × `workout_sessions` join of
  `_lastSessionSets` but aggregates over **all** matching sets (in Dart —
  a single exercise's lifetime set count is small).
* Loaded once per `ExerciseBlock` alongside `_loadPreviousPerformance`
  (one extra query per exercise at screen open / exercise add), stored on
  the block like `previousSets`. Null until loaded → detection simply
  stays silent for the first seconds, never celebrates against a
  half-loaded history.

### M3 — Live detection while logging (presentation)

* In `LogSessionScreen`, on the three paths that produce/alter a done row
  (mark done at `log_session_screen.dart:390`, edit of a done row,
  duplicate-as-done), run `detectPrs` against the block's running
  baseline.
* New PR on a row →
  * stamp the earned `PrType`s on the `SetRow` (in-memory, screen state
    like the rest of `SetRow`),
  * render a small **PR badge** on the row in `ExerciseSessionCard`
    (trophy icon + "PR" pill, amber — matching the trophy already used on
    the detail screen's PR stat card), with a one-shot scale-in animation
    (respect `disableAnimations`, like the success dialog does),
  * `HapticFeedback.mediumImpact()` — instant physical feedback without
    interrupting the logging flow (no dialog mid-workout; the full
    celebration belongs to the finish moment, M4).
* Reopening / editing / deleting rows recomputes the affected block's PR
  flags from scratch (baseline + current done rows) — flags are derived
  state, so they can never go stale or double-count.

### M4 — Finish celebration (success pop-up)

* `computeWorkoutProgress` (or a thin wrapper) additionally collects the
  session's PR moments per exercise from the blocks' PR flags.
* `WorkoutProgressResult` gains `records: List<WorkoutPrRow>`;
  `isSuccess` becomes `score >= 2 || records.isNotEmpty` — **any PR is a
  success on its own**, even in an otherwise flat workout.
* `WorkoutSuccessDialog` renders a PR section above the improvement rows:
  same row container, trophy icon instead of the up-arrow, chips like
  "105 kg", "12 × 80 kg", "e1RM 118 kg" (one chip per broken type).
  Title/subtitle copy switches to a PR-flavored variant when records
  exist ("New personal record!" / count-aware plural).
* No new dialog, no new trigger path — `_finishWorkout` already awaits
  `showWorkoutSuccessDialog`.

### M5 — PR history on the exercise detail screen

* New "PR history" section between the stat cards and "Recent sets",
  fed by `computePrHistory` over the already-watched
  `_setsForExerciseProvider` stream (no new query).
* One row per event, newest first, capped at ~10 with the same visual
  language as `_DaySetRow`: date + type chip + value ("Jul 12 · Max
  weight · 105 kg × 3"). Empty history → section hidden (no empty-state
  noise; the existing stat cards already communicate "no sets yet").
* The existing PR / e1RM stat cards stay as-is (they are the "current
  record" view; the new list is the "when" view).

### M6 — l10n

* New keys in `app_en.arb` / `app_hu.arb`: row badge ("PR"), dialog
  PR-title/subtitle (ICU plural), per-type chip labels ("max weight",
  "reps @ {weight} kg", "e1RM"), detail-screen section title, event row
  formats. Hungarian plural rules via ICU where counts appear.

## Non-goals (deferred)

* **Persisted PR table / backend surface** — derivation covers every
  listed use; a trainer-side "client hit a PR" feed would need backend
  aggregation and is a separate roadmap conversation.
* **Push/local notification on PR** — the in-session moment is the
  celebration; notifications add nothing when the user is already in the
  app.
* **PR types beyond the three listed** — no volume records, no rep-range
  (3RM/5RM) records; the engine is enum-driven so adding one later is a
  small diff.
* **Records for duration/distance exercises** — the set model is
  weight × reps only today; revisit if/when other set types exist.
* **Sharing / export of a PR** — out of scope.

## Edge cases

* **First-ever session for an exercise** — no baseline → silent (see PR
  definitions). The detail screen still shows the stat cards immediately.
* **Set edited downward / deleted after earning the badge** — block-level
  recompute (M3) clears or reassigns flags; the finish dialog reads the
  final flags, so it can never celebrate a set that was later corrected.
* **Deleting a historic session after the fact** — detail-screen history
  and stat cards recompute from the watch stream (may retroactively
  *create* a "new" current record); nothing to migrate — the decisive
  argument for derivation.
* **Same weight logged with float noise** — weights are parsed from text
  input and compared by value; no arithmetic is ever performed on them
  before comparison, so exact equality holds. (Epley results are compared
  only against other Epley results.)
* **Apple Health imported sessions** — they carry no sets, so they can
  neither earn nor block PRs. Correct by construction.
* **Another device's sets syncing mid-session** — the baseline is
  snapshotted at block load; a PR earned against a stale baseline stays
  visually stamped for this session (acceptable: celebrating twice across
  two devices is a cosmetic, self-limiting issue), while the detail
  screen's derived history is always eventually correct.
* **Trainer-scheduled session started later than another session**
  — baseline uses `performedAt`/`startedAt` ordering, not creation order,
  so out-of-order logging compares against what was truly "before".
* **Editing an old (finished) session** — same screen, same code paths;
  baseline excludes the edited session itself, so its own old sets don't
  block re-earning flags. The finish dialog isn't reshown for finished
  sessions (existing behavior), so no re-celebration.
* **weight = 0** — reps-at-weight only (see PR definitions).

## Test plan

* **Unit — engine**: `detectPrs` per type: strictly-greater semantics
  (equal ties are not PRs); no-baseline suppression per type;
  reps-at-weight requires prior sets at that weight; weight-0 exclusions;
  multi-type single set; in-session running baseline (100 → 105 two
  events, 100 → 100 one).
* **Unit — history**: `computePrHistory` forward pass: event order,
  interleaved types, plateau produces no events, history over unsorted
  input is rejected or sorted (pick one, test it).
* **Unit — progress**: `isSuccess` true on records alone with score 0;
  existing score-based trigger unchanged.
* **Repository**: `getPrBaseline` on a seeded DB — excludes the current
  session, spans templates, respects nothing else (records are
  template-agnostic, unlike `getPreviousPerformance`).
* **Widget**: PR badge appears on mark-done and disappears on reopen/edit-
  down; success dialog renders the PR section and PR-flavored copy;
  detail screen shows history rows and hides the section when empty.

## Suggested PR split

1. **Engine + baseline + live badge** (M1–M3, M6 partial): the in-session
   detection moment, unit tests included.
2. **Finish celebration + detail-screen history** (M4–M5, M6 rest):
   builds on PR 1's flags and engine; independent review surface.

Rough effort: no schema, no API, no sync changes; the largest pieces are
the success-dialog extension and the row-badge state handling in
`LogSessionScreen`.
