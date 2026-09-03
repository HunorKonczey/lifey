# 72 – Landing Page & Monetization — Follow-up

Status: **F1 done bar Prompt 6 (blocked on company data) · F2 done**; F3–F6 proposed
Scope: web · mobile · backend · design · docs — the closing pass over `63`–`71`
Depends on: `63`–`71` (all implemented; `64` Prompt 12 partial, see §1)

This is the "what did we leave behind" document for `docs/landing_page/`. Everything in
`63`–`71` that shipped is listed in each doc's own landed notes; this one collects what did
**not** ship, what shipped differently from the design, and what shipped but has never been
verified against a real store, a real Stripe account or a real device — plus the defects found
by looking at the running product rather than at the plans.

Nothing here is large. It is one release-readiness pass, and roughly half of it is either a
one-line fix or a documentation update that should have travelled with the original change.

---

## 1. Current state

| Doc | Prompts | Real status |
|---|---|---|
| `63` monetization strategy | — | Decisions live; `Status:` header still says *proposed* |
| `64` billing backend | 12 | 11 done, **Prompt 12 half-done** (counter infra only; the 402 gate has no AI call path to sit in). Header still *proposed* |
| `65` web landing page | 11 | All done. Header still *proposed* |
| `66` trainer billing web | 10 | All done. Header still *proposed* |
| `67` mobile free/Pro | 11 | All done. Header correct (*done*) |
| `68` web design | — | Canvas L01–L21 delivered; 5 items in §13 never drawn; DV-5 fixed in code, not in the canvas |
| `69` mobile design | — | Canvas P01–P27 delivered; §13's 4 items open; DV-9 fixed in code, not in the canvas |

Milestones (`63` §9): **M0, M1, M2, M3, M4 are built**. **M5 (store & polish) does not exist
at all** — there is no store listing, no ASO text, no exported screenshot set, and both the ad
unit ids and the store product listings are still Google's/Apple's test placeholders.

### 1.1 How this list was produced

So that a reader knows which lines are measured and which are read off the code:

- **Measured.** `axe-core` (WCAG 2.0/2.1 A + AA) against all 11 HU marketing routes plus `/en`,
  in three variants (dark desktop, light desktop, light mobile) — 36 page loads, two distinct
  violations, both on `/hu/alkalmazas`. Full-page screenshots of every marketing page in
  dark/light × desktop/mobile. A throwaway Flutter widget test pumping `PaywallScreen` at
  `TextScaler.linear(2.0)` on a 390 × 844 view (no overflow; the crest does **not** hide).
- **Read off the code**, against `68`/`69`'s own spec tables: the ad slot, the range menu, the
  boundary row, the paywall structure, the entitlement gates, the routing/SEO plumbing.
- **Not verifiable in this environment, and therefore still open by definition:** anything
  needing a Stripe account, a store sandbox, a physical device, a deployed URL, or a Flutter
  run (the repo has no `windows/` desktop target, so there is no way to look at the real mobile
  UI here — the mobile findings below are code-vs-spec, not eyeball findings).

---

## 2. Key decisions

### D-F1 The 404 is a real marketing page, in both locales — Next's default is not acceptable

There is **no `not-found.tsx` anywhere in `web/src/app/`**. Every unknown URL under the
marketing tree — including the deliberate `notFound()` calls in
`(marketing)/[locale]/layout.tsx:27` and `(marketing-bare)/[locale]/layout.tsx:36` for an
unknown locale segment — renders Next.js's built-in black page with the English string
"This page could not be found." That page is unbranded, untranslated, has no way back, and
ignores the theme. It is the one page a first-time visitor is most likely to reach from a
stale link or a typo'd path.

Fix: a `(marketing)/[locale]/not-found.tsx` inside the marketing shell (so it keeps the header,
the footer and the theme), plus a minimal branded `app/not-found.tsx` for the root-level case
where no locale segment could be resolved at all. `68` §13 item 4 asked for exactly this and it
was never drawn; it is a wordmark, one line and two links, and needs no frame.

*Rejected: redirecting unknown paths to `/hu`.* A soft-404 that answers 200 is worse than an
ugly 404 — it pollutes the index and hides broken links from us (`65` §3.3 already decided this
for the locale case).

### D-F2 Store badges stop pretending to be icons until real artwork exists

`StoreBadges.tsx:37` renders `<span class="material-symbols-rounded">apple</span>`. **There is
no `apple` glyph in Material Symbols**, so the ligature fails and the font falls back to
literal text: the badge reads `APPLE App Store` in a stretched wide face, with the label
wrapping onto two lines at every size. It is visible in the footer of *every* marketing page,
on the app page hero and on the download page — i.e. on the one page an invited client lands
on. The `shop` glyph next to it is real, which makes the pair look accidental rather than
deliberate.

Fix: replace the Apple mark with an inline SVG path (`currentColor` fill, `aria-hidden` since
the label carries the name), keeping the layout identical. The component's own doc comment
already explains why the official trademarked badge artwork is not embedded yet — that
reasoning stands; this is about the placeholder being broken, not about swapping in the real
badge.

*Rejected: dropping the icon and shipping text-only badges.* Two labelled rectangles with no
mark do not read as store badges at all, and the download page is nothing but those two
buttons.

