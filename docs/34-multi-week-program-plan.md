# Multi-Week Program Builder Plan (Roadmap #14)

Goal: the trainer builds a named 4–12 week program — a week-by-week grid of
workout template slots — and assigning it to a client materializes every
scheduled session automatically, extending the existing schedule/assignment
model rather than replacing it.

## Current state

Backend (all in `com.lifey.trainer`):

* **Schedules** (`WorkoutSchedule`, V47): a single-template recurrence
  (ONCE/DAILY/WEEKLY, ≤ 3 months, ≤ 100 occurrences). Occurrences are
  materialized up front as plain `workout_sessions` rows (`scheduledFor` set,
  `startedAt` null, `scheduleId` pointing back). The client receives them via
  the normal delta sync — nothing on mobile knows about schedules beyond the
  nullable `scheduleId` column it stores but never branches on.
* **Assignments** (`ContentAssignment`): deep-copies a trainer template/recipe
  to the client (`ContentAssignmentServiceImpl.assign`), reusing existing
  copies of shared exercises. `WorkoutScheduleServiceImpl.resolveClientTemplate`
  makes scheduling an *implicit* assignment: reuse the client's live copy of
  the exact trainer template, else deep-copy via `assign()`.
* **Cancellation**: cancelling a schedule soft-deletes its future, not-started
  occurrences; `ScheduleCancellationListener` does the same for the whole
  trainer–client pair on `TrainerClientRevokedEvent`.
* Occurrence status is derived, not stored
  (`WorkoutScheduleServiceImpl#occurrenceStatus`): CANCELLED (deletedAt) /
  DONE (startedAt) / MISSED (past) / UPCOMING.
* **Downstream consumers of occurrences**:
  * Workout reminder push (`findReminderCandidates`) keys on `scheduledFor`
    only — schedule-agnostic, works for any materialized occurrence.
  * Compliance overview's `countMissedOccurrences` **joins on
    `s.scheduleId = ws.id`** — anything not born from a `WorkoutSchedule` is
    invisible to it today.
  * Weekly report email counts by `startedAt`/`finishedAt` — occurrence-source
    agnostic.
* Latest Flyway migration: **V58**.

Web (`web/src/features/trainer`):

* `/admin/workouts` lists trainer templates; `ScheduleWorkoutDrawer` creates a
  schedule (client, recurrence, days, time, dates); `ClientScheduleTab` lists
  a client's schedules (`ScheduleList`) + occurrence timeline
  (`ScheduleTimeline`); `/admin/calendar` renders `TrainerCalendar`
  (month/week/agenda views + `CalendarSessionPeek`), all fed by
  `trainerApi.*` endpoints in `api.ts`.

Mobile:

* Zero program awareness needed. Scheduled sessions arrive through the
  existing `workout_sessions` delta sync; the UI treats `scheduledFor != null`
  as "scheduled" and never branches on `scheduleId`
  (`mobile/lib/features/workouts/domain/workout_session.dart` stores it only).
  Program-generated occurrences are indistinguishable from schedule-generated
  ones on the phone.

## Design decisions

**A program is a trainer-owned reusable definition; an assignment is a
materialized snapshot.** Two concerns, two aggregates:

* `TrainingProgram` + `ProgramWorkout` — the reusable blueprint (name, weeks,
  a grid of week × day → template slots). Owned by the trainer like a
  template, soft-deletable.
* `ProgramAssignment` — the fact "this program was started for this client on
  this date", with a denormalized `programName` so history survives program
  deletion/rename. Occurrences are generated once, at assign time; later
  edits to the program's *structure* do not retro-edit an in-flight
  assignment (same snapshot semantics schedules already have). Edits to a
  slot template's *content* still reach the client through the existing
  live-copy propagation (`propagateTemplateUpdate`), because occurrences
  point at the client's template copy.

**Occurrences stay plain `workout_sessions` rows, with a new nullable
`program_assignment_id` alongside `schedule_id`.** This is the "extends the
existing model" requirement made literal: everything that keys on
`scheduledFor` (mobile sync, reminder push, trainer calendar, client
scheduled-sessions timeline, weekly report) works for program occurrences
with **zero changes**. A session's origin is now one of: own (both null),
schedule, or program assignment. No CHECK constraint forbidding both being
set — the code never sets both, and the constraint would complicate nothing
worth protecting.

*Rejected alternative*: generating one ONCE `WorkoutSchedule` per slot per
week. It would reuse more code but produce up to 84 schedule rows per
assignment, make "cancel the program" a multi-row dance, and pollute the
client's schedule list UI.

