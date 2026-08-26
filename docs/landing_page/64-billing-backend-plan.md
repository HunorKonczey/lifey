# 64 – Billing Backend

Status: proposed
Scope: backend — domain, migrations, entitlement resolver, Stripe adapter, store IAP adapter,
seat enforcement, reconciliation
Depends on: `docs/landing_page/63-monetization-strategy-plan.md` (all `D-M*` decisions),
`docs/personal_trainer/02-domain-es-migraciok.md` (`trainer_client`),
`docs/personal_trainer/03-backend-terv.md` (`/api/v1/trainer/**` authorization),
`docs/06-development-rules.md` (constructor injection, DTO validation, feature packaging)

Latest migration in the repo at the time of writing is `V71__cardio_hike_fields.sql`, so this
plan starts at **V72**. Adjust the numbers if something else lands first — but keep the order.

---

## 1. What we're building

1. One `com.lifey.billing` feature package that owns *everything* about who is entitled to
   what, exposing exactly one read endpoint to clients: `GET /api/v1/me/entitlements`.
2. A Stripe adapter: create a Checkout session, receive webhooks, expose the customer
   portal, keep a local mirror of the subscription state.
3. A store adapter: verify an iOS/Android purchase token, receive App Store Server
   Notifications V2 and Play Real-Time Developer Notifications, keep the same local mirror.
4. Seat enforcement for the trainer tiers (D-M2, D-M12), wired into the existing invite and
   assignment paths.
5. A reconciliation job that repairs anything the webhooks missed, because they will miss
   things (63 §8.3).
6. **With the feature off** — no rows in `subscription`, no Stripe keys configured — the
   resolver returns `PRO`/`COMP` for everyone and every seat check passes. That is what
   makes this safe to deploy before the clients understand it.

---

## 2. Package layout

```
com.lifey.billing
├── BillingProperties.java            @ConfigurationProperties("lifey.billing")
├── entity/
│   ├── Subscription.java             one row per (user, provider) pair
│   ├── SubscriptionStatus.java       TRIALING, ACTIVE, PAST_DUE, CANCELED, EXPIRED, REFUNDED
│   ├── SubscriptionProvider.java     STRIPE, APP_STORE, PLAY_STORE, COMP
│   ├── TrainerPlan.java              STARTER, PRO, STUDIO  (maxClients lives here)
│   ├── ProcessedBillingEvent.java    idempotency ledger
│   └── AiUsageCounter.java           per-user, per-month AI call counter (D-M5)
├── repository/
│   ├── SubscriptionRepository.java
│   ├── ProcessedBillingEventRepository.java
│   └── AiUsageCounterRepository.java
├── service/
│   ├── EntitlementService(+Impl)     the resolver — §3
│   ├── SeatLimitService(+Impl)       the trainer seat rules — §4
│   ├── SubscriptionWriter.java       the only class that mutates `subscription`
│   ├── StripeBillingService(+Impl)   §5
│   ├── StoreBillingService(+Impl)    §6
│   └── BillingReconciliationJob.java §7
├── controller/
│   ├── EntitlementController.java    GET /api/v1/me/entitlements
│   ├── BillingCheckoutController.java POST /api/v1/billing/checkout-session, /portal-session
│   ├── StorePurchaseController.java  POST /api/v1/billing/store-purchase
│   └── webhook/
│       ├── StripeWebhookController.java        POST /api/v1/webhooks/stripe
│       ├── AppStoreWebhookController.java      POST /api/v1/webhooks/app-store
│       └── PlayWebhookController.java          POST /api/v1/webhooks/play
├── dto/  (EntitlementResponse, CheckoutSessionRequest/Response, StorePurchaseRequest, …)
└── exception/ (SeatLimitExceededException, SubscriptionAlreadyLinkedException, …)
```

### D-B1 One `subscription` table for both rails, not one table per provider

A single table with a `provider` discriminator and a nullable provider-specific id column
set. Two tables would mean two resolvers, two reconciliation jobs and a join every time
someone asks "what does this user have".

