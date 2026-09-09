# Landing page & monetization — documentation

This folder plans how Lifey **makes money** and how it **presents itself in public**. Status:
**both designs done; the marketing web app (`65`) and the mobile free/Pro app (`67`) are both
fully implemented** — see each plan's own reading-order row below for what that covers.
**What is still missing across all of them is collected in
[`72-monetization-followup-plan.md`](72-monetization-followup-plan.md)**, and the two
verification passes that need a Stripe account and two phones are in
[`73-billing-verification-runbook.md`](73-billing-verification-runbook.md). `72`'s milestones **F1–F5 have landed**
(F5 as far as it can go without store accounts), and what is left is tracked in
[`REMAINING-WORK.md`](REMAINING-WORK.md) — the store launch is **parked until the company
exists**, and the rest is listed there by whether it is blocked or simply not done yet.

**Design status: both canvases are done — implementation is unblocked.** The mobile canvas is
delivered ([`design/Lifey Paywall.dc.html`](design/Lifey%20Paywall.dc.html), **P01–P27**), with
its frame map at [69 §11](69-mobile-paywall-design-plan.md), one defect to fix rather than copy
([69 DV-9](69-mobile-paywall-design-plan.md)) and the designer's eight open questions answered
at [69 §12](69-mobile-paywall-design-plan.md) — five of which settled decisions the plans had
not previously made. The marketing web canvas is finished —
[`design/Lifey Landing.dc.html`](design/Lifey%20Landing.dc.html), frames **L01–L21**, covering
the home page and the pricing page at both sizes in both themes.

**Nothing in M0b, M2 or M3 is design-blocked any more.** What remains is small: the web state
frames ([68 §13](68-web-landing-design-plan.md) item 4), three mobile additions
([69 §13](69-mobile-paywall-design-plan.md)), and **one remaining defect in the delivered
canvases that implementation must fix rather than copy** — the double check mark in the range
menu ([69 DV-9](69-mobile-paywall-design-plan.md)). The Studio card's phantom feature
([68 DV-5](68-web-landing-design-plan.md)) is fixed in code as of `65` Prompt 6; only the
canvas frame itself hasn't been redrawn to match. The for-trainers, app and download page
frames ([68 §13](68-web-landing-design-plan.md) items 1–3) were never drawn at all, but no
longer block anything either — `65` Prompts 5–7 implemented all three without a frame.

