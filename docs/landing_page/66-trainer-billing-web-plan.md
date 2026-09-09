# 66 – Trainer Billing on the Web

Status: **done** — all 10 prompts. One end-to-end Stripe test-mode pass is still owed:
[`73`](73-billing-verification-runbook.md) §1
Scope: web (`/admin`) + a small backend annex (trainer access requests)
Depends on: `docs/landing_page/63-monetization-strategy-plan.md` (D-M2, D-M3, D-M8, D-M12),
`docs/landing_page/64-billing-backend-plan.md` (entitlements, checkout, seat limits),
`docs/personal_trainer/04-web-admin-terv.md` (the `/admin` shell this extends),
`docs/landing_page/65-web-landing-page-plan.md` (the `PLANS` constant, attribution)

This is the paying side of the product: how a trainer goes from landing page to card, and
what the workspace looks like when the trial ends or the seats run out.

---

## 1. What we're building

1. A **trainer access request** flow — because role granting is a super-admin action
   (63 §6), the landing page's "start free trial" CTA cannot self-serve. It creates a
   request, and the wait has to be made legible instead of hidden.
2. `/admin/billing` — current plan, seat usage, invoices, upgrade/downgrade, cancel.
3. A **trial state** that is visible without being nagging: quiet for the first week, then
   increasingly present.
4. **Seat-limit and restriction UX** at the exact points where an action is blocked, saying
   what is blocked and what to do — never a generic 403 toast.
5. A **first-week onboarding checklist** whose only real goal is the first accepted invite
   (63 §4).
6. **With the feature off** (`lifey.billing.enabled=false`), `/admin` looks exactly as it
   does today: no banner, no billing nav item, no blocked actions.

---

## 2. The trainer access request

### D-T1 The landing CTA creates a request, and the request page is honest about the wait

`POST /api/v1/trainer-requests { motivation?, clientCount?, signupSource }` — authenticated,
any `ROLE_USER`. Creates a `trainer_request` row (`PENDING`), notifies the super admin by
email through the existing `com.lifey.mail` path, and is rate-limited to one open request per
user.

The user is redirected to `/admin/pending`, a page that states plainly: *"We review trainer
applications by hand, usually within one working day. Your 14 days start when we approve
you, not now."* That last clause is the whole point (63 §8.10) — it removes the incentive to
lie about the delay.

`GET /api/v1/trainer-requests/me` lets the page poll its own status. On approval the super
admin's existing grant action (`SuperAdminUserController`) also resolves the request and
sends the "you're in" email.

*Rejected: auto-granting `ROLE_TRAINER` on request.* It is the current security model's
deliberate choice (`docs/personal_trainer/README.md` §2) and the thing that keeps the trainer
surface from being a spam target. Revisit only with a real verification step.

*Rejected: hiding the review behind a fake "setting up your workspace" spinner.* A person
waiting a day for a spinner is a person who has uninstalled you.

### 2.1 Backend annex (small, belongs to this doc)

- `V76__trainer_request.sql` — `trainer_request (id, user_id, status, motivation,
  client_count, signup_source, created_at, decided_at, decided_by)`; unique partial index on
  `user_id` where `status = 'PENDING'`.
- `com.lifey.trainer.request` — entity, repository, `TrainerRequestService`,
  `TrainerRequestController`, plus a `GET /api/v1/superadmin/trainer-requests` list and a
  decision endpoint that reuses `RoleManagementService`.
- Granting the role publishes `TrainerRoleGrantedEvent`, which starts the trial (`64` §4.1).
  The request flow does **not** create subscriptions itself — one writer only (`64` D-B2).

---

## 3. `/admin/billing`

Route: `web/src/app/(admin)/admin/billing/page.tsx`, added to `AdminSidebar`.

Sections, in order:

1. **Current plan card** — plan name, price, billing interval, renewal or expiry date,
   status pill (`Trial · 6 days left`, `Active`, `Payment failed`, `Canceled`).
2. **Seat meter** — `11 / 25 active clients`, a bar, and the count of pending invites shown
   separately (they count toward the limit, `64` §4.3 — so they must be visible).
3. **Plan chooser** — the three tiers from the shared `PLANS` constant (`65` D-W9 / §10.4),
   monthly/yearly toggle, current plan marked, each with the seat limit as the headline
   number. Selecting one calls `POST /api/v1/billing/checkout-session` and redirects.
4. **Manage billing** — a button to `POST /api/v1/billing/portal-session`; card updates,
   invoices, cancellation and VAT details all live in Stripe's portal.
5. **What happens if I cancel** — a plain-language block, because this is the question that
   otherwise arrives as a support email: clients keep their data, chat keeps working, you
   keep read access, you cannot send new invites or assign new content.

### D-T2 We do not rebuild Stripe's customer portal

Invoices, card management, cancellation, tax ids and dunning UI are one link. Building them
means keeping a second, worse copy of Stripe's state in sync forever.

*Rejected: an embedded invoice list.* Two extra endpoints and a pagination story for a page
a trainer visits twice a year.

### D-T3 After checkout the page polls entitlements; it does not trust the redirect

`?checkout=success` shows an optimistic "activating your plan…" state and polls
`GET /api/v1/me/entitlements` (1 s, backing off, 30 s ceiling) until the plan changes. If the
webhook has not landed in 30 s, the page says so and offers a refresh — it never claims a
plan that the server has not confirmed (`64` D-B5).

---

## 4. Trial and restriction UX

### D-T4 One banner slot in the admin shell, with a defined escalation

`AdminBillingBanner` renders in `(admin)/admin/layout.tsx` above the content, driven purely
by the entitlement response. Exactly one banner shows at a time, in this priority order:

| Condition | Tone | Copy focus | Dismissible |
|---|---|---|---|
| `CANCELED` / `EXPIRED` | error | "Your workspace is read-only. Reactivate to invite and assign." | no |
| `PAST_DUE` | warning | "We couldn't charge your card. Update it to keep your clients' access." (63 §7.5) | no |
| `OVER_LIMIT` | warning | "You have 12 active clients on a 5-client plan. Upgrade, or archive clients." | no |
| Trial, ≤ 3 days left | warning | "3 days left. Pick a plan to keep inviting." | no |
| Trial, 4–7 days left | info | "7 days left in your trial." | yes, for the session |
| Trial, > 7 days left | none | — | — |

Silence in the first week is deliberate: a trial banner on day one is a banner the trainer
learns to ignore by day ten.

### D-T5 Blocked actions explain themselves at the point of action

Every blocked control (send invite, assign, create program, schedule) stays **visible and
enabled-looking**, and opens a small dialog on click that states the reason and the one
action that fixes it. It never silently disables, and it never shows a bare toast.

The dialog is one component, `BillingBlockedDialog`, taking `{ reason, currentPlan,
activeClients }` — so the four call sites cannot drift into four different explanations.

*Rejected: disabling the buttons.* A disabled button with a tooltip is invisible on touch and
tells the trainer nothing about *why*.

### D-T6 Chat is never touched by any of this

No banner state, no dialog, no disabled control in `/admin/chat` (D-M8). Worth an explicit
test, because the natural implementation is a layout-level guard that would catch chat too.

### 4.1 Over-limit archiving flow

When `OVER_LIMIT`, the clients list gains a mode: seats over the limit are marked, and an
"Archive client" action is offered inline with a confirm dialog explaining that the client
keeps everything they have and only loses the coaching link. The trainer chooses who
(D-M12). The banner counts down as they go: `12 / 5 — archive 7 more, or upgrade`.

---

## 5. Onboarding checklist

`TrainerOnboardingChecklist`, on `/admin` for the trial's duration, dismissible permanently
after completion:

