# Password Management + Transactional Email Plan

Covers three related features, built on the existing custom JWT auth module (see `08-auth-module.md`):

1. **Email infrastructure** — backend can send transactional emails (sender: `hunot08adf@gmail.com` for now).
2. **Registration email** — welcome email sent after successful registration.
3. **Forgot password** — email-based reset flow (web + mobile).
4. **Change password** — logged-in user changes password from settings (web + mobile).

Existing constraints that apply:

- Spring Boot 4, Java 24, Maven, Flyway, feature-based packaging, constructor injection.
- Refresh tokens are stored in DB with a revocation flag — password reset/change must revoke all sessions (the entity was designed for this, see `08-auth-module.md` "Refresh Token Persistence").
- Controllers never accept userId; current user always resolved from security context.
- Never reveal whether an email address is registered (anti-enumeration).

---

## Design decisions (made up front so all phases agree)

### Email transport

~~Gmail SMTP with an App Password~~ — **superseded, see below.** Originally sent via `smtp.gmail.com:587` (STARTTLS) using `spring-boot-starter-mail`, but Railway (and most PaaS hosts) block outbound SMTP ports, so every send timed out in production (`Connection timed out` on port 587) and the `MailHealthIndicator` also made `/actuator/health` hang and fail Railway's healthcheck.

**Current: Resend HTTPS API** (`https://api.resend.com/emails`, port 443 — not blocked). `com.lifey.mail.ResendMailService` posts via Spring's `RestClient` (no extra dependency, already available from `spring-boot-starter-web`); `spring-boot-starter-mail` was removed from `pom.xml`.

- Config: `lifey.mail.resend-api-key` (env `RESEND_API_KEY`, no default), `lifey.mail.from` (env `MAIL_FROM`, defaults to `onboarding@resend.dev`), `lifey.mail.enabled` (env `MAIL_ENABLED`).
- **Current limitation:** sending `from` the shared `onboarding@resend.dev` test domain only delivers to the email address the Resend account was signed up with (currently `hunorkonczey@gmail.com`) — fine for solo testing, not usable for real users until a custom domain is verified (see "Future: custom domain for email" below).
- Emails are still sent **asynchronously** (`@Async`) and failures are logged but never fail the triggering request (registration must succeed even if the welcome email bounces).

### Reset mechanism: 6-digit code (not link)

One flow works identically on web and mobile, no deep-link setup needed:

- User requests reset → receives a **6-digit numeric code** by email.
- Code is valid **15 minutes**, single-use, stored **hashed** (reuse `TokenHasher`), max **5 verification attempts** per code.
- Rate limit: max 3 reset requests per email per hour (silently swallow extras).
- On successful reset: revoke **all** refresh tokens for the user.

### Email language

User entity / user_settings already store language (`V11__user_settings_language.sql`). Send the email in the user's language, fallback English. For forgot-password (user may not be resolvable before lookup) use the stored user's language; the anti-enumeration 200-response never reveals anything either way.

### Email wording

Plain, friendly, no marketing. Both languages, HTML + plain-text fallback. Templates live in `src/main/resources/mail/` as simple HTML files with `{{placeholders}}` (no Thymeleaf/Freemarker — do not add a template engine dependency for two emails; simple `String.replace` is fine).

**Welcome (EN)** — subject: `Welcome to Lifey 🎉`

> Hi {{name}},
>
> Your Lifey account is ready. Track your workouts, meals, water and weight — all in one place.
>
> If you didn't create this account, you can safely ignore this email.
>
> — The Lifey team

**Welcome (HU)** — subject: `Üdvözlünk a Lifey-ban 🎉`

> Szia {{name}},
>
> A Lifey fiókod elkészült. Kövesd az edzéseidet, étkezéseidet, vízfogyasztásodat és súlyodat — mind egy helyen.
>
> Ha nem te hoztad létre ezt a fiókot, nyugodtan hagyd figyelmen kívül ezt az emailt.
>
> — A Lifey csapat

**Password reset (EN)** — subject: `Your Lifey password reset code`

> Hi {{name}},
>
> Your password reset code is:
>
> **{{code}}**
>
> The code is valid for 15 minutes. If you didn't request a password reset, ignore this email — your password stays unchanged.
>
> — The Lifey team

**Password reset (HU)** — subject: `Lifey jelszó-visszaállító kódod`

> Szia {{name}},
>
> A jelszó-visszaállító kódod:
>
> **{{code}}**
>
> A kód 15 percig érvényes. Ha nem te kérted a jelszó visszaállítását, hagyd figyelmen kívül ezt az emailt — a jelszavad változatlan marad.
>
> — A Lifey csapat

### New endpoints

