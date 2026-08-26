# 65 – Web Landing Page

Status: proposed
Scope: web — routing, i18n + SEO, page inventory, content, analytics, performance
Depends on: `docs/landing_page/63-monetization-strategy-plan.md` (pricing, funnel, legal),
`docs/web/04-frontend-architecture.md` (rendering, folder structure, providers),
`docs/web/06-design-system-web.md` (tokens), `docs/landing_page/68-web-landing-design-plan.md`
(the visual spec this implements)

The visual design lives in `68`. This doc is the engineering plan: where the pages sit, how
two locales get real URLs, how the marketing bundle stays away from the app bundle, and what
gets measured.

---

## 1. Current state (what already exists)

- `web/src/app/page.tsx` is three lines: `redirect("/dashboard")`. There is **no public
  page** on this domain today.
- Route groups: `(app)`, `(admin)`, `(auth)`, `(superadmin)`. All authenticated.
- `web/src/app/layout.tsx` wraps *everything* in `<Providers>` — TanStack Query,
  `I18nProvider`, the toaster, devtools, plus a `/client-config` fetch. Every one of those is
  a client component, and none of them belongs on a marketing page.
- i18n is **client-side only**: `next-intl`'s `NextIntlClientProvider` fed from a zustand
  store (`useLocale`) that reads `navigator.language` after mount. There are no locale URL
  segments and **no `middleware.ts` anywhere in the project**.
- Tokens: dark-first brown-green palette in `src/app/globals.css`, Plus Jakarta Sans via
  `next/font`, Material Symbols Rounded via a Google Fonts `<link>`.
- CSP is hand-built in `next.config.ts`; `img-src` is `'self' data: blob:` and `script-src`
  allows Google Identity Services only.

Two of these are blockers for a landing page — the client-only i18n (no indexable
Hungarian URL) and the global `Providers` (a marketing page that ships React Query). Both
are addressed below.

---

## 2. Key design decisions

### D-W1 The marketing site is a `(marketing)` route group in the existing app

```
web/src/app/
├── (marketing)/
│   └── [locale]/
│       ├── layout.tsx          server component; MarketingHeader + MarketingFooter
│       ├── page.tsx            home
│       ├── edzoknek/page.tsx   for-trainers   (localized path, §3.2)
│       ├── alkalmazas/page.tsx the app, for individual users
│       ├── arak/page.tsx       pricing
│       ├── gyik/page.tsx       FAQ
│       ├── letoltes/page.tsx   download / deferred deep link (69 §6)
│       ├── kapcsolat/page.tsx  contact
│       └── jogi/[doc]/page.tsx ÁSZF, privacy, cookies (63 §5)
├── (app)/ (admin)/ (auth)/ (superadmin)/   ← unchanged
```

One repo, one deploy, one set of design tokens, and the pricing→register path never crosses
an origin. Marketing pages are **statically rendered** (no `cookies()`, no `headers()`, no
client providers), so they are served from the edge cache.

*Rejected: a separate Next app on the same domain behind a proxy.* Clean isolation, but two
builds, two copies of the token file that will drift within a month, and a rewrite layer to
maintain for no user-visible gain.

*Rejected: a marketing subdomain.* `lifey.app` vs `app.lifey.app` is tidy for SEO but puts a
domain change in the middle of the one funnel step that matters (pricing → register), and
complicates the auth cookie story for no benefit at this size.

### D-W2 `/` no longer redirects to `/dashboard`

`src/app/page.tsx` becomes a locale redirect (§3.3), not a dashboard redirect. A signed-in
visitor who types the bare domain lands on the landing page and sees a **"Back to app"**
button in the header instead of the sign-in CTA. Auto-redirecting them away would make the
marketing site invisible to exactly the people most likely to share it.

The header decides between "Sign in" and "Back to app" from a small client component that
reads the session store; the rest of the page stays server-rendered.

### D-W3 Locale segments for marketing only — the app group keeps its client-side i18n

`next-intl`'s routing (`defineRouting` + `createNavigation`) is introduced with
`localePrefix: "always"`, `locales: ["hu", "en"]`, `defaultLocale: "hu"` — and a
`middleware.ts` whose matcher covers **only** the marketing paths:

```ts
export const config = {
  matcher: ["/", "/(hu|en)/:path*"],
};
```

The authenticated groups keep resolving locale from `settings.language` through
`useLocale`, exactly as today. Migrating the whole app to URL locales is a much larger,
riskier change with no SEO payoff — the app is behind a login and is not indexed.

