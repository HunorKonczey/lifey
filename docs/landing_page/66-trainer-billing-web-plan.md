# 66 – Trainer Billing on the Web

Status: proposed
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

**Prompt 1 — Backend: trainer access requests**
`V76`, `com.lifey.trainer.request`, the three endpoints, the mail notification, resolution on
role grant.
*Verify:* integration tests — one open request per user, super-admin list, approval both
grants the role and resolves the request, approval starts the trial (`64` §4.1).

**Prompt 2 — Web: request + pending pages**
`/admin/pending`, the request form reachable from the landing CTA, status polling.
*Verify:* Playwright — a fresh non-trainer user is routed to `/admin/pending`, sees the
pending state, and after an approval (seeded in the test DB) is routed into `/admin`.

**Prompt 3 — Web: superadmin trainer-request queue**
A tab in `/superadmin` listing pending requests with approve/reject.
*Verify:* Playwright as a super admin; a rejected request cannot be re-opened by the user
without a new submission.

**Prompt 4 — Web: `features/billing` data layer + `useEntitlements`**
Types, api module, query keys, invalidations. No UI yet.
*Verify:* Vitest on the api module and the invalidation map; a test that the types match a
recorded `EntitlementResponse` fixture.

**Prompt 5 — Web: `/admin/billing` page**
Plan card, seat meter, plan chooser, portal button, cancel explainer.
*Verify:* Playwright over three seeded states (trialing, active-Starter, past-due); a unit
test that the rendered prices come from the shared `PLANS` constant (`65` §10.4).

**Prompt 6 — Web: checkout round trip**
Checkout redirect, `?checkout=success` polling state (D-T3), error/cancel returns.
*Verify:* Playwright with a stubbed checkout endpoint; assert the page never shows the new
plan before the entitlement response changes, and that the 30 s timeout path renders.

**Prompt 7 — Web: `AdminBillingBanner`**
The escalation table in D-T4.
*Verify:* a component test over every row of the table, asserting exactly one banner and the
correct dismissibility; plus a test that `> 7 days trial` renders nothing.

**Prompt 8 — Web: `BillingBlockedDialog` on the four blocked paths**
Invites, assignments, programs, scheduling.
*Verify:* Playwright over a seeded `CANCELED` trainer: each of the four shows the dialog,
**and `/admin/chat` is fully usable** (D-T6).

**Prompt 9 — Web: over-limit archiving flow**
Marking, inline archive action, the counting banner.
*Verify:* Playwright — a Studio→Starter downgrade with 8 clients enters `OVER_LIMIT`, and
archiving down to 5 clears it without any data disappearing from the archived clients' pages.

**Prompt 10 — Web: onboarding checklist**
*Verify:* component test that step 2 ticks on *accepted*, not on *sent*.

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
