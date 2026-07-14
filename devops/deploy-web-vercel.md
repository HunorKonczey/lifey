# Deploy — Web Admin on Vercel

The web admin is a standalone **Next.js 16** app that talks to the Railway
backend. It is deployed as its **own service** — never bundled with the backend.

- **Primary target: Vercel** (native Next.js, zero-config, edge CDN).
- **Fallback: Railway** as a second service, using [`web/Dockerfile`](../web/Dockerfile).

> The full step-by-step walkthrough (with the post-deploy checklist) lives in
> [`web/DEPLOY.md`](../web/DEPLOY.md) next to the code. **That file is the
> canonical procedure** — this doc is the ops-side summary and the cross-origin
> reference. Keep the two in sync if either changes.

## The one thing that always bites: cross-site cookies

Web and API are on **different domains**, so requests are cross-origin **and**
cross-site (`*.vercel.app` and `*.up.railway.app` are separate sites). The
refresh token is an httpOnly cookie, and a browser only sends a cross-site cookie
when it's `SameSite=None; Secure`.

Set these on the **backend** (Railway) and redeploy it:
```
CORS_ALLOWED_ORIGINS=https://<your-web-domain>   # exact origin, no wildcard; comma-separated for multiple
COOKIE_SECURE=true
COOKIE_SAME_SITE=None
```
`CORS_ALLOWED_ORIGINS` must list the **exact** web origin (credentials are sent,
so no wildcard is allowed). For PR previews, add the preview domain too, e.g.
`https://lifey-web.vercel.app,https://lifey-web-git-main.vercel.app`.

## Vercel setup (summary)

1. Import the repo at <https://vercel.com/new>.
2. **Root Directory: `web`** (monorepo — the Next app is under `web/`). Vercel
   auto-detects Next.js; leave build/output at defaults.
3. **Environment variable:**
   ```
   NEXT_PUBLIC_API_BASE_URL = https://lifey-production-7aa5.up.railway.app/api/v1
   ```
   Set for **Production** (and Preview if you want PR previews — then the backend
   CORS must also allow the preview domain).
4. Deploy. Copy the assigned domain, put it into the backend's
   `CORS_ALLOWED_ORIGINS` (above), redeploy the backend.

> ⚠️ `NEXT_PUBLIC_*` is **inlined at build time**, not read at runtime. After
> changing the API URL you must **trigger a redeploy**, not just restart.

## Environment variables

| Where | Variable | Example | Notes |
|---|---|---|---|
| Web | `NEXT_PUBLIC_API_BASE_URL` | `https://lifey-production-7aa5.up.railway.app/api/v1` | Build-time, inlined into the client bundle. |
| Backend | `CORS_ALLOWED_ORIGINS` | `https://lifey-web.vercel.app` | Exact origin(s), comma-separated. |
| Backend | `COOKIE_SECURE` | `true` | Required for `SameSite=None`. |
| Backend | `COOKIE_SAME_SITE` | `None` | Cross-site refresh cookie. |

## CI & auto-deploy

- **CI:** [`.github/workflows/web-ci.yml`](../.github/workflows/web-ci.yml) runs
  lint + typecheck + unit tests + production build on pushes/PRs touching `web/**`.
- **Vercel Git integration is on:** `main` deploys as **Production**, every other
  branch as a **Preview**, automatically. Production is gated by GitHub branch
  protection (a `main` merge requires Web CI green + PR), so no production build
  fires without CI having passed.
- Don't gate this with a Vercel `ignoreCommand` keyed on branch name — see
  [`web/DEPLOY.md`](../web/DEPLOY.md) for why it doesn't work.

## Verification

Open the deployed URL and confirm:
- [ ] Login works (no CORS error in the browser console).
- [ ] After login, **F5 refresh** keeps you logged in (session restored from the
      refresh cookie — not bounced to `/login`).
- [ ] Dashboard loads real data (statistics/meals/water/steps/sessions → `200`).
- [ ] Logout clears the session.
- [ ] DevTools → Application → Cookies → backend domain: a `refreshToken` cookie
      with `HttpOnly`, `Secure`, `SameSite=None`.

If login works but a refresh logs you out, the cross-site cookie isn't being sent
— re-check `COOKIE_SECURE=true` and `COOKIE_SAME_SITE=None` on the backend.

## Railway fallback

If hosting the web on Railway instead of Vercel: second service, **Root Directory
`web`**, Dockerfile builder. `NEXT_PUBLIC_API_BASE_URL` must be passed as a
**build arg** (the Dockerfile declares `ARG NEXT_PUBLIC_API_BASE_URL`); Railway
forwards service variables as build args. Full steps in
[`web/DEPLOY.md`](../web/DEPLOY.md) → Option B.
