# 82 – Web-redesign backend gaps: goal attribution, real last activity, invite history, role filter

Status: built (2026-10-03, branch `feature/web-backend-gaps`) — S1–S5 done; unit, real-Postgres and web tests green (log in §9)
Scope: backend · web (mobile only where noted)
Depends on: `78` §6 (the non-goals this closes), W9.4 / W9.7 / W9.b2 (the screens that worked around them),
`docs/32-trainer-nutrition-goals-plan.md` (trainer-set goals), `docs/personal_trainer/02-domain-es-migraciok.md`
(the invite is a `trainer_clients` row)

Four items from `docs/REMAINING-WORK.md` §2.2 that the web redesign had to hide, approximate or do
client-side. Each is independent and mergeable on its own; the order below is smallest first.

## 1. What we're building

1. **Role filter on the server** — `GET /api/v1/superadmin/users?role=USER|TRAINER|ADMIN`, so the filter
   no longer depends on the table having loaded every user (the web caps the list at 500).
2. **Invite history** — `GET /api/v1/trainer/invites/history` lists every invite the trainer ever sent with
   its outcome: pending, accepted, declined, cancelled, expired. The invites page shows it under the live list.
3. **Real last activity** — `users.last_active_at`, stamped on authenticated use, replacing the "last sign-in /
   refresh in 30 days" approximation. Shown as a column on the superadmin users table and used by the
   "active accounts" KPI.
4. **Goal attribution** — who last changed a client's nutrition goals and when, so the web can say "set by your
   trainer on Sep 12" and a trainer sees "Goals: Szabó Bence".

## 2. Key design decisions

### 2.1 The role filter uses the table's own three kinds, not raw roles

The web already groups a user by their *primary* role (`primaryRole`: admin/super-admin over trainer over
client). The server filter takes exactly those kinds (`USER`, `TRAINER`, `ADMIN`) with the same precedence,
so the segmented control means the same thing before and after. Rejected: filtering by a raw `Role` — a
trainer who is also an admin would appear under both "Edző" and "Superadmin" on the server but under one on
the client.

### 2.2 The invite history is a read over rows that already exist; no migration

An invite is a `trainer_clients` row and nothing is ever deleted: it moves PENDING → ACTIVE / DECLINED /
EXPIRED / REVOKED with `responded_at` / `revoked_at` stamped. `78` §6 said "the invite model does not store it"
— what is missing is only an endpoint. Outcome is derived, not stored:

| Row | Outcome |
|---|---|
| `ACTIVE`, or `REVOKED` with `responded_at` set | ACCEPTED (a later REVOKED is the *relationship* ending, reported as `endedAt`) |
| `DECLINED` | DECLINED |
| `REVOKED` with no `responded_at` | CANCELLED (the trainer withdrew a pending invite) |
| `EXPIRED`, or `PENDING` past `expires_at` | EXPIRED |
| `PENDING` before `expires_at` | PENDING |

Shareable link and reminder emails (also listed in `78` §6) are **not** part of this.

### 2.3 Last activity is a throttled stamp on the authenticated request, not an event log

`users.last_active_at timestamptz` (nullable), written by a small tracker the JWT filter calls after it has
authenticated a request. It throttles in memory (one write per user per 5 minutes per instance) and the SQL is
conditional (`… where last_active_at is null or last_active_at < :threshold`), so several instances still
write at most about once per window. A failure in the tracker never fails the request. Rejected: an
activity-event table (grows without bound for a number we only ever read as "latest"); stamping on login/refresh
only (what we already approximate with — a user can stay "active" for a week on one access token).
Existing users start `null` until their next request; the KPI treats "`last_active_at` in window **or** a session
refresh in window" as active during the ramp-up, so the number does not drop to zero on deploy.

### 2.4 Goal attribution records who and when, only when a value actually changes

