# 70 – Landing Page & Paywall: design prompt (for Claude Design)

> **What this file is:** a self-contained brief for designing the **web landing page** and the
> **mobile paywall / upsell surfaces** in one canvas set. **§0 is the prompt — paste it as
> is**; §1–§7 are appendices, handed over in the same conversation. The **decision log** at the
> end is *outside* the prompt; the designer does not need it.
>
> Technical background: [63-monetization-strategy-plan.md](63-monetization-strategy-plan.md)
> (tiers, funnel), [65-web-landing-page-plan.md](65-web-landing-page-plan.md) (routing, pages,
> budgets), [66-trainer-billing-web-plan.md](66-trainer-billing-web-plan.md) (billing screens),
> [67-mobile-free-pro-plan.md](67-mobile-free-pro-plan.md) (gates, triggers).
> Design specifications: [68-web-landing-design-plan.md](68-web-landing-design-plan.md) (web,
> section by section), [69-mobile-paywall-design-plan.md](69-mobile-paywall-design-plan.md)
> (mobile, store, download page).
> Design foundations: [../design/18-design-system-prompt.md](../design/18-design-system-prompt.md)
> (mobile tokens), [../web/06-design-system-web.md](../web/06-design-system-web.md) (web tokens),
> `../design/design-handoff/design-terv-kidolgoz-sa/project/Lifey Web.dc.html` (the existing web
> canvas — the marketing frames continue its visual language, not its density).
>
> **Status: both halves have run — this file is history.** The web half ran from here; the
> mobile half ran from [`71`](71-mobile-paywall-design-prompt.md), which superseded §3/§4/§6.
> Neither half should be re-run from this file.
> [`design/Lifey Landing.dc.html`](design/Lifey%20Landing.dc.html) — **L01–L21**, the marketing
> web canvas. Frame map and the deviations from the spec:
> [68 §12](68-web-landing-design-plan.md). The **`Lifey Paywall.dc.html` (P01–P27) canvas** was
> produced from [`71`](71-mobile-paywall-design-prompt.md) instead of from §0/§3/§4/§6 here —
> those had gone stale on three points (the QR, the 30-day history window, and two UI
> assumptions that did not match the code). Its frame map is
> [69 §11](69-mobile-paywall-design-plan.md).
>
> **Also still outstanding from §0/§5/§7, on the web side:** the for-trainers, the app and the
> download page frames; the form/failed-image/404 state frames; and the motion-notes + open-
> questions closing sections. The rerun brief for these is [68 §13](68-web-landing-design-plan.md).

---

## 0. The prompt (hand this over as is)

Design the **public marketing site** and the **in-app purchase surfaces** for **Lifey**, an
existing fitness and nutrition app with a personal-trainer workspace. This is not a new brand
— the product exists, has a design system, and you are extending it outward to the people who
have not installed it yet.

**The business, in three sentences.** Personal trainers pay for a web workspace where they
manage clients, write multi-week programs, schedule sessions, chat, and see their clients'
real logged data. Their clients use the mobile app for **free**, and while their trainer pays,
those clients get the ad-free Pro version at no cost. Someone with no trainer uses the app
free with ads and can buy Pro themselves.

**The primary market is Hungary; Hungarian is the default language, English is second.**
Design every text slot against the **Hungarian** string — it runs 20–35 % longer than English.
Provide both languages for the hero and at least one full section.

**Who you are designing for.**
- The **trainer** (pays): 25–45, runs their coaching on a phone's notes app and a spreadsheet
  today, has 5–30 clients, is sceptical of software that will make more work. Wants to see
  that this replaces the spreadsheet, not that it is "AI-powered".
- The **client** (does not pay): downloads the app because their trainer asked. Needs to
  believe the app is good on its own.

**What you are designing.**

*Web (desktop + mobile browser, both themes):*
1. Home page — 12 sections (§2).
2. For-trainers page — the revenue page.
3. Pricing page — three plans keyed to **active client count**, monthly/yearly toggle.
4. The app page — the consumer story.
5. Download page — sparse, opened on a phone next to a trainer.
6. Marketing header + footer + mobile sticky CTA bar.
7. Empty/error/success states listed in §5.

*Mobile (Flutter, dark and light):*
8. Paywall screen — one layout, five headline variants, four special states (§3).
9. Locked statistics range chips + the history boundary row.
10. The AI credit chip.
11. The banner-ad slot, in context on the dashboard (showing it must not collide with the FAB).
12. The Settings subscription tile, four states.
13. App Store / Google Play screenshot set — 6 frames, dark, Hungarian and English captions.