```http
POST /api/auth/forgot-password   { "email" }                          → 200 always (public)
POST /api/auth/reset-password    { "email", "code", "newPassword" }   → 200 / 400 (public)
POST /api/auth/change-password   { "currentPassword", "newPassword" } → 200 / 400 (authenticated)
```

`forgot-password` and `reset-password` must be added to the public matcher list in `SecurityConfig`.

Password policy for `newPassword`: same validation as registration (single source of truth — extract a shared validator if registration currently inlines it).

### Database

Flyway `V36__password_reset_tokens.sql`:

```sql
CREATE TABLE password_reset_tokens (
    id          UUID PRIMARY KEY,
    user_id     BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    code_hash   VARCHAR(255) NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ,
    attempts    INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_prt_user_id ON password_reset_tokens (user_id);
```

Requesting a new code invalidates (deletes or marks used) previous unused codes for the same user.

---

## Phase 1 — Backend: mail infrastructure

**Prompt:**

> In the Lifey backend (Spring Boot 4, Java 24, Maven), add transactional email support in a new `com.lifey.mail` package.
>
> - Add `spring-boot-starter-mail`. Configure Gmail SMTP (`smtp.gmail.com:587`, STARTTLS) via `application.yml` with env-var placeholders: `MAIL_USERNAME` (default `hunot08adf@gmail.com`), `MAIL_PASSWORD` (no default). Add a `MailProperties`-style `@ConfigurationProperties` record (`app.mail.from`, `app.mail.enabled`) — when `app.mail.enabled=false` (default in `test` profile and local dev without credentials), the sender logs instead of sending.
> - Create a `MailService` interface with intent-based methods (`sendWelcomeEmail(User user)`, `sendPasswordResetEmail(User user, String code)`) and an SMTP implementation. Callers must never build subjects/bodies themselves.
> - Templates as HTML files under `src/main/resources/mail/` (`welcome_en.html`, `welcome_hu.html`, `password_reset_en.html`, `password_reset_hu.html`) plus plain-text variants; substitution via simple placeholder replace, no template engine. Wording exactly as specified in `docs/19-password-email-plan.md`.
> - Pick language from the user's stored language setting, fallback `en`.
> - Sending is `@Async` (enable `@EnableAsync` if not present, dedicated small executor). Failures are caught and logged with the recipient and mail type — they must never propagate to the caller.
> - Constructor injection, no Lombok if the project doesn't use it. Unit test the template rendering and the enabled=false path.

---

## Phase 2 — Backend: welcome email on registration

**Prompt:**

> In the Lifey backend, after a successful registration (`POST /api/auth/register`), send the welcome email via `MailService.sendWelcomeEmail(user)`.
>
> - Call it after the user row is committed (after the transaction, e.g. `TransactionalEventListener(AFTER_COMMIT)` with a `UserRegisteredEvent`, or simply invoke the async method after the service method returns — choose the simpler option that guarantees the user exists when the mail job runs, and explain the choice).
> - Registration response/latency must not change; a mail failure must not fail registration.
> - Add/extend an integration test: register → assert mail service invoked with the right user and language (mock or `enabled=false` log capture).

---

## Phase 3 — Backend: forgot / reset password

**Prompt:**

> In the Lifey backend, implement the forgot-password flow per `docs/19-password-email-plan.md` in the existing `com.lifey.auth` package.
>
> - Flyway `V36__password_reset_tokens.sql` exactly as in the plan doc.
> - `POST /api/auth/forgot-password {email}` (public): always returns 200 with a generic message. If the email exists: invalidate previous unused codes, generate a random 6-digit code (`SecureRandom`), store its hash (reuse `TokenHasher`), 15-minute expiry, send via `MailService.sendPasswordResetEmail`. Rate limit: if 3 codes were already created for that user in the last hour, silently do nothing.
> - `POST /api/auth/reset-password {email, code, newPassword}` (public): validates code (exists, unused, unexpired, hash matches, attempts < 5 — increment attempts on mismatch). On success: BCrypt-hash and set new password, mark code used, **revoke all refresh tokens of the user**. Return generic 400 (`invalid or expired code`) for every failure mode — do not distinguish.
> - `newPassword` uses the same validation rules as registration; extract shared validation if needed.
> - Add both endpoints to the public matchers in `SecurityConfig`.
> - Cleanup: scheduled job (daily) deleting expired/used tokens older than 24h.
> - Integration tests: happy path, wrong code attempts exhaustion, expired code, code reuse, rate limit, anti-enumeration (unknown email still 200), all-sessions-revoked assertion.

---

## Phase 4 — Backend: change password (authenticated)

**Prompt:**