**✅ Landed, Prompt 2 — with one deviation from the paragraph above.** The replacement is
`phone_iphone`, a real Material Symbol, not an inline Apple-logo path. Writing this decision
down and then reading `StoreBadges.tsx`'s own header comment surfaced the better argument
against the logo: Apple's identity guidelines permit their mark only inside the official
"Download on the App Store" badge lockup, so a hand-drawn Apple glyph would be the same kind of
almost-official artwork the component already refuses to fake. A neutral real glyph is the
honest placeholder until M5 brings both official badges (Prompt 20). The canvas is the origin of
the bug and is now recorded as `68` §12.2 DV-11.

### D-F3 The banner ad's own furniture moves off the creative

`69` §4.4 requires two things on every banner: a 12 px "Reklám" label at the top-left, and a
remove-ads affordance at the top-right. `banner_ad_slot.dart` ships the second and **not the
first** — there is no such string in `app_hu.arb`/`app_en.arb` at all, so `69` §9's acceptance
criterion ("'Reklám' label and the remove-ads affordance present on every banner") is unmet.
Worse, the affordance it does ship is a `Positioned` `IconButton` inside a `Stack`, painted
**on top of the `AdWidget`** (`banner_ad_slot.dart:129-149`). Overlaying a control on a served
creative is the shape of thing AdMob's policies treat as an obscured ad and as an
accidental-click generator; it is a policy risk on top of a design one.

Fix: the slot becomes a two-row `Column` — a ~20 dp chrome row ("Reklám" left, remove-ads
button right, both on `surfaceContainer`), then the `AdWidget` at its natural height, untouched
and unobscured. The reserved height reported through `bannerAdSlotHeightProvider` grows by the
chrome row, which the FAB-clearance test from `67` Prompt 9 already asserts against.

### D-F4 60 % opacity on the locked range rows yields to WCAG AA

`69` §4.1 specifies the locked row's label "at 60 % opacity", and `statistics_screen.dart`'s
`_RangeMenuRow` implements it literally. Commit `1c252fd` removed exactly this pattern from 15
other places in the app after measuring 0.6–0.8 alpha secondary text at 2.9–3.9:1, i.e. below
AA — and this row was not in that sweep because it is `Opacity()` around a widget subtree
rather than an alpha'd colour, so the grep that found the others missed it.

Fix: full alpha, and let the `lock` glyph plus the row's own semantics label carry the "locked"
meaning — which is what `69` §8 ("no gate communicated by colour alone") wants anyway. The
design spec yields; record it as a deviation in `69` §11.2 rather than diverging silently.

### D-F5 The paywall's large-text adaptation keys off text scale, not screen width

`paywall_screen.dart:243` computes `compact` from `MediaQuery.sizeOf(context).width <= 320`
only. `69` §8 and frame P10 ask for two separate adaptations: 320 pt **width**, and 200 %
**text scale** ("benefits collapse to title-only, the crest hides, the CTA never truncates").
Measured: at `TextScaler.linear(2.0)` on a 390 pt device the screen renders with no overflow
exception (the `SingleChildScrollView` absorbs it) but the crest is still drawn at 72 px and
the benefit description lines are still present — the frame's behaviour is simply not
implemented, and no test covers it.

Fix: `compact` becomes `width <= 320 || textScaler.scale(15) >= 24` (~1.6× and up), and past 2×
the crest is not built at all. One widget test per branch.

### D-F6 The free AI allowance is 3/month, and config says so

