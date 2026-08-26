# 68 – Web Landing Page — Design

Status: **design done for the home + pricing pages** — [`design/Lifey Landing.dc.html`](design/Lifey%20Landing.dc.html),
frames **L01–L21** (§12). Four page/state groups are still outstanding (§13).
Scope: design (web) — desktop and mobile, both themes, both locales
Depends on: `docs/web/06-design-system-web.md` (tokens, type scale, radius, motion,
breakpoints), `docs/design/18-design-system-prompt.md` (the brown-green brand),
`docs/landing_page/65-web-landing-page-plan.md` (page inventory, routing, budgets),
`docs/landing_page/63-monetization-strategy-plan.md` (what the pricing page must say)

`70` is the self-contained brief for the design tool. This document is the specification the
implementation works from — section by section, at both sizes, in both themes. **§1–§11 are the
spec; §12 maps it to the delivered frames and records where the canvas deliberately departs from
it; §13 is what still has to be designed.** Where §12 records a deviation, **the canvas wins** —
the spec text above it has been left as written so the change is visible rather than silently
overwritten.

---

## 1. The design problem

The app's design system is built for **data density**: small type, tight radii, quiet
surfaces, a sidebar. A landing page has the opposite job — one message per screen, generous
whitespace, a scroll that carries momentum. But it has to look like the same product, or the
first screenshot breaks the promise.

The resolution used throughout this document: **the app's palette and shapes, at marketing
scale.** Same tokens, same radii, same font, same icon set — three times the type size, four
times the vertical rhythm, and a small set of marketing-only additions (§2.2, §2.3).

### D-DW1 Product screenshots carry the page; no illustration system

Every visual on the site is either a real screenshot of the running app or a piece of the
app's own UI reproduced at marketing scale (a real `StatCard`, a real macro ring). No stock
photos, no bespoke illustration style to maintain, no 3D renders.

*Rejected: a custom illustration set.* It photographs well in a design review and then rots,
because every product change makes it a little more wrong.

### D-DW2 Dark is the hero, light is complete

The brand's dark palette (`--bg: #161611`) is what the hero and the section backgrounds are
designed around. But the FOUC script means a light-preference visitor sees light on first
paint (`65` §10.5), so **every section in this document specifies both**. A section that only
works dark is a bug, not a style.

### D-DW3 The page has exactly two accent colours

`--primary` (`#9DAE6B` olive) for everything trainer/CTA, `--secondary` (`#C49A6C` warm tan)
for everything client/app. Section by section, the reader can tell which audience is being
addressed by the accent alone. The metric accents (`--metric-kcal` etc.) appear *only* inside
reproduced product UI, never as decoration.

---

## 2. Foundations

### 2.1 Grid and rhythm

| Breakpoint | Container | Columns | Gutter | Section padding (y) |
|---|---|---|---|---|
| ≥ 1280 (desktop) | 1200 px | 12 | 32 px | 120 px |
| 768–1279 (tablet) | 100 % − 64 px | 8 | 24 px | 96 px |
| < 768 (mobile) | 100 % − 40 px | 4 | 16 px | 72 px |

Vertical rhythm is the app's 4 pt grid, scaled: marketing spacing steps are
`8 / 16 / 24 / 40 / 64 / 96 / 120`.

Max text measure: **62 ch** for body copy, **18 ch** for a hero headline (so it breaks into
2–3 lines by itself and never needs a `<br>`).

### 2.2 Marketing type scale (an extension, not a replacement)

The app scale (`docs/web/06-design-system-web.md` §4) tops out at 34 px. Marketing adds four
steps above it and reuses everything below:

| Role | Desktop | Mobile | Weight | Use |
|---|---|---|---|---|
| `mkt-display` | 64 / 1.05 | 36 / 1.1 | 800 | hero headline only |
| `mkt-headline` | 44 / 1.12 | 28 / 1.2 | 700 | section headline |
| `mkt-title` | 28 / 1.25 | 22 / 1.3 | 700 | card / feature title |
| `mkt-lead` | 20 / 1.55 | 17 / 1.6 | 500 | hero sub, section lead |
| `text-body` … | as app | as app | — | everything else |

Letter-spacing: `-0.02em` on `mkt-display` and `mkt-headline`, `0` below. Numbers keep
`tabular-nums` (prices, seat counts).

**Hungarian is the constraint, not English.** Hungarian headlines run 20–35 % longer; every
headline slot in §4 is sized against the Hungarian string, and the English one is allowed to
look airy. A layout that only works in English is not done.

