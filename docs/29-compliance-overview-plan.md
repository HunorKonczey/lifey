# Compliance Overview Plan (Roadmap #12)

Goal: let a trainer see at a glance which clients are slipping — without
opening each client detail page. Two surfaces on the web admin dashboard:

1. **Flags + sorting on the client list** — days since last log, missed
   scheduled workouts, weight not logged.
2. **"Needs attention" section** — flagged clients pulled to the top of the
   dashboard with the reason spelled out.

Guiding constraint from the roadmap: *all required data already exists —
aggregation only*. No new tables, no Flyway migration, no mobile changes.
The backend returns raw compliance facts (timestamps + one count); all
thresholds, flag logic and sorting are presentation concerns on the web.

## Current state

Backend:

* `GET /api/v1/trainer/clients` (`TrainerClientController` →
  `TrainerAccessServiceImpl.findActiveClientsForTrainer()`) already enriches
  each client per-row: 8-point weight trend, `assignedPlanCount`,
  `workoutsPerWeek` (28-day window). The enrichment pattern (a few small
  queries per client, trainer-scale list sizes) is established — compliance
  fields slot into the same method.
* Missed-workout semantics already exist:
  `WorkoutScheduleServiceImpl.occurrenceStatus()` derives `MISSED` =
  `startedAt == null && deletedAt == null && scheduledFor < today`, and
  `ScheduleSummaryResponse` already carries a per-schedule `missedCount`.
  What's missing is a per-client count across schedules, scoped to *this*
  trainer, over a recent window.
* Log sources and their "when" fields:
  * meals — `Meal.dateTime` (`Instant`)
  * weight — `WeightEntry.date` (`LocalDate`) + `recordedAt`
  * workouts — `WorkoutSession.startedAt` (`Instant`)
  * water — `WaterEntry.consumedAt` (`Instant`)
  * steps — `DailyStepCount.date` (auto-imported from HealthKit)
* All of these are soft-deleted (`deletedAt`) — queries must filter it.

Web:

* `admin/page.tsx` renders `ClientCard`s in a grid, ordered by the backend
  default (`respondedAt` desc). No sorting UI, no flags.
* `ClientCard` already shows sparkline + two stat chips — a natural place
  for warning badges.
* i18n via `next-intl` (`messages/en.json` / `hu.json`), `admin.dashboard`
  namespace.

## Definitions (shared vocabulary)

**Last activity** (`lastActivityAt`): the max of the client's latest meal
`dateTime`, latest weight `recordedAt`, latest workout `startedAt`, and
latest water `consumedAt` — non-deleted rows only. **Steps are deliberately
excluded**: step counts are auto-imported from HealthKit, so they measure
that the phone moved, not that the client engaged with the app. HealthKit-
*imported workouts* do count (they land as workout sessions and reflect real
training).

**Missed workouts** (`missedWorkoutCount`): scheduled occurrences belonging
to *this trainer's* schedules for this client where `startedAt IS NULL AND
deletedAt IS NULL AND scheduledFor < today`, restricted to a trailing
window of the **last 14 days** (`scheduledFor >= today − 14d`). Window
rationale: old misses from a month ago shouldn't keep a now-compliant
client flagged forever; 14 days covers "missed something this week or
last". Trainer-scoped so a client with two trainers doesn't leak the other
trainer's misses.

**Last weight** (`lastWeightAt`): the client's newest non-deleted
`WeightEntry.date`. Already effectively fetched — the weight-trend query
returns the newest 8 entries; the newest one's date is `lastWeightAt`
(no extra query).

Raw facts cross the API; the web derives:

* `daysSinceLastLog = daysBetween(max(lastActivityAt, activeSince), now)` —
  falling back to `activeSince` gives brand-new clients a grace period
  instead of an immediate "never logged" flag.
* `daysSinceWeight` — same fallback with `activeSince`.

## Backend plan

### B1 — Repository queries (latest-log lookups)

New derived/`@Query` methods, all filtering `deletedAt IS NULL`:

* `MealRepository`: `Optional<Instant> findMaxDateTimeByUserId(Long userId)`
  (`select max(m.dateTime) …`).
* `WorkoutSessionRepository`:
  `Optional<Instant> findMaxStartedAtByUserId(Long userId)`.
* `WaterEntryRepository`:
  `Optional<Instant> findMaxConsumedAtByUserId(Long userId)`.
* Weight: no new query — reuse the trend fetch already in
  `toEnrichedClientResponse` (last point of the pre-reverse list).

These are `max()` aggregates over indexed-by-user tables — cheap.

### B2 — Missed-workout count query

`WorkoutSessionRepository` (or `WorkoutScheduleRepository`, whichever reads
better — the join spans both):

```java
@Query("""
    select count(s) from WorkoutSession s, WorkoutSchedule ws
    where s.scheduleId = ws.id
      and ws.trainer.id = :trainerId
      and s.user.id = :clientId
      and s.startedAt is null
      and s.deletedAt is null
      and s.scheduledFor >= :windowStart
      and s.scheduledFor < :today
    """)
