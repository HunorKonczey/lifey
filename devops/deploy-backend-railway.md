# Deploy — Backend on Railway

The Spring Boot backend runs on **Railway** as a Docker service, next to a managed
**PostgreSQL 16** database. Current production URL:
`https://lifey-production-7aa5.up.railway.app`.

Build config lives in the repo:
- [`backend/Dockerfile`](../backend/Dockerfile) — multi-stage (Temurin 24 JDK build
  → JRE runtime), heap capped via `JAVA_OPTS` for a small plan.
- [`backend/railway.toml`](../backend/railway.toml) — Dockerfile builder, healthcheck
  at `/actuator/health`, restart-on-failure.

## How it runs

- The container binds to Railway's injected **`$PORT`** (falls back to `8080`
  locally) — never a hardcoded port.
- **Flyway** runs migrations automatically on startup (`spring.flyway.enabled=true`);
  `spring.jpa.hibernate.ddl-auto=validate` means Hibernate only validates the
  schema, it never mutates it. All schema changes go through
  `backend/src/main/resources/db/migration/V*.sql`.
- Health: `/actuator/health` is public (returns plain `UP`/`DOWN`, no details) so
  Railway's probe passes the JWT filter. Only the health endpoint is exposed over
  HTTP; nothing else from actuator.
- Heap: `JAVA_OPTS=-Xms128m -Xmx384m -XX:MaxMetaspaceSize=128m` keeps total RSS
  under a 1 GB plan. Override `JAVA_OPTS` in Railway env to retune without a
  rebuild.

## First-time setup

1. **Create the project & database.** Railway → New Project → **Provision
   PostgreSQL**. This gives you the DB service and its connection variables.
2. **Add the backend service.** New → **GitHub Repo** → select the Lifey repo.
   - **Root Directory:** `backend`
   - **Builder:** Dockerfile (auto-detected from `railway.toml`).
3. **Wire the database.** In the backend service's Variables, reference the
   Postgres service. Spring expects:
   ```
   SPRING_DATASOURCE_URL=jdbc:postgresql://<host>:<port>/<db>
   SPRING_DATASOURCE_USERNAME=<user>
   SPRING_DATASOURCE_PASSWORD=<password>
   ```
   Use Railway's variable references (e.g. `${{Postgres.PGHOST}}` etc.) to build
   the JDBC URL so it tracks the DB service automatically. Note the JDBC URL must
   be the `jdbc:postgresql://...` form, not Railway's bare `postgres://` URL.
4. **Set the required app secrets** (see the table below). At minimum `JWT_SECRET`.
5. **Generate a public domain:** Settings → Networking → Generate Domain.
6. Deploy. Watch the deploy logs for the Flyway migration list and
   `Started LifeyApplication`.

## Environment variables

### Required in any shared/production environment
| Variable | Purpose |
|---|---|
| `SPRING_DATASOURCE_URL` / `_USERNAME` / `_PASSWORD` | Database connection. |
| `JWT_SECRET` | **Must** override the dev default — anyone with it can forge tokens for any user. Use a long random string. |

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
| `TRAINER_INVITE_EMAIL_ENABLED`, `TRAINER_INVITE_PUBLIC_BASE_URL` | Email trainer invites | — |

### Tuning (optional)
| Variable | Default | Purpose |
|---|---|---|
| `JAVA_OPTS` | `-Xms128m -Xmx384m -XX:MaxMetaspaceSize=128m` | JVM heap/metaspace. Raise on a bigger plan. |
| `JWT_ACCESS_TTL` / `JWT_REFRESH_TTL` | `7d` / `30d` | Token lifetimes. |
| `STARTER_CATALOG_ENABLED` | `true` | Seed new users with a starter exercise catalog. Turn **off** in prod. |
| `PORT` | injected by Railway | Don't set manually on Railway. |

## Secret files (APNs `.p8`, Firebase JSON)

Push needs credential **files** on disk (`PUSH_APNS_KEY_PATH`,
`PUSH_FCM_CREDENTIALS_PATH`). **Railway has no secret-file / config-file upload**
— it only has environment **Variables** and persistent **Volumes** (neither is a
"paste a file, mount it at a path" feature). So the file has to be *materialized*
on the container at startup. The approach used here: store the credential
**base64-encoded in a Variable**, and let the Docker `ENTRYPOINT` decode it to a
file before launching the app.