*Rejected: a `stripe_subscription` + `store_subscription` pair.* Cleaner columns, but every
read path then has to union them, and the "user has both" case (63 §7.3) becomes a
three-way merge instead of an ordering rule.

### D-B2 `SubscriptionWriter` is the only class allowed to write `subscription`

Webhooks, the purchase endpoint, the reconciliation job and the admin comp tool all go
through it. It is where idempotency, status transition validation and the audit log live.
A subscription row changed from four places is a subscription row nobody can explain.

### D-B3 The resolver is pure and cheap; nothing else is allowed to decide entitlement

`EntitlementService.resolve(userId)` is the *only* place the rules in 63 §3 exist. No
controller, no other service, and no client re-derives them. It does at most two queries
(the user's own subscriptions, and the sponsoring trainers' subscriptions via a single
join), and is annotated `@Transactional(readOnly = true)`.

---

## 3. Entitlements

### 3.1 Endpoint

```
GET /api/v1/me/entitlements
→ 200 EntitlementResponse   (63 §3 shape)
Cache-Control: private, max-age=60
```

Authenticated, `ROLE_USER` and up. Never 404 — an unknown/entitlement-less user is a
well-formed `FREE` response. Never 5xx for a *business* reason; if a downstream lookup
fails, log and return the `COMP`-equivalent open response (D-M9) with
`"degraded": true` so the client can tell the difference in support logs.

### 3.2 Shape

`EntitlementResponse` fields, all computed server-side:

| Field | Meaning |
|---|---|
| `tier` | `FREE` \| `PRO` |
| `source` | `NONE`, `STRIPE`, `APP_STORE`, `PLAY_STORE`, `TRAINER_SPONSORED`, `TRAINER_TRIAL`, `COMP` |
| `adsEnabled` | `tier == FREE` — sent explicitly so the policy can change without an app release |
| `historyDays` | `30` for free, `null` for Pro |
| `aiCreditsRemaining` | remaining calls this month; `null` = unlimited |
| `trainer` | present only for `ROLE_TRAINER`: `plan`, `status`, `maxClients`, `activeClients`, `trialEndsAt` |
| `expiresAt` | when the current entitlement lapses, `null` if open-ended |
| `checkedAt` / `graceUntil` | server timestamps; the client's offline grace (D-M10) is anchored to these |
| `degraded` | true when the resolver had to fail open |

### 3.3 Limits come from config, not from constants in the client

`lifey.billing.free-history-days`, `lifey.billing.free-ai-credits-per-month`,
`lifey.billing.offline-grace-days` live in `BillingProperties`. Changing the free history
window from 30 to 60 days must never require a store release (63 §8.7 is the related trap:
it is a *display* limit, so the client only needs the number).

### 3.4 AI credit counting

`ai_usage_counter (user_id, year_month, used_count)`, incremented in the same transaction
as the AI call in the nutrition feature (`docs/23-ai-calorie-estimation-plan.md`). The
check is `used_count < limit` for `FREE`, always-true for `PRO` up to the fair-use ceiling.
Counting on *successful* calls only — a failed LLM call must not burn a credit, which is
the kind of thing users notice and we would not.

---

## 4. Trainer seats

### 4.1 Trial starts at the `ROLE_TRAINER` grant, not at registration

When `RoleManagementServiceImpl` grants `ROLE_TRAINER`, it publishes a
`TrainerRoleGrantedEvent`; `SubscriptionWriter` creates the `TRIALING` row with
`trial_ends_at = now + 14d` and `plan = PRO`. A trainer who waits three days for approval
gets the full 14 days (63 §8.10).

Revoking `ROLE_TRAINER` ends the subscription's trainer scope but does not delete the row —
history matters for support and for the reconciliation job.

### 4.2 `SeatLimitService`

```java
int activeClientCount(Long trainerId);      // the ONE canonical count
boolean canAcquireClient(Long trainerId);   // activeClientCount < maxClients
void assertCanAcquireClient(Long trainerId);// throws SeatLimitExceededException
TrainerBillingState state(Long trainerId);  // OK | OVER_LIMIT | RESTRICTED
```

