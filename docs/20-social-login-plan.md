# Social Login Plan — Google / Apple / Facebook

Add third-party sign-in (Google, Apple, Facebook) to web + mobile, on top of the existing custom JWT auth (`08-auth-module.md`). Core rule: **if the provider email already belongs to a Lifey user, link the provider identity to that existing user row** — no duplicate accounts.

> ⚠️ `08-auth-module.md` said "no OAuth / external identity providers". That referred to replacing our auth. This plan keeps our JWT + refresh tokens as the session mechanism; providers are only used to *prove identity once* at login.

---

## Architecture (common to all options)

The clients obtain a provider credential (ID token / access token) using native SDKs, then exchange it at our backend for our own JWT pair:

```
Mobile/Web ── provider SDK ──> Google/Apple/Facebook
Mobile/Web ── POST /api/auth/social/{provider} { token } ──> Lifey BE
Lifey BE   ── verify token signature/audience ──> provider JWKS / Graph API
Lifey BE   ── find-or-create user + identity ──> our access+refresh pair
```

The backend never runs a browser OAuth redirect flow itself — it only **verifies tokens**. This keeps `SecurityConfig` stateless and unchanged except one new public endpoint.

### Account model

Flyway `V37__user_identities.sql` (number after the password-reset migration):

```sql
CREATE TABLE user_identities (
    id               UUID PRIMARY KEY,
    user_id          BIGINT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    provider         VARCHAR(20) NOT NULL,          -- GOOGLE | APPLE | FACEBOOK
    provider_user_id VARCHAR(255) NOT NULL,         -- provider's stable subject id
    email            VARCHAR(255),                  -- email as reported at link time
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (provider, provider_user_id)
);
CREATE INDEX idx_user_identities_user_id ON user_identities (user_id);

ALTER TABLE users ALTER COLUMN password_hash DROP NOT NULL;  -- social-only users
```

### Login/link algorithm (backend, per request)

1. Verify the provider token (signature via provider JWKS, `aud` = our client ID, `exp`, `iss`).
2. Extract `provider_user_id` (sub), `email`, `email_verified`, name.
3. `user_identities` hit on `(provider, provider_user_id)` → login as that user. Done.
4. No identity, but a `users` row exists with that email:
   - **Only link if the provider asserts the email is verified** (Google `email_verified=true`; Apple emails are verified by design; Facebook emails are verified by Facebook). Otherwise reject — unverified-email auto-link is an account-takeover vector.
   - Create the `user_identities` row → login as the existing user. (Whether to require an extra confirmation step — see open question Q4.)
5. No identity, no user: create user (null password_hash, ROLE_USER, language from request/Accept-Language) + identity → login.
6. Issue our normal access+refresh pair. Refresh/logout flows unchanged.

Edge cases to spec in implementation phase: Apple hides email behind private relay (`@privaterelay.appleid.com`) and only returns name/email on *first* authorization — must be captured then; account with only social identity uses "forgot password" to *set* a password (works as-is once `19-password-email-plan.md` ships); "unlink provider" is out of scope for v1 but the table supports it.

### Provider prerequisites (independent of chosen option)

| Provider | Needs | Cost / friction |
|---|---|---|
| Google | GCP project, OAuth client IDs (Android, iOS, Web) | Free, ~30 min setup |
| Apple | **Apple Developer Program account ($99/yr)**, App ID with Sign in with Apple capability, Services ID for web | Paid; and **App Store rule: if an iOS app offers any third-party login, it MUST also offer Sign in with Apple** |
| Facebook | Meta developer app, App Review ("Facebook Login" permission) for production use, privacy policy URL, data-deletion callback URL | Free but review friction is real |

Consequence: **Google is the cheap first step; adding Facebook on iOS forces Apple sign-in too.**

---

## Options — do we need an external service?

Short answer: **no external service is required**, but one can reduce provider plumbing. Three realistic options:

### Option A — Direct verification, no third party (recommended)