### 2.3 Marketing-only additions

Four tokens, defined in `globals.css` alongside the existing ones, in both themes:

```css
--mkt-hero-glow:   radial-gradient(60% 50% at 50% 0%, rgba(157,174,107,.14), transparent 70%);
--mkt-section-alt: var(--surface-container);   /* alternating band background */
--mkt-hairline:    var(--outline);             /* 1px section separators */
--mkt-shadow-lift: 0 8px 32px rgba(0,0,0,.28); /* screenshot frames only; .10 in light */
```

Nothing else is added. If a section needs a fifth token, the section is wrong.

### 2.4 Motion

`--dur-base` / `--ease` from the app. On the marketing pages, exactly one motion pattern:
**fade-up 16 px on first viewport entry**, staggered 60 ms across siblings, played once.
Nothing loops, nothing parallaxes, nothing moves on hover except a 1 px lift on cards and the
standard button state.

`prefers-reduced-motion: reduce` → everything renders in its final state immediately. This is
tested, not assumed.

### 2.5 Buttons

Three variants only, all at `--r-pill`:

| Variant | Fill | Text | Use |
|---|---|---|---|
| Primary | `--primary` | `--bg` | the trial CTA, once per section at most |
| Secondary | transparent, 1 px `--outline` | `--on-surface` | "See pricing", "How it works" |
| Ghost | none | `--on-surface-variant` | footer/nav links |

Sizes: 52 px tall desktop, 48 px mobile, 24 px horizontal padding, `--dur-fast` transitions.
Focus ring: 2 px `--primary` at 2 px offset, on every variant, always visible.

---

## 3. Shell

### 3.1 Header

Desktop: 72 px tall, sticky, `background: color-mix(in srgb, var(--bg) 82%, transparent)`
with `backdrop-filter: blur(12px)`, and a `--mkt-hairline` bottom border that appears only
after 8 px of scroll.

Left: wordmark (24 px). Centre: `Edzőknek · Az app · Árak · GYIK`. Right: language switch
(`HU/EN` as a two-item segmented control, not a dropdown — two options never deserve a menu),
theme toggle, then either **"Belépés"** (ghost) + **"Ingyenes próba"** (primary) or **"Vissza
az appba"** (secondary) for a signed-in visitor (`65` D-W2).

Mobile: 60 px, wordmark left, a primary CTA pill right (text shortened to "Próba"), hamburger
opening a full-height sheet with the nav, the language switch, the theme toggle and both CTAs
stacked at the bottom, thumb-reachable.

### 3.2 Footer

Four columns desktop (Termék · Edzőknek · Cég · Jogi), stacked accordion-free on mobile.
Includes: both store badges, the language switch again, `© Lifey`, and the three legal links
(63 §5). Background `--surface`, top hairline.

### 3.3 Mobile sticky CTA bar

Below 768 px, after the hero scrolls out of view, a 64 px bar pins to the bottom:
`--surface-high`, top hairline, one primary CTA full-width minus 20 px margins, plus a small
"Árak" ghost link. It hides while the footer is in view so it never covers the legal links.

*Rejected: showing it from page load.* It would cover the hero's own CTA with a duplicate.

---

## 4. Home page, section by section

Twelve sections. Backgrounds alternate `--bg` / `--mkt-section-alt` starting from the hero,
so the eye gets a rhythm without any borders doing the work.

### 4.1 Hero — `--bg` + `--mkt-hero-glow`

Desktop: 7/5 split. Left column (7): eyebrow label (`text-label-sm`, ALL CAPS,
`--on-surface-variant`) reading "Edzőknek és klienseiknek"; `mkt-display` headline;
`mkt-lead` sub, max 2 lines; primary + secondary CTA row; below them a single line of
`text-label` reassurance — *"14 nap ingyen · bankkártya nélkül · a klienseidnek ingyenes az
app"*.

Right column (5): the **hero device pair** — a desktop `/admin` client-detail screenshot in a
soft frame (`--r-lg`, `--mkt-shadow-lift`, 1 px `--outline`), with a phone screenshot
overlapping its lower-left corner at −24 px, rotated 0° (no jaunty angles; the product is a
tool). Both are real captures in the dark theme, swapped for light-theme captures under
`[data-theme="light"]`.

Mobile: single column, headline → sub → primary CTA (full width) → secondary (full width,
below) → reassurance line → then the phone screenshot alone, centred, 280 px wide, with the
desktop frame cropped behind it at 30 % opacity as depth.