`activeClientCount` is a single repository method on `TrainerClientRepository` — the same
one the UI reads. This is 63 §8.1: two queries that disagree is the classic silent failure
here.

### 4.3 Where enforcement is wired

| Path | Rule |
|---|---|
| `TrainerInviteController` — send invite | `assertCanAcquireClient`, counting **pending** invites toward the limit so a trainer cannot queue 40 invites on a 5-seat plan |
| `ClientInviteController` — client accepts | re-check inside the accepting transaction with a `SELECT … FOR UPDATE` on the trainer's subscription row; losing the race → `409 SEAT_LIMIT_EXCEEDED` (63 §7.6) |
| `AssignmentController`, `ProgramAssignmentController`, `WorkoutScheduleController` | blocked when `state != OK` |
| Chat endpoints | **never blocked** (D-M8) |
| Every read endpoint under `/api/v1/trainer/**` | never blocked |

### D-B4 Enforcement is an interceptor-free, explicit service call

A `@RequiresActiveSubscription` annotation with an aspect was considered and rejected: the
rules differ per endpoint (chat exempt, reads exempt, pending invites counted), so an
annotation would need parameters that make it harder to read than the two-line explicit
call. Explicit calls also show up in a diff, which is what §8's review guidance depends on.

### 4.4 Statuses and what they allow

| `SubscriptionStatus` | Trainer can invite/assign | Sponsors clients | Banner |
|---|---|---|---|
| `TRIALING` | yes | **yes** (D-M4) | days left, from day 7 |
| `ACTIVE` | yes | yes | none |
| `PAST_DUE` | yes | yes | "update your card" (63 §7.5) |
| `CANCELED` / `EXPIRED` | no | no | "reactivate" |
| any, but `OVER_LIMIT` | no (existing untouched) | yes | "you are over your plan" |

---

## 5. Stripe adapter

### 5.1 Objects

- One Stripe **Customer** per trainer, id mirrored on `subscription.provider_customer_id`.
- Three **Products**, six **Prices** (monthly/yearly × Starter/Pro/Studio), created in the
  Stripe dashboard and referenced by id from `BillingProperties` — never created from code.
- Checkout in `subscription` mode, with `client_reference_id = userId`, Stripe Tax on,
  promotion codes on, and the withdrawal-waiver checkbox as a custom consent field (63 §5).

### 5.2 Endpoints

```
POST /api/v1/billing/checkout-session   { plan, interval }        → { url }
POST /api/v1/billing/portal-session                               → { url }
```

Both `ROLE_TRAINER`, both returning a URL the browser is redirected to. The success URL is
`/admin/billing?checkout=success`, which polls the entitlement endpoint rather than trusting
the redirect — the webhook is the source of truth and may land after the redirect (§5.4).

### 5.3 Webhook

`POST /api/v1/webhooks/stripe` — **public** (added to `PUBLIC_ENDPOINTS` in
`SecurityConfig`), authenticated by Stripe's signature header, reading the **raw** body.

Events handled: `checkout.session.completed`, `customer.subscription.created|updated|deleted`,
`invoice.paid`, `invoice.payment_failed`, `charge.refunded`. Everything else is acknowledged
with 200 and ignored — a 4xx makes Stripe retry forever.

### D-B5 The webhook only records; it never trusts the redirect

The success redirect is a UI convenience. Entitlement changes exclusively on the webhook, so
a user who closes the tab at the wrong moment still gets what they paid for, and a user who
crafts a success URL gets nothing.

### 5.4 Idempotency

Every handled event writes `processed_billing_event (provider, event_id, processed_at)`
with a unique constraint on `(provider, event_id)`; a duplicate insert short-circuits the
handler. Combined with the reconciliation job (§7), this covers both directions of 63 §8.3.

---

## 6. Store adapter (mobile Pro)

### 6.1 Purchase verification

```
POST /api/v1/billing/store-purchase
{ "platform": "IOS" | "ANDROID", "productId": "...", "purchaseToken": "..." }
→ 200 EntitlementResponse | 409 SUBSCRIPTION_ALREADY_LINKED | 422 INVALID_RECEIPT
```

