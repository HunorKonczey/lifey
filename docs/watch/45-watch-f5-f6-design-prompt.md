# Lifey Watch – Design Prompt for F5 (set logging) + F6 (standalone start)

> **Purpose of this file:** a single, self-contained prompt you can hand to Claude
> (or any capable design agent) to design the **F5 and F6 feature rows** of the
> Lifey watch app and extend the existing design canvas
> (`docs/watch/design/Lifey Watch Design.dc.html`) with them. The design agent
> will NOT see the codebase or the other docs, so this document carries the
> complete brand and the exact as-built state of the current app. Nothing else
> is needed.
>
> Related docs (for humans, not required by the design agent):
> [43-watch-f5-set-logging-plan.md](43-watch-f5-set-logging-plan.md) — F5
> implementation plan; [44-watch-f6-standalone-plan.md](44-watch-f6-standalone-plan.md)
> — F6 implementation plan; [41-watch-design-prompt.md](41-watch-design-prompt.md)
> — the original F4 prompt this one supersedes for F5/F6 scope.

---

## 0. The prompt (copy/paste this to start)

> You are designing two new feature rows for the **watch app** of **Lifey**, a
> personal fitness & nutrition tracker. The watch app (native SwiftUI on
> watchOS 10+, Compose for Wear OS 3+) already ships a fully branded live
> strength-workout experience — the F4 design row exists on the canvas and is
> implemented on both platforms. Your job is to design, **in the same visual
> system**, the two v2 features:
>
> 1. **F5 — set logging from the watch** (§4): a "+1 set" action so the user
>    never pulls out the phone mid-workout. The watch sends an event; the
>    **phone actually logs it** (phone stays master) and the confirmed state
>    flows back. Deliver **4 watchOS + 4 Wear OS frames**.
> 2. **F6 — standalone start from the watch** (§5): start a workout from the
>    watch with no phone around; the watch records locally and the session
>    syncs to the phone later. Deliver **4 watchOS + 4 Wear OS frames**.
>    F6 **reuses the F5 log-set control** (running in local mode), so design
>    F5 first and keep the control identical.
>
> Extend the existing canvas with two new rows ("F5 — set logging",
> "F6 — standalone"), continuing its frame-numbering conventions
> (Apple Watch frames currently run 01–07, Wear OS 01–06). Round faces:
> design at 396×396 px (Apple Watch 45 mm safe area); Wear OS is also round
> (454×454 typical) — same radial layout, note platform deltas per frame only
> where they genuinely diverge.
>
> Constraints (identical to the shipped F4 row):
> - Use ONLY the color tokens in §2 — do not invent new hues. Dark-only
>   (AMOLED), built on true black / warm near-blacks.
> - The design must survive a 1-second glance mid-set with sweaty hands: one
>   dominant number per screen, huge tap targets (≥ 48 px), high contrast.
>   For F5 this is the whole point — the log-set control must be **the easiest
>   tap on the entire watch**.
> - Everything must be buildable in plain SwiftUI / Compose for Wear OS —
>   no custom rendering engines, no images-as-UI. SF Symbols / Material
>   Symbols icons are fine.
> - All copy must exist in EN and HU; design with the longer Hungarian strings
>   in mind (e.g. "+1 szett" = +1 set, "A telefon nem érhető el" = Phone not
>   reachable, "Szinkronizálás a telefonra" = Will sync to phone). Sample copy
>   in mockups may be English. Deliver the proposed string-key list with the
>   frames (see §7).

---

## 1. Brand identity (what Lifey looks and feels like)

The app is a **dark-first, warm brown-green** ("mossy forest") design:

- **Dark is the hero theme.** Near-black warm backgrounds — never cold grey,
  never pure neutral. Surfaces step up in subtle warm layers on true black.
- **Moss-olive green** is the primary accent; **warm brown** secondary;
  **forest green** tertiary. Organic, calm, premium — not neon-sporty.
- **Rounded everything**: radius scale **8** (chips) · **16** (buttons) ·
  **20** (cards) · **24** (large cards) · **pill/stadium** for chips and small
  buttons.
- **Minimal text, icons everywhere**; **big tabular numbers** — the hero of any
  screen is a large weight-800 number with tabular figures.
- Type: platform system font (SF Rounded on watchOS, Roboto on Wear OS).
  Scale: hero metric 34+/800 tabular · body 15/500–600 · caption 11–13/600–700,
  uppercase labels tracked +0.5.
- Motion: 150 ms (fast) / 250 ms (base) / 350 ms (slow), easing
  `cubic-bezier(0.2, 0.8, 0.2, 1)`. Countdown rings tick smoothly, not stepwise.

---

## 2. Color tokens (complete — this is the entire palette)

### 2.1 Surfaces (warm near-blacks, stepped layers on #000000)

