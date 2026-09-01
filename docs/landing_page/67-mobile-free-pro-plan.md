# 67 – Mobile Free / Pro

Status: done
Scope: mobile (Flutter) — entitlement client, feature gates, in-app purchase, ads, settings
Depends on: `docs/landing_page/63-monetization-strategy-plan.md` (D-M4–D-M10),
`docs/landing_page/64-billing-backend-plan.md` (`/me/entitlements`, `/billing/store-purchase`),
`docs/10-offline-frontend.md` (offline-first stack), `docs/15-delta-sync.md` (why this is
*not* in the sync feed — D-M11), `docs/landing_page/69-mobile-paywall-design-plan.md` (visual
spec), `docs/13-localization-guide.md` + the `localization` skill (every string below is ARB)

---

## 1. What we're building

1. An **entitlement layer** in `core/`: fetch, cache in Drift, expose through Riverpod, with
   a 7-day offline grace window (D-M10) and fail-open semantics (D-M9).
2. **Three gates**, and only three: ads, the 30-day history window, and the monthly AI credit
   count (D-M5). Nothing else in the app is ever locked.
3. A **paywall** and its triggers, plus a subscription tile in Settings.
4. **StoreKit 2 / Play Billing purchase** through `in_app_purchase`, verified server-side.
5. **AdMob** banners and a rate-limited interstitial, behind Google UMP consent (D-M7).
6. **With the feature off** — `lifey.billing.enabled=false` on the server, or any failure at
   all — the app is exactly today's app: no ads, no locks, no paywall. That is the default
   state of every code path here.

---

## 2. The entitlement layer

```
mobile/lib/core/entitlements/
├── entitlement.dart               domain model (mirrors 64 §3.2)
├── entitlement_repository.dart    fetch + cache + grace
├── entitlement_providers.dart     Riverpod: entitlementProvider, isProProvider,
│                                  adsEnabledProvider, historyCutoffProvider,
│                                  aiCreditsProvider
└── entitlement_refresher.dart     when to re-fetch
```

Plus one Drift table in `core/local_db/tables/` — `entitlement_cache`, **single row**,
holding the raw response fields, `checkedAt` and `graceUntil`.

### D-P1 Entitlement is `core/`, not a feature

Every feature reads it; it belongs beside `core/sync/` and `core/auth/`, not inside a
`features/billing/` that four other features would then import. The *purchase* flow is a
feature (`features/subscription/`, §4) — the *state* is core.

### D-P2 One Drift row, outside the sync engine

The cache is a plain single-row table written by the repository, never by `SyncEngine`, never
in the outbox. It is server-truth, not user data (D-M11). Reading it must work before the
first successful network call of the app's life — a fresh install offline resolves to the
fail-open default, not to free.

### D-P3 Refresh points, and only these

`EntitlementRefresher` fetches on: app start after auth, app resume when the cache is older
than 15 minutes, immediately after a successful purchase or restore, after accepting or
losing a trainer invite (that is a D-M4 transition), and on a `402`/`403` from any gated
endpoint. Never on a timer, never on every screen build.

*Rejected: piggy-backing on the sync cycle.* It would tie a billing-critical read to a
subsystem whose failure mode is "silently stale" (D-M11).

### D-P4 Grace and fail-open, precisely

```
if (cache == null)                       → OPEN (Pro-equivalent, no ads)
if (fetch succeeded)                     → use response
if (fetch failed && now < graceUntil)    → use cache
if (fetch failed && now >= graceUntil)   → FREE
```

`graceUntil` comes from the server (D-M10). The `now` used here is the device clock, but only
ever to compare against a **server-issued** timestamp, and the comparison is one-way: a device
clock set backwards extends grace (harmless), a device clock set forwards ends it early (and
the next successful fetch fixes it).

### D-P5 The client never derives policy

`isProProvider` exists for UI copy. Every actual gate reads the *field*: `adsEnabled`,
`historyDays`, `aiCreditsRemaining`. Changing the free history window is then a server config
change (`64` §3.3), not an app release — which matters, because an app release takes a week
of review and a month of adoption.

---

## 3. The gates

### 3.1 Ads — `adsEnabledProvider`

See §5. Default false until a `FREE` snapshot is *resolved* (63 §8.6).

### 3.2 History window — `historyCutoffProvider`

`historyDays == null` → `null` cutoff (everything). Otherwise
`cutoff = serverToday - historyDays`.

Applied in: `statistics_screen.dart` range selectors, the workout history list, the nutrition
day navigator, the weight/steps/water charts, and the cardio activity list.

