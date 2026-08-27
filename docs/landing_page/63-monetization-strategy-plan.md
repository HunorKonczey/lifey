# 63 – Monetization Strategy

Status: proposed
Scope: product · backend · mobile · web · design — umbrella doc for `docs/landing_page/`
Depends on: `docs/personal_trainer/01-koncepcio-es-folyamatok.md` (`ROLE_TRAINER`, trainer↔client
relationships), `docs/personal_trainer/03-backend-terv.md` (`/api/v1/trainer/**` authorization),
`docs/23-ai-calorie-estimation-plan.md` (the AI features this plan puts behind Pro),
`docs/15-delta-sync.md` (entitlements deliberately stay *outside* the sync feed — D-M11)

This is the business layer the rest of `docs/landing_page/` implements. Read it before
`64` (billing backend), `65`–`66` (web) and `67` (mobile); they cite decisions from here
by id (`D-M*`).

---

## 1. What we're building

1. **Trainers pay, clients don't.** The revenue product is the trainer workspace
   (`/admin`): client management, program builder, scheduling, calendar, chat,
   nutrition goals, weekly reports. A trainer subscribes on the **web**, with a card,
   through Stripe. A client keeps using the mobile app for free, exactly as today.
2. **A second, much smaller product: mobile Pro.** The individual (non-coached) user
   gets the app free with ads and a bounded history window; Pro removes the ads,
   unlocks the full history and the AI features. Bought **in-app** through the App
   Store / Play Store.
3. **A client of a paying trainer gets Pro for free** for as long as the relationship
   is active (D-M4). This is the single strongest line on the trainer pricing page,
   and it is what keeps a coached client from ever seeing an ad.
4. **A public marketing surface** that did not exist before: the web app currently
   redirects `/` straight to `/dashboard` (`web/src/app/page.tsx`). After this work `/`
   is a bilingual landing page whose job is to convert a trainer into a 14-day trial
   (`65`, `68`).
5. **With the feature off** — i.e. before any of this ships, and for anyone whose
   entitlement lookup fails — the app behaves exactly as it does today: everything
   unlocked, no ads, no paywall. Failure is always *open*, never *closed* (D-M9).

---

## 2. Key design decisions

### D-M1 Two payment rails, one entitlement model: Stripe on the web, native IAP on mobile

Trainer subscriptions go through **Stripe Checkout + Billing** on the web; mobile Pro
goes through **StoreKit 2 / Google Play Billing** via the `in_app_purchase` Flutter
package. Both write into one server-side `subscription` table and are read back through
one endpoint, `GET /api/v1/me/entitlements` (`64` §3).

*Rejected: Stripe everywhere.* Apple App Review Guideline 3.1.1 and Play's Payments
policy require IAP for digital content consumed in the app, and forbid even *linking* to
an external purchase flow for it. Selling mobile Pro on the web only would be compliant
but would cost most of the mobile conversion.

*Rejected: RevenueCat for both.* It would save the receipt-validation and store-webhook
work in `64` §5–6, but the trainer side needs Stripe Billing proper — proration on a
seat-tier change, EU VAT via Stripe Tax, coupons, the customer portal. Paying for two
billing systems to avoid one adapter is the worse trade. RevenueCat stays a documented
fallback if store-notification handling turns out to be more maintenance than expected.

*Why the trainer side is web-only:* trainers never buy inside the Flutter app. There is
no trainer purchase UI on mobile at all (`docs/personal_trainer/05-mobil-terv.md` limits
mobile to the invite card and received content), so no store rule is engaged and the
15–30 % store commission never applies to the main revenue line.

### D-M2 Trainer pricing is tiered by **active client count**, not by feature

| Tier | Active clients | Monthly | Yearly (2 months free) |
|---|---|---|---|
| **Trial** | up to 25 | free, 14 days, no card | — |
| **Starter** | 5 | 4 990 Ft / €12.90 | 49 900 Ft / €129 |
| **Pro** | 25 | 12 990 Ft / €32.90 | 129 900 Ft / €329 |
| **Studio** | unlimited¹ | 24 990 Ft / €64.90 | 249 900 Ft / €649 |

¹ Fair-use ceiling of 100 active clients, handled as a support conversation, not as code.