**Design constraints — these are not preferences.**

- **Use the existing tokens.** Dark-first brown-green: background `#161611`, surface `#1C1E16`,
  container `#22241B`, primary olive `#9DAE6B`, secondary tan `#C49A6C`, tertiary green
  `#6E9A6A`, text `#F1F0E4`, variant `#A8A899`, muted `#918B7A`, outline `#3C3E32`. Light
  theme: bg `#F3F2E8`, surface `#FFFFFF`, primary `#586E38`, secondary `#8A6A42`, tertiary
  `#4A7A52`, text `#1E1F18`, outline `#CDCBBC`. Radii 8 / 16 / 20 / 24 / 28 / pill. Font: Plus
  Jakarta Sans 400–800. Icons: Material Symbols Rounded, filled for active/emphasis.
- **Exactly two accent colours on the marketing site**: olive `primary` for everything
  trainer-facing, tan `secondary` for everything client-facing. The reader should be able to
  tell who a section is talking to from the accent alone.
- **Product screenshots carry the page.** No illustrations, no stock photography, no 3D, no
  mascot. Where you need a visual, it is a framed screenshot of the real product or a piece of
  real product UI shown at marketing scale.
- **Both themes, for every frame.** A visitor with a light OS preference sees light on first
  paint. A section that only works in dark is not finished.
- **One motion pattern**: fade-up 16 px on first viewport entry, 60 ms stagger, played once.
  No parallax, no scroll-jacking, no animated counters, no looping anything. Everything must
  render in its final state under `prefers-reduced-motion`.
- **No urgency theatre.** No countdown timers, no "only today", no fake scarcity. The offer is
  14 days free without a card; that is enough.
- **The paywall is not a special world.** Same tokens, same radii, same type scale as the rest
  of the app. No gradients, no gold, no confetti.
- **Free must never look broken.** Every gated thing is *marked*, never removed: a locked
  range chip stays in place, the history list ends with a boundary row (never a blurred fake
  list), the AI action keeps a credit counter.
- **Accessibility is a constraint, not a pass.** ≥ 4.5:1 contrast for every text/background
  pair in *both* themes; ≥ 44 × 44 px tap targets; visible focus rings; the paywall usable at
  200 % text scale and at 320 pt width; no state signalled by colour alone.