**Web implementation status: all 11 prompts of `65` are done** — the Providers refactor, locale
routing + proxy, the marketing header/footer/sticky-CTA shell, the full 12-section home page,
the for-trainers page, the full pricing page, the app + download pages, the FAQ, contact and
legal pages, the SEO plumbing (per-page metadata, `sitemap.xml`, `robots.txt`,
`opengraph-image.tsx`, the remaining `Organization`/`WebSite`/`SoftwareApplication` JSON-LD),
and first-touch attribution + the five analytics events all work in a real production build,
both locales, both themes. Prompts 8 and 10 are the only two of these ten to touch `backend/` —
Prompt 8's contact form needed a genuinely new mail capability
(`com.lifey.contact`/`MailService.sendContactMessage`, since the existing Resend pipeline only
ever sent *to* a registered user, never from an anonymous visitor) and Prompt 10's first-touch
attribution needed a new `signup_source` column (`RegisterRequest`/`AuthServiceImpl`/`User`);
see each prompt's own landed notes for why, and for real end-to-end verification against a live
(locally run) backend and Postgres in both cases — a real contact-form email logged with the
right recipient/reply-to in Prompt 8, a real registration's `signup_source` confirmed with a
direct `psql` query in Prompt 10. `/hu`'s first-load JS is still ~275 KB gzipped,
not under `65` §8's 100 KB target — but only ~16 KB of that is marketing-specific (the home,
for-trainers and app pages added **zero** more JS each: every component in them is a Server
Component, the FAQ accordion is a native `<details>`; the pricing page adds ~1.4 KB for its
interval toggle and signed-in CTA swap; the download page is actually *lighter* than the
baseline, ~204.9 KB, since it skips the shared header/footer/sticky-CTA chrome entirely — see
below); the rest is a pre-existing shared root-layout baseline that `/login` already paid
before this work started. Closing the literal target is root-layout-level work (bundle
analysis, deferring Analytics/SpeedInsights), tracked but not attempted as a side effect of
building pages — see `65` Prompt 3's landed notes. **A real Lighthouse run finally happened in
Prompt 11**, not just "still worth doing" — headless Chrome, mobile emulation, §8's own
throttle profile, against `/hu`: performance 93, accessibility 100 (after Prompt 11 fixed two
real `color-contrast` failures Lighthouse itself surfaced — `ChatMock.tsx`'s message timestamp,
`SponsoredBand.tsx`'s ad-slot label), SEO 92 (capped by one `canonical` audit that only fails
against `localhost`, not the real `https://lifey.hu` `metadataBase` every canonical tag
correctly uses), LCP ~3.16 s. None of Performance/SEO/LCP meet §8's literal targets yet, for the
same >100 KB root-layout-JS reason as the JS budget itself — `65` Prompt 11 wired both a
Lighthouse CI gate and a first-load-JS gate into `web-ci.yml`, thresholded against these real
measurements (with buffer) rather than the unmet literal targets, and verified both actually
catch a regression by deliberately importing `recharts` into the home page (JS: 283 KB → 379 KB;
Lighthouse performance: 93 → 89) before reverting it. Other open items carried forward: the
hero/value-block "screenshots" are **reproduced UI**, not photographic captures — no seeded
demo backend exists yet to capture from; the light-mode contrast bug that ran through
23 places across Prompts 3–5 is **closed**: four were fixed in passing in Prompts 10–11, and
commit `1c252fd` swept the rest of the palette in both products. `72` F1 then ran axe-core over
all 12 marketing routes in both themes and at mobile width, found the last two (on
`/hu/alkalmazas`), fixed them, and wired that sweep into CI so the next one cannot ship — the
suite is green at zero violations today; and the download page's `lifey://invite/<token>` deep
link has not been checked against a real device with the app installed (`65` Prompt 7's own *Verify* line asks
for this, and nothing in this environment can register that URL scheme to test it). The
for-trainers, pricing, app and download pages all shipped without their own design frames for
some or all of their content — each reuses the home page's own components rather than inventing
new ones, and the download page needed a second, chrome-free route group
(`(marketing-bare)`) besides; see each prompt's landed notes in `65` for the specific calls
made without a canvas to check them against. The four legal pages (`65` Prompt 8) are drafted,
real content grounded in facts already established across `63`–`69`, not lawyer-reviewed text —
the Impresszum's company-identity fields are explicit placeholders rather than invented values,
and real legal review of all four is still open before this ships. SEO plumbing (`65` Prompt 9)
landed too: every page has real per-locale metadata, canonical/hreflang, a build-time-generated
`opengraph-image.tsx`, and `sitemap.xml`/`robots.txt` — with one known, accepted cosmetic quirk
(a font-rendering gap around certain word boundaries in the generated OG images, not a data bug,
documented in `lib/ogImage.tsx` and `65` Prompt 9's landed notes) and one still-open item (Rich
Results / structured-data validation needs Google's actual tool against a deployed URL, not
available in this environment).

