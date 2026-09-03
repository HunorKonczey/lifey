# 73 – Billing Verification Runbook

Status: reference — the procedure, not a plan; results are recorded in `72` §4 (F3)
Scope: backend · mobile — the two verification passes that need real provider accounts
Depends on: `64` (billing backend), `66` (trainer billing web), `67` (mobile free/Pro), `72` F3

Everything in `64`, `66` and `67` that a machine can check is checked: 989 backend tests, the
webhook path end to end against a real Postgres with real Stripe signature verification, and —
since `72` F3 — every Checkout and Portal call validated against Stripe's own API schema via
`stripe-mock` (`StripeBillingServiceStripeMockIntegrationTest`).

What no test in this repo can reach is the part that needs an account, a card and a phone: does
Stripe accept our *price ids*, does the hosted page render the withdrawal-waiver checkbox, does
a real sandbox purchase on each store come back and grant Pro. This document is that pass,
written so someone with the accounts can run it in one sitting instead of reconstructing it.

**Fill in the result columns as you go and paste them into `72` §4 under Prompts 12 and 13.**
An unrecorded pass is the same as no pass a month later.

---

## 1. Stripe test-mode round trip (`72` Prompt 12)

### 1.1 Prerequisites

| Thing | Where it comes from |
|---|---|
| Stripe account in **test mode** | dashboard.stripe.com, no live keys anywhere in this procedure |
| Six Prices | Created **in the dashboard**, never from code (`64` §5.1). 3 plans × monthly/yearly, HUF, amounts from `63` D-M2 / `web/src/lib/pricing.ts` |
| `stripe` CLI | For webhook forwarding — `stripe login`, then `stripe listen` |
| Local Postgres + backend | `docker compose up` for the DB, then the backend with the env below |
| A trainer account | Any user with `ROLE_TRAINER`; `/admin/pending` → approve is the real path (`66` Prompt 3) |

Environment (test keys only — everything here is empty by default in `application.yml`):

```bash
export BILLING_ENABLED=true
export STRIPE_SECRET_KEY=sk_test_...
export STRIPE_WEBHOOK_SECRET=whsec_...        # printed by `stripe listen`
export STRIPE_PRICE_STARTER_MONTHLY=price_...
export STRIPE_PRICE_STARTER_YEARLY=price_...
export STRIPE_PRICE_PRO_MONTHLY=price_...
export STRIPE_PRICE_PRO_YEARLY=price_...
export STRIPE_PRICE_STUDIO_MONTHLY=price_...
export STRIPE_PRICE_STUDIO_YEARLY=price_...
```

`BILLING_ENABLED=true` matters: with the default `false`, every user resolves an open
entitlement and every seat check passes (`64` §1), so the whole procedure would "pass" without
testing anything.

Forward webhooks in a second terminal — leave it running for the whole session:

```bash
stripe listen --forward-to localhost:8080/api/v1/webhooks/stripe
```

### 1.2 The checks

The SQL to hand for every step (the `subscription` row is the source of truth, not the UI):

```sql
select id, user_id, provider, status, plan, provider_subscription_id,
       provider_customer_id, trial_ends_at, current_period_end, cancel_at_period_end
from subscription where user_id = :trainerId;
```

**Expect an UPDATE, not an INSERT.** An approved trainer already has a `STRIPE` row in
`TRIALING` from the moment `ROLE_TRAINER` was granted (`SubscriptionWriter.startTrainerTrial`,
inside the same transaction as the grant), and `subscription` is unique on
`(user_id, provider)` — so a successful checkout *transitions that row* to `ACTIVE` and fills in
the provider ids. A second row appearing at any point in this procedure is itself the bug.

| # | Step | Expected | Result |
|---|---|---|---|
| S1 | Sign in as the trainer, open `/admin/billing`, click a plan's CTA | Redirect to a `checkout.stripe.com` URL — **this is what proves the price ids exist**; a bad id fails here and nowhere earlier | |
| S2 | On the hosted page, look for the consent checkbox | The withdrawal-waiver text from `StripeBillingServiceImpl.WITHDRAWAL_WAIVER_MESSAGE` renders as a **required checkbox**, not fine print (`63` §5). Screenshot it — this is the only place it can be seen | |
| S3 | Check the session's own params in the Stripe dashboard (Payments → the session) | `client_reference_id` = the trainer's user id; automatic tax on; promotion codes allowed | |
| S4 | Pay with `4242 4242 4242 4242`, any future expiry | Redirect back to `/admin/billing?checkout=success` | |
| S5 | Watch the `stripe listen` terminal, then the DB | `checkout.session.completed` → the **existing** trial row flips `TRIALING` → `ACTIVE`, the right `plan`, both provider ids populated, `current_period_end` set | |
| S6 | Reload `/admin/billing` | The page leaves its polling state and shows the active plan (`66` Prompt 6 gives up after 30 s and offers a refresh — if you see that, the webhook did not arrive) | |
| S7 | Replay the same event: `stripe events resend <evt_id>` | **No second row, no second state change** — `processed_billing_event` makes it idempotent (`64` Prompt 5) | |
| S8 | Click "Manage billing" → the Stripe portal | Portal opens for the same customer; return link comes back to `/admin/billing` | |
| S9 | In the portal, cancel the subscription | `customer.subscription.updated` → `cancel_at_period_end = true`, status still `ACTIVE` | |
| S10 | In the dashboard, force the period to end (or `stripe trigger customer.subscription.deleted`) | Status → `CANCELED`; entitlement drops; `/admin` shows the blocked-action UX (`66` Prompt 8) | |
| S11 | While `CANCELED`, try to send an invite | `409` + the seat-limit dialog; **chat and every read path still work** (`64` Prompt 6) | |
| S12 | Downgrade path: subscribe to Studio, add 6 clients, switch to Starter (5 seats) | Over-limit archiving flow appears (`66` Prompt 9); nothing is archived without an explicit click | |

