# 86 – Missing design frames: the rerun brief (for Claude Design)

> **What this is.** The frames that were never drawn for surfaces that are **already built**
> ([`68` §13](68-web-landing-design-plan.md) on the web, [`69` §13](69-mobile-paywall-design-plan.md)
> on mobile; LIF-121, `72` D3/D4). This is a brief for drawing them *after the fact*: the frames
> are a **check** on calls the code already made, not a spec the code has yet to follow. **§0 is
> the prompt — paste it as is**, with the two canvases and the screenshots in
> [`design/as-built/`](design/as-built/) attached; §1–§3 are appendices.
>
> **Nothing here blocks a release.** The value is that the next change to these surfaces has a frame
> to check itself against, and that the designer's unresolved product questions (the part of the
> original brief that never came back) finally get asked.
>
> Canvases to continue: [`design/Lifey Landing.dc.html`](design/Lifey%20Landing.dc.html) (last frame
> **L21**) and [`design/Lifey Paywall.dc.html`](design/Lifey%20Paywall.dc.html) (last frame **P27**).
> Foundations: [`70`](70-landing-design-prompt.md) (the original web brief, history),
> [`71`](71-mobile-paywall-design-prompt.md) (the mobile one), [`68`](68-web-landing-design-plan.md),
> [`69`](69-mobile-paywall-design-plan.md).
>
> The screenshots were captured on 2026-10-14 from the dev build (dark theme, reduced motion;
> 1440 px and 390 px wide, Hungarian and English). Only the dark theme was captured; the site also has a
> complete light theme (`68` D-DW2: dark is the hero, light is complete).

---

## 0. The prompt (hand this over as is)

You designed the Lifey marketing site (`Lifey Landing.dc.html`, frames L01–L21) and the mobile
paywall (`Lifey Paywall.dc.html`, P01–P27). Several surfaces were then **built without a frame**
because none had been drawn. They exist and run; the attached screenshots show them exactly as
built. Please draw the missing frames **continuing the same canvases and numbering**, so the code
can be checked against them.

**This is a review as much as a drawing job.** For each frame, start from the screenshot, draw
what you would have drawn, and **mark every place where the built version differs from what you
would have designed** — the list of calls we made without a frame is in each item below. Say which
you would keep, which you would change, and why. Keep the visual language of L01–L21 / P01–P27:
same tokens, same type, no new components unless you name them.

Hard constraints (all carried over from the original briefs):

- Dark first, light complete (`68` D-DW2): draw light only where the existing frames do.
- Hungarian is the default and the longer language; draw every frame in **HU and EN**.
- **No QR code** anywhere on the download page (withdrawn, `69` §6.3).
- **No invented prices and no fake store URLs.** The store badges are inert until a listing
  exists; they carry a small "Hamarosan / Coming soon" caption.
- No new product claims beyond what the existing copy says.

**Frames to add — web (continue after L21):**

1. **L22 / L23 — For-trainers page**, desktop 1440 and mobile 390. Built as: a text-only hero
   (headline, subhead, two CTAs), six alternating value blocks, a "day in the life" strip, the
   home page's pricing preview and final CTA. *Calls made without a frame:* (a) **no hero mockup**
   — the home hero spends a product mockup on itself and this page needed all three mockups for the
   value blocks; (b) on mobile the six value blocks are **copy only** (eyebrow, title, body,
   bullets) with no compact visual, unlike the home page's per-section mobile mockups.
2. **L24 / L25 — App page**, desktop and mobile. Built as: phone-first hero, feature grid,
   scroll-snap screenshot row, closing store-badge CTA, tan accent throughout. *Call made:* **one
   phone in the hero, not three** (your §6 spec asked for three, centre one forward).
3. **L26 — Download page** plus its two **invite states**, mobile 390. Built as: wordmark, one
   line, two inert store badges with the "coming soon" caption, two legal links; nothing scrolls on
   a phone; no header or footer nav. With `?invite=<token>` the page first shows a full-screen
   **attempt state** (a pulsing phone glyph, about 1.2 s) while it tries to open the app, then the
   **fallback**: the same page with one extra reassurance line ("your invite will wait").
   *Question:* is a glyph alone the right attempt state, or should it say something?
4. **L27 — Contact form states**, HU and EN: idle, sending (button disabled, label "Küldés…"),
   success (the form is replaced by a confirmation), error (the typed message is kept, an inline
   error and the direct e-mail address are offered).
5. **L28 — 404**, HU and EN, inside the marketing shell (header and footer stay).
6. **L29 — Failed image** (frame with alt text): **hold this one.** The marketing pages contain no
   `<img>` today — every mockup is reproduced HTML/CSS — so there is nothing for it to apply to
   until real captures replace the reproduced UI (LIF-120). Draw it only if you want it ready for
   then.
7. **L30 — Motion notes and open questions** (closing sections). The motion spec is one pattern
   (§2.4), so the notes are short. **The open questions are the part we most want:** every product
   or design question you had to assume an answer to while drawing L01–L21 and these frames.