**Mobile implementation status: all 11 prompts of `67` are done** — the entitlement layer
(Drift cache, D-P4's fail-open/grace ladder, `EntitlementRefresher`'s five refresh points), the
three gates (history window with the `69` DV-9 fix landed in the same change, the AI credit
counter), the `in_app_purchase` purchase flow and paywall screen (five triggers, the D-P9
sponsored state), the Settings subscription tile, AdMob init behind UMP consent, `BannerAdSlot`
on the four tab roots, `InterstitialManager`'s six eligibility conditions, and the two D-P7/D-P10
structural tests (`gated_surfaces_test.dart`, the watch/widget-has-no-path-to-ads test) all work
against the real provider graph, not just in isolation. The full `flutter test` suite passes
except three pre-existing chat-attachment failures unrelated to this work (Windows-only, see
`67` §11). Two things are still open: the banner/interstitial ad unit IDs and the AdMob App IDs
in `Info.plist`/`AndroidManifest.xml` are Google's public **test** identifiers, not the real ones
from the AdMob console (each site carries a "swap before release" comment); and `AiCreditChip`/
`requireAiCredits` (Prompt 4) exist and are tested but aren't embedded in any screen yet, because
mobile has no AI meal-photo-estimation UI built (`docs/23-ai-calorie-estimation-plan.md` is still
backend-only here) — flagged as its own follow-up rather than built as a side effect. `67` §11's
manual row (sandbox purchase on both stores, restore on a second device, UMP consent in an EU
locale, a full offline→grace-expiry cycle with the clock moved forward) needs a real device and
store sandbox neither available in this environment, so none of it has run yet.

The business model in one paragraph: **trainers pay, clients don't.** The revenue product is
the trainer workspace (`/admin`), sold as three tiers keyed to active client count, on the
web, through Stripe, after a 14-day card-free trial. A client keeps using the mobile app for
free — and while their trainer pays, they get the ad-free Pro app at no cost. Someone with no
trainer uses the app free with ads and can buy Pro through the App Store or Play Store.

## Reading order

