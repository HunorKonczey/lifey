# 69 – Mobile Paywall, Ads and Store Presence — Design

Status: **design done** — [`design/Lifey Paywall.dc.html`](design/Lifey%20Paywall.dc.html),
frames **P01–P27** (§11). One defect in the canvas must be fixed rather than copied
(§11.2 DV-9); three small additions remain (§13). The eight open questions the designer raised
are answered in §12.
Scope: design (mobile) — paywall, upsell surfaces, ad placement, store listings, download page
Depends on: `docs/design/18-design-system-prompt.md` (mobile tokens),
`mobile/lib/core/theme/app_tokens.dart` (the actual values),
`docs/landing_page/67-mobile-free-pro-plan.md` (what each surface does),
`docs/landing_page/63-monetization-strategy-plan.md` (D-M5, D-M7),
`docs/landing_page/68-web-landing-design-plan.md` (the download page lives on the web site)

The mobile "landing page" is four surfaces, not one: the **paywall** (the screen that sells),
the **upsell moments** (where selling is allowed to happen), the **store listing** (the actual
landing page for most installs), and the **download page** (the bridge from an invite).

---

## 1. Principles

### D-DM1 Free must never look broken

A free user is, statistically, a paying trainer's client or a future one. Every gated surface
shows the *shape* of what is behind it — a locked row left in the range menu, a history boundary row
rather than a truncated list, a credit counter rather than a missing button. Nothing is
removed; things are marked.

*Rejected: hiding gated features entirely.* Cleaner UI, zero upsell, and a user who never
learns the product has more to give.

### D-DM2 One paywall layout, five headlines

`paywall_screen.dart` renders the same structure for every trigger (`67` §4.3); only the
headline, the sub-line and the highlighted benefit change. Five bespoke paywalls is five
places for a price to go stale.

### D-DM3 The ad is a guest, and it sits where a guest sits

Bottom of the content, above the navigation, inside the safe area, never over a control,
never in a scroll position the user did not choose to reach. It never animates in, and it
never reserves space before it exists (`67` §5.2).

### D-DM4 Tokens only — the paywall is not a special world

The paywall uses `AppTokens` exactly as every other screen does: `--r-card` (20), `--r-pill`,
`primary`, `secondary`, `tertiaryContainer`, the Plus Jakarta Sans scale. No gradient mesh, no
gold, no confetti. The product is a training tool and the purchase screen should feel like the
same tool, not like a different app's checkout.

---

## 2. Where selling is allowed

| Surface | Allowed | Notes |
|---|---|---|
| Statistics range menu | yes | two locked rows in the popup (§4.1) — not a chip row |
| History boundary row | yes | one row at the cutoff |
| AI action | yes | credit counter, then paywall at zero |
| Ad banner "Remove ads" affix | yes | the only ad-adjacent CTA |
| Settings tile | yes | the permanent, non-intrusive entry |
| End of onboarding | once | a dismissible card, never a wall |
| **Active workout / cardio session** | **no** | nothing, ever |
| **Watch, widgets, notifications** | **no** | (`67` D-P10) |
| **Chat** | **no** | (D-M8) |
| **A sponsored client, anywhere** | **no** | (`67` D-P9) |
| App start | no | no launch interstitial, no "welcome back" upsell |

---

## 3. The paywall screen

Full-screen route, not a bottom sheet — it carries a plan choice, two prices, legal text and
a restore action, and a sheet at that height is just a worse full screen.

### 3.1 Structure, top to bottom