| Token | Hex | Use |
|---|---|---|
| `bg` | `#161611` | deepest brand background (may sit on #000000) |
| `surface` | `#1C1E16` | cards / grouped content |
| `container` | `#22241B` | elevated cards, stat tiles |
| `containerHigh` | `#2A2C20` | floating bars, prominent containers |
| `containerHighest` | `#32342A` | chips, selected states |
| `outline` | `#3C3E32` | subtle borders/dividers |

### 2.2 Accents

| Token | Hex | Use |
|---|---|---|
| `primary` (moss-olive) | `#9DAE6B` | active states, progress, primary buttons |
| `secondary` (warm brown) | `#C49A6C` | secondary accent, warm highlights |
| `tertiary` (forest green) | `#6E9A6A` | success / positive / synced states |
| `primaryContainer` | `#22241B` | filled container behind primary content |
| `secondaryContainer` | `#2A2018` | filled container behind secondary content |
| `tertiaryContainer` | `#1A2E1A` | filled container behind tertiary content |

### 2.3 Text

| Token | Hex | Use |
|---|---|---|
| `onSurface` | `#F1F0E4` | primary text (warm off-white — never pure white) |
| `onSurfaceVariant` | `#A8A899` | secondary/muted text, units, captions, ghosted controls |
| `onPrimary` | `#161611` | text on a primary-filled button |

### 2.4 Metric accents

| Metric | Hex | Notes |
|---|---|---|
| `heart` | `#D97F7F` | heart rate (♥ + bpm). **This is the as-built value** — an older prompt said `#C46A6A`; the shipped canvas and both codebases use `#D97F7F`. Use `#D97F7F`. |
| `calories` | `#E0915A` | active kcal (flame icon) |
| `positive` | `#9DAE6B` | goal-reached, **set-logged confirmation** |
| `negative` | `#E08A52` | warnings, final-5-seconds rest countdown |

### 2.5 Error family

| Token | Hex |
|---|---|
| `error` | `#CF6679` |
| `onError` | `#1C0008` |
| `errorContainer` | `#8C1D2F` |
| `onErrorContainer` | `#FFB3BF` |

### 2.6 Established mappings (as shipped — keep consistent)

- **Elapsed time hero: `primary #9DAE6B`** (an older suggestion said neutral
  `onSurface`; the shipped app uses primary olive — follow that).
- Rest countdown ring/number: `primary`, flipping to `negative #E08A52` for the
  final 5 seconds (haptic + a 1–1.5 s "GO" primary-fill flash at zero).
- End button: `errorContainer` fill + `onErrorContainer` text.
- Connected/synced affordance: `tertiary #6E9A6A`.

---

## 3. The app as it exists today (your starting point)

The F4 row is shipped on both platforms. What you are extending:

- **Idle**: brand-moment screen — leaf mark in a `surface` badge + "Lifey"
  wordmark + "Start a workout on your phone" caption.
- **Active — paged layout on BOTH platforms** (this is the key structural
  fact): a horizontal pager with **page 1 = metrics/rest** (elapsed-time hero
  in primary olive, "STRENGTH"/"REST" header chip, ♥ HR + 🔥 kcal accent rows,
  exercise card with set counter — dot-row on Apple Watch, text pill on Wear)
  and **page 2 = controls** (End + Pause, with a dimmed exercise-reminder
  card), with page dots at the bottom. **The metrics page deliberately has no
  buttons** — on round displays, bottom-anchored buttons got clipped by the
  bezel, which is why controls live on their own page. Respect this
  constraint or consciously solve the clipping if you place a button on the
  metrics page.
- **Rest**: the countdown takes over page 1 as a hero with a draining circular
  progress ring, "of 1:30" target line, "Next · <exercise> — Set 3 of 4" line,
  and a small HR/kcal row at the bottom.
- **watchOS extras**: ENDING ("Finish on your iPhone") and SUMMARY ("Workout
  saved" — time/avg bpm/kcal stat tiles, "Saved to Health", auto-dismiss)
  screens exist; Wear OS versions of these are designed separately (not your
  scope, but don't contradict them).
- **Errors**: "Workout already running" screen (icon badge + OK pill) and a
  degraded heart-rate state ("––" muted + "Heart rate off — allow sensors"
  chip).

---

## 4. F5 — set logging from the watch (4 + 4 frames)

Behavioral contract (fixed by the implementation plan — design within it):
the tap sends an event to the phone; the phone logs the set and replies. The
watch shows a **pending** state until the acknowledgment (≤ 5 s), then a
**confirmed** state driven by the phone's reply — the set counter never shows
a number the phone hasn't confirmed. If the phone is unreachable or the ack
times out, the watch shows a failure state. The control is only available
during an active workout; it stays available during rest and while paused.

### Frame F5/1 — where the log-set control lives (the placement decision)

This frame **decides the screen structure**; argue your choice. Options on the
table:
- (a) a large bottom button on the metrics page — fastest access, but must
  solve the round-display clipping problem described in §3;
- (b) a **dedicated pager page** (recommended starting point: log ↔ metrics ↔
  controls, log page first) — one giant tap target filling the page, page
  dots grow to 3;
- (c) hardware interactions (crown/rotary press) are **out** — undiscoverable
  and partly system-reserved.
Design the chosen layout for both platforms, including how the pager/page-dots
change.

### Frame F5/2 — pending → confirmed → chained rest transition

The tap's lifecycle: control goes pending ("Logging…", control inert), then
the set pill increments (2/4 → 3/4) with a satisfying `positive #9DAE6B`
micro-animation + success haptic; when the phone auto-starts a rest timer
(the typical case), the confirmed moment **chains into the rest-hero
takeover** — storyboard that transition (pending state, confirm flash, rest
ring entering).

### Frame F5/3 — optional reps/weight adjust (clearly secondary)

A crown (watchOS) / rotary-bezel (Wear) stepper to tweak reps or weight before
confirming — but the **default flow must remain one-tap "as planned"**. Design
it as a secondary affordance that never slows down the primary tap (e.g.
revealed by rotating before tapping). This ships later than the core flow —
keep it visually detachable.

### Frame F5/4 — phone unreachable / failure

Two related states, distinguish them:
- **Unreachable before the tap**: control ghosted (`onSurfaceVariant`), short
  explainer "Phone not reachable" / HU "A telefon nem érhető el".
- **Ack timeout / rejection after the tap**: brief failure feedback
  ("Couldn't log — try again" / HU "Nem sikerült — próbáld újra") + error
  haptic, control returns to ready.

---

## 5. F6 — standalone start from the watch (4 + 4 frames)

Behavioral contract: the watch starts and owns the whole workout locally (no
phone involved until the end); set logging uses the F5 control in local mode
(no pending state — taps confirm instantly); rest timers are watch-local with
a fixed default length; after ending, the session queues on the watch and
syncs to the phone whenever it reconnects — possibly days later, possibly
several sessions at once. There is no ENDING ("waiting for phone") phase in
standalone mode.

### Frame F6/1 — idle becomes a launcher

The idle brand-moment screen (§3) gains a `primary`-fill, `onPrimary`-text
"Start workout" action. Balance brand calm vs. launcher affordance on a round
display; the "start on your phone" caption demotes or disappears.

### Frame F6/2 — minimal pre-start picker

A short vertical list: "Quick strength" (always present, works with zero
phone contact) + up to ~5 recent plans synced from the phone (title +
exercise count). One item = one card (`container` bg, radius 20); platform
list idioms (List-carousel on watchOS, ScalingLazyColumn on Wear — scrolling
lists ARE fine here, unlike the active screen). Show how a stale/empty
template cache degrades to quick-start only.

### Frame F6/3 — standalone active screen

The F4 active pager (§3) with two deltas: a **discreet** standalone/"not
connected" indicator (this is a normal mode, not an error — do not alarm),
and the F5 log-set control operating locally (instant confirm). Show the
local rest variant (same rest-hero, deadline is watch-local, "of 1:30"
default).

### Frame F6/4 — end summary with sync state

"Workout saved" summary card — total time, kcal, avg HR, sets — plus the sync
status pair: **pending** ("Will sync to phone", muted glyph) vs. **synced**
(`tertiary #6E9A6A` check). Reassure: nothing is lost. Decide and show
whether multiple queued sessions get any surface (a count line is enough) or
sync silently.

---

## 6. Platform notes

- **watchOS**: TimeText/status bar top; page dots bottom; digital crown
  scrolls/adjusts (F5/3 stepper).
- **Wear OS**: curved `TimeText` top; rotary input = crown equivalent; the
  shipped app draws its own 2-dot page indicator (the stock curved one is
  unreliable on round displays) — extending it to 3 dots is fine.
- **Battery honesty**: black/near-black fills; moss green is an accent, never
  a background.
- Ambient/always-on variants are **not** in this scope (tracked separately for
  the F4 row).

## 7. Deliverables checklist

1. Canvas extended with the "F5 — set logging" row (4 AW + 4 Wear frames) and
   the "F6 — standalone" row (4 AW + 4 Wear frames), numbering continued.
2. A one-paragraph rationale for the F5 placement decision (frame F5/1).
3. Proposed EN/HU string-key list covering every new copy string (starting
   set: `log_set_button`, `log_set_pending`, `log_set_failed`,
   `phone_unreachable`, `standalone_start_button`, `standalone_quick_start`,
   `standalone_badge`, `standalone_session_title`, `sync_pending`,
   `sync_done` — extend as the design requires).
4. Per-frame platform-delta notes only where watchOS and Wear OS genuinely
   diverge.