Backend verifies provider tokens itself: Google/Apple ID tokens via their public JWKS (Nimbus JOSE / spring-security-oauth2-jose `JwtDecoder`, cached keys); Facebook via Graph API `debug_token` + `/me?fields=id,name,email` (Facebook's "Limited Login" OIDC token is iOS-only, so classic access-token verification is the portable path).

- ✅ No new vendor, no per-user cost, everything stays in our DB and our JWT flow.
- ✅ Smallest conceptual change: one endpoint + one table.
- ✅ Client SDKs are standard: `google_sign_in`, `sign_in_with_apple`, `flutter_facebook_auth` (Flutter); Google Identity Services JS, Apple JS, Facebook JS SDK (web).
- ❌ Three provider consoles to configure ourselves; Facebook verification is the ugliest part (~1 extra service class).
- ❌ We own JWKS caching/rotation handling (small, well-trodden code).

### Option B — Firebase Authentication as broker

Clients sign in through Firebase Auth (which wraps all three providers); backend verifies a single **Firebase ID token** with the Firebase Admin SDK, then applies the same find-or-link-or-create logic and issues our JWT pair.

- ✅ One token format to verify; Firebase console handles provider quirks; free at any realistic scale (no-cost Spark tier covers auth).
- ✅ Bonus: gives us a path to phone auth etc. later.
- ❌ New Google dependency in both clients and backend; user identities partially live in Firebase's console too.
- ❌ Still need the same provider consoles (Apple/Facebook credentials get pasted into Firebase, not eliminated).
- ❌ Slightly awkward with our offline-first, custom-JWT stack — two auth SDKs in the mobile app.

### Option C — Full external IdP (Auth0 / Supabase Auth / Keycloak)

Outsource the whole login (hosted login page or SDK), backend trusts their tokens.

- ❌ Conflicts with the existing custom JWT + refresh-token module (would be a rewrite or a permanent dual-auth system).
- ❌ Auth0 free tier caps MAUs and the pricing cliff is steep; Keycloak means self-hosting another service.
- Not recommended for Lifey; listed for completeness only.

**Recommendation: Option A.** It matches the "fully custom auth" philosophy already in place, adds zero vendors, and the per-provider verification code is small and stable. Choose B only if minimizing provider-specific backend code matters more than adding the Firebase dependency.

---

## Phased breakdown (Option A — direct verification; v1 = Phases 1–3)

### Phase 1 — Backend: identity model + Google

**Prompt:**

> In the Lifey backend (Spring Boot 4, Java 24), implement social login per `docs/20-social-login-plan.md`, Google only for now.
>
> - Flyway `V37__user_identities.sql` as specified (incl. `password_hash` nullable).
> - New public endpoint `POST /api/auth/social/google { idToken }` → verifies the Google ID token (JWKS from `https://www.googleapis.com/oauth2/v3/certs`, cached; validate `iss`, `aud` against configured client IDs — accept the Android, iOS and Web client IDs as a list, `exp`). Use `spring-security-oauth2-jose`'s `NimbusJwtDecoder`; do not add the Google API client library.
> - Apply the login/link algorithm from the plan doc exactly (identity hit → login; verified-email match → link; else create user with null password). Reject unverified emails with 403 + error code.
> - Return the same token-pair DTO as `/api/auth/login`. Add the endpoint to public matchers.
> - Config: `app.oauth.google.client-ids` list via env vars.
> - Handle the "social-only user tries password login" case: return the standard invalid-credentials error (do not leak that the account is social-only).
> - Integration tests with a locally-signed JWT + injected test JWKS: new user, existing-identity login, email-link, unverified-email rejection, wrong audience.

### Phase 2 — Mobile: Google sign-in

**Prompt:**

> In the Lifey Flutter app, add "Continue with Google" to `features/auth/presentation/login_screen.dart` (and register screen) using the `google_sign_in` package.
>
> - Obtain the ID token, POST to `/api/auth/social/google` via `auth_repository.dart`, store the returned pair through the existing token flow — after this point the session is identical to password login.
> - Standard Google-branded button per Google guidelines; l10n strings EN+HU; loading/disabled state; error snackbar on failure/cancel.
> - Android + iOS client-ID setup steps documented in `mobile/README` (google-services not needed for pure sign-in on Android if using serverClientId — pick the simplest current `google_sign_in` v7+ approach and document it).

### Phase 3 — Web: Google sign-in

**Prompt:**

> In the Lifey web app, add "Continue with Google" to the `(auth)` login and register pages using Google Identity Services (GIS) — the `accounts.google.com/gsi/client` script with the credential (ID token) callback, not the deprecated gapi flow.
>
> - Use the **official GIS-rendered button** (`google.accounts.id.renderButton`), not a custom-styled one. Match `theme`/`locale` to the app's dark/light mode and next-intl locale where the API allows.
> - On credential response, POST the ID token to `/api/auth/social/google`, then store tokens exactly like the password login mutation does (reuse the existing auth store logic).
> - next-intl strings EN+HU for surrounding texts, graceful error toast.

### Phase 4 — Backend + clients: Apple *(deferred — requires Apple Developer account, Q3)*

**Prompt:**

> Extend Lifey social login with Sign in with Apple per `docs/20-social-login-plan.md`.
>
> - BE: `POST /api/auth/social/apple { idToken, fullName? }` — verify via Apple JWKS (`https://appleid.apple.com/auth/keys`), `iss=https://appleid.apple.com`, `aud` = our bundle ID / Services ID. Apple sends name only on first auth → accept optional `fullName` from the client at first login. Handle private-relay emails as normal emails.
> - Mobile: `sign_in_with_apple` package; the Apple button must appear **above or equal to** other social buttons on iOS (App Store guideline); show only on iOS/macOS + web, not Android.
> - Web: Apple JS SDK with the Services ID, popup mode, same exchange endpoint.
> - Same link/create semantics and tests as Google.

### Phase 5 — Backend + clients: Facebook *(deferred — on iOS it mandates Apple sign-in first, so blocked with Phase 4)*

**Prompt:**

> Extend Lifey social login with Facebook per `docs/20-social-login-plan.md`.
>
> - BE: `POST /api/auth/social/facebook { accessToken }` — verify server-side: call Graph `debug_token` with our app token (check `is_valid`, `app_id`), then `/me?fields=id,name,email`. If Facebook returns no email (user can deny it), reject with a clear error code telling the client to ask for email permission again.
> - Mobile: `flutter_facebook_auth` with `email,public_profile` scopes. Note: shipping this on iOS requires the Apple sign-in phase to be done first (store rule).
> - Web: Facebook JS SDK login, same exchange.
> - Document the Meta app-review checklist (privacy policy URL, data deletion callback) in the doc/README.

### Phase 6 — Account settings polish (later)

Linked-accounts section in settings (list identities, link additional provider while logged in, set password for social-only accounts via the reset flow). Out of scope for v1; table already supports it.

---

## ✅ Decisions (answered 2026-07-01)

| # | Question | Decision |
|---|---|---|
| Q1 | Provider handling | **A — direct token verification in the backend**, no external service |
| Q2 | v1 provider scope | **A — Google only**; Apple and Facebook deferred |
| Q3 | Apple Developer account | **B — not yet** → Phase 4 (Apple) blocked until the account exists; Phase 5 (Facebook) is transitively blocked on iOS by the App Store rule, so it waits too |
| Q4 | Linking to existing email | **A — automatic link when the provider asserts the email is verified** |
| Q5 | Web Google button | **A — official GIS rendered button** (no custom-styled button) |

**Effective v1 scope: Phases 1–3 (backend + mobile + web, Google only).** Phases 4–5 stay in this doc as ready-to-run prompts for when the Apple Developer account is purchased.