- **iOS**: verify the StoreKit 2 signed `JWSTransaction` locally against Apple's root
  certificates, then confirm with the App Store Server API. Local verification first means
  a working purchase even during an Apple API blip.
- **Android**: `purchases.subscriptionsv2.get` on the Play Developer API with a service
  account, then `acknowledge` — an unacknowledged Play purchase is **auto-refunded after 3
  days**, which is a silent revenue loss and belongs in the checklist of things to test.

### 6.2 Server notifications

`POST /api/v1/webhooks/app-store` (ASSN V2, JWS-signed) and `POST /api/v1/webhooks/play`
(RTDN via a Pub/Sub push subscription, verified by an OIDC token). Both public in
`SecurityConfig`, both idempotent via `processed_billing_event`, both routed into
`SubscriptionWriter`.

Notification types that must change state: `DID_RENEW`, `EXPIRED`, `DID_FAIL_TO_RENEW`,
`REFUND`, `REVOKE`, `GRACE_PERIOD_EXPIRED` (Apple); `SUBSCRIPTION_RENEWED`,
`SUBSCRIPTION_EXPIRED`, `SUBSCRIPTION_REVOKED`, `SUBSCRIPTION_IN_GRACE_PERIOD` (Play).

### D-B6 The purchase token, not the receipt, is the identity

`subscription.provider_subscription_id` holds the Apple `originalTransactionId` / the Play
`purchaseToken`'s linked subscription id, and carries a unique index. That index is what
makes 63 §7.7 a clean 409 instead of a silently transferred entitlement.

---

## 7. Reconciliation

`BillingReconciliationJob`, daily at 03:30 Europe/Budapest (same scheduling style as
`TrainerWeeklyReportJob`):

1. For every non-terminal `subscription`, re-fetch the provider's truth (Stripe API, App
   Store Server API, Play Developer API).
2. Write any difference through `SubscriptionWriter`, logging at WARN with the diff — every
   line in that log is a webhook that did not arrive.
3. Expire any `TRIALING` row past `trial_ends_at`.
4. Emit a metric per provider: rows checked, rows corrected. A non-zero corrected count that
   *stays* non-zero is the signal that webhook delivery is broken.

Rate-limited to N per run (config) so a large account base cannot blow the provider quotas.

---

## 8. Migrations

| Version | Contents |
|---|---|
| `V72__subscription.sql` | `subscription` — `id`, `user_id` FK, `provider`, `status`, `plan`, `provider_customer_id`, `provider_subscription_id`, `current_period_end`, `trial_ends_at`, `cancel_at_period_end`, `created_at`, `updated_at`. Unique `(user_id, provider)`; unique `provider_subscription_id` where not null; index on `(status, current_period_end)` for the job. |
| `V73__processed_billing_event.sql` | `processed_billing_event` — `provider`, `event_id`, `event_type`, `processed_at`; unique `(provider, event_id)`; index on `processed_at` for pruning. |
| `V74__ai_usage_counter.sql` | `ai_usage_counter` — `user_id`, `year_month` (`char(7)`), `used_count`; unique `(user_id, year_month)`. |
| `V75__backfill_trainer_trials.sql` | Data backfill: every existing `ROLE_TRAINER` user gets a `TRIALING` row with `trial_ends_at = now + 30 days`. Existing trainers must not wake up locked out on deploy day — 30, not 14, deliberately. |

No column is added to `users`; entitlement is derived, never stored on the user
(D-B3). No column is added to any synced table, so delta sync is untouched (D-M11).

---

## 9. Order of work

Each step is one surface, one session, independently mergeable, with its own verification.

### Milestone M1a — the resolver, with nothing to resolve

**Prompt 1 — Backend: `subscription` schema and entity**
`V72` + `V73`, `Subscription`, `SubscriptionStatus`, `SubscriptionProvider`, `TrainerPlan`
(with `maxClients`), repositories. No service, no endpoint.
*Verify:* `mvn -pl backend test` — repository slice test that saves and reads back a row of
each provider, and that the unique constraints reject duplicates.

