# 81 – Billing Reconciliation Runbook

Status: reference — the operational procedure for `BillingReconciliationJob`, not a plan
Scope: backend · operations
Depends on: `64` §7 and Prompts 7 + 11 (the job), `73` (the verification passes this one complements)

`64` §15 asks for a runbook for correcting what the nightly reconciliation finds; `72` B5 recorded that
it did not exist. `73` covers *verifying* billing against real provider accounts once; this covers
*operating* the daily job afterwards: what it does, how to tell it is healthy, and what to do when it
is not.

Code: `backend/src/main/java/com/lifey/billing/service/BillingReconciliationJob.java`.

---

## 1. What the job does, exactly

Runs daily at **03:30 Europe/Budapest** (`lifey.jobs.billing-reconciliation.cron`, env
`JOB_BILLING_RECONCILIATION_CRON`, default `0 30 3 * * *`). Two steps, in this order:

1. **Provider re-fetch and correct.** Takes up to `lifey.billing.reconciliation-batch-size` (env
   `BILLING_RECONCILIATION_BATCH_SIZE`, default **200**) subscriptions that are `TRIALING`, `ACTIVE` or
   `PAST_DUE` and have a provider subscription id, ordered by local `id`. For each, it asks the provider
   for the current status and, if that differs from the local row, **overwrites the local status**
   (`SubscriptionWriter.markStatus`).
   - Stripe: `Subscription.retrieve`. `trialing`/`active`/`past_due` map straight across;
     `canceled`/`unpaid`/`incomplete_expired` → `CANCELED`; anything else → no change.
   - App Store: `getAllSubscriptionStatuses`. `ACTIVE` and `BILLING_GRACE_PERIOD` → `ACTIVE`,
     `BILLING_RETRY` → `PAST_DUE`, `EXPIRED` → `EXPIRED`, `REVOKED` → `CANCELED`.
   - Google Play: `SubscriptionPurchaseV2.subscriptionState`. `ACTIVE`/`IN_GRACE_PERIOD` → `ACTIVE`,
     `ON_HOLD`/`PAUSED` → `PAST_DUE`, `CANCELED` → `CANCELED`, everything else → `EXPIRED`.
   - `COMP` (admin grants) is skipped: there is no vendor to check against.
2. **Trial expiry.** Every `TRIALING` row whose `trialEndsAt` is in the past becomes `EXPIRED`.

What it deliberately does **not** do: it only touches `status` — never the period end, the plan or the seat
count; it never creates or deletes a subscription; it never refunds (`REVOKED` maps to `CANCELED`, not
`REFUNDED`). Rows already `CANCELED`/`EXPIRED`/`REFUNDED` are never looked at again.

A failure on one row (rate limit, outage, missing credential) is logged and that row is retried on the
next night's run; it never aborts the sweep and never changes the local row. Each correction commits on
its own — there is no run-wide transaction.

## 2. Is it healthy? — the three signals

| Signal | Where | Healthy |
|---|---|---|
| `billing.reconciliation.rows_checked{provider}` | `GET /actuator/metrics/billing.reconciliation.rows_checked?tag=provider:STRIPE` (and `APP_STORE`, `PLAY_STORE`) — **ROLE_SUPER_ADMIN only**, there is no scraper | Grows by roughly the number of live subscriptions of that provider per day |
| `billing.reconciliation.rows_corrected{provider}` | same, `…rows_corrected…` | **Flat, or a handful a week.** See §3 |
| Log lines | search for `Billing reconciliation:` | `…correcting` lines are rare; `could not re-fetch … skipping this run` lines are occasional, not every row |

The counters are Micrometer counters held in memory: they **reset on every deploy/restart**, so read them
as "since the last restart", and compare two readings a day apart rather than trusting one number. A
provider with no candidates in a run does not emit a point for that run.

## 3. Reading `rows_corrected`

Every correction is a webhook delivery that never arrived or was processed wrongly (`64` §7 point 2). One
now and then is the safety net doing its job — webhooks are at-least-once and can be late or lost.

- **Zero for weeks on a provider with real subscriptions:** fine, or the sweep is not reaching that
  provider — check `rows_checked` for it. Checked but never corrected means the webhook is working.