Every tier has **every feature**. The price scales with the trainer's own revenue, the
limit is a single number that is trivially checkable (`TrainerClient` rows with
`status = ACTIVE`), and the upsell moment is a natural one — the trainer is growing.

*Rejected: feature-gated tiers.* A trainer with 40 clients would pay the same as one with
three, and every new trainer feature would then need a "which tier is this in?" decision
forever. Gating the program builder or the weekly report would also make the cheap tier a
bad product, which is the opposite of what an entry tier is for.

*Rejected: base fee + per-seat.* Best revenue scaling, worst everything else: proration
maths on every invite accept/revoke, an invoice that changes every month, and a pricing
page that needs a calculator. Revisit only if tier boundaries visibly cost money.

*Rejected: one unlimited plan.* Prices out the trainer with two clients — who is exactly
the person most likely to try an unknown Hungarian product first.

### D-M3 14-day full trial, no card

A trainer gets Pro-tier access (25 clients) for 14 days from the moment `ROLE_TRAINER` is
granted, with no payment method. At expiry the workspace goes **restricted**, never dark:

- Blocked: sending invites, assigning content, creating/editing programs, scheduling.
- Allowed: viewing every client, every chart, every past assignment; chat stays readable
  and writable (D-M8).

*Rejected: card-gated trial.* Converts better per trial but cuts trial starts by roughly
two thirds; for a product with no brand yet, the top of the funnel is the scarce thing.

*Rejected: a permanent free tier for trainers.* A trainer with one client would never pay
while still costing support, storage and push volume — and a "1 free client" tier is the
tier most likely to be gamed with a second account.

### D-M4 A paying trainer's active clients get mobile Pro, sponsored

While `trainer_client.status = ACTIVE` and that trainer has a live paid subscription, the
client's entitlement resolves to Pro with `source = TRAINER_SPONSORED`. No ads, full
history, AI included.

This does three things at once: it makes the trainer plan measurably more valuable
("your clients get the ad-free app, on you"), it removes the absurdity of showing a
banner ad inside a session a coach prescribed, and it gives the client a concrete reason
to accept the invite in the first place.

When the relationship ends or the trainer's subscription lapses, the client falls back to
whatever they hold themselves — free, or their own paid Pro — after a **7-day grace
window** (D-M10). Their data is untouched; only the ad-free flag and the history window
change.

*Rejected: sponsorship as a paid add-on for the trainer.* A second price axis on the
pricing page, for something that should read as included.

### D-M5 Mobile free/Pro split: ads + history window + AI

| | Free | Pro |
|---|---|---|
| Nutrition, workouts, cardio, weight, water, steps | full | full |
| Watch app, widgets, Apple Health / Health Connect | full | full |
| Multi-week programs, PRs, rest timer, GPS routes | full | full |
| Statistics & history depth | last **30 days** | unlimited |
| AI calorie estimation from photo, AI recipes (`docs/23`) | **3 / month** | unlimited² |
| Ads | banner + occasional interstitial | none |

² Fair-use ceiling of 100/month, since each call has a real LLM cost.

Everything that makes the app *work* stays free. The two things behind Pro are the one
with an actual marginal cost (LLM calls) and the one with an actual perceived cost (ads),
plus a history window that only a long-term user notices — by which point they are
attached.

*Rejected: gating training features (programs, PRs, GPS) behind Pro.* A large share of
free users are a paying trainer's clients; a crippled free app makes the trainer's product
worse and directly undermines D-M4.

*Rejected: gating the watch app and integrations.* Those are the screenshots that sell the
store listing. Locking them costs more installs than the Pro upgrades they would buy.

### D-M6 Mobile Pro pricing

| Product | Price | Store product id |
|---|---|---|
| Monthly | 1 490 Ft / €3.99 | `lifey.pro.monthly` |
| Yearly | 11 900 Ft / €29.99 | `lifey.pro.yearly` |

Yearly is the default selection on the paywall (~34 % cheaper per month, and it is what
makes trading away the ad revenue worthwhile). No lifetime tier — see Non-goals.

### D-M7 Ads: AdMob, banners plus a rate-limited interstitial, never during training

Placements (`67` §5, `69` §4):

- **Banner** — anchored adaptive banner at the bottom of the **four tab roots** (dashboard,
  nutrition, workouts, statistics) and nowhere else — no detail screens, no modals, no sheets.
  Never overlapping a FAB or a sticky action bar. The exact placement against the *floating*
  bottom nav is settled in `69` §11.2 DV-10 and §12.5.