Height: never a forced 100 vh. The next section's headline must be partly visible at 800 px
viewport height — the fold's job is to promise there is more.

### 4.2 The fork — two cards

Two large cards side by side (desktop) / stacked (mobile), `--surface`, `--r-lg`, 32 px
padding.

| | Trainer card | Client card |
|---|---|---|
| Accent | `--primary` | `--secondary` |
| Icon | `groups` (filled) | `phone_iphone` (filled) |
| Title | "Edző vagy?" | "Edződ van, vagy egyedül edzel?" |
| Body | one sentence | one sentence |
| CTA | "Nézd meg, mit kapsz" → for-trainers | "Töltsd le az appot" → app page |

This is the page's structural promise (`65` D-W9): everything below is trainer-weighted, and
the client has a door of their own right here.

### 4.3 Proof strip — `--mkt-section-alt`

A single row of four numbers with `tabular-nums`: active trainers, clients coached, sessions
logged, ingredients in the database. Until there are real numbers worth showing, this section
**does not ship** — a proof strip with invented figures is worse than no proof strip.
Placeholder state for the design: the row is replaced by one line of copy stating what the
product does, at `mkt-lead`.

### 4.4–4.6 Three trainer value blocks — alternating

Each: a 6/6 split, screenshot on one side, copy on the other, alternating sides down the
page. Copy is `mkt-headline` + `mkt-lead` + three `text-body` bullets with a filled
`check_circle` in `--primary`.

1. **"Minden kliensed egy helyen"** — `/admin/clients` + a client detail. Bullets: invite by
   email, see their real logged data, compliance at a glance.
2. **"Programot írsz, nem táblázatot"** — the program builder + the schedule drawer. Bullets:
   multi-week programs, bulk assignment, scheduling with recurrence.
3. **"Nem tűnnek el két edzés között"** — chat + the weekly report email. Bullets: in-app
   chat, weekly report, nutrition goals you set.

Mobile: copy first, screenshot below, always in that order regardless of the desktop
alternation — a screenshot with no context above it is decoration.

Screenshot frames: `--r-lg`, 1 px `--outline`, `--mkt-shadow-lift`, and a 1 px inner
highlight (`inset 0 1px 0 rgba(255,255,255,.06)`) in dark only.

### 4.7 The sponsored-Pro band — `--mkt-section-alt`, `--secondary` accent

The single most important commercial section on the page (D-M4). Centred, narrow (720 px):
`mkt-headline` "A klienseid reklámmentes Pro appot kapnak — a te előfizetéseddel", a
`mkt-lead` sentence, and a small three-item row showing what that means (no ads, full
history, AI). Visual: a phone screenshot of the dashboard with a subtle `--secondary` glow,
and — beside it — the same screenshot with a banner ad greyed out and struck through. One
image, one idea.

### 4.8 How it works — three steps

Three numbered cards, `--surface-container`, connected on desktop by a 1 px `--outline` line
running behind them. `01 Kérj hozzáférést · 02 Hívd meg a klienseidet · 03 Írj programot és
kövesd őket`. Step 1's caption states the manual-review wait honestly (66 D-T1), because
finding that out later feels like a bait-and-switch.

Mobile: vertical, the connector becomes a left rail.

### 4.9 Feature grid

Nine small cards, 3×3 desktop / 1 column mobile, `--surface`, `--r-card`, 24 px padding, a
28 px Material Symbol in `--primary`, `mkt-title` title, two lines of `text-body`. Covers the
things the value blocks do not: calendar, statistics, PRs, cardio + GPS, watch app, offline,
HU/EN, Apple Health / Health Connect, widgets.

### 4.10 Pricing preview — `--mkt-section-alt`

The three plan cards from §5.2, rendered identically to the pricing page but with the FAQ and
the fine print omitted, plus a "Minden csomag részletei" secondary CTA. One source of truth
for the numbers (`65` §10.4) means this section literally reuses the pricing page's card
component.

### 4.11 FAQ preview

Five accordion items, the five objections from `65` §4, with a link to the full FAQ. Native
`<details>`/`<summary>` styled — no JS, no layout shift, keyboard-accessible for free.

### 4.12 Final CTA — `--bg`, hero glow repeated at the bottom edge

Centred, `mkt-headline`, one primary CTA, and the same reassurance line as the hero. Nothing
else. A final CTA with a form field in it is a final CTA that gets abandoned.

