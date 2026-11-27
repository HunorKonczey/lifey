# 89 – Garmin and Health-Store Data Import

Status: in progress (M1: G1.2–G1.9 done; G1.1 waits for a real Garmin watch. M2: G2.1–G2.6 done. M3: G3.1–G3.2 done). M1–M3 are unblocked. M4–M5 are parked until a company exists and Garmin approves a Starter application, the same gate as LIF-22.
Scope: roadmap V4 "Garmin" (docs/07-roadmap.md). Surfaces: backend · mobile · web (read-only display)
Jira: LIF-86 (this plan). The step stories are listed in §6.
Depends on:
- docs/16-apple-health-integration-plan.md and docs/26-android-health-connect-integration-plan.md (permissions, the `health` plugin, read limits)
- docs/cardio/51–62 (the CARDIO `workout_sessions` model, `cardio_details`, the route polyline)
- docs/15-delta-sync.md (the sync feed every new entity joins)

## Current state (what already exists)

- **Health store, read and write:** `mobile/lib/core/health/health_service.dart` reads steps, weight, and finished workouts. Workouts are read only as `recentStrengthWorkouts`, to pair a Lifey session with the matching HealthKit / Health Connect record through `healthWorkoutId`. It also writes weight and strength workouts.
- **Importers:** `step_history_importer.dart` and `weight_health_importer.dart` run on startup and on app resume (`StepImportLifecycle`). They are the template for every importer below.
- **Cardio model:** a cardio session is a `workout_sessions` row with `session_kind = CARDIO` and an `activity_type`, plus a 1:1 `cardio_details` row (V67): distance, elevation, cadence, HR zones, and `route_polyline`. `ActivityType` covers RUNNING, WALKING, HIKING, CYCLING, INDOOR_BIKE, BASKETBALL, FOOTBALL and OTHER_CARDIO.
- **Plugin:** `health` 14.0.0 already exposes `WORKOUT` (with `workoutActivityType`, `totalDistance`, `totalEnergyBurned` and the source app), `WORKOUT_ROUTE`, `SLEEP_SESSION`, the `SLEEP_*` stages, `RESTING_HEART_RATE`, `HEART_RATE_VARIABILITY_SDNN` (iOS) and `HEART_RATE_VARIABILITY_RMSSD` (Android). No new dependency is needed for M1–M3.
- **Not built yet:** importing cardio from the health store, a sleep entity, a daily-vitals entity, and anything Garmin-specific.

## 1. What we're building

1. **Cardio import (M1).** Outdoor runs, walks, hikes and rides recorded on another device show up in Lifey as normal cardio sessions. That device can be a Garmin watch (through the Garmin Connect app, which writes to Apple Health / Health Connect), an Apple Watch workout from another app, Polar, Coros, and so on. They count toward statistics and the weekly review, and are marked with the app they came from.
2. **Sleep (M2).** Last night's sleep (duration and, where available, deep / light / REM / awake) on the Today screen, plus a sleep history. It comes from the health store whatever recorded it.
3. **Daily vitals (M3).** Resting heart rate and HRV trends from the health store.
4. **Direct Garmin connection (M4–M5, parked).** The user signs in with Garmin from Settings. Activities arrive server-side, so the phone does not need to open the app. Garmin-only data comes too: stress, Body Battery, FIT laps. Lifey interval plans can be sent to the watch where Garmin allows it.
5. **When it is off.** Every import is opt-in per data type in the Health settings section. With everything off, the app behaves exactly as today. Turning an import off stops future imports; it never deletes what was already imported.

## 2. Key design decisions

### D-G1 The health store comes first, the Garmin API second
**Chosen:** M1–M3 read Apple Health and Health Connect. The direct Garmin API is M4–M5.
**Rejected:** starting with the Garmin Connect Developer Program.
**Why:**
- A multi-user app needs the **Starter** tier. Its access form is for "businesses, organizations and other commercial entities", and Lifey has no company yet.
- The **Personal** key is explicitly not for apps that serve other users.
- Garmin can terminate access on 30 days' notice (agreement §9.2).
- Garmin closed the program from March to October 2026.

The health store needs no approval, works today, and covers every other watch brand too. Garmin Connect already writes activities, steps, sleep and heart rate to both stores (Health Connect since mid-2025). The API is still worth having later, for server-side delivery and for Garmin-only data the stores never get: stress, Body Battery, full FIT files.

