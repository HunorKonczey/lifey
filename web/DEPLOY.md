# Lifey Web — Deployment

The web frontend is a standalone Next.js app that talks to the existing Spring Boot
backend (deployed on **Render** — see
[`devops/deploy-backend-render.md`](../devops/deploy-backend-render.md) for its URL).
The web is deployed as its **own service** — it is never bundled with the backend.

Two supported targets:

- **Vercel** — recommended (native Next.js, zero-config, edge CDN). *Planned target.*
- **Render** — a second service next to the backend (uses the included `Dockerfile`).

---

## 0. Backend prerequisites (do this once, regardless of host)

The web and API live on **different domains**, so the request is cross-origin **and**
cross-site (`*.vercel.app` and `*.onrender.com` are separate sites). Set these
environment variables on the **backend** Render service, then redeploy it:

```
CORS_ALLOWED_ORIGINS=https://<your-web-domain>     # e.g. https://lifey-web.vercel.app
COOKIE_SECURE=true                                  # prod is HTTPS
COOKIE_SAME_SITE=None                               # cross-site cookie must be None+Secure
```

Why: the refresh token is an httpOnly cookie. A cross-site cookie is only sent by the
browser when it is `SameSite=None; Secure`. `CORS_ALLOWED_ORIGINS` must list the exact
web origin (no wildcard) because credentials are sent.

> Multiple origins are comma-separated, e.g. a Vercel preview + production domain:
> `CORS_ALLOWED_ORIGINS=https://lifey-web.vercel.app,https://lifey-web-git-main.vercel.app`

---

## Option A — Vercel (recommended)

1. **Import the repo** at <https://vercel.com/new> → select the Lifey repository.
2. **Root Directory:** set to `web` (this is a monorepo; the Next app is under `web/`).
   Vercel auto-detects Next.js — leave Build/Output settings as default.
3. **Environment Variables** (Project → Settings → Environment Variables):
   ```
   NEXT_PUBLIC_API_BASE_URL  = https://<backend>.onrender.com/api/v1
   NEXT_PUBLIC_CHAT_BASE_URL = https://<chat-service>.onrender.com/api/v1
   ```
   Add them for **Production** (and Preview if you want PR previews to work — but note the
   backend CORS must then also allow the preview domain).

   `NEXT_PUBLIC_CHAT_BASE_URL` is **not optional on the web**, even though the chat's URL is
   otherwise resolved at runtime from `GET /client-config`: the CSP `connect-src` header is
   fixed at build time ([`next.config.ts`](next.config.ts)), so an origin the build never
   heard of is blocked by the browser regardless of what the config endpoint answers. The
   runtime lookup still gives you the rollback it was built for — emptying
   `CHAT_PUBLIC_BASE_URL` on the API sends the chat back to the API with no redeploy — but
   moving the chat to a *different host* needs this variable updated and the web rebuilt.
   See `docs/chat/44-chat-service-extraction-plan.md` §7.1.
4. **Deploy.** Vercel builds and serves automatically on every push to `main`.
5. Copy the assigned domain (e.g. `https://lifey-web.vercel.app`) and put it into the
   backend's `CORS_ALLOWED_ORIGINS` (step 0), then redeploy the backend.

> `NEXT_PUBLIC_*` vars are inlined at **build time** — after changing the API URL you must
> trigger a redeploy, not just restart.

---

## Option B — Render (second service next to the backend)

1. Render → **New → Web Service** → connect the Lifey repo.
2. **Service settings:**
   - **Runtime:** Docker (the repo includes [`web/Dockerfile`](Dockerfile), a
     multi-stage standalone build)
   - **Root Directory:** `web`
3. **Build arg / variables:** `NEXT_PUBLIC_*` must exist at **build time**, not just
   at runtime:
   ```
   NEXT_PUBLIC_API_BASE_URL = https://<backend>.onrender.com/api/v1
   ```
   The Dockerfile declares `ARG NEXT_PUBLIC_API_BASE_URL`. Render does **not**
   automatically forward environment variables into the Docker build — add it under
   the service's **Settings → Docker Build Arguments** as well.
4. **Networking:** Render assigns `https://<service>.onrender.com` and injects `$PORT`.
   The container listens on `$PORT` / `3000` and binds `0.0.0.0`, so nothing to configure.
5. Put the assigned web domain into the backend's `CORS_ALLOWED_ORIGINS` (step 0),
   redeploy the backend.

---

## Post-deploy verification

Open the deployed web URL and check:

- [ ] **Login** works (no CORS error in the browser console).
- [ ] After login, **refresh the page (F5)** — the session is restored from the refresh
      cookie (you stay logged in, not bounced to `/login`).
- [ ] **Dashboard** loads real data (statistics/meals/water/steps/sessions return `200`).
- [ ] **Logout** clears the session and returns to `/login`.
- [ ] DevTools → Application → Cookies → backend domain: a `refreshToken` cookie exists
      with `HttpOnly`, `Secure`, `SameSite=None`, `Path=/api/v1/auth`.

If login works but a page refresh logs you out, the cross-site cookie isn't being
sent — re-check `COOKIE_SECURE=true` and `COOKIE_SAME_SITE=None` on the backend.

---

## CI

[`.github/workflows/web-ci.yml`](../.github/workflows/web-ci.yml) runs lint + typecheck +
unit tests + production build on every push/PR touching `web/**`.

Vercel's own Git integration is left **on** (default): it deploys the `main` branch as
**Production** and every other branch (e.g. `feature/**`) as a **Preview**, automatically,
with no extra config. Production is gated on CI by GitHub branch protection instead of by
a Vercel Deploy Hook: `main` requires the Web CI check to pass and only accepts merges via
PR, so no commit reaches `main` — and therefore no Vercel production build fires — without
CI having already gone green. `feature/**` pushes get instant, ungated preview deploys.

> Don't try to gate this with a Vercel `ignoreCommand`/Ignored Build Step keyed on branch
> name — it can't distinguish a Deploy-Hook-triggered build from a plain git-push build
> (both see the same branch/commit), so it ends up skipping both or neither.

Render (if used for the web too) likewise deploys on push to `main` independently of CI.

---

## Environment variables reference

| Where | Variable | Example | Notes |
|---|---|---|---|
| Web | `NEXT_PUBLIC_API_BASE_URL` | `https://<backend>.onrender.com/api/v1` | Build-time, inlined |
| Web | `NEXT_PUBLIC_CHAT_BASE_URL` | `https://<chat-service>.onrender.com/api/v1` | Build-time; also feeds the CSP `connect-src` |
| Chat | `CORS_ALLOWED_ORIGINS` | `https://lifey-web.vercel.app` | The chat has its own — the API's does not cover it |
| API | `CHAT_PUBLIC_BASE_URL` | `https://<chat-service>.onrender.com/api/v1` | What `/client-config` hands to clients; empty = "the API serves the chat" |
| Backend | `CORS_ALLOWED_ORIGINS` | `https://lifey-web.vercel.app` | Exact origin(s), comma-separated |
| Backend | `COOKIE_SECURE` | `true` | Required for `SameSite=None` |
| Backend | `COOKIE_SAME_SITE` | `None` | Cross-site refresh cookie |