---

## 5. Pricing page

### 5.1 Header block

`mkt-headline` + `mkt-lead` + the interval toggle: a segmented control (`--r-pill`,
`--surface-container` track, `--primary` thumb) reading `Havi / Éves`, with a
`--tertiary-container` badge on the yearly option — **"2 hónap ingyen"**. Yearly is
pre-selected (D-M6 logic applies to the trainer plans too: it is the better deal and the
better business).

### 5.2 The three plan cards

Equal-height cards on a 3-column grid; horizontal scroll-snap carousel below 768 px with the
recommended card first in the scroll order and a 16 px peek of the next.

| Element | Spec |
|---|---|
| Frame | `--surface`, `--r-lg`, 1 px `--outline`, 32 px padding |
| Recommended (Pro) | 2 px `--primary` border, `--tertiary-container` "Legnépszerűbb" pill, `--mkt-shadow-lift`, no scale transform |
| Plan name | `mkt-title` |
| **Seat count** | `mkt-display` at 44 px, `tabular-nums`, e.g. **25** with "aktív kliens" beneath — the seat count is the headline number, not the price (D-M2) |
| Price | `mkt-lead`, `12 990 Ft` + `/hó` in `--on-surface-variant`; the yearly equivalent in `text-label` below |
| CTA | Primary on the recommended card, secondary on the other two |
| Feature list | Identical on all three, each with a `check_circle` in `--primary` — the *point* is that they are identical (D-M2) |

Under the cards, in `text-label`, `--muted`: currency note (63 §7.12), VAT note, and the
withdrawal-right line (63 §5).

### 5.3 Mobile Pro block

Visually subordinate: a single wide `--surface-container` card with a `--secondary` accent,
two price chips (monthly/yearly), and one line — *"A kliensek ingyen használják az appot. Ha
edző nélkül edzel, a Pro leveszi a reklámokat."* It must not compete with the trainer plans
for attention; it is here so the pricing page answers every pricing question, not to sell.

### 5.4 Billing FAQ

Six `<details>` items: what happens at trial end, can I cancel, what happens to my clients,
where is my invoice, can I change plans, is there VAT.

---

## 6. Other pages

- **For trainers** — the same section vocabulary as the home page's 4.4–4.6, expanded to six
  blocks, plus a "day in the life" strip and the pricing preview. No new components.
- **The app** — `--secondary` accent throughout, a phone-first hero (three phones, centre one
  forward), a feature grid, store badges, and a screenshot carousel that is a scroll-snap
  row, not a JS carousel.
- **Download** — deliberately sparse: wordmark, one line, two store badges at 200 px, the legal
  links, nothing else. **No QR card** — see §12.2 DV-4. It is opened on a phone, in a hurry,
  usually by someone standing next to their trainer.
- **FAQ** — a two-column layout on desktop (category rail + content), single column mobile.
- **Legal** — one column, 62 ch, `text-body` at 16 px with 1.7 line height, a sticky table of
  contents on desktop. Print stylesheet: no header, no footer, black on white.
- **Contact** — a short form (name, email, message) in a `--surface` card, plus a direct email
  address in plain text for people who would rather not use a form.

---

## 7. States

Every page needs these designed, not improvised:

| State | Design |
|---|---|
| Form submitting | button label swaps to a 20 px spinner in `--bg`, width held so nothing jumps |
| Form success | the card's content is replaced by a `check_circle` in `--tertiary` + one line |
| Form error | field-level, `--error` text under the field, and the field border in `--error` |
| Image failed | the frame renders with `--surface-container` fill and the `alt` text centred in `--muted` — never a broken-image icon |
| Signed-in header | "Vissza az appba" (secondary), no "Belépés" |
| Trainer with an active plan | pricing CTAs read "Csomag kezelése" (66 §8.2) |
| Reduced motion | all entry animations resolved (§2.4) |
| 404 | wordmark, `mkt-headline`, one line, a primary CTA back to home, in both locales |

---

## 8. Accessibility

- Contrast: every text/background pair ≥ 4.5:1 in **both** themes. The tokens were already
  corrected for this in `globals.css` (the `--muted` comments record it); marketing must not
  reintroduce the problem by putting `--muted` on `--surface-container` at 13 px.
- Focus visible on every interactive element, including the language switch and the
  `<summary>` accordion rows.
