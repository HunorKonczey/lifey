# Trainer push package (LIF-100)

Goal: the trainer hears about two things without opening the app - **a client missed a scheduled workout** and **a client
logged this week's weigh-in** - as pushes on the infrastructure of [`30`](30-push-notifications-plan.md). Origin:
[`chat/41`](chat/41-trainer-mobile-v2-plan.md) section 8.3 (open question 3), [`REMAINING-WORK`](REMAINING-WORK.md) 1.2.

Until now every server push went *to the client* (reminder, goals, comment, program, invite). These are the first two that go
to the *trainer*. The pipe is the same (`PushService.sendToUser`); what is new is who is told, when, and the opt-out.

## Decisions

### 1. Missed workout

- **What counts.** The same as the compliance flag ([`29`](29-compliance-overview-plan.md)): a trainer-scheduled occurrence
  (`workout_sessions.schedule_id` set) with `started_at is null and deleted_at is null` whose day has passed. The trainer who
  is told is the schedule's trainer - a client with two trainers does not leak one trainer's misses to the other.
- **When.** One push per occurrence, never repeated, sent at **08:00 on the trainer's local day after** the scheduled day (the
  trainer's `users.utc_offset_minutes`, like the client's workout reminder). Not at midnight: a push for a workout that was
  still possible to log late in the evening, in the middle of the night, helps nobody. An occurrence older than 3 days when the
  job first sees it (downtime, a late-created schedule) is **not** announced - a stale "missed" is noise, not news; the
  compliance flag on the client list still shows it.
- **No spam.** The job runs every 15 minutes, but one tick sends **one push per trainer**: a single miss names the client and
  the workout ("Anna missed Push day (Mon)"), several are folded ("3 clients missed a workout: Anna, Bela, +1"). A relationship
  that is no longer ACTIVE sends nothing.
- **Marker.** `workout_sessions.missed_notified_at` (like `reminder_sent_at`): set when the occurrence was announced **or** when
  the trainer has the push switched off - a trainer who turns it back on tomorrow does not get yesterday's backlog.
- **Tap.** `type=client_missed_workout`, `clientId` when it is one client: opens that client's page; several: the client list.

### 2. Weekly weigh-in

- **What counts.** "The weekly measurement" is the client's weigh-in (`weight_entries`; the body measurements and photos of
  [`80`](80-progress-photos-measurements-plan.md) are private to the client and stay that way - section 2.6 there). The push is
  for the **first weight entry of a client's calendar week** (Monday-Sunday, by the entry's own date): a client who weighs in
  every day causes one push a week, not seven.
- **Which entries.** Only a weigh-in dated **in the current week** of the client (local date from the client's utc offset): an
  offline entry that syncs late for a past week is history, not news. A second entry in the same week, or an edit, sends
  nothing.
- **Who.** Every ACTIVE trainer of the client, immediately (after the transaction commits - a rolled-back entry must not be
  announced).
- **Body.** "Anna logged this week's weigh-in: 82.4 kg" (the weight is already visible to the trainer in the client's trend).
- **Tap.** `type=client_weigh_in`, `clientId`: opens that client's page.

### 3. Opt-out

Two switches on the **trainer's** `user_settings` (default on): `client_missed_workout_push_enabled`,
`client_weigh_in_push_enabled`. They live next to the weekly report switch behind **`/trainer/preferences`** (trainer-only,
not the client `/settings` round trip - see the note on `UserSettings.weeklyReportEmailEnabled`): the response gains the two
booleans, the request fields become optional ("absent keeps the stored value" - an older client that only knows the weekly
report switch keeps working). UI: the phone's trainer settings screen and the web account menu.

### 4. Language

Push text is in the **trainer's** language (`user_settings.language`, EN default), like every other push.

## Not in this package

- A push for "client logged nothing for N days" (needs its own threshold and a quiet-hours story) - a follow-up if wanted.
- A push when a client *completes* a workout (the trainer comment flow of [`31`](31-session-feedback-loop-plan.md) covers
  that conversation).
- Quiet hours for these pushes (the chat's `chat_quiet_hours_*` is chat-only; a general one is a separate decision).

## Backend

- `V93`: the two `user_settings` booleans, `workout_sessions.missed_notified_at`.
- `ClientMissedWorkoutJob` (`trainer/`, cron `lifey.jobs.client-missed-workout.cron`, every 15 minutes) over
  `WorkoutScheduleRepository.findMissedOccurrenceCandidates` (the join of an occurrence with its schedule's trainer and
  client). The grouping and the message are separate, pure functions (`MissedWorkoutPush`) so they are tested without a
  clock or a database.
- `WeightLoggedEvent` published by `WeightServiceImpl.create`; `ClientWeighInPushListener` (`trainer/`,
  `@TransactionalEventListener(AFTER_COMMIT)`) decides "first of the week" and notifies the trainers.
- `TrainerPreferences*` carry the two switches.

## Phone and web

- The push tap handler routes `client_missed_workout` / `client_weigh_in` to the trainer client page (the list when several).
- Trainer settings screen (phone) and account menu (web): two more switches.