*This is the first `middleware.ts` in the project.* Its matcher is therefore a
correctness-critical line: a matcher that accidentally covers `/dashboard` puts middleware in
front of every authenticated request. It gets its own test (§9, Prompt 2).

### D-W4 Hungarian is the default locale, with localized pathnames

`defaultLocale: "hu"`, and `pathnames` maps each route to both languages:

| Route key | `hu` | `en` |
|---|---|---|
| `/` | `/hu` | `/en` |
| `/for-trainers` | `/hu/edzoknek` | `/en/for-trainers` |
| `/app` | `/hu/alkalmazas` | `/en/app` |
| `/pricing` | `/hu/arak` | `/en/pricing` |
| `/faq` | `/hu/gyik` | `/en/faq` |
| `/download` | `/hu/letoltes` | `/en/download` |
| `/contact` | `/hu/kapcsolat` | `/en/contact` |
| `/legal/terms` | `/hu/jogi/aszf` | `/en/legal/terms` |
| `/legal/privacy` | `/hu/jogi/adatkezeles` | `/en/legal/privacy` |

Hungarian keyword URLs matter for the Hungarian search results this site is actually
competing in. `hreflang` alternates and a canonical are emitted per page (§5.1).

### D-W5 Marketing copy lives in its own message files, not in `messages/hu.json`

`web/messages/marketing.hu.json` and `marketing.en.json`, loaded server-side by the
marketing layout only. The app's message bundle is already large and is shipped to the
client; marketing copy is long-form prose that must never enter that bundle.

### D-W6 `<Providers>` moves out of the root layout

Root layout keeps only `<html>`, the fonts, the theme bootstrap script and `<body>`.
`<Providers>` moves into `(app)/layout.tsx`, `(admin)/layout.tsx`, `(auth)/layout.tsx` and
`(superadmin)/layout.tsx`.

This is the single change that decides whether the landing page is fast. It is also a
refactor that touches every authenticated route, so it lands as its own PR with the E2E suite
as the gate (§9, Prompt 1).

### D-W7 No third-party marketing scripts, and therefore no cookie banner

Vercel Analytics + Speed Insights are already in the root layout and are cookieless. No
Google Analytics, no Meta Pixel, no chat widget, no font host beyond the two already
allowed. The landing page stays banner-free, the CSP stays as narrow as it is today, and
consent is one less thing to get wrong (63 §5).

If paid acquisition later needs a pixel, that is a deliberate decision that also buys a
consent banner — it does not get to arrive as a one-line addition.

### D-W8 Every CTA carries its attribution into registration

CTA links append `?src=<page>-<slot>` and any inbound `utm_*` is preserved. A tiny client
component writes the first-touch value to a `lifey_attrib` cookie (30 days, `SameSite=Lax`,
no personal data — 63 §5 privacy rules), which `(auth)/register` reads and sends as
`signupSource` on the register call. Without this, "which page produced paying trainers" is
unanswerable and the landing page cannot be improved on evidence.

---

## 3. Routing details

### 3.1 Static rendering

Every marketing page exports `generateStaticParams` for both locales and sets
`export const dynamic = "force-static"`. The only dynamic content on the whole site is the
header's sign-in/back-to-app state, which is client-side and hydrates after paint.

### 3.2 Localized paths in practice

Links use `next-intl`'s `Link` from `createNavigation(routing)`, never a raw `<a href>`, so a
Hungarian page never links to an English path by accident.

### 3.3 `/` and unknown locales

- `/` → `middleware` negotiates from `Accept-Language` → `/hu` or `/en`. Hungarian wins ties.
- `/de/...` → 404 through `notFound()`, not a silent redirect (a soft-404 that returns 200 is
  an SEO liability).
- A logged-in user hitting `/` still gets the landing page (D-W2).

### 3.4 Trailing slashes and redirects