- The hero glow is decorative and must not sit behind text at a contrast-reducing opacity.
- Every screenshot has a translated `alt` describing what is *shown*, not "screenshot".
- Heading order is strictly h1 → h2 → h3 per page.
- Target size ≥ 44 × 44 px for every tap target on mobile, including the language switch.
- The sticky mobile CTA bar must not overlap the focused element when the keyboard is open on
  the contact form — it hides while an input has focus.

---

## 9. Assets to produce

| Asset | Count | Notes |
|---|---|---|
| Desktop `/admin` screenshots | 6 | dark + light each = 12 files, 2× |
| Phone screenshots | 8 | dark + light = 16, 2×, status bar cleaned |
| Hero device composite | 2 | one per theme |
| Sponsored-Pro before/after | 2 | one per theme |
| Wordmark | 3 | full, compact, favicon |
| OG images | per page | generated (`65` §5.1), not exported |
| ~~QR code~~ | 0 | withdrawn — §12.2 DV-4 |

Screenshot content rules: realistic but not real — seeded demo data with plausible Hungarian
names, sensible numbers, no empty states, no lorem, and **no locked/free-tier UI** (`67`
§9.8). Same demo dataset across every screenshot so the product looks like one product.

---

## 10. Acceptance criteria

- [ ] Every section specified in both themes and at all three breakpoints.
- [ ] Hungarian strings fit every headline slot without truncation or a manual line break.
- [ ] Only the four marketing tokens added; no new colours.
- [ ] One motion pattern, respecting `prefers-reduced-motion`.
- [ ] Contrast ≥ 4.5:1 verified on every pair, both themes.
- [ ] Pricing cards render from the shared `PLANS` constant, identical on home and pricing.
- [ ] Mobile sticky CTA does not cover the footer or a focused input.
- [ ] Proof strip either has real numbers or is absent (§4.3).
- [ ] Screenshots: one demo dataset, no free-tier UI, translated alt text.
- [ ] Performance budgets from `65` §8 met with the final images in place.

---

## 11. Non-goals

- Illustration system, mascot, 3D, video backgrounds.
- Scroll-jacking, parallax, animated counters, typewriter effects.
- A dark/light "designed separately" split — it is one design with two palettes.
- Testimonial and logo sections before there is anything real to put in them.
- Any component that exists only on the marketing site and duplicates an app component.

---

## 12. The delivered canvas — frame map and deviations

[`design/Lifey Landing.dc.html`](design/Lifey%20Landing.dc.html), frames **L01–L21**. The canvas
is the source of truth for anything below; where it and §1–§11 disagree, the entries in §12.2
say which won and why.

### 12.1 Frame map

| Frame | Contents | Spec section | Implements (`65` §9) |
|---|---|---|---|
| **L01** | Token sheet — marketing type scale, the two accents, buttons, radii, dark + light values | §2 | Prompt 3 |
| **L02** | Marketing header in 3 states (signed out · signed in · mobile hamburger, open) + footer | §3.1, §3.2, §7 | Prompt 3 |
| **L03** | Mobile sticky CTA bar, 3 states | §3.3 | Prompt 3 |
| **L04** | Hero — desktop · dark · HU | §4.1 | Prompt 4 |
| **L05** | Hero — desktop · light · EN | §4.1, §2.2 | Prompt 4 |
| **L06** | Hero — mobile 390 px, dark HU + light EN | §4.1 | Prompt 4 |
| **L07** | §2 The fork — the two accents teach themselves here | §4.2 | Prompt 4 |
| **L08** | §3 Proof strip — **both** the numbers version and the fallback | §4.3 | Prompt 4 |
| **L09** | §2–§3 on mobile | §4.2, §4.3 | Prompt 4 |
| **L10** | §4 "Minden kliensed egy helyen" — image right | §4.4 | Prompt 4 |
| **L11** | §5 "Programot írsz, nem táblázatot" — image left, container background | §4.5 | Prompt 4 |
| **L12** | §6 "Nem tűnnek el két edzés között" — image right | §4.6 | Prompt 4 |
| **L13** | §7 Sponsored-Pro band — dark · HU | §4.7 | Prompt 4 |
| **L14** | §7 Sponsored-Pro band — light · EN | §4.7, D-DW2 | Prompt 4 |
| **L15** | §4–§7 on mobile — copy always before image | §4.4–§4.7 | Prompt 4 |
| **L16** | §8 How it works — step 1 states the manual approval | §4.8 | Prompt 4 |
| **L17** | §9 Feature grid — 9 cards, client-side features in tan | §4.9 | Prompt 4 |
| **L18** | §9 on mobile, single column | §4.9 | Prompt 4 |
| **L19** | Pricing page — desktop | §5 | Prompt 6 |
| **L20** | Pricing — mobile | §5.2 | Prompt 6 |
| **L21** | §11 FAQ (first row open) + §12 final CTA | §4.11, §4.12 | Prompt 4 |

