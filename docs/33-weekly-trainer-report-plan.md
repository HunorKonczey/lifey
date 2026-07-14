# Weekly Trainer Report Email Plan (Roadmap #16)

Goal: every trainer automatically receives a **weekly email digest** — one
email, one section per active client — summarizing the past week:
completed workouts, calorie goal adherence, and weight change.

Roadmap constraint: *mail module already exists* — this is aggregation +
one new email template + one scheduled job. No mobile changes at all.

## Current state

Backend:

* **Mail module** (`mail/`): `MailService` is intent-based
  (`sendWelcomeEmail`, `sendPasswordResetEmail`, `sendTrainerInviteEmail`);
  `ResendMailService` sends via the Resend HTTPS API, `@Async` on
  `mailTaskExecutor`, failures caught and logged (a bounced email never
  fails the caller), no-ops with a log line when `lifey.mail.enabled=false`.
  `MailTemplateRenderer` is deliberately `String.replace` on
  `{{placeholder}}` tokens over `src/main/resources/mail/*_{en,hu}.{html,txt}`
  files. `MailLanguageResolver` picks EN/HU from the recipient's
  `UserSettings.language` (missing row → EN).
* **Scheduled-job pattern** established three times:
  `TrainerClientCleanupJob` + `PasswordResetTokenCleanupJob` (fixed server
  cron), `WorkoutReminderJob` (15-min tick + user-local time + injected
  `Clock`). `@EnableScheduling` is on `LifeyApplication`.
* **All three report metrics have data + query precedent:**
  * Completed workouts — `WorkoutSession.startedAt` / `finishedAt`;
    `countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual` exists
    (open-ended, needs a range variant).
  * Calories vs goal — `MealRepository.sumCaloriesSince` (JPQL aggregate
    over `MealEntry × Food`; open-ended, needs a range variant) +
    `UserSettings.dailyCalorieGoal` on the client.
  * Weight change — `WeightEntryRepository` has range and newest-first
    queries; the trainer dashboard already reads them.
  * Missed workouts — `WorkoutSessionRepository.countMissedOccurrences(
    trainerId, clientId, windowStart, today)` from docs/29, trainer-scoped,
    takes an arbitrary window.
* **Day-boundary convention**: `StatisticsServiceImpl.zoneForUser` /
  `WorkoutReminderJob` compute user-local days from
  `User.utcOffsetMinutes`. The report must follow the same convention.
* **Per-client enrichment pattern** (a few small queries per client,
  trainer-scale lists): `TrainerAccessServiceImpl.toEnrichedClientResponse`.
  The weekly job runs at the same scale, once a week, off-peak.
* Trainers-with-clients lookup: `TrainerClientRepository` has per-trainer
  queries but no "all trainers having ≥1 ACTIVE client" query yet.
* Latest Flyway migration: **V57** (on this branch).

Web:

* The admin has no settings surface at all
  (`(admin)/admin/{page,clients,calendar,…}`) — the opt-out toggle (W2)
  is the first, so it should be as small as possible.
* i18n via `next-intl` (`messages/en.json` / `hu.json`).

Mobile: not involved. The report goes to the **trainer**, who lives on the
web admin; the email preference deliberately stays out of the mobile
`/settings` round-trip (see Design decisions).

## Definitions (shared vocabulary)

All ranges are the **previous ISO week**: Monday 00:00 (inclusive) to the
next Monday 00:00 (exclusive), computed **in the client's zone**
(`utcOffsetMinutes`) for activity metrics — consistent with
`StatisticsServiceImpl` — so a Sunday-evening meal doesn't leak into the
wrong week for a client far from UTC.

Per client section:

* **Completed workouts** — non-deleted sessions with `startedAt` in the
  week **and `finishedAt` not null**. Started-but-abandoned sessions don't
  count as completed (unlike `workoutsPerWeek`, which counts starts —
  that's a pace metric, this is an achievement metric). HealthKit-imported
  workouts have `finishedAt` and count.
* **Missed workouts** — `countMissedOccurrences` over the report week,
  scoped to *this* trainer's schedules. Not in the roadmap bullet, but the
  query exists and "did 3, skipped 2" is far more useful to a trainer than
  "did 3" — one reused call, included.
* **Calorie adherence** — per local day: `daysLogged` (calorie sum > 0),
  `daysWithinGoal` (0 < sum ≤ `dailyCalorieGoal`), `avgCalories` (mean
  over logged days, rounded). Shown as "5/7 days logged · 4 within goal ·
  avg 2 150 kcal". No goal set → adherence omitted, only
  "5/7 days logged · avg 2 150 kcal". The goal is treated as a ceiling,
  matching the remaining-budget-view semantics (docs/28).
* **Weight change** — `current` = newest non-deleted entry with `date`
  inside the week; `baseline` = newest entry with `date` before the week
  start. Change = `current − baseline`, one decimal, signed
  ("−0.4 kg"). No entry in the week → "no weigh-in this week". No
  baseline → fall back to oldest-in-week vs newest-in-week; single entry →
  weight shown, change omitted.

## Design decisions

**One digest email per trainer, not one email per client.** The roadmap
says "weekly summary per client" — that's the granularity of the
*content*, not the delivery. A trainer with 15 clients should get one
Monday-morning email with 15 sections, not 15 emails. One send per
trainer also keeps the failure blast radius per-trainer.

**Fixed server cron, Monday 05:00 UTC.** Unlike a push, an email doesn't
need to land at a user-local minute — it waits in the inbox. The
`WorkoutReminderJob` 15-min-tick + local-time machinery (plus a sent-at
marker for idempotency) is not worth it here; if trainer-local send time
is ever wanted, that job is the template. Consequence, accepted: if the
app happens to be down at the Monday firing, that week's report is
skipped (same "never carries over" stance as the workout reminder).

**Activity weeks are client-local, the send moment is not.** Metrics use
each client's `utcOffsetMinutes` day boundaries (the established
convention); at 05:00 UTC Monday the previous ISO week is over in every
timezone the app targets (Europe; even UTC−10 Monday 05:00 UTC is
Sunday 19:00 — edge accepted and noted below).

**Opt-out on `user_settings`, but *not* in the mobile DTOs.** New
`weekly_report_email_enabled boolean not null default true` (V58) on the
trainer's own settings row (trainers are `User`s; the row is lazily
created). It is deliberately **excluded** from `SettingsRequest`/
`SettingsResponse`/`SettingsMapper`: the mobile settings screen is a
client surface, the full-replace mobile save simply never touches the
column, and no Drift/sync plumbing is needed. The toggle gets a tiny
trainer-scoped endpoint instead (B4) — first divergence from the "every
settings field rides the mobile round-trip" pattern, justified because
this is the first *trainer-facing* preference.