long countMissedOccurrences(Long trainerId, Long clientId,
        LocalDate windowStart, LocalDate today);
```

The predicate must stay semantically identical to
`WorkoutScheduleServiceImpl.occurrenceStatus()`'s `MISSED` branch — add a
comment cross-referencing it so the two don't drift.

### B3 — Extend `TrainerClientResponse`

```java
public record TrainerClientResponse(
        Long clientId,
        String clientEmail,
        Instant activeSince,
        List<WeightTrendPoint> weightTrend,
        int assignedPlanCount,
        int workoutsPerWeek,
        // compliance (roadmap #12) — raw facts, thresholds live on the web
        Instant lastActivityAt,      // null = never logged anything
        LocalDate lastWeightAt,      // null = never logged weight
        int missedWorkoutCount       // trainer-scoped, last 14 days
) {}
```

Wire through `TrainerClientMapper.toClientResponse(...)` and
`TrainerAccessServiceImpl.toEnrichedClientResponse(...)`:

* `lastActivityAt` = max of the three B1 lookups + the newest weight's
  `recordedAt` (nulls skipped; all-null → null).
* `MISSED_WORKOUT_WINDOW_DAYS = 14` as a class constant next to
  `WORKOUTS_PER_WEEK_WINDOW_DAYS`.

This adds ~4 queries per client on top of the existing 3. The list already
runs per-client queries and a trainer has tens of clients, not thousands —
acceptable. If it ever shows up in profiling, the follow-up is batching
each metric into one `group by user_id` query over the client-id set (note
this in a code comment, don't build it now).

No new endpoint, no API version bump: additive response fields only, and
the app is not released (no backward-compat concern).

### B4 — Backend tests

* Repository-level (Testcontainers): each `max()` query ignores soft-deleted
  rows and returns empty for a user with no data; missed-count query —
  respects the window, excludes started/cancelled occurrences, excludes
  another trainer's schedules for the same client.
* Service-level: `findActiveClientsForTrainer` returns correct
  `lastActivityAt` (max across sources, null when nothing logged) and
  `missedWorkoutCount`.

## Web plan

### W1 — Types + pure compliance logic

* Extend `TrainerClientResponse` in `features/trainer/types.ts` with the
  three new fields.
* New `features/trainer/compliance.ts` — pure, vitest-able:

```ts
export const INACTIVITY_FLAG_DAYS = 3;
export const WEIGHT_STALE_FLAG_DAYS = 7;

export interface ComplianceFlags {
  daysSinceLastLog: number;   // vs max(lastActivityAt, activeSince)
  daysSinceWeight: number;    // vs max(lastWeightAt, activeSince)
  missedWorkouts: number;
  inactive: boolean;          // daysSinceLastLog >= INACTIVITY_FLAG_DAYS
  weightStale: boolean;       // daysSinceWeight >= WEIGHT_STALE_FLAG_DAYS
  hasMissedWorkouts: boolean; // missedWorkouts >= 1
  needsAttention: boolean;    // any of the above
}