- **A few a week:** expected. Read the `…correcting` log line: it names the provider, the provider
  subscription id, the local status and the provider's. A pattern in the *direction* tells you what broke
  (always `ACTIVE`→`EXPIRED` on Play suggests the RTDN notifications are lost; always `PAST_DUE`→`ACTIVE`
  on Stripe suggests `invoice.paid` is lost).
- **The same provider corrected every night:** that provider's webhook is broken, not late. Go to §5.
- **A burst on one night:** usually an outage on our side (webhooks returned 5xx) or the provider's.
  Confirm in the provider dashboard that delivery failures cluster on that day, then nothing more to do —
  the job already repaired it.

## 4. When the job does not run, or you need it now

There is **no manual trigger endpoint** (the job class is package-private and `@Scheduled` only), so:

- **Did it run?** Look for `Expired N stale trainer trial(s)` (only logged when N > 0) or any
  `Billing reconciliation:` line around 03:30 Budapest; with neither, check `rows_checked` moved. If the
  instance was asleep or redeploying at 03:30 the run was skipped — the next night's run covers it, nothing
  is lost, because every run re-reads provider truth from scratch.
- **Run it now:** set `JOB_BILLING_RECONCILIATION_CRON` to a time a couple of minutes ahead (a Spring
  six-field cron, e.g. `0 15 14 * * *`), redeploy/restart, wait for the lines above, then **set it back**
  and restart again. Remember the counters reset with each restart.
- **Backlog larger than the batch:** more than `reconciliation-batch-size` live subscriptions means the
  tail beyond row 200 (by `id`) is never reached. Raise `BILLING_RECONCILIATION_BATCH_SIZE`; each row costs
  one outbound call, and the job runs without holding a DB transaction, so a few hundred more is cheap. A
  real fix (paging across runs) is not built — it matters only past a few hundred subscriptions.

## 5. A provider is corrected every night — fixing the webhook

In order of likelihood:

1. **Stripe** — dashboard → Developers → Webhooks → the endpoint → recent deliveries. Failing deliveries
   with 400 mean the signing secret in `STRIPE_WEBHOOK_SECRET` no longer matches the endpoint (it is
   per-endpoint, and re-created endpoints get a new one). 5xx means our side; read the backend log at that
   timestamp. Fix the secret/endpoint, then use **Resend** on the failed events, or simply wait one night:
   the sweep re-syncs the status anyway.
2. **App Store** — App Store Connect → the app → App Information → App Store Server Notifications: the
   production URL must be set (a sandbox URL set only for sandbox). The reconciliation uses
   `appleProperties.environment()`; a production app with the environment set to sandbox will find
   nothing and `rows_checked` will look healthy while correcting nothing — check that property first when
   corrections are *zero* and store users complain.
3. **Google Play** — Play Console → Monetization setup → Real-time developer notifications: the Pub/Sub
   topic and our push subscription must exist, and the service account must be allowed to publish to it.

After fixing the cause, the next night's `rows_corrected` for that provider should drop to ~0. If it does
not, the cause was something else — go back to the first log line of the next run.

## 6. Correcting one subscription by hand

The job fixes drift from the provider; it cannot fix a disagreement the provider itself is wrong about, or
a user who paid outside the app. Do not edit `subscriptions` with SQL: every write is meant to go through
`SubscriptionWriter`, which is also what keeps the log trail (`Subscription … status X -> Y`) that this
runbook relies on.

- **Grant access:** a `COMP`-provider subscription row (the admin comp grant of `64`) entitles the user
  (`EntitlementServiceImpl`), and `ROLE_SUPER_ADMIN` is always Pro. The job skips `COMP` rows, so a comp
  grant is never "corrected" away.
- **Revoke or fix a status:** do it in the provider (cancel or refund there). The webhook, or the next
  night's sweep, brings the local row in line; if it must be immediate, trigger a run as in §4 after
  the provider change.

## 7. Known limits

- Status only: a period-end or plan drift is **not** repaired by this job.
- Apple `REVOKED` and Play `CANCELED` both end up `CANCELED`; a refund is only recorded as `REFUNDED` when
  Stripe's `charge.refunded` webhook says so.
- Counters are in-memory and per-instance; with more than one backend instance each keeps its own, and
  every instance would run the 03:30 sweep (the job has no leader election or lock, e.g. no ShedLock), so
  a multi-instance deploy needs one added before it is safe.