1. Complete your trainer profile
2. **Invite your first client** ← the one that matters
3. Create or import a workout template
4. Assign it to a client
5. Send your first message

Step 2's completion state is *accepted*, not *sent*. A checklist that ticks on "invite sent"
measures our convenience, not the trainer's progress (63 §4).

---

## 6. Data layer

`web/src/features/billing/`:

```
api.ts              entitlements, checkout-session, portal-session, trainer-requests
types.ts            mirrors 64 §3.2 exactly
hooks.ts            useEntitlements() — TanStack Query, staleTime 60s,
                    refetchOnWindowFocus, invalidated after any seat-changing mutation
components/         AdminBillingBanner, PlanChooser, SeatMeter, BillingBlockedDialog,
                    TrainerOnboardingChecklist
```

`queryKeys.billing.entitlements()` is added to `src/lib/api/queryKeys.ts`, and every mutation
that can change the seat count — invite send, invite revoke, client archive — invalidates it.
Missing one of those invalidations is a stale seat meter that nothing reports (§9.1).

---

## 7. Order of work

**Prompt 1 — Backend: trainer access requests — ✅ done**
`V76`, `com.lifey.trainer.request`, the three endpoints, the mail notification, resolution on
role grant.
*Verify:* integration tests — one open request per user, super-admin list, approval both
grants the role and resolves the request, approval starts the trial (`64` §4.1).

Landed as `V77__trainer_request.sql` — `V76` was already taken by `64` Prompt 12's
`ai_usage_counter`, so this is the next free version, the same shifting pattern every earlier
prompt in `64` also hit. `trainer_request (id, user_id, status, motivation, client_count,
signup_source, created_at, decided_at, decided_by)`, with a partial unique index on `user_id
where status = 'PENDING'` doing the actual "one open request per user" enforcement, not
application code. `com.lifey.trainer.request` came together exactly as laid out: `TrainerRequest`
+ `TrainerRequestStatus` flat at the package root, `TrainerRequestRepository`, `dto/` (request +
two response shapes — a self-facing one and a richer superadmin one carrying the requester's
email), `service/TrainerRequestService(+Impl)`, `controller/` (`TrainerRequestController` for
`POST /api/v1/trainer-requests` + `GET /me`, `SuperAdminTrainerRequestController` for the queue
under `/api/v1/superadmin/trainer-requests` — already `ROLE_SUPER_ADMIN`-gated by `SecurityConfig`'s
existing wildcard, no changes needed there). One new exception, `TrainerRequestAlreadyDecidedException`
(409); everything else reuses `ResourceNotFoundException`/`DuplicateResourceException` rather than
inventing narrower ones.

The one real design decision this prompt required: the doc's own text has two claims that look
like they could conflict — "a decision endpoint that reuses `RoleManagementService`" (implying a
dedicated approve/reject action in this queue) versus "the super admin's existing grant action
(`SuperAdminUserController`) also resolves the request" (implying resolution has to work no
matter which endpoint granted the role). Built both, reconciled: `POST
/api/v1/superadmin/trainer-requests/{id}/approve` calls `RoleManagementService.grant(...)`
directly (the "reuse" part), but resolving the row to `APPROVED` + sending the "you're in" email
happens in a new `TrainerRequestResolutionListener`, a second `@EventListener` on the *same*
`TrainerRoleGrantedEvent` `64` Prompt 7's `TrainerTrialListener` already consumes — plain
(synchronous, same-transaction), not `@TransactionalEventListener`, for the identical reason
Prompt 7 gave: the request row and the role must never be observably out of sync. This means a
super admin granting `ROLE_TRAINER` through the *plain* `/api/v1/superadmin/users/{id}/roles`
endpoint also resolves a pending request — exactly what the doc's other sentence asks for — with
no special-casing in that endpoint at all. Doing this required widening `TrainerRoleGrantedEvent`
from `(userId)` to `(userId, actorId)`, since the listener needs the granting admin's id for
`decided_by` and had no other way to recover it; `TrainerTrialListener` ignores the new field.
Reject has no such indirection — it never touches `RoleManagementService`, so it just marks the
row `REJECTED` inline with the current-request actor id.

One subtle correctness bug caught before it shipped: the listener originally passed
`request.getUser()` (a lazy `@ManyToOne` proxy) straight into `MailService.sendTrainerRequestApproved`,
whose implementation is `@Async` — meaning the actual field access happens on a different thread,
after the listener's own method (and the Hibernate session with it) has already returned. An
uninitialized proxy crossing that boundary would throw `LazyInitializationException` intermittently,
not on every run. Fixed by re-fetching a real `User` via `UserRepository` inside the listener
before handing it to `MailService` — the exact reasoning `WelcomeEmailListener`'s own javadoc
already documents for a related but not identical reason (that one re-fetches because
`AFTER_COMMIT` runs outside the original transaction entirely; this one re-fetches to avoid
handing an uninitialized proxy across an `@Async` thread boundary within the *same* transaction).

Two new `MailService` methods reuse the exact "team inbox" delivery path `65` Prompt 8's contact
form established (`sendToInbox`, `mailProperties.contactTo()`) rather than emailing every
`ROLE_SUPER_ADMIN` account individually — the admin-facing notification is hardcoded to English
(an internal-facing message, not user-facing copy), while the "you're in" email to the newly
approved trainer resolves the recipient's own language normally, matching every other
`User`-addressed email in `ResendMailService`.

Test coverage: `TrainerRequestRepositoryTest` (7 cases — round trip, the partial-unique-index
rejection, that a *decided* row doesn't block a new `PENDING` one, `existsByUserIdAndStatus`,
`findFirstByUserIdOrderByCreatedAtDesc` across statuses, `findFirstByUserIdAndStatus`, and
`findByStatus`'s join-fetch — the last one deliberately scoped to specific synthetic users rather
than a total-row-count, since JUnit doesn't guarantee method order and this table is shared
across the whole test class); `TrainerRequestServiceImplTest` (12 cases) and
`TrainerRequestResolutionListenerTest` (3, including the "user missing after resolve" edge case)
at the unit level; `@WebMvcTest` controller tests for both controllers (9 cases total, HTTP-layer
only); and `TrainerRequestIntegrationTest` (6 cases, real JWTs, Testcontainers, mirroring
`TrainerTrialIntegrationTest`'s pattern) covering every clause of this prompt's own *Verify*
line plus the direct-grant-bypasses-the-queue case the design reconciliation above was built to
handle. `RoleManagementServiceImplTest` and `TrainerTrialListenerTest` needed their
`TrainerRoleGrantedEvent` construction calls updated for the new `actorId` field; no other
production behavior in `64`'s billing feature changed. Full `mvn verify` (986 tests) and
`check-schema-ownership.sh` both clean. Not verified: an actual Resend delivery of either new
email type (same standing gap as every other `MailService` addition in this codebase — mail
sending is only exercised as "would have sent X" log lines with `lifey.mail.enabled=false`).

**Prompt 2 — Web: request + pending pages — ✅ done**
`/admin/pending`, the request form reachable from the landing CTA, status polling.
*Verify:* Playwright — a fresh non-trainer user is routed to `/admin/pending`, sees the
pending state, and after an approval (seeded in the test DB) is routed into `/admin`.

Landed `web/src/app/(admin)/admin/pending/page.tsx` as a single page component handling four
states inline (loading, the request form, the `PENDING` waiting screen, and a brief redirecting
state on `APPROVED`) — matching the codebase's existing style (`admin/invites/page.tsx` does the
same). `features/trainer-requests/` (new, `api.ts` + `types.ts`, mirroring the backend DTOs
exactly) plus a new `queryKeys.trainerRequests.mine()` entry. Polling is a plain fixed
10s `refetchInterval` while `status === "PENDING"` — the chat feature's existing precedent
(`features/chat/hooks.ts`), not the doc's separate backing-off 1s→30s pattern from §3 D-T3, which
is Prompt 6's checkout-polling job and doesn't exist yet; this page's wait is measured in hours,
not seconds, so the extra machinery isn't warranted here.