### D-P6 The window is a presentation filter, never a sync or storage limit

Sync keeps pulling and storing everything (`docs/10-offline-frontend.md` is unchanged). The
UI hides rows older than the cutoff and, in their place, shows a single "See your full
history with Pro" row at the boundary. Upgrading is then instant and offline; downgrading
loses nothing.

Implementing this by not fetching would make an upgrade look like data recovery and a
re-install look like data loss (63 §8.7). This constraint is worth a comment at each call
site.

### 3.3 The range menu degrades, it does not shrink

**There is no chip row** — `_StatsRangeButton` in `statistics_screen.dart` is a
`PopupMenuButton` with a single trigger chip, and the four ranges live in its popup
(`shared/widgets/charts/stats_range.dart`): `7 nap / 30 nap / 90 nap / Összes`. At
`historyDays: 30` the last two rows are **locked** — `lock` glyph in the 20 px slot that
otherwise holds the selected row's check mark, label at 60 % opacity, still tappable, opening
the paywall with the `historyRange` trigger. The trigger chip itself never changes.

A menu with two rows removed teaches nothing; two locked rows are the upsell. See `69` §4.1 and
frame **P11** — and its defect, `69` DV-9.

### 3.4 AI credits — `aiCreditsProvider`

`aiCreditsRemaining` is shown as a small counter next to the AI actions in the nutrition
feature (`docs/23-ai-calorie-estimation-plan.md`). At zero, the action opens the paywall with
`trigger: aiCredits` instead of firing the request. A `402 AI_CREDITS_EXHAUSTED` from the
server (the authoritative check) does the same — the client counter is a courtesy, never the
enforcement.

### D-P7 Every gate lives in `core/entitlements` and is enumerated in a test

`gated_surfaces_test.dart` asserts the list of gated widgets/screens. Adding a gate means
editing that list; adding a screen that *should* be gated and is not shows up as a review
question rather than as free Pro forever (63 §8.5).

---

## 4. Purchase flow

```
mobile/lib/features/subscription/
├── application/subscription_controller.dart
├── data/purchase_repository.dart        in_app_purchase + POST /billing/store-purchase
├── domain/subscription_product.dart
└── presentation/
    ├── paywall_screen.dart
    ├── subscription_settings_tile.dart
    └── widgets/
```

### 4.1 Flow

1. Query products (`lifey.pro.monthly`, `lifey.pro.yearly`) from the store. If the query
   fails or returns nothing, the paywall shows a "temporarily unavailable" state — never
   fabricated prices.
2. Prices are rendered **from the store's localized strings**, never from a constant in the
   app. Store pricing is per-territory and changes without us.
3. `buyNonConsumable` → listen on `purchaseStream`.
4. On `purchased`/`restored`: send the platform token to `POST /api/v1/billing/store-purchase`
   (`64` §6.1), then `completePurchase` **only after the server responds 200**.
5. Refresh entitlements, show the success state, pop.

### D-P8 `completePurchase` after server verification, not before

Completing first and then failing verification loses the purchase with no way to recover
except "Restore". Completing after means a crash mid-flow leaves the transaction pending, and
the store re-delivers it on next launch — which is exactly the behaviour we want.

The one exception: if the server returns a *terminal* rejection (`409
SUBSCRIPTION_ALREADY_LINKED`, `422 INVALID_RECEIPT`), complete the purchase anyway and show
the explanation, or the store will re-deliver the same doomed transaction forever.

### 4.2 Restore

An explicit "Restore purchases" action on the paywall and in Settings (required by App
Review). It calls `restorePurchases()` and re-posts whatever the stream delivers.

### 4.3 Paywall triggers

| Trigger | Entry point |
|---|---|
| `historyRange` | a locked statistics range chip, or the history boundary row |
| `aiCredits` | AI action at zero credits, or a `402` |
| `adRemoval` | the "Remove ads" affordance on the banner (§5.2) |
| `settings` | the Settings subscription tile |
| `onboarding` | one soft card at the end of onboarding — dismissible, shown once, never a wall |

The trigger is passed into `paywall_screen.dart` and changes the headline only (`69` §3).
Everything else about the screen is identical, so there is one layout to maintain.

### D-P9 The paywall is unreachable **while** sponsored — and reachable again afterwards

If `source == TRAINER_SPONSORED`, no trigger fires and the Settings tile reads "Included by
your trainer" with no CTA. Reached by deep link, the paywall renders an explanatory state
instead of a purchase button (63 §7.3). Selling someone something their coach already pays
for is the fastest way to lose both of them.