| File | What it covers | Who it's for |
|---|---|---|
| [63-monetization-strategy-plan.md](63-monetization-strategy-plan.md) | **Start here.** Tiers and prices, what is free vs Pro, sponsored Pro, ads policy, trial, the entitlement resolution order, funnel, EU/HU legal and tax, milestones M0–M5 | Everyone |
| [64-billing-backend-plan.md](64-billing-backend-plan.md) | `com.lifey.billing`: subscription domain, migrations V72–V75, the entitlement resolver, Stripe adapter, StoreKit/Play adapter, seat enforcement, reconciliation, 12 prompt-sized steps | Backend |
| [65-web-landing-page-plan.md](65-web-landing-page-plan.md) | The `(marketing)` route group, `/[locale]` routing + the project's **first proxy** (`src/proxy.ts`), moving `<Providers>` out of the root layout, the marketing shell, the full home page (12 sections), the for-trainers page, the pricing page, the app + download pages, the FAQ/contact/legal pages, SEO plumbing, attribution + analytics events, performance budgets in CI, 11 steps — **all 11 done** | Web (Next.js) |
| [66-trainer-billing-web-plan.md](66-trainer-billing-web-plan.md) | Trainer access requests, `/admin/billing`, checkout round trip, trial banner escalation, blocked-action UX, over-limit archiving, 10 steps | Web + a small backend annex (V76) |
| [67-mobile-free-pro-plan.md](67-mobile-free-pro-plan.md) | `core/entitlements/`, the three gates, the paywall and its triggers, `in_app_purchase`, AdMob + UMP consent, 11 steps — **all 11 done** | Flutter |
| [68-web-landing-design-plan.md](68-web-landing-design-plan.md) | Web design spec: marketing type scale, grid, the home page section by section, pricing cards, states, assets — desktop **and** mobile, dark **and** light | Design + Web |
| [69-mobile-paywall-design-plan.md](69-mobile-paywall-design-plan.md) | Mobile design spec: the paywall layout and its 5 headlines + 4 special states, gated surfaces, the ad slot, store listings and ASO, the invite → download bridge | Design + Flutter |
| [70-landing-design-prompt.md](70-landing-design-prompt.md) | The original design prompt for both canvases + decision log. **The web half has run; its mobile half is superseded by `71`** | Design (historical) |
| [71-mobile-paywall-design-prompt.md](71-mobile-paywall-design-prompt.md) | The narrowed prompt that produced the mobile canvas. **Already run** — do not re-run it | Design (historical) |
| [72-monetization-followup-plan.md](72-monetization-followup-plan.md) | **Read this before calling any of the above finished.** The closing pass: everything `63`–`71` left behind — 21 steps in 6 milestones. **F1 (web launch blockers) is done bar its legal-content step** — the branded localized 404, the broken Apple badge glyph, two measured axe failures, a WCAG gate over every marketing route in both themes in CI, the six marketing e2e specs `65` §12 asked for — and **F2 (mobile) is done**: the banner's "Reklám" label with its remove-ads button moved off the creative, the locked-row and plan-card accessibility fixes, the 200 % text-scale paywall, the sponsorship-ended card, and the AdMob ids behind defines with a release checker. Still open: the real store/AdMob ids themselves, the unverified Stripe and store-sandbox paths, both uncorrected canvas defects, M5 in full, and the eight documentation updates the original prompts owed but never made | Everyone |
| [73-billing-verification-runbook.md](73-billing-verification-runbook.md) | **The two verification passes no test in this repo can run.** §1 is a 12-step Stripe test-mode round trip (do the price ids exist, does the withdrawal-waiver checkbox actually render, portal → cancellation → downgrade), with the SQL to run at each step. §2 is a 15-row store sandbox matrix, a column per platform — sandbox purchase, second-device restore, UMP consent, offline grace expiry, ad slot, Play acknowledgement. Fill in the result columns and paste them back into `72` §4 | Whoever has the Stripe account and two phones |
| [74-store-listing-and-aso.md](74-store-listing-and-aso.md) | **What goes in the store listing boxes.** Title, subtitle, keywords, promo text and the full description in HU and EN with every character count verified; the App Privacy / Data Safety / Health Connect answers derived from the app's actual SDKs; and the screenshot export (`node devops/export-store-screenshots.mjs`, straight from the canvas at each store's exact size). §5 is the list of things only the account holder can do | Whoever owns the store accounts |
| [REMAINING-WORK.md](REMAINING-WORK.md) | **Start here to pick something up.** The living list of what is left: the whole store-launch section parked until the company is registered (§1), what is developable today with no external dependency (§2), what is blocked on a device / a deployed URL / design time (§3), and the decisions not to re-raise (§4). Unnumbered because it shrinks as work lands, unlike the plans around it | Everyone |
| [`design/Lifey Landing.dc.html`](design/Lifey%20Landing.dc.html) | **The finished marketing web design — frames L01–L21**: token sheet, header/footer/sticky-CTA states, the full home page (desktop + mobile, dark + light), the pricing page. Frame map: [68 §12.1](68-web-landing-design-plan.md) | **Web implementation works from this** |
| [`design/Lifey Paywall.dc.html`](design/Lifey%20Paywall.dc.html) | **The finished mobile design — frames P01–P27**: paywall (5 triggers, 4 edge states, 320 pt + 200 % scale), the three gated surfaces, the Settings tile, both ad-slot variants + the Pro no-slot render, the store screenshot set. Frame map: [69 §11.1](69-mobile-paywall-design-plan.md) | **Mobile implementation works from this** |

## Milestones at a glance

| # | Name | What you can demo | Main docs |
|---|---|---|---|
| **M0** | Marketing surface | A bilingual public landing page at `/` with a pricing page that leads to registration. No billing yet. | 65, 68, 70, 66 (steps 1–3) |
| **M1** | Trainer billing | A trainer registers, gets 14 days, pays by card, and the seat limit is enforced. **Revenue exists.** | 64 §3–4, 66 |
| **M2** | Entitlements on mobile | The app reads its entitlement; sponsored Pro, the 30-day history window and the AI credit counter are live. No ads, no purchases yet. | 64 §3, 67 §2–3 |
| **M3** | Mobile Pro purchase | Paywall, StoreKit/Play purchase, restore, the Settings tile. | 64 §5–6, 67 §4, 69 |
| **M4** | Ads | UMP consent, banners, the rate-limited interstitial, ad-free on every Pro path. | 67 §5, 69 §4 |
| **M5** | Store & polish | Store listings, ASO assets, the download page with the invite handoff, the reconciliation job. | 65 §6, 69 §5–6, 64 §7 |