The home page's pricing preview (§4.10) has no frame of its own by design — it reuses L19's
cards with the fine print dropped, which is what §4.10 asked for.

### 12.2 Deviations from §1–§11 — all accepted except one

**DV-1 The recommended plan's pill reads "AJÁNLOTT", not "Legnépszerűbb" (L19).** Accepted, and
better: there is no popularity data yet, so "most popular" would be an invented claim on the one
page where a claim costs the most. §5.2 is superseded on this word.

**DV-2 The plan cards lead with the yearly price; the monthly equivalent and the monthly-billed
price sit under it in one small line (L19).** §5.2 had it the other way round. Accepted — yearly
is the pre-selected interval (§5.1), so the number the card shouts should be the one the toggle
has chosen. The monthly-billed figure staying visible is what keeps this honest.

**DV-3 The three feature bullets are not identical across the cards (L19).** §5.2 required
identical lists to make "every plan has every feature" visible. The canvas instead scales the
same bullet with the tier — *"Reklámmentes Pro a klienseknek" / "…25 kliensnek" / "…mindenkinek"*.
Accepted: it makes the seat axis the subject of the feature list too, which is the point of
D-M2, and identical lists three times over read as filler.

**DV-4 "How it works" step 2 says the client link is made by email — *"nincs kód, nincs QR"*
(L16).** This is correct and matches the actual invite mechanism
(`docs/personal_trainer/01-koncepcio-es-folyamatok.md`: email-based invites, delivered to the
app by polling). It contradicts `69` §6.3, which specified a QR card on the trainer's invite
screen and the download page — **`69` yields**, and has been corrected (`69` §11, DV-4).

**DV-5 ⚠ The Studio card's third bullet reads "Több edző egy stúdióban" (L19).** **Not
accepted — this must change before the pricing page is implemented.** It breaks two decisions at
once: D-M2 (every tier has every feature; the client count is the only axis) and `63` §6, which
explicitly defers team/gym accounts with several trainers on one workspace. As drawn, the page
sells a feature that does not exist and is not planned, on the tier most likely to be bought by
someone who would notice.

*Fix:* replace it with a bullet that scales on the same axis as the other two — e.g. *"Korlátlan
aktív kliens"* or *"Prioritásos támogatás"* (the latter only if we will actually provide it).
Whoever implements `65` Prompt 6 owns this; the canvas frame should be corrected in the same
change so the two do not drift.

**DV-6 The sponsored band (L13/L14) also delivers a mobile surface.** It renders the dashboard
twice — free with a labelled 320 × 50 banner slot, and sponsored with the slot absent and the
absence *called out in the frame* (*"— nincs reklámhely, nincs hajszálvonal —"*). That is `69`
§4.4 and DD-4 satisfied ahead of the mobile canvas; `69` §11 records it so the work is not
redone.

---

## 13. What still has to be designed (web)

The rerun brief. Everything here was in `70` §0/§5/§7 and is not in the canvas:

1. **For-trainers page** (§6) — six value blocks reusing L10–L12's vocabulary, the "day in the
   life" strip, and the pricing preview. No new components, so this is composition, not design.
2. **The app page** (§6) — tan accent throughout, phone-first hero, feature grid, screenshot
   scroll-snap row, store badges.
3. **Download page** (§6, `69` §6) — wordmark, one line, two store badges, legal links. **No QR
   card** (DV-4). It needs the deep-link-attempt and fallback states.
4. **State frames** (§7) — form submitting / success / error; failed image (frame with alt text);
   404 in both locales. The signed-in header and the "Csomag kezelése" pricing CTA are already
   done (L02, L19).
5. **Motion notes and open questions** (`70` §7) — the canvas has no closing section for either.
   The motion spec in §2.4 is one pattern, so this is a short addendum, but the open-questions
   list is the part worth asking for: it is where the designer's unresolved product questions
   would have surfaced.

Items 1–3 block `65` Prompts 5 and 7. Item 4 blocks nothing but will be improvised at
implementation time if it is not drawn. Item 5 blocks nothing.