**The rule is scoped to the sponsorship.** Once the relationship and its 7-day grace (D-M10)
are over, the user is an ordinary free user and every trigger works again — a churned client
who could never buy Pro would be an absurd outcome. The transition gets exactly one
dismissible dashboard card and a Settings-tile change, never a modal and never an immediate
paywall (`69` §12.1).

### 4.4 Settings tile

In `settings_screen.dart`, above the account section:

| State | Tile |
|---|---|
| Free | "Lifey Pro — remove ads, full history, unlimited AI" → paywall |
| Pro (own) | "Pro · renews 12 Sept" → store subscription management deep link + Restore |
| Pro (sponsored) | "Pro — included by your trainer" → no CTA |
| Trainer trial | "Trainer trial · 6 days left" → link to the web billing page |

---

## 5. Ads

```
mobile/lib/core/ads/
├── ads_service.dart          init, UMP consent, request configuration
├── consent_manager.dart      UMP flow, non-personalized fallback
├── banner_ad_slot.dart       the only widget features embed
└── interstitial_manager.dart rate limiting + eligibility
```

Package: `google_mobile_ads`. Added to `pubspec.yaml` with a comment explaining the choice, in
the style the file already uses.

### 5.1 Consent

UMP runs **after** the first successful entitlement resolve, and only if `adsEnabled` is true
— a Pro user must never see a consent dialog for ads they will never be shown. Consent
refused, or an under-16 birth date in the user's details → `tagForUnderAgeOfConsent` +
non-personalized requests (D-M7). Consent is never a blocking wall.

### 5.2 Banner

`BannerAdSlot` is the only ad widget a feature ever touches. It renders nothing at all unless:
`adsEnabled == true` **and** the snapshot is resolved **and** the ad has loaded. It reserves
its height only once an ad is in hand, so a Pro user has no reserved gap and a failed load
causes no layout shift.

Placed at the bottom of the **four tab roots** — `dashboard_screen.dart`, the nutrition list,
the workouts list and `statistics_screen.dart` — and **nowhere else**: no detail screens, no
modals, no sheets (`69` §12.5). The bottom nav *floats* and collapses to a pill on scroll, so
"above the nav" is not a placement; the resolved answer is the **anchored** variant, frame
**P15** (`69` DV-10). Never over a FAB. A small "Remove ads" affix on the slot is the
`adRemoval` paywall trigger.

### 5.3 Interstitial

`InterstitialManager.maybeShow(context, reason)` is called from exactly two places: after a
meal is successfully logged, and after a workout session is successfully saved.

Eligibility, all required:

- `adsEnabled`
- no active workout or cardio session (`workout_session_notifier`)
- ≥ 4 h since the last interstitial, from `shared_preferences` (63 §8.8 — in-memory only is
  the classic bug here)
- not already shown this app session
- the app has been foregrounded for ≥ 60 s (so it can never land on a cold start)
- not on a route opened from a push notification

### D-P10 The ad layer never reaches the watch, widgets or notifications

`core/ads/` is imported only from phone-side presentation code. A lint-level rule of thumb
plus a test that `core/watch/` and `core/home_screen_widget/` have no path to it.

---

## 6. Localization

Every string in this plan goes through `mobile/lib/l10n/app_en.arb` + `app_hu.arb` per
`docs/13-localization-guide.md` and the `localization` skill. Notable ones:

- Paywall: headline per trigger (5), benefit bullets (3), plan labels, "2 months free" badge,
  legal line, restore, terms/privacy links.
- Gates: history boundary row, locked range chip semantics label, AI credit counter with an
  ICU plural.
- Settings tile: four states.
- Ads: the "Remove ads" affix, the consent explainer.

Prices are **never** in ARB — they come from the store (§4.1).

---

## 7. Accessibility

- The banner slot has a `Semantics` label identifying it as an advertisement.
- Locked chips carry a semantics label that says *why* they are locked, not just "locked".
- The paywall is fully navigable with a screen reader, and the close affordance is the first
  focusable element — App Review checks this, and so should we.
- No gate is communicated by colour alone.

---

## 8. Order of work

**Design status: done — every prompt below is unblocked.**
[`design/Lifey Paywall.dc.html`](design/Lifey%20Paywall.dc.html) carries frames **P01–P27**;
the per-prompt frame map is [`69` §11.1](69-mobile-paywall-design-plan.md). Read two things
before starting: [`69` §11.2](69-mobile-paywall-design-plan.md) for where the canvas departs
from the spec — **DV-9 is a defect Prompt 3 must fix, not copy** — and
[`69` §12](69-mobile-paywall-design-plan.md), which answers the eight questions the designer
raised and settles five decisions this plan did not previously make.

