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

**Prompt 1 — Backend: `subscription` schema and entity — ✅ done**
`V72` + `V73`, `Subscription`, `SubscriptionStatus`, `SubscriptionProvider`, `TrainerPlan`
(with `maxClients`), repositories. No service, no endpoint.
*Verify:* `mvn -pl backend test` — repository slice test that saves and reads back a row of
each provider, and that the unique constraints reject duplicates.

Landed as `V73__subscription.sql` + `V74__processed_billing_event.sql` — `V72` was already
taken by `65` Prompt 10's `signup_source` column by the time this ran, so the pair shifted up
by one, keeping the order this doc specifies. `com.lifey.billing.entity` gained `Subscription`,
`SubscriptionStatus`, `SubscriptionProvider`, `TrainerPlan` (`STARTER`=5, `PRO`=25, `STUDIO`=100,
per `63` D-M2's fair-use ceiling) and `ProcessedBillingEvent` (not explicitly named in this
prompt's bullet, but its migration is — adding the entity alongside its table now avoids an
unmapped table sitting around until Prompt 5). `com.lifey.billing.repository` gained
`SubscriptionRepository` and `ProcessedBillingEventRepository`. Repository-slice tests cover a
round trip for every `SubscriptionProvider` and both unique constraints
(`user_id, provider` and `provider_subscription_id`). Full `mvn verify` (805 tests) and
`check-schema-ownership.sh` both clean.

**Prompt 2 — Backend: `EntitlementService` + `GET /api/v1/me/entitlements` — ✅ done**
The resolver from 63 §3, the DTO from §3.2, the controller, `BillingProperties`. With no
subscription rows anywhere, every user resolves `FREE` — except that `lifey.billing.enabled`
defaults to `false`, which forces `COMP`/open. That flag is what makes this deployable on
day one.
*Verify:* a table-driven test over 63 §3 and §7.1–7.4; an integration test hitting the
endpoint as a plain user, a trainer, and a sponsored client.

Landed as specified. `EntitlementServiceImpl.resolve(userId)` reads at most two queries —
`SubscriptionRepository.findByUserId` for the user's own rows, and a new
`findSponsoringSubscriptionsForActiveClient` (an actual SQL `join` against `TrainerClient`,
one round trip) for sponsors — then walks the five branches from 63 §3 in order, wrapped in a
try/catch that fails open with `degraded: true` per §3.1. The trainer block is built
independently of the resolved tier (so a trainer with a lapsed trial still sees their own
plan/status) from a new `TrainerClientRepository.countByTrainerIdAndStatus`, called out in its
own Javadoc as the one canonical active-client count both this resolver and `64` Prompt 3's
`SeatLimitService` must share (63 §8.1). `lifey.billing.*` (`enabled` defaulting to `false`,
`free-history-days`, `free-ai-credits-per-month`, `offline-grace-days`) landed in
`application.yml` alongside `BillingProperties`/`BillingConfig`. `aiCreditsRemaining` for the
free tier currently just echoes the configured monthly allowance — there is no usage counter
yet (`64` Prompt 12 wires `ai_usage_counter` and real decrementing).

Test coverage: an 18-case table-driven `EntitlementServiceImplTest` (Mockito) over every 63 §3
branch plus edge cases 7.1 (trainer-who-is-also-a-client precedence, asserted with
`verify(..., never())` that the sponsor query isn't even run), 7.2 (any single active sponsor
is enough), 7.5 (`PAST_DUE` still sponsors/still grants through dunning), the disabled-flag
open path, the unknown-user fallback, and the fail-open path; a 3-scenario
`EntitlementControllerIntegrationTest` over the real security filter chain and schema
(Testcontainers), covering a plain user, a trainer on trial, and a sponsored client. Full `mvn
verify` and `check-schema-ownership.sh` both clean.

**Prompt 3 — Backend: `SeatLimitService` and the trainer state machine — ✅ done**
`activeClientCount` on `TrainerClientRepository`, `TrainerBillingState`, `trainer` block in
the response. Nothing enforced yet — the numbers just become visible.
*Verify:* a test that walks a `TrainerClient` through `PENDING → ACTIVE → REVOKED → EXPIRED`
and asserts the count at each step (63 §8.1).