**Week grid: at most one workout per (week, day) cell.** Keeps the builder a
simple grid, keeps the occurrence count ≤ 12 × 7 = 84, comfortably under the
existing `MAX_OCCURRENCES = 100` sanity cap and inside the 3-month horizon
philosophy (12 weeks = 84 days ≤ 92). Two-a-days can be a later relaxation.

**`weeksCount` 1–12; the roadmap's "4–12" is a UI default, not a server
rule.** The hard cap of 12 falls out of the horizon/occurrence caps; a
2-week intro block is harmless and forbidding it buys nothing. The builder
UI defaults the picker to 4–12.

**Start date must be a Monday.** Weeks are Mon–Sun; occurrence date =
`startDate + (weekNumber − 1) × 7 + dayOffset`. Anchoring to Monday makes
the mapping trivial and unambiguous (no "week 1's Monday is already in the
past" cases). The assign drawer defaults to the next Monday. Validation:
Monday, not in the past — mirrors `ScheduleInPastException`.

**Assign-time template resolution reuses the schedule path.** For each
*distinct* template in the program, resolve the client's copy exactly like
`resolveClientTemplate` does today (reuse live copy, else deep-copy via
`ContentAssignmentService.assign`, which also writes the `content_assignments`
fact row). The helper moves from `WorkoutScheduleServiceImpl` to
`ContentAssignmentService` (e.g. `resolveClientCopy(trainerId, clientId,
template)`) so both call sites share it. Templates referenced by the program
are validated non-deleted at assign time; a deleted one fails the whole
assignment (it's one transaction) with an error naming the slot.

**One active assignment of a program per client.** Re-running a finished or
cancelled program later is allowed (progressive blocks get repeated);
overlapping duplicates are not. "Active" = `cancelledAt` null and
`endDate >= today`.

**Cancellation mirrors schedules.** Cancelling an assignment stamps
`cancelledAt` and soft-deletes its future, not-started occurrences (copy of
`WorkoutScheduleServiceImpl.cancel`). `cancelOccurrence` learns to authorize
via `programAssignmentId` when `scheduleId` is null.
`ScheduleCancellationListener` additionally cancels the pair's active program
assignments on revoke.

**Compliance counts program occurrences too.** `countMissedOccurrences` gets
a sibling query joining `program_assignments` (or the existing query is
rewritten to a union over both origins); `ComplianceBadges` needs no change —
the number just becomes correct.

**Progression between weeks = per-week structure + per-slot note.** Templates
carry no weights (only `targetSets`), so numeric auto-progression has nothing
to act on. What the trainer actually needs: week 3 can point at a different
(heavier) template than week 1, the builder can duplicate a week as the next
week's starting point, and each slot takes an optional trainer-facing note
("top set +2.5 kg"). Notes live on `program_workouts` and show in the builder
and the assignment detail — they are *not* pushed to the client's session (a
client-visible note would need a new synced session column; out of scope,
listed below).

## Milestones

### M1 — Migration + domain (backend)

`V59__training_programs.sql`:

```sql
create table training_programs (
    id          bigserial primary key,
    user_id     bigint not null references users (id),   -- the trainer
    name        varchar(120) not null,
    weeks_count int not null,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    deleted_at  timestamptz,
    constraint training_programs_weeks check (weeks_count between 1 and 12)
);
create index training_programs_user_idx on training_programs (user_id) where deleted_at is null;

create table program_workouts (
    id           bigserial primary key,
    program_id   bigint not null references training_programs (id),
    week_number  int not null,                 -- 1-based, <= weeks_count
    day_of_week  varchar(3) not null,          -- ISO abbreviation, 'MON'..'SUN' (same codes as workout_schedules.days_of_week)
    template_id  bigint not null references workout_templates (id),  -- trainer's own template
    time_of_day  time,
    note         varchar(500),                 -- trainer-facing progression note
    constraint program_workouts_slot_unique unique (program_id, week_number, day_of_week),
    constraint program_workouts_week check (week_number >= 1)
);

create table program_assignments (
    id            bigserial primary key,
    program_id    bigint not null references training_programs (id),
    trainer_id    bigint not null references users (id),
    client_id     bigint not null references users (id),
    program_name  varchar(120) not null,       -- snapshot, survives program rename/delete
    start_date    date not null,               -- always a Monday
    end_date      date not null,               -- start_date + weeks*7 - 1
    assigned_at   timestamptz not null default now(),
    cancelled_at  timestamptz
);
create index program_assignments_trainer_idx on program_assignments (trainer_id, client_id);

alter table workout_sessions add column program_assignment_id bigint references program_assignments (id);
create index workout_sessions_program_idx on workout_sessions (program_assignment_id)
    where program_assignment_id is not null;
```

Entities (`trainer/entity/`): `TrainingProgram`, `ProgramWorkout` (List on the
program, `orphanRemoval` for full-replace edits), `ProgramAssignment` — all
extend `BaseEntity`. `WorkoutSession` gains `programAssignmentId` (plain
`Long`, same reasoning as `scheduleId`). Repositories:
`TrainingProgramRepository`, `ProgramAssignmentRepository`; new
`WorkoutSessionRepository` count/find methods keyed on
`programAssignmentId` (mirror the four `scheduleId` ones).

### M2 — Program CRUD (backend)

`TrainingProgramService`/`Impl` + `TrainingProgramController`:

* `POST /api/v1/trainer/programs` — create. Body: `name`, `weeksCount`,
  `workouts[] {weekNumber, dayOfWeek, templateId, timeOfDay?, note?}`.
  Validation: weeks 1–12, every `weekNumber <= weeksCount`, no duplicate
  (week, day) slot, at least one slot, every template owned by the trainer
  and not deleted.
* `GET /api/v1/trainer/programs` — list summaries: id, name, weeksCount,
  slots-per-week (distinct count), activeAssignmentCount.
* `GET /api/v1/trainer/programs/{id}` — full grid (slots carry template id +
  current template name, resolved live).
* `PUT /api/v1/trainer/programs/{id}` — full replace of name/weeks/slots
  (same full-overwrite style as `copyTemplateFields`); does not touch
  existing assignments.
* `DELETE /api/v1/trainer/programs/{id}` — soft delete. Allowed while
  assignments are in flight (they are materialized snapshots); the program
  just disappears from the builder list.

Exceptions follow the existing pattern (`trainer/exception/`, e.g.
`ProgramNotFoundException`, `InvalidProgramStructureException`).

### M3 — Assignment + occurrence generation (backend)

`ProgramAssignmentService`/`Impl` + controller endpoints:

* `POST /api/v1/trainer/programs/{id}/assignments` — body `{clientId,
  startDate}`. Flow (one transaction, mirroring `WorkoutScheduleServiceImpl.create`):
  1. `requireActiveClient`; program owned by trainer, not deleted, has slots.
  2. `startDate` is a Monday, not in the past; no overlapping active
     assignment of this program for this client.
  3. For each distinct template: validate not deleted, resolve the client
     copy (shared helper, see Design decisions).
  4. Insert `program_assignments` row (endDate = startDate + weeks×7 − 1,
     programName snapshot).
  5. For each slot: insert a `WorkoutSession` occurrence (`user` = client,
     `scheduledFor` computed, `scheduledTime` = slot time, `template` +
     `templateName` = client copy, `programAssignmentId` set).
  * Response: assignmentId, programName, startDate, endDate, occurrenceCount.
* `GET /api/v1/trainer/clients/{clientId}/program-assignments` — summaries
  with derived progress: done/missed/remaining occurrence counts (the
  `scheduleId`-count queries cloned for `programAssignmentId`), plus
  cancelledAt.
* `DELETE /api/v1/trainer/program-assignments/{id}` — cancel (see Design
  decisions).

Cross-cutting edits in the same milestone:

* `WorkoutScheduleServiceImpl.cancelOccurrence` — authorize program
  occurrences via `ProgramAssignmentRepository.findByIdAndTrainerId`.
* `ScheduleCancellationListener` — also cancel active program assignments
  for the revoked pair.
* `countMissedOccurrences` — include program-origin occurrences (second
  query summed in `ComplianceService`, or a rewritten union query).
* `ScheduledSessionResponse` / `TrainerCalendarSessionResponse` — add
  nullable `programAssignmentId` (and `programName` on the calendar
  response for the peek), populated from the session row + a batch lookup.

### M4 — Program builder (web)

* New route `/admin/programs`: program list (cards: name, weeks, slots/week,
  active assignments) + create button. New nav entry in the admin layout.
* `/admin/programs/[programId]`: the builder — a weeks × Mon–Sun grid.
  Cell interactions: pick one of the trainer's templates (reuse the template
  list already fetched for `/admin/workouts`), optional time, optional note;
  clear cell. Week-level actions: "duplicate week below", "copy week 1 to
  all". Save = `PUT` full replace. Client-side mirror of the server
  validation (slot ≤ weeksCount, unique slots).