### Milestone M2 — entitlements, no purchases, no ads

**Prompt 1 — Mobile data: entitlement model, Drift cache, repository**
`core/entitlements/` minus the providers, the `entitlement_cache` table + migration, the API
call, grace and fail-open logic.
*Verify:* unit tests for every branch of D-P4, including "no cache at all", "expired grace",
and "server unreachable"; a Drift migration test.

**Prompt 2 — Mobile data: Riverpod providers + refresher**
`entitlementProvider` and the four derived providers, `EntitlementRefresher` and its five
refresh points.
*Verify:* provider tests over a fake repository; a test that a trainer-invite acceptance
triggers a refresh (D-P3).

**Prompt 3 — Mobile UI: history window** — frames **P11–P12**
`historyCutoffProvider` applied to statistics, workout history, nutrition navigation, charts;
the boundary row; the two locked rows in the range popup. **Fix `69` DV-9 while implementing:**
P11 draws a check mark on two rows, but `_StatsRangeButton` renders the check only for
`r == range`. One check, on the selected row; the locked rows keep the `lock` glyph in the same
20 px slot. Correct the frame in the same change.
*Verify:* widget tests at `historyDays: 30` and `null`; an explicit test that the underlying
repository query is **unchanged** between the two (D-P6).

**Prompt 4 — Mobile UI: AI credit counter** — frame **P13**
Counter next to the AI actions, zero-state → paywall trigger, `402` handling. The exhausted chip
names the calendar-month refill date (`69` DV-11), and the row **stays tappable at 0/3** — it
explains, it does not fail (`69` DV-12).
*Verify:* widget test at 3/1/0 credits with the ICU plural in both locales.

### Milestone M3 — purchases

**Prompt 5 — Mobile data: `in_app_purchase` + `PurchaseRepository`**
Product query, purchase stream, server verification, `completePurchase` ordering (D-P8),
restore.
*Verify:* unit tests with a fake `InAppPurchase`; explicit tests for the terminal-rejection
exception and for a crash between purchase and verification (transaction stays pending).

**Prompt 6 — Mobile UI: paywall screen** — frames **P02–P10**
Layout from `69` §3, five triggers, store-sourced prices, the sponsored state (D-P9). Also
required by `69` §12: the legal links open in the **system browser**, not a webview (§12.7), and
the plan cards render as **skeletons with an amount-less CTA** while the store prices load
(§12.8 — note that frame is one of the three still to be drawn, `69` §13).
*Verify:* widget test per trigger; a test that the sponsored state renders no purchase
button; a golden-free layout test at 320 pt width.

**Prompt 7 — Mobile UI: Settings subscription tile** — frame **P14**
Four states, store management deep links, restore. The tile renders the **resolved `source`**,
never a merge of two (`69` §12.6); the trainer-trial state links to the web billing page.
*Verify:* widget test per state, both locales.

### Milestone M4 — ads

**Prompt 8 — Mobile: AdMob init + UMP consent**
`core/ads/ads_service.dart`, `consent_manager.dart`, platform config (iOS
`GADApplicationIdentifier` + `NSUserTrackingUsageDescription`, Android manifest metadata).
No ad is displayed yet.
*Verify:* a Pro account never triggers the consent flow; consent-refused produces
non-personalized configuration; the app starts normally with no network.

**Prompt 9 — Mobile UI: `BannerAdSlot` on the four tab roots** — frames **P15, P17**
Variant **A (anchored)** won, restricted to the four tab roots — dashboard, nutrition, workouts,
statistics — and nowhere else (`69` DV-10, §12.5). P17 is the acceptance reference for the Pro
case: no slot, no gap, no hairline.
*Verify:* widget tests that nothing renders for Pro, nothing renders before resolution, and
no layout shift on a failed load; a layout test that the slot never overlaps the bottom
navigation or a FAB.

**Prompt 10 — Mobile: `InterstitialManager`**
All six eligibility conditions, persisted rate limit.
*Verify:* unit tests per condition; specifically, a test that a cold start within 4 h of the
last interstitial shows nothing (63 §8.8), and one that an active workout suppresses it.

**Prompt 11 — Mobile: ad-free assertions across the app**
The `gated_surfaces_test.dart` from D-P7 plus the no-ads-on-watch/widget test (D-P10).
*Verify:* the test suite itself is the deliverable.

---

## 9. Edge cases

1. **Fresh install, offline, previously Pro.** No cache → open (D-P4). Correct: a paying user
   reinstalling on a plane is not shown ads.
