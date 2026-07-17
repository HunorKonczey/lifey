# Lifey Watch – Design Prompt (F4 state + F5/F6 concepts)

> **Purpose of this file:** a single, self-contained prompt you can hand to Claude
> (or any capable design agent) to design the **Lifey watch app UI** — Apple Watch
> (SwiftUI) and Wear OS (Compose). The design agent will NOT see the mobile app,
> so this document carries the complete brand: every color token, the type scale,
> radii, motion values, and the exact feature set. Nothing else is needed.
>
> Related docs (for humans, not required by the design agent):
> [40-watch-app-plan.md](40-watch-app-plan.md) — the implementation plan;
> F0–F4 are shipped on both platforms, F5/F6 are future v2 phases.

---

## 0. The prompt (copy/paste this to start)

> You are designing the **watch app** for **Lifey**, a personal fitness &
> nutrition tracker. The watch app is a native companion (SwiftUI on watchOS 10+,
> Compose for Wear OS 3+) whose single job is **live strength-workout tracking**:
> the phone starts/ends the workout, the watch measures heart rate + calories and
> displays live state. The current implementation works but is unstyled
> stock-widget UI — your job is to give it the Lifey brand and make it feel like
> a first-class Apple-Workout-quality experience.
>
> Deliver **multiple mockup frames** (round watch face, 396×396 px safe area for
> a 45 mm watch; design once, note platform deltas where relevant):
>
> 1. **Current app (F4 scope) — at least 6 frames**, covering every state listed
>    in §3: idle, active-metrics, active with rest countdown, rest-finished
>    haptic moment, controls/end page, and the error states.
> 2. **F5 concept (set logging from the watch) — its own separate design**, §4.
> 3. **F6 concept (standalone start from the watch) — its own separate design**, §5.
>
> Constraints:
> - Use ONLY the color tokens in §2 — do not invent new hues. The watch is
>   dark-only (AMOLED): build on the true-black/near-black end of the palette.
> - The design must survive a 1-second glance mid-set with sweaty hands: one
>   dominant number per screen, huge tap targets (≥ 48 px), high contrast.
> - Everything must be buildable in plain SwiftUI / Compose for Wear OS — no
>   custom rendering engines, no images-as-UI. Gradients, rounded shapes, SF
>   Symbols / Material Symbols icons are all fine.
> - All copy must exist in EN and HU (the app is localized); design with the
>   longer Hungarian strings in mind (e.g. "Pihenő" = Rest, "Befejezés" = End,
>   "Szett" = Set). Sample copy in mockups may be English.

---

## 1. Brand identity (what Lifey looks and feels like)

The mobile app is a **dark-first, warm brown-green** ("mossy forest") design:

- **Dark is the hero theme.** Near-black warm backgrounds — never cold grey,
  never pure neutral. Surfaces step up in subtle warm layers.
- **Moss-olive green** is the primary accent; **warm brown** secondary;
  **forest green** tertiary. The overall feel is organic, calm, premium —
  not neon-sporty.
- **Rounded everything**: generous corner radii, pill-shaped chips and buttons.
- **Minimal text, icons everywhere**: short labels, one icon per metric/action.
- **Big tabular numbers** for metrics — the hero of any screen is a large,
  weight-800 number with tabular figures so digits don't jump as they tick.

### Typography

Mobile uses **Plus Jakarta Sans**. On watch, use the platform system font
(SF Rounded on watchOS, Roboto/product default on Wear OS) but keep the
**scale relationships and weights**:

| Role | Size (mobile ref) | Weight | Notes |
|---|---|---|---|
| Hero metric (elapsed time, HR) | 34+ | 800 | tabular figures, the one big number |
| Screen/section title | 20–26 | 700 | rarely needed on watch |
| Body / secondary metric | 15 | 500–600 | exercise name, kcal |
| Label / caption | 11–13 | 600–700 | units, "REST", set counter; uppercase labels tracked +0.5 |

### Shape & motion

- Radius scale: **8** (chips/tags) · **16** (buttons) · **20** (cards) ·
  **24** (large cards) · **pill/stadium** for progress chips and small buttons.
- Motion: 150 ms (fast) / 250 ms (base) / 350 ms (slow), easing
  `cubic-bezier(0.2, 0.8, 0.2, 1)` for emphasized transitions. Rest-countdown
  ring should tick smoothly, not stepwise.

---