`user_settings.nutrition_goals_set_by` (nullable FK to `users`, `on delete set null`) and
`nutrition_goals_set_at`. The mobile app PUTs the *whole* settings object on every change, so the stamp moves
**only when one of the four nutrition goals (calories, protein, carbs, fat) differs from the stored value** —
otherwise any unrelated settings sync from the client would silently overwrite "set by your trainer". The
trainer path stamps the trainer; the client path (settings update, suggested goals) stamps the client.
`SettingsResponse` is a positional record used all over the tests and the mobile sync, so it is **not**
widened; the attribution is served by `GET /api/v1/settings/nutrition-goals-source` (client) and by
`GET /api/v1/trainer/clients/{id}/nutrition-goals/source` (trainer). Existing rows have `set_at = null`: "unknown", and the
web shows no chip rather than inventing a date.

## 3. API

| Endpoint | Change |
|---|---|
| `GET /superadmin/users` | new optional `role=USER\|TRAINER\|ADMIN` |
| `GET /trainer/invites/history?page&size` | new, newest first |
| `GET /superadmin/users` rows, `GET /superadmin/stats` | `lastActiveAt` on rows; `activeAccounts30d` definition per §2.3 |
| `GET /settings/nutrition-goals-source` | new: `{ source: SELF\|TRAINER\|UNKNOWN, setAt, setByName }` — always a body, `UNKNOWN` carries no date |
| `GET /trainer/clients/{id}/nutrition-goals/source` | new: `{ source, setAt, setByYou }` — a separate endpoint, so the existing goals response (also the web's *request* type) is not widened; no names |

## 4. Non-goals

- Shareable invite link, invite reminder emails, a public trainer directory.
- Showing goal attribution in the mobile app (the data is available; the screens are a separate step).
- Per-request activity history, or activity for the trainer's *clients* beyond what the dashboard derives.
- Pagination of the superadmin users table beyond the existing 500 cap — the filter just stops depending on it.

## 5. Order of work

| Step | Surface | What |
|---|---|---|
| S1 | Backend + web | role filter |
| S2 | Backend + web | invite history |
| S3 | Backend + web | `last_active_at` (V80), tracker, KPI, column |
| S4 | Backend + web | goal attribution (V81), endpoints, chips |
| S5 | Docs | close `78` §6 rows, `REMAINING-WORK.md`, Postman, this log |

## 6. Test plan

Controller + service unit tests per step (the repo's pattern); the tracker's throttle with a fake clock; the
attribution "unchanged values never move the stamp" case; the outcome table in §2.2 row by row. Because Docker is
not available in this environment, a **query-validation test** boots only the JPA layer with no database
connection and lets Hibernate parse every `@Query` in the project — it catches a JPQL typo in the new queries,
which the existing unit tests never would. It does not replace a run against a real Postgres.

## 7. Risks where a failure would be silent

- **Attribution overwritten by an unrelated settings sync** (§2.4) — covered by a test that PUTs unchanged goals
  after a trainer change.
- **`primaryRole` precedence differing between web and server** (§2.1) — one test per kind with a user holding
  two roles.
- **The activity tracker hiding behind its own swallow-all** — it logs at debug on failure and counts a metric, so
  "never updates" is visible.
- **Invite outcome mislabelled when a relationship later ends** (§2.2) — the REVOKED-after-accept row has its own test.

## 8. Edge cases

- A user with no `last_active_at` sorts as the *oldest* on the activity column (an unknown value is never the newest); the cell shows "—".
- A trainer who deleted their account: `nutrition_goals_set_by` becomes null while `set_at` stays — the source is
  then reported as TRAINER with no name (the web says "your former trainer").
- The 24 h invite re-send creates a new row; the old one shows as EXPIRED in the history, not as a duplicate pending.

## 9. Step log

- **Query validation test — done first.** `JpqlQueryValidationTest` builds a Hibernate `SessionFactory` from the entities and the PostgreSQL dialect with JDBC metadata access off, and parses every non-native `@Query` in the project (no database, no Docker). Proven able to fail by breaking `UserRepository.countByRole` on purpose (`Could not resolve attribute 'rolez'`) and restoring it. It checks validity, not results.
- **S1 (role filter) — done.** `UserRoleKind {USER, TRAINER, ADMIN}`, `UserRepository.findByRoleKind` (one JPQL, precedence ADMIN > TRAINER > USER, literal enum paths so no role parameters), `?role=` on `GET /superadmin/users` (unknown value → 400 through the new global type-mismatch handler). Web: the segmented control now sends `role`; the client-side `matchesRoleFilter` is gone (replaced by `roleFilterParam`), and the summary line shows the server total whenever a filter is on. Backend 36 tests incl. the validator; web `superadmin` suite and `tsc` clean.

- **S2 (invite history) — done.** No migration, as planned. `InviteOutcome` (pure `of(status, respondedAt, expiresAt, now)` — the §2.2 table row by row in `InviteOutcomeTest`), `GET /trainer/invites/history` (newest first, 30 per page, the client fetched with the page by an entity graph, a caller-supplied sort dropped). **Deviation from §2.2:** `endedAt` is when *any* REVOKED row stopped being live — the withdrawal of a CANCELLED invite as well as the end of an accepted relationship — so a withdrawn row can show a date; every other outcome has none. Web: a History section under the live list on `/admin/invites` (outcome chip, "elfogadta 3 napja · az együttműködés megszűnt …", Újraküldés only for EXPIRED/CANCELLED, "Továbbiak" to load more), and the empty-state copy no longer says expired invites "don't show up". Backend 17 tests incl. the query validator; web 1067 tests, `tsc` and eslint clean.
- **S3 (real last activity) — done.** `V80__user_last_active_at.sql` (nullable `users.last_active_at`, no index on purpose), `UserActivityTracker` (in-memory throttle of 5 min per user per instance, conditional `UPDATE`, failures swallowed and counted in `lifey.user.activity.touch.failures`, the optimistic throttle entry dropped on failure so the next request retries), called by `JwtAuthenticationFilter` after a token is accepted. `UserRepository.countActiveSince` = `last_active_at` in window OR a session refresh in window (so the KPI does not drop to zero on deploy); `RefreshTokenRepository.countDistinctUsersSince` removed as unused. `SuperAdminUserResponse.lastActiveAt`; web: a sortable "Utolsó aktivitás" column (relative time, absolute in the tooltip, "—" when unknown). Tests: tracker (fake clock: throttle, window, per-user, failure + retry), filter (stamps only on an accepted token), repository against Postgres.
- **S4 (goal attribution) — done.** `V81__nutrition_goals_attribution.sql` (`nutrition_goals_set_by` FK `on delete set null`, `nutrition_goals_set_at`, FK index). `SettingsServiceImpl` stamps in three places — the client's settings `update`, `applyGoals`, and the trainer path (`updateNutritionGoalsForUser` now takes the actor) — **only when one of the four values differs**; `GoalsSource` / `NutritionGoalsAttribution` carry the rules. Endpoints as in §3. Web: a clay chip "Az edződ állította be · szept. 12." on the client's Settings → daily goals (trainer-set only), and "Te állítottad be / Másik edző állította be / A kliens állította be · …" on the trainer's client Nutrition tab. Tests: the silent-failure case (an unrelated settings sync with unchanged goals never overwrites "set by your trainer"), clearing a goal counts, water/steps do not, the deleted-trainer case, and the FK behaviour against Postgres. **Mobile does not show the attribution yet** (data is there).
- **S5 (docs) — done.** `78` §6 rows closed, `REMAINING-WORK.md` rows removed, Postman gets *Invite history*, *Who set the nutrition goals*, *Client nutrition goals - who set them*, *List users by displayed role*.

### Verification

- **Real Postgres at last.** Docker was available this time, so `./mvnw -B verify` ran the whole suite against Testcontainers Postgres 16 — Flyway applied V1–V81 and Hibernate's schema validation passed — plus `WebBackendGapsRepositoryTest` (role-kind filter precedence and paging, `touchLastActive` window, `countActiveSince` on either signal counted once, the invite-history entity graph, attribution columns and `on delete set null`). That run also surfaced a *pre-existing* failure unrelated to this plan: `BackfillTrainerTrialsMigrationTest` expected `now + 30×24 h` while the migration adds 30 calendar days in the session time zone, so it failed by exactly one hour for the month before every clock change; the test now computes 30 calendar days.
- `JpqlQueryValidationTest` (no database) parses every `@Query` in the project; it caught nothing here, but it is what made the S1 query safe to write before Docker was around.
- Not done: an end-to-end click-through of the web screens against a running backend (the unit/e2e suites that need a seeded backend were not run), and the mobile app does not use any of this.
