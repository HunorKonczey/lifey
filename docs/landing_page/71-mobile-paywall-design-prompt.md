# 71 – Mobile Paywall & Upsell: design prompt (for Claude Design)

> **What this file is:** the **narrowed rerun** of `70`, covering only the mobile half — the
> paywall, the gated surfaces, the ad slot, the Settings tile and the store screenshots.
> **§0 is the prompt: paste it as is, on its own, into a fresh conversation.** §1–§6 are
> appendices for the same conversation. The decision log at the end is *outside* the prompt.
>
> **Why a separate doc rather than re-running `70`.** `70` §0 briefs both surfaces at once, and
> the web half is already built (`design/Lifey Landing.dc.html`, L01–L21). Re-running it whole
> would invite a redesign of finished frames. Three of its appendices have also gone stale since
> it was written — the QR was withdrawn, the free history window changed from 90 to 30 days, and
> two UI assumptions turned out not to match the code (§DD-11, §DD-12). This file supersedes
> `70` §3, §4 and §6.
>
> Specification behind it: [69-mobile-paywall-design-plan.md](69-mobile-paywall-design-plan.md).
> Product background: [63](63-monetization-strategy-plan.md) (D-M5, D-M7),
> [67](67-mobile-free-pro-plan.md) (what each surface does at runtime).
>
> **Status: run — the canvas is delivered.**
> [`design/Lifey Paywall.dc.html`](design/Lifey%20Paywall.dc.html), frames **P01–P27**: every
> frame §0 asked for, including the two ad-slot variants with a recommendation (variant A,
> conditioned) and a non-empty open-questions frame. Frame map and deviations:
> [69 §11](69-mobile-paywall-design-plan.md); the eight questions from P27 are answered in
> [69 §12](69-mobile-paywall-design-plan.md). Do not re-run this prompt — the three small
> remaining items are listed in [69 §13](69-mobile-paywall-design-plan.md).

---

## 0. The prompt (paste this, on its own)

Design the **in-app purchase and upsell surfaces** for **Lifey**, an existing Flutter fitness
and nutrition app (iOS + Android). The app is live in design terms — it has a full design
system, which you are extending, not replacing. Everything below is the complete brief; you do
not need any other file.

### The business

Personal trainers pay for a **web** workspace where they coach clients. Their clients use this
**mobile** app for free, and while their trainer pays, those clients get the ad-free Pro version
at no cost — they must never be sold anything, ever. Someone with **no** trainer uses the app
free with ads, and can buy Pro themselves through the App Store / Play Store.

So the mobile app has three kinds of user, and the design has to serve all three:

1. **Sponsored** (a paying trainer's client) — full Pro, no ads, no upsell anywhere.
2. **Free** (no trainer, no purchase) — ads, a 30-day history window, 3 AI calls a month.
3. **Pro** (bought it themselves) — same as sponsored, plus a subscription to manage.

**Only three things are behind Pro.** Ads, history depth beyond 30 days, and the AI features
(calorie estimation from a photo, recipe generation). Everything else — nutrition, workouts,
cardio with GPS, the watch app, widgets, Apple Health / Health Connect, multi-week programs,
personal records — is free for everyone, permanently. Do not design a lock onto anything else.

Mobile Pro prices: **1 490 Ft / month** or **11 900 Ft / year**. Yearly is the default choice.
Never draw a price you invented — where a real store price is unknown, use these two.

### Language

**Hungarian is the product's primary language and sets every layout.** Hungarian strings run
20–35 % longer than English, so size every text slot against the Hungarian text in §1 and let
the English version look airy. Deliver Hungarian frames throughout, plus an English version of
the main paywall and one gated surface.

### Design tokens — use these exactly

Dark is the default theme; light is a first-class second, not an afterthought. Every frame you
draw must exist in **both**.

```
DARK                                    LIGHT
bg                #161611               #F3F2E8
surface           #1C1E16               #FFFFFF
surfaceContainer  #22241B               #ECEBDE
surfaceHigh       #2A2C20               #FFFFFF
primary  (olive)  #9DAE6B               #586E38
secondary (tan)   #C49A6C               #8A6A42
tertiary (green)  #6E9A6A               #4A7A52
tertiaryContainer #1A2E1A               #CCE8D2
onSurface         #F1F0E4               #1E1F18
onSurfaceVariant  #A8A899               #5C5C50
muted             #918B7A               #696960
outline           #3C3E32               #CDCBBC
error             #CF6679               #BA1A2C
```

Radii: `8` (chips, small) · `16` (buttons) · `18` (inputs) · `20` (cards) · `24` (large cards) ·
`28` (nav) · `999` (pill).
Font: **Plus Jakarta Sans**, weights 400–800. All numbers use `tabular-nums`.
Icons: **Material Symbols Rounded**; filled variant for active/emphasis, outline otherwise.
Motion: 150 / 250 / 350 ms, `cubic-bezier(.2,.8,.2,1)`. Shadows are soft and low —
`0 1px 3px rgba(0,0,0,.18)` — never hard Material elevation.

Type scale in the app: 34/800 display · 26/700 headline · 20/700 title · 15/500 body ·
14/600 list title · 13/600 label · 11/700 caps label.

### The rules that matter most

1. **The paywall is not a special world.** Same tokens, same radii, same font as every other
   screen. No gradients, no gold, no glow, no confetti, no crown iconography. This is a training
   tool; the purchase screen should feel like the same tool.
2. **Free must never look broken.** Gated things are *marked*, never removed. A locked row stays
   in the menu. A list that hits the history limit ends with an explanatory row — **never a
   blurred fake list and never a fade-out**. Blurring the user's own data is a hostile pattern
   and is out of bounds here.
3. **No urgency theatre.** No countdowns, no "limited offer", no fake scarcity, no red badges.
4. **The ad is a guest.** It is labelled as an ad, it never covers a control, and when there is
   no ad it occupies **zero pixels** — no reserved gap, no leftover hairline.
5. **Nothing is ever sold** during an active workout or cardio session, on the watch, in chat,
   on app start, or to a sponsored user.
6. **Accessibility is a constraint.** ≥ 4.5:1 contrast for every text/background pair in both
   themes; ≥ 44 × 44 tap targets; the paywall must survive **200 % text scale** and a **320 pt**
   wide screen; no state signalled by colour alone.

### What to draw

**A. The paywall** (§1 has every string, §2 the exact structure)

- `P01` Token sheet — the colours above, the paywall's type sizes, the button and plan-card
  specs, in both themes. Draw this first; everything else reads values from it.
- `P02` Paywall, default (`settings` entry) — dark, HU.
- `P03` Same, light, EN.
- `P04–P06` The three trigger variants: history · AI credits · remove ads (dark, HU). Only the
  headline, the sub-line and which benefit row is highlighted change — **do not redesign the
  screen three times.**
- `P07` **Sponsored state** — "the Pro is on your trainer": no plan cards, no purchase button,
  the three benefits shown as already active, one dismiss button.
- `P08` Three failure/edge states side by side: *products unavailable* · *purchase pending
  (bought offline)* · *already subscribed, reached by deep link*.
- `P09` Purchasing (button spinner) and success states.
- `P10` The paywall at **320 pt wide** and at **200 % text scale** — show what collapses.

**B. The gated surfaces** (§3)

- `P11` The statistics range menu, open, with **two locked rows** — dark HU and light EN.
- `P12` The history boundary row, in a workout-history list — dark HU and light EN.
- `P13` The AI credit chip at 3 / 1 / 0 remaining, next to the AI action.
- `P14` The Settings subscription tile in its **four** states: free · Pro (own) · Pro
  (sponsored) · trainer trial.

**C. The ad slot** (§4 — this one has an open question you must answer with frames)

- `P15` **Variant A — anchored**: the banner pinned at the bottom, with the floating nav above
  it. Draw nav-expanded and nav-collapsed.
- `P16` **Variant B — in-scroll**: the banner as the last item in the list content, nav
  floating over it as normal.
- `P17` The **Pro** dashboard: no banner, no gap, no hairline — and annotate the absence in the
  frame, because that emptiness is the thing implementation gets wrong.
- Add a short note recommending A or B and saying why. We will decide from your frames.

**D. Store screenshots** (§5)

- `P18–P23` Six store frames, dark, with Hungarian captions.
- `P24` The same six as a contact sheet with English captions.
- `P25` Play feature graphic, 1024 × 500.

**E. Closing**

- `P26` Motion notes — what animates, how long, and what `prefers-reduced-motion` collapses to.
- `P27` **Open questions** — anything you hit that the brief does not answer. This frame is more
  valuable than a confident guess; leave it non-empty if you have doubts.

### Deliverable

One canvas file, `Lifey Paywall.dc.html`, frames numbered `P01…` in the order above. Frame `P01`
is the token sheet. Do not renumber if you revise.

---

## 1. Appendix — every string, HU and EN

**Paywall headlines** (the sub-line sits under each):

| Trigger | HU headline | HU sub | EN headline |
|---|---|---|---|
| `settings` | Lifey Pro | Reklámok nélkül, teljes előzménnyel, korlátlan AI-val. | Lifey Pro |
| `historyRange` | Lásd a teljes történetedet | Az adataid megvannak — a Pro az összeset megmutatja, nem csak az utolsó 30 napot. | See your whole history |
| `aiCredits` | Fogyott az AI-kereteted | Havi 3 becslés ingyenes. A Pro-val korlátlan. | You're out of AI credits |
| `adRemoval` | Edzés reklámok nélkül | Egy előfizetés, és többé nem látsz hirdetést az appban. | Train without ads |

**The three benefit rows** (fixed order, same everywhere):

| Icon | HU title | HU line | EN title |
|---|---|---|---|
| `block` | Nincs reklám | Sehol az appban. | No ads |
| `history` | Teljes előzmény | Minden edzés, minden étkezés, az első naptól. | Full history |
| `auto_awesome` | Korlátlan AI | Kalóriabecslés fotóból, receptgenerálás. | Unlimited AI |

**Plan cards:** `Éves · 11 900 Ft` with a tan pill **"2 hónap ingyen"** and under it
`992 Ft / hó`; `Havi · 1 490 Ft`. Yearly pre-selected.
**CTA:** `Előfizetés — 11 900 Ft` / `Subscribe — 11 900 Ft`.
**Legal line:** `Az előfizetés automatikusan megújul, bármikor lemondható a store-ban.` +
links `ÁSZF` and `Adatkezelés`.
**Restore:** `Vásárlások visszaállítása` / `Restore purchases`.

**Sponsored state:** headline `A Pro-t az edződ állja`, sub
`Amíg az edződdel dolgozol, minden Pro funkció a tiéd — nem kell fizetned semmit.`, button
`Rendben`.
**Unavailable:** `Az előfizetés most nem elérhető` + `Próbáld újra`.
**Pending:** `A vásárlás feldolgozás alatt. Amint online vagy, aktiváljuk.`
**Already Pro:** `Aktív előfizetésed van` + `Kezelés`.

**Gated surfaces:**
- Range menu rows: `7 nap` · `30 nap` · `90 nap` · `Összes` (EN: `7 days` · `30 days` ·
  `90 days` · `All`). **The last two are locked.**
- Boundary row: `Régebbi adataid megvannak — a Pro megmutatja`.
- AI chip: `3/3`, `1/3`, `0/3`.
- Ad slot label: `Reklám` / `Ad`.

**Settings tile, four states:**

| State | Title | Subtitle |
|---|---|---|
| Free | Lifey Pro | Reklámmentes app, teljes előzmény, korlátlan AI |
| Pro (own) | Pro · aktív | Megújul: 2026. szeptember 12. |
| Pro (sponsored) | Pro — az edződ jóvoltából | Amíg Kovács Anna az edződ |
| Trainer trial | Edzői próba · 6 nap van hátra | Csomagválasztás a weben |

---

## 2. Appendix — the paywall's exact structure

Full-screen route, not a bottom sheet. Top to bottom:

| Slot | Spec |
|---|---|
| Close | 44 × 44 target, top-left, `close` in `onSurfaceVariant`. First element in the focus order. |
| Crest | 72 px `workspace_premium` on a 96 px `tertiaryContainer` circle. One glyph — not an illustration. |
| Headline | 28 / 700, centred, max 2 lines |
| Sub | 15 / 500 `onSurfaceVariant`, centred, max 2 lines |
| Benefits | Three rows, 16 px apart: 28 px filled icon in `primary` + 15/600 title + 13/500 line. The row matching the trigger gets a `tertiaryContainer` fill at radius 20. |
| Plan cards | Two **stacked** cards (not a segmented control — each carries a price, a period and a badge). Selected: 2 px `primary` border + `tertiaryContainer` fill + a `check_circle`, so selection is not colour-only. |
| CTA | Full-width pill, 56 px, `primary` fill, `bg` text, 16/700 |
| Legal | 11/500 `muted`, centred, **readable** — this is a store requirement, not fine print to hide |
| Restore | Text button, `onSurfaceVariant`, under the legal line |

The column scrolls; the CTA + legal + restore block pins above the safe area once content
overflows. At 320 × 568 the crest drops to 56 px and the benefit sub-lines are dropped. At
200 % text scale the crest hides entirely and the benefits collapse to titles — show this.

---

## 3. Appendix — the gated surfaces, precisely

**The range menu is a popup, not a chip row.** The statistics screen has a single filter chip
that opens a four-row popup menu. In the free tier the **last two rows are locked**: label at
60 % opacity, a 16 px `lock` glyph in `secondary` sitting where the selected row's check mark
would be. The locked row stays tappable — tapping it closes the menu and opens the paywall. The
chip that opens the menu is never locked and never changes appearance.

**The history boundary row** appears where a list crosses the 30-day cutoff: full width,
`surfaceContainer`, radius 20, 16 px padding, a 20 px `history` glyph in `primary`, the text at
14/600, and a chevron. **Below it the list simply ends.** No blur, no fade, no ghost rows.

**The AI credit chip** sits beside the AI action: pill, `surfaceContainer` fill, 12/700
`tabular-nums`. Neutral at 3, `secondary` at 1, `error`-toned at 0.

---

## 4. Appendix — the ad slot, and the question you need to answer

**The bottom navigation is not a solid bar.** It is a *floating, scroll-reactive* nav: 58 dp
tall, sitting 26 dp above the safe area with 14 dp side margins, and it **collapses into a
centred stadium pill (icons only) when the user scrolls**. Content scrolls underneath it.

That leaves a genuine open question, which is why you are drawing two variants:

**Variant A — anchored.** Banner pinned at the very bottom, full-bleed, inside the safe area,
with the floating nav sitting above it (its bottom gap shrinks to clear the banner). Real ad
revenue depends on an anchored banner, but this costs roughly 130 dp + safe area of permanent
bottom chrome for a free user, and you have to make the collapsed-pill state work over it.

**Variant B — in-scroll.** The banner is the last item in the scrollable content. It never
fights the nav and eats no permanent space, but it is seen far less often, so it earns far less.

Draw both, in both nav states, and say which you would ship and why.

**In every variant**, the slot has: a `surfaceContainer` background behind the creative (so a
transparent ad never shows content through it), a 1 px `outline` hairline on top, a 12 px
`Reklám` label in `muted` top-left, and a 24 px `block` icon top-right (44 px target) that opens
the paywall. **With no ad loaded the whole slot is zero-height** — no background, no hairline, no
label.

For the free-tier dashboard render, show the banner **against the floating action button** so it
is visible that the two do not collide.

---

## 5. Appendix — the store screenshots

Six frames, device-framed on a `bg`-toned background, dark theme, caption above the device at
32/800 in `onSurface` with one accent word in `primary`:

| # | Screen | HU caption |
|---|---|---|
| 1 | Dashboard, a full day of data | A napod egy képernyőn |
| 2 | Workout logging, mid-set | Sorozatok, ismétlések, súlyok — gyorsan |
| 3 | Nutrition with macro rings | Kalória és makrók, keresés nélkül is |
| 4 | Cardio with a GPS route | Futás, bringa, túra — térképpel |
| 5 | Watch app on a wrist | Az órádról is |
| 6 | Trainer chat + an assigned program | Az edződ programja, egy appban |

**Every store frame shows the unlocked state** — no ad slot, no lock glyphs, no boundary row. A
store screenshot advertising the paywall is a store screenshot nobody installs from.

Use **one seeded demo dataset across every frame in the whole canvas**: plausible Hungarian
names, realistic numbers, no empty states, no lorem. The product must look like one product.

---

## 6. Appendix — what already exists, and must not be redesigned

The marketing web canvas (`Lifey Landing.dc.html`) already contains, in frames **L13/L14**, a
phone dashboard rendered twice: free with a labelled `320 × 50` ad slot, and sponsored with the
slot **absent and the absence annotated**. Those two renders are the reference for the slot's
visual treatment — match them rather than inventing a second look. What they do *not* cover, and
what §4 above is asking for, is the slot against the **floating nav** in both its states, against
the **FAB**, and in **light theme**.

---

# Decision log *(outside the prompt)*

### DD-10 Why a narrowed rerun instead of re-running `70`

`70` §0 briefs the web and mobile surfaces together. Handing that to a fresh conversation now
would put 21 finished web frames back on the table, and the most likely outcome is a
"improved" redesign of work that is already approved and already mapped to implementation
prompts in `68` §12.1. Narrow reruns are also the house precedent — `61` did the same for the
cardio sport-specifics after `57` had run.

### DD-11 Why the range gate moved from "locked chips" to "locked menu rows"

`69` §4.1 originally specified a row of range chips with lock affixes. There is no such row in
the app: `statistics_screen.dart` uses a `PopupMenuButton` with a single trigger chip, and the
four ranges (`7 nap` / `30 nap` / `90 nap` / `Összes`) live inside the popup. Designing the
chip row would have produced frames that could not be implemented without first rebuilding a
working control for no product reason. Corrected in `69` §4.1 as DV-7.

### DD-12 Why the free history window dropped from 90 days to 30

With a 90-day window, the four available ranges are 7 / 30 / 90 / All — so exactly **one** row
(`Összes`) would have been locked, inside a menu most users never open. The history gate would
have been invisible, which makes it worthless as an upsell *and* worthless as an explanation of
what Pro is for. At 30 days two rows lock, and the boundary row starts appearing in lists after
about a month of use, which is roughly when someone has enough logged data to care. 30 days
still covers the ordinary "how did my month go" use. `63` D-M5, `64` §3.2, `67` and the README
were updated together.

### DD-13 Why the ad placement is asked as a question rather than specified

`69` §4.4 assumed a solid bottom bar to sit above. `AdaptiveBottomNav` is floating and
collapses to a pill on scroll, with `extendBody: true`, so "above the nav" does not describe a
place. The two candidate answers differ by roughly an order of magnitude in ad revenue and by a
large amount in how much of a free user's screen is permanently spent — that is a trade to look
at, not to assert. Two frames cost a fraction of what discovering the wrong answer after
implementation would.

### DD-14 Why the store screenshots are in this canvas and not a separate asset job

They are the same three-user story told to a fourth audience, using the same seeded dataset. A
separate job would re-pick the data, re-pick the theme and drift. They are also the surface most
likely to be produced in a hurry the week of a release, which is precisely when the "no locked
UI in a store screenshot" rule gets forgotten.