| Slot | Spec |
|---|---|
| **Close** | 44 × 44 tap target, top-left (iOS) / top-left (Android, matching the app's existing back convention), `close` icon in `onSurfaceVariant`. First focusable element (`67` §7). |
| **Crest** | 72 px `workspace_premium` glyph in `primary`, on a 96 px `tertiaryContainer` circle. One graphic, not an illustration. |
| **Headline** | 28 / 700, centred, max 2 lines. Per trigger (§3.2). |
| **Sub** | 15 / 500 `onSurfaceVariant`, centred, max 2 lines. |
| **Benefits** | Three rows, 16 px gap: filled icon in `primary` (28 px) + 15/600 title + 13/500 `onSurfaceVariant` line. Order is fixed: *Nincs reklám · Teljes előzmény · Korlátlan AI*. The row matching the trigger gets a `tertiaryContainer` background and `--r-card`. |
| **Plan selector** | Two stacked cards, not a segmented control — each needs a price, a period and a badge. Selected: 2 px `primary` border + `tertiaryContainer` fill. Yearly pre-selected with a `secondary` pill reading "2 hónap ingyen" and a `13/500` per-month equivalent underneath. |
| **CTA** | Full-width pill, 56 px, `primary` fill, `bg` text, 16/700. Label: "Előfizetés — {store price}". Loading state swaps to a 22 px spinner, width held. |
| **Legal line** | 11/500 `muted`, centred: renewal terms, cancel-anytime, and the two links (ÁSZF, Adatkezelés). Required by both stores; must be *readable*, not 8 px grey-on-grey. |
| **Restore** | Text button, `onSurfaceVariant`, below the legal line. Required by App Review. |

Scroll: the whole column scrolls, and the CTA + legal + restore block pins to the bottom
above the safe area once the content exceeds the viewport. On a 320 × 568 device the crest
shrinks to 56 px and the benefit sub-lines drop — specified, not left to overflow.

### 3.2 Headlines per trigger

| Trigger | Headline (HU) | Highlighted benefit |
|---|---|---|
| `historyRange` | "Lásd a teljes történetedet" | full history |
| `aiCredits` | "Fogyott az AI-kereteted" | unlimited AI |
| `adRemoval` | "Edzés reklámok nélkül" | no ads |
| `settings` | "Lifey Pro" | none (all three neutral) |
| `onboarding` | "Próbáld ki a Pro-t" | none |

English strings are translations; Hungarian is the original (`68` §2.2 applies here too —
the Hungarian headline sets the slot size).

### 3.3 Special states

- **Sponsored** (`67` D-P9): crest in `secondary`, headline "A Pro-t az edződ állja", the
  three benefits shown as *already active* with `check_circle` in `tertiary`, no plan
  selector, no CTA, and a single "Rendben" button.
- **Products unavailable**: crest greyed, one line of copy, a "Próbáld újra" secondary
  button. Never a fabricated price.
- **Purchase pending** (offline StoreKit, `67` §9.4): a `tertiaryContainer` info card above
  the CTA — "A vásárlás feldolgozás alatt. Amint online vagy, aktiváljuk."
- **Already Pro, reached by deep link**: the sponsored layout with "Aktív előfizetésed van"
  and a "Kezelés" button to the store.

---

## 4. Gated surfaces and ads

### 4.1 Locked rows in the range menu — *not* a chip row

**Corrected against the code (DV-7).** This section originally specified a row of range chips
with lock affixes. There is no such row: `statistics_screen.dart`'s `_StatsRangeButton` is a
`PopupMenuButton` rendering a **single** `_FilterChip`, and the four ranges live in its popup
(`shared/widgets/charts/stats_range.dart`) —
`7 nap · 30 nap · 90 nap · Összes` (`week` / `month` / `quarter` / `all`).

With a 30-day free window (D-M5), **two rows are locked: "90 nap" and "Összes"**. Locked row:
label at 60 % opacity, a 16 px `lock` glyph in `secondary` where the check mark sits for the
selected row, and the row stays tappable — tapping opens the paywall with the `historyRange`
trigger and closes the menu. The trigger chip itself is never locked and never changes
appearance; the gate lives entirely inside the menu.

*Rejected: hiding the two locked rows.* A two-item menu teaches the user nothing and removes
the only place the history limit is visible at all.

### 4.2 History boundary row

Where the list crosses the cutoff: a full-width row, `surfaceContainer`, `--r-card`, 16 px
padding, a 20 px `history` glyph in `primary`, 14/600 "Régebbi adataid megvannak — a Pro
megmutatja", and a chevron. Below it, **nothing** — the list ends there. Not a fade-out, not
a blurred fake list. A blurred teaser of your own data is a hostile pattern.

### 4.3 AI credit counter

A `--r-pill` chip beside the AI action: `surfaceContainer` fill, 12/700 `tabular-nums`,
"3/3", turning `secondary` at 1 remaining and `error`-toned at 0. ICU plural in both locales
(`67` §6).

### 4.4 Banner ad slot

**The bottom navigation is not a solid bar (DV-8).** `AdaptiveBottomNav` is a *floating,
scroll-reactive* nav: 58 dp tall with a 26 dp bottom gap plus the safe area, 14 dp side margins
when expanded, collapsing to a **centred stadium pill (icons only)** on scroll, and mounted with
`extendBody: true` so content scrolls underneath it. There is no bar to sit "above", which makes
the slot's placement a real decision rather than a detail — it is `71` §4's open question, to
be resolved with drawn frames, not in code.

- Anchored adaptive banner, full width, its natural height (typically 50–60 dp).
- Placement: **to be decided from the two variants in `71` §4** — anchored below the floating
  nav, or scrolling as the last item in the list. Whichever wins, it must be drawn in both the
  nav-expanded and the nav-collapsed (pill) state.
- Background `surfaceContainer` behind the ad so a transparent creative never shows the page
  content through it; a 1 px `outline` hairline on top.
- A 12 px "Reklám" label in `muted` at the top-left of the slot — honest, and it stops the ad
  reading as product UI.
- A 24 × 24 `block` icon at the top-right is the "Remove ads" affordance → paywall,
  `adRemoval` trigger. It has a 44 px tap target.
- Renders **nothing** — zero height, no hairline, no label — when not showing an ad.
- On Dashboard, it must clear the FAB: content padding accounts for slot height + FAB height,
  and this is a layout test, not an eyeball check (`67` Prompt 9).

### 4.5 Interstitial

Standard AdMob full-screen; no custom design. The only design decision is the *moment*: after
the success feedback of a completed log has been seen, never instead of it. If a workout-saved
celebration dialog exists (the `--success-*` tokens in the design system), the interstitial
comes after it is dismissed, never before.

### 4.6 Consent dialog

Google UMP's own UI, configured with the app's name and privacy URL. No custom pre-prompt
screen — a "we're about to ask you about ads" interstitial is one more screen between the user
and the app, and it depresses consent rates rather than raising them.

---

## 5. Store listings (App Store + Google Play)

The store page is the real landing page for most installs, and it is designed, not typed.

### 5.1 Screenshot set — 6 frames, per platform, per language

Same composition on both stores, sized per platform (6.9" + 6.5" iPhone, 12.9" iPad if the
app ships there; phone + 7"/10" tablet on Play).

| # | Frame | Caption (HU) |
|---|---|---|
| 1 | Dashboard, full day of data | "A napod egy képernyőn" |
| 2 | Workout session logging, mid-set | "Sorozatok, ismétlések, súlyok — gyorsan" |
| 3 | Nutrition + macro rings | "Kalória és makrók, keresés nélkül is" |
| 4 | Cardio with a GPS route | "Futás, bringa, túra — térképpel" |
| 5 | Watch app on a wrist render | "Az órádról is" |
| 6 | Trainer chat + assigned program | "Az edződ programja, egy appban" |

Style: device frame on a `bg`-toned background, caption above the device in 32/800
`onSurface`, one accent word per caption in `primary`. Dark theme throughout — it is the
brand's stronger look and it stands out in a search-results row of white screenshots.

**Frames 1–6 show the Pro/unlocked state**: no ad banner, no lock icons, no boundary row
(`67` §9.8). Showing a paywall in a store screenshot is allowed only for a screenshot that is
*about* the paywall, and none of these are.

### 5.2 Text

| Field | HU | EN |
|---|---|---|
| App name | `Lifey — Edzés & Táplálkozás` | `Lifey — Workout & Nutrition` |
| Subtitle (iOS, 30 ch) | `Edzésnapló, kalória, edződ` | `Training log, calories, coach` |
| Short description (Play, 80 ch) | one sentence covering log + coach | as HU |
| Keywords (iOS, 100 ch) | edzésnapló, kalóriaszámláló, konditerem, makró, súlyzós, futás, edző, fogyás | workout log, calorie counter, gym, macros, strength, running, coach |
| Full description | Problem → three feature blocks → the coaching angle → free/Pro disclosure | as HU |

The full description **must** disclose the subscription terms and link to the terms and
privacy policy (both stores require it; Play rejects for a missing one).

### 5.3 Other required assets

- Play feature graphic 1024 × 500: wordmark + the tagline + a single phone, dark.
- App icon: unchanged.
- Privacy answers: App Privacy (iOS) and Data Safety (Play) filled from the actual AdMob and
  backend data flows (63 §5). Wrong answers here are a rejection, and a repeated wrong answer
  is an account problem.

---

## 6. The download / invite bridge page

Lives on the web site (`65` §4, `68` §6) but is designed here because its whole job is mobile.

### 6.1 Layout

Single column, centred, no header nav, no footer nav — wordmark, one line, two store badges
at 200 × 60, and the legal links in 11/500. No QR (§6.3). Nothing scrolls on a phone.

### 6.2 The invite handoff

A trainer's invite email links to `/hu/letoltes?invite=<token>`:

1. The page stores the token in `sessionStorage` and in a short-lived cookie.
2. It attempts a deep link to `lifey://invite/<token>` — if the app is installed, the app
   opens on the invite card and the page is never seen.
3. If the deep link does not resolve within ~1.2 s, the page renders normally with the store
   badges and a line: *"Töltsd le az appot — a meghívód megvár."*
4. After install, the invite is found by the account's email on first login
   (`docs/personal_trainer/01-koncepcio-es-folyamatok.md` already delivers pending invites by
   polling), so no deferred-deep-link SDK is needed.

### D-DM5 No attribution SDK for deferred deep linking

Branch/AppsFlyer-style deferred deep linking is a third-party SDK, a privacy disclosure and a
recurring cost, to solve a problem the invite polling already solves. The email-matched invite
*is* the deferred deep link.

*Rejected: Firebase Dynamic Links.* Shut down; not a foundation to build on.

### 6.3 ~~The QR~~ — withdrawn (see §11, DV-4)

**There is no QR anywhere in this flow.** This section originally specified a QR card on the
download page and on the trainer's `/admin/invites` screen. It was wrong: an invite is bound to
an **email address**, not to a scannable token
(`docs/personal_trainer/01-koncepcio-es-folyamatok.md`), and the client's app finds the pending
invite by polling after they first sign in. A QR would either encode a link that does nothing
the email link does not already do, or imply a second, tokenised invite path that does not
exist.

The web canvas states this in the product copy — L16, step 2: *"E-mail címmel. Amikor először
belépnek az appba, összekapcsolódtok — nincs kód, nincs QR."* The download page (§6.1) drops
its QR card accordingly.

---

## 7. States to design

| Surface | States |
|---|---|
| Paywall | loading products · loaded · purchasing · pending · success · failed · unavailable · sponsored · already Pro |
| Banner slot | hidden · loading (hidden) · loaded · failed (hidden) |
| Credit chip | 3 · 1 · 0 |
| Settings tile | free · Pro (own) · Pro (sponsored) · trainer trial |
| Boundary row | present · absent (Pro) |
| Download page | deep-link attempt · fallback · no invite token |

---

## 8. Accessibility

- Paywall: close button first in the focus order; every plan card is a single semantic
  radio; the legal line is real text at 11 px minimum with ≥ 4.5:1 contrast (the `--muted`
  token was corrected for exactly this).
- Ad slot: `Semantics(label: 'Hirdetés')`, excluded from the reading flow of the content
  above it.
- Locked chip: semantics label states the reason ("2024 — Pro szükséges"), not "locked".
- Dynamic Type / large font scale: the paywall must survive 200 % text scale — benefits
  collapse to title-only, the crest hides, the CTA never truncates.
- No purchase decision communicated by colour alone; the selected plan also carries a
  `check_circle`.

---

## 9. Acceptance criteria

- [ ] One paywall layout, five headline variants, all four special states designed.
- [ ] Every gated surface marks rather than removes (D-DM1).
- [ ] Ad slot renders zero height when there is no ad; never overlaps FAB or navigation.
- [ ] "Reklám" label and the remove-ads affordance present on every banner.
- [ ] No selling surface in an active session, on the watch, in chat, or for a sponsored user.
- [ ] Store screenshots show the unlocked state, in both languages, dark theme.
- [ ] Subscription terms + both legal links present on the paywall and in both store listings.
- [ ] Paywall usable at 200 % text scale and on a 320 pt wide screen.
- [ ] Download page works with the app installed and without, on both platforms.

---

## 10. Non-goals

- A custom paywall visual language (gradients, gold, celebration animation).
- Countdown timers, "limited offer" pressure, or any urgency the offer does not actually have.
- A pre-consent explainer screen (§4.6).
- An attribution SDK (D-DM5).
- Native ad formats, list-embedded ads, or an ad on any screen not listed in §2.
- A separate tablet paywall design — the phone layout centred at 480 px max width is enough.

---

## 11. The delivered canvas — frame map and deviations

[`design/Lifey Paywall.dc.html`](design/Lifey%20Paywall.dc.html), frames **P01–P27** — every
frame `71` §0 asked for. The canvas is the source of truth; §11.2 records where it and §1–§10
disagree, and which won.

### 11.1 Frame map

| Frame | Contents | Spec | Implements (`67` §8) |
|---|---|---|---|
| **P01** | Token sheet — paywall scale, buttons, plan-card spec, dark + light | §3.1 | read values from here |
| **P02** | Paywall, `settings` entry · dark · HU | §3.1 | Prompt 6 |
| **P03** | Same · light · EN | §3.1 | Prompt 6 |
| **P04–P06** | The three trigger variants — history · AI · ads | §3.2 | Prompt 6 |
| **P07** | Sponsored state — no plan cards, no purchase | §3.3, `67` D-P9 | Prompt 6 |
| **P08** | Unavailable · pending · already-subscribed | §3.3 | Prompt 6 |
| **P09** | Purchasing (spinner) · success | §7 | Prompt 5–6 |
| **P10** | 320 pt width · 200 % text scale | §3.1, §8 | Prompt 6 |
| **P11** | Range popup, two locked rows · dark HU + light EN | §4.1 | Prompt 3 |
| **P12** | History boundary row in a workout list · both themes | §4.2 | Prompt 3 |
| **P13** | AI credit chip at 3 / 1 / 0 | §4.3 | Prompt 4 |
| **P14** | Settings subscription tile, four states · both themes | §4 | Prompt 7 |
| **P15** | Ad slot **variant A — anchored**, nav expanded / collapsed / light | §4.4 | Prompt 9 |
| **P16** | Ad slot **variant B — in-scroll**, nav expanded / collapsed | §4.4 | Prompt 9 |
| **P17** | Pro / sponsored dashboard — no slot at all, both themes | §4.4, `70` DD-4 | Prompt 9 |
| **P18–P23** | Six store screenshots, dark, HU captions | §5.1 | M5 |
| **P24** | The same six, EN captions, contact sheet | §5.1 | M5 |
| **P25** | Play feature graphic 1024 × 500 | §5.3 | M5 |
| **P26** | Motion notes + reduced-motion | §7 | Prompt 6, 9 |
| **P27** | Open questions — eight of them, answered in §12 | — | — |

### 11.2 Deviations and defects

**DV-9 ⚠ P11 draws a check mark on *two* rows ("7 nap" and "30 nap").** **Defect — do not
implement as drawn.** The frame uses the check to mean "included in your plan". The control does
not: `statistics_screen.dart` renders `r == range ? Icon(Icons.check) : null`, so the check marks
the **currently selected** range and there is never more than one. Implemented literally this
produces a menu with two check marks and no way to tell what is selected.

*Fix:* one check, on the selected row only ("30 nap" in this frame); "7 nap" gets the empty 20 px
slot the code already reserves. The locked rows keep their `lock` glyph in that same slot — that
is the frame's genuinely good idea and it should survive. `67` Prompt 3 owns the fix, and the
frame should be corrected in the same change.

**DV-10 The ad recommendation is variant A, conditioned.** The canvas recommends the **anchored**
banner (P15) over in-scroll (P16), on the grounds that on a dashboard the user rarely reaches the
bottom of the list, so B loses most of the impressions rather than some — but **only on the four
main tab screens**, with zero on detail screens, modals, during a session, in chat and on the
watch. **Accepted**, and it also answers P27's fifth question (§12.5). This widens `63` D-M7 by
one surface: the workouts tab was not in D-M7's list of three and now is. The active-session
prohibition is untouched.

**DV-11 P13 puts a concrete refill date in the exhausted chip** — *"Szeptember 1-jén
újratöltődik"*. Correct, and it matches the backend: `64` §3.4 counts into
`ai_usage_counter (user_id, year_month, used_count)` where `year_month` is a `char(7)`, i.e. a
**calendar month**. Recorded because that copy stays true only while the column shape does.

**DV-12 P13 keeps the AI row tappable at 0/3.** The row explains rather than fails, and the chip
never disables the control. D-DM1 applied more strictly than §4.3 asked for. Accepted.

**DV-13 P16 places the in-scroll banner *below* the history boundary row.** The right ordering if
B were ever chosen — the last thing in the list is the explanation of where the data went, not an
ad wedged between the user's data and that explanation. Moot under DV-10; kept in case the
placement is revisited.

**DV-14 §4.1's "60 % opacity" on a locked range row is dropped — the spec yields to WCAG AA.**
`_RangeMenuRow` implemented it literally, and it is the same pattern commit `1c252fd` removed
from 15 other places in the app after measuring 0.6–0.8 alpha secondary text at 2.9–3.9:1. That
sweep missed this one because it dims with `Opacity()` around a subtree rather than an alpha'd
colour. Locked rows now draw at full alpha; the `lock` glyph in the check mark's own slot and the
row's semantics label carry the state, which is what §8 ("no gate communicated by colour alone")
wants anyway. Fixed in `72` Prompt 8, along with a second defect found there: the row's semantics
label *merged* with its own text, so a screen reader read "90 days — Pro required, 90 days" — it
now replaces it (`ExcludeSemantics`).

**DV-15 P15's slot chrome was drawn correctly and implemented wrongly — now corrected in code.**
The frame draws a 12 px muted "Reklám" label and the `block` glyph in a 44 × 28 target in a row
**above** the creative. `67` Prompt 9 shipped a `Stack` instead: the button painted on top of the
`AdWidget`, and no label at all — failing §4.4, failing §9's acceptance criterion, and putting a
control over a served ad, which AdMob treats as obscuring it. Rebuilt as the frame draws it in
`72` Prompt 7; no design change, so nothing to redraw.

---

## 12. The eight open questions from P27 — answered

Two were already settled in the plans and the canvas guessed right; five are decided here; one is
a real gap needing a small design addition.

### 12.1 A sponsored client whose trainer leaves — *decided here*

Pro ends after the 7-day grace (D-M10), and at that moment history beyond 30 days disappears from
the lists. Two rules:

1. **The "never sell to them" rule ends with the sponsorship.** Once the relationship and its
   grace are over they are an ordinary free user, and the paywall becomes reachable. The rule in
   §2 and `67` D-P9 is scoped to *while sponsored* — a churned client who can never buy Pro is an
   absurd outcome.
2. **One notice, once, never a modal.** At the first app open after grace ends, the Settings tile
   flips to the free state and the dashboard shows a single dismissible card: *"Az edződdel való
   kapcsolat lezárult, így a Pro funkciók kikapcsoltak. Az adataid megvannak."* No push, no
   full-screen takeover, no immediate paywall. The data reassurance is the important half —
   losing sight of your history looks exactly like losing it.

Needs one frame and two ARB strings (§13).

### 12.2 Is there a free trial on mobile Pro? — *decided: no*

**No introductory trial.** The free tier is fully usable; the app itself is the trial, which is
the entire point of D-M5. A store trial would also add trial-state handling to `64` §6 for a
1 490 Ft/month product. The canvas drew no trial, which is correct.

Reversible, but not cheaply: it changes the plan-card label, the CTA text and the legal line —
all three store-reviewed. Revisit only with evidence that the paywall converts badly.

### 12.3 Calendar month or rolling 30 days for AI credits? — *already decided: calendar month*

`64` §3.4; see DV-11. The canvas guessed right, no change.

### 12.4 Does the 30-day window limit display or storage? — *already decided: display only*

`67` D-P6 and `63` §8.7, emphatically: sync keeps pulling and storing everything, the window is a
presentation filter. The boundary row's *"Régebbi adataid megvannak"* is therefore literally
true — and it is the one line of copy in the app that would become a lie if the window were ever
"optimised" into the sync layer.

### 12.5 Which screens may show the anchored banner? — *decided: the four tab roots only*

Per DV-10. Dashboard, nutrition, workouts, statistics. Nothing on detail screens, modals, sheets,
onboarding, chat, during a session, or on the watch. `63` D-M7 and `67` §5.2 gain the workouts
tab and are otherwise unchanged.

### 12.6 What does a client see about a trainer trial? — *decided: the tile renders the resolved source*

The Settings tile shows whatever `source` the server resolved (`63` §3), never a merge of two. A
user who is both a trainer and someone's client resolves by that order — own paid, then
sponsored, then trainer trial — so the trainer-trial state appears only when it genuinely is the
winning source. Its CTA points at the **web** billing page, because there is no trainer purchase
UI on mobile and there will not be one (D-M1).

### 12.7 Where do the ÁSZF / privacy links open? — *decided: the system browser*

External browser, not an in-app webview. Both stores accept either; the browser costs no webview
to maintain, no back-navigation edge cases and no extra CSP surface. `67` Prompt 6 wires it.

### 12.8 What is shown while the store prices load? — *a real gap, needs one frame*

`71` asked for the terminal *unavailable* state (P08a) and got it, but not the few hundred
milliseconds before the store answers. Rule: **plan cards render as skeletons and the CTA reads
"Előfizetés" with no amount** until real prices arrive; the amount is appended only once it is
real (`67` §4.1 — never a fabricated price). Needs one sub-frame on P08 (§13).

---

## 13. What is still outstanding

Small, and none of it blocks `67`'s prompts:

1. **DV-9 fix in P11** — one check mark, not two. Fixed in code (`67` Prompt 3); the frame itself
   is still undrawn, and is now `72` Prompt 17's job.
2. **Sponsorship-ended card** (§12.1) — one dismissible dashboard card, both themes. **Built
   without a frame** in `72` Prompt 10, from §12.1's own copy: `surfaceContainer` card, info
   glyph, title + reassurance line, close button, no CTA. A frame is still worth having to check
   that call against.
3. **Price-loading skeleton** (§12.8) — one sub-frame on P08. **Built without a frame** in `67`
   Prompt 6 (two skeleton plan cards, CTA reading "Előfizetés" with no amount), same note.
4. **Download page frames** — still on the web side (`68` §13.3), unchanged by this canvas.

Everything else `71` asked for was delivered.