Landed as specified — `activeClientCount` was already added to `TrainerClientRepository` in
Prompt 2 (reused here, not duplicated: 63 §8.1's "one shared repository method" now literally
backs both `EntitlementService`'s trainer block and this service). New: `TrainerBillingState`
(`OK`/`OVER_LIMIT`/`RESTRICTED`), `SeatLimitExceededException`, and `SeatLimitService`/`Impl`
implementing all four §4.2 methods. `state()`/`canAcquireClient()`
both gate on the trainer's own Stripe subscription being in one of §4.4's "can invite/assign"
statuses (`TRIALING`/`ACTIVE`/`PAST_DUE`) before looking at the seat count at all — a
`CANCELED`/`EXPIRED`/no-subscription trainer is `RESTRICTED` regardless of how few clients
they have. The `OVER_LIMIT`/at-capacity boundary is deliberately asymmetric:
`activeClientCount == maxClients` is still `state() == OK` (full, not over) but
`canAcquireClient()` is already `false` — the count has to become strictly greater than the
limit (a downgrade, 63 §7.6) before `state()` flips to `OVER_LIMIT`. Nothing calls
`assertCanAcquireClient` or gates on `state()` yet; that wiring is Prompt 6.

Test coverage: a 13-case table-driven `SeatLimitServiceImplTest` (Mockito) over every §4.4
status, the disabled-flag bypass (asserting the subscription repository isn't even queried),
and the `OK`/`OVER_LIMIT` boundary; a real-DB `SeatLimitServiceActiveClientCountTest`
(Testcontainers) walking one `TrainerClient` through `PENDING → ACTIVE → REVOKED → EXPIRED`
plus a second test proving the count isn't thrown off by another trainer's or another client's
row. Full `mvn verify` (841 tests) and `check-schema-ownership.sh` both clean.

### Milestone M1b — money in

**Prompt 4 — Backend: Stripe checkout + portal endpoints — ✅ done** (automated verify only —
see note below)
Stripe Java SDK, `BillingProperties` price ids, `BillingCheckoutController`. No webhook yet;
the session is created and the URL returned.
*Verify:* an integration test with the Stripe SDK stubbed, asserting `client_reference_id`
and the price id; plus one manual run against Stripe test mode.

Landed as `stripe-java` `33.4.0`, a new `StripeProperties` (`lifey.billing.stripe.*` — secret
key, success/cancel/portal-return URLs, the six price ids, all empty-by-default so the app
still starts with no Stripe account configured), `StripeBillingService`/`Impl`, and
`BillingCheckoutController` (`POST /api/v1/billing/checkout-session`, `POST
/api/v1/billing/portal-session`), both new `SecurityConfig` matchers scoped to `ROLE_TRAINER`
rather than folded into `/api/v1/trainer/**` (that prefix will also carry `ROLE_USER`-only
billing endpoints later, e.g. mobile store-purchase). Checkout sets `client_reference_id` to
the trainer's own user id (that's how the Prompt 5 webhook finds them back), turns on Stripe
Tax and promotion codes, and collects the EU 14-day withdrawal-right waiver as a real
`consent_collection.terms_of_service` checkbox with custom text (63 §5) rather than just fine
print. Neither endpoint writes `subscription` — no `SubscriptionWriter` exists yet (that's
Prompt 5); a Checkout call reuses an existing `provider_customer_id` if one is already on file
so retrying after a Prompt-5 webhook doesn't mint a duplicate Stripe Customer, and Portal
throws a 404 (`ResourceNotFoundException`) if a trainer has no linked customer yet — expected
until Prompt 5 lands, since nothing writes that column before then.

Test coverage: 6 cases in `StripeBillingServiceImplTest`, stubbing the actual Stripe SDK via
`Mockito.mockStatic` (not a hand-rolled wrapper) and capturing the real `SessionCreateParams`
sent to `Session.create` — asserts `client_reference_id`, the resolved price id per
plan/interval, the customer-reuse-vs-email branch, the 404 on an unknown trainer, and a
`StripeException` wrapped as `StripeApiException`. **The "one manual run against Stripe test
mode" half of this prompt's *Verify* line has not been done** — this environment has no Stripe
test-mode account/keys — so real API-shape correctness (price id formats, the actual redirect
URL, the consent checkbox rendering) is unverified beyond what the stubbed SDK call proves.
Flagged as open until someone runs it against a real Stripe test account. Full `mvn verify`
(847 tests) and `check-schema-ownership.sh` both clean.

**Prompt 5 — Backend: Stripe webhook + `SubscriptionWriter` — ✅ done**
Signature verification, raw-body handling, the six event types, the idempotency ledger,
`SecurityConfig` public rule.
*Verify:* replay a captured event fixture twice → one state change; an unsigned request →
400; an unknown event type → 200 and no write.

Landed as `StripeWebhookController` (`controller/webhook/`, reads the raw body off
`HttpServletRequest` rather than `@RequestBody` since the signature is computed over Stripe's
exact bytes) and `SubscriptionWriter` — the only class that now writes `subscription`,
matching D-B2. `/api/v1/webhooks/stripe` is public in `SecurityConfig`, authenticated by
`Webhook.constructEvent`'s own signature check. Idempotency: only one of the six *handled*
types reaches `processed_billing_event` — an unknown type is acknowledged but leaves no
trace, which is what the *Verify* line's "no write" turned out to mean once `charge.refunded`
et al. needed a place to record themselves; the check is a plain `existsBy` done before
dispatch, not an insert-first race guard, since the *Verify* line only asks for correctness
under sequential replay and a true concurrent double-delivery would just apply the same
idempotent-in-effect mutation twice — the reconciliation job (Prompt 11) is the intended
backstop for anything that races.

Two real Stripe API surface facts, discovered by extracting the `stripe-java` `33.4.0`
sources rather than assuming an older shape, that shaped the event handlers: (1)
`current_period_end` and `price` live on `subscription.items.data[0]`, not on `Subscription`
itself anymore, so plan/period-end come from the first line item; (2) `Charge` no longer
carries an `invoice`/`subscription` reference at all, and `Invoice`'s subscription id moved to
the nested `invoice.parent.subscription_details.subscription`. Given that, `charge.refunded`
resolves the row by `provider_customer_id` (a new `SubscriptionRepository` method) rather than
chasing a subscription id through an extra API call — correct for this system specifically
since Stripe is trainer-subscription-only (D-M1), so a charge's customer has exactly one
Stripe subscription to refund. `checkout.session.completed` is the only event carrying
`client_reference_id` (= the user id), so it links the (userId, provider) row to its
customer/subscription id; a brand-new row defaults to `ACTIVE` since the coincident
`customer.subscription.created` event corrects it in virtually every real case (63 §11.1's
missing-user race: log a WARN and skip rather than 4xx-ing Stripe into a retry storm).
`customer.subscription.created`/`.updated` are found by `provider_subscription_id`; if that
row doesn't exist yet (an ordering race with `checkout.session.completed`), same treatment —
WARN and skip, left for a later event or Prompt 11's job to settle.

Test coverage: a 10-case `StripeWebhookControllerIntegrationTest` (Testcontainers, real
signatures via `Webhook.Signature.generateSignatureHeader` — the SDK's own test helper) —
unsigned and badly-signed requests both 400, an unknown type 200-and-no-write, the replay
case, all six event types individually, and the unknown-user checkout race. Full `mvn verify`
(857 tests) and `check-schema-ownership.sh` both clean. Not verified: an actual Stripe CLI
`stripe trigger`/dashboard-resend run against a live endpoint — same "no test-mode account in
this environment" gap noted in Prompt 4.

**Prompt 6 — Backend: seat enforcement on the invite and assignment paths — ✅ done**
`assertCanAcquireClient` in the four controllers from §4.3, the locking re-check on accept,
`SeatLimitExceededException` → `409` in `GlobalExceptionHandler`.
*Verify:* integration tests for send-over-limit, accept-over-limit, the concurrent accept
race, and — importantly — that chat and every read path still work at `CANCELED`.

Landed as specified, behind `lifey.billing.enabled` as its own PR per §13. `SeatLimitService`
gained three purpose-built assertions beyond the four §4.2 methods, each still one explicit
call at its call site (D-B4): `assertCanSendInvite` (status gate + active **and pending**
count vs. `maxClients` — a new `TrainerClientRepository.countByTrainerIdAndStatusAndExpiresAtAfter`,
wired into `TrainerInviteServiceImpl.invite`), `assertCanAcquireClientForAccept` (a new
`SubscriptionRepository.lockTrainerSubscriptionForUpdate`, `SELECT … FOR UPDATE` — wired into
a shared `TrainerInviteServiceImpl.applyResponse` private method so both accept paths,
`respond` and the email-token `respondViaEmailToken`, get the same locked re-check inside the
same transaction that then mutates the row, per 63 §7.6), and `assertActiveState` (blocks
whenever `state() != OK`, i.e. `RESTRICTED` **or** `OVER_LIMIT` — wired into
`ContentAssignmentServiceImpl.assign`, `ProgramAssignmentServiceImpl.assign`,
`WorkoutScheduleServiceImpl.create`). `SeatLimitExceededException` → `409` landed in
`GlobalExceptionHandler`.

Two interpretive calls the plan text didn't spell out, made and documented rather than left
implicit: (1) "blocked when `state != OK`" is read as gating only the **create** endpoints in
those three controllers — `unassign`/`cancel`/`revoke` and every `GET` stay ungated, matching
the "block acquiring, not managing what you have" principle used everywhere else in `63`/`64`
(a restricted trainer who couldn't even unassign their own content would be actively worse
off). (2) declining an invite is never seat-checked — only `respond(..., accept=true)` and the
email accept link call the assertion; decline only ever shrinks a trainer's footprint. "Chat…
never blocked" needed no code change to verify: chat lives entirely in the separate
`lifey-chat` service (`backend/CLAUDE.md`) with no dependency on this billing package, so
there is nothing in this repo that could regress it.

Test coverage: `SeatLimitServiceImplTest` grew from 13 to 22 cases covering the three new
methods (including that `assertCanSendInvite` never even queries pending invites once the
status gate alone rejects, and that `assertCanAcquireClientForAccept` locks rather than
plain-reads); a new `SeatEnforcementIntegrationTest` (Testcontainers, real JWTs, real security
chain) covers send-over-limit, send-under-limit-still-succeeds, accept-over-limit (queued
while under the limit, still caught at accept time), decline-is-never-blocked,
a real two-thread concurrent-accept race for the last seat (asserts exactly one 204 and one
409, and that the final active count is exactly the plan's limit — never a 6th seat), and
three CANCELED-state checks (`GET /api/v1/trainer/clients` still 200, `DELETE .../clients/{id}`
still 204, sending an invite still 409). All four pre-existing `@InjectMocks`-based service
tests this prompt touches (`TrainerInviteServiceImplTest`, `ContentAssignmentServiceImplTest`,
`ProgramAssignmentServiceImplTest`, `WorkoutScheduleServiceImplTest`) needed an added
`@Mock SeatLimitService` field to keep passing — an unstubbed mock's `void` methods are already
no-ops, so no other change to those files was needed. Full `mvn verify` (874 tests) and
`check-schema-ownership.sh` both clean.

**Prompt 7 — Backend: trial lifecycle — ✅ done**
`TrainerRoleGrantedEvent` → `TRIALING` row, `V75` backfill, trial expiry in the job skeleton.
*Verify:* granting the role in a test creates a 14-day trial; the backfill migration test
asserts every pre-existing trainer got 30 days.

Landed as specified. `RoleManagementServiceImpl` didn't publish any event before this — added
a new `TrainerRoleGrantedEvent` (record, publisher-side package `com.lifey.superadmin`,
matching `TrainerClientRevokedEvent`'s convention) fired only on the branch that actually adds
the role (not the idempotent no-op), and guarded on `role == ROLE_TRAINER` even though
`MANAGEABLE_ROLES` only contains that role today. A new package-private `TrainerTrialListener`
(`com.lifey.billing`) consumes it with a plain `@EventListener` — not `AFTER_COMMIT` — so the
trial row is created atomically with the grant, matching `ScheduleCancellationListener`'s
precedent and directly serving "a trainer who waits three days for approval gets the full 14
days" (63 §8.10): the clock starts at grant, not at whenever a later request happens to
notice the missing row. `SubscriptionWriter` gained `startTrainerTrial` (no-ops if the trainer
already has a Stripe-provider row — re-granting after a revoke must never reset an existing
paid subscription back to a fresh trial, since history is kept) and `expireTrial` (found by
our own row id, not `providerSubscriptionId`, since a trial that never converted may not have
one yet).

`BillingReconciliationJob` (`com.lifey.billing.service`) is genuinely the skeleton of the §7
job named in the package layout, not a differently-named placeholder — Prompt 11 adds more
steps to this same class rather than replacing it. Scheduled 03:30 **Europe/Budapest**
explicitly (`@Scheduled(..., zone = "Europe/Budapest")`) per §7's literal spec, breaking from
every other job's plain-UTC-cron convention deliberately: a daily sweep is more exposed to DST
drift than `TrainerWeeklyReportJob`'s once-a-week 05:00 UTC, which the job's own Javadoc
argues is already positioned hours inside every relevant timezone's day regardless of zone.

`V75__backfill_trainer_trials.sql` (the version the plan predicted was in fact still free)
backfills a 30-day `TRIALING`/`PRO` row for every `ROLE_TRAINER` user with no existing
Stripe-provider row — the `not exists` guard means it's also safe to have landed after Prompt
1's `subscription` table rather than needing careful sequencing.

Test coverage: a real end-to-end `TrainerTrialIntegrationTest` (Testcontainers, real JWTs,
`SuperAdminUserController` → `RoleManagementServiceImpl` → event → listener → `SubscriptionWriter`
→ DB) for both "granting the role creates a 14-day trial" and "re-granting after a revoke
doesn't reset an existing subscription"; a `TrainerTrialListenerTest` and `SubscriptionWriterTest`
(new — its first dedicated test file) at the unit level; a `BillingReconciliationJobTest`
(`Clock.fixed`, matching `WorkoutReminderJobTest`'s convention); and a
`BackfillTrainerTrialsMigrationTest` following `FoodsExercisesOwnershipMigrationTest`'s
two-phase-Flyway pattern (migrate to V74, seed pre-existing trainer/user rows via raw JDBC,
migrate to latest, assert on the result) — the only way to actually test a backfill's effect
on pre-existing data, since a normal `@SpringBootTest` would apply V75 before a test method
ever got to seed anything for it to backfill. `RoleManagementServiceImplTest` gained an
`@Mock ApplicationEventPublisher` field plus two new cases (event published on real grant,
not published on the idempotent no-op). Full `mvn verify` (888 tests) and
`check-schema-ownership.sh` both clean.

### Milestone M3a — store purchases

**Prompt 8 — Backend: iOS purchase verification — ✅ done**
StoreKit 2 JWS verification, App Store Server API client, `POST /billing/store-purchase` for
`IOS`.
*Verify:* fixture-based test with a signed sandbox transaction; a tampered JWS → 422; the
same `originalTransactionId` for a second user → 409.

Landed on Apple's own `app-store-server-library` `5.2.0` (`SignedDataVerifier` for local JWS
verification, `AppStoreServerAPIClient` for the confirmation call) rather than hand-rolling
JWS/X.509 chain verification — the same "use the vendor SDK, not our own crypto" choice as
Stripe in Prompt 4. `apple/AppleRootCA-G3.cer`, Apple's own published production root, is
bundled as a real classpath resource (`BillingConfig`'s `SignedDataVerifier` bean — safe to
build eagerly, unlike the API client, since it never touches a secret). New `AppleProperties`
(`lifey.billing.apple.*`); `environment` defaults to `SANDBOX` so a fresh deploy can't
accidentally accept production receipts, which is also the concrete mechanism behind 63
§11.5's "the environment must be asserted, not assumed" — `SignedDataVerifier` rejects any
transaction whose own embedded environment doesn't match what's configured.

`AppStoreServerAPIClient` is built fresh per call inside `StoreBillingServiceImpl`, not as a
Spring bean — its `BearerTokenAuthenticator` eagerly parses the configured private key at
construction, which would crash application startup with an empty/placeholder key otherwise.
Wrapping construction *and* the call in one broad catch turned out to double as the "local
verification first means a working purchase even during an Apple API blip" resilience the
plan asks for: an unconfigured Apple key in dev degrades identically to a live outage — logged
as a WARN, swallowed, the purchase still succeeds on local verification alone. `StoreBillingServiceImpl`
also folds in D-B6/63 §7.7 (409 only when the `originalTransactionId` belongs to a *different*
user — the same user re-verifying their own token is treated as an idempotent refresh) and a
small status inference from the decoded transaction (`revocationDate` present → `REFUNDED`,
`expiresDate` in the past → `EXPIRED`, else `ACTIVE`) — the App Store Server API's richer
status (`getAllSubscriptionStatuses`) is left for the reconciliation job (Prompt 11) rather
than fetched synchronously on every purchase call. `StorePurchasePlatform` intentionally has
only the `IOS` value — `ANDROID` lands in Prompt 9 alongside its own verification branch,
rather than sitting here half-wired.

The genuinely hard part was testing real cryptography without real Apple credentials.
Apple's `ChainVerifier` requires an exact 3-certificate x5c chain and a specific non-critical
X.509 OID on the leaf and intermediate (`AppleExtensionCertPathChecker`), discovered by
reading `ChainVerifier`/`AppleExtensionCertPathChecker` source directly rather than assuming a
shape. `AppleTestChain` (test-only, via a new `bcpkix-jdk18on` test dependency) builds a real,
self-signed root → WWDR-shaped intermediate → receipt-signer-shaped leaf chain with those
exact OIDs present, so `StoreBillingServiceImplTest` exercises genuine ECDSA chain and
signature verification — not a stub — against a locally-generated root passed directly to a
test-scoped `SignedDataVerifier` instance (the production bean, trusting the real Apple root,
is never used in tests). The chain's validity window is fixed and wide (2020–2035) rather than
relative to `Instant.now()`, since `ChainVerifier` validates against the JWS payload's own
`signedDate` field (online checks are off), not wall-clock time.

Test coverage: an 8-case `StoreBillingServiceImplTest` (real crypto: valid/expired/revoked
transactions, a tampered signature, a malformed token, a wrong bundle id, the second-user 409,
the same-user idempotent-refresh allow); a 4-case `StorePurchaseControllerTest` (`@WebMvcTest`,
mocked service — the HTTP/`GlobalExceptionHandler` layer only, since the crypto is already
covered). Full `mvn verify` (900 tests) and `check-schema-ownership.sh` both clean. Not
verified: an actual device/sandbox-tester purchase against Apple's real sandbox — same
"no real vendor account in this environment" gap as Stripe (Prompts 4–5).

**Prompt 9 — Backend: Android purchase verification — ✅ done**
Play Developer API client, acknowledgement, the `ANDROID` branch.
*Verify:* as above, plus an explicit assertion that `acknowledge` is called (§6.1).

Landed on Google's official `google-api-services-androidpublisher` (`v3-rev20260825-2.0.0`) —
pulling in `google-api-client`, which transitively brings `google-auth-library-oauth2-http`
(`GoogleCredentials`/`HttpCredentialsAdapter`) and `google-http-client-gson` (`GsonFactory`),
so no dependency beyond the one artifact was needed. Unlike Apple's SDK, Google's generated
client has no clean, directly-injectable verifier object — `AndroidPublisher.Purchases
.subscriptionsv2().get(...)`/`.subscriptions().acknowledge(...)` are concrete, deeply nested
builder classes with no seam for a unit test. Wrote one: a new `PlayPurchaseClient` interface
(`getSubscription`, `acknowledge`), implemented by `PlayPurchaseClientImpl`, which builds the
real `AndroidPublisher` fresh on every call — same reason as `AppStoreServerAPIClient` in
Prompt 8: `GoogleCredentials.fromStream` parses the service-account key eagerly, so holding one
as a field would fail application startup with no key configured. New `GoogleProperties`
(`lifey.billing.google.*`), empty by default.

The critical asymmetry from iOS, called out explicitly in code comments and tests: Android has
**no local verification at all** — the `subscriptionsv2.get` call *is* the entire proof of
purchase, so unlike Apple's best-effort confirmation step (swallowed on failure),
`StoreBillingServiceImpl` lets both the `getSubscription` call and the `acknowledge` call
propagate as `InvalidReceiptException` (422) on any failure. Acknowledge is skipped only when
`acknowledgementState` is already `ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED` (idempotent re-verification,
e.g. the app re-sending the same purchase on every launch) — otherwise it's always attempted
and its failure is never swallowed, since an unacknowledged Play purchase auto-refunds after 3
days (§6.1) and silently eating that failure is exactly the "silent revenue loss" the plan
calls out. D-B6's identity for Android is the purchase token itself — Play's v2 API returns no
separate "subscription id" distinct from the token that was verified, unlike Apple's
`originalTransactionId`. Play's five relevant `subscriptionState` values were mapped onto the
existing `SubscriptionStatus` enum (`ACTIVE`/`IN_GRACE_PERIOD` → `ACTIVE`,
`ON_HOLD`/`PAUSED` → `PAST_DUE`, `CANCELED` → `CANCELED`, everything else including
`PENDING`/`UNSPECIFIED`/absent → `EXPIRED`, a fail-safe default) — a judgment call, since the
plan doesn't spell out this mapping and Play's states don't line up 1:1 with Stripe's/Apple's.

Test coverage: `StoreBillingServiceImplTest` grew from 8 to 14 cases (the file now covers both
platforms) — a valid Play purchase that acknowledges and links, the explicit "acknowledge is
called" assertion the *Verify* line asks for, an idempotency case proving acknowledge is
*not* called a second time once already acknowledged, a failed-acknowledge case proving it
surfaces as 422 rather than being swallowed, a Play API failure on the initial fetch, the
`ON_HOLD` → `PAST_DUE` mapping, and the second-user 409 keyed by purchase token. Unlike
Prompt 8, no real cryptography was needed here — `PlayPurchaseClient` is a plain Mockito mock,
which is the whole point of having introduced that seam. Full `mvn verify` (906 tests) and
`check-schema-ownership.sh` both clean. Not verified: an actual Play Console test-track
purchase against a real service account — same "no vendor account in this environment" gap as
Prompts 4, 5 and 8.

**Prompt 10 — Backend: store server notifications — ✅ done**
The two webhook controllers, notification-type mapping, idempotency.
*Verify:* fixture replay per notification type; duplicate delivery → one write.

Both webhooks are public endpoints (`SecurityConfig.PUBLIC_ENDPOINTS`), each authenticated by
its own scheme rather than a JWT — App Store notifications by the same `SignedDataVerifier`
StoreKit 2 JWS verification Prompt 8 already wired as a bean; Play RTDN by a brand-new
`PubSubTokenVerifier` checking the Pub/Sub push subscription's OIDC bearer token against
Google's live JWKS. `PubSubTokenVerifier` deliberately does *not* reuse
`com.lifey.auth.GoogleIdTokenVerifier` despite the identical shape (decode, check `iss`,
check `aud`, check a verified identity claim) — it's a different trust domain (a Pub/Sub push
audience/service-account email, not an OAuth client id audience), so collapsing them would
couple two things that change for unrelated reasons. `GoogleProperties` grew two fields
(`pubsubAudience`, `pubsubServiceAccountEmail`), both empty by default so the verifier rejects
every push until the Cloud Pub/Sub subscription is actually configured.

`AppStoreWebhookController` takes the notification as an ordinary `@RequestBody` rather than
reading the raw body — unlike Stripe (Prompt 5), the signature is over the JWS's own
`signedPayload` content, not the HTTP body bytes, so there's nothing raw-byte handling would
buy here. `PlayWebhookController` does read the raw body, matching Stripe's reasoning: simpler
to parse the two-layer, partly-base64 Pub/Sub envelope once with the one Jackson 2
`ObjectMapper` `SecurityConfig` already defines than fight Spring Boot 4's default Jackson 3
converter over it. Google ships no Java model for the RTDN payload shape (unlike the Play
Developer API's generated classes used in Prompt 9) — `PubSubPushEnvelope`, `PubSubMessage`,
`PlayDeveloperNotification`, `PlaySubscriptionNotification`, and a from-scratch
`PlayNotificationType` enum (Google documents only the raw integer codes) were all written by
hand, package-private, `@JsonIgnoreProperties(ignoreUnknown = true)`.

Both controllers follow the exact idempotency shape Prompt 5 established for Stripe:
`SubscriptionWriter.isAlreadyProcessed` short-circuits to 200 before doing any work, and
`markProcessed` is called only after a successful apply — keyed by `notificationUUID` for
Apple, `messageId` for Play. An unhandled notification type is acknowledged with 200 and
never written or marked processed, same reasoning as Stripe: a 4xx just buys endless retries
from a vendor that can't fix the type mismatch itself. One asymmetry between the two vendors,
called out explicitly in code comments: Apple's `REVOKE` (Family Sharing access loss) maps to
`CANCELED`, since `REFUND` is Apple's own separate, distinct type — but Play has no dedicated
refund RTDN type at all, so `SUBSCRIPTION_REVOKED` maps to `REFUNDED` as the closest available
signal, a deliberate judgment call the plan doesn't spell out. `DID_RENEW` is the one Apple
type that gets a full `syncSubscriptionState` (a fresh `currentPeriodEnd`, extracted from the
re-verified `signedTransactionInfo`) rather than a bare `markStatus` — every other handled type
on both sides is status-only, since Play's push payload carries no expiry itself.

Both controllers were tested as plain unit tests — no MockMvc, no Spring context, no real
HTTP — since neither needs raw-signature-over-HTTP-body verification (unlike Stripe's webhook):
`AppStoreWebhookController` is called directly with a hand-built `AppStoreServerNotificationRequest`,
`PlayWebhookController` with a `MockHttpServletRequest` carrying just the raw body. Apple's side
reuses `AppleTestChain` (Prompt 8's self-signed 3-certificate chain builder), widened from
package-private to `public` so `com.lifey.billing.controller.webhook`'s tests can share the same
real StoreKit 2 cryptography rather than building a second, divergent fixture generator.
`AppStoreWebhookControllerTest` (9 cases) covers `DID_RENEW`'s full-sync path, all five
status-only types via a parameterized test, an unhandled type writing nothing, a duplicate
`notificationUUID` writing only once, and a tampered signature returning 400.
`PubSubTokenVerifierTest` (7 cases) mirrors `GoogleIdTokenVerifierTest`'s exact pattern — a
locally RSA-signed JWT plus an in-memory Nimbus `JWKSet` standing in for Google's real JWKS —
covering the valid case, both issuer string variants, wrong audience, wrong/unverified service
account email, and a malformed token. `PlayWebhookControllerTest` (10 cases) covers all four
handled notification-type codes via a parameterized test, an unhandled code, a missing/non-Bearer/
invalid OIDC token (three separate 401 cases), a malformed envelope (400), and a duplicate
`messageId`. Full `mvn verify` (932 tests) and `check-schema-ownership.sh` both clean. Not
verified, same standing gap as every other webhook/vendor-integration prompt in this plan: no
real Apple/Google delivery in this environment, so the actual production JWKS endpoint, the
real Apple root certificates, and Google's real push-subscription behavior are all unexercised.

### Milestone M5a — the safety net

**Prompt 11 — Backend: `BillingReconciliationJob` + metrics — ✅ done**
*Verify:* a test where the local row says `ACTIVE` and the provider says `CANCELED` → the
job corrects it and logs a WARN; a test that the per-run cap is honoured.

Landed as three new steps on the same `BillingReconciliationJob` class Prompt 7 started (§7
points 1, 2, 4 — point 3, trial expiry, was already there). `reconcileProviderTruth()` reads
every non-terminal (`TRIALING`/`ACTIVE`/`PAST_DUE`) row that actually has a
`providerSubscriptionId` — a new repository method, `findByStatusInAndProviderSubscriptionIdIsNotNull`,
capped by a new `Pageable` built from a new `BillingProperties.reconciliationBatchSize`
(`lifey.billing.reconciliation-batch-size`, default 200) — that's §7's per-run rate limit.
`COMP` rows are skipped outright (no vendor to check). For each candidate, the job re-fetches
the provider's own status — Stripe via `Subscription.retrieve` (mirroring `StripeWebhookController`'s
status-string mapping), Apple via `AppStoreServerAPIClient.getAllSubscriptionStatuses`, Play via
the existing `PlayPurchaseClient` seam — and calls `SubscriptionWriter.markStatus` plus a WARN
log only when the provider's status actually differs from the local row. Metrics are per-provider
Micrometer counters, `billing.reconciliation.rows_checked`/`rows_corrected` tagged by `provider`,
emitted once at the end of the run rather than per-row — this is the first place in the whole
backend that emits a custom Micrometer counter directly (the codebase's existing `/actuator/metrics`
exposure was previously unused; `lifey-chat`'s counters live in that separate service).

Two judgment calls worth flagging. First, the Apple re-fetch deliberately uses a *different*
signal than Prompt 8's per-transaction `revocationDate`/`expiresDate` check: `getAllSubscriptionStatuses`
returns Apple's own coarse status enum (`ACTIVE`/`EXPIRED`/`BILLING_RETRY`/`BILLING_GRACE_PERIOD`/`REVOKED`)
for the whole subscription group, which is the actual "ask the provider for the truth" call §7
wants, not a re-verification of one already-trusted receipt. `REVOKED` maps to `CANCELED`, not
`REFUNDED` — consistent with `AppStoreWebhookController`'s own `REVOKE` judgment call (`64`
Prompt 10), since Apple's enum doesn't distinguish a refund from a Family Sharing access loss at
this granularity either. Second, `run()` lost its `@Transactional` annotation: Prompt 7's version
had it (fine, no external calls), but this job now makes up to `reconciliationBatchSize` blocking
HTTP calls to three vendors per run, and holding a database connection open across all of them
risked pool exhaustion; every actual write already goes through `SubscriptionWriter`, which is
`@Transactional` on its own, so each row's correction still commits atomically — just not as one
big transaction spanning the whole sweep, which is fine for a nightly best-effort job.

Test coverage in the same `BillingReconciliationJobTest`: Stripe status mismatch → correction +
both metrics via `MockedStatic<com.stripe.model.Subscription>` (mirroring `StripeBillingServiceImplTest`'s
precedent); matching status → no correction; a Play status mismatch → correction (via the
already-mockable `PlayPurchaseClient`); a provider fetch failure (Play throwing `IOException`) →
swallowed, row skipped, not corrected, still counted as checked; a `COMP` row never reaching a
vendor call; and the per-run cap test, asserting the `Pageable` passed to the repository carries
the configured page size. Apple's own fetch path isn't separately unit-tested here — exercising
it meaningfully needs a real signing key the way `AppleTestChain` supplies one for JWS
verification (`64` Prompt 8), and the swallowed-failure path is already covered via Play — so
this is a deliberate, documented coverage gap rather than a missed case. `BillingProperties`
gained its fifth field (`reconciliationBatchSize`), so two existing test files
(`SeatLimitServiceImplTest`, `EntitlementServiceImplTest`) needed their positional-constructor
calls updated. Full `mvn verify` (938 tests) and `check-schema-ownership.sh` (no migration in
this prompt) both clean.

**Prompt 12 — Backend: AI credit counter — ⚠️ partially done (counter infra only)**
`V74`, `AiUsageCounter`, the increment inside the AI call path, `aiCreditsRemaining` in the
response.
*Verify:* a free user's 4th call in a month → 402/`AI_CREDITS_EXHAUSTED`; a failed LLM call
does not increment (§3.4).

**Scope cut, made explicitly with the user before starting:** this prompt assumes an AI call
path already exists to increment inside of. It doesn't — `docs/23-ai-calorie-estimation-plan.md`'s
meal-photo estimation feature (`com.lifey.ai`, `com.lifey.nutrition.estimation`,
`MealEstimationController`/`Service`, `AiFeatureGate`) is a separate, explicitly-deferred plan
("later, designed now") with no code in this repo yet. Given three options — build the counter
infra only, skip the prompt entirely, or also build the whole AI feature just to have a real
call site — the user chose the first. So this prompt landed the counter side in full, and
everything downstream of an actual AI call (the 402/`AI_CREDITS_EXHAUSTED` gate, the
"failed call doesn't increment" guarantee, the *Verify* line above) is **not done** and cannot
be until `docs/23`'s feature lands and calls into what's built here.

Landed as `V76__ai_usage_counter.sql` — `V74`/`V75` were already taken by `processed_billing_event`
and the trainer-trial backfill (Prompts 1 and 7), so this is the next free version, same shifting
pattern Prompt 1 flagged for `V72`. `com.lifey.billing.entity.AiUsageCounter` (extends `BaseEntity`,
not `SyncableEntity` — server-only bookkeeping, never synced to the mobile client) plus
`AiUsageCounterRepository`, with an `incrementUsage(userId, yearMonth)` atomic Postgres upsert
(`insert … on conflict (user_id, year_month) do update set used_count = used_count + 1`) rather
than JPA's usual load-mutate-save, since two AI calls landing in the same user's same month at
the same time must not race and silently lose one. `AiUsageCounterService`/`Impl` wraps it with
`usedThisMonth(userId)` (read) and `recordUsage(userId)` (the increment) — the interface's
javadoc is explicit that callers must only call `recordUsage` after a successful call, since this
class has no way to verify that itself. `EntitlementServiceImpl.freeResponse` now computes
`aiCreditsRemaining` as `max(0, freeAiCreditsPerMonth - usedThisMonth(userId))` instead of always
returning the flat monthly allowance — the placeholder Prompt 2's landed notes flagged. `PRO`'s
`aiCreditsRemaining` stays `null` (unlimited-looking) as before; the fair-use ceiling for Pro
(63 D-M5, 100/month) is deliberately not wired to anything here, since enforcing it is squarely
`AiFeatureGate`'s future job, not the counter's or the resolver's.

Two real bugs surfaced and fixed during verification, both worth flagging since they're the kind
that only show up under a real Testcontainers Postgres run, not at compile time. First, the
migration originally declared `year_month char(7)`, but the entity maps it as a plain `String`
field — Hibernate maps that to `varchar`, and `ddl-auto=validate` failed application startup with
a `SchemaManagementException` at the *next* test class after this one, not this one, which took
a moment to trace back. Fixed by changing the column to `varchar(7)`. Second,
`incrementUsage_existingRow_incrementsInPlace` initially asserted 4+1+1=6 but read back 4: the
native `@Modifying` query bypasses Hibernate's persistence context entirely, so a
`findByUserIdAndYearMonth` call in the same transaction was returning the stale first-level-cached
entity from before the native update ran. Fixed with `@Modifying(clearAutomatically = true)`.

Test coverage: `AiUsageCounterRepositoryTest` (6 cases — round trip, no-row-yet, the
`(user_id, year_month)` unique constraint, same user across two different months, and the
upsert's both branches, insert and conflict-update); `AiUsageCounterServiceImplTest` (3 cases,
plain Mockito); two new `EntitlementServiceImplTest` cases proving `aiCreditsRemaining` actually
subtracts real usage and clamps at 0 rather than going negative. `BillingProperties` was
unaffected (no new config field this prompt), but `EntitlementServiceImpl`'s constructor gained
the new `AiUsageCounterService` dependency, so its one direct instantiation
(`EntitlementServiceImplTest`) needed updating — existing FREE-tier assertions kept passing
unmodified since an unstubbed mock's `usedThisMonth` returns 0 by default, which is exactly the
"no usage yet" case those tests were already implicitly asserting. Full `mvn verify` (949 tests)
and `check-schema-ownership.sh` both clean.

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