**Prompt 2 — Backend: `EntitlementService` + `GET /api/v1/me/entitlements`**
The resolver from 63 §3, the DTO from §3.2, the controller, `BillingProperties`. With no
subscription rows anywhere, every user resolves `FREE` — except that `lifey.billing.enabled`
defaults to `false`, which forces `COMP`/open. That flag is what makes this deployable on
day one.
*Verify:* a table-driven test over 63 §3 and §7.1–7.4; an integration test hitting the
endpoint as a plain user, a trainer, and a sponsored client.

**Prompt 3 — Backend: `SeatLimitService` and the trainer state machine**
`activeClientCount` on `TrainerClientRepository`, `TrainerBillingState`, `trainer` block in
the response. Nothing enforced yet — the numbers just become visible.
*Verify:* a test that walks a `TrainerClient` through `PENDING → ACTIVE → REVOKED → EXPIRED`
and asserts the count at each step (63 §8.1).

### Milestone M1b — money in

**Prompt 4 — Backend: Stripe checkout + portal endpoints**
Stripe Java SDK, `BillingProperties` price ids, `BillingCheckoutController`. No webhook yet;
the session is created and the URL returned.
*Verify:* an integration test with the Stripe SDK stubbed, asserting `client_reference_id`
and the price id; plus one manual run against Stripe test mode.

**Prompt 5 — Backend: Stripe webhook + `SubscriptionWriter`**
Signature verification, raw-body handling, the six event types, the idempotency ledger,
`SecurityConfig` public rule.
*Verify:* replay a captured event fixture twice → one state change; an unsigned request →
400; an unknown event type → 200 and no write.

**Prompt 6 — Backend: seat enforcement on the invite and assignment paths**
`assertCanAcquireClient` in the four controllers from §4.3, the locking re-check on accept,
`SeatLimitExceededException` → `409` in `GlobalExceptionHandler`.
*Verify:* integration tests for send-over-limit, accept-over-limit, the concurrent accept
race, and — importantly — that chat and every read path still work at `CANCELED`.

**Prompt 7 — Backend: trial lifecycle**
`TrainerRoleGrantedEvent` → `TRIALING` row, `V75` backfill, trial expiry in the job skeleton.
*Verify:* granting the role in a test creates a 14-day trial; the backfill migration test
asserts every pre-existing trainer got 30 days.

### Milestone M3a — store purchases

**Prompt 8 — Backend: iOS purchase verification**
StoreKit 2 JWS verification, App Store Server API client, `POST /billing/store-purchase` for
`IOS`.
*Verify:* fixture-based test with a signed sandbox transaction; a tampered JWS → 422; the
same `originalTransactionId` for a second user → 409.

**Prompt 9 — Backend: Android purchase verification**
Play Developer API client, acknowledgement, the `ANDROID` branch.
*Verify:* as above, plus an explicit assertion that `acknowledge` is called (§6.1).

**Prompt 10 — Backend: store server notifications**
The two webhook controllers, notification-type mapping, idempotency.
*Verify:* fixture replay per notification type; duplicate delivery → one write.

### Milestone M5a — the safety net

**Prompt 11 — Backend: `BillingReconciliationJob` + metrics**
*Verify:* a test where the local row says `ACTIVE` and the provider says `CANCELED` → the
job corrects it and logs a WARN; a test that the per-run cap is honoured.

**Prompt 12 — Backend: AI credit counter**
`V74`, `AiUsageCounter`, the increment inside the AI call path, `aiCreditsRemaining` in the
response.
*Verify:* a free user's 4th call in a month → 402/`AI_CREDITS_EXHAUSTED`; a failed LLM call
does not increment (§3.4).

---

## 10. Non-goals (deferred)

- Proration UI or mid-cycle plan-change previews beyond what Stripe's portal already does.
- Invoicing beyond Stripe's own PDFs (63 §5).
- Multiple concurrent paid subscriptions per user per provider.
- Anything resembling a payments ledger of our own — Stripe and the stores are the ledger.
- Admin tooling for issuing comps beyond a single `COMP` row inserted by SQL.

