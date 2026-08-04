# Deploy — Backend on Render (+ Neon Postgres)

The Spring Boot backend runs on **Render** as a Docker Web Service, against a
**Neon** serverless PostgreSQL database. Both replaced the previous Railway
setup (app + managed Postgres); the old runbook is kept at
[deploy-backend-railway.md](deploy-backend-railway.md) for the rollback window
only.

Build config lives in the repo:
- [`backend/Dockerfile`](../backend/Dockerfile) — multi-stage (Temurin 24 JDK build
  → JRE runtime), heap capped via `JAVA_OPTS` for a 512 MB instance.
- [`render.yaml`](../render.yaml) — Blueprint: Docker runtime, health check at
  `/actuator/health`, non-secret env vars. Secrets are `sync: false` (dashboard-only).

> **Public URL:** fill in once the service exists — Render assigns
> `https://<service-name>.onrender.com`. Several places still need that value;
> see [Post-creation checklist](#post-creation-checklist).

## How it runs

- The container binds to Render's injected **`$PORT`** (falls back to `8080`
  locally) — never a hardcoded port. Don't set `PORT` yourself.
- **Flyway** runs migrations automatically on startup (`spring.flyway.enabled=true`);
  `spring.jpa.hibernate.ddl-auto=validate` means Hibernate only validates the
  schema, it never mutates it. All schema changes go through
  `backend/src/main/resources/db/migration/V*.sql`.
- Health: `/actuator/health` is public (returns plain `UP`/`DOWN`, no details) so
  the probe passes the JWT filter. Only the health endpoint is exposed over HTTP;
  nothing else from actuator. Render **gates deploys on it** — a broken datasource
  fails the health check and the previous version keeps serving.
- Heap: `JAVA_OPTS=-Xms96m -Xmx256m -XX:MaxMetaspaceSize=96m`. Render's Free and
  Starter instances are both 512 MB, and total RSS is heap + metaspace + thread
  stacks + code cache + native — so the cap sits well below the limit rather than
  at it. Override `JAVA_OPTS` in the Render environment to retune on a bigger plan
  without a rebuild.