`63` D-M5 and the delivered design (P13's "3/3" chip) both say **3 AI calls a month** on Free.
`backend/src/main/resources/application.yml`'s `free-ai-credits-per-month` defaults to **5**.
Nothing user-visible contradicts itself today only because no AI action screen exists yet
(`AiCreditChip` is mounted nowhere) — the day one does, the app shows 5/5 while the strategy
and the marketing story say 3.

Fix: default to 3. It stays config-driven (`64` §3.3), so raising it later is still a config
change, not a release.

### D-F7 The mobile end-of-onboarding upsell is dropped, not built

`69` §2 allows one selling surface we never built: a dismissible card at the end of onboarding.
`PaywallTrigger.onboarding` exists, has an ARB headline and a passing widget test, and is
referenced from nowhere.

Decision: **leave it unbuilt and record it as a non-goal.** A user who has not yet logged a
single meal has no evidence that Pro is worth 1 490 Ft; the triggers with real context
(`historyRange`, `aiCredits`, `adRemoval`) fire later on their own. Keeping the enum value
costs nothing and keeps the decision reversible.

*Rejected: deleting the enum value and its strings.* It is three lines and a translated string;
deleting it would turn reversing this into a real change instead of a one-screen one.

### D-F8 Statuses are part of the deliverable

Four of the seven plans still say `Status: proposed` after every prompt in them landed. The
same is true of `README.md`'s "19 still open" contrast note, which commit `1c252fd` closed. A
status line that lies costs the next reader a full re-audit — which is what produced this
document.

---

## 3. Findings register

Severity: **S1** = fix before the site is public / before store submission · **S2** = fix before
the first paying customer · **S3** = correctness of the record, or polish.

### 3.1 Web (`65`, `68`)

| # | Finding | Evidence | Sev |
|---|---|---|---|
| W1 | ✅ **Fixed (Prompt 1).** No `not-found.tsx`; every 404 was Next's default English page | `web/src/app/**` had no such file; verified by loading `/hu/nincs-ilyen-oldal` (404 + unbranded page) | S1 |
| W2 | ✅ **Fixed (Prompt 2).** The Apple store badge rendered the literal text "APPLE" | `StoreBadges.tsx:37`; was visible in the footer of every page, on `/alkalmazas` and `/letoltes`. Inherited from the canvas — now `68` §12.2 DV-11 | S1 |
| W3 | ✅ **Fixed (Prompt 3).** Light-theme contrast 3.92:1 on the app-page hero mock | `AppHero.tsx:87` and `:89` — `opacity-80` over `var(--secondary)`; axe `color-contrast`, desktop **and** mobile | S1 |
| W4 | ✅ **Fixed (Prompt 3).** The screenshot scroll-snap row was not keyboard-reachable | `AppScreenshotRow.tsx:42`; axe `scrollable-region-focusable` at mobile widths | S1 |
| W5 | ✅ **Fixed (Prompt 5).** Marketing e2e coverage was one spec | `web/e2e/` had only `pricing-page.spec.ts`; `65` §12 asked for locale negotiation, language switch preserving the route, both hero CTAs, the contact form, the signed-in header, `/dashboard` unaffected by the proxy | S2 |
| W6 | ✅ **Fixed (Prompt 4).** No accessibility check in CI | `web-ci.yml` ran lint/typecheck/vitest/build/js-budget/lhci; no axe anywhere, no Playwright, and `lighthouserc.js` covers `/hu` only | S2 |
| W7 | First-load JS ~275 KB on `/hu` vs `65` §8's 100 KB target; Lighthouse perf 93 / SEO 92 / LCP 3.16 s vs 95/100/2.5 s | `65` Prompts 3 and 11 landed notes; CI thresholds are calibrated to the measured numbers, not the targets | S2 |
| W8 | Four legal pages are drafted, not reviewed; the Impresszum's company-identity fields are explicit placeholders | `65` Prompt 8 landed notes; `/jogi/impresszum` renders them today | S1 |
| W9 | Structured data never validated with Google's Rich Results tool | needs a deployed URL (`65` Prompt 9) | S3 |
| W10 | `sitemap.xml` emits `hu`/`en` alternates but no `x-default` | verified against the running dev server | S3 |
| W11 | The pricing fine print promises "forintban vagy euróban … a számlázási országtól függően", but `lib/pricing.ts` carries HUF only and no page ever shows a EUR figure | `63` D-M2 lists EUR prices; nothing implements them | S2 |
| W12 | Hero/value-block "screenshots" are reproduced UI, not captures | accepted in `68` D-DW1; no seeded demo backend exists to capture from | S3 |
| W13 | `lifey://invite/<token>` never checked on a device with the app installed | `65` Prompt 7's own verify line | S2 |
| W14 | **`65` §10 edge case 7 is wrong about what the site does.** It predicts "a crawler on `/en/arak` → 404"; the shipped behaviour is a **307 to the canonical `/en/pricing`**, which next-intl's `pathnames` map produces for every cross-locale path | measured against the running app for `/en/arak`, `/hu/pricing`, `/en/edzoknek`; now asserted in `e2e/marketing/locale-routing.spec.ts`. The redirect is the better answer — the requirement behind that line (one piece of content, one URL) holds either way, and a redirect keeps the link usable. **Correct the doc, not the code** (`72` Prompt 16) | S3 |

### 3.2 Mobile (`67`, `69`)

| # | Finding | Evidence | Sev |
|---|---|---|---|
| M1 | ✅ **Fixed (Prompt 7).** No "Reklám" label on the banner, and the remove-ads button overlaid the creative | `banner_ad_slot.dart:120-152`; no such ARB key existed; `69` §4.4 + §9. Frame P15 drew this correctly all along — the implementation, not the design, was wrong | S1 |
| M2 | ⚠️ **Guarded (Prompt 11), not yet swapped.** The ids are still Google's test ids, but they are now one module, one checker script and one pinned test constant instead of four buried literals | `lib/core/ads/ad_ids.dart`, `tool/check_release_ad_ids.dart`, `test/core/ads/ad_ids_test.dart`. Real ids arrive in Prompt 20 | S1 |
| M3 | ✅ **Fixed (Prompt 10).** The sponsorship-ended notice (`69` §12.1) did not exist | no ARB strings, no dashboard card, no code path on the resolved source leaving `trainerSponsored` | S2 |
| M4 | ✅ **Fixed (Prompt 9).** 200 % text-scale adaptation not implemented | measured; see D-F5 | S2 |
| M5 | ✅ **Fixed (Prompt 8).** Locked range rows drew their label at 0.6 opacity | `_RangeMenuRow`; contradicted commit `1c252fd`'s app-wide rule | S2 |
| M6 | ✅ **Fixed (Prompt 8).** Plan cards were not semantic radios | `_PlanCard` drew the icons but carried no `Semantics(inMutuallyExclusiveGroup:, checked:)`; `69` §8 asks for "a single semantic radio" | S2 |
| M7 | `AiCreditChip` / `requireAiCredits` are built, tested and mounted nowhere | recorded deliberately in `gated_surfaces_test.dart`; blocked on `docs/23` | S3 |
| M8 | `PaywallTrigger.onboarding` is unreachable | see D-F7 — a decision once recorded, not a defect | S3 |
| M9 | `67` §11's manual row has never run: sandbox purchase on both stores, restore on a second device, UMP consent in an EU locale, a full offline→grace-expiry cycle | needs devices + store sandboxes | S1 |
| M10 | Chat-attachment tests fail on Windows — 2 to 4 per run, not a fixed 3: it is a file-lock race (`PathAccessException`), so the count varies | pre-existing, unrelated, documented in `67` §11 | S3 |

### 3.3 Backend (`64`, `66`)

| # | Finding | Evidence | Sev |
|---|---|---|---|
| B1 | `64` Prompt 12's gate half is unbuilt: no 402/`AI_CREDITS_EXHAUSTED`, no "a failed call doesn't burn a credit" guarantee | there is no AI call path to increment inside; `docs/23` is plan-only | S2 |
| B2 | Free AI allowance config default is 5, strategy says 3 | `application.yml` vs `63` D-M5 | S2 |
| B3 | Stripe has never been exercised against a real test-mode account — checkout, the consent checkbox, the portal, the webhook, a cancellation | `64` Prompt 4 and `66` §11's manual rows | S1 |
| B4 | Pro's 100/month fair-use ceiling (`63` D-M5 note 2) is enforced nowhere | deliberate — belongs to `AiFeatureGate`; tracked here so it is not forgotten | S3 |
| B5 | No runbook for `BillingReconciliationJob` corrections | `64` §15 asks for one | S2 |

### 3.4 Design canvases (`68`, `69`)

| # | Finding | Evidence | Sev |
|---|---|---|---|
| D1 | L19 still sells "Több edző egy stúdióban" | one occurrence in `design/Lifey Landing.dc.html`; fixed in `lib/pricing.ts`, never redrawn (DV-5) | S2 |
| D2 | P11 still draws two check marks | `design/Lifey Paywall.dc.html` marks both "7 nap" and "30 nap"; fixed in code, never redrawn (DV-9) | S2 |
| D3 | Never drawn: for-trainers page, app page, download page, the web state frames (form submitting/success/error, failed image, 404), the motion + open-questions addendum | `68` §13 items 1–5 | S3 |
| D4 | Never drawn: the sponsorship-ended card, the price-loading skeleton (built in code from the spec text) | `69` §13 items 2–3 | S3 |
| D5 | `68` §2.2–2.3's marketing type scale and `--mkt-*` tokens exist in neither `globals.css` nor `docs/web/06-design-system-web.md` — the shipped pages use Tailwind arbitrary values plus the app's own tokens | grep: zero `--mkt-` under `web/src` | S3 |

### 3.5 Documentation debt

Every one of these was on an "After implementation" checklist in `64`/`65`/`66`/`67`, and none
of them happened:

| # | Owed by | What |
|---|---|---|
| X1 | `63`–`66` | `Status:` headers still say *proposed* |
| X2 | `README.md` | The "19 still open" light-theme contrast instances were closed by `1c252fd`; two remain, both on `/hu/alkalmazas` |
| X3 | `64` §15 | `docs/05-backend-api.md` has no billing endpoints; `docs/postman/lifey.postman_collection.json` has no entitlement/checkout calls |
| X4 | `64` §15 | `docs/personal_trainer/03-backend-terv.md` has no `SeatLimitService` note |
| X5 | `65` §15 | `docs/web/01-feature-inventory.md` (marketing surface) and `docs/web/04-frontend-architecture.md` (D-W6's providers move, `src/proxy.ts`) both untouched |
| X6 | `66` §13 | `docs/personal_trainer/04-web-admin-terv.md` (`/admin/billing`, `/admin/pending`), `docs/personal_trainer/README.md` §2, `docs/web/07-screen-specifications.md` |
| X7 | `67` §14 | `docs/04-mobile-app.md` (free/Pro split), `docs/23-ai-calorie-estimation-plan.md` (credit gate), `docs/17-statistics-page-plan.md` (history window) |
| X8 | `68` DV-9 | `63` §5 still lists two legal documents; four shipped (ÁSZF, Adatkezelés, Elállás, Impresszum) |

---

## 4. Order of work

Six milestones. **F1 is the smallest thing worth shipping** — it is everything a stranger sees
on a public URL. F3 and F5 are the only ones that cannot be finished inside this repo.

### Milestone F1 — the site can be made public

**Prompt 1 — Web: branded 404 in both locales — ✅ done**
`src/app/(marketing)/[locale]/not-found.tsx` inside the shell (header, footer, theme) with a
wordmark, one line of copy and two links (home, pricing); plus `src/app/not-found.tsx` for the
no-locale case, defaulting to Hungarian. New keys in `messages/marketing.{hu,en}.json`.
*Verify:* `/hu/nincs-ilyen`, `/en/nope` and `/de/` all render the branded page and answer 404
(`curl -sI`); a Playwright assertion on the status code and the heading.

Landed as three files, not two — the third is the one that makes the other two reachable.
**`(marketing)/[locale]/[...rest]/page.tsx`**, a catch-all that does nothing but call
`notFound()`: without it, `/hu/nincs-ilyen-oldal` matches no route at all, and Next.js answers
an unmatched URL from the **root** `not-found.tsx` — nested not-found boundaries only catch a
`notFound()` thrown inside their own subtree, so the locale-aware page would never have
rendered. The catch-all is what puts the request inside the marketing subtree first.

Four request shapes, three of them exercised for the first time: an unmatched path under a
known locale (→ the shell 404, correct locale), an unknown locale segment (→ the root 404 in
Hungarian, because `[locale]/layout.tsx` throws from the *layout*, above its own boundary),
anything outside the marketing tree, and `/hu/letoltes/extra` — which lands on the `(marketing)`
catch-all even though `/hu/letoltes` itself lives in `(marketing-bare)`. That last one settles
§6's edge case 1 by construction rather than by a decision: a bare-group 404 cannot be reached,
so it is not built (edge case 1 corrected below).

Verified at both ends: `curl` against `next dev` and against a real `next build` + `next start`
(dev and prod can differ on status codes — Next's own docs note a streamed not-found response
answers 200), plus five Playwright cases in `e2e/marketing/not-found.spec.ts`. `next build`
also confirms the catch-all does not collide with the sibling route group: `/[locale]/[...rest]`
compiles as one dynamic route next to the existing static ones.

**Prompt 2 — Web: fix the Apple badge glyph — ✅ done**
A real glyph in `StoreBadges.tsx`. No layout change.
*Verify:* screenshots of the footer, `/alkalmazas` and `/letoltes` at 390 px and 1440 px; the
label no longer wraps onto two lines.

Landed as `phone_iphone` rather than the inline Apple SVG D-F2 originally proposed — see that
decision's own landed note for the trademark argument that changed it. Verified in full-page
screenshots at both widths, both themes: the badge pair now reads as a pair, and the label sits
on one line.

**Prompt 3 — Web: close the two axe violations on the app page — ✅ done**
`AppHero.tsx:87,89` — drop `opacity-80` (size and weight already carry the hierarchy, the same
fix `1c252fd` applied on mobile). `AppScreenshotRow.tsx:42` — `tabIndex={0}`, `role="group"` and
an `aria-label` on the scroller.
*Verify:* re-run axe over all 12 routes × 3 variants; zero violations.

Landed as specified, except the scroller is labelled by the section's own `<h2>`
(`aria-labelledby`) instead of a new `aria-label` string — the heading already says what the row
is, and a second copy of that sentence would be one more string to translate and keep in sync.
Re-ran axe over 12 routes × 3 variants (dark desktop, light desktop, light mobile): **0
violations**, down from 2.

**Prompt 4 — Web: axe in CI — ✅ done**
A Playwright spec loading every route in `routing.ts`'s `pathnames` (both locales, both colour
schemes via `colorScheme`) asserting `axe.run()` returns no WCAG 2.1 AA violations; wire
`npx playwright test` into `web-ci.yml` after the build step.
*Verify:* the job fails when `opacity-80` is put back on `AppHero.tsx:87`, and passes once
removed.

Landed as `e2e/marketing/accessibility.spec.ts` on a new `@axe-core/playwright` devDependency
(axe-core was previously only in the tree transitively, via Lighthouse — not something a CI gate
should rest on). Three notes worth keeping:

1. **The route list is derived from `routing.pathnames`, not hand-kept.** A new marketing page
   has to be registered there before it can be linked, so it is audited the day it exists —
   unlike `scripts/check-js-budget.mjs`, whose route list is a hand-maintained copy.
2. **Switching colour scheme needs a reload, not just `emulateMedia`.** The theme is decided
   before first paint by the inline script in `app/layout.tsx`; each route is therefore visited
   twice, once per scheme.
3. **CI needed a second Playwright project.** `playwright.config.ts` now has `chromium`
   (everything in `e2e/`, backend-dependent, local only) and `marketing`
   (`e2e/marketing/**`, no backend at all) — `web-ci.yml` runs `--project=marketing`.
   `e2e/pricing-page.spec.ts` moved into the folder, since it never needed a backend either.

The verify line was run for real: putting `opacity-80` back on `AppHero.tsx:87` fails the
`/hu/alkalmazas` case with `color-contrast (1)` naming that exact element, and removing it
passes. Full suite: **48 passed in 1.2 min.**

**Prompt 5 — Web: the six missing marketing e2e specs (`65` §12) — ✅ done**
Locale negotiation on `/`; language switch preserving a deep route; both hero CTAs carrying
their attribution param; the contact form's three states with the POST stubbed; the signed-in
header/CTA swap; `/dashboard` untouched by the proxy.
*Verify:* all six pass against `npm run dev` with no backend (the contact one stubs its route).

Landed as five spec files (`locale-routing`, `home-ctas`, `contact-form`, `signed-in-header`,
`not-found`) beside the accessibility one. Two things the writing of them turned up:

- **The signed-in state is testable without a backend after all.** `useSessionStore.initialize()`
  reads one `localStorage` key and exchanges it at `POST /auth/refresh`; seeding the key and
  stubbing that one endpoint with a hand-built JWT is a complete session as far as
  `HeaderAuthActions` and `PricingCards` are concerned. `65` Prompt 6 had skipped this coverage
  as needing "a real session"; it does not.
- **W14**: `/en/arak` does not 404 the way `65` §10 edge case 7 predicts — it 307s to
  `/en/pricing`. The spec asserts the real (and better) behaviour and points at W14; the doc
  gets corrected in Prompt 16.

Also covered beyond the six: first-touch attribution really surviving a later internal CTA
(D-W8's "first touch, not last touch", previously only unit-tested as a pure function).

**Prompt 6 — Web: legal content sign-off pass — ⛔ blocked on data, not on code**
Fill the Impresszum's company-identity fields with real values and give each of the four legal
pages a "last reviewed" date line. Content plus one code change.
*Verify:* no placeholder token remains anywhere under `(marketing)/[locale]/legal/`.

The placeholders are exactly five fields, in `legal.imprint.s1Body` of both message files —
**Cégnév, Székhely, Cégjegyzékszám, Adószám, Képviselő** (and their English twins). Nothing else
anywhere in the legal tree is a placeholder: the ÁSZF deliberately defers to the Impresszum for
provider identity, and the hosting-provider section already names Vercel with a real address.
These five are company-registry facts — inventing them would put a false legal record on a
public page — so this step waits for the values. The "last reviewed" line is deliberately part
of the same step: adding it before a human has actually reviewed the four documents would make
the page claim a review that did not happen.

### Milestone F2 — the app is honest about its ads and its limits

**Prompt 7 — Mobile: banner slot chrome row — ✅ done**
Two-row layout per D-F3: "Reklám" label + remove-ads button above the creative, nothing painted
over the `AdWidget`; one new ARB key; `bannerAdSlotHeightProvider` reports the taller slot.
*Verify:* `banner_ad_slot_test.dart` gains a label assertion and a "no widget overlaps the
AdWidget's rect" assertion; the existing FAB-clearance test still passes.

Landed as a `Column` (chrome row, then the creative) plus a new public `BannerAdChrome` widget —
public because the loaded slot contains a real platform-view `AdWidget` that no widget test can
pump, so the furniture had to be testable on its own.

**The canvas was right and the code was wrong.** Frame P15 draws exactly this: a row with a
12 px muted "Reklám" left and a 24 px `block` glyph in a 44 × 28 target right, above the 50 dp
creative, on `surfaceContainer` with a 1 px top hairline. `67` Prompt 9 had implemented it as a
`Stack` with the button over the ad and no label at all. So the row's height is not a guess
either — 32 dp (4 dp padding + a 28 dp row), read off the frame.

Three things worth knowing:

1. **`bannerSlotHeight(adHeight)` now lives in `nav_reserved_space.dart`** next to the other
   layout math, and `onAdLoaded` reports *that* number. Everything that pads content or places a
   FAB reads it, so the chrome row can never be what puts a FAB on top of an ad — asserted in
   `nav_reserved_space_test.dart`.
2. **The button needs `tapTargetSize: MaterialTapTargetSize.shrinkWrap`.** Material's default
   48 dp minimum would have grown the *touch* area back down over the creative — an invisible
   version of the exact problem this prompt removes. There is a test comparing the button's rect
   to the chrome row's for that reason.
3. **The visible label is wrapped in `ExcludeSemantics`.** The slot's own `Semantics` container
   already announces "Hirdetés"; without the exclusion a screen reader reads the ad twice.

One deliberate deviation from P15: the creative keeps the full slot width rather than the
frame's 10 dp side margins and 8 dp radius. The adaptive banner size is requested *from* the
screen width, so insetting it would mean asking for one size and rendering another.

**Prompt 8 — Mobile: locked-row and plan-card accessibility — ✅ done**
Full alpha on `_RangeMenuRow`'s label (D-F4); `Semantics(inMutuallyExclusiveGroup: true,
checked: …)` around each `_PlanCard` (`69` §8).
*Verify:* a widget test reading the semantics tree for both; record the `69` §4.1 deviation in
that doc's §11.2.

Landed, and the locked row turned out to carry a second defect the audit had missed: its
`Semantics(label: "90 nap — Pro szükséges")` **merged with** the child `Text`, so a screen reader
read "90 days — Pro required, 90 days". The reason has to *replace* the row's own text, so a
locked row is now wrapped in `ExcludeSemantics` — the same shape as the ad label above. The tests
assert the exact announced label for both locked rows, and that no `Opacity` reappears inside a
menu row. `69` §11.2 gained DV-14 for the opacity deviation.

**Prompt 9 — Mobile: paywall at 200 % text scale — ✅ done**
`compact` becomes scale-aware; past 2× the crest is not built.
*Verify:* widget tests at `TextScaler.linear(1.0)` and `2.0` asserting crest presence and the
absence of benefit description lines; no overflow at 320 pt × 2.0.

Landed as two thresholds measured off `textScaler.scale(15)` — the sub-line's own rendered size,
which is the number that actually decides whether the column fits — rather than a raw scale
factor: at `>= 24` the benefits collapse to titles and the crest shrinks (the same treatment
320 pt width gets), at `>= 30` the crest is not built at all.

The CTA needed its own fix, which neither threshold covers: it was a fixed-height `SizedBox(56)`,
so a wrapped label was clipped instead of making the button taller. It is a
`ConstrainedBox(minHeight: 56)` now, label centred and wrapping. Its test runs at **320 pt ×
2.5** — at the default 800 pt test surface the label still fits on one line and the assertion
would have passed against the old code too, which is worth remembering before trusting any
large-text test that does not also narrow the screen.

**Prompt 10 — Mobile: the sponsorship-ended card (`69` §12.1) — ✅ done**
A dismissible dashboard card shown once when the resolved source stops being
`trainerSponsored` **and** the 7-day grace has elapsed; three ARB strings; dismissal persisted
the way the other dashboard cards do it. No push, no modal, no paywall redirect.
*Verify:* a widget test driving the entitlement sponsored → free and asserting the card appears
once and stays dismissed.

Landed as `core/entitlements/sponsorship_notice.dart` (the rule, two `shared_preferences` flags
and the controller) plus `features/dashboard/presentation/widgets/sponsorship_ended_card.dart`,
mounted just under the onboarding banner.

The rule is a pure function, `sponsorshipNoticeActionFor`, and the interesting part is what it
deliberately does **not** key off:

- not "the trainer relationship ended" but "the resolved entitlement is no longer Pro" — a client
  inside the 7-day grace still has Pro, and telling them it is gone while it demonstrably works
  is this document's own §6 edge case 5;
- not an unresolved snapshot, which fails open reporting `tier: pro` (D-P4) and would otherwise
  fire the notice on every cold start before the first refresh;
- and it stays **silent** when a former sponsee is Pro through their own purchase — nothing was
  lost, so there is nothing to explain.

`Entitlement.decayedToFree` (the offline expiry of that same grace) resolves to `tier: free`, so
it lands in the same branch, which is right: from the user's side it is the same event. Eleven
tests cover the rule's branches, the pending flag surviving a process restart, and dismissal
being permanent; three more cover the card — including that it carries **no CTA at all**, since
the reassurance is the point and the paywall is reachable again from its normal entries.

**Prompt 11 — Mobile: make the test ad ids un-shippable — ✅ done, by a different mechanism**
Move the four ids behind `--dart-define` values with the test ids as debug-only defaults, and
add a test that fails in release mode when an id still starts with `ca-app-pub-3940256099942544`.
*Verify:* `flutter test`; a release build with no define fails the assertion.

The first half landed as written: `lib/core/ads/ad_ids.dart` holds all four unit ids as
`String.fromEnvironment` values with Google's test ids as defaults, so a plain `flutter run`
still needs no setup, and neither widget carries a string literal any more.

**The second half cannot work as specified**, and shipping it anyway would have meant a gate that
never fires: `assert` is stripped from release builds, so an assertion can never fail in the mode
it exists to protect. A real runtime check would have to either crash a production app on launch
or silently disable ads — a different silent failure. And two of the six ids are **app** ids in
`AndroidManifest.xml`/`Info.plist`, which no Dart define reaches at all.

The gate is therefore two pieces:

1. **`tool/check_release_ad_ids.dart`** — run before shipping, with the same `--dart-define`s as
   the release build. It checks all six (four defines plus both native manifests) and exits 1
   naming every one still on Google's test publisher.
2. **`test/core/ads/ad_ids_test.dart`** — pins today's state in one constant,
   `kAdIdsAreStillTestIds = true`, and fails when reality stops matching it. The day real ids
   land, that test fails and forces whoever swapped them to flip the constant deliberately — the
   same "a change to enumerated state must be an explicit edit" mechanism as
   `gated_surfaces_test.dart` (D-P7). It catches the reverse too: a quiet revert to test ids.

The script is what Prompt 20 runs when the real ids arrive.

### Milestone F3 — the money paths are verified against the real providers

Nothing here can be done in this repo; each step is a scripted manual run whose output is pasted
back into the plan it verifies.

**Prompt 12 — Backend: one Stripe test-mode round trip**
Real test keys in a local profile, the six Prices created in the dashboard, then: checkout
(assert `client_reference_id` and that the consent checkbox renders), the webhook via the Stripe
CLI, the portal, a cancellation, and an over-limit downgrade.
*Verify:* the `subscription` row at each step; `64` Prompt 4's and `66` §11's manual rows tick.

**Prompt 13 — Mobile: the store sandbox matrix (`67` §11)**
Sandbox purchase on both stores; restore on a second device; UMP consent in an EU locale; an
offline → grace-expiry cycle with the device clock moved forward.
*Verify:* the four rows in `67` §11 stop being aspirational.

**Prompt 14 — Backend: AI credit default + the gate's other half**
Default `free-ai-credits-per-month` to 3 (D-F6). The 402/`AI_CREDITS_EXHAUSTED` gate and the
"a failed call doesn't increment" guarantee land with `docs/23`'s meal-estimation feature, not
before — this step's deliverable is the config change plus a section in `docs/23` naming exactly
where `AiUsageCounterService.recordUsage` must be called and what must happen on a failed LLM
call.
*Verify:* the existing `EntitlementServiceImplTest` cases pass against the new default; the
`docs/23` section names the class and the transaction boundary.

### Milestone F4 — the record matches reality

**Prompt 15 — Docs: statuses and the README**
`Status:` on `63`–`66`; `README.md`'s contrast paragraph corrected to the measured state; this
document added to the reading-order table.
*Verify:* read it back against §1 of this doc.

**Prompt 16 — Docs: the seven downstream documents (X3–X8)**
One commit, small edits: API doc, Postman collection, trainer backend/admin plans, web
inventory/architecture/screen specs, mobile app doc, `docs/23`, `docs/17`, and `63` §5's legal
list.
*Verify:* each file mentions the thing it was supposed to gain — e.g. `grep -i billing
docs/05-backend-api.md` returns hits.

**Prompt 17 — Design: correct the two canvas defects**
Redraw L19's Studio bullet to match `lib/pricing.ts`, and P11 with one check mark. Both are
already fixed in code; this closes the drift so the canvases stay trustworthy as references.
*Verify:* grep both `.dc.html` files for the offending strings.

### Milestone F5 — store & polish (`63` M5)

**Prompt 18 — Design: export the store screenshot set**
P18–P25 exported per platform and per language (6 phone frames × 2 languages × 2 platforms,
plus the 1024 × 500 Play feature graphic).

**Prompt 19 — Store: listings and ASO text**
Title, subtitle, keywords, description and promo text in both languages (`69` §5.2), the privacy
policy URL, Apple's privacy nutrition labels and Play's Data Safety form — both of which must
declare AdMob and the entitlement calls.

**Prompt 20 — Web + mobile: swap the placeholders once the listings exist**
Real store URLs into `StoreBadges.tsx` (`variant="disabled"` becomes `"link"`), real AdMob ids
through Prompt 11's defines, and the device check of `lifey://invite/<token>` — noting the token
is deliberately inert on the app side (the invite matches server-side by e-mail, `69` D-DM5;
`app_router.dart`'s `onException` sends an unmatched `lifey://` link to `/dashboard`), so the
check is "the app opens and lands on login/dashboard", not "the invite is consumed".

### Milestone F6 — performance budget (optional, `65` §8)

**Prompt 21 — Web: root-layout JS reduction**
`@next/bundle-analyzer` over the root layout, then defer `<Analytics>`/`<SpeedInsights>` behind
an idle callback and re-measure. The marketing pages themselves add ~16 KB; the rest is the
shared baseline `/login` already paid before this work started.
*Verify:* `npm run check:js-budget` plus one `lhci` run; if `/hu` clears 100 KB, the thresholds
in `lighthouserc.js` and `check-js-budget.mjs` tighten in the same commit.

---

## 5. Non-goals (deferred)

- The end-of-onboarding upsell card (D-F7).
- Enforcing Pro's 100/month AI fair-use ceiling (B4) — it belongs to `AiFeatureGate`.
- Redrawing the frames `68` §13 items 1–3 and `69` §13 ask for. The pages ship; a frame after
  the fact is documentation, and this plan would rather spend the design budget on M5.
- EUR pricing as a second displayed currency (W11) — the fix in scope is making the fine print
  true, not building currency negotiation.
- Rewarded ads, referral, NAV e-invoicing, team seats — already deferred in `63` §6.
- The three Windows-only chat-attachment test failures (M10).

---

## 6. Edge cases

1. ~~**The 404 inside `(marketing-bare)`.**~~ **Settled by construction, Prompt 1.** The worry
   was that the chrome-free download page would need a chrome-free 404 of its own. It cannot
   have one: `(marketing-bare)` has no catch-all, so `/hu/letoltes/anything` is matched by the
   catch-all in `(marketing)` and gets the normal shell 404. A bare not-found file would be
   unreachable dead code, so none was written — asserted in `not-found.spec.ts` rather than left
   as a comment.
2. **A 404 with no resolvable locale** (`/de/whatever`, `/random`). Falls to the root
   `not-found.tsx` in Hungarian — the default locale, not the browser's.
3. **The banner chrome row on a failed ad load.** The slot renders nothing at all when there is
   no ad (`69` P17); the chrome row must live inside that same conditional, or a free user with
   no fill sees an empty "Reklám" strip.
4. **A user at 200 % text scale on a 320 pt device.** Both branches of D-F5 fire at once; the
   CTA label is the one thing that may never truncate.
5. **The sponsorship-ended card firing during the grace period.** It must key off grace expiry,
   not off the relationship ending, or a client whose trainer is mid-renewal is told their Pro
   is gone while it still works.
6. **Store ids swapped in one place only.** The AdMob App ID lives in two native manifests and
   the unit ids in two Dart files; Prompt 11's assertion has to cover all four, or a release can
   ship half-real.

---

## 7. Test plan

| Layer | What |
|---|---|
| Playwright (web) | The six `65` §12 specs; the 404's status code and copy in both locales; axe over every route × both colour schemes |
| Vitest | none new — F1's fixes are markup-level |
| Flutter widget | banner chrome row + no-overlap assertion; locked-row semantics and alpha; plan-card radio semantics; paywall at 1× and 2× text scale; the sponsorship-ended card's once-only behaviour |
| Flutter structural | `gated_surfaces_test.dart` unchanged (no new gate); the release-id assertion from Prompt 11 |
| Backend | `EntitlementServiceImplTest` against the new default of 3 |
| Manual | Stripe test-mode round trip (Prompt 12); the store sandbox matrix (Prompt 13); the invite deep link on a real device (Prompt 20); Rich Results against a deployed URL |

---

## 8. Suggested PR split

Prompts 1–3 are one PR (three small, independent, visible fixes on the marketing tree).
Prompts 4 and 5 are one PR each — both change CI runtime and will need their own flakiness
triage. Prompts 7–11 are one PR each; Prompt 7 changes a layout constant other tests depend on,
so it merges alone. Prompts 15–17 are one docs PR. F3 and F5 are not PRs at all until someone
has the accounts and the devices; each of their steps ends by editing the plan it verifies.

---

## 9. Risk checkpoints where a failure would be silent

1. **The banner chrome row swallowing the ad's height.** If the slot keeps reporting its old
   height to `bannerAdSlotHeightProvider`, the FAB overlaps the ad on the dashboard — no error,
   and only on the one screen that has a FAB.
2. **A release built with the test AdMob ids.** Zero revenue, no error, indistinguishable from
   "ads aren't converting" for as long as nobody opens the console. Prompt 11's assertion is the
   only thing that catches it.
3. **axe in CI running against the wrong colour scheme.** Both violations found here are
   light-theme-only; a suite that checks dark alone passes forever while the light theme rots —
   the same trap `1c252fd` documented for Lighthouse.
4. **The 404 answering 200.** A `not-found.tsx` reached by a redirect instead of by `notFound()`
   returns 200 and quietly poisons the index.
5. **The sponsorship-ended card keyed to the wrong event.** Fires during grace → paying
   trainers' clients are told their Pro is gone; fires never → features disappear with no
   explanation. Both are silent.
6. **The AI credit default changed in config but not in the copy.** If `docs/23`'s feature ships
   reading a different constant, the chip and the strategy disagree and only a user notices.
7. **Redrawing a canvas frame without re-reading the code it was corrected against.** DV-5 and
   DV-9 were both fixed in code first; a redraw that "restores" the original design silently
   reintroduces a phantom feature and a two-check menu.

---

## 10. After implementation

- Set `Status:` here and on `63`–`66`; update `docs/landing_page/README.md`'s status paragraph
  and reading-order table (Prompt 15 does both).
- Fold X3–X8's edits into their target documents (Prompt 16) — after which
  `docs/landing_page/` owes nothing to the rest of `docs/`.
- Re-run the two measurements this document rests on (axe over every route; the paywall at 2×
  text scale) and paste the numbers into §1.1, so the next reader can tell how stale this page
  is without redoing the audit.