`trailingSlash: false` (Next's default) stays. Old inbound links to `/` expecting the
dashboard: none exist publicly, but the app itself links to `/dashboard` everywhere, so
nothing breaks.

---

## 4. Page inventory and what each page must do

| Page | Primary audience | Job | Primary CTA |
|---|---|---|---|
| **Home** | both | Explain in one screen that this is a coaching platform whose clients get a real, free app. Split immediately into two paths. | "Try it as a trainer — 14 days free" |
| **For trainers** | trainer | The revenue page. Client management, program builder, scheduling, calendar, chat, weekly reports, and the "your clients get Pro" line (D-M4). Product screenshots, not stock photos. | trial |
| **The app** | individual user | The consumer story: nutrition, workouts, cardio, watch, offline. | store badges |
| **Pricing** | trainer | The three tiers from D-M2, monthly/yearly toggle, the trial terms, mobile Pro as a small separate block, FAQ about billing. | trial |
| **FAQ** | both | Objection handling: what happens at trial end, what happens to my clients' data, is the client app really free, can I cancel, where is my invoice. | trial |
| **Download** | client | Store badges, the deferred-deep-link handoff for an invite (`69` §6), a QR code a trainer can show in person. | store |
| **Contact** | both | An email address and a form that posts to the existing mail infrastructure. No live chat. | — |
| **Legal** | — | ÁSZF, privacy, cookies (63 §5). Long-form MDX-free plain content, indexable. | — |

### D-W9 The home page is dual-audience, but the site is not

One hero, one sentence each for the two audiences, then an immediate fork. Everything below
the fork on the home page is trainer-weighted, because that is who pays. The consumer story
gets its own page rather than half the home page.

*Rejected: two separate home pages with a chooser.* An interstitial that makes every visitor
do work before seeing anything.

---

## 5. SEO

### 5.1 Metadata

Per-page `generateMetadata` producing: localized title and description, canonical,
`hreflang` alternates for `hu`/`en` plus `x-default` → `hu`, OpenGraph and Twitter cards.

`opengraph-image.tsx` per page using Next's `ImageResponse` — generated at build, so the
brand image is never a stale PNG someone forgot to re-export.

### 5.2 Structured data

JSON-LD, emitted from server components:

- `Organization` + `WebSite` on the home page.
- `SoftwareApplication` on the app page (with `applicationCategory: HealthApplication`,
  `offers` reflecting free + Pro).
- `Product` with three `Offer`s on the pricing page — prices must be generated from the same
  constant the page renders, never hand-written twice (§10.3).
- `FAQPage` on the FAQ page.

### 5.3 `sitemap.ts` and `robots.ts`

`src/app/sitemap.ts` lists every marketing route in both locales with `alternates`.
`robots.ts` allows the marketing tree and **disallows** `/dashboard`, `/admin`, `/superadmin`,
`/onboarding` — those are behind a login and have no business in an index.

### 5.4 Content requirements that are engineering constraints

- One `<h1>` per page, in the page's language.
- Every product screenshot has a real, translated `alt`.
- No text baked into images for anything that matters — a screenshot's *caption* carries the
  message.
- Hungarian copy is written in Hungarian, not translated from English. The English page is
  allowed to be a translation; the Hungarian one is the original.

---

## 6. Assets

- Product screenshots: real captures from the running app in both themes, exported at 2× and
  served as `next/image` with explicit dimensions. Stored in `web/public/marketing/`.
- Store badges: the official Apple and Google artwork, self-hosted (CSP `img-src 'self'`).
- No stock photography of people in a gym. If a human is needed, it is a real trainer with a
  release, or it is not there.
- Total image weight budget for the home page: **≤ 600 KB** after optimization (§8).

---

## 7. Analytics

Vercel Analytics custom events (cookieless, already installed):

| Event | Props | Answers |
|---|---|---|
| `cta_click` | `page`, `slot`, `audience` | which CTA produces trials |
| `pricing_view` | `interval` | do people flip to yearly |
| `pricing_plan_click` | `plan`, `interval` | which tier is actually chosen |
| `trainer_request_submitted` | `src` | funnel top |
| `store_badge_click` | `platform`, `page` | client acquisition path |

Server-side, `signupSource` (D-W8) is stored on the user at registration so trial→paid can be
attributed months later. That column is the join key between marketing and revenue; without
it §4's table is decoration.

---

## 8. Performance budget

Measured on the home page, mobile, Lighthouse CI in the pipeline:

| Metric | Budget |
|---|---|
| LCP | < 2.0 s (mobile, 4G throttle) |
| CLS | < 0.05 |
| First-load JS for `/hu` | **< 100 KB** gzipped |
| Total image bytes | < 600 KB |
| Lighthouse Performance / SEO / Accessibility | ≥ 95 / 100 / 100 |

The JS budget is the one that catches regressions: it fails the moment someone imports a
chart, a form library, or the API client into a marketing page. It is asserted in CI, not
watched by hand (63 §8.9).

---

## 9. Order of work

### Milestone M0a — make room

**Prompt 1 — Web: move `<Providers>` out of the root layout**
Root layout keeps html/fonts/theme-script/body. `Providers` is added to `(app)`, `(admin)`,
`(auth)` and `(superadmin)` layouts. No marketing code yet.
*Verify:* `npm run build && npm run test && npm run test:e2e` in `web/` — the existing
Playwright suite is the whole safety net for this refactor. Also confirm the toaster still
appears on a settings save, and the chat still resolves its host.

**Prompt 2 — Web: locale routing for the marketing tree**
`src/i18n/routing.ts` (`defineRouting`, localized `pathnames` from D-W4),
`src/i18n/navigation.ts`, `middleware.ts` with the scoped matcher, `src/app/page.tsx` →
locale redirect, an empty `(marketing)/[locale]/layout.tsx` and a placeholder home page.
*Verify:* a Vitest test over the matcher asserting `/dashboard`, `/admin/clients`,
`/api/...` and `/_next/...` do **not** match; a Playwright test that `/` with
`Accept-Language: hu` lands on `/hu` and with `en-US` on `/en`, and that `/dashboard` still
loads for a signed-in user.

### Milestone M0b — the pages

The design for M0b is done and lives in
[`design/Lifey Landing.dc.html`](design/Lifey%20Landing.dc.html) — frames **L01–L21**, mapped to
these prompts in [`68` §12.1](68-web-landing-design-plan.md). Two things to read before starting:
[`68` §12.2](68-web-landing-design-plan.md) lists where the canvas deliberately departs from the
written spec (the canvas wins), and **DV-5 is a defect in the canvas that Prompt 6 has to fix**,
not copy. Prompts 5 and 7 have **no frames yet** ([`68` §13](68-web-landing-design-plan.md)).

**Prompt 3 — Web: marketing shell (header, footer, layout, message files)** — frames **L01–L03**
`MarketingHeader` (sticky, language switch, theme toggle, sign-in/back-to-app client island —
the three header states are drawn in L02), `MarketingFooter` (nav, legal links, store badges,
language), the mobile sticky CTA bar in its three states (L03), `marketing.hu.json` /
`marketing.en.json`, and the shared section primitives from `68` §3. Take the token values from
**L01** rather than measuring the other frames.
*Verify:* both locales render the shell; Lighthouse on the placeholder home page already
meets the JS budget (§8) — check this now, while there is nothing on the page to blame.

**Prompt 4 — Web: home page** — frames **L04–L18, L21**
All sections from `68` §4, real copy in both languages (the Hungarian strings are in the
frames), real screenshots. The proof strip (L08) ships in its **fallback** form until there are
real numbers — both versions are drawn, and picking the numbers one early is `68` §4.3's whole
warning.
*Verify:* Lighthouse ≥ 95/100/100 mobile; axe pass; the JS budget assertion; a Playwright
test that both hero CTAs reach the right destinations with `?src=` attached.

**Prompt 5 — Web: for-trainers page** — **no frames yet** (`68` §13.1)
Composition from L10–L12's vocabulary; do not invent new components for it.
*Verify:* as Prompt 4, plus a check that every screenshot has a translated `alt`.

**Prompt 6 — Web: pricing page** — frames **L19–L20**
Plan constants in one module shared with the JSON-LD and (later) with the checkout call;
monthly/yearly toggle; trial terms; the mobile Pro block. **Fix `68` §12.2 DV-5 while
implementing**: L19's Studio card advertises "Több edző egy stúdióban", a feature that breaks
D-M2 and is explicitly deferred in `63` §6. Replace the bullet, and correct the frame in the
same change.
*Verify:* a unit test asserting the rendered prices and the JSON-LD `Offer`s come from the
same source (§10.3); Playwright over the toggle and the three plan CTAs; a review check that no
card claims a feature another tier lacks.

**Prompt 7 — Web: app + download pages** — **no frames yet** (`68` §13.2–13.3)
Store badges and the deep-link handoff described in `69` §6. **No QR** — withdrawn, `69` §6.3.
*Verify:* Playwright over the badge events; manual check of the deep link on a real device.

**Prompt 8 — Web: FAQ, contact, legal pages**
FAQ with `FAQPage` JSON-LD; contact form posting through the existing mail path; the three
legal documents.
*Verify:* Rich Results validation on the FAQ JSON-LD; a Playwright test that the contact form
shows a success state and rejects an empty email.

**Prompt 9 — Web: SEO plumbing**
`sitemap.ts`, `robots.ts`, `opengraph-image.tsx` per page, canonical/hreflang audit.
*Verify:* fetch `/sitemap.xml` in a test and assert every route appears in both locales with
alternates; assert `robots.txt` disallows the four authenticated trees.

**Prompt 10 — Web: attribution + analytics events**
The `lifey_attrib` cookie island, `signupSource` on register, the five events from §7.
*Verify:* a Playwright test that lands on `/hu/arak?utm_source=test`, clicks through to
register, and asserts the registration request body carries the source.

**Prompt 11 — Web: performance budget in CI**
Lighthouse CI + a first-load-JS assertion on the marketing routes, wired into the existing
GitHub workflow.
*Verify:* deliberately import `recharts` into the home page and watch CI go red; revert.

---

## 10. Edge cases

1. **A signed-in user on `/hu/arak`** must see "Back to app" and a pricing CTA that goes to
   `/admin/billing`, not to `/register`.
2. **A trainer who already has a subscription** clicking a pricing CTA lands on the billing
   page showing their current plan, never on a second checkout.
3. **Language switch on a deep page** must preserve the route, not dump the user on the home
   page — that is what `pathnames` is for, and it needs a test.
4. **Prices in two places.** The pricing page, the JSON-LD, the checkout call and `66`'s
   in-app paywall must all read one `PLANS` constant. Two hand-maintained copies is how a
   page ends up advertising a price that Checkout does not charge (§10.3 / 63 §8).
5. **Theme.** The marketing pages inherit the FOUC-prevention script, so a visitor with a
   light OS preference gets the light palette on first paint. `68` must therefore specify
   both themes for every section, not just the dark one.
6. **Print / reader mode** on the legal pages — plain semantic HTML, no layout tricks.
7. **A crawler on `/en/arak`** (an English visitor hitting the Hungarian path) → 404, and the
   `hreflang` graph must not point at it.

---

## 11. Non-goals (deferred)

- A blog or content marketing system (MDX pipeline, RSS).
- A public trainer directory or trainer profile pages — attractive, and a much bigger feature
  (moderation, SEO surface, personal data).
- Customer logos / testimonials until there are real ones to show.
- A/B testing (63 §6).
- Live chat, cookie banner, any third-party script (D-W7).
- Locale routing for the authenticated app (D-W3).

---

## 12. Test plan

| Layer | What |
|---|---|
| Vitest | middleware matcher scope; `PLANS` constant ↔ JSON-LD; attribution cookie logic |
| Playwright | locale negotiation on `/`; language switch preserving route; both hero CTAs; pricing toggle; contact form; signed-in header state; `/dashboard` unaffected by middleware |
| Lighthouse CI | budgets from §8 on home, for-trainers, pricing |
| axe | every marketing page, both themes, both locales |
| Manual | store deep link on a physical device; Rich Results test on FAQ + Product |

---

## 13. Suggested PR split

Prompt 1 alone (the refactor with the most blast radius and the least visible change).
Prompt 2 alone (first middleware in the project). Prompts 3–8 are one PR each and are
independently mergeable — an unfinished marketing tree simply has fewer pages, since nothing
in the app links to it until Prompt 3's footer exists. Prompts 9–11 close it out.

---

## 14. Risk checkpoints where a failure would be silent

1. **The middleware matcher widening.** Adding a locale or a path can accidentally pull
   `/dashboard` into the matcher; nothing errors, the app just gets slower and a redirect
   loop appears for one locale prefix. The matcher test in Prompt 2 must enumerate the
   authenticated trees.
2. **A client import creeping into a marketing page** — no error, just a page that ships the
   API client and drops 30 Lighthouse points. §8's CI assertion is the only thing that
   catches it.
3. **Stale prices** (§10.4).
4. **`hreflang` pointing at a non-existent localized path**, which quietly de-indexes one
   language. Asserted in the sitemap test.
5. **`robots.txt` allowing `/admin`.** Trainer workspace URLs in a search index — no error,
   real embarrassment.
6. **OG images generated from a font that fails to load at build**, producing a
   silently blank card. Assert non-empty output dimensions in the build.
7. **The attribution cookie set before consent exists.** It is first-party, no personal data,
   and documented in the privacy policy — but if D-W7 is ever reversed and a third-party
   pixel arrives, this cookie's legal basis changes with it. Re-read this line at that point.

---

## 15. After implementation

- Set `Status:`; update `docs/landing_page/README.md` and `docs/web/README.md`.
- `docs/web/01-feature-inventory.md` gains the marketing surface and the `(marketing)` group.
- `docs/web/04-frontend-architecture.md` §providers is now wrong — update it for D-W6, and
  add the middleware to the architecture doc.
- Add the marketing routes to the Playwright smoke suite's default run.