**Clients with zero weekly activity stay in the digest.** "No activity
this week" is the single most valuable line for a trainer — omitting
quiet clients would hide exactly the people who need attention
(consistent with the compliance overview's purpose, docs/29).

**Row-fragment rendering, still no template engine.** The renderer's
`String.replace` approach can't loop. Rather than adding a dependency:
an outer template (`weekly_report_{en,hu}.{html,txt}`) with a
`{{clientRows}}` token, plus a per-client fragment template
(`weekly_report_row_{en,hu}.{html,txt}`) rendered once per client and
joined. Numbers are formatted in Java; the only free-text value is the
client display name (email local-part, same as `ResendMailService.
displayName`), which must be HTML-escaped before injection into the
HTML variant.

**Trainer's language decides the email language** via the existing
`MailLanguageResolver` — one language per digest, clients' languages are
irrelevant here.

**No sent-log table.** No `weekly_report_sent_at` tracking: the cron
fires once on the single app instance (the same assumption every existing
`@Scheduled` job makes). Duplicate-send protection becomes worth building
only with multiple instances — note it in the job's Javadoc, don't build
it.

## Backend plan

### B1 — Migration + entity

* Flyway `V58__user_settings_weekly_report_email.sql`:
  `alter table user_settings add column weekly_report_email_enabled
  boolean not null default true;`
* `UserSettings`: new boolean field, default `true`, Javadoc marking it
  **trainer-facing, not exposed to mobile** (opt-out: the trainer chose
  to have clients; a weekly summary of them is core value, and the email
  contains its own settings pointer).
* **No** `SettingsRequest`/`SettingsResponse`/`SettingsMapper` changes.

### B2 — Repository range queries

All filtering `deletedAt is null`, `from` inclusive / `to` exclusive
(the codebase's range idiom, see `MealRepository`):

* `MealRepository.sumCaloriesBetween(userId, from, toExclusive)` — copy
  of `sumCaloriesSince` with an upper bound. Called once per client-day
  (7×/client) — same per-client-small-queries scale as
  `toEnrichedClientResponse`; if it ever hurts, the follow-up is one
  `group by` day query (comment, don't build).
* `WorkoutSessionRepository.countCompletedBetween(userId, from,
  toExclusive)` — `count(s) … where s.startedAt >= :from and s.startedAt
  < :toExclusive and s.finishedAt is not null and s.deletedAt is null`.
* `WeightEntryRepository.
  findFirstByUserIdAndDeletedAtIsNullAndDateLessThanOrderByDateDescRecordedAtDesc(
  userId, weekStart)` — derived query for the baseline weight. In-week
  entries come from the existing `findByUserIdAndDeletedAtIsNullAndDateRange`.
* `TrainerClientRepository.findTrainerIdsWithActiveClients()` —
  `select distinct tc.trainer.id from TrainerClient tc where tc.status =
  com.lifey.trainer.TrainerClientStatus.ACTIVE`.
* Missed workouts: reuse `countMissedOccurrences(trainerId, clientId,
  weekStart, weekEndExclusive)` unchanged.

### B3 — Aggregation service + job

`trainer/service/WeeklyReportService` + `WeeklyReportServiceImpl`
(interface+impl per convention; lives in `trainer/` because it spans
trainer relationships + nutrition + weight + workout + settings, exactly
like `TrainerAccessServiceImpl`):

* `sendWeeklyReports(LocalDate anyDayOfPreviousWeek)` (or take the
  computed week start — implementer's choice, keep it `Clock`-testable):
  * `findTrainerIdsWithActiveClients()`; per trainer:
    * Opt-out gate: skip when the trainer's
      `weeklyReportEmailEnabled` is `false` (missing row → enabled, the
      established idiom).
    * `findByTrainerIdAndStatusOrderByRespondedAtDesc(trainerId, ACTIVE)`
      → per client, compute the section (Definitions above), using the
      client's `utcOffsetMinutes` for day/week instants.
    * Call `mailService.sendWeeklyTrainerReport(trainer, report)` — one
      call per trainer; the send itself is async and failure-swallowed in
      the mail layer, so one trainer's bounce never blocks the loop.
  * A trainer whose clients were all revoked since the id query — or a
    trainer with zero active clients — sends nothing.

Report data record, defined **in the `mail` package** (flat, next to
`MailLanguage`) so the dependency direction stays trainer → mail, same as
the invite email:

```java
public record WeeklyTrainerReport(
        LocalDate weekStart, LocalDate weekEnd,          // inclusive Mon..Sun
        List<ClientWeekSummary> clients) {
    public record ClientWeekSummary(
            String clientName,                            // email local-part
            int completedWorkouts, int missedWorkouts,
            int daysLogged, Integer daysWithinGoal,       // null = no goal set
            Integer avgCalories,                          // null = nothing logged
            Double weightKg, Double weightChangeKg) {}    // nulls per Definitions
}
```

`trainer/TrainerWeeklyReportJob` (flat in trainer root, package-private,
like `TrainerClientCleanupJob`):

```java
@Scheduled(cron = "0 0 5 * * MON")
void sendWeeklyReports() { weeklyReportService.sendWeeklyReports(LocalDate.now(clock).minusDays(1)); }
```

Inject `Clock` (the `WorkoutReminderJob` precedent) so tests pin the date.
Javadoc: single-instance assumption, skipped-on-downtime stance.

### B4 — Trainer preference endpoint

Smallest thing that works — on `TrainerClientDataController`? No: this is
trainer-*self* data, not client data. New tiny
`trainer/controller/TrainerPreferencesController`:

* `GET /api/v1/trainer/preferences` →
  `{ "weeklyReportEmailEnabled": true }`
* `PUT /api/v1/trainer/preferences` — same body, `@NotNull Boolean`.

Backed by a small addition to `SettingsService`
(`isWeeklyReportEmailEnabled` / `setWeeklyReportEmailEnabled` via the
existing `getOrCreate`) — the settings package keeps write ownership of
its entity, same rule as docs/32 B2. Trainer role guard: whatever the
other `/api/v1/trainer/**` endpoints use (the route prefix is already
trainer-gated by security config). Request/response DTO
`trainer/dto/TrainerPreferencesRequest/Response` (or one record — it's a
single boolean; implementer's choice).

### B5 — Mail: new intent + templates

* `MailService.sendWeeklyTrainerReport(User trainer, WeeklyTrainerReport
  report)`; `ResendMailService` impl: `@Async("mailTaskExecutor")`,
  resolve language from the trainer, render, send — the existing `send()`
  helper does the rest.
* Templates (8 files):
  `weekly_report_{en,hu}.{html,txt}` — header with the week range
  (`{{weekStart}}`–`{{weekEnd}}`, dd MMM formatted in Java), a
  `{{clientRows}}` token, footer pointing at the admin dashboard.
  `weekly_report_row_{en,hu}.{html,txt}` — one client section:
  name, workouts line ("3 completed · 1 missed"), nutrition line
  (per Definitions, with the no-goal / nothing-logged fallbacks),
  weight line ("82.4 kg (−0.4 kg)" / "no weigh-in this week"), or a
  single "No activity this week" line when everything is empty.
  Follow the existing templates' inline-styled table markup.
* Subject: EN "Your weekly client report ({{range}})", HU "Heti
  ügyfélriport ({{range}})".
* HTML-escape `clientName` before substitution (the renderer doesn't
  escape; existing templates only ever injected names into contexts the
  team controlled — this is the first template concatenating many
  user-derived strings, do it right).

### B6 — Backend tests

* `WeeklyReportServiceImplTest` (mock repos + `MailService`, fixed
  `Clock`):
  * digest built for a trainer with 2 clients — section values correct
    (completed/missed counts, daysLogged/daysWithinGoal/avg math,
    weight change vs baseline);
  * calorie adherence: no goal → `daysWithinGoal` null; nothing
    logged → avg null; over-goal day not counted as within;
  * weight fallbacks: no in-week entry, no baseline (in-week
    first-vs-last), single entry;
  * zero-activity client still present in the report;
  * opt-out trainer skipped (no `MailService` call); missing settings
    row → sent;
  * trainer with no active clients → no call.
* Repository tests (Testcontainers): `sumCaloriesBetween` bounds
  (inclusive/exclusive, soft-deleted excluded), `countCompletedBetween`
  (unfinished session excluded), baseline weight query,
  `findTrainerIdsWithActiveClients` (PENDING/REVOKED excluded, distinct).
* Preference endpoint test (extend the controller-test pattern):
  GET default true, PUT flips it, lazily creates the settings row,
  validation on null.
* Template smoke test: render both languages with a full and an
  empty-ish report — no leftover `{{` tokens (the renderer throws on
  missing files but not on missed placeholders).

## Web plan

### W1 — API + types

* `features/trainer/types.ts`: `TrainerPreferencesResponse` (one
  boolean). `features/trainer/api.ts`: `trainerPreferences` query +
  `updateTrainerPreferences` mutation, new
  `queryKeys.trainerPreferences` entry, invalidate on mutate.

### W2 — Opt-out toggle

Smallest possible surface: a switch row "Weekly email report" in the
admin — suggested home: the dashboard page header area or the layout's
user menu, whichever the existing markup makes cheaper (there is no
settings page to extend and one toggle doesn't justify creating one).
Optimistic or spinner-on-mutation, error toast on failure, matching
existing admin mutation patterns.

### W3 — i18n + web tests

* `admin` namespace keys (EN + HU): toggle label, saved/error toasts.
* vitest: toggle renders from the query value; flipping calls the
  mutation with the new value.

## Mobile plan

None. No display, no sync, no Drift migration, no notification-settings
row — the preference is trainer-only and web-only by design.

## Non-goals (deferred)

* Trainer-local send time (the 15-min-tick pattern exists if wanted).
* Catch-up / re-send when the Monday firing was missed; multi-instance
  duplicate protection (sent-log table).
* Per-client emails, PDF attachment, charts/sparklines in the email.
* Configurable metrics, thresholds, or week start day.
* Client-facing weekly recap — that's roadmap #7, a different audience.
* In-app (web) rendering of the same report.
* Protein/carbs/fat adherence — calories only, per the roadmap bullet.
* Unsubscribe link with a signed token in the email itself — the toggle
  lives behind the admin login; a one-click unsubscribe becomes
  necessary only if deliverability/compliance (List-Unsubscribe) starts
  to matter post-release.

## Edge cases

* **Trainer with zero active clients** — filtered out by the id query;
  no "empty digest" email.
* **Client accepted mid-week** — metrics computed over the full week
  window; days before `activeSince` simply have no data. Accepted: the
  first digest may look sparse for a brand-new client (no grace-period
  annotation — the trainer knows who just joined).
* **Client with no activity at all** — section says "No activity this
  week" (deliberate, see Design decisions).
* **No calorie goal set** — adherence line degrades to logged-days +
  average (Definitions); no goal is not an error.
* **Two trainers, one client** — both digests contain the client;
  missed-workout counts are trainer-scoped, activity/weight facts are
  shared (a log is a log — same stance as docs/29).
* **Revoked between id query and per-trainer fetch** — the ACTIVE
  filter in the per-trainer query drops them; a trainer whose list came
  back empty sends nothing.
* **Soft-deleted logs** — excluded by every query; deleting last week's
  only meal after Sunday but before the send changes the report
  (server truth at send time, accepted).
* **Offline-first lag** — a client's unsynced weekend logs miss the
  Monday 05:00 UTC snapshot. Accepted and honest: the report states
  what the server knew; the sync window is normally seconds-to-minutes.
* **Extreme west timezones** (UTC−9 and beyond): at the send moment the
  client's local Sunday may not be over. Irrelevant for the app's
  target audience (Europe) — noted in the job Javadoc rather than
  engineered around.
* **Mail disabled (`lifey.mail.enabled=false`, the dev default)** — the
  job runs, `ResendMailService` logs "would have sent" — harmless and
  useful in dev.
* **Resend failure for one trainer** — caught inside the mail layer's
  per-send try/catch; other trainers' digests unaffected; error logged.
* **DST / offset changes mid-week** — `utcOffsetMinutes` is a fixed
  offset snapshot, not a zone; a day boundary can shift an hour around
  a DST switch. Same tolerance already accepted by statistics and the
  reminder job.
* **App not released** — no rollout concern for V58 or the new
  endpoint (project memory: no backward-compat needed).

## Test plan summary

Backend: B6 (service math with fixed Clock + mocked mail, Testcontainers
range queries, preference endpoint, template smoke). Web: W3 (toggle
render + mutation wiring). Mobile: nothing. Manual pass: point
`lifey.mail.enabled=true` at a sandbox Resend key, trigger the job
method directly (temporary test endpoint or `@Scheduled` cron override)
with seeded data, eyeball the EN and HU emails in a real inbox.

## Suggested PR split

1. **Backend — everything** (B1–B6, V58): migration, queries, service,
   job, mail intent + templates, preference endpoint. Independently
   mergeable and already delivers the feature (opt-out reachable via
   API even before the web toggle exists).
2. **Web — preference toggle** (W1–W3): small, depends on PR 1.

Rough effort: medium backend (the aggregation service + 8 template files
+ tests are the bulk; every query is a copy of an existing idiom), tiny
web. The riskiest part is silent-wrong adherence math around day
boundaries — that's why B6 pins the Clock and covers the boundary cases
explicitly.
