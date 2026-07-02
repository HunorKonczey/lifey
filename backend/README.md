# Lifey Backend

Spring Boot 4 / Java 24 / Maven API for the Lifey fitness & nutrition tracker. See [CLAUDE.md](CLAUDE.md) for architecture and conventions.

## Running locally

```
./mvnw spring-boot:run
```

Requires a local Postgres (see `../docker-compose.yml`) and, optionally, a `.env` file at the repo root (`../.env`, copy from `../.env.example`) — `docker-compose` reads it automatically for the vars below.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `SPRING_DATASOURCE_URL` / `_USERNAME` / `_PASSWORD` | local Postgres | Database connection |
| `JWT_SECRET` | dev-only placeholder | **Must** be overridden in any shared/production environment |
| `MAIL_USERNAME` | `hunot08adf@gmail.com` | Gmail SMTP sender address |
| `MAIL_PASSWORD` | *(none)* | Gmail **App Password** (see below) — never the account's normal login password |
| `MAIL_ENABLED` | `true` | When `false` (or when `MAIL_PASSWORD` is missing/invalid), mail sends fail silently and are only logged — registration/password-reset requests never fail because of it |

None of these are committed. Local values go in `.env` (gitignored); deployment values are set on the host (Railway env vars, etc.).

## Setting up the Gmail App Password

Transactional email (welcome mail, password reset codes) goes out via Gmail SMTP, which requires a Google **App Password**, not the account's normal password.

1. Sign in to the `MAIL_USERNAME` Gmail account.
2. Enable **2-Step Verification** on that account (required before an App Password can be generated) — Google Account → Security → 2-Step Verification.
3. Go to [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords), give it a name (e.g. "Lifey backend"), and generate a 16-character password.
4. Put it in `MAIL_PASSWORD` in your local `.env` or the deployment's env vars. It's shown only once — revoke and regenerate from the same page if lost.

Without a valid `MAIL_PASSWORD`, the app still boots and serves requests normally; outgoing mail just fails (and is logged) instead of sending.