Two real architectural problems surfaced before any of this could work, neither mentioned in the
plan text, both resolved:

1. **`(admin)/admin/layout.tsx`'s existing guard redirects any non-trainer straight to
   `/dashboard`, before rendering children at all** — which would have bounced every fresh
   `ROLE_USER` visitor away from `/admin/pending` on arrival, i.e. away from the exact audience
   this whole feature is for. Fixed by exempting `pathname === "/admin/pending"` from both the
   redirect and the full trainer-sidebar chrome (a pending, not-yet-a-trainer user has no reason
   to see `AdminSidebar`'s trainer nav items) — a small, targeted change to the shared layout
   rather than trying to route around it.
2. **An approved trainer's already-issued JWT doesn't retroactively gain `ROLE_TRAINER`** —
   `e2e/trainer-flow.spec.ts` already documents this exact fact for a different flow (it
   re-logs-in after a direct-DB role grant). The pending page's poll detects `APPROVED` via
   `/trainer-requests/me`, but redirecting straight to `/admin` at that point would just bounce
   off `AdminLayout`'s own guard, since the browser's current access token still lacks the role.
   Fixed by adding a new `refreshUser()` action to `features/auth/store.ts` — unlike the existing
   `initialize()`, it always re-exchanges the refresh token even when a user is already set,
   specifically for this "the server-side role set changed under an active session" case — called
   once on `APPROVED`, before the redirect.

**Reaching the form from the landing CTA** turned out to mean more than just linking a button:
the marketing CTAs (`TrainerHero`'s hero button, `HeaderAuthActions`'s site-wide "start trial"
button, `FinalCta` when shown on `/for-trainers`) all pointed at a bare `/register`, and the
register page had zero return-path handling — a fresh signup always landed on `/onboarding`,
losing all trainer intent. `HeaderAuthActions.tsx` already carried a code comment marking this as
the deliberate placeholder ("`/register` is the working placeholder target... once \[66 D-T1]
exists"). Added a `?next=` convention: the register page honors it (guarded by a
`safeNextPath` check — same-origin, relative paths only, rejecting `//host` protocol-relative
values — to close off an open-redirect vector before it existed) and falls back to `/onboarding`
otherwise; all three CTAs now link to `/register?next=/admin/pending`. `FinalCta` is shared
between the home page and `/for-trainers` with genuinely different intent per caller, so its href
is conditional on the existing `page` prop rather than a blanket change — a home-page visitor
hasn't signaled trainer intent, so that instance keeps the plain `/register`.

A real backend/frontend mismatch surfaced only when actually driving this in a browser, not from
`tsc`/`eslint`/Vitest: the locally-running backend process (started independently of this
session, well before Prompt 1's `com.lifey.trainer.request` controllers existed) was still
serving stale compiled classes — `POST /api/v1/trainer-requests` 404'd with "No endpoint",
which the browser only ever surfaced as a swallowed-into-generic-error-message mutation failure,
never a visible network error, because `/api/v1/**` returns 401 (not 404) for literally any path
when unauthenticated, which had made an earlier manual `curl` check look like the route existed
when it didn't. Restarting the backend process resolved it — not a code bug, but exactly the
kind of "looks fine until you actually click through it" gap the CLAUDE.md verification rule
exists to catch.

Test coverage: two new Playwright specs in `e2e/trainer-request-flow.spec.ts` — the CTA-to-form
navigation (`/en/for-trainers` → "Request access" → lands on `/register?next=...`), and the full
loop this prompt's *Verify* line asks for (register through the real UI, see the empty-state
form, submit it, see the `PENDING` waiting screen, approve via a direct DB write mirroring
`RoleManagementServiceImpl.grant` + `TrainerRequestResolutionListener`'s combined effect since
Prompt 3's superadmin queue UI doesn't exist yet, then confirm the poll picks it up and the page
redirects into `/admin`). Ran the full existing Playwright suite afterward to check for
regressions from the shared `AdminLayout` edit — all green except `trainer-chat.spec.ts`, which
was already failing before this session touched anything (its `test-results/` artifact was
already present in the repo's git status at the very start of this session) and depends on the
separate `lifey-chat` microservice not running in this environment; unrelated to this change.
`tsc --noEmit`, `eslint`, and the full Vitest suite (359 tests) all clean. Not verified: Hungarian
copy for the two new backend mail templates and this page's own `trainerRequest.*` message keys
were translated but not proofread by a native speaker; no real Resend delivery (same standing gap
noted in Prompt 1's own landed notes).

**Prompt 3 — Web: superadmin trainer-request queue — ✅ done**
A tab in `/superadmin` listing pending requests with approve/reject.
*Verify:* Playwright as a super admin; a rejected request cannot be re-opened by the user
without a new submission.

Landed `web/src/app/(superadmin)/superadmin/trainer-requests/page.tsx`, mirroring
`superadmin/users/page.tsx`'s established shape closely — paged list, a confirm dialog before
either decision (matching that page's grant/revoke pattern, since approve has the same real
weight: it grants a role and starts a trial), toasts on success/failure. Added the three
superadmin endpoints to `features/trainer-requests/api.ts` (same feature module as Prompt 2's
self-facing endpoints, not split into `features/superadmin/` — mirrors the backend's own
`com.lifey.trainer.request.controller` package, which keeps `TrainerRequestController` and
`SuperAdminTrainerRequestController` together by domain despite the different audiences) plus a
`SuperAdminTrainerRequestResponse` type and a `queryKeys.trainerRequests.pending()` entry.

**"A tab in `/superadmin`" meant introducing tab navigation into `SuperAdminShell` for the first
time** — that layout has held exactly one page (`/superadmin/users`) since it was built, so there
was no existing tab-bar pattern to reuse; `SegmentedControl` (the closest existing component) is a
controlled-state toggle for filters, not `<Link>`-based route navigation, so it wasn't the right
fit. Added a small `usePathname()`-driven tab row directly in the shared layout instead of a new
component, matching the scale of the change (two tabs).

Verified the whole loop directly in a browser against the real backend before writing the
Playwright tests, not just after: registered a superadmin via a direct Postgres role insert (the
established pattern, `ROLE_SUPER_ADMIN` has no grant API by design), a second account that
submitted a real request, then drove approve and reject through the actual UI and checked
Postgres afterward — `decided_by` on the resolved row matched the approving superadmin's user id,
confirming `TrainerRequestResolutionListener`'s event-driven design (from Prompt 1) resolves
correctly through this new UI path too, not just the direct-DB-write path Prompt 2's test used.
Also manually confirmed the exact case this prompt's *Verify* line asks about: after a real
rejection through the queue, the rejected user's `/admin/pending` showed the "your previous
request wasn't approved, submit a new one" note plus the request form again — no reopen path
exists anywhere, by construction, since the backend's partial-unique-index only blocks a second
*open* request, not a new one after a decided row (Prompt 1's design).

Added `data-testid="trainer-request-row"` (with a `data-user-email` attribute) and
`data-testid="trainer-request-confirm-decision"` to the new page for Playwright, after an
early version of the test using bare `getByRole("button", { name: "Approve" }).first()` turned
out to be a real flakiness risk: the queue is a shared dev/test database, and the *oldest* pending
row (sorted by `createdAt` per the backend's default) is not necessarily the one a given test run
just created — a leftover row from an earlier manual-verification session would have made
`.first()` silently approve/reject the wrong request. Scoped locators fixed it, matching
`e2e/trainer-flow.spec.ts`'s own `[data-testid="client-card"][data-client-email="..."]` precedent.

Test coverage: `e2e/trainer-request-superadmin-queue.spec.ts` (new, 2 cases) — approve grants the
role and clears the row from the list (checked both via the UI and by re-fetching
`/trainer-requests/me` as the applicant), and reject lets the applicant submit a fresh request
while never exposing any way to reopen the rejected one. Ran the full Playwright suite afterward;
same pre-existing, unrelated `trainer-chat.spec.ts` failure as Prompt 2's notes, nothing new.
`tsc --noEmit`, `eslint`, and the full Vitest suite (359 tests) all clean. Not verified: real
Resend delivery, and the Hungarian tab label/copy weren't proofread by a native speaker (same
standing gaps as Prompts 1 and 2).

**Prompt 4 — Web: `features/billing` data layer + `useEntitlements` — ✅ done**
Types, api module, query keys, invalidations. No UI yet.
*Verify:* Vitest on the api module and the invalidation map; a test that the types match a
recorded `EntitlementResponse` fixture.

Landed `web/src/features/billing/` — `types.ts` mirroring `com.lifey.billing.dto.EntitlementResponse`
and its nested `TrainerEntitlement`/enums field-for-field (64 §3.2), `api.ts` (`entitlements`,
`checkoutSession`, `portalSession`), and `hooks.ts` (`useEntitlements()`, 60s `staleTime` matching
the backend's own `Cache-Control: max-age=60`, `refetchOnWindowFocus` explicit — the one query in
the app where that default actually earns a comment, since a trainer returning from Stripe's
hosted checkout in another tab needs the next focus to pick up what the webhook already recorded,
D-B5). `queryKeys.billing.entitlements()` added. One deliberate deviation from §6's literal file
list: it names `api.ts` as covering "entitlements, checkout-session, portal-session,
trainer-requests" — but `features/trainer-requests/` already exists as its own module (Prompts
1–3), predating this prompt, and duplicating that surface into `features/billing/` would just be
two places calling the same three endpoints. Left it where it is.

**The invalidation map** (§6, §9.1) turned out to mean more than adding an entry — `invalidationMap`
in `queryKeys.ts` existed already but was never actually imported anywhere in the app, decorative
since whichever prompt first wrote it. Confirmed with a repo-wide grep before touching anything:
zero call sites. Added `trainerInvite`/`trainerClient` entries (each pairing the resource's own key
with `queryKeys.billing.entitlements()`) and then wired them into the three existing mutations that
actually change seat count — `admin/invites/page.tsx`'s send and revoke, `admin/page.tsx`'s "end
relationship" — replacing their single ad-hoc `invalidateQueries` calls with a loop over the map
entry. This makes the map load-bearing for the first time, and is exactly the fix for the failure
mode §9.1 names directly: "a missing query invalidation... the seat meter shows a stale number."
No seat meter exists to observe yet (that's `66` Prompt 5), so this only matters once something
calls `useEntitlements()` — but wiring it now means Prompt 5 doesn't have to remember to.

Verified the wiring didn't regress the two existing mutations by actually driving them in a
browser against the real backend (not just `tsc`/`eslint`/Vitest, and not just trusting the diff):
logged in as a real trainer account, sent an invite, watched the network panel show the `POST`
immediately followed by the invalidation-triggered `GET` refetch, watched the pending list update
in the UI, then revoked it and watched the same round trip in reverse. Along the way, hit a real
tooling snag worth flagging: this session's `computer` tool's coordinate-based clicks and
simulated typing were unreliable against this particular page (silently no-op — no error, just no
DOM effect) after the first couple of interactions, while `form_input` (sets the value through
React's tracked setter) and a direct `element.click()` via `javascript_tool` both worked
reliably; switched to that combination rather than trusting an un-actioned "click succeeded"
report a second time.

Test coverage: `features/billing/types.test.ts` (4 cases, this prompt's own *Verify* line —
each fixture uses `satisfies EntitlementResponse`, which is the actual check: it fails
`tsc --noEmit` the moment the type drifts from what the backend really sends, covering a
mid-trial trainer, a free non-trainer, a degraded fail-open response, and a sponsored client);
`features/billing/api.test.ts` (3 cases, mirroring `client-config.test.ts`'s `vi.stubGlobal("fetch", ...)`
pattern — the one existing precedent in this codebase for testing an `api.ts` module directly);
`queryKeys.test.ts` gained two new `describe` blocks asserting the new key and that both
`invalidationMap` entries actually contain `billing.entitlements()`. `tsc --noEmit`, `eslint`,
and the full Vitest suite (369 tests, up from 359) all clean.

**Prompt 5 — Web: `/admin/billing` page — ✅ done**
Plan card, seat meter, plan chooser, portal button, cancel explainer.
*Verify:* Playwright over three seeded states (trialing, active-Starter, past-due); a unit
test that the rendered prices come from the shared `PLANS` constant (`65` §10.4).

Landed `web/src/app/(admin)/admin/billing/page.tsx` (the first real consumer of `useEntitlements()`
from Prompt 4) plus two new reusable components under `features/billing/components/` —
`SeatMeter` and `PlanChooser`, named that way in §6 specifically because later prompts reuse them
(the over-limit archiving flow, Prompt 9, needs the same seat meter; the onboarding checklist,
Prompt 10, likely needs the same chooser). The current-plan card, manage-billing button, and
cancel explainer stay inline in `page.tsx` — §6's own component list doesn't name them
separately, unlike `SeatMeter`/`PlanChooser`, so there's no signal they're meant to be reused
elsewhere. Added `/admin/billing` to `AdminSidebar`'s nav (a new "Billing" item with a
`credit_card` icon, after "Invites").

Two pieces of pure logic were split out specifically so Prompt 5's own *Verify* line could be
satisfied without inventing component-rendering test infrastructure this project doesn't have —
confirmed by reading `vitest.config.ts` before writing anything: `environment: "node"`,
`include: ["src/**/*.test.ts"]` (`.test.ts` only, not `.tsx` — no React Testing Library, no
jsdom/happy-dom anywhere in the dependency tree). Every existing test in this codebase is a pure-
function test for exactly this reason (`lib/pricing.test.ts` is the closest precedent, testing
`buildPricingOffers` rather than rendering `PricingCards`). So: `features/billing/planPricing.ts`
(`planOptionsFor(interval)`, reading straight from `PLANS`, plus the `TrainerPlan` (upper) <->
`PlanId` (lower) conversion the backend/frontend enums need) and `features/billing/status.ts`
(`daysUntil`, `statusPillFor`) are both plain `.ts` modules `PlanChooser.tsx`/`page.tsx` import
and render with no further transformation — meaning testing the functions *is* testing what
renders, satisfying the Verify line's "rendered prices come from PLANS" directly rather than by
proxy.

**A real bug surfaced only by actually seeding the three states and looking at the page in a
browser, not from `tsc`/`eslint`/Vitest**: the trial-ends date line was gated on
`EntitlementResponse.expiresAt`, which is `null` whenever `lifey.billing.enabled=false` — the
*current default* in every environment per `64` §1 point 6, including this one. `TrainerEntitlement
.trialEndsAt` is populated regardless of that flag (`buildTrainerBlock` runs before the
enabled-check in `EntitlementServiceImpl`), so a TRIALING trainer's card silently showed the
status pill's "Trial · 6 days left" correctly but never the "Your trial ends on {date}" line
underneath it — a bug a type-correct, fully-linted build would never have caught, since both
fields are legitimately typed as nullable strings. Fixed by reading `trainer.trialEndsAt` for the
trial case instead of the top-level field. Documented, not fixed, as a related limitation:
`TrainerEntitlement` has no `currentPeriodEnd`-equivalent field of its own, so an ACTIVE/PAST_DUE
trainer's "renews on" date is *only* available when billing is actually enabled — invisible
today, everywhere, until that flag flips. Out of scope for a "Web" prompt to fix by adding a
backend field; flagged here for whoever flips the flag.

Verified all three seeded states directly in a browser against the real backend before writing
the Playwright tests (matching Prompt 4's practice): seeded a TRIALING/PRO, an ACTIVE/STARTER,
and a PAST_DUE/PRO subscription row via direct SQL for three fresh trainer accounts (raw
`user_roles`/`subscription` inserts, same reasoning as `trainer-flow.spec.ts`'s `grantTrainerRole`
— no grant API, and seeding a real Stripe subscription isn't possible in this environment),
logged in as each, and confirmed the plan name, status pill, trial-days-left text, seat count, and
which `PlanChooser` card was marked "Current plan" all matched. Also exercised both mutations'
failure paths for real (no Stripe key configured locally): clicking "Open billing portal" and
"Select" on a plan both produced real 500s from the backend, and both were caught by the
mutations' `onError` handlers and shown as inline error text — no crash, no unhandled rejection.

Test coverage: `features/billing/planPricing.test.ts` (9 cases — this prompt's own *Verify*
line, asserting monthly/yearly prices come straight from `PLANS` in its own order, the
`TrainerPlan`/`PlanId` round trip, and `isCurrentPlan`'s marking logic) and
`features/billing/status.test.ts` (5 cases — `daysUntil`'s rounding/floor-at-zero behavior and
`statusPillFor`'s tone mapping). `e2e/trainer-billing-page.spec.ts` (new, 3 cases, one per
seeded state) covers this prompt's own *Verify* line end to end. Ran the full Playwright suite
afterward to check for regressions from the `AdminSidebar` nav change; same pre-existing,
unrelated `trainer-chat.spec.ts` failure as every prior prompt's notes, nothing new. `tsc --noEmit`
(including `e2e/`, which isn't covered by `eslint src`), `eslint`, and the full Vitest suite (381
tests, up from 369) all clean.

**Prompt 6 — Web: checkout round trip — ✅ done**
Checkout redirect, `?checkout=success` polling state (D-T3), error/cancel returns.
*Verify:* Playwright with a stubbed checkout endpoint; assert the page never shows the new
plan before the entitlement response changes, and that the 30 s timeout path renders.

`64` D-B5 is the whole shape of this prompt: the Stripe redirect itself is never trusted, only a
`GET /api/v1/me/entitlements` response that actually matches. Landed as three new pieces under
`features/billing/`: `checkoutPoll.ts` (pure — `nextCheckoutPollDelayMs(attempt)` returning the
fixed backoff schedule `[1000, 1000, 2000, 3000, 5000, 8000, 10000]`, summing to exactly the 30 s
ceiling, plus `setPendingCheckoutPlan`/`consumePendingCheckoutPlan` wrapping `sessionStorage`),
`hooks.ts`'s new `useCheckoutConfirmation(active, expectedPlan)` (a plain `setTimeout` loop, not
TanStack Query's `refetchInterval` — the stop condition depends on the *fetched value*, and the
manual "Check again" refresh needs to run one check without restarting the schedule), and
`PlanChooser`'s checkout mutation now stashing the selected plan into `sessionStorage` the instant
"Select" is clicked — Stripe's `success_url` is a fixed, server-configured value
(`StripeProperties.successUrl`) that can't carry a dynamic per-checkout plan parameter, and the
full-page redirect to Stripe wipes any in-memory React state, so this is the only place left to
remember which plan the trainer was buying by the time the browser comes back.

`/admin/billing/page.tsx` reads `?checkout=success|cancel` via lazy `useState(() => ...)`
initializers (locking `checkoutActive`/`expectedPlan`/`showCancelNotice` once per page load rather
than re-deriving them on every render, since `consumePendingCheckoutPlan()` is one-shot and would
return `null` on a second call) and strips the query param via `router.replace()` in an effect so a
refresh doesn't restart the poll or re-show the cancel notice. While `checkoutActive &&
status === "polling"`, the entire normal page body (plan card, seat meter, chooser, cancel
explainer) is suppressed in favor of a single `CheckoutStatusBanner` — deliberately, since
`64` D-B5's whole point is that the stale plan must not be visible as if it were current during
this window. Once `status` becomes `"confirmed"` the banner disappears and the normal body (now
reading the fresh entitlement) renders; `"timedOut"` keeps the banner up (now with a "Check again"
button wired to `manualRefresh`) but lets the normal body show underneath it too, since by then
showing the *last known-true* state is honest, not misleading.

Test coverage: `checkoutPoll.test.ts` (4 cases — starts at 1000ms, backs off monotonically, the
schedule sums to exactly the 30 s ceiling, returns `false` past the end). `e2e/billing-checkout-
round-trip.spec.ts` (new, 3 cases) is this prompt's own *Verify* line: `page.route()` stubs
`GET /api/v1/me/entitlements` (the first spec in this suite to stub a backend response rather than
hit the real one — the whole point here is controlling *when* the backend "changes its mind", which
a real webhook-driven backend can't be told to do on a schedule) and `page.clock` fakes
`setTimeout`/`Date` so the 30 s ceiling doesn't mean a 30-real-second test. One case confirms the
new plan is never shown before the 3rd stubbed response; one drives the stub to never confirm and
asserts the timeout banner, the "Check again" button, and that clicking it re-checks without
getting stuck; one covers `?checkout=cancel`.

**A real timing bug found only by running the suite, not by the isolated test file**: the timeout
test originally advanced the fake clock with either one large `fastForward(31_000)` or a fixed
`for` loop of even 4 s steps, and both intermittently failed to reach the timed-out state — a
single fake-clock jump fires every fake `setTimeout` due within it before any of their `await
refetch()` calls (a real, if `page.route`-mocked, Promise chain tied to real microtask scheduling,
not the fake clock) actually resolves and schedules the *next* real timer, so callbacks chained
after that await never become "due" within the jump that was supposed to trigger them. Fixed by
stepping the fast-forward through `checkoutPoll.ts`'s own schedule exactly, one element at a time,
gating each step on `expect.poll(() => entitlementCalls).toBeGreaterThanOrEqual(...)` before
advancing further — this also exposed that the default 5 s `expect.poll` timeout was itself too
tight under the full suite's 4-worker parallel load (passed reliably alone, failed once at "6 of 7
calls" when run alongside 17 other specs), fixed by giving that specific poll a 15 s timeout, since
the fake-clock jump is instant but the mocked fetch's promise settling is real wall-clock time
competing for the same event loop as three other workers.

Ran the full Playwright suite twice after the fix (once to catch the parallel-load flake, once to
confirm the 15 s timeout resolved it) — same pre-existing, unrelated `trainer-chat.spec.ts`
failure as every prior prompt's notes, nothing else. `tsc --noEmit`, `eslint`, and the full Vitest
suite (385 tests, up from 381) all clean.

**Prompt 7 — Web: `AdminBillingBanner` — ✅ done**
The escalation table in D-T4.
*Verify:* a component test over every row of the table, asserting exactly one banner and the
correct dismissibility; plus a test that `> 7 days trial` renders nothing.

Landed as `features/billing/bannerState.ts` — D-T4's table as one pure function, `bannerStateFor
(entitlement)`, returning a discriminated union on `kind` (`restricted | pastDue | overLimit |
trialUrgent | trialInfo`, or `null`) rather than one flat interface with optional fields, so a
caller that has already switched on `kind` gets `activeClients`/`daysLeft` narrowed to non-optional
instead of fighting `| undefined` at every call site. Same "extract the logic into a plain `.ts`
function" pattern as `planPricing.ts`/`status.ts` (Prompt 5) and `checkoutPoll.ts` (Prompt 6), for
the same reason: no component-rendering test infrastructure in this project, so the pure function
is what makes the table itself unit-testable (`bannerState.test.ts`, 15 cases — one per table row,
plus the priority-collapse cases §9 risk 2 calls out by name: `PAST_DUE` outranking `overLimit`,
`overLimit` outranking a trial banner). `AdminBillingBanner.tsx` imports it, adds sessionStorage-
backed dismissal for `trialInfo` only (`isTrialInfoDismissed`/`dismissTrialInfo`, co-located in
`bannerState.ts` alongside the pure function — the same pattern `checkoutPoll.ts` set for pairing a
schedule with its sessionStorage helpers), and is wired into `(admin)/admin/layout.tsx` above
`{children}`.

**A real design gap found only by seeding real subscription rows and hitting the real backend, not
from the table itself**: 66 §8 edge case 6 says a super admin who also holds ROLE_TRAINER resolves
to `source: "COMP"` and should see no banner. Implementing that as `if (entitlement.source ===
"COMP") return null` seemed direct — until testing against the real (default) local backend showed
*every* trainer resolving to `source: "COMP"`, banner permanently dark. The cause:
`EntitlementServiceImpl.openResponse` — the `lifey.billing.enabled=false` rollback switch (`64` §1
point 6, default in every environment today) — deliberately reuses the same `EntitlementSource.COMP`
value to mean "open for everyone, nothing degraded" (its own code comment), completely unrelated to
the super-admin case the plan doc names. This isn't a coincidence to work around: while billing is
disabled, `SeatLimitServiceImpl.state()` always returns `OK` and every seat check passes — nothing
is actually enforced — so a "Your workspace is read-only" banner sourced from a stale subscription
row would be actively false, not just premature. Keeping the `source === "COMP"` check as-is is
therefore correct for both cases at once, not a bug; documented here because the doc's edge case
and the backend's actual encoding don't obviously line up without tracing `openResponse` directly.

Verified against the real backend with actual seeded accounts (STARTER/PRO subscriptions in every
status, and six real `trainer_clients` rows to push a STARTER trainer over its 5-seat limit for
the `overLimit` case) rather than trusting the unit tests alone — the same discipline as every
prior prompt. This surfaced the `source: "COMP"` gap above, and separately confirmed
`useSessionStore.initialize()` is called independently by four different mount points (the admin,
app, and superadmin layouts, plus the marketing header's `HeaderAuthActions`) sharing one
single-use, rotating refresh token in `localStorage` — manually seeding a session by writing a
token into `localStorage` and navigating is a race the genuinely-signed-in path (login through the
UI) doesn't have, since a concurrent `initialize()` call elsewhere can consume-and-rotate the same
token first. Not a Prompt 7 bug, but real friction worth remembering for future manual verification:
prefer `loginThroughUi` (or a real login call) over seeding tokens directly.

New Playwright spec `e2e/admin-billing-banner.spec.ts` (7 cases, one per table row plus D-T6's chat
exemption and the dismissal-survives-navigation case) is this prompt's *Verify* line end to end —
but only runs meaningfully with the backend started `BILLING_ENABLED=true`, for the same reason the
implementation itself checks `source`. Each test probes the real state first (`billingIsEnabled`,
a throwaway account's entitlement source) and calls `test.skip(...)` rather than failing when
billing is off, so `npx playwright test` stays green against this project's actual default
environment — the same category of documented gap as Prompt 5's un-testable live-Stripe-checkout
limitation, not a fudge. Ran the full suite twice: once against a temporary `BILLING_ENABLED=true`
backend (all 7 new cases passing for the real reason, not by coincidence), once against the normal
default backend (the same 7 cleanly skipped, everything else — including `billing-checkout-round-
trip.spec.ts` and `trainer-billing-page.spec.ts` — passing, same pre-existing unrelated
`trainer-chat.spec.ts` failure as every prior prompt). `tsc --noEmit`, `eslint`, and the full Vitest
suite (400 tests, up from 385) all clean.

**Prompt 8 — Web: `BillingBlockedDialog` on the four blocked paths — ✅ done**
Invites, assignments, programs, scheduling.
*Verify:* Playwright over a seeded `CANCELED` trainer: each of the four shows the dialog,
**and `/admin/chat` is fully usable** (D-T6).

Landed as `features/billing/billingGate.ts` — `trainerBillingStateFor(entitlement)`, a client-side
mirror of the backend's own `SeatLimitServiceImpl.state()` (`RESTRICTED`/`OVER_LIMIT`/`OK`), same
naming as the backend enum on purpose for searchability. Deliberately **one** rule for all four
actions, even though the backend's real `assertCanSendInvite` is a touch stricter (it also counts
pending invites toward the limit) — matching `state()` exactly, rather than each call site
inventing its own threshold, is what D-T5 asks for directly ("so the four call sites cannot drift
into four different explanations"); the backend's stricter invite check remains the real
enforcement underneath, this is only the "don't bother opening the drawer" pre-check.
`useTrainerBillingGate()` (`features/billing/hooks.ts`) wraps it around `useEntitlements()`, and
`BillingBlockedDialog.tsx` renders it — reusing `AdminBillingBanner`'s own `bannerRestrictedTitle/
Body` and `bannerOverLimitTitle/Body` copy (`admin.billing` namespace) rather than a near-duplicate
set of dialog-only strings, since D-T4's table and D-T5's dialog describe the exact same two states
at two different moments. No new translation keys needed for this prompt.

**Wiring landed at the *drawer* level, not at every individual trigger button.** All three shared
drawers (`AssignToClientDrawer`, `AssignProgramDrawer`, `ScheduleWorkoutDrawer`) turned out to
already be the single component behind every one of their several trigger buttons across different
pages (the programs list, a program's own edit page, a client's Schedule tab, the calendar's "+",
and `TemplatesView`'s per-template buttons all just conditionally mount the same drawer component,
confirmed by reading each trigger site before touching anything) — so gating inside each drawer
(an early return rendering `BillingBlockedDialog` instead of the drawer's own JSX, once its own
hooks have run, when `gate.state !== "OK"`) covers every entry point without touching the trigger
buttons themselves. Combined with the invites page's inline "Send" button (not a drawer — gated
directly in its `onClick`), that's exactly four files touched for four actions, matching D-T5's own
framing. The trigger buttons stay exactly as clickable-looking as they were — D-T5's explicit
rejection of disabling them — and clicking one shows the dialog immediately instead of a drawer the
trainer would only fill out to hit a wall.

**The same `source: "COMP"` consideration from Prompt 7 applies here identically, and for the same
reason**: `trainerBillingStateFor` returns `"OK"` whenever `source === "COMP"`, which is correct for
both the super-admin case and `lifey.billing.enabled=false`'s open-for-everyone rollback response,
since `SeatLimitServiceImpl` itself returns `OK` unconditionally when billing is disabled — this
pre-check has to agree with the real enforcement it's standing in front of, or a trainer would see a
dialog claiming a restriction the backend was never going to apply. New Playwright spec
`e2e/billing-blocked-dialog.spec.ts` (2 cases: all four actions in one seeded-`CANCELED`-trainer
test via `test.step`, plus a dedicated D-T6 chat-is-untouched case) follows the exact same
`billingIsEnabled`-probe-and-skip pattern Prompt 7 established, for the identical reason.

**A real ordering bug found only by running against the real backend, not from the type-checker**:
the spec originally logged in immediately after registering a fresh trainer account, then granted
`ROLE_TRAINER` by direct SQL afterward, then tried to seed a workout template and a program through
the API using that first login's access token — every request came back `403 Forbidden`. A JWT's
`roles` claim is fixed at mint time; the token from a login that happened *before* the role grant
never carries `ROLE_TRAINER`, no matter what the database says a moment later. Fixed by reordering
to register → grant the role → log in (the token that actually gets used for seeding), matching
what `useSessionStore.refreshUser()` exists to solve on the client side (Prompt 1's landed notes) —
the same JWT-staleness shape, just hit from the API-seeding side of a test instead of the browser.

Ran the full Playwright suite twice (once against a temporary `BILLING_ENABLED=true` backend — both
new cases passing for the real reason — once against the normal default backend — both cleanly
skipped, everything else passing, same pre-existing unrelated `trainer-chat.spec.ts` failure as
every prior prompt). `tsc --noEmit`, `eslint`, and the full Vitest suite (414 tests, up from 400,
`billingGate.test.ts`'s 10 cases covering the state machine including the "RESTRICTED outranks
OVER_LIMIT" and "exactly at the limit is still OK" edge cases) all clean.

**Prompt 9 — Web: over-limit archiving flow — ✅ done**
Marking, inline archive action, the counting banner.
*Verify:* Playwright — a Studio→Starter downgrade with 8 clients enters `OVER_LIMIT`, and
archiving down to 5 clears it without any data disappearing from the archived clients' pages.

A generic "End relationship" flow (`ClientCard`'s "⋯" menu, `trainerApi.revokeClient` →
`DELETE /trainer/clients/{id}`) already existed, predating this prompt — confirmed by reading
`TrainerAccessServiceImpl.revoke()` before writing anything: it only flips the relationship row to
`REVOKED` and publishes `TrainerClientRevokedEvent` (which cancels *future* schedules/program
assignments via `ScheduleCancellationListener`); the client's own weights, workouts, and history are
never touched, since they belong to the client's own `user_id`, not the relationship. So "no data
disappearing" (this prompt's own Verify line) was already true by construction — this prompt's job
was archive-specific UI, not a new backend action.

**"Marking" turned out to be the one genuinely interpretive part of D-4.1's text.** "seats over the
limit are marked" could mean flagging *specific* client cards as "these are the ones over the
limit" — but D-M12 explicitly rejects any auto-archiving heuristic ("N most recent / least active"),
and singling out particular cards as "the extra ones" implies exactly that kind of ordering, even if
the trainer still clicks the button themselves. Landed as: the *list* enters the marked mode, not
individual cards — every `ClientCard` gets an identical inline "Archive client" button
(`data-testid="archive-client-inline"`, distinct from the neutral always-available "End
relationship" menu item, with its own confirm dialog using D-4.1's exact reassurance: "{name} keeps
everything they have... You'll only lose the coaching link") the moment `useTrainerBillingGate()`
(Prompt 8) reports `OVER_LIMIT`, and the existing `AdminBillingBanner` (Prompt 7) is *the* counting
banner — its `overLimitBody` copy changed from the generic "Upgrade, or archive clients..." to the
live countdown `66` §4.1 quotes verbatim: "Archive {count} clients to fit your plan, or upgrade to
keep them all," recomputed from `activeClients - maxClients` on every render. No client is marked as
more disposable than any other; the count is the only thing that moves.

**A real, previously-invisible bug found only by testing a live seat-count change within one page
session, not by any earlier prompt's tests**: after archiving a client, the banner's "N / 5" count
never updated — stuck at the pre-archive number for up to a full minute, the exact "seat meter shows
a stale number" failure `66` §9 risk 1 warns about, just from a cause none of Prompts 4–8 could have
surfaced (their tests never needed entitlements to *change* within a single running page). Traced to
`EntitlementController` answering with `Cache-Control: private, max-age=60` (a deliberate,
reasonable header — `useEntitlements()`'s own `staleTime: 60_000` comment already says it matches
this) — but `queryClient.invalidateQueries()` only forces *TanStack Query* to refetch; the resulting
`fetch()` call is still transparently served from the *browser's own* HTTP cache for up to 60s,
which has no idea an invalidation happened. Fixed at `billingApi.entitlements` with `cache:
"no-store"` (a new optional second parameter on `api.get`, `web/src/lib/api/client.ts`) — deliberately
scoped to just this one endpoint's fetch call, not a global change, since `staleTime` already gives
every *other* access pattern (page load, window focus, plain remount) the "don't hit the network
more than once a minute" behavior at the layer that actually understands invalidation. This bug was
real in production already: any of the three seat-changing mutations (invite send, invite revoke,
this prompt's archive) would have shown a stale seat meter/banner for up to a minute, on every
environment where billing is enabled — not something Prompt 9 introduced, only exposed.

New Playwright spec `e2e/billing-overlimit-archiving.spec.ts` (1 case, seeding a trainer with 8
active clients on a seeded `ACTIVE`/`STARTER` subscription — max 5 — then archiving 3 through the
real UI and confirming the banner clears and the archived client's own weight data survives via a
direct API check) follows the same `billingIsEnabled`-probe-and-skip pattern as Prompts 7–8, plus
re-ran the full 16-case billing spec set (Prompts 6–9 combined) against a temporary
`BILLING_ENABLED=true` backend to confirm the cache fix didn't regress anything already passing.
Also hit, and fixed inline, the pre-existing "first visit" `ClientListModal` on `/admin` intercepting
clicks on the archive buttons underneath it in the test — seeded past via `sessionStorage`, matching
how the app itself gates it. Ran the full suite against the normal default backend afterward: same
pre-existing unrelated `trainer-chat.spec.ts` failure, everything else — including all ten now-skip-
by-default billing specs — clean. `tsc --noEmit`, `eslint`, and the full Vitest suite (414 tests,
unchanged from Prompt 8 — this prompt added no new pure-logic module worth a dedicated unit test,
the arithmetic being one subtraction already covered by `bannerState.test.ts`'s `overLimit` cases)
all clean.

**Prompt 10 — Web: onboarding checklist — ✅ done**
*Verify:* component test that step 2 ticks on *accepted*, not on *sent*.

Landed as `features/billing/onboardingChecklist.ts` — `onboardingStepsFor(input)`, a pure function
over five already-known booleans/counts (same pattern as `bannerState.ts`/`billingGate.ts`), plus
`allStepsDone` and a pair of `localStorage` helpers (`markProfileDone`/`isProfileMarkedDone`,
`dismissChecklist`/`isChecklistDismissed` — `localStorage`, not `sessionStorage`, since §5 says
"dismissible *permanently*," unlike Prompt 7's session-only trial-info banner). §5's own point —
step 2 must tick on an *accepted* invite, never a merely-*sent* one — falls out for free rather than
needing special-case logic: `GET /trainer/clients` (`TrainerAccessService
.findActiveClientsForTrainer`) is already ACTIVE-only server-side, confirmed by reading it before
writing anything, so a pending invite is simply invisible to `activeClientCount` by construction.
`onboardingChecklist.test.ts` (8 cases) is this prompt's own *Verify* line, run as a pure-function
test in place of a component test for the same reason every earlier prompt gives: no jsdom/RTL in
this project's Vitest config.

**Two of the five steps needed a real judgment call, both documented here rather than guessed
silently:**

1. **Step 1 ("complete your trainer profile") has no backend concept to check against** — searched
   both `com.lifey.user` and `com.lifey.settings` before writing anything; there is no
   `bio`/`specialties`/`certifications` field or `TrainerProfile` entity anywhere, and this prompt's
   own doc entry has no backend annex (unlike Prompt 1's). Rather than fabricate a proxy from
   `firstName`/`lastName` (always set at registration, so it would tick trivially on day one and
   defeat the point of it being a step at all), landed as the one *self-reported* step: a checkbox
   the trainer clicks themselves, linking to `/settings` — a common, honest pattern for a step with
   no real backend signal, and consistent with §5 calling step 2 (not step 1) "the one that
   matters," which already signals step 1 was never meant to be the rigorously-verified one.
2. **Step 5 ("first message sent") is a best-effort read, not an exact one.**
   `ConversationResponse.lastMessage` is only the *most recent* message per conversation (confirmed
   in `features/chat/types.ts`'s own doc comment), not full history, so `lastMessage.senderId !==
   peer.userId` only tells you the trainer sent the *latest* message in at least one thread — a
   trainer whose first message was later replied to would read as "not done" until they send
   another. A precise answer needs a new backend aggregate; not worth it for a nice-to-have nudge,
   documented here rather than silently accepted as exact.

**"On `/admin` for the trial's duration" turned out to need no new plumbing**: `trainer.status ===
"TRIALING"` (read via `useEntitlements()` directly, since `useTrainerBillingGate()` only exposes the
derived `OK`/`OVER_LIMIT`/`RESTRICTED` state, not the raw status) is populated from the real
subscription row regardless of `lifey.billing.enabled` — `buildTrainerBlock` runs before that flag
is even checked (re-confirmed from Prompt 5's landed notes before writing this). Unlike Prompts
7–9, this component needed **no** temporary `BILLING_ENABLED=true` backend to test for real.

Verified against the real (default, billing-disabled) backend: seeded a TRIALING/PRO trainer, sent
a pending (not yet accepted) invite and confirmed step 2 stayed undone, then accepted a client via
direct SQL and confirmed it ticked; clicked the profile checkbox and confirmed it persisted across a
reload; created a real workout template via the API and confirmed step 3; assigned that template to
the client via the real assignment endpoint and confirmed step 4. Step 5 was **not** exercised
end-to-end — chat is a separate service (`chat_conversations`/`chat_messages` belong to
`lifey-chat`, per `backend/CLAUDE.md`, not this monolith's database) that isn't running in this
local dev setup (no entry in `.claude/launch.json`), the same reason `trainer-chat.spec.ts` is this
suite's one known, pre-existing, unrelated timeout — its logic is covered by the unit test instead.
New Playwright spec `e2e/trainer-onboarding-checklist.spec.ts` (2 cases) covers all of the above,
plus that the checklist never renders for a non-TRIALING (e.g. `ACTIVE`) trainer. Also hit, and
fixed the same way as Prompt 9, the pre-existing `ClientListModal` first-visit backdrop on `/admin`
intercepting clicks — seeded past via `sessionStorage`.

Ran the full Playwright suite afterward: same pre-existing unrelated `trainer-chat.spec.ts` failure,
the ten Prompt 7–9 billing-gated specs cleanly skipped (default backend), everything else — 19 cases
— passing. `tsc --noEmit`, `eslint`, and the full Vitest suite (422 tests, up from 414) all clean.

This closes out `66`'s Order of work — Prompts 1–10 are now all ✅ done.

---

## 8. Edge cases

1. **A trainer whose role is revoked while on `/admin/billing`.** The next entitlement
   refetch has no `trainer` block; the page redirects to `/dashboard` with an explanation
   rather than rendering an empty plan card.
2. **Checkout completed in a second tab.** The polling in D-T3 is per-tab; the other tab
   picks it up on window focus (`refetchOnWindowFocus`).
3. **Downgrade that would be over-limit** — allowed (D-M12), but the plan chooser warns
   before redirecting: *"You have 12 active clients. On Starter you can keep them, but you
   won't be able to invite or assign until you're back to 5."*
4. **A pending invite pushing a trainer to the limit.** The seat meter shows
   `4 active + 1 pending / 5` so "why can't I invite" is answered before it is asked.
5. **Currency.** The plan chooser shows HUF for a Hungarian locale and EUR otherwise, but the
   charge follows the billing country chosen in Checkout (63 §7.12). The page says so in one
   line under the prices.
6. **A super admin viewing `/admin`** — they have `COMP` (63 §3.1); no banner, no limits, and
   no accidental checkout.
7. **Trial expiring while the trainer has a screen open.** The banner appears on the next
   focus refetch, and the next blocked action explains itself. Nothing force-navigates.

---

## 9. Risk checkpoints where a failure would be silent

1. **A missing query invalidation** after invite/revoke/archive: the seat meter shows a stale
   number and the trainer is told they are at the limit when they are not (or worse, the
   reverse). The invalidation map has its own test (§6).
2. **The banner priority collapsing** into "show them all" or "show the wrong one" — a
   `PAST_DUE` trainer who sees a friendly trial banner does not update their card, and the
   subscription silently lapses. D-T4's table is a test table for a reason.
3. **A blocked action failing with a bare 403** because one call site forgot
   `BillingBlockedDialog`. Nothing errors visibly; the trainer just concludes the product is
   broken. Prompt 8's test enumerates all four.
4. **Chat caught by a layout-level guard** (D-T6).
5. **Trial length computed on the client** from `trialEndsAt` minus device time — off-by-a-day
   banners and, worse, an "expired" banner for a trainer whose clock is ahead. Days-left comes
   from the server-side `expiresAt` compared with `checkedAt`.
6. **Prices hard-coded in the plan chooser** rather than read from `PLANS` — the page
   advertises one number and Stripe charges another (`65` §10.4).
7. **The onboarding checklist ticking step 2 on send.** Makes the funnel metric look healthy
   while the actual aha moment never happens (63 §4).

---

## 10. Non-goals (deferred)

- In-app invoice list, tax-id editing, dunning emails from our side (Stripe's portal + Stripe's
  dunning, D-T2).
- Team seats, sub-accounts, transferring a client between trainers.
- Coupon UI beyond Stripe's own promotion-code field at Checkout.
- A self-service "become a trainer" path (63 §6).
- Usage-based add-ons of any kind.

---

## 11. Test plan

| Layer | What |
|---|---|
| Backend integration | trainer request lifecycle, one-open-request rule, approval → role + trial |
| Vitest | billing api module, invalidation map, banner priority table, `PLANS` ↔ rendered prices |
| Playwright | request→pending→approved path; billing page in three states; checkout round trip incl. timeout; four blocked actions + chat unaffected; over-limit archive flow |
| Manual | one real Stripe test-mode subscription end to end, including the portal and a cancellation |

---

## 12. Suggested PR split

Prompts 1–3 (request flow) are a self-contained PR pair and can ship with M0, before any
billing exists — they make the landing CTA real. Prompts 4–6 are the checkout path. Prompts
7–9 are the restriction UX and should not merge before `64` Prompt 6, or they will render
states the backend never produces. Prompt 10 is independent.

---

## 13. After implementation

- Set `Status:`; update `docs/landing_page/README.md`.
- `docs/personal_trainer/04-web-admin-terv.md` gains `/admin/billing` and `/admin/pending`.
- `docs/personal_trainer/README.md` §2 note: role granting now also resolves a request row.
- `docs/web/07-screen-specifications.md` gains the billing screens.