**1. Base64-encode the credential locally** (PowerShell):
```powershell
# Firebase service-account JSON
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\secrets\firebase.json"))
# APNs .p8 key
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\secrets\apns.p8"))
```

**2. Set Variables on the backend service** (mark the `*_B64` ones **Sealed** —
Railway then never shows them in the UI or API):
```
# Android / FCM
PUSH_FCM_ENABLED=true
PUSH_FCM_CREDENTIALS_B64=<base64 of firebase.json>   # sealed
PUSH_FCM_CREDENTIALS_PATH=/tmp/firebase.json

# iOS / APNs
PUSH_APNS_ENABLED=true
PUSH_APNS_KEY_B64=<base64 of the .p8>                # sealed
PUSH_APNS_KEY_PATH=/tmp/apns.p8
# (+ PUSH_APNS_KEY_ID / TEAM_ID / BUNDLE_ID / SANDBOX — see the iOS doc)
```

**3. Decode at startup in [`backend/Dockerfile`](../backend/Dockerfile)** — the
`ENTRYPOINT` writes each file only when its `*_B64` var is set, so a service
with push disabled (no vars) still boots unchanged:
```dockerfile
ENTRYPOINT ["sh", "-c", "\
  if [ -n \"$PUSH_FCM_CREDENTIALS_B64\" ]; then echo \"$PUSH_FCM_CREDENTIALS_B64\" | base64 -d > \"${PUSH_FCM_CREDENTIALS_PATH:-/tmp/firebase.json}\"; fi; \
  if [ -n \"$PUSH_APNS_KEY_B64\" ]; then echo \"$PUSH_APNS_KEY_B64\" | base64 -d > \"${PUSH_APNS_KEY_PATH:-/tmp/apns.p8}\"; fi; \
  java $JAVA_OPTS -jar app.jar"]
```

`/tmp` is fine — the file is regenerated from the Variable on every deploy/
restart, so it doesn't need to survive on a Volume. The base64 wrapper (vs.
pasting raw JSON/PEM into a Variable) avoids newline- and quote-mangling in
multi-line credentials.

> **Alternative — Railway Volume:** attach a persistent Volume and place the
> real file on it once. Rejected here as more awkward: populating a Volume needs
> a one-off shell/deploy step, and the file then lives outside version-tracked
> config. The base64-Variable approach keeps the credential in Railway's own
> (sealed) secret store and needs no manual file placement.

## Deployments & CI

- **CI:** [`.github/workflows/backend-ci.yml`](../.github/workflows/backend-ci.yml)
  runs the test suite (JUnit + Testcontainers Postgres) on pushes/PRs touching
  `backend/**`.
- **Auto-deploy:** Railway redeploys the backend on push to `main` (its own Git
  integration, independent of GitHub CI). Keep `main` protected so only
  CI-green PRs merge.
- **Migrations run on deploy:** a new `V*.sql` applies automatically at startup.
  Never edit an already-applied migration — add a new one. Flyway validates
  checksums and will refuse to start if a past migration file changed.

## Verification

1. `GET https://<backend-domain>/actuator/health` → `{"status":"UP"}`.
2. `GET https://<backend-domain>/swagger-ui.html` loads the API docs.
3. Register/login through the web or app and confirm `200`s.
4. Deploy logs show the Flyway version climbing to the latest `V##` and
   `Started LifeyApplication in N seconds`.

## Troubleshooting

- **Boot fails, `FlywayValidateException`:** an applied migration file was edited,
  or migrations are out of order. Never modify applied `V*.sql`.
- **Boot fails on schema `validate`:** an entity doesn't match the DB — a
  migration is missing for a new column/table.
- **Container killed / OOM:** lower `JAVA_OPTS` heap or move to a bigger plan;
  the free tier kills rather than constrains.
- **401 on `/actuator/health`:** the healthcheck path drifted — it must stay a
  public endpoint (`railway.toml` → `healthcheckPath = /actuator/health`).
- **Service never sleeps / unexpected egress:** a connection pool that keeps a DB
  connection open counts as traffic. The Hikari idle settings are commented in
  `application.yml` if you need the service to go idle on a Serverless plan.