**M1 is the smallest thing worth shipping** — a complete, working revenue product. M2 comes
before M3 deliberately: sponsored Pro is the entitlement path with the most edge cases and no
store dependency, so it should prove the model before a purchase flow is built on top of it.

## The decisions that shape everything else

1. **Two payment rails, one entitlement model** (63 D-M1): Stripe on the web for trainers,
   native IAP on mobile for Pro, both resolving through a single
   `GET /api/v1/me/entitlements`. Store rules require IAP in the app; the trainer side never
   touches a store, so the main revenue pays no store commission.
2. **Trainer tiers are keyed to active client count, not features** (63 D-M2). Every plan has
   every feature; the seat number is the headline on the pricing card, not the price.
3. **A paying trainer's clients get Pro for free** (63 D-M4). It is the strongest line on the
   pricing page and it means a coached client never sees an ad.
4. **Only three things are gated on mobile** (63 D-M5): ads, a 30-day history window, and the
   monthly AI credit count. Nothing that makes the app *work* is ever locked.
5. **Entitlements fail open** (63 D-M9) with a 7-day offline grace (D-M10), and they are
   deliberately **outside the delta-sync feed** (D-M11).
6. **Going over the seat limit is soft, and the trainer chooses who to archive** (63 D-M12).
   Nothing is ever auto-archived.
7. **Chat is never paywalled** (63 D-M8) — the block is on acquiring clients, not on talking
   to the ones you have.
8. **The landing page lives in the existing Next.js app** as a `(marketing)` route group with
   real `/hu` and `/en` URLs (65 D-W1, D-W3). Hungarian is the default locale and sets every
   layout's text slot (68 §2.2).
9. **Trainer access stays a super-admin grant** (63 §6). The landing CTA creates a *request*,
   and the review wait is stated plainly rather than hidden (66 D-T1, 70 DD-3).

## Two prerequisites that were hiding in the web app — both done

Both are in `65`, both landed (Prompts 1–2), and both are worth knowing before touching this
tree again:

- `<Providers>` (TanStack Query, i18n, toaster, `/client-config`) used to wrap **every** route
  from the root layout — it now lives in each of the four authenticated groups instead, or the
  landing page would ship the whole app bundle (65 D-W6, Prompt 1).
- There was **no proxy/middleware file in the project**. Locale routing introduced the first
  one — as **`src/proxy.ts`, not `middleware.ts`**: Next.js 16 renamed the convention and
  changed its default runtime to Node.js (65 D-W3, Prompt 2). Its matcher is scoped to the
  marketing tree only. A related landmine for whoever picks up Prompt 4: **`force-static` on
  a `[locale]` page silently breaks next-intl's per-locale rendering** unless the page also
  calls `setRequestLocale` itself, not just its layout — see `65` Prompt 2's landed notes for
  the fix and why it's easy to miss (the build succeeds either way).

## Related existing documents

- `docs/personal_trainer/` — the workspace being sold; `03-backend-terv.md` for the
  `/api/v1/trainer/**` authorization this plan extends with seat limits.
- `docs/web/04-frontend-architecture.md` — the provider/rendering description that `65` D-W6
  makes out of date.
- `docs/15-delta-sync.md` — why entitlements deliberately stay out of the sync feed.
- `docs/23-ai-calorie-estimation-plan.md` — the AI features that become the Pro gate.
- `docs/design/18-design-system-prompt.md`, `docs/web/06-design-system-web.md` — the tokens
  `68`–`70` extend.