- **Interstitial** — after a *completed* meal log or a *saved* workout session, at most
  **1 per 4 hours** and never twice in one app session.
- **Never**: during an active workout or cardio session, on any watch surface, during
  onboarding, on any screen opened from a push notification, on any error state.

Consent through the **Google UMP SDK** (GDPR/TCF in the EU, ATT on iOS). Consent refused,
or user age < 16 derived from `user_details` → **non-personalized ads** plus
`tagForUnderAgeOfConsent`; never "no ads" (that is what Pro is for) and never a consent
wall that blocks the app.

*Rejected: rewarded video for AI credits.* Attractive revenue, but it turns the AI feature
into a slot machine and doubles the ad integration work for the least-used surface.
Recorded as a possible follow-up, not in scope.

*Rejected: banner-only.* Roughly a third of the ARPU and, more importantly, a much weaker
reason to ever open the paywall.

### D-M8 Chat is never paywalled in either direction

An expired trial, a lapsed trainer subscription and an over-limit workspace all keep chat
readable and writable for existing relationships. A client mid-conversation with their
coach must never hit a wall because the coach's card expired. The block is on *acquiring*
(invites, assignments, scheduling), not on *communicating*.

### D-M9 Entitlements fail open

Every gate reads a cached entitlement snapshot. If the lookup fails — offline, 5xx, token
refresh in flight, store receipt unverifiable — the client behaves as **entitled**: no
ads, no locks. A paying user must never be punished for our outage, and a free user
briefly getting Pro costs nothing measurable.

*Rejected: fail closed.* Would show ads to paying customers on every flaky connection —
the fastest known way to generate refund requests. The abuse vector (permanent airplane
mode) is bounded by D-M10.

### D-M10 Offline grace: 7 days on the cached snapshot

The snapshot carries `checkedAt` and `graceUntil = checkedAt + 7d`. Past `graceUntil` with
no successful refresh, a *sponsored or paid* entitlement decays to free — an intentional
bound on D-M9, sized so a two-week holiday without signal is still covered by the first
launch back online, but an indefinitely offline device is not free Pro forever. Trial
expiry is computed from `trialEndsAt`, not from grace, so it cannot be extended by going
offline.

### D-M11 Entitlements are **not** part of the delta-sync feed

