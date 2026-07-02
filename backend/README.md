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
| `RESEND_API_KEY` | *(none)* | [Resend](https://resend.com) API key used to send transactional email |
| `MAIL_FROM` | `onboarding@resend.dev` | Sender address — Resend's shared test domain until a real domain is verified |
| `MAIL_ENABLED` | `true` | When `false` (or when `RESEND_API_KEY` is missing/invalid), mail sends fail silently and are only logged — registration/password-reset requests never fail because of it |

None of these are committed. Local values go in `.env` (gitignored); deployment values are set on the host (Railway env vars, etc.).

## Setting up Resend

Transactional email (welcome mail, password reset codes) goes out via the [Resend](https://resend.com) HTTPS API rather than SMTP — PaaS hosts like Railway commonly block outbound SMTP ports, but the API goes over 443.

1. Sign up at [resend.com](https://resend.com) (no credit card required) and create an API key.
2. Put it in `RESEND_API_KEY` in your local `.env` or the deployment's env vars.
3. Without a verified domain, sending uses `onboarding@resend.dev` as the `from` address — Resend only delivers those to the email address the account was signed up with, which is enough for testing. Once a real domain is verified in Resend, set `MAIL_FROM` to an address on that domain to send to anyone.

Without a valid `RESEND_API_KEY`, the app still boots and serves requests normally; outgoing mail just fails (and is logged) instead of sending.