export function complianceFor(client: TrainerClientResponse, now: Date): ComplianceFlags;
```

Thresholds are constants here (single source for card badges, the
needs-attention section and sorting). Making them trainer-configurable is a
non-goal for now.

### W2 — Flags on `ClientCard`

* A compact badge row (only when flagged, so healthy cards stay clean):
  * `schedule` icon — "3 days inactive" (inactive flag)
  * `event_busy` icon — "2 missed workouts" (hasMissedWorkouts)
  * `monitor_weight` icon — "no weight for 8 days" (weightStale)
* Warning styling via the existing `--error` / warning-ish token palette
  (match whatever the design tokens offer — subtle chip, not a red alarm;
  the needs-attention section is the loud surface).
* Cards keep working with zero flags — no layout shift for compliant
  clients beyond the absent row.

### W3 — "Needs attention" dashboard section

* On `admin/page.tsx`, above the client grid: a section rendered only when
  at least one client has `needsAttention`.
* Header: warning icon + "Needs attention" + count.
* One compact row per flagged client: avatar, name, the concrete reasons as
  chips (reuse W2's badge component), whole row links to
  `/admin/clients/{id}`.
* Order: most severe first — sort by `daysSinceLastLog` desc, then
  `missedWorkouts` desc.
* Flagged clients still appear in the main grid below (the section is a
  spotlight, not a filter) — keeps the grid's mental model stable.

### W4 — Sorting the client list

* A small sort control next to the dashboard header (segmented control or
  select, matching existing admin UI patterns):
  * **Recent** (default — current `respondedAt` order from the backend)
  * **Least active first** (`daysSinceLastLog` desc)
  * **Most missed workouts** (`missedWorkouts` desc)
  * **Weight overdue** (`daysSinceWeight` desc)
* Pure client-side sort of the already-fetched list — no API params.
* Persist the choice in `sessionStorage` (same lightweight pattern as the
  dashboard's `MODAL_SEEN_KEY`).

### W5 — i18n

New keys in `messages/en.json` / `messages/hu.json` under
`admin.dashboard` (or an `admin.compliance` sub-namespace): section title,
badge labels with pluralization (`{count} days inactive`,
`{count} missed workouts`, `no weight for {count} days`), sort option
labels. Hungarian translations included in the same PR.

### W6 — Web tests

* vitest for `compliance.ts`: never-logged client (activeSince fallback /
  grace period), each flag threshold boundary, `needsAttention`
  composition, sort comparators.
* Component: `ClientCard` renders badges only when flagged; dashboard
  renders the needs-attention section only when someone is flagged.
* Optional Playwright e2e: seeded flagged client shows up in the section
  (only if the existing e2e seeding makes this cheap).

## Non-goals (deferred)

* Trainer-configurable thresholds — constants for now.
* Push/email nudges to inactive clients — that's roadmap #8/#16 territory.
* Compliance history/trend ("was flagged 3 of the last 4 weeks").
* Mobile/client-side changes of any kind — clients never see these flags.
* Batched aggregation queries — noted as a follow-up in B3, not built.
* A dedicated compliance endpoint — additive fields on the existing list
  response are enough.

## Edge cases

* **Brand-new client** — no logs at all: `lastActivityAt`/`lastWeightAt`
  null; the `activeSince` fallback means they only get flagged after the
  threshold days of the relationship, not instantly on accept.
* **Offline-first lag** — a client may have logged on the phone but not
  synced yet; the flag can be stale-positive. Acceptable: the trainer sees
  server truth, and the wording ("days since last log") stays honest.
* **Timezones** — `daysSince*` is computed in the trainer's browser from
  UTC instants; the missed-workout window uses the server's `LocalDate`,
  consistent with `occurrenceStatus()`. Off-by-a-few-hours around midnight
  is fine for a coarse "days" metric.
* **Client trains outside the schedule** — starts a blank session instead
  of the scheduled occurrence: the occurrence still counts as missed. This
  matches the existing calendar/schedule-summary semantics; the trainer
  sees the workout in `workoutsPerWeek` and the session list, so context is
  available.
* **Two trainers, one client** — missed counts are trainer-scoped (B2);
  activity/weight facts are inherently shared, which is correct (a log is
  a log).
* **Soft-deleted logs** — excluded everywhere (`deletedAt IS NULL`), so
  deleting your only meal really does reset `lastActivityAt`.
* **Revoked mid-window** — revoked clients don't appear in the list at
  all (existing behavior), so no special handling.

## Test plan summary

Backend: B4 (repository + service, Testcontainers). Web: W6 (vitest +
component). The pure `compliance.ts` module carries the threshold logic, so
most behavior is testable without a browser.

## Suggested PR split

1. **Backend — compliance facts on the client list** (B1–B4): additive
   response fields, independently mergeable; web ignores unknown fields.
2. **Web — flags, needs-attention, sorting** (W1–W6): depends on PR 1
   being deployed to whatever backend the web dev points at.

Rough effort: no schema, no sync, no mobile; the largest pieces are the
missed-count JPQL + tests on the backend and the needs-attention section
on the web.