**Frames to add — mobile (continue after P27):**

8. **P28 — Sponsorship-ended card**, dashboard, both themes. Built as: one dismissible card,
   info glyph, title ("Your coach's Pro has ended" / "Az edződ Pro-ja lejárt"), one reassurance
   line ("…Your data is all still here." / "…Az adataid megvannak."), a close button, **no CTA**.
   *Call made:* no upsell at all — losing sight of history looks like losing data, so the card
   only reassures.
9. **P29 — Price-loading skeleton**, a sub-frame of P08. Built as: two empty plan cards of the same
   shape as the real ones (68 dp, surface tint, **no shimmer, no content**) and the CTA reading
   "Előfizetés" with no amount. *Call made:* never a price before the store returns one.
10. *(Optional, `72` Prompt 17.)* **P11 with one check mark, not two** — the DV-9 fix is in code
    already; the frame is still the old one.

For each frame: name it in the canvas (L22…, P28…), list in a short note what it checks in the
code, and finish with the open-questions section from item 7.

---

## 1. As built — the reference screenshots

All in [`design/as-built/`](design/as-built/) (JPEG, dark, reduced motion). `-hu` / `-en`,
`-desktop` is 1440 px wide, `-mobile` 390 px; the pages are full-height.

| Frame | Files | Route (HU / EN) | Code |
|---|---|---|---|
| L22 / L23 for-trainers | `for-trainers-{hu,en}-{desktop,mobile}.jpg` | `/hu/edzoknek` · `/en/for-trainers` | `web/src/components/marketing/for-trainers/` |
| L24 / L25 app | `app-{hu,en}-{desktop,mobile}.jpg` | `/hu/alkalmazas` · `/en/app` | `web/src/components/marketing/app/` |
| L26 download | `download-{hu,en}-{desktop,mobile}.jpg` | `/hu/letoltes` · `/en/download` | `web/src/app/(marketing-bare)/[locale]/download/page.tsx` |
| L26 invite attempt | `download-invite-attempt-{hu,en}-mobile.jpg` | `…?invite=<token>`, first 1.2 s | `web/src/components/marketing/download/InviteDeepLink.tsx` |
| L26 invite fallback | `download-invite-fallback-{hu,en}-mobile.jpg` | `…?invite=<token>`, after | same |
| L27 contact states | `contact-{idle,sending,success,error}-{hu,en}.jpg` | `/hu/kapcsolat` · `/en/contact` | `web/src/components/marketing/contact/` |
| L28 404 | `not-found-{hu,en}.jpg` | any unknown path under a locale | `web/src/app/(marketing)/[locale]/[...rest]/` |

**Mobile (P28, P29) has no screenshots** — they need a device or emulator. The code is
`mobile/lib/features/dashboard/presentation/widgets/sponsorship_ended_card.dart` and
`_PlanCardSkeleton` in `mobile/lib/features/subscription/presentation/paywall_screen.dart`; the
copy is in `app_en.arb` / `app_hu.arb` under `sponsorshipEndedCard*`.

The capture script is not kept; the shots were taken with Playwright against `npm run dev`, with
the contact endpoint stubbed (`POST /api/v1/contact`) for the four states, as
`web/e2e/marketing/contact-form.spec.ts` does.

---

## 2. Why the pages were built the way they were

The calls in §0 come from the landed notes of the prompts that built the pages
([`65`](65-web-landing-page-plan.md) Prompts 5 and 7, [`72`](72-monetization-followup-plan.md)
Prompt 10, [`67`](67-mobile-free-pro-plan.md) Prompt 6). In short:

- **For-trainers:** composed from L10–L12's vocabulary with no new components. Three of the six
  value blocks reuse the home page's product mockups with new copy; the other three needed a
  visual for a fact that is not a single screen (seat-based pricing parity, sponsored Pro, the
  trial guarantee), so each got a small reproduced-UI card in the same tokens.
- **App page:** one phone because two more mockups with nothing to check them against would have
  been decoration invented from nothing.
- **Download page:** its own route group, because "no header nav, no footer nav" cannot be
  produced inside the shared marketing layout. Badges are inert (no store listing) and say so.
  The invite fallback reveals on a plain timer; an earlier version keyed on tab visibility and got
  stuck.
- **Sponsorship-ended card / skeleton:** built from `69` §12.1 / §12.8's own copy.

---

## 3. When the frames land

- Update the frame maps: [`68` §12](68-web-landing-design-plan.md) (L22–L30) and
  [`69` §11](69-mobile-paywall-design-plan.md) (P28–P29); close [`68` §13](68-web-landing-design-plan.md)
  and [`69` §13](69-mobile-paywall-design-plan.md); tick `72` D3 / D4 and the matching rows in
  [`REMAINING-WORK.md`](REMAINING-WORK.md).
- Walk each frame against its screenshot and the code. Where the canvas wins (`68` says it does),
  open a story for the difference; where the built version is better, say so in the frame map.
- The open-questions section goes to the owner; each answered question either becomes a decision in
  `68` / `69` or a story.