### D-G2 An imported workout is an ordinary CARDIO session, not a new entity
**Chosen:** an import creates a `workout_sessions` row (`session_kind = CARDIO`) plus `cardio_details`. Two new nullable columns record where it came from:
- `import_source`: `HEALTH` | `GARMIN`; null means recorded in Lifey;
- `import_app_name`: the store's source name, e.g. "Garmin Connect".

**Rejected:** a separate `imported_activities` table.
**Why:** statistics, the weekly review, PRs, the web view and the trainer's client view all read `workout_sessions` already. A second table would need every one of those queries to union two sources (docs/cardio/56 lists them).

### D-G3 The health record id is the dedupe key, and a deleted import stays deleted
**Chosen:** the existing `health_workout_id` holds the store's record id. A new partial unique index on `(user_id, health_workout_id) where import_source is not null and health_workout_id is not null` stops a second import of the same record (V97, LIF-196). On create, the server answers a duplicate import with 409 before it reaches the index.

The index is partial on `import_source`, not only on `health_workout_id`, because `health_workout_id` already marks a Lifey-recorded session *paired* with a store workout (V15). A user can delete a paired session and pair a new one with the same workout, and that must keep working.

Sessions are soft-deleted (`deleted_at`), so a deleted import keeps its id in the index, and the importer skips it.
**Rejected:** matching on start time and duration. Two devices recording the same run would merge wrongly, and a watch that edits a record later would break the match.

### D-G4 Lifey's own workouts are never re-imported
**Chosen:** the importer skips records whose source is Lifey itself (bundle id / package name). It also skips records already paired with a Lifey session through `healthWorkoutId`.
**Why:** Lifey writes its own sessions to the store (docs/16, docs/26). Without this rule every Lifey workout would come back as a duplicate import. This is the highest-risk rule in the plan (§7, R1).

### D-G5 Imports are opt-in per data type, and the first run looks back 14 days
**Chosen:** three toggles in the Health settings: cardio, sleep, vitals. Each is off until the user turns it on and grants the matching permission. The first run imports the last 14 days. After that, a per-type cursor (last imported end time) is kept in `HealthPreferences`.
**Rejected:**
- **On by default:** a user who records a run in Lifey *and* on a Garmin would get two sessions without having asked for either.
- **Unlimited history:** years of activities in one sync would flood the outbox and the statistics.