---

## 11. Edge cases

1. **Webhook arrives before the user row is committed** (Checkout completed on a
   just-registered account). Look up by `client_reference_id`; if absent, 200 + park the
   event for the reconciliation job rather than 4xx-ing Stripe into a retry storm.
2. **A user with both a Stripe trainer subscription and a store Pro subscription.** Two
   rows, both valid; §3 resolution makes it a non-event.
3. **Plan change mid-cycle** from Studio to Starter while over the limit → `OVER_LIMIT`
   immediately at the webhook, not at period end (D-M12).
4. **`ROLE_TRAINER` revoked while subscribed.** The Stripe subscription is *not*
   auto-cancelled — that is a refund decision, not a code decision. The workspace goes
   inaccessible and the situation is logged at WARN for support.
5. **Sandbox purchases in production.** Apple sandbox transactions carry an environment
   flag; accepting one in prod is free Pro for anyone with a sandbox account. The
   environment must be asserted, not assumed.
6. **Play RTDN replays after a topic re-subscribe** can deliver months of old
   notifications. The idempotency ledger absorbs them; the ledger must therefore not be
   pruned more aggressively than 90 days.
7. **A user deleted while a webhook is in flight.** `SubscriptionWriter` no-ops on a missing
   user and logs; it must never resurrect a deleted account.

---

## 12. Test plan

| Layer | What |
|---|---|
| Repository slice | constraints in §8, `activeClientCount` across all statuses |
| Service unit | `EntitlementService` table-driven over 63 §3 + §7; `SeatLimitService` transitions |
| Webhook integration | signature verification, idempotent replay, unknown types, out-of-order delivery |
| Store integration | valid/tampered/sandbox receipts, second-user 409, Play acknowledgement |
| Endpoint integration | `/me/entitlements` for each of the five resolution branches, plus the fail-open path with the resolver throwing |
| Migration | `V75` backfill over a fixture with three pre-existing trainers |

`lifey.billing.enabled=false` must have its own test asserting the whole system is open —
that is the rollback switch, and an untested rollback switch is not one.

---

## 13. Suggested PR split

One PR per prompt. Prompts 1–3 can merge before any UI exists and change no behaviour.
Prompt 6 (enforcement) is the first behaviour-changing PR and should merge alone, behind
`lifey.billing.enabled`, so it can be reverted by config rather than by deploy.

---

## 14. Risk checkpoints where a failure would be silent

1. **`lifey.billing.enabled` defaulting to `true` in some environment file.** Locks out
   every trainer on a deploy with no error. It defaults to `false` and is enabled per
   environment, explicitly.
2. **Play purchases never acknowledged** → auto-refunded after 3 days, revenue silently
   gone (§6.1).
3. **Sandbox receipts accepted in production** (§11.5).
4. **Idempotency ledger pruned too aggressively**, so a replayed RTDN double-applies (§11.6).
5. **Seat check bypassed on one of the four assignment controllers** — the trainer simply
   gets more than they pay for, and nothing anywhere reports it. The test in Prompt 6 must
   enumerate the endpoints.
6. **The reconciliation job silently no-op-ing** because the per-run cap is smaller than the
   number of subscriptions. Emit both "checked" and "eligible" counts, and alert when they
   diverge.
7. **`current_period_end` stored in local time.** Everything is `Instant`, UTC, via the
   existing `ClockConfig`.

---

## 15. After implementation

- Set `Status:` here; update `docs/landing_page/README.md`.
- `docs/05-backend-api.md` gains the billing endpoints; the Postman collection in
  `docs/postman/` gains the entitlement and checkout calls.
- `docs/personal_trainer/03-backend-terv.md` gains a note that `/api/v1/trainer/**` is now
  subject to `SeatLimitService`.
- Runbook: what to do when the reconciliation job reports corrections (webhook endpoint
  health, Stripe dashboard delivery log, Play Pub/Sub subscription state).