**Marketing type scale** (an extension above the app's scale, which tops out at 34 px):
display 64/36 (desktop/mobile) at 800 weight for the hero only; headline 44/28 at 700;
title 28/22 at 700; lead 20/17 at 500; body and below as in the app. Letter-spacing −0.02em on
display and headline. Numbers always `tabular-nums`.

**Grid**: 1200 px / 12 col / 32 gutter / 120 px section padding (desktop); 8 col / 24 / 96
(tablet); 4 col / 16 / 72 (mobile). Body text max 62 ch; hero headline max 18 ch so it wraps
by itself.

**What the site must communicate, in priority order.**
1. A trainer can run their whole coaching practice here.
2. Their clients get a genuinely good, free, ad-free app out of it.
3. It costs less than one client session per month.
4. Trying it takes 14 days and no card — but access is reviewed by hand, usually within a
   working day, and the trial starts on approval. **Say this plainly**; do not hide the wait
   behind a spinner.

**What it must never look like**: a crypto product, an AI product, a hustle-culture fitness
brand, or an enterprise SaaS. It is a working tool for someone who trains people for a living.

**Deliverables**: see §7.

---

## 1. Appendix — the pricing table (exact numbers)

| Plan | Active clients | Monthly | Yearly |
|---|---|---|---|
| Trial | 25 | free, 14 days, no card | — |
| Starter | 5 | 4 990 Ft / €12.90 | 49 900 Ft / €129 |
| Pro *(recommended)* | 25 | 12 990 Ft / €32.90 | 129 900 Ft / €329 |
| Studio | unlimited | 24 990 Ft / €64.90 | 249 900 Ft / €649 |

**All three plans contain every feature.** The differentiator is the client count, so the
**seat number is the headline number on each card** — larger than the price. Yearly is
pre-selected and carries a "2 hónap ingyen" badge.

Mobile Pro, shown as a small subordinate block on the pricing page only: 1 490 Ft/month,
11 900 Ft/year.

Fine print that must appear under the cards: prices in HUF or EUR depending on billing
country; VAT; the 14-day EU withdrawal right.

---

## 2. Appendix — home page sections, in order

1. **Hero** — 7/5 split desktop. Eyebrow, display headline, lead, primary + secondary CTA,
   and a reassurance line: *"14 nap ingyen · bankkártya nélkül · a klienseidnek ingyenes az
   app"*. Right: a framed desktop `/admin` screenshot with a phone screenshot overlapping its
   lower-left. Do not force 100 vh — the next headline must peek at 800 px height.
2. **The fork** — two large cards, "Edző vagy?" (olive) and "Edződ van, vagy egyedül edzel?"
   (tan), each with one sentence and its own CTA.
3. **Proof strip** — four numbers. *There are no real numbers yet*: design both the numbers
   version and the fallback (a single line of copy at lead size).
4. **"Minden kliensed egy helyen"** — client list + client detail screenshots.
5. **"Programot írsz, nem táblázatot"** — program builder + schedule drawer.
6. **"Nem tűnnek el két edzés között"** — chat + weekly report.
7. **The sponsored-Pro band** — the most important commercial section: *"A klienseid
   reklámmentes Pro appot kapnak — a te előfizetéseddel."* One image showing the same
   dashboard with and without an ad banner.
8. **How it works** — three numbered steps; step 1 states the manual review honestly.
9. **Feature grid** — 9 cards: calendar, statistics, personal records, cardio + GPS, watch
   app, offline, HU/EN, Apple Health / Health Connect, widgets.
10. **Pricing preview** — the same three cards as the pricing page, fine print omitted.
11. **FAQ preview** — five accordion rows.
12. **Final CTA** — headline, one button, the reassurance line. Nothing else.

Sections 4–6 alternate screenshot side on desktop; on mobile the copy always comes first.
Backgrounds alternate between `bg` and `surface-container`.

---

## 3. Appendix — the mobile paywall

**One layout.** Top to bottom: close (44 px, top-left, first in focus order) · 72 px
`workspace_premium` crest on a tertiary-container circle · headline 28/700 · sub 15/500 ·
three benefit rows (*Nincs reklám · Teljes előzmény · Korlátlan AI*, the one matching the
trigger highlighted with a container background) · two stacked plan cards (yearly
pre-selected, "2 hónap ingyen" pill, per-month equivalent below) · full-width 56 px pill CTA
reading "Előfizetés — {ár}" · legal line at 11/500 with terms + privacy links · "Vásárlások
visszaállítása" text button.

**Five headline variants:** locked history range · AI credits exhausted · remove ads ·
opened from Settings · end of onboarding.

**Four special states, each its own frame:**
- **Sponsored** — "A Pro-t az edződ állja": tan crest, the three benefits shown as already
  active with green checks, no plan cards, no purchase button, one "Rendben" button.
- **Products unavailable** — greyed crest, one line, a retry button. Never a made-up price.
- **Purchase pending** (bought offline) — an info card above the CTA.
- **Already Pro** — "Aktív előfizetésed van" + a "Kezelés" button.

Also design it at **320 pt wide** and at **200 % text scale**.

---

## 4. Appendix — the gated surfaces and the ad slot

- **Locked range chip**: the existing chip + a 14 px lock glyph, label at 60 % opacity, outline
  border. Same press feedback as an unlocked chip.
- **History boundary row**: full-width container card at the cutoff — history glyph, *"Régebbi
  adataid megvannak — a Pro megmutatja"*, chevron. The list simply ends there. **No blur, no
  fade-out, no fake rows.**
- **AI credit chip**: pill, `tabular-nums`, "3/3" → tan at 1 → error-toned at 0.
- **Banner ad slot** (design it in context on the dashboard): container background behind the
  ad, 1 px hairline on top, a 12 px "Reklám" label top-left, a 24 px `block` remove-ads icon
  top-right with a 44 px target. Sits above the bottom navigation, inside the safe area.
  **Show explicitly that it does not collide with the FAB.** Also design the state where there
  is no ad: the slot has zero height, no hairline, no label.
- **Settings subscription tile**, four states: free · Pro (own, with renewal date) · Pro
  (sponsored, no CTA) · trainer trial (days left).

---

## 5. Appendix — states that must not be skipped

Web: form submitting / success / error · failed image (frame with alt text, never a broken
icon) · signed-in header ("Vissza az appba" instead of "Belépés") · a trainer who already has
a plan (pricing CTA reads "Csomag kezelése") · reduced motion · 404, both locales · the mobile
sticky CTA bar hidden while the footer is visible and while an input is focused.

Mobile: everything in §3 plus the boundary row's absence for a Pro user.

---

## 6. Appendix — the store screenshot set

Six frames per platform, per language, dark theme, device frame on a `bg`-toned background,
caption above the device at 32/800 with one accent word in olive:

1. Dashboard, a full day of data — *"A napod egy képernyőn"*
2. Workout logging mid-set — *"Sorozatok, ismétlések, súlyok — gyorsan"*
3. Nutrition with macro rings — *"Kalória és makrók, keresés nélkül is"*
4. Cardio with a GPS route — *"Futás, bringa, túra — térképpel"*
5. Watch app on a wrist — *"Az órádról is"*
6. Trainer chat + assigned program — *"Az edződ programja, egy appban"*

**Every frame shows the unlocked state** — no ad banner, no lock icons, no boundary row.

Also: the Play feature graphic (1024 × 500, wordmark + tagline + one phone, dark).

**Screenshot content rules for the whole canvas**: one seeded demo dataset used everywhere,
plausible Hungarian names, realistic numbers, no empty states, no lorem. The product must look
like one product across every frame on the site and in the stores.

---

## 7. Output and form

- **Two canvases**, so the web and mobile frames can evolve separately:
  - `design/Lifey Landing.dc.html` — web frames `L01…`
  - `design/Lifey Paywall.dc.html` — mobile frames `P01…`
- Frame numbering continues in each file; do not renumber existing frames.
- Frame 1 of each canvas is a **token sheet** (the colours, the marketing type scale, the
  button variants, the radii) so the implementation reads values rather than measuring pixels.
- Every web section gets **desktop and mobile** frames. Hero and one full section additionally
  in **light theme** and in **English**; everything else may be dark/Hungarian.
- A final section per canvas: **motion notes** (what fades up, in what order) and **open
  product questions** you hit while designing — those are more valuable than a polished
  guess, and they get routed back into the plans.

---

# Decision log *(outside the prompt — the designer does not need this)*

### DD-1 Why one canvas set covers both web and mobile

The two surfaces sell the same thing to the same two people, and the mobile paywall's benefit
list is the sponsored-Pro band's promise seen from the other side. Designed apart, they drift
into two different descriptions of one product. Split into two *files* only so a web iteration
does not churn the mobile frames.

### DD-2 Why the seat count is the headline number on a pricing card, not the price

The plans are identical in features (D-M2), so a card whose largest element is the price
invites a straight price comparison with nothing to justify the difference. Leading with
"25 aktív kliens" makes the axis of the decision visible in half a second, and it is the axis
that actually maps to the trainer's own revenue.

### DD-3 Why the manual-approval wait is stated on the landing page

It is a real friction point (63 §6): `ROLE_TRAINER` is granted by a super admin. Hiding it
buys a slightly better click-through and pays for it with a first-day experience of "I signed
up and nothing happened", which is the worst possible first impression for a product whose
whole promise is reliability. Stated up front, a one-day wait reads as curation.

### DD-4 Why the design must show the ad slot's *empty* state explicitly

The most likely production bug is a reserved gap or a hairline showing for a paying user
(63 §8.6). A frame that shows "this is what a Pro user's dashboard looks like — no slot at
all" turns that from a code detail into an acceptance criterion someone can look at.

### DD-5 Why no blurred teaser over the user's own history

A blur over data the user themselves logged is the pattern that generates the "hostage"
review. The boundary row asks for the upgrade once and then gets out of the way — and it is
also honest about the fact that the data is safe, which is the actual worry.

### DD-6 Why Hungarian sets the layout and English is allowed to look airy

Every previous Lifey design round has surfaced HU-length overflow late, in implementation. The
constraint is cheap to honour in design and expensive to retrofit. English text in a slot sized
for Hungarian looks generous; the reverse looks broken.

### DD-7 Why the marketing site gets no illustration system

An illustration set is the highest-maintenance asset class on a marketing site: it looks best
on the day it ships and is subtly wrong after every product change. Screenshots are wrong in a
way that is *visible and fixable* — you re-take them. Given a small team and a product that
changes weekly, that is the correct failure mode.

### DD-8 Why the paywall is a full screen and not a bottom sheet

It carries a plan choice, two prices, a legal paragraph and a restore action. A sheet tall
enough to hold those is a full screen with a rounded top and less room, and it makes the
200 %-text-scale case unsolvable.

### DD-9 Why no attribution SDK for the invite → install → invite handoff

Covered in `69` D-DM5: the invite is already delivered by email match on first login, so a
deferred-deep-link SDK would add a third-party dependency, a privacy disclosure and a cost to
solve a solved problem.