`GET /api/v1/me/entitlements` is a plain, small, cache-headered endpoint polled on app
start / foreground / after a purchase, and written into a single-row Drift table. It is
deliberately outside the cursor-based sync feed (`docs/15-delta-sync.md`) because it is
not user-owned business data, and because it changes from *server-side* events (a Stripe
webhook, a trainer's card failing) that bump no `updated_at` on any row the user owns. A
sync bug that silently stopped delivering it would be a billing incident, not a stale list.

### D-M12 Downgrading over the seat limit is soft, and the trainer chooses

A Studio→Starter downgrade with 12 active clients does **not** auto-archive seven of them.
The workspace enters `OVER_LIMIT`: a persistent banner, new invites and new assignments
blocked, everything existing untouched and fully functional, until the trainer archives
clients down to the limit themselves.

*Rejected: auto-archiving the N most recent / least active.* An automated action on
someone's paying customers, based on a heuristic we invented, that is indistinguishable
from data loss. Never worth the support cost.

---

## 3. Entitlement resolution order

Resolved server-side, first match wins:

1. `ROLE_SUPER_ADMIN` or an internal comp flag → `PRO`, source `COMP`.
2. Own active paid subscription (`APP_STORE` / `PLAY_STORE` / `STRIPE`) → `PRO`.
3. Active `TrainerClient` whose trainer holds `ACTIVE` or `TRIALING` billing → `PRO`,
   source `TRAINER_SPONSORED`.
4. Own trainer trial still in date (trainers only) → `PRO`, source `TRAINER_TRIAL`.
5. Otherwise → `FREE`.

The response is one object, versioned, and never a list of feature booleans the client has
to interpret:

```json
{
  "tier": "PRO",
  "source": "TRAINER_SPONSORED",
  "adsEnabled": false,
  "historyDays": null,
  "aiCreditsRemaining": null,
  "trainer": { "plan": "PRO", "status": "ACTIVE", "maxClients": 25, "activeClients": 11 },
  "expiresAt": "2026-09-24T00:00:00Z",
  "checkedAt": "2026-08-25T09:14:00Z",
  "graceUntil": "2026-09-01T09:14:00Z"
}
```

`historyDays: null` and `aiCreditsRemaining: null` mean unlimited. The client renders from
these fields; it never re-derives policy from `tier` + `source`, so changing a limit is a
server deploy, not an app release (`64` §3.3).

---

## 4. The funnel this is built for

**Trainer (the one that matters).**
`landing / for-trainers` → `pricing` → `register` (trainer request) → super admin grants
`ROLE_TRAINER` → 14-day trial starts → invite first client → *aha moment: the first client
accepts and their data appears* → day 10 in-app reminder → day 14 upgrade.

The aha moment is the first accepted invite, which means both the trial clock and the
onboarding checklist in `/admin` have to push toward it (`66` §4). A trial that ends with
zero accepted invites converts at approximately zero, so that number is worth measuring
above all others.

**Client.** Invite email → `download` page → store → install → accept invite →
sponsored Pro, silently. The client is never sold anything, ever. No QR anywhere in this
path — an invite is bound to an e-mail address, not a scannable token (`69` §6.3, DV-4).

**Individual user.** Store search / landing `app` page → install → free with ads → history
window or AI limit hit → paywall.

Instrumentation (`65` §7) must be able to answer: trials started, trials with ≥ 1 accepted
invite, trial→paid rate, seat-limit hits, and — on mobile — paywall impressions by trigger.

---

## 5. Legal and tax (Hungary / EU)

Not optional, and each one blocks either a store release or a Stripe account review:

- **ÁSZF** (terms) and **Adatkezelési tájékoztató** (privacy) as real pages under
  `/[locale]/jogi/...`, linked from the footer, the register form, both paywalls and both
  store listings (`65` §5).
- **Cookies/consent**: the marketing pages get a consent banner only if analytics beyond
  Vercel's cookieless Analytics is added. Staying cookieless is a deliberate choice to
  avoid a consent banner sitting on top of the landing page (`65` §7).
- **Right of withdrawal**: the 14-day EU withdrawal right for digital services, with the
  standard "I request immediate performance and waive my withdrawal right" checkbox at
  Stripe Checkout, **and** a standalone "Elállási tájékoztató" page
  (`/legal/withdrawal` — the checkbox alone is not sufficient under Korm. rendelet 45/2014;
  the page must exist and be linkable, which it now is, footer-linked from `65` Prompt 3).
  Store purchases are governed by Apple/Google's own refund flows — support must never
  promise a refund it cannot issue.
- **Impresszum**: a company-details page (`/legal/imprint`) — name, registration number,
  registered address, contact — required for any commercial website operating in Hungary.
  Easy to forget because it has no billing-flow trigger the way the others do; already
  footer-linked (`65` Prompt 3), the page content itself is still `65` Prompt 8 scope.
- **VAT**: Stripe Tax for EU B2C/B2B VAT and reverse charge; the trainer's tax number is
  collected at Checkout. Hungarian e-invoicing (Számlázz.hu / Billingo + NAV) is a
  documented follow-up, not in the first release — Stripe's invoice is enough to transact,
  not enough to be NAV-compliant, and that gap must be stated out loud to the first paying
  trainers rather than discovered by their accountant.
- **AdMob**: the privacy policy must disclose ad-SDK data collection; iOS needs
  `NSUserTrackingUsageDescription` and correct App Privacy answers; Play needs the Data
  Safety form and an ads declaration. Getting these wrong is a rejected release, not a bug.

---

## 6. Non-goals (deferred)

- Lifetime / one-off mobile purchase — unbounded LLM liability against a fixed price.
- Rewarded ads, offerwalls, any ad format beyond banner + interstitial.
- An in-app trainer purchase — there is no trainer UI on mobile.
- Trainer→client billing: Lifey does not process the money between a coach and their
  client. Large, regulated, and a different product.
- Team/gym accounts, several trainers on one workspace, white-label branding.
- Referral / affiliate program; coupons beyond Stripe's built-in promotion codes.
- Regional (PPP) pricing beyond the HUF/EUR pair.
- NAV-compliant e-invoicing (see §5).
- Self-service "become a trainer" — role granting stays a super-admin action
  (`docs/personal_trainer/README.md` §2). The landing page's trainer CTA therefore leads
  to a *request*, and `66` §2 has to make that wait legible instead of pretending it is
  instant.
- A/B testing infrastructure for the landing page.

---

## 7. Edge cases

1. **A trainer who is also someone's client.** Both hold; §3 gives their own paid/trial
   state precedence, and the sponsorship is irrelevant since they already have Pro.
2. **Client of two trainers, one paying, one lapsed.** Any single active sponsor is enough.
3. **Client buys Pro while sponsored.** Allowed but wasteful — the paywall must not be
   *reachable* while sponsored (ad-free means no trigger fires), and if reached by deep
   link it says "your trainer already covers this" instead of offering a purchase.
4. **The client's own Pro expires while sponsored.** No visible change. Nothing may
   announce a downgrade that did not happen.
5. **Trainer's card fails.** Stripe `past_due` → keep full access through the dunning
   window (Smart Retries, ~2 weeks) with an in-app banner; only `canceled` / `unpaid`
   flips to restricted. Sponsored clients follow the trainer's state, so they keep Pro
   through dunning too.
6. **An invite accepted the same minute the trainer downgrades.** The seat check is at
   accept time and transactional (`64` §4.3); losing the race fails the accept with a
   clear message to the client and a notification to the trainer, rather than silently
   creating a 13th seat.
7. **One store account, two Lifey users.** A store subscription binds to the first
   `userId` that redeems it; a second redemption returns `409 SUBSCRIPTION_ALREADY_LINKED`
   rather than silently moving the entitlement.
8. **Refund / chargeback.** Store refund notifications and Stripe `charge.refunded` revoke
   the entitlement on the next resolve; nothing is deleted.
9. **Account deletion with a live subscription.** The Stripe subscription is cancelled as
   part of deletion; store subscriptions cannot be cancelled by us, so the deletion flow
   must *tell* the user to cancel in the store, somewhere they will actually read it.
10. **Clock skew / device time.** All expiry maths is server-side; `expiresAt` is compared
    against the server time carried in the snapshot, never against `DateTime.now()` alone.
11. **Ads and the watch.** A phone showing a banner must never push an ad-related state to
    the watch or a home-screen widget; the ad layer lives strictly in the phone UI tree.
12. **Locale/currency mismatch.** A Hungarian trainer paying in EUR because their browser
    is set to English is a support ticket. Currency follows the billing country chosen at
    Checkout, not the UI locale, and the pricing page says so.

---

## 8. Risk checkpoints where a failure would be silent

The places where a bug produces a *wrong number* or a *wrong permission* rather than an
error. These are what a reviewer should stare at:

1. **`activeClients` drifting from reality.** If the count query and the enforcement query
   disagree (soft-deleted rows, `EXPIRED` vs `REVOKED`, the sweep in
   `TrainerClientCleanupJob`), a trainer either silently exceeds their tier or is blocked
   at 4 of 5 seats with no error anywhere. One shared repository method used by both the
   check and the display, plus a test that walks a relationship through every status.
2. **A sponsored entitlement surviving the end of the relationship.** The client keeps
   ad-free Pro forever and nothing errors. Needs an explicit revoke → grace → free test.
3. **A webhook processed twice, or never.** Stripe and store notifications are
   at-least-once. A missed `customer.subscription.deleted` leaves a cancelled trainer fully
   entitled with no trace; a double-processed one can double-extend `expiresAt`.
   Idempotency on the event id *and* a daily reconciliation job (`64` §7) — both, not
   either.
4. **Grace computed client-side from device time.** Becomes "free Pro forever" for anyone
   who moves their clock. `graceUntil` comes from the server, always.
5. **The gate that was never wired.** A screen added later reads no entitlement at all and
   is free by accident. The gates live in one place (`67` §3) and a widget test asserts the
   list of gated surfaces, so adding one is a deliberate edit.
6. **Ads rendering for a Pro user for a few frames** on cold start, before the snapshot
   loads. The ad widget starts hidden and appears only on a *resolved* free snapshot — the
   default is "no ad", not "ad until told otherwise".
7. **The history window applied to sync instead of to display.** If the 30-day limit were
   implemented by not *fetching* older rows, upgrading to Pro would appear to lose data and
   a re-install would delete it. The window is a **presentation** filter over fully synced
   data (`67` §3.4) — worth repeating in the code comment.
8. **The interstitial rate limit stored in memory only.** Resets on every cold start and
   silently becomes "an ad every time you open the app". It belongs in `shared_preferences`
   with a monotonic timestamp check.
9. **Marketing pages pulling the app bundle.** No error, just a landing page that scores 40
   on mobile Lighthouse and loses the traffic it was built for. Guarded by a bundle-size
   assertion in CI (`65` §8).
10. **Trial start silently not happening.** If `trialEndsAt` is set on registration rather
    than on the `ROLE_TRAINER` grant, a trainer waiting three days for approval loses three
    days of trial and simply feels the product is stingy. Trial starts at grant (`64` §4.1).

---

## 9. Order of work

Milestones are demoable slices, not layers. **M1 is the smallest thing worth shipping** —
it is a complete, working revenue product; everything after it is optimization.

| Milestone | What you can demo | Docs |
|---|---|---|
| **M0 — Marketing surface** | A bilingual public landing page at `/` with a pricing page that leads to registration. No billing yet; the pricing CTA starts a trainer request. | `65`, `68`, `70` |
| **M1 — Trainer billing** | A trainer registers, gets 14 days, hits the paywall, pays by card, and the seat limit is enforced. Revenue exists. | `64` §3–4, `66` |
| **M2 — Entitlements on mobile** | The client app reads its entitlement, sponsored Pro works end to end, the 30-day history window and the AI credit counter are live. Still no ads, still no purchases. | `64` §3, `67` §2–3 |
| **M3 — Mobile Pro purchase** | Paywall, StoreKit/Play purchase, restore, receipt verification, the Settings subscription tile. | `64` §5–6, `67` §4, `69` |
| **M4 — Ads** | UMP consent, banners, the rate-limited interstitial, ad-free on every Pro path. | `67` §5, `69` §4 |
| **M5 — Store & polish** | Store listings, ASO assets, the download page with deferred deep links, dunning emails, the reconciliation job. | `65` §6, `69` §5–6, `64` §7 |

M2 before M3 on purpose: sponsored Pro is the entitlement path with the most edge cases and
no store dependency, so it is the one that should prove the model first. Shipping a purchase
flow on top of an unproven entitlement resolver is how you find out about §8.2 from a
customer.

The per-surface, prompt-sized steps live in the individual docs — `64` §9, `65` §9, `66` §7,
`67` §8.

---

## 10. Test plan (strategy level; per-layer detail in `64`–`67`)

- **Entitlement resolution** — a table-driven backend test over every combination in §3
  plus the edge cases in §7. The single highest-value test in the whole feature.
- **Seat enforcement** — integration tests for invite-send, invite-accept and the
  downgrade→`OVER_LIMIT` transition, including the concurrent-accept race (§7.6).
- **Webhook idempotency** — replay the same Stripe/store event twice, assert one state
  change; drop an event, assert the reconciliation job repairs it.
- **Client gating** — Flutter widget tests asserting no ad widget and no lock for each Pro
  source, and a layout test proving the free-tier banner does not overlap the bottom
  navigation.
- **Fail-open** — a test that a 500 and a timeout from `/me/entitlements` both leave the app
  fully unlocked.
- **Landing page** — Playwright smoke on both locales for the CTA paths, plus a Lighthouse
  budget check in CI.

---

## 11. Suggested PR split

`63` is documentation only. The implementation split is per doc; the cross-cutting rule is
that **no PR may both change the entitlement resolver and add a gate that reads it** —
resolver changes land alone, with tests, so a wrong resolution is never hidden inside a UI
diff.

---

## 12. After implementation

- Set `Status:` here and in each doc as milestones land.
- Update `docs/README.md` (topic-folder table) and `docs/07-roadmap.md` with the
  monetization milestone.
- Update `docs/personal_trainer/README.md` §"A legfontosabb döntések" with the subscription
  gate — the trainer module's behaviour changes materially at M1.
- `docs/web/01-feature-inventory.md` gains the marketing surface.
- Follow-ups explicitly deferred here: NAV e-invoicing, rewarded ads, referral program,
  regional pricing, landing-page A/B testing.
