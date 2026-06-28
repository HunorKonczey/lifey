# Lifey Web — Deployment

The web frontend is a standalone Next.js app that talks to the existing Spring Boot
backend (already deployed on **Railway** at
`https://lifey-production-7aa5.up.railway.app/api/v1`). The web is deployed as its
**own service** — it is never bundled with the backend.

Two supported targets:

- **Vercel** — recommended (native Next.js, zero-config, edge CDN). *Planned target.*
- **Railway** — a second service next to the backend (uses the included `Dockerfile`).

---

## 0. Backend prerequisites (do this once, regardless of host)

The web and API live on **different domains**, so the request is cross-origin **and**
cross-site (Railway's `*.up.railway.app` subdomains are separate sites). Set these
environment variables on the **backend** Railway service, then redeploy it:

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
   NEXT_PUBLIC_API_BASE_URL = https://lifey-production-7aa5.up.railway.app/api/v1
   ```
   Add it for **Production** (and Preview if you want PR previews to work — but note the
   backend CORS must then also allow the preview domain).
4. **Deploy.** Vercel builds and serves automatically on every push to `main`.
5. Copy the assigned domain (e.g. `https://lifey-web.vercel.app`) and put it into the
   backend's `CORS_ALLOWED_ORIGINS` (step 0), then redeploy the backend.

> `NEXT_PUBLIC_*` vars are inlined at **build time** — after changing the API URL you must
> trigger a redeploy, not just restart.

---

## Option B — Railway (second service next to the backend)

1. In the **same Railway project** as the backend: **New → GitHub Repo** (or "Empty
   Service" → connect repo).
2. **Service settings:**
   - **Root Directory:** `web`
   - **Builder:** Dockerfile (the repo includes [`web/Dockerfile`](Dockerfile), a
     multi-stage standalone build). Railway will use it automatically when root is `web`.
3. **Build arg / variables:** `NEXT_PUBLIC_*` must exist at **build time**. Set as a
   service variable AND pass it as a Docker build arg:
   ```
   NEXT_PUBLIC_API_BASE_URL = https://lifey-production-7aa5.up.railway.app/api/v1
   ```
   The Dockerfile already declares `ARG NEXT_PUBLIC_API_BASE_URL`; Railway forwards
   service variables as build args. If a build doesn't pick it up, add it explicitly
   under the service's **Build → Build Args**.
4. **Networking:** generate a public domain for the web service (Settings → Networking →
   Generate Domain). The container listens on `$PORT` / `3000` (the Dockerfile binds
   `0.0.0.0`).
5. Put the generated web domain into the backend's `CORS_ALLOWED_ORIGINS` (step 0),
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
unit tests + production build on every push/PR touching `web/**`. Both Vercel and Railway
deploy on push to `main` independently of CI; treat CI as the gate and protect `main` with
a required status check if desired.

---

## Environment variables reference

| Where | Variable | Example | Notes |
|---|---|---|---|
| Web | `NEXT_PUBLIC_API_BASE_URL` | `https://lifey-production-7aa5.up.railway.app/api/v1` | Build-time, inlined |
| Backend | `CORS_ALLOWED_ORIGINS` | `https://lifey-web.vercel.app` | Exact origin(s), comma-separated |
| Backend | `COOKIE_SECURE` | `true` | Required for `SameSite=None` |
| Backend | `COOKIE_SAME_SITE` | `None` | Cross-site refresh cookie |