## 2. Color tokens (complete — this is the entire palette)

The watch app uses the **dark palette only**. `#000000` true black is allowed
(and encouraged) as the outermost background on AMOLED; the warm near-blacks
below are the brand's dark surfaces layered on top of it.

### 2.1 Surfaces (dark, warm near-blacks — stepped layers)

| Token | Hex | Use |
|---|---|---|
| `bg` | `#161611` | deepest brand background (on watch: may sit on #000000) |
| `surface` | `#1C1E16` | cards / grouped content |
| `container` | `#22241B` | elevated cards, stat tiles |
| `containerHigh` | `#2A2C20` | floating bars, prominent containers |
| `containerHighest` | `#32342A` | chips, selected states |
| `outline` | `#3C3E32` | subtle borders/dividers |

### 2.2 Accents

| Token | Hex | Use |
|---|---|---|
| `primary` (moss-olive) | `#9DAE6B` | primary accent: active states, progress, primary buttons |
| `secondary` (warm brown) | `#C49A6C` | secondary accent, warm highlights |
| `tertiary` (forest green) | `#6E9A6A` | success / positive states |
| `primaryContainer` | `#22241B` | filled container behind primary content |
| `secondaryContainer` | `#2A2018` | filled container behind secondary content |
| `tertiaryContainer` | `#1A2E1A` | filled container behind tertiary content |

### 2.3 Text

| Token | Hex | Use |
|---|---|---|
| `onSurface` | `#F1F0E4` | primary text (warm off-white — never pure white) |
| `onSurfaceVariant` | `#A8A899` | secondary/muted text, units, captions |
| `onPrimary` | `#161611` | text on a primary-filled button |

### 2.4 Metric accent colors (dark variants)

Each metric has its own accent — use these for the metric's icon + number tint:

| Metric | Hex | Watch relevance |
|---|---|---|
| `heart` | `#C46A6A` | **heart rate — used constantly** (♥ icon + bpm) |
| `calories` | `#E0915A` | **active kcal — used constantly** (flame icon) |
| `protein` / `positive` | `#9DAE6B` | positive/goal-reached states, set completed |
| `negative` | `#E08A52` | over-budget / warning states |
| `steps` | `#B08AC8` | (not used on watch v1) |
| `water` | `#6FA8C4` | (not used on watch v1) |
| `weight` | `#8AA0B4` | (not used on watch v1) |
| `carbs` | `#D8B35A` | (not used on watch v1) |
| `fat` | `#8E8EC4` | (not used on watch v1) |

### 2.5 Error

| Token | Hex |
|---|---|
| `error` | `#CF6679` |
| `onError` | `#1C0008` |
| `errorContainer` | `#8C1D2F` |
| `onErrorContainer` | `#FFB3BF` |

### 2.6 Suggested watch-specific mappings

- Rest countdown ring/number: `primary #9DAE6B`, flipping to `negative #E08A52`
  for the final 5 seconds (haptic fires at 0).
- Elapsed time: `onSurface #F1F0E4` (neutral hero — the accents belong to HR/kcal).
- End button: `errorContainer` fill + `onErrorContainer` text, or outlined
  `error` — destructive, but must not dominate the metrics page.
- "Connected to phone" affordance: tiny `tertiary #6E9A6A` dot or ⌚/📱 glyph.

---

## 3. Current app — F4 scope (design frames for what exists TODAY)

Context: the workout **always starts and ends on the phone** (v1: phone is
master, watch is display+sensor). The watch shows live data pushed from the
phone (exercise name, set counter, rest timer) merged with locally measured
HR/kcal. Screens are currently: an Idle screen and an Active screen (iOS: single
page today, plan allows Apple-Workout-style paged layout; Android: Compose
equivalent).

Design these frames:

### 3.1 Idle / empty state
- Message: "Start a workout on your phone" (HU: "Indíts edzést a telefonon").
- Lifey brand moment: logo/wordmark or a subtle moss-green mark. Optionally a
  small hint of the paired-phone state. This is the only screen where brand
  decoration is allowed to breathe; keep it calm, not salesy.

### 3.2 Active workout — metrics page (THE hero screen)
Data available: elapsed time (ticks every second), current exercise name,
set counter `setsDone/setsTotal` (e.g. "2/4"), live heart rate (bpm, may be
absent — see 3.6), active calories (kcal), rest state (see 3.3).
- One dominant element: elapsed time OR heart rate (designer's call — argue it).
- HR in `heart #C46A6A` with ♥, kcal in `calories #E0915A` with flame.
- Exercise name may be long ("Bulgarian Split Squat") — plan truncation.
- Set counter as a pill/chip (`containerHighest` bg) or progress dots.

### 3.3 Active workout — rest countdown state
When the phone starts a rest timer, the watch shows a live countdown ("0:47").
This is the watch's killer feature — the user's wrist buzzes when rest ends.
- The countdown should transform the metrics page (e.g. progress ring around
  the dial, or the countdown takes the hero slot) — not just a small text line.
- Final-5-seconds color shift to `negative #E08A52`.

### 3.4 Rest finished — haptic moment
The instant rest hits zero: a strong haptic fires + a brief visual "GO" state
(1–2 s flash/transition, e.g. `primary` fill pulse), then back to metrics.
Design this transient frame.

### 3.5 Controls / End page
- **End button with confirmation** (End on watch only *requests* the phone to
  close the session — the phone remains master). Frame both the control page
  and the confirm step.
- Layout convention: swipe/page left of metrics (Apple Workout pattern) on
  watchOS; on Wear OS either a second page or long-press → controls.

### 3.6 Error / degraded states (design at least these two)
- **"A workout is already running on the watch"** (startRejected — another
  app owns the sensor session). Shown briefly on watch; phone also gets it.
- **Heart-rate permission denied**: workout runs, but no HR — the metrics page
  must look intentional with the HR slot absent or showing "--" (muted
  `onSurfaceVariant`), never broken.

---

## 4. F5 concept — set logging FROM the watch (separate design)

Future v2: a **"+1 set" action on the watch** so the user never pulls out the
phone mid-workout. The watch sends the event; the phone actually logs it
(phone stays master). Only works while the phone is reachable.

Design a separate concept (3–4 frames):
1. Where the **log-set control** lives on the active screen (dedicated page?
   big bottom button? bezel/crown interaction?). It will be hit between sets
   with shaky hands — make it the easiest tap on the whole watch.
2. **Confirmation feedback**: set counter increments (2/4 → 3/4) with a
   satisfying `positive #9DAE6B` micro-animation + haptic; ideally the rest
   timer auto-starts right after — show that chained transition.
3. **Optional reps/weight adjust** (stepper with crown/bezel rotation) — design
   it, but as clearly secondary; default flow must be one-tap "same as planned".
4. **Phone unreachable state**: the control disabled/ghosted with a brief
   explainer ("Phone not reachable" / HU: "A telefon nem érhető el").

## 5. F6 concept — standalone start from the watch (separate design)

Future v2: start a workout **from the watch, without the phone**. The watch
records locally; when the phone reconnects, the session syncs into the app.

Design a separate concept (3–4 frames):
1. **Idle screen evolution**: idle (§3.1) gains a "Start workout" primary
   action (`primary` fill, `onPrimary` text) — the empty state becomes a
   launcher.
2. **Minimal pre-start picker**: choose a template/quick-start ("Quick
   strength" + a few recent plans). Vertical list, `ScalingLazyColumn` /
   List-carousel style, one item = one card (`container` bg, radius 20).
3. **Standalone active screen**: same as §3.2 but with a subtle "standalone /
   not connected" indicator, and set-logging works locally (F5 control reused).
4. **Sync state**: after ending, a "Will sync to phone" summary card (total
   time, kcal, avg HR, sets) — reassure the user nothing is lost. Show the
   synced/pending distinction (`tertiary` check vs. muted pending glyph).

---

## 6. Platform notes for the designer

- **Canvas**: round, design at 396×396 (Apple Watch 45 mm) with a circular safe
  area; Wear OS is also round (454×454 typical) — the same radial layout works.
  Note deltas per frame only where the platforms genuinely diverge.
- **watchOS**: TimeText/status bar is at the top; page dots at bottom;
  horizontal paging between controls ↔ metrics; digital crown scrolls/adjusts.
- **Wear OS**: `TimeText` curved at top; rotary input = crown equivalent;
  ongoing activity indicator may appear on the watch face — no need to design it.
- **Always-on / ambient mode**: design a dimmed variant of the active screen
  (both platforms support it): black background, thin/outline type, no seconds
  ticking, accents desaturated. One frame is enough.
- **Battery honesty**: prefer black/near-black fills over large bright areas;
  the moss green is an accent, not a background.
