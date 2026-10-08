# Web e2e: what each run needs

`playwright.config.ts` has three projects. Only the first needs anything running besides the Next.js dev server (which
Playwright starts, or reuses on :3000).

| Project | Command | Needs | CI |
|---|---|---|---|
| `marketing` (`e2e/marketing/**`) | `npm run test:e2e:marketing` | nothing | yes |
| `ds` (`e2e/ds/**`) | `npm run test:e2e:ds` | nothing (fixture data) | yes |
| `chromium` (everything else in `e2e/`) | `npm run test:e2e:backend` | the real backend on :8080 and its Postgres on :5432 (`docker compose up -d postgres`) | no, local only |

## The backend-dependent specs and their extra conditions

Most of `chromium` runs against a default backend. Two groups need one more piece; without it they **skip themselves
with a reason** (or, for the web side of chat, fail with an explanation) instead of breaking half way through:

| Specs | Extra condition | How to get it | Without it |
|---|---|---|---|
| `trainer-chat.spec.ts` (1 test) | the **chat service** on :8081 | `chat/`: `./mvnw spring-boot:run`, or `java -jar target/lifey-chat-*.jar` with `LIFEY_API_INTERNAL_URL=http://localhost:8080` | skipped |
| same | the **web started with `NEXT_PUBLIC_CHAT_BASE_URL=http://localhost:8081/api/v1`** (the `web-chat` dev config in `.claude/launch.json`) | stop the plain `npm run dev` on :3000 and start `web-chat` — Playwright reuses whatever answers on :3000 | fails at the "Message" step: "the web must be started with NEXT_PUBLIC_CHAT_BASE_URL…" |
| `admin-billing-banner`, `billing-blocked-dialog`, `billing-overlimit-archiving` (10 tests) | the backend started with **`BILLING_ENABLED=true`** (the `backend-billing` config in `.claude/launch.json`) | restart the backend with it | skipped (`billingIsEnabled` in `support/environment.ts` probes it once per worker) |

`npm run test:e2e:chat` and `npm run test:e2e:billing` run just those groups. Skips are not shown by the `list`
reporter; add `--reporter=line,json` or open the HTML report (`npx playwright show-report`) to see the reasons.

**Run it twice for the full picture.** The four trainer specs (`trainer-flow`, `trainer-calendar`, `trainer-compliance`,
`trainer-onboarding-checklist`) grant `ROLE_TRAINER` straight in the database, so those trainers have no subscription;
with `BILLING_ENABLED=true` the workspace is blocked and they fail. They are written for the default backend.

1. Default backend + `web-chat` + the chat service: `npm run test:e2e:backend` → everything but the 10 billing tests
   (17 pass, 10 skip as of 2026-10-08).
2. `backend-billing` (the web can stay as is): `npm run test:e2e:billing` → 16 pass (the 10 above plus
   `billing-checkout-round-trip` and `trainer-billing-page`, which run either way).

## Conventions

- Specs create their own accounts (`e2e-…-${Date.now()}@example.com`) and never clean up; run them against a local
  development database, not a shared one.
- `ROLE_TRAINER` has no grant API by design (see `trainer-flow.spec.ts`): specs insert it through `pg`. A token issued
  before the grant has a stale `roles` claim — log in again afterwards.
- Probes for optional conditions live in `support/environment.ts`; add new ones there and call
  `test.skip(!(await …(request)), "requires … — see e2e/README.md")`.
