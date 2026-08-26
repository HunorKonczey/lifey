# Landing page & monetization — documentation

This folder plans how Lifey **makes money** and how it **presents itself in public**. Status:
**plans written, both designs done, no code started.** No billing, subscription, entitlement,
ad or marketing code exists in the repo today, and `web/src/app/page.tsx` still redirects `/`
straight to `/dashboard`.

**Design status: both canvases are done — implementation is unblocked.** The mobile canvas is
delivered ([`design/Lifey Paywall.dc.html`](design/Lifey%20Paywall.dc.html), **P01–P27**), with
its frame map at [69 §11](69-mobile-paywall-design-plan.md), one defect to fix rather than copy
([69 DV-9](69-mobile-paywall-design-plan.md)) and the designer's eight open questions answered
at [69 §12](69-mobile-paywall-design-plan.md) — five of which settled decisions the plans had
not previously made. The marketing web canvas is finished —
[`design/Lifey Landing.dc.html`](design/Lifey%20Landing.dc.html), frames **L01–L21**, covering
the home page and the pricing page at both sizes in both themes.

**Nothing in M0b, M2 or M3 is design-blocked any more.** What remains is small: the
for-trainers / app / download page frames and the web state frames
([68 §13](68-web-landing-design-plan.md)), three mobile additions
([69 §13](69-mobile-paywall-design-plan.md)), and **two defects in the delivered canvases that
implementation must fix rather than copy** — the Studio card's phantom feature
([68 DV-5](68-web-landing-design-plan.md)) and the double check mark in the range menu
([69 DV-9](69-mobile-paywall-design-plan.md)).

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
| [65-web-landing-page-plan.md](65-web-landing-page-plan.md) | The `(marketing)` route group, `/[locale]` routing + the project's **first middleware**, moving `<Providers>` out of the root layout, SEO, analytics, performance budgets, 11 steps | Web (Next.js) |
| [66-trainer-billing-web-plan.md](66-trainer-billing-web-plan.md) | Trainer access requests, `/admin/billing`, checkout round trip, trial banner escalation, blocked-action UX, over-limit archiving, 10 steps | Web + a small backend annex (V76) |
| [67-mobile-free-pro-plan.md](67-mobile-free-pro-plan.md) | `core/entitlements/`, the three gates, the paywall and its triggers, `in_app_purchase`, AdMob + UMP consent, 11 steps | Flutter |
| [68-web-landing-design-plan.md](68-web-landing-design-plan.md) | Web design spec: marketing type scale, grid, the home page section by section, pricing cards, states, assets — desktop **and** mobile, dark **and** light | Design + Web |
| [69-mobile-paywall-design-plan.md](69-mobile-paywall-design-plan.md) | Mobile design spec: the paywall layout and its 5 headlines + 4 special states, gated surfaces, the ad slot, store listings and ASO, the invite → download bridge | Design + Flutter |
| [70-landing-design-prompt.md](70-landing-design-prompt.md) | The original design prompt for both canvases + decision log. **The web half has run; its mobile half is superseded by `71`** | Design (historical) |
| [71-mobile-paywall-design-prompt.md](71-mobile-paywall-design-prompt.md) | The narrowed prompt that produced the mobile canvas. **Already run** — do not re-run it | Design (historical) |
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

## Two prerequisites hiding in the web app

Both are in `65` and both are worth knowing before planning a sprint:

- `<Providers>` (TanStack Query, i18n, toaster, `/client-config`) currently wraps **every**
  route from the root layout. It has to move down into the four authenticated groups, or the
  landing page ships the whole app bundle (65 D-W6, step 1).
- There is **no `middleware.ts` in the project**. Locale routing introduces the first one, and
  its matcher must be scoped to the marketing tree only (65 D-W3, step 2).

## Related existing documents

- `docs/personal_trainer/` — the workspace being sold; `03-backend-terv.md` for the
  `/api/v1/trainer/**` authorization this plan extends with seat limits.
- `docs/web/04-frontend-architecture.md` — the provider/rendering description that `65` D-W6
  makes out of date.
- `docs/15-delta-sync.md` — why entitlements deliberately stay out of the sync feed.
- `docs/23-ai-calorie-estimation-plan.md` — the AI features that become the Pro gate.
- `docs/design/18-design-system-prompt.md`, `docs/web/06-design-system-web.md` — the tokens
  `68`–`70` extend.