- The filesystem is **ephemeral**. Nothing depends on it: images are `bytea`
  columns in Postgres, and the push credential files are regenerated from env vars
  at every start (see [Secret files](#secret-files-apns-p8-firebase-json)).

## Plan choice

Not a cost detail — it changes behaviour. A **Free** Render service spins down
after ~15 minutes with no inbound traffic, and a spun-down container runs no
`@Scheduled` work. The app has four scheduled jobs
(`WorkoutReminderJob` every 15 min, `TrainerWeeklyReportJob` Mondays 05:00,
`PasswordResetTokenCleanupJob` 03:00, `TrainerClientCleanupJob` 03:30). On Free,
the nightly and weekly ones would essentially never fire, and reminders only when
unrelated traffic happens to keep the service awake. Cold start is also a real
cost here: waking a spun-down JVM is ~40–70 s including Flyway validation and a
Neon compute resume, which is longer than the mobile client's HTTP timeout.

→ Use **Starter** if push reminders and the scheduled jobs matter. An external
cron pinger is not an equivalent workaround: it keeps the service warm but can't
make a 03:00 job run inside its window if the container happened to be down.

## Database — Neon

### Connection string

Neon hands out a `postgresql://…` URL. Spring wants the **JDBC** form, with user
and password as separate variables:

```
SPRING_DATASOURCE_URL=jdbc:postgresql://ep-xxxx-123456.eu-central-1.aws.neon.tech/lifey?sslmode=require
SPRING_DATASOURCE_USERNAME=<neon user>
SPRING_DATASOURCE_PASSWORD=<neon password>
```

Two things that are easy to get wrong:

- **`sslmode=require` is mandatory** — Neon refuses plaintext connections. The
  PostgreSQL JDBC driver (42.x) does SNI, so no `options=endpoint%3D…` workaround
  is needed.
- **Use the direct endpoint, not the `-pooler` one.** Flyway takes a session-level
  advisory lock around migrations, which PgBouncer's transaction pooling does not
  preserve. The Hikari pool is capped at 5 connections anyway, far below the direct
  connection limit.

Keep the Render service in the **same region as the Neon project** — a JPA
workload makes many small round-trips and a cross-region hop taxes each one.

### Pool settings

`application.yml` configures Hikari for Neon's scale-to-zero: `minimum-idle: 0`,
`idle-timeout: 60000`, `max-lifetime: 240000`. A permanently warm pool would stop
the Neon compute from ever suspending, and a connection held across a suspend
comes back dead — with the borrowing request being the one that discovers it. The
trade is that a request arriving into an empty pool pays one handshake plus, if
the compute had suspended, Neon's resume of a few hundred ms.

### Pre-flight checks on a restored dump

Because the schema is Flyway-managed and Hibernate runs `ddl-auto=validate`, a
restored database that is missing its migration history will make the app try to
re-run `V1` and fail on startup. Check before deploying:

```bash
psql "postgresql://<user>:<pass>@<endpoint>/lifey?sslmode=require" -c "select installed_rank, version, description, success from flyway_schema_history order by installed_rank desc limit 5;"
```

Expected: the top row is the highest `V##` present in
`backend/src/main/resources/db/migration/` with `success = t`.

```bash
psql "postgresql://<user>:<pass>@<endpoint>/lifey?sslmode=require" -c "\dx"
```

`unaccent` must be listed — `V47__unaccent_search.sql` builds the food search on
it. If a data-only dump left it out: `CREATE EXTENSION unaccent;`.

Also spot-check that sequences carried over (`select last_value from users_id_seq;`
— a sequence reset to 1 means the first insert dies on a duplicate key) and
compare row counts on `users`, `workout_sessions`, `meals`, `foods` against the
source database.

## First-time setup

1. **Create the database.** Neon → new project, region chosen to match where the
   Render service will run. Restore the dump, then run the
   [pre-flight checks](#pre-flight-checks-on-a-restored-dump).
2. **Create the service.** Render → **New → Web Service** → connect the Lifey repo.
   - **Runtime:** Docker
   - **Root Directory:** `backend`
   - **Health Check Path:** `/actuator/health`
   - **Region:** same as Neon
   - **Plan:** see [Plan choice](#plan-choice)

   Or, equivalently: **New → Blueprint** and let Render read
   [`render.yaml`](../render.yaml), which encodes all of the above.
3. **Set the environment variables** (next section). At minimum the three
   `SPRING_DATASOURCE_*` and `JWT_SECRET`.
4. **Deploy.** The first build is slow (~5–10 min: the Docker build downloads the
   full Maven dependency tree). Watch for the Flyway migration list and
   `Started LifeyApplication` in the logs.
5. Run the [verification](#verification) steps, then the
   [post-creation checklist](#post-creation-checklist).

## Environment variables

### Required in any shared/production environment
| Variable | Purpose |
|---|---|
| `SPRING_DATASOURCE_URL` / `_USERNAME` / `_PASSWORD` | Neon connection — JDBC form, `?sslmode=require`, direct (non-pooler) endpoint. |
| `JWT_SECRET` | **Must** override the dev default — anyone with it can forge tokens for any user. Use a long random string. **When migrating hosts, carry the existing value over**: a new secret invalidates every issued access and refresh token and logs everyone out. |
| `SPRING_PROFILES_ACTIVE` | `prod` — disables Swagger/OpenAPI, turns mail on, turns the starter catalog off. Set in `render.yaml`. |

### Cross-origin / web (details in [deploy-web-vercel.md](deploy-web-vercel.md))
| Variable | Example | Purpose |
|---|---|---|
| `CORS_ALLOWED_ORIGINS` | `https://lifey-web.vercel.app` | Exact web origin(s), comma-separated, no wildcard. |
| `COOKIE_SECURE` | `true` | Required for the cross-site refresh cookie. |
| `COOKIE_SAME_SITE` | `None` | Cross-site cookie needs `None` + `Secure`. |

### Feature integrations (each has its own doc)
| Variable group | Feature | Doc |
|---|---|---|
| `MAIL_ENABLED`, `RESEND_API_KEY`, `MAIL_FROM` | Email | [email-sender.md](email-sender.md) |
| `PUSH_APNS_*` | iOS push | [push-notifications-ios.md](push-notifications-ios.md) |
| `PUSH_FCM_*` | Android push | [push-notifications-android.md](push-notifications-android.md) |
| `OAUTH_GOOGLE_CLIENT_IDS` | Google Sign-In (comma-separated Android/iOS/Web client IDs) | — |
| `TRAINER_INVITE_EMAIL_ENABLED`, `TRAINER_INVITE_PUBLIC_BASE_URL` | Email trainer invites — the base URL must point at the **Render** domain, or the accept/decline links in sent invites are dead. | — |

### Tuning (optional)
| Variable | Default | Purpose |
|---|---|---|
| `JAVA_OPTS` | `-Xms96m -Xmx256m -XX:MaxMetaspaceSize=96m` | JVM heap/metaspace, sized for a 512 MB instance. Raise on a bigger plan. |
| `JWT_ACCESS_TTL` / `JWT_REFRESH_TTL` | `7d` / `30d` | Token lifetimes. |
| `STARTER_CATALOG_ENABLED` | `true` | Seed new users with a starter exercise catalog. Already **off** in the `prod` profile. |
| `JOB_*_CRON` | see `application.yml` | Schedules for the four background jobs. |
| `PORT` | injected by Render | Don't set manually. |

## Secret files (APNs `.p8`, Firebase JSON)

Push needs credential **files** on disk (`PUSH_APNS_KEY_PATH`,
`PUSH_FCM_CREDENTIALS_PATH`), and Render has no secret-file mount — only
environment variables and (on paid plans) persistent disks. So the file is
*materialized* at startup: the credential is stored **base64-encoded in an env
var**, and the Docker `ENTRYPOINT` decodes it to a path before launching the app.

**1. Base64-encode the credential locally** (PowerShell):
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\secrets\firebase.json"))
```
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\secrets\apns.p8"))
```

**2. Set the variables on the Render service:**
```
# Android / FCM
PUSH_FCM_ENABLED=true
PUSH_FCM_CREDENTIALS_B64=<base64 of firebase.json>
PUSH_FCM_CREDENTIALS_PATH=/tmp/firebase.json

# iOS / APNs
PUSH_APNS_ENABLED=true
PUSH_APNS_KEY_B64=<base64 of the .p8>
PUSH_APNS_KEY_PATH=/tmp/apns.p8
# (+ PUSH_APNS_KEY_ID / TEAM_ID / BUNDLE_ID / SANDBOX — see the iOS doc)
```

**3. The [`Dockerfile`](../backend/Dockerfile) `ENTRYPOINT` writes each file only
when its `*_B64` var is set**, so a service with push disabled boots unchanged:
```dockerfile
ENTRYPOINT ["sh", "-c", "\
  if [ -n \"$PUSH_FCM_CREDENTIALS_B64\" ]; then echo \"$PUSH_FCM_CREDENTIALS_B64\" | base64 -d > \"${PUSH_FCM_CREDENTIALS_PATH:-/tmp/firebase.json}\"; fi; \
  if [ -n \"$PUSH_APNS_KEY_B64\" ]; then echo \"$PUSH_APNS_KEY_B64\" | base64 -d > \"${PUSH_APNS_KEY_PATH:-/tmp/apns.p8}\"; fi; \
  java $JAVA_OPTS -jar app.jar"]
```

`/tmp` is fine — the file is regenerated from the variable on every deploy and
restart, so it doesn't need to survive. The base64 wrapper (vs. pasting raw
JSON/PEM into a variable) avoids newline- and quote-mangling in multi-line
credentials.

> If these values were marked **Sealed** on the old Railway service, they can no
> longer be read back from it — re-encode from the original credential files.

## Deployments & CI

- **CI:** [`.github/workflows/backend-ci.yml`](../.github/workflows/backend-ci.yml)
  runs the test suite (JUnit + Testcontainers Postgres) on pushes/PRs touching
  `backend/**`.
- **Auto-deploy:** Render redeploys on push to `main` via its own Git integration,
  independent of GitHub CI. Keep `main` protected so only CI-green PRs merge.
- **Migrations run on deploy:** a new `V*.sql` applies automatically at startup.
  Never edit an already-applied migration — add a new one. Flyway validates
  checksums and refuses to start if a past migration file changed.
- **Deploys are health-gated:** if the new version fails `/actuator/health`, Render
  keeps the previous one live.

## Verification

1. `GET https://<render-domain>/actuator/health` → `{"status":"UP"}`.
2. `GET https://<render-domain>/swagger-ui.html` → **404** (proves the `prod`
   profile is active; a 200 here means `SPRING_PROFILES_ACTIVE` didn't take).
3. Log in with an existing account → `200` plus tokens. This exercises the
   restored data *and* confirms `JWT_SECRET` carried over.
4. One authenticated read (e.g. statistics) and one write (e.g. a water log) →
   `200`, and the write is visible in Neon.
5. Deploy logs show Flyway reaching the latest `V##` and
   `Started LifeyApplication in N seconds`.
6. Render → Metrics: memory settles well under 512 MB after warm-up.

## Post-creation checklist

Once the service exists and its URL is known, these still point at the old host:

- [ ] `_productionUrl` in [`mobile/lib/core/network/api_config.dart`](../mobile/lib/core/network/api_config.dart)
      → the Render URL + `/api/v1`. **Requires a new app build.**
- [ ] `NEXT_PUBLIC_API_BASE_URL` on Vercel → the Render URL + `/api/v1`. It is
      inlined at build time, so **redeploy** the web app; a restart is not enough.
- [ ] `TRAINER_INVITE_PUBLIC_BASE_URL` on the Render service → the Render URL.
- [ ] `CORS_ALLOWED_ORIGINS` — unchanged if the web domain didn't move.
- [ ] Replace the URL placeholders in this doc, [README.md](README.md),
      [`web/DEPLOY.md`](../web/DEPLOY.md) and [`mobile/RUNNING.md`](../mobile/RUNNING.md).

> **Worth doing now:** put a custom domain (e.g. `api.lifey.app`) in front of the
> service under Render → Settings → Custom Domains. The reason this migration
> touches a mobile build and a web redeploy at all is that a host-assigned URL is
> baked into both. With an own domain, this is the last time.

## Cutover from Railway

The app is not publicly released, so a short, deliberate outage beats trying to
run both hosts against diverging databases.

1. **Freeze** usage (or just do it overnight).
2. **Re-dump** the Railway database and restore it into Neon. Any dump taken
   during preparation is stale by now.
3. Re-run the [pre-flight checks](#pre-flight-checks-on-a-restored-dump) on the
   fresh data.
4. **Redeploy** the Render service so it definitely connects to the fresh
   database, then run [verification](#verification).
5. **Redeploy the web** app with the new API base URL; **build the mobile** app
   with the new `_productionUrl`.
6. **Stop the Railway backend service** — but keep the **Railway Postgres** for
   at least a week or two as the rollback path.

**Rollback:** restart the Railway service and revert the client URLs. The Railway
database is untouched, so this works until real data lands in Neon that you're
unwilling to lose — after that the move is one-way.

## Troubleshooting

- **Boot fails, `FlywayValidateException`:** an applied migration file was edited,
  or the restored database is missing `flyway_schema_history`. Never modify applied
  `V*.sql`.
- **Boot fails on schema `validate`:** an entity doesn't match the DB — either a
  migration is missing for a new column/table, or the dump restored an older schema.
- **`FATAL: password authentication failed` / SSL errors:** check the JDBC URL keeps
  `?sslmode=require` and that the username is Neon's role, not the database name.
- **Migrations hang or time out:** you're on the Neon `-pooler` endpoint. Flyway's
  advisory lock needs the direct one.
- **Container killed / OOM:** lower `JAVA_OPTS` heap or move to a bigger instance;
  the 512 MB limit is enforced by killing the process.
- **First request after a quiet period fails or is very slow:** on a Free plan
  that's the service spinning back up (see [Plan choice](#plan-choice)); on any plan
  a few hundred ms of it is Neon resuming its compute.
- **401 on `/actuator/health`:** the health check path drifted — it must stay a
  public endpoint (`render.yaml` → `healthCheckPath`).
- **Scheduled jobs never run:** Free plan spin-down. See [Plan choice](#plan-choice).