### D-G6 Imported metrics are read-only; type and notes stay editable
**Chosen:**
- **Editable:** the activity type (the store's type mapping can be wrong, e.g. a treadmill run arriving as RUNNING) and the notes.
- **Read-only:** duration, distance, calories and route, because they are the watch's measurement.
- **Delete:** allowed.

**Why:** editing the measurement would silently disagree with the source app.

### D-G7 A sleep session is its own synced entity, attributed to the wake-up date
**Chosen:** a new `sleep_sessions` table, one row per sleep session from the store: start, end, asleep / deep / light / REM / awake minutes (nullable when the source has no stages), source app, and the store's record id. "Last night" is the longest session whose **end** falls on the local date. Naps are stored too, but the Today tile shows only the main sleep.
- As built (G2.1, `V99`; `V98` went to LIF-224 in the meantime): there is no date column. Only the client knows the local time zone, so it derives the wake-up date from `ended_at`. The record id is a plain unique `(user_id, health_record_id)`: nulls stay distinct, so a session without a store id is never blocked. API: `/api/v1/sleep-sessions` with list, delta feed, create (409 on a record the user already has, deleted ones included) and soft delete. There is no update, because imported values are measurements (D-G6).
- As built (G2.2, schema v56): `lib/features/sleep/` holds `SleepSession` with `wakeDate` and `mainSleepFor(sessions, date)` (the longest session that ended on that local date), `SleepSessionRepository` (watch, create, delete, `existsByHealthRecordId` for the importer) and a thin `SleepSessionController`. The UI comes with G2.5–G2.6.
- As built (G2.3): `health_sleep.dart` `mergeSleep` makes one row per session. On Health Connect, a `SLEEP_SESSION` takes the stages that carry its record id; a stage whose session started before the read window is dropped, never imported alone. On HealthKit, each source's samples cluster into a session until a gap of more than 30 minutes, keyed by the earliest sample's id; a cluster with no sleep in it (only the iPhone's "in bed") is skipped. Awake in bed and out of bed count as awake. Deep / light / REM are null unless the night is staged, so an "asleep"-only night never shows 0 minutes of deep sleep. The read window opens 24 h before the cursor, because the store returns sleep by start time. The Android manifest declares `READ_SLEEP`; the permission request comes with the toggle (G2.4).
**Rejected:**
- **A per-night aggregate row:** loses naps, and makes re-imports after a watch edit ambiguous.
- **Attributing to the start date:** a sleep starting at 23:30 would land on the previous day.

### D-G8 Resting HR and HRV share one daily-vitals row
**Chosen:** `daily_vitals` (user, date, `resting_hr`, `hrv_ms`, `hrv_method` = `SDNN` | `RMSSD`), one row per day, the same shape as `daily_step_counts`.
**Why `hrv_method`:** iOS stores SDNN and Health Connect stores RMSSD. The two are not comparable, so the method is kept and the UI never mixes them in one trend.

- As built (G3.1, `V100`): both values are nullable but not both at once, and `hrv_method` is set exactly when `hrv_ms` is (check constraints, mirrored by the request validation). Sanity bounds: resting HR 20–250 bpm, HRV over 0 and up to 1000 ms. API: `/api/v1/vitals` with list (optional `from`/`to`), delta feed, upsert on the date (a deleted day is revived), update and soft delete.

### D-G9 When Garmin is connected directly, the API wins over the health store
**Chosen:** while a Garmin connection is active (M4), the health importer skips records whose source app is Garmin Connect. The server-side Garmin import owns those activities (`import_source = GARMIN`, Garmin `activityId` in a new `external_id` column with its own partial unique index).
**Why:** otherwise every Garmin activity would arrive twice, once from each path.

### D-G10 Garmin tokens are encrypted at rest; a Garmin deregistration deletes the connection
**Chosen:** OAuth tokens are encrypted with an application key (the env-var pattern already used for other secrets). Garmin's deregistration and user-permission-change notifications remove the connection and its tokens. Imported sessions stay, because they are the user's data, and the user can delete them. Garmin attribution is shown wherever Garmin data is displayed (agreement §6.4).
The exact auth mechanism (OAuth 2.0 with PKCE expected) is to be confirmed from Garmin's documentation once access is granted (step G4.1).

## 3. UI spec

- **Settings → Health:** the existing Health section in the settings screen. It gets three switches (cardio / sleep / vitals), each with a one-line explanation and the permission request on first enable. In M4 it also gets a "Garmin" row with connect / disconnect.
- **Session list and session detail:** an imported session shows a small source chip ("Garmin Connect", "Apple Health"). The metric fields are read-only. The detail screen shows the route when one was imported.
- **Today dashboard:** a sleep tile (M2) with last night's duration and a stage bar when stages exist. Tapping it opens the sleep history screen: a weekly list and a 7-day average.
- **Body / Statistics:** resting-HR and HRV trend cards (M3), one per HRV method.
- **Web:** imported sessions display through the existing read-only cardio view (docs/cardio/58), with the source chip. Sleep and vitals on the web are a later step (§5 Non-goals).
- All strings go through the ARB files (localization skill). All visuals use the existing design-system components; the design audit must stay at 0.

## 4. Order of work

Milestones are demoable slices. Each step is one surface, one PR and one session. M1 alone is the smallest version worth using: Garmin runs show up in Lifey.

### M1 — Cardio import from the health store
**Demo:** a run recorded on a Garmin watch appears in Lifey's session list after opening the app.

| Step | Surface | What | Verification |
|---|---|---|---|
| G1.1 | Spike (device) | Record a run on a Garmin watch synced through Garmin Connect. Log what reaches Health Connect (Android) and Apple Health (iOS): workout type, source name, distance, calories, HR samples, route. Record the findings in §8 of this doc. | Findings written down. Mapping table in G1.4 updated from real data. Needs a real Garmin watch. |
| G1.2 ✅ | Backend | `V97`: `import_source`, `import_app_name` on `workout_sessions`, plus the partial unique index on `(user_id, health_workout_id)` for imports. Entity, DTOs and mapper carry the two fields. Create rules: `HEALTH` requires `healthWorkoutId`; `GARMIN` is rejected from clients; a duplicate import gets 409. Provenance is create-only. | `./mvnw -B verify`. The test rejects a second import of the same `health_workout_id`. |
| G1.3 ✅ | Mobile data | Drift columns and DTO fields for `importSource` / `importAppName`, with a schema-version bump (v54) and migration. Round-trip through the outbox (create only) and pull sync. `WorkoutSession.isImported`; `enrichedFromWatch` excludes imports. | Repository and sync tests. `flutter analyze`. |
| G1.4 ✅ | Mobile domain | `HealthService.recentCardioWorkouts(since:)` plus a pure mapper from store workout type to `ActivityType` (`health_cardio_workout.dart`). Unknown types map to OTHER_CARDIO; strength and breathing/recovery types are never imported. Skips Lifey-sourced records (D-G4). | Unit tests for the mapper and the source filter. |
| G1.5 ✅ | Mobile data | `CardioHealthImporter`: cursor in `HealthPreferences`, 14-day first run, dedupe by record id, creates the session through `WorkoutSessionRepository` and the outbox. Started from the same lifecycle as the step importer, and only when the toggle is on. | Unit tests: re-run imports nothing new; a deleted import is not recreated; a Lifey-sourced record is skipped. |
| G1.6 ✅ | Mobile UI | Health settings toggle for cardio import, with the permission request (`CardioImportRow`, `CardioImportController`; Android manifest declares `READ_DISTANCE`). | Widget test. Emulator check. |
| G1.7 ✅ | Mobile UI | Source chip on the session list and detail screens; read-only metric fields on imported sessions (D-G6). | Widget tests. Emulator screenshot. |
| G1.8 ✅ | Mobile data | Route import: `WORKOUT_ROUTE` → simplified polyline (the docs/cardio/54 simplifier), and HR zones from HR samples. | Unit tests on a recorded fixture route. |
| G1.9 ✅ | Web | Source chip on the web cardio view. | Vitest. Browser check. |

### M2 — Sleep from the health store
**Demo:** the Today screen shows last night's sleep from any watch.

| Step | Surface | What | Verification |
|---|---|---|---|
| G2.1 ✅ | Backend | `V99`: `sleep_sessions` (D-G7), with `user_id … on delete cascade`, `updated_at`/`deleted_at` plus the `(updated_at, id)` index, and a unique `(user_id, health_record_id)`. Entity, CRUD and delta-sync feed (backend-feature-slice). | `./mvnw -B verify`. Ownership and sync-feed tests. |
| G2.2 ✅ | Mobile data | Drift table (schema v56), repository, outbox and pull sync for sleep sessions (flutter-feature-slice). A 409 on a create with a `healthRecordId` drops the local duplicate, like D-G3. | Repository and sync tests. |
| G2.3 ✅ | Mobile data | `SleepHealthImporter`: `SLEEP_SESSION` plus stage samples, merged into one row per session. Same cursor, dedupe and lifecycle as G1.5. | Unit tests with iOS-style (stages only) and Health Connect-style (session plus stages) fixtures. |
| G2.4 ✅ | Mobile UI | Sleep toggle in the Health settings (`SleepImportRow`, `SleepImportController`; the first enable requests the sleep types and imports at once). | Widget test. |
| G2.5 ✅ | Mobile UI | Today sleep tile (main sleep, stage bar): `TodaySleepTile` under the weight tile, hidden while the user neither imports sleep nor has any. Sleep colour = the fat indigo (`AppMetricColors.sleep`). | Widget tests: stages present, duration only, no data. |
| G2.6 ✅ | Mobile UI | Sleep history screen: weekly list and 7-day average (`SleepHistoryScreen`, opened from the Today tile). The average counts main sleeps only; naps are marked with their own icon and "Nap". | Widget test. Emulator screenshot. |

### M3 — Resting HR and HRV from the health store
**Demo:** the Body tab shows a 30-day resting-HR trend.

| Step | Surface | What | Verification |
|---|---|---|---|
| G3.1 ✅ | Backend | `V100`: `daily_vitals` (D-G8), with CRUD and the sync feed. `/api/v1/vitals`; POST upserts on the date and replaces both values, so the client sends the whole day. | `./mvnw -B verify`. |
| G3.2 ✅ | Mobile data | Drift table (schema v57), repository and sync for daily vitals. `DailyVitalsRepository.upsertForDay` merges resting HR and HRV into one row per day and always sends the whole day, because the server replaces both values. | Repository and sync tests. |
| G3.3 | Mobile data | `VitalsHealthImporter`: daily resting HR and HRV with its method, plus the settings toggle. | Unit tests: SDNN and RMSSD never mixed. |
| G3.4 | Mobile UI | Resting-HR and HRV trend cards. | Widget tests. Emulator screenshot. |

### M4 — Direct Garmin connection (parked: company + Starter approval)
**Demo:** a run synced to Garmin Connect appears in Lifey without opening the phone app.

| Step | Surface | What | Verification |
|---|---|---|---|
| G4.0 | Admin (user) | Register the company, then submit the Starter access request. List every processor that touches Garmin data (Render, Neon/Postgres host, AI providers). Accept the agreement. Store credentials as Render env vars. | Garmin app credentials exist. |
| G4.1 | Backend | `garmin/` feature: `garmin_connections` table (encrypted tokens, D-G10) and the OAuth start/callback endpoints. The auth mechanism is confirmed from Garmin's docs in this step. | `./mvnw -B verify` with a mocked Garmin token endpoint. |
| G4.2 | Mobile UI | Connect / disconnect Garmin in Settings. Opens the browser, with a deep link back. | Emulator check against the evaluation environment. |
| G4.3 | Backend | Webhook receiver for push notifications: verification, an idempotent raw-payload store, and the deregistration / permission-change handlers. | Controller tests with recorded payloads. A duplicate delivery is ignored. |
| G4.4 | Backend | Activity summary → CARDIO session (`import_source = GARMIN`, `external_id` = activityId, `V101` index). The health importer skips the Garmin Connect source while connected (D-G9). | Service tests: same activity delivered twice gives one session; a deregistered user gets nothing. |
| G4.5 | Backend | FIT file parsing for route, laps and HR zones. This adds the Garmin FIT SDK; justify the dependency in the PR. | Tests on a fixture FIT file. |

### M5 — Garmin-only data (parked with M4)
| Step | Surface | What | Verification |
|---|---|---|---|
| G5.1 | Backend | Garmin dailies and sleep into `daily_vitals` / `sleep_sessions` with `import_source = GARMIN`. Adds stress and Body Battery columns (`V102`). | Service tests with recorded payloads. |
| G5.2 | Mobile UI | Stress and Body Battery cards. | Widget tests. |
| G5.3 | Backend | Training API: send a Lifey cardio interval plan to the watch. Only if Garmin's terms allow it for the app; the sources say third-party workout pushing is largely restricted. | Decided at G4.0. Tests against the sandbox. |

## 5. Non-goals (deferred)

- Writing Lifey data *to* Garmin, apart from G5.3.
- Strava. That is LIF-87, with its own plan. The health-store import from M1 already covers runs that Strava writes to the store.
- Importing more than 14 days of history on first run. The Garmin Starter tier has no historical backfill either.
- Sleep and vitals on the web, sleep scores, and sleep coaching.
- Stress / Body Battery without the Garmin API. The health stores do not carry them.
- Editing an imported workout's measured values (D-G6).
- Background import while the app is fully closed. The same rule as steps (mobile/CLAUDE.md).

## Edge cases

- The same run recorded in Lifey *and* on a Garmin watch: two sessions with different record ids, by design. The detail screen of the imported one offers "Delete — I already logged this".
- A watch edits or deletes its record after import: the import is not updated (D-G3). A re-import of an edited record is skipped because its id is unchanged. Accepted for M1.
- Health Connect returns no route unless the user grants the per-route permission. The session imports without a route, and that is not an error.
  - As built (G1.8): the manifest declares `READ_EXERCISE_ROUTES`, but no in-app request can ask for it. The user grants "Exercise routes" in the Health Connect app. Without it the plugin returns a route with no locations. On iOS, `WORKOUT_ROUTE` is part of the cardio permission request. A user who turned the import on before G1.8 is asked again only after toggling it off and on.
  - Settings hint (LIF-223): on Android, while the import runs and the grant is missing, a "Route maps from other apps" row under the toggle names the path (Health Connect › Lifey › Additional access › Access exercise routes, "Always allow") and opens Health Connect. An app may not open its own Health Connect permission page from Android 14 (`MANAGE_HEALTH_PERMISSIONS` needs the system-only `GRANT_RUNTIME_PERMISSIONS`), so the row opens Health Connect's home. From Android 14 the grant is an ordinary runtime permission, so the row hides once it is granted (re-checked on app resume). Below 14 the grant is unknown and the row stays.
  - Matching: on Health Connect a route names its exercise session. On HealthKit a Garmin route carries no workout id, so it goes to the workout it overlaps most in time (`routeForWorkout`).
  - The route goes through the same closing step as a Lifey recording: gap split, 5 m Douglas–Peucker, altitude channel (`encodeRoute`). The §4.2 accuracy and speed gates are skipped, because the watch has already filtered its track.
- HR zones of an imported session (G1.8) are measured against 220 − age, the same bands as the live screen (`hr_zones.dart`). Without a birth date the zone columns stay null and the panel is hidden. A sample counts until the next one, capped at 30 s, so a lost reading shows as partial coverage instead of invented zone time.
- Time zones: a run starts in one zone and ends in another, or sleep crosses midnight. Dates come from the local end time, consistently on both platforms.
- Permission revoked after enabling: the importer stops quietly, and the toggle shows "permission needed". This uses the same revoked-permission check as `_looksLikeRevokedPermission`.
- An unknown or new store workout type: it imports as OTHER_CARDIO and the user can change the type.
- iOS sleep comes as stage samples with no session record: G2.3 builds the session from contiguous samples.

## Test plan

- **Backend:** migration plus Hibernate validate (`./mvnw -B verify`). Ownership and sync-feed tests for `sleep_sessions` and `daily_vitals`. Unique-index tests for both dedupe keys. Garmin webhook idempotency and deregistration (M4).
- **Mobile unit:** type mapper, source filter (D-G4), each importer with fixtures (re-run, deleted, Lifey-sourced, empty, permission revoked), stage merging, and HRV method separation.
- **Mobile widget:** settings toggles, source chip, read-only fields, sleep tile states, trend cards.
- **Device:** G1.1 spike, plus an emulator smoke test at the end of each milestone (emulator workflow memory).
- **Web:** vitest for the source chip.

## Suggested PR split

One PR per step, in the order of §4, each on its own `LIF-<n>` branch (one-branch-per-ticket rule). Backend steps merge before the mobile steps that sync their fields. Within a milestone, the UI steps can follow in any order once the data step has landed.

## 6. Jira

**Planning:** LIF-86.

**M1–M3: epic LIF-194, "Health-adatok importja: cardio, alvás, vitálértékek".**
- G1.1 → LIF-195
- G1.2 → LIF-196
- G1.3 → LIF-197
- G1.4 → LIF-198
- G1.5 → LIF-199
- G1.6 → LIF-200
- G1.7 → LIF-201
- G1.8 → LIF-202
- G1.9 → LIF-203
- G2.1 → LIF-204
- G2.2 → LIF-205
- G2.3 → LIF-206
- G2.4 → LIF-207
- G2.5 → LIF-208
- G2.6 → LIF-209
- G3.1 → LIF-210
- G3.2 → LIF-211
- G3.3 → LIF-212
- G3.4 → LIF-213

**M4–M5: epic LIF-24, "Garmin és Strava integráció". Parked.**
- G4.0 → LIF-214
- G4.1 → LIF-215
- G4.2 → LIF-216
- G4.3 → LIF-217
- G4.4 → LIF-218
- G4.5 → LIF-219
- G5.1 → LIF-220
- G5.2 → LIF-221
- G5.3 → LIF-222

## 7. Risk checkpoints where a failure would be silent

- **R1 — Re-import loop.** A Lifey-recorded workout written to the store comes back as an import (D-G4). The result is doubled weekly minutes and calories, not an error. Reviewers check the source filter and its test on both platforms.
- **R2 — Double-counted calories.** An imported session's active calories added on top of the day's active energy that already includes it. Follow docs/cardio/51 Q4 and docs/cardio/56: one source per number.
- **R3 — Wrong activity mapping feeding PRs.** A treadmill run mapped to outdoor RUNNING could enter best efforts. Imported sessions without splits must produce null best efforts, never values extrapolated from the average.
- **R4 — Sync not bumping `updated_at`.** Importers write through the repositories, never with raw SQL. The `cardio_details` rule from V67 applies: a write there bumps the parent session.
- **R5 — Garmin and health paths both importing.** If D-G9's skip rule breaks, every Garmin activity arrives twice.
- **R6 — Mixed HRV methods.** An SDNN value and an RMSSD value on one chart looks like a real trend change (D-G8).
- **R7 — Sleep on the wrong day.** Attribution by start date or by UTC instead of the local end date (D-G7).

## 8. Findings (filled in by G1.1)

_Empty until the spike runs._

## 9. After implementation

- Update `docs/REMAINING-WORK.md` §1.5 and `docs/07-roadmap.md` V4.
- Update this doc's Status and mark finished steps with ✅.
- Revisit M4 when the company exists. Re-check Garmin's program terms then, since they changed twice in 2026.

## Sources (Garmin program, checked 2026-11-23)

- DC Rainmaker: "Garmin Revamps and Opens Up Connect Developer API Program" (Oct 2026)
- Sahha: "Garmin API Access in 2026: New Tiers, Fees and Terms"
- Momentum: "Garmin Connect Developer Program Reopens"

Garmin's own program page and agreement were not read directly; confirm the tier details at G4.0.