* `api.ts` + `types.ts` additions; `messages/` hu + en strings; unit tests
  for the grid-state reducer and the occurrence-date math kept in a pure
  module (pattern: `compliance.ts` + `compliance.test.ts`).

### M5 — Assign + monitor (web)

* `AssignProgramDrawer` (pattern: `ScheduleWorkoutDrawer`): client picker,
  start-date picker constrained to Mondays (default next Monday), summary
  line ("48 sessions over 12 weeks, until 5 Oct"), confirm. Entry points:
  the program card/builder page and the client detail Schedule tab.
* `ClientScheduleTab`: a "Programs" section above the schedule list —
  program name, week progress ("week 5 / 12"), done/missed/remaining
  counts, cancel action. Occurrences already show up in the existing
  `ScheduleTimeline` (they come from the same endpoint); label program-origin
  rows with the program name.
* `CalendarSessionPeek` / calendar views: show the program name badge when
  `programAssignmentId` is present.

### M6 — Optional: "program assigned" push

Reuse the established per-type push pattern (docs/30/31/32): one push to the
client on assignment ("Your trainer started you on *Hypertrophy Block*,
first session Mon 14 Jul"), new `UserSettings` opt-out boolean + settings
toggle row + `PushTapHandler` route to the workouts tab. Independent of
M1–M5; ship if time allows.

## Edge cases

* **Template soft-deleted after program creation** — assignment fails
  atomically with a clear error naming the slot; the builder marks the cell
  as broken on next load (template name resolves to "deleted").
* **Client already owns a copy of a slot template** (earlier assignment or
  schedule) — reused, not duplicated (existing `origin_trainer_id` +
  `origin_source_id` lookup).
* **Same template in many slots** — resolved once per assignment; one
  `content_assignments` fact row at most (the duplicate-assignment guard in
  `assign()` is bypassed by the reuse path, same as schedules today).
* **Trainer edits program mid-flight** — in-flight assignments unchanged by
  design; only future assignments pick up the new structure. Template
  *content* edits still propagate to the client copy (existing behavior).
* **Client revoked mid-program** — listener cancels the assignment; past
  occurrences (done/missed) survive as history, same as schedules.
* **Program deleted with active assignments** — assignments keep working
  (snapshot + `program_name` denormalized); only the blueprint is gone.
* **Occurrence collision** — a program day landing on an existing scheduled
  session is allowed (schedules can already overlap each other); the calendar
  simply shows both.
* **Weekly report / reminder push / mobile** — no changes needed; all key on
  `scheduledFor`/`startedAt`. Verify in M3 tests that reminder candidates
  include program occurrences.

## Testing

Backend (existing patterns: service tests with Testcontainers/mocks per
current suite):

* `ProgramOccurrenceGenerator`-style pure date-math tests: slot → date
  mapping, Monday anchoring, end-date arithmetic, 84-occurrence max.
* Service tests: create/update validation matrix (weeks bounds, orphan slot
  weeks, duplicate slots, foreign template); assign happy path (counts, copy
  reuse, fact rows), non-Monday start, past start, duplicate active
  assignment, deleted template, cancel (future-only soft delete), revoke
  listener, `cancelOccurrence` on a program occurrence, compliance count
  includes program misses.
* Controller slice tests for auth guards (`requireActiveClient`, ownership).

Web: vitest for grid reducer + date summary helpers; one Playwright flow if
the e2e suite covers trainer paths (build 2-week program → assign → see
occurrences in client tab + calendar).

## Out of scope (deliberate)

* Client-visible per-session notes (needs a new synced `workout_sessions`
  column + mobile UI — separate slice if wanted).
* Auto-progression of loads/reps (templates carry no load targets).
* Multiple workouts per day per program; programs longer than 12 weeks.
* Pausing/shifting an in-flight assignment (cancel + re-assign covers v1).
* Program sharing between trainers / template marketplace.

## Suggested order & sizing

M1+M2 (domain + CRUD) → M3 (assignment engine, the risky core) → M4
(builder UI, the largest UI piece) → M5 (assign/monitor UI) → M6 (optional
push). M1–M3 are shippable behind the absence of UI; M4–M5 make the feature
real. Rough effort split: backend 40%, web 50%, mobile 0%, push 10%.