### 1.3 What a failure here means

- **S1 fails** → the price ids in config are wrong or from the wrong mode. Nothing in this repo
  can catch that; it is the single most likely reason a first deploy breaks.
- **S2 missing** → `consent_collection` is not doing what `63` §5 needs, and the EU withdrawal
  waiver is not actually being collected. That is a legal defect, not a UI one.
- **S5 never arrives** → the webhook secret or the forwarding URL is wrong. Check the raw-body
  handling first (`StripeWebhookController` reads the raw body precisely because signature
  verification needs it).

---

## 2. Store sandbox matrix (`72` Prompt 13, `67` §11)

### 2.1 Prerequisites

| Thing | Notes |
|---|---|
| Apple sandbox tester + App Store Connect app record | `APPLE_BUNDLE_ID`, `APPLE_APP_APPLE_ID`; `APPLE_ENVIRONMENT=SANDBOX` is already the default |
| Play Console app + licence tester account | `GOOGLE_PLAY_PACKAGE_NAME` + `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` — **not optional**: Play verification fails closed without the service account (`64` §6.1) |
| Two products per store | `lifey.pro.monthly`, `lifey.pro.yearly` (`63` D-M6) |
| Two physical devices | One is not enough: R3 below is a second-device restore |
| Real AdMob ids | Only for A1–A2. Everything else works with the test ids — see `mobile/tool/check_release_ad_ids.dart` |

The app talks to `POST /api/v1/billing/store-purchase` with
`{platform, productId, purchaseToken}` and only calls the store's `completePurchase` **after**
that returns 200 (`67` D-P8) — so the backend log for that endpoint is the thing to watch
throughout.

### 2.2 The matrix

| # | Check | Expected | iOS | Android |
|---|---|---|---|---|
| P1 | Paywall opens from Settings, prices load | Real store prices, no fabricated amount before they arrive (`67` §4.1); skeleton cards while loading (`69` §12.8) | | |
| P2 | Buy monthly | 200 from `/store-purchase`; entitlement flips to Pro; ads disappear; history unlocks | | |
| P3 | Kill the app mid-purchase (airplane mode right after paying) | The transaction is **re-delivered** on next launch and verified then — nothing is lost, nothing double-charged (`67` D-P8) | | |
| P4 | Buy yearly on a fresh account | Same as P2, `plan`/period reflect the yearly product | | |
| R1 | Restore on the same device after reinstall | Pro returns with no second charge | | |
| R2 | Restore with no purchase to restore | A clear "nothing to restore" outcome, not a spinner | | |
| R3 | **Restore on a second device**, same store account | Pro on both; one `subscription` row, not two | | |
| C1 | UMP consent in an EU locale, free account | Google's own consent UI; personalized ads only after consent (`67` Prompt 8) | | |
| C2 | UMP for a **Pro** account | **No consent dialog at all** — asking a paying customer about ad personalization is `67` §13 risk 8 | | |
| G1 | Offline → grace: kill the network, move the device clock past `graceUntil` (7 days) | Pro decays to free *exactly* at expiry; the sponsorship-ended card appears once if the source was a trainer (`69` §12.1) | | |
| G2 | Come back online | Entitlement refreshes; if still paid, Pro returns with no user action | | |
| A1 | Free account, four tab roots | Banner with the "Reklám" label above the creative, remove-ads button in the same row, never over the ad (`72` D-F3) | | |
| A2 | Pro/sponsored account | No slot at all — zero height, no hairline (`69` P17) | | |
| A3 | Interstitial after a logged meal/workout | At most one per session, ≥ 4 h apart, never during an active session (`67` §5.3) | | |
| X1 | Play only: purchase acknowledged within 3 days | Acknowledgement is server-side (`64` §6.1) — an unacknowledged purchase **auto-refunds silently**, which is `67` §13 risk 5 | — | |

### 2.3 The two that hide

R3 and X1 are the checks worth doing even when time is short. Both fail silently: a
second-device restore that quietly creates a second subscription row shows up as a support
ticket weeks later, and an unacknowledged Play purchase refunds itself after three days with no
error anywhere in the system.