> In the Lifey backend, add `POST /api/auth/change-password {currentPassword, newPassword}` for authenticated users in `com.lifey.auth`.
>
> - Resolve the user from the security context (`CurrentUserProvider`), never from the request.
> - Verify `currentPassword` with BCrypt; on mismatch return 400 with a dedicated error code.
> - Validate `newPassword` with the shared registration rules; reject if equal to the current password.
> - On success: update the hash and revoke **all** refresh tokens (the client will re-login or refresh its pair — return a fresh token pair in the response so the current device stays logged in; document this in the response DTO).
> - Integration tests: success + fresh tokens work + old refresh token rejected, wrong current password, weak new password.

---

## Phase 5 — Web: forgot/reset + change password UI

**Prompt:**

> In the Lifey web app (Next.js 16 App Router, TypeScript, react-hook-form + zod, TanStack Query, next-intl — follow `docs/web/04-frontend-architecture.md` conventions), implement:
>
> 1. `(auth)/forgot-password` page: email field → calls `POST /api/auth/forgot-password` → switches to a "code + new password" step (`reset-password` can be the same page with a step state or a separate route — match existing (auth) page patterns). Always show the generic "if this email exists, we sent a code" message. Code input: 6-digit, numeric. On success: toast + redirect to login.
> 2. Login page: add a "Forgot password?" link.
> 3. Settings: "Change password" section (current password, new password, confirm) calling `POST /api/auth/change-password`; on success store the returned fresh token pair exactly like login does, show success toast.
> 4. All texts via next-intl in `messages/en.json` and `messages/hu.json`.
> 5. Zod schemas mirror backend password rules. Handle 400s with field-level errors where the API distinguishes them, generic error otherwise.

---

## Phase 6 — Mobile: forgot/reset + change password UI

**Prompt:**

> In the Lifey Flutter app (`mobile/`, Riverpod + go_router + dio, feature-based packaging per `mobile/CLAUDE.md`), implement:
>
> 1. `features/auth`: "Forgot password?" link on `login_screen.dart` → new `forgot_password_screen.dart` with two steps: email entry → code + new password entry. Calls the two public endpoints through `auth_repository.dart` (these are online-only, no outbox involvement — auth already works that way).
> 2. `features/settings`: "Change password" tile → screen/sheet with current + new + confirm fields, calls `POST /api/auth/change-password`, stores the returned fresh token pair via the existing token storage path.
> 3. All strings through `l10n` (EN + HU ARB files).
> 4. Follow existing form validation and error-snackbar patterns (`app_snackbar.dart`); disable submit while in flight.
> 5. Note: these screens require connectivity; show the standard offline error if the request fails.

---

## Phase 7 — Verification checklist

- [ ] Register on web and mobile → welcome email arrives in the right language, registration latency unchanged.
- [ ] Forgot password with unknown email → same 200/UI message, no email.
- [ ] Reset happy path on both clients → old sessions logged out everywhere.
- [ ] 6 wrong codes → code burned; expired code rejected; code not reusable.
- [ ] Change password → other devices logged out, current device keeps working.
- [ ] `RESEND_API_KEY` absent → app still boots with mail disabled, logs instead of sending.
- [ ] Resend setup documented in backend README (env vars only, nothing committed).

---

## Future: custom domain for email (unblocks sending to any recipient)

**Problem:** on the Resend shared test domain (`onboarding@resend.dev`), mail only delivers to the address the Resend account was signed up with. To send welcome/reset emails to real users, a verified custom domain is required.

**Plan:**

1. **Buy a domain** (not yet owned) — candidates: `lifey.app`, `lifey.dev`, `lifey.com`, or a `.hu` if preferred. Registrars considered: [Namecheap](https://www.namecheap.com) (cheap, easy), [Cloudflare Registrar](https://www.cloudflare.com/products/registrar/) (at-cost pricing, and doubles as the DNS host so SPF/DKIM records live in the same dashboard), or a `.hu`-specific registrar (Rackhost, Forpsi) if a `.hu` TLD is chosen.
2. **Add the domain in Resend** (Domains → Add Domain). Resend generates SPF (TXT), DKIM (CNAME/TXT), and optionally a DMARC record.
3. **Add those records at the DNS host** (registrar's DNS or Cloudflare if delegated there). Verification is usually automatic within minutes once records propagate.
4. **Update `MAIL_FROM`** (env var, both local `.env` and Railway) from `onboarding@resend.dev` to an address on the new domain, e.g. `noreply@lifey.app` or `hello@lifey.app`.
5. **Update `docs/19-password-email-plan.md` and `backend/README.md`** to drop the "test domain, self-only" caveat once verified.
6. No backend code changes needed — `ResendMailService` already reads `lifey.mail.from` from config, so switching domains is a config-only change.