2. **Sponsorship gained mid-session** (invite accepted): the refresher fires, banners
   disappear on the next frame. Removing an ad mid-view is fine; inserting one is not — the
   slot only appears at a route change.
3. **Sponsorship lost.** Grace applies; when it ends, ads appear at the next route change,
   with no announcement. The Settings tile is the only place that explains it.
4. **Purchase succeeds while offline** (StoreKit allows this). The transaction stays pending,
   the server verification runs on the next launch with connectivity. The UI says "we'll
   finish this as soon as you're online" rather than "failed".
5. **Two accounts on one device.** The store subscription binds to the first user (`64` D-B6);
   the second gets the 409 and a clear message pointing at the store account.
6. **User under 16.** Non-personalized ads, and the paywall's data-use copy adjusts. If the
   birth date is unknown, treat as under-consent-age — the safe direction here is the
   restrictive one, which is the opposite of the entitlement rule, and that asymmetry is
   deliberate.
7. **Interstitial and the rest timer.** The rest timer runs inside a session, so §5.3's
   active-session condition already covers it — but `docs/39-rest-timer-plan.md`'s derived-state
   design means there is no "timer object" to ask; the check is on the session, not the timer.
8. **A locked range chip in a screenshot for the store listing.** Store screenshots must show
   the Pro state, not the locked one (`69` §5).

---

## 10. Non-goals (deferred)

- Rewarded ads and AI credit top-ups (63 §6).
- Native ad formats inside lists.
- A web-based purchase for mobile Pro (store policy, D-M1).
- Promotional offers / win-back offers / introductory pricing beyond the yearly discount.
- Family sharing.
- Any ad on the watch, on widgets, or in notifications (D-P10).

---

## 11. Test plan

| Layer | What |
|---|---|
| Unit | D-P4 branches; interstitial eligibility per condition; purchase-flow ordering incl. terminal rejection |
| Drift | `entitlement_cache` migration; single-row invariant |
| Provider | refresh points; derived providers |
| Widget | history window at both settings; the two locked rows in the range popup, with exactly **one** check mark on the selected row (`69` DV-9); AI counter plural (hu/en) and the row still tappable at 0/3; paywall per trigger; sponsored state; Settings tile per state; banner absent for Pro / before resolution / on failed load |
| Structural | `gated_surfaces_test.dart`; no ads path from watch or widget code |
| Manual | sandbox purchase on both stores; restore on a second device; UMP consent in an EU locale; a full offline→grace-expiry cycle with the clock moved forward |

Known environment caveat: three chat-attachment tests already fail on Windows and are
unrelated to this work.

---

## 12. Suggested PR split

One PR per prompt. Prompts 1–2 change no visible behaviour and should merge first. Prompt 3
is the first user-visible gate and must not merge before the server can actually return
`historyDays` (`64` Prompt 2). Prompts 8–10 (ads) merge last and behind a client-side kill
switch read from the entitlement response, so ads can be turned off server-side without an
app release.

---

## 13. Risk checkpoints where a failure would be silent

1. **Ads shown to a Pro user for a few frames** on cold start (63 §8.6) — the slot must
   default to nothing.
2. **The history window implemented in the repository query** instead of the presentation
   layer (D-P6). Looks identical in a demo; destroys data on the next re-install.
3. **The interstitial rate limit in memory** (63 §8.8).
4. **`completePurchase` before verification** (D-P8) — a silently lost purchase, reported as
   "I paid and got nothing".
5. **Unacknowledged Play purchases** — the acknowledgement is server-side (`64` §6.1), but a
   client that never posts the token means it never happens, and the purchase auto-refunds in
   three days with no error anywhere.
6. **A gate reading `isPro` instead of the specific field** (D-P5), so a server-side limit
   change does nothing and nobody notices for months.
7. **The refresher not firing on invite acceptance**, leaving a newly coached client watching
   ads for up to 15 minutes — small, but it is the first minute of the coaching relationship.
8. **The consent flow running for Pro users**, which is not a crash, just a baffling dialog
   asking a paying customer about ad personalization.

---

## 14. After implementation

- Set `Status:`; update `docs/landing_page/README.md`.
- `docs/04-mobile-app.md` gains the free/Pro split.
- `docs/23-ai-calorie-estimation-plan.md` gains the credit-gate section.
- `docs/17-statistics-page-plan.md` gains the history-window note.
- `pubspec.yaml` comments for `google_mobile_ads` and `in_app_purchase` explaining the
  choices, per the file's existing convention.
