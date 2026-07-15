# Lifey DevOps & Operations

Operational runbooks for deploying and running Lifey in production. Each doc is
self-contained: setup steps, environment variables, verification, troubleshooting,
and routine maintenance (key rotation, etc.).

Written for the person doing the deploy/ops — assumes you have the relevant
console access (Railway, Vercel, Apple Developer, Google Play, Firebase, Resend)
but not that you remember how any of it was wired.

## Topology at a glance

| Component | Tech | Host | Public URL |
|---|---|---|---|
| Backend API | Spring Boot 4.1 (Java 24) | Railway (Docker) | `https://lifey-production-7aa5.up.railway.app` |
| Web admin | Next.js 16 | Vercel (primary) / Railway | *assigned by host* |
| Database | PostgreSQL 16 | Railway (managed) | private |
| Mobile | Flutter (`com.khunor.lifey`) | App Store / Google Play | — |

Identifiers reused across every doc:

- **Bundle ID / applicationId:** `com.khunor.lifey`
- **iOS App Groups:** `group.com.khunor.lifey`, `group.com.khunor.lifey.LifeyWidgets`
- **iOS widget target:** `LifeyWidgets` (Home-screen widget + Live Activity)
- **Android widget:** `TodaySummaryWidgetProvider`

## Documents

### Infrastructure / features
- [email-sender.md](email-sender.md) — Resend transactional email (welcome, password reset, trainer invite)
- [push-notifications-ios.md](push-notifications-ios.md) — APNs setup & operation (backend + app)
- [push-notifications-android.md](push-notifications-android.md) — FCM setup & operation (backend + app)

### Deployment
- [deploy-backend-railway.md](deploy-backend-railway.md) — backend on Railway
- [deploy-web-vercel.md](deploy-web-vercel.md) — web admin on Vercel (and Railway fallback)
- [deploy-ios-appstore.md](deploy-ios-appstore.md) — iOS build & App Store submission (incl. widget/Live Activity capabilities)
- [deploy-android-playstore.md](deploy-android-playstore.md) — Android build & Play Store submission
- [deploy-watch-testing.md](deploy-watch-testing.md) — Apple Watch & Wear OS companion app, dev/test install (no paid account needed)

## Secrets: the one rule

**No credential file or key ever goes into git.** Every secret below is supplied
at runtime as an environment variable or an injected file:

- `.p8` APNs key, Firebase service-account JSON, Play upload keystore, Google
  service-account JSON, Resend API key, JWT secret, DB password.
- The repo `.gitignore` already excludes `.env`; keep it that way.
- Store the originals in a password manager / secret vault, not on a laptop's
  Desktop. Several of these (APNs `.p8`, Play upload key) are **downloadable
  only once** — losing them means re-issuing.

## Cross-cutting env var index

Full details in each doc; this is the "where does X live" map.

| Variable | Component | Doc |
|---|---|---|
| `SPRING_DATASOURCE_*`, `JWT_SECRET`, `PORT`, `JAVA_OPTS` | Backend | [backend](deploy-backend-railway.md) |
| `CORS_ALLOWED_ORIGINS`, `COOKIE_SECURE`, `COOKIE_SAME_SITE` | Backend | [web](deploy-web-vercel.md) |
| `MAIL_ENABLED`, `RESEND_API_KEY`, `MAIL_FROM` | Backend | [email](email-sender.md) |
| `PUSH_APNS_*` | Backend | [ios push](push-notifications-ios.md) |
| `PUSH_FCM_*` | Backend | [android push](push-notifications-android.md) |
| `NEXT_PUBLIC_API_BASE_URL` | Web | [web](deploy-web-vercel.md) |
