# 77 – Mobile Redesign (Design System v2)

Status: in progress — R0 done (R0.1–R0.14 + review fixes R0.fix-1…7, reviewed 2026-09-25); R1 done (R1.1–R1.8 + review fixes R1.fix-1…3, reviewed 2026-09-25); R2 done (R2.1–R2.9 + review fix R2.fix-1, reviewed 2026-09-25); R3 done (R3.1–R3.11 + review fixes R3.fix-1…5, reviewed 2026-09-25); R4 in progress (R4.1–R4.3 done)
Scope: mobile (all screens) · design system · one optional backend step (R6.2) · docs
Depends on: the Claude Design output in this folder (`Lifey Design System.dc.html` + six screen
canvases), commissioned by [docs/design/21-design-modernization-prompt.md](../design/21-design-modernization-prompt.md).
Supersedes the token values of [docs/design/20-design-implementation-tasks.md](../design/20-design-implementation-tasks.md)
(the first redesign) — its structure (tokens → components → screens) is reused, its values are not.
Branch: `feature/mobile-redesign` (integration branch, cut from `main` on 2026-09-24).

---

## 0. How to read this plan

The plan is split into **eight iterations**. R0 is the general, app-wide foundation (the
`Lifey Design System.dc.html` canvas). R1–R6 map one-to-one onto the six screen canvases. R7 is
the closing sweep for everything no canvas drew, plus the removal of the old system.

| Iteration | Design source | What it delivers | Demo at the end |
|---|---|---|---|
| **R0** | `Lifey Design System.dc.html` | Tokens, type, formatting, motion, every shared component, header, bottom nav, sheet, charts, a debug design gallery | Gallery screen in both themes; every existing screen already on the new palette |
| **R1** | `Lifey 1 Dashboard.dc.html` (1.1–1.3) | Today screen rebuilt: hero calorie card, tiles, weekly bar chart, meals + workouts lists | Dashboard matches the canvas in dark / light / HU |
| **R2** | `Lifey 2 Nutrition.dc.html` (2.1–2.4) | Week strip, day budget, meal editor with floating total, add-food sheet, recipe grid, macro rings | Log a meal end-to-end on the new UI |
| **R3** | `Lifey 3 Workouts.dc.html` (3.1–3.3) | Sessions list, live strength log (rest hero, set rows, PR language), PR sheet, live cardio, cardio detail | Run a strength and a cardio session end-to-end |
| **R4** | `Lifey 4 Weight Stats.dc.html` (4, 5) | Weight hero + goal band + chart + log sheet; Stats metric chips, hero number, per-metric summaries | Log a weight, browse stats for 4 metrics |
| **R5** | `Lifey 5 Onboarding Chat Settings.dc.html` (6–8) | Login, onboarding, chat thread, settings (grouped lists, honest logout) | New account → onboarding → chat → settings → logout |
| **R6** | `Lifey 6 Trainer.dc.html` (9.1–9.2) | Trainer shell in the client family, client cards, client detail, tablet 3-column | Trainer flow on phone and 1280×800 tablet |
| **R7** | — (derived) | Undesigned screens, removal of legacy widgets/aliases, docs + audit | Zero legacy header/nav usages; audit script clean |

**Smallest thing worth using:** R0 + R1. After those two, the whole app is on the new palette,
type and navigation, and the most-seen screen is fully redesigned. Everything after R1 can be
paused without leaving the app in a broken or inconsistent-looking state (see D-R0.1).

Every iteration has the same shape: **goal → design source → current code → target spec →
steps (prompt-sized) → derived screens → verification → acceptance → emulator review (§4.1)**.
No iteration counts as done until its emulator review is written up. Steps are numbered
`R<iteration>.<n>` and are the unit of work: one surface, one session, independently mergeable.

---

## 1. What we're building

1. **A new design system (v2)** built on the existing identity — dark-first, warm olive/earth
   tones, per-metric colour coding — with layered surfaces, big tabular numbers, a 4-step radius
   scale, a motion spec and a fixed set of shared components.
2. **Every mobile screen restyled** to that system: the 9 designed areas (dashboard, nutrition,
   workouts, weight, statistics, auth/onboarding, chat, settings, trainer) and all undesigned
   secondary screens by analogy.
3. **One header system and one bottom nav** for the whole app — large-title header with a
   status-bar scrim, a subpage header (back + title) used by chat and every former plain
   `AppBar` screen, and a bottom nav whose active tab expands into a labelled pill.
4. **Fixes the design called out:** content no longer slides under the status bar; charts get
   axes, goal lines and legends; meaningless aggregates (weight "Total") disappear; number
   formatting and plurals are consistent ("17 519 kcal", "1 exercise"); no truncation in
   Hungarian; tinted chips reach WCAG AA; the trainer shell stops using a second green.
5. **Small UX relocations the design specifies** (not new features): logout moves from the
   dashboard to the bottom of Settings with a confirmation; "copy day" moves into the nutrition
   header; per-row delete buttons move into `⋮` menus / long-press / detail pages; the
   workout filter moves into a header icon; the stats period switcher moves under the chart.
6. **Both themes are first-class.** Light is not an inversion of dark; it has its own
   text-safe metric colours and uses shadow (not borders) for depth.

**When nothing is "on":** there is no feature flag (D-R0.1). Before R0 lands the app looks as
today; after R0 every screen uses the new tokens even before its own iteration lands; after
its iteration a screen also has the new layout.

---

## 2. Current state (what already exists)

| Area | Where | Relevance |
|---|---|---|
| Colour scheme + text theme | `mobile/lib/core/theme/app_theme.dart` (249 lines) | Values replaced in R0.1/R0.3; structure kept |
| Spacing / radius / motion / metric colours | `mobile/lib/core/theme/app_tokens.dart` (`AppSpacing`, `AppRadius`, `AppDuration`, `AppCurve`, `AppMetricColors` ThemeExtension + `context.metricColors`) | Extended in R0.1/R0.2 |
| Font | `mobile/assets/fonts/PlusJakartaSans-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf`, bundled in `pubspec.yaml`; all five files carry the `tnum` OpenType feature | No change needed; tabular figures will work |
| Floating top bar | `shared/widgets/adaptive_app_bar.dart` (422 lines, pill-shaped, 16 users) | Replaced by `LifeyHeader` (R0.9), deleted in R7 |
| Bottom nav | `shared/widgets/adaptive_bottom_nav.dart` + `nav_collapse_controller.dart`, used by `main_shell.dart` and `trainer_shell.dart` (`accentColor: scheme.tertiary`) | Visuals rewritten in R0.10, public API kept |
| Plain Material `AppBar`s | 14 files: `change_password_screen`, `chat_search_screen`, `chat_thread_screen`, `chat_attachment_view`, `barcode_scanner_screen`, `onboarding_edit_screen`, `generated_recipe_screen`, `notification_settings_screen`, `trainer_invites_screen`, `program_detail_screen`, `trainer_settings_screen`, `water_sources_screen`, `template_picker_screen`, `placeholder_screen` | Each migrated to `LifeySubpageHeader` in its iteration |
| Charts | `shared/widgets/charts/time_series_chart.dart` (504), `pace_bar_chart.dart` (264), `stats_range.dart`; dashboard `calorie_sparkline_card.dart`; trainer `weight_sparkline.dart`, `trend_chart_card.dart`; workouts `elevation_profile_chart.dart`, `route_painter.dart`, `hr_zone_panel.dart` | All custom-painted — stays that way (D-R0.9) |
| Shared states | `empty_view.dart`, `error_view.dart`, `app_snackbar.dart`, `confirm_delete_dialog.dart`, `pill_tab_bar.dart`, `date_range_filter_bar.dart`, `shell_fab.dart`, `offline_banner.dart`, `sync_status_indicator.dart` | Restyled in R0, not forked |
| Hard-coded styling debt | 396 `fontSize:` literals, 348 `BorderRadius.circular(` literals, 70 `Color(0x…)` literals outside `core/theme/` (worst: `workout_success_dialog.dart` 21, `confirm_save_details_dialog.dart` 10, `app_snackbar.dart` 7) | Removed file by file as each iteration touches them; R7 audits the remainder |
| Number formatting | 23 `NumberFormat` call sites, 72 `toStringAsFixed` call sites, `core/format/cardio_formatter.dart` | Centralised in R0.4, adopted per iteration |
| Logout | `features/auth/application/auth_controller.dart` `logout()` — wipes the local DB **including the unsynced outbox**, no confirmation; the only entry point is the dashboard header icon. Settings has no logout row. | R1.1 adds the Settings row before the dashboard icon goes; R5.6 makes the dialog honest (see §9 risk 9) |
| Tests | `mobile/test/{core,features,shared}`, no golden tests; CI (`.github/workflows/mobile-ci.yml`, ubuntu) runs `flutter analyze` + `flutter test` | Goldens stay out (D-R0.11) |

---

## 3. Key design decisions

### D-R0.1 Retheme in place on the integration branch — no v1/v2 feature flag

The new values replace the old ones in `app_theme.dart` / `app_tokens.dart` directly. Rejected:
a `designV2` flag or a parallel `AppThemeV2`. The app is not released yet (no users to protect
from a half-migrated look), a flag would double every restyled widget for months, and because
all screens read colours through `ColorScheme` / `context.metricColors`, an in-place token change
already gives unmigrated screens ~70% of the new look. Work happens on `feature/mobile-redesign`;
see §8 for how it reaches `main`.

### D-R0.2 Semantic palette as a `ThemeExtension`, mapped onto `ColorScheme` for Material widgets

The design has tokens Material 3 has no slot for (three text tiers, a translucent `float`
surface, the header scrim). They go into a new `AppPalette` ThemeExtension (read via
`context.palette`), and the overlapping ones are *also* mapped into `ColorScheme` so stock
Material widgets pick them up. Rejected: stuffing everything into `ColorScheme` slots with
misleading names (e.g. `outline` as text-3) — that is how "fehérje = kijelölt" happened.

| Design token | Dark | Light | `AppPalette` field | `ColorScheme` slot |
|---|---|---|---|---|
| bg | `#12130E` | `#F4F2E9` | `bg` | `surface`, scaffold bg; `surfaceContainerLowest` in dark (light keeps it white, the M3 light convention existing call sites rely on) |
| surface-1 · card | `#1A1C15` | `#FFFFFF` | `card` | `surfaceContainerLow` |
| surface-2 · nested | `#22251C` | `#F0EEE3` | `nested` | `surfaceContainer` |
| surface-3 · chip, input, track | `#2C2F24` | `#E6E4D6` | `control` | `surfaceContainerHigh` |
| *(derived)* surface-4 | `#36392D` | `#DCDAC9` | `raised` | `surfaceContainerHighest` — one step past `control` so the ladder stays monotonic |
| float · nav, header | `#282C20` @ 82 % + blur 24 | bg @ 86 % + blur | `float` | — (translucent; no Material slot) |
| header scrim | bg @ 88 % + blur | bg @ 88 % + blur | `scrim` | — |
| text | `#F2F1E6` (16.8:1) | `#1C1D16` (15.9:1) | `text` | `onSurface` |
| text-2 | `#B6B5A5` (9.1:1) | `#56574B` (6.9:1) | `text2` | `onSurfaceVariant` |
| text-3 · footnote | `#8F8F80` (5.6:1) | `#6B6C5F` (4.9:1) | `text3` | — |
| primary (controls only) | `#B5C47C` on `#1A1F0A` (10.2:1) | `#4E6530` on `#FFFFFF` (6.8:1) | — | `primary` / `onPrimary` |
| primary tint (avatar, selected chip) | primary @ 16 %, text `#D6E2A6` | primary @ 12 %, text primary | `primaryTint` | `primaryContainer` / `onPrimaryContainer` |
| clay (trainer role) | existing secondary `#C49A6C` | existing secondary `#7E613C` | `role` | `secondary` (unchanged) |

Outline / divider values are not in the canvas; derived: `hairline` = text @ 7 % (dark, the canvas's
`rgba(242,241,230,0.07)`) / `#E6E4D6` (light); `outline` (component boundaries) `#45483B` dark,
`#CDCBBC` light (unchanged). The canvas's printed contrast ratios run 2–4 % above what the WCAG
formula gives for the same hexes; every text tier is still AA on bg, card and nested
(`test/core/theme/contrast_test.dart`).

### D-R0.3 Metric colours get new, equal-lightness values; protein is no longer the brand olive

`AppMetricColors` keeps its shape and gains three semantic roles. Rejected: keeping protein =
primary — the design explicitly separates them so "selected" and "protein" stop blending.

| Metric | Dark · canvas, `oklch(0.76 0.11 h)` | Light · canvas hue + chroma at oklch L 0.50 | Light · canvas hex (not used) |
|---|---|---|---|
| calories | `#EC9A66` | `#9D4602` | `#B35A22` |
| protein | `#93C98C` | `#34742F` | `#3F7F3A` |
| carbs | `#E2BE62` | `#7F5D00` | `#8C6A0C` |
| fat | `#A3A1DB` | `#5A57A8` | `#5A57A8` |
| water | `#74B6D6` | `#1A6C8F` | `#1F6F92` |
| steps | `#C593CC` | `#83488D` | `#8A4E94` |
| weight | `#98ADC0` | `#50667A` | `#4F6579` |
| heart | `#E07F76` | `#A73831` | `#B2433B` |

**Light deviates from the canvas hexes (decided in R0.1).** The canvas labels its light set
`oklch(0.52 …)` and promises chips at "AA ≥ 4.8:1", but its hexes actually spread over L
0.50–0.57, and calories / protein / carbs measure only 4.1–4.3:1 on their own 12 % chip tint
(below AA) and 4.25–4.48:1 as text on bg. Moving all eight to one shared L = 0.50 (same hue and
chroma) keeps the "one family" rule and the canvas's own promise: worst chip 4.82:1, every colour
≥ 5:1 on bg. Rejected: darkening only the three failing colours (breaks equal lightness), and a
lighter chip tint (the chip would stop reading as a chip).

New semantic roles (aliases, so a later palette change moves them together):
`improvement` = protein (the ↑ "better than last time" mark), `record` = carbs (🏆 PR),
`decrease` = weight (a signed "−" change chip), `increase` = calories (a signed "+" chip).
`positive` / `negative` stay for goal states (reached / over budget) and take the protein /
calories values. The roles are getters on `AppMetricColors`, not fields. **In light theme every metric colour is used for text, fills, rings and bars alike**
— there is no separate "fill" variant (the canvas: "a sávok és gyűrűk is ezt használják").

### D-R0.4 Tinted chips follow one rule per theme — this closes the deferred AA issue

Dark: background = metric @ 16 %, text = metric @ 100 % (AA ≥ 6:1). Light: background =
metric @ 12 %, text = the light (dark-toned) metric colour (AA ≥ 4.8:1). One `TintedChip`
widget encodes this; no call site picks alphas by hand. This is the design call the
"tinted-chip contrast" backlog item was waiting for.

### D-R0.5 Radius scale collapses to four steps + pill, with deprecated aliases during migration

New: `AppRadius.tag = 8` (tag, set row), `control = 14` (input, button, icon holder),
`card = 22`, `hero = 30` (hero card, sheet, nav), `pill`. Nested elements use
`parent − inner padding`. The old names stay as legacy aliases pointing at the nearest
new step (`sm→8`, `md→14`, `input→14`, `card→22`, `lg→22`, `nav→30`) so R0 doesn't have to
touch 140 call sites — marked with a "Legacy — use X" doc comment, **not** `@Deprecated`,
because CI's `flutter analyze` treats infos as fatal and the deprecation infos would keep CI
red until R7; the R7.1 audit script counts them instead; each iteration moves its files to the new names, R7 deletes the aliases.
Rejected: a big-bang rename in R0 (an unreviewable diff across every feature).

### D-R0.6 Spacing gains 20 / 40 / 56; the screen side margin becomes 20

`AppSpacing` adds `s20` (screen side margin), `s40` (above a hero), `s56` (bottom of screen,
above the nav). Documented uses: 4 icon↔label · 8 chip gap, tight group · 12 list-row inner ·
16 card padding · 20 screen margin · 24 between cards · 32 between sections · 40 above hero ·
56 screen bottom. Today most screens use 16 as side margin — each iteration changes its own.

### D-R0.7 Type scale mapped onto Material 3 roles; odd hero sizes come from one helper

| Design role | Spec | M3 slot | Typical use |
|---|---|---|---|
| display-xl | 72/68 · 800 · −3 % | `displayLarge` | weight log sheet value |
| display | 48/48 · 800 · −2.5 % | `displayMedium` | weight hero (64 via helper), rest timer |
| headline | 30/36 · 800 · −2 % | `headlineMedium` | large page title, greeting |
| title | 20/26 · 700 · −1 % | `titleLarge` | card titles, sheet titles, collapsed header |
| title-s | 16/22 · 700 | `titleMedium` | list-row title |
| body | 15/22 · 500 | `bodyMedium` (the default `Text` style) | body copy |
| body-s | 13/18 · 500 | `bodySmall` | metadata, footnotes |
| label | 12/16 · 700 (· +8 % · CAPS via `AppType.sectionLabel`) | `labelSmall` | small labels; caps section labels use the helper |
| (derived) | 14/20 · 700 | `labelLarge` | buttons, nav pill label |
| (derived) | 13/16 · 600 | `labelMedium` | chips, tabs |
| (derived) | 16/22 · 600 | `bodyLarge` | Material list-tile title, input text |
| (derived) | 36/40, 34/40, 24/30 · 800 | `displaySmall`, `headlineLarge`, `headlineSmall` | keep today's sizes for existing users (login wordmark, weight hero, sheet titles) |
| (derived) | 14/20 · 700 | `titleSmall` | — |

Every slot is defined, so none falls back to Material's 400-weight defaults. The +8 % caps
tracking is **not** baked into `labelSmall`: ~50 of its ~56 users are ordinary small labels
that the tracking would spread out.

Numbers not on the scale (34 ring centre, 40 pace, 44 rest timer, 52 distance, 60 plan kcal, 64
current weight, 104 moving time) come from `AppType.number(size)` — same family, 800, tracking
−3 %, tabular. Rejected: adding custom `TextTheme` slots (M3 has none spare) or ad-hoc
`TextStyle(fontSize: …)` (that is the 396-literal debt we are paying off).

**Rules the helpers enforce:** every number uses `FontFeature.tabularFigures()`; the unit sits
next to the number at ~42 % size in `text2` (`MetricValue` widget); ALL CAPS only for 12 px
section labels, never inside cards ("Calories / CALORIES" mix goes away).

### D-R0.8 Dynamic type: body grows to 130 %, display numbers do not

Hero/display numbers render with `textScaler.clamp(maxScaleFactor: 1.0)`; everything else
scales freely and layouts are verified at 1.3. No global clamp in `MaterialApp.builder`
(rejected: it would cap accessibility for text that can grow). Row heights are content-driven —
no fixed heights on anything containing text.

### D-R0.9 Charts stay custom-painted; one bar chart and one line chart cover every screen

The design prompt forbids a chart library, and the existing painters already work. Two
components cover every chart in the canvases:
- `LifeyBarChart` (new, `shared/widgets/charts/bar_chart.dart`): Y axis with 3 labels
  (0 / mid / max, compact "2.4k"), dashed goal line, highlighted "today" bar, optional weekly
  bucketing, average label in the header. **The average excludes today's partial day.**
- `TimeSeriesChart` (upgraded): Y axis with 3 labels, faint grid, value line + gradient fill,
  optional dotted 7-day average, highlighted last point, legend row, X labels at 3 dates.
`pace_bar_chart`, `elevation_profile_chart`, `weight_sparkline` and `hr_zone_panel` are restyled
to the same axis/label tokens, not merged.

### D-R0.10 Icons stay on Flutter's built-in Material Icons, standardised on `_rounded`

The canvases use Material Symbols Rounded. Rejected: adding `material_symbols_icons` (a large
icon-font dependency for a visually near-identical glyph set; "no new framework without
justification"). Rule: inactive = `Icons.x_outlined` / `Icons.x_rounded`, active/filled =
`Icons.x_rounded` (filled). Symbol→Icon mapping for names that differ: `trophy` →
`emoji_events_rounded`, `space_dashboard` → `space_dashboard_rounded`, `monitor_weight` →
`monitor_weight_rounded`, `barcode_scanner` → `qr_code_scanner_rounded`, `south`/`north` →
`south_rounded`/`north_rounded`. The mapping table lives in the gallery (R0.6).

### D-R0.11 Verification = debug design gallery + widget tests, no golden files

CI runs on ubuntu and development on Windows; golden images would differ by platform font
rendering and fail constantly. Instead: (a) a debug-only **design gallery** route renders every
component in dark/light × EN/HU × text scale 1.0/1.3, for side-by-side comparison with the
canvas; (b) widget tests assert structure, semantics and *no overflow* at 1.3 + HU; (c) pure
functions (formatting, contrast, averages, bucketing) get unit tests.

### D-R0.12 Page transitions are built in-house on `go_router`, no `animations` package

Only two transitions are needed: fade-through between bottom-nav tabs, shared-axis X for pushes
within a tab (300 ms), both in `core/router/transitions.dart`. Rejected: `package:animations` —
small and official, but a dependency for two transitions is not justified.

*As built (R0.5):* shared-axis X is a `PageTransitionsBuilder` installed through the themes'
`pageTransitionsTheme` — not per-route `CustomTransitionPage`s — so it also covers the ~30
screens pushed with a plain `MaterialPageRoute`. It applies on Android (and desktop); **iOS keeps
the Cupertino transition**, because replacing it would remove the edge swipe-back gesture.
Fade-through is a `navigatorContainerBuilder` for both `StatefulShellRoute`s (they were
`.indexedStack`); every branch stays mounted as before.

### D-R0.13 Animations are implicit widgets with a reduced-motion switch

`AppMotion` exposes durations and the three curves (standard `Cubic(0.2,0,0,1)`, enter
`Cubic(0.05,0.7,0.1,1)`, exit `Cubic(0.3,0,0.8,0.15)`) and a
`AppMotion.of(context).duration(d)` that returns `Duration.zero` when
`MediaQuery.disableAnimationsOf(context)` is true. Animated components are
`TweenAnimationBuilder`-based and animate **from the previous value**, never from 0 on rebuild.

| Motion | Duration | Spec |
|---|---|---|
| Tap | 100 ms | cards scale to 0.98, buttons one surface step lighter; no ripple on big cards |
| Number count-up | 600 ms | from old to new value, tabular so width is stable |
| Ring / bar fill | 900 ms | enter curve, 60 ms stagger between macros; after a new entry only the delta animates |
| Page change | 300 ms | shared-axis X within a tab, fade-through between nav tabs |
| Bottom sheet | 350 ms | slide up, backdrop to 40 %, spring close on drag |
| Set done | 250 ms | row tint to green, check draws in, light haptic; PR trophy pops once |
| Rest countdown | continuous | bar drains linearly; last 5 s number turns calorie-orange and pulses |
| Celebration | 1.2 s | trophy, then rows staggered in; runs once, never loops |

### D-R0.14 New shared components live in `lib/shared/widgets/ds/`

One folder, one import barrel (`ds.dart`), so "is this screen on the new system?" is a grep.
Existing shared widgets (`empty_view`, `error_view`, `pill_tab_bar`, …) are restyled in place
rather than forked (same rule as doc 20).

### D-R0.15 Pure redesign: no feature that needs new persisted data or new endpoints

Where a canvas shows something the data model can't produce, the element is either derived
client-side (listed per iteration under "Data") or left out and recorded in §6 Non-goals. The
only exception is R6.2 (two read-only aggregate fields for the trainer client list) — a
separate, optional backend step whose absence the UI tolerates.

---

## 4. Shared rules for every step

- Follow `mobile/CLAUDE.md`: four-layer feature split, hand-written Riverpod providers, never
  edit `*.g.dart`.
- **No hard-coded strings** — every new or changed text goes through the `localization` skill
  (`app_en.arb` + `app_hu.arb`, ICU plurals). No hard-coded `Color(0x…)`, `fontSize:` or
  `BorderRadius.circular(` in files a step touches; use tokens.
- A step that touches a file also moves that file's `AppRadius` usages to the new names.
- Per-iteration checklist at the end of every UI step:
  `flutter analyze` clean · `flutter test` green (the 3 known Windows chat-attachment failures
  excepted) · run on an emulator in **dark EN, light EN, dark HU**, and once at **text scale
  1.3** · compare with the canvas section named in the step · no content under the status bar
  · no overflow stripes · last list item fully visible above the nav.
- Keep behaviour identical unless the step says otherwise; relocations (logout, copy, delete)
  are called out explicitly.
- **Every step ends with a commit and a push** to `feature/mobile-redesign` (one commit per
  step, message `Mobile: <what> (redesign R<n>.<m>)`), after `flutter analyze` and `flutter test`
  pass. The step heading gets a ✅ in this doc in the same commit.

### 4.1 Iteration-end emulator review (mandatory, every R)

After the last step of an iteration, a thorough check on an **Android emulator** that everything
was built the way the canvas describes. Tests and the gallery catch structure; this catches
what only a running app shows (real data, scroll behaviour, keyboard, animations, navigation).

**Setup (once):** an AVD close to the design's 411 × 923 dp phone (Pixel 7-class, API 34+), and
for R6 a 1280 × 800 tablet AVD. No emulator exists on the dev machine yet (2026-09-24), so the
first review (end of R0) starts by creating them (`flutter emulators --create`, or Android
Studio's Device Manager). Backend runs locally (`RUNNING.md` §0); a test account is seeded with
data resembling the canvas (≈ 621 / 2 360 kcal day, a week of meals, a strength session with a
PR, a run with HR zones, 30 days of weights) so screens can be compared value by value.

**Procedure:**
1. `flutter run` on the emulator; walk every screen the iteration touched, in this matrix:
   **dark EN · light EN · dark HU · light HU**, plus one pass at **text scale 1.3** and one with
   **Remove animations** (reduced motion) on.
2. For every canvas frame of the iteration (e.g. R1: 1.1 top + scrolled, 1.2 light top +
   scrolled, 1.3 HU), take an emulator screenshot (`adb exec-out screencap -p`) of the same
   state and put it next to the canvas frame (canvas opened in a browser from `docs/redesign/`).
3. Check against the canvas, item by item: layout order, spacing and radii, colours (metric vs
   brand olive), type sizes of hero numbers and titles, icons, chip tints, number formatting,
   HU strings (no ellipsis), the "MI VÁLTOZOTT ÉS MIÉRT" notes of every frame (each note is a
   requirement), motion (count-up, ring fill, sheet, tab transitions), nothing under the status
   bar, last row visible above the nav, ≥ 48 dp touch targets.
4. Exercise the flows, not just the screens: the iteration's demo flow from the §0 table
   (e.g. R2 = log a meal end to end), including offline for AI entry points.
5. Write the result into **§12 Review log** of this doc: date, device, what matches, every
   deviation (intended — with the decision id — or a bug). Bugs are fixed as extra steps
   `R<n>.fix-<k>` (each committed and pushed) and the affected part re-checked.
6. Send the side-by-side screenshots to the user. Screenshots are **not committed** (repo size);
   the review log is the durable record.

The iteration is done when the review log has no open bug for it.

---

## R0 — Foundation (general) · `Lifey Design System.dc.html`

**Goal:** everything app-wide that the screen iterations build on. After R0, every screen
already renders with the new palette, type and nav, and every component the canvases use exists
in the gallery.

**Design principles to hold every later step to** (canvas §01–04):
1. *One hero number per screen* — remaining calories, current weight, moving time; everything
   else is subordinate.
2. *Colour means data* — metric colours only on their metric; brand olive only on controls
   (buttons, active tab, selection).
3. *Fewer boxes, more groups* — related data in one card separated by row dividers; **never a
   card inside a card**.
4. *Hungarian is the yardstick* — every row may wrap to two lines; labels sized for the longest
   HU string; no ellipsis on labels.

### R0.1 — Mobile UI: new palette in `ColorScheme` + `AppPalette` extension ✅

- Files: `core/theme/app_theme.dart`, `core/theme/app_tokens.dart` (new `AppPalette` +
  `context.palette`), `test/core/theme/contrast_test.dart` (new).
- Replace `_DarkColors` / `_LightColors` values and the `ColorScheme` mapping per D-R0.2. Set
  `splashColor`/`highlightColor` from the new primary.
- Replace `AppMetricColors.dark/light` values and add `improvement`, `record`, `decrease`,
  `increase` per D-R0.3.
- Add a tiny WCAG relative-luminance helper in the test and assert every pair in the D-R0.2 table
  and every light metric colour on `card` and `bg` ≥ 4.5:1, every dark metric colour on its
  16 % tint over `card` ≥ 4.5:1.
- Grep for `metricColors.protein` used as a selection colour and `colorScheme.primary` used to
  mean protein; list findings in the PR (fixed in the owning iteration, not here).
- **Verify:** contrast test green; app runs, every tab shows the new bg/cards in both themes.

### R0.2 — Mobile UI: spacing, radius, elevation and motion tokens ✅

- Files: `core/theme/app_tokens.dart`.
- `AppSpacing` + `s20`, `s40`, `s56` (D-R0.6). `AppRadius` new names + deprecated aliases
  (D-R0.5). `AppElevation` ThemeExtension (`context.elevation`), values taken from the
  canvases' actual `box-shadow`s: `border` (e0 hairline: text @ 7 % dark, `rgba(28,29,22,.08)`
  light); top light edges `cardEdge` / `heroEdge` / `floatEdge` (white @ 3.5 / 5 / 7 % dark,
  none light); `e1` card (none dark; light `0 1 2 rgba(40,38,20,.05)` + `0 10 24 −16 .22`); `e2`
  hero/FAB (dark `0 10 24 −12 black@.8`; light = e1); `e3` nav (dark `0 20 40 −12 black@.9`;
  light `0 16 32 −12 rgba(40,38,20,.3)`); `sheet` (e3 cast upwards). Blur sigmas: `floatBlur`
  24 (nav, floating bars), `scrimBlur` 20 (status-bar scrim). `AppSpacing.screen` = 20.
  `AppRadius.nested(parent, inset)` for concentric corners.
- `AppMotion` per D-R0.13 (keep `AppCurve.collapse` for the nav until R0.10 replaces it).
- The "top light edge" needs a painter: Flutter can't draw a non-uniform `Border` with a radius.
  Implement it once in `ds/card_edge_painter.dart` (strokes the top arc of the RRect only).
- **Verify:** `test/core/theme/tokens_test.dart` — `AppMotion.of` is zero under
  `disableAnimations`, legacy aliases map as above, the edge band follows the corner radius;
  `flutter analyze` clean.

### R0.3 — Mobile UI: type scale + number helpers ✅

- Files: `core/theme/app_theme.dart` (`_textTheme`), `core/theme/app_type.dart` (new:
  `AppType.number(size)`, `AppType.unit(size)`, `AppType.sectionLabel()`,
  `AppType.noScale(context)`, `AppType.tabular`), `shared/widgets/ds/metric_value.dart`.
- Remap the `TextTheme` per D-R0.7 (line heights as `height:`, tracking as `letterSpacing`).
- `MetricValue(value, unit, size)` — RichText, number tabular, unit at 0.42× in `text2`,
  hero clamp per D-R0.8, `Semantics(label: "1739 kilocalories left")`.
- Grep every `textTheme.displayLarge/headlineMedium/bodyLarge` usage — slot meanings shift
  (e.g. `displayLarge` goes 34 → 72); fix call sites that would now render absurdly (most
  should become `AppType.number(34)`). *Done:* `displayLarge`/`displayMedium` had no users;
  the only risky one was the macros-tab kcal total in a no-wrap row (`headlineMedium` 26 → 30),
  pinned to `AppType.number(26)` until R2.8. `bodyLarge` 14 → 16 moves list titles toward the
  design's 16 px row title; `bodySmall` 12/400 → 13/500 everywhere — watch for tight rows in
  the R0 emulator review.
- **Verify:** app-wide click-through of all 5 tabs: no giant or clipped text; unit test that
  `AppType.number` has `tnum`.

### R0.4 — Mobile UI: one number/date/plural formatting layer ✅

- Files: `core/format/lifey_format.dart` (new), `test/core/format/lifey_format_test.dart`,
  ARB audit via the `localization` skill.
- Functions: `integer(n)` (locale grouping — `intl` gives "1,739" in EN and "1 739" in HU, both
  acceptable per the canvas), `kcal(double)` (rounded, never a decimal), `grams`, `weightKg`
  (1 decimal), `distanceKm` (2 decimals), `litres` (2 decimals), `signedDelta` (U+2212 minus,
  "+" for gains, "0" without sign), `compactAxis` ("2.4k"), `durationHm` ("23 h 40"),
  `dayLabel(context, date)` (locale date: "Csütörtök, szeptember 24." / "Thursday, 24 Sep").
- Rule in the doc comment: **round only at display time; never sum rounded values.**
- Plural audit: grep ARB values for `{count}` without `plural` (e.g. "exercises", "sets",
  "workouts", "sessions") and convert to ICU plurals — keys unchanged, so call sites don't move.
- Call sites are **not** migrated here; each iteration migrates its own.
- **Verify:** unit tests for EN + HU of every function incl. negatives, 0, 999.95, 17518.6.

*As built:* `LifeyFormat(locale)` / `LifeyFormat.of(context)` in `core/format/lifey_format.dart`
with `integer`, `kcal`, `grams`, `weight`, `distance`, `litres`, `decimal`, `percent`,
`signedDelta`, `compactAxis`, `dayLabel`, `shortDayLabel`, `time`, `weekdayNarrow`
(`test/core/format/lifey_format_test.dart`, 20 cases). Decisions made on the way:
- **Hungarian decimals use a comma** ("64,5 kg", "0,25 L") — the locale's own separator and the
  house style in the `localization` skill. The HU canvas frame (1.3) shows dots; that is read as
  a canvas oversight, not a decision. Display only — editable fields keep their own parsing.
- **Root cause of the "Thu, Sep 24" leak:** the app never sets `Intl.defaultLocale`, and most of
  the ~25 `DateFormat(...)` calls pass no locale, so they render English in Hungarian mode.
  `LifeyFormat` always passes the locale; each iteration replaces its screens' bare
  `DateFormat`s (the R7.1 audit should count `DateFormat('` without a locale argument).
- **Hungarian chart weekdays are abbreviations** (H K Sze Cs P Szo V): intl's narrow form
  repeats "Sz" for Wednesday and Saturday.
- **`durationHm` is not in `LifeyFormat`** — its unit words need translating; the existing
  `trainerDurationHoursMinutesLabel` ARB key ("{hours} h {minutes} min" / "{hours} ó {minutes}
  perc") is generalised when R3/R4 first need it.
- **Plurals fixed** (keys and signatures unchanged): `exercisesCountLabel`, `setsCountLabel`,
  `workoutExerciseCount`, `workoutSuccessSubtitle`, `recapWorkoutsCount`,
  `intervalPlanSummaryLabel`, `intervalSectionsCountChip`, `waypointsCountChip`,
  `trainerOccurrenceCountSummary`. Left alone because their count can never be 1:
  `stepGoalNotificationBody`, `chatSearchPromptBody`, `intervalSectionsShowAll`,
  `trainerTooManyOccurrencesMessage`. Three widget tests asserted the buggy "1 workouts" /
  "1 waypoints" / "1 sets" and were corrected; `test/l10n/plural_strings_test.dart` guards
  the fix.

### R0.5 — Mobile UI: motion primitives + page transitions ✅

- Files: `shared/widgets/ds/animated_number.dart`, `shared/widgets/ds/pressable.dart` (tap
  scale 0.98 / 100 ms), `core/router/transitions.dart`, `core/router/app_router.dart`.
- `AnimatedNumber` keeps the last shown value in state and animates old→new (600 ms); first
  build shows the value without animating from 0.
- Fade-through for shell tab switches, shared-axis X for pushed routes (D-R0.12).
- **Verify:** widget test — rebuild with the same value causes no animation; with
  `disableAnimations` the final value shows on the first frame.

*As built:* `AnimatedNumber` (builder API, continues from the on-screen value when retargeted
mid-animation, screen readers get only the final `semanticsLabel`), `Pressable` (scale 0.98,
`button` semantics, a long-press action only when there is a handler; tap-down shows after
Flutter's `kPressTimeout`, so a scroll starting on a card doesn't flash it),
`SharedAxisXPageTransitionsBuilder` + `lifeyPageTransitions`, `FadeThroughBranchContainer`.
Tests: `test/shared/widgets/ds/motion_widgets_test.dart`, `test/core/router/transitions_test.dart`
(17 cases, including tab state surviving a switch and the leaving tab not taking taps).

### R0.6 — Mobile UI: debug design gallery (skeleton) ✅

- Files: `shared/widgets/ds/gallery/design_gallery_screen.dart`, route `/debug/design` in
  `app_router.dart` guarded by `kDebugMode` (never reachable in release), an entry in the
  Settings screen's debug section if one exists (else long-press on the version label).
- Toolbar toggles: theme (dark/light), locale (EN/HU), text scale (1.0/1.3).
- Sections so far: colour swatches with contrast ratios, type scale, spacing, radius,
  elevation, icon mapping (D-R0.10). Every later R0 component step adds its section.
- **Verify:** open the gallery in both themes; screenshot next to the canvas's token sections.

*As built:* `shared/widgets/ds/gallery/` — `design_gallery_screen.dart` (the `gallerySections`
registry every later component step appends to), `gallery_section.dart`,
`foundation_sections.dart` (Colour with **live WCAG ratios** for every text tier, metric and chip —
anything under 4.5 shows a red ✗ — Type with each slot's live size/line/weight/tracking, Formatting,
Spacing & radius, Elevation incl. blur, Motion demos, Icon mapping). The toolbar has a fourth
toggle beyond the plan: **reduced motion**. Settings has no debug section or version label, so
the entry is a "Debug → Design gallery" row at the bottom of Settings, `kDebugMode` only (its
labels deliberately not in the ARB); the route is also exempt from the login redirect, so the
gallery opens without an account. `contrastRatio` moved to `core/theme/contrast.dart` and is
shared with the contrast test. `test/shared/widgets/ds/design_gallery_test.dart` walks all 16
toolbar combinations at 411 × 923 dp and fails on any overflow.

### R0.7 — Mobile UI: surface + text components ✅

- Files in `shared/widgets/ds/`: `lifey_card.dart` (variants `card` r22/e1/pad 16, `hero`
  r30/e2/pad 20–22, `nested` surface-2 r = parent − padding), `section_label.dart` (12/16 caps
  +8 %, optional trailing "See all" text button), `tinted_chip.dart` (D-R0.4; 26 px tall, 10 px
  horizontal padding, 12/700), `delta_chip.dart` (signed change using `decrease`/`increase`;
  `record` 🏆 and `improvement` ↑ variants), `monogram_avatar.dart` (initials from first + last
  name, fallback first letter of e-mail; primary tint bg; 44 px default).
- **Verify:** gallery section per component, dark/light/HU/1.3; widget test that the monogram
  for "Anna Kovács" is "AK" and for no name falls back to the e-mail initial.

*As built* (values checked against the canvases' markup, not only the design-system page):
- `LifeyCard` / `.hero` / `.nested`. **The hero has no drop shadow in dark** — the dashboard
  canvas draws only the 3.5 % top light edge, although the design-system page labels heroes
  "e2"; the screen canvas wins. Nested radius defaults to 14; pass
  `AppRadius.nested(parent, inset)` for concentric corners. Tappable cards go through
  `Pressable` (no ripple).
- `SectionLabel` — caps via `AppType.sectionLabel`, 4 px side inset, "See all" in primary
  13/700 with a 48 dp target; screen readers get the sentence-case label as a header.
- `TintedChip` — two sizes from the canvases: **small 26** (12/700, 10 px padding, 13 px icon —
  what the screens use) and **medium 32** (13/700 — the design-system showcase row).
- `DeltaChip.arrow` ("↓ 0.1 kg": arrow + unsigned number) and `DeltaChip.signed` ("−0.1"), colour
  by direction with an override — the weight hero's "↓ 1.4 in 30 d" is **protein green** on the
  canvas (progress toward the goal), only plain history chips use blue/orange. A change that
  rounds to zero is neutral with no arrow. Spoken as "down 0.1 kg" / "0,1 kg csökkenés" (new ARB
  keys `deltaDownSemantics`, `deltaUpSemantics`). `RecordChip` (🏆 carbs gold) and
  `ImprovementChip` (↑ protein green) fix those two meanings in one place.
- `MonogramAvatar` — font = 0.34 × size (the canvases' 44/15, 48/16, 56/19); self = olive
  tint, other people a stable metric hue from `MonogramAvatar.colorFor(name)` (the trainer and
  chat canvases give each person a different hue); optional photo with initials as fallback;
  initials never scale with dynamic type.
- Gallery: `gallery/component_sections.dart` ("Cards & labels", "Chips & avatars"); tests:
  `test/shared/widgets/ds/base_components_test.dart` (23 cases).

### R0.8 — Mobile UI: list rows, buttons, chips, inputs, dialogs (themes) ✅

- Files: `shared/widgets/ds/list_group.dart` (`ListGroup` = one card with row dividers,
  `ListRow` = 40 px icon holder r14 in metric/neutral tint + title-s + body-s meta + trailing
  value/chevron; min height 56, content-driven), `app_theme.dart` component themes:
  `FilledButton` (48 dp min, r14, labelLarge), `OutlinedButton`/tonal "Secondary",
  `TextButton`, `IconButton.filledTonal` (48 dp, r14), `ChipTheme` (pill, 36 px, check icon
  when selected, selected = primary tint + primary text), `SegmentedButtonTheme` (7 d / 30 d /
  90 d / All — pill track surface-3, selected card-surface pill), `InputDecorationTheme`
  (filled surface-3, r14, no border, 52 px, leading icon text2), `DialogTheme` (r30, surface-2),
  `SnackBarTheme` + restyle `app_snackbar.dart` (remove its 7 colour literals).
- `pill_tab_bar.dart` and `date_range_filter_bar.dart` restyled onto these themes.
- **Verify:** gallery sections; widget test that every button/chip/icon button measures ≥ 48 dp
  hit area.

*As built* — component themes live in `core/theme/app_component_themes.dart`
(`withLifeyComponents`, applied to both themes), measured from the canvases' markup. Deviations
from the text above, all following the canvases:
- **Radii follow the 4-step rule even where a canvas sample doesn't**: the button samples still
  use 16/18 and the FAB 20 → buttons 14, FAB 22 (the design-system page itself says the old
  8/16/18/20/24/28 are gone).
- **Button sizes:** theme default 48 (so ~100 existing buttons in tight rows keep fitting); the
  canvas's 56 px full-width primary CTA is `lifeyLargeButtonStyle`, applied per screen.
  `OutlinedButton` = the canvas "Secondary" (surface-2 + hairline). Pressed = lighter tone, no
  splash.
- **Selected chip = solid brand olive with a check** (canvas "CHIP · szűrő"), not the tint this
  plan assumed; unselected surface-2 + hairline; 40 tall.
- **Segmented control is a widget, `LifeySegmented`, not a `SegmentedButtonTheme`** — Material's
  `SegmentedButton` draws joined segments and can't make the canvas's floating selected pill.
  The 3 existing `SegmentedButton`s move to it in their iteration.
- **Inputs:** default is the in-sheet field (surface-3, no ring, 14, ≥ 52); the login canvas's
  on-page field (card fill + hairline, 56) is a per-screen override in R5.
- **Dialog** fill = control in dark (canvas `#2A2D22`), white in light; radius 30.
- **Hairline rings are foreground decorations** (the canvas uses inset box-shadows): a real
  `Border` adds 2 px of layout — it had squeezed the tab bar's pills to 36 px.
- `ListGroup`/`ListRow` follow the dashboard canvas: 44 px icon holder, title 15/700 (the
  screen canvas, not the 16 px title-s of the type page), value 15/800 + 12 px unit, divider
  inset 74; subtitles wrap to 2 lines. `ListIconHolder`, `ListRowValue`, `SquareIconButton`
  (48 px, surface-2).
- `AppSnackbar` rebuilt on tokens (7 colour literals gone): an inverse surface — the v2 dark
  palette in both themes — with success = `positive`, error = `heart`, info = `water` (brand
  olive is for controls); close and action are 48 dp targets.
- `PillTabBar` → canvas tab bar (card track + hairline, surface-3 selected pill with shadow,
  20 px screen margin); the v1 olive-filled active tab is gone. `date_range_filter_bar` moved
  onto tokens only (it is replaced by the week strip in R2).
- Gallery: `gallery/control_sections.dart`; tests `test/shared/widgets/ds/controls_test.dart`
  (23 cases). The gallery matrix test now prints the full overflow error.

### R0.9 — Mobile UI: progress components ✅

- Files in `shared/widgets/ds/`: `progress_ring.dart` (size, stroke, track `control`, round
  caps, animated fill 900 ms enter curve; over-goal state: full ring in `negative` +
  outer overflow arc), `metric_bar.dart` (7 px track r7, animated), `ratio_bar.dart` (stacked
  P/C/F segments with 2 px gaps), `metric_tile.dart` (icon + label, `MetricValue`, optional
  subline, optional 48 dp trailing action, optional `DeltaChip`; half-width and full-width).
- Stagger helper for "60 ms between macros".
- **Verify:** gallery with 0 %, 22 %, 100 %, 130 % states; widget test that a value above goal
  renders the over state and never a > 360° sweep.

*As built* (sizes read from the canvases):
- `AnimatedFill` drives every fill: **fills animate in from 0 on first appearance** (900 ms,
  enter curve, `AppMotion.staggered(i)` = 60 ms steps) — unlike the count-up number, which
  doesn't — and later changes animate only the difference; equal rebuilds and reduced motion
  never animate.
- `ProgressRing`: stroke = 15/160 of the size (the canvases' 144/88/30/132 rings all use that
  proportion), track surface-3, round caps from 12 o'clock; holds its own size under tight
  constraints. **Over the goal** (no canvas example): the ring completes and a second lap
  runs over it in the same colour with a soft shadow under its leading end (Apple-rings style)
  — no extra colour, so "colour means data" holds; `overColor` for screens that want it louder.
  `ringSweeps()` caps the overflow lap at one turn.
- `MetricBar` 7 px; `RatioBar` 10 px / 3 px gaps: with a `total` (the kcal goal) segment widths
  are kcal ÷ goal — so the canvas's P/C/F bar shows 5 % / 15 % / 8 % and the empty track is the
  budget left — scaled together past the goal; without `total` it is a 100 % split (macros tab).
- `MetricTile`: canvas tile (16 padding, 18 px icon + 13/600 label, value 26/800 with a **13 px
  unit** — the tile's own 0.5 ratio, not MetricValue's 0.42), optional bar, delta chip,
  subline, trailing (sparkline) and the solid metric-coloured 48 dp quick-add button floating
  over the corner. The header is a fixed 32 px so tiles side by side line up with or without
  the button; the value/unit may wrap instead of truncating.
- **Found on the way — fixed:** `AppTheme.dark/light` were getters building a new `ThemeData`
  per call; since R0.8's `resolveWith` closures two builds are never `==`, so every app-root
  rebuild made `AnimatedTheme` run a 200 ms "transition" repainting everything. The themes
  are now built once (`static final`).
- **For R1.3:** the hero's macro rows need the HU canvas rule — at 130 % "Szénhidrát" +
  "88 / 313 g" doesn't fit beside the ring, so the value wraps under the label (the gallery
  demo already does this with a `Wrap`).
- Gallery: `gallery/progress_sections.dart` (hero composition, ring states, macro and week
  rings, day budget); tests `test/shared/widgets/ds/progress_test.dart` (19 cases).

### R0.10 — Mobile UI: `LifeyHeader` (large title) + `LifeySubpageHeader` + status-bar scrim ✅

- Files: `shared/widgets/ds/lifey_header.dart` (sliver: optional overline (date) 13–14/600 text2,
  large title 30/800 −2 %, trailing 44 px round actions incl. unread dot and monogram avatar;
  collapses on scroll to a 20 px title row), `lifey_subpage_header.dart` (back button + title +
  optional subtitle/avatar + actions, same scrim), `status_bar_scrim.dart` (bg @ 88 % + blur
  pinned under the status bar on every screen).
- Coexists with `AdaptiveAppBar` — no screen migrates in this step except the gallery and
  `placeholder_screen.dart` (the smallest real user, as proof).
- **Verify:** placeholder screen: scroll a long list — nothing visible under the status bar;
  title collapses 30 → 20; TalkBack reads the title once.

*As built* — `shared/widgets/ds/lifey_header.dart`, measured from the canvases (Lifey 1 top and
scrolled, Lifey 2 "Edit meal", Lifey 5 chat):
- `LifeyHeader` — pinned sliver; expanded = 13/600 overline + 30/800 title (two lines allowed);
  collapsed = status bar + a **52 px** row with a 20/800 title; the scrim (bg @ 90 % + blur 24,
  the canvas's scrolled values) fades in with the collapse and gets the hairline when fully
  collapsed. **Extents are measured with `TextPainter`** from the actual title, width and text
  scale, so a long Hungarian title at 130 % can't overflow. Only the title is the semantic
  heading (the date overline was being read as part of it). Sets the status-bar icon brightness.
- `LifeySubpageHeader` — a `PreferredSizeWidget`, so the 14 plain-`AppBar` screens migrate with a
  one-line `appBar:` swap: 44 px round back button (auto when the route can pop), optional
  leading avatar, 20/800 title or 18/800 + 13/600 subtitle (colour settable — the chat's green
  "online"), trailing actions; always on the scrim, hairline once content scrolls under (the
  same `ScrollNotificationObserver` hook Material's AppBar uses).
- `HeaderIconButton` — 44 px round surface-2 button in a 48 dp touch box, optional unread dot
  (9 px calorie orange, 2 px ring); `StatusBarScrim` for header-less screens.
- Migrated: `placeholder_screen.dart` (currently has no callers — the proof migration). The
  pinned header can't be shown inside the gallery's own scroll view, so the gallery's
  "Headers" section opens two demo screens (`LargeTitleDemo`, `SubpageDemo`) in the preview's
  theme/locale/scale — the emulator review checks the header there.
- Tests: `test/shared/widgets/ds/header_test.dart` (13 cases incl. both demos at 100/130 %).

### R0.11 — Mobile UI: bottom nav — active tab expands into a labelled pill ✅

- Files: `shared/widgets/adaptive_bottom_nav.dart` (visuals rewritten, **public API kept** so
  `main_shell.dart` and `trainer_shell.dart` don't change), `nav_collapse_controller.dart`
  (unchanged logic), `shell_fab.dart` (e2, r14 → extended FAB "＋ Meal" style from the canvases).
- Spec: 68 px tall, r30, `float` + blur 24, e3; active tab = primary pill 48 px tall with icon +
  label (14/700), inactive = 48×48 icon in text2; on scroll-down it flattens to 56 px (no
  separate collapsed pill any more). Every tab keeps a semantics label even when its text is
  hidden. Uses `AppMotion` curves instead of `AppCurve.collapse`.
- **Verify:** widget test — semantics finds all 5 labels; HU "Áttekintés"/"Statisztika" fit at
  1.3; scroll collapses to 56 and back.

*As built:* `adaptive_bottom_nav.dart` rewritten, public API unchanged (both shells untouched
except `MainShell`'s icons and FAB). 68 px bar, radius 30, 16 px side margins, `float` + blur
24 + e3 + top light edge; active = brand-olive pill (22 px filled icon + 14/700 label, grows
open with the tab switch), others 48 × 48 outlined icons in `text2`; collapses to 56 px (the
v1 separate collapsed pill is gone); a bg gradient behind the bar fades content under it (the
canvas's 130 px fade, kept within the nav's slot). Each tab is one semantics node — label,
button, selected — and the visible label is excluded, so nothing is read twice. The active
label shrinks to fit (`FittedBox`) on a 360 px phone at 130 %.
- **The reserved slot stays 84** (68 bar + 16 gap = the v1 58 + 26), so `navSlotHeight` and all
  banner-ad / FAB placement math (`core/ads/nav_reserved_space.dart`, `trainer_fab.dart`) and
  their tests are unchanged.
- `MainShell`: destinations use the canvas icons (`space_dashboard`, … — outlined / rounded);
  the FAB drops its own radius-18 and colour overrides (the R0.8 FAB theme applies: radius 22,
  primary) and gains the canvas's olive glow; right margin 20.
- `NavCollapseController.collapse()` added (gallery demo, tests); scroll logic unchanged.
- **Caught by the tests:** `AnimatedSize` with a zero duration throws a layout assertion — with
  reduced motion on, every tab switch would have errored. The label skips `AnimatedSize` then.
- The trainer shell still passes `tertiary` as its accent — R6.1 removes that.
- Gallery "Bottom nav" section (real nav, tab switching, collapse toggle); tests
  `test/shared/widgets/adaptive_bottom_nav_test.dart` (8 cases).

### R0.12 — Mobile UI: bottom sheet + empty and error states ✅

- Files: `app_theme.dart` (`BottomSheetThemeData`: r30 top, surface-2, handle 36×4
  `#4A4E3E`-equivalent, backdrop 40 %), `shared/widgets/ds/lifey_sheet.dart`
  (`showLifeySheet` with title row + optional trailing metric text, safe-area aware),
  `empty_view.dart` (64 px icon in tint, title-s, body-s text2, primary + secondary action),
  `error_view.dart` (`cloud_off`, "AI features need a connection…"-style copy slot, Try again).
- Rewire the existing `showModalBottomSheet` helper calls only where it is a one-line change;
  others move with their iteration.
- **Verify:** gallery; open the existing Add water sheet — it already picks up the theme.

*As built* (canvas "BOTTOM SHEET", "ÜRES ÁLLAPOT", "HIBAÁLLAPOT", Lifey 4 "Log weight"):
- `BottomSheetThemeData` in `app_component_themes.dart` — surface-2, radius 30 on top, no
  elevation (depth by tone), backdrop **40 %** (the motion spec's figure; the Lifey 4 canvas
  frame shows 55 % — the written spec wins). All ~57 existing `showModalBottomSheet`s pick it
  up; none was rewired here.
- `ds/lifey_sheet.dart` — `showLifeySheet` / `LifeySheet`: its **own 36 × 4 handle** (Material's
  drag handle brings a 48 px box, taller than the canvas's 10 + 4), 20/800 title with a
  trailing value or close button, keyboard- and safe-area-aware, scrolls when tall, 350 ms
  enter/exit curves (instant under reduced motion).
- `EmptyView` rebuilt as the canvas card: 56 px tinted icon holder (brand olive by default,
  a metric colour optional), 17/700 title as a heading, 14/500 text, main + **new
  `secondaryAction`**. API compatible — the 32 call sites are unchanged.
- `ErrorView` rebuilt as the canvas card: red hairline ring, 40 px `heart`-tinted `cloud_off`
  holder, 15/700 title, friendly message, a 48 dp "Retry" text action; **new `title`/`message`
  overrides** for the design's specific copy ("AI features need a connection…"). API
  compatible — the 46 call sites are unchanged. The canvas says "Try again"; the existing
  `retryButton` string ("Retry" / "Újra") means the same and is reused.
- Gallery "Sheets & states"; tests `test/shared/widgets/ds/states_test.dart` (8 cases).

### R0.13 — Mobile UI: `LifeyBarChart` ✅

- Files: `shared/widgets/charts/bar_chart.dart`, `test/shared/widgets/charts/bar_chart_test.dart`.
- Spec per D-R0.9. Pure helpers `yAxisTicks(max)` (0 / mid / nice max) and
  `averageExcludingPartialToday(points, now)` with unit tests.
- Bars: r = 6 top corners, inactive days in metric @ 45 %, today full colour, goal line dashed
  text3; weekday letters locale-aware (HU: H K Sze Cs P Szo V).
- **Verify:** unit tests (average excludes today; ticks for max 0, 7, 2 360, 13 000);
  gallery example with the canvas's "This week" data.

*As built* — `shared/widgets/charts/chart_math.dart` + `bar_chart.dart`, measured from the
dashboard "This week" and stats "Workouts · last 30 days" canvases:
- **Axis rule, reverse-engineered from the canvases:** the top rounds up to two significant
  digits (2 360 → 2 400, 12 612 → 13 000); small integer counts get one step of headroom (a
  peak of 6 workouts → 7); the middle label is the exact half ("3.5", not rounded); the goal
  counts toward the top. `niceAxisMax`, `yAxisTicks`.
- `averageExcludingPartialToday(points, now, ignoreZero:)` — skips today, missing days, and
  (optionally) zero days — for calories a 0 means "nothing logged"; null when nothing is left.
- `LifeyBarChart`: 34 px axis (11/600 `text3`, labels centred on their lines), bars with 6/6/2/2
  corners at 45 % except the highlighted one, dashed 1.5 px goal line in the metric colour at
  70 %, hairline baseline, X labels (highlighted one 800 in `text`); `height` 96 / 150 and
  `barGap` 8 / 14 per canvas; bars grow in via `AnimatedFill`. Per-bar `semanticsLabel`, a
  summary label that keeps them (`explicitChildNodes`), and the Y-axis numbers are excluded
  from screen readers.
- `LifeyFormat.shortDate` added ("Sep 24" / "szept. 24." — the canvas axes).
- Weekly bucketing stays in R4.7 (it is stats data shaping, not chart drawing).
- Gallery "Bar chart" (both canvas charts); tests `test/shared/widgets/charts/bar_chart_test.dart`
  (14 cases).

### R0.14 — Mobile UI: `TimeSeriesChart` upgrade ✅

- Files: `shared/widgets/charts/time_series_chart.dart`.
- Add: 3-label Y axis, faint horizontal grid, gradient fill under the value line, optional
  dotted average series, emphasised last point, legend row ("Daily · 7-day average"), 3 X
  labels (start/mid/end, locale dates). Existing callers keep working with defaults off.
- **Verify:** existing chart tests green; gallery example matching canvas §4 chart.

*As built* — new options on `TimeSeriesChart`, **all off by default**, so the five existing
charts (weight, statistics, trainer trend card, cardio summary, exercise detail) look exactly
as before until their iteration opts in (existing chart tests unchanged and green):
`axisLabelBuilder` (34 px axis + hairline grid at top/middle/bottom; labels are widgets,
excluded from semantics, like `LifeyBarChart`), `yFromZero` (nice max via `niceAxisMax`),
`gradientFill` (accent 32 % → 0), `trendStyle`, `showPoints`, `highlightLast` (12 px dot with a
4 px card-colour ring), `legend` ("Daily · 7-day average", the trend entry only when a trend is
drawn). Values from the Lifey 4 weight canvas.
- **Open decision (§10 Q4):** the canvas draws the daily line as the hero with the 7-day
  average **dotted** — the reverse of docs/76 D-W3 (trend bold, raw thin). Both are
  `TrendStyle` values (`emphasized` default = D-W3, `dotted` = canvas); R4.2 picks one.
- Gallery "Line chart" (weight month with dotted average + legend; steps from zero with goal);
  tests `test/shared/widgets/charts/time_series_chart_v2_test.dart` (7 cases).

**R0 derived screens:** none — but because tokens change in place, *every* screen changes
colour in R0.1. Click through all tabs after R0.1–R0.3 and list anything unreadable in the
R0 PR; fix only true breakages (unreadable text), leave layout to its iteration.

**R0 acceptance** (plus the §4.1 emulator review logged in §12)**:** gallery shows every component of the canvas "Alapkomponensek" section in both
themes; contrast test green; the app runs on the new palette/type/nav with no screen unreadable.

**R0 emulator review focus:** R0 redesigns no screen, so the review covers the gallery (every
component against the canvas "Alapkomponensek" section, both themes, EN/HU, 1.3) and a pass over
**every** existing screen on the new palette/type/nav, listing anything unreadable or broken
(fixed as `R0.fix-<k>`; purely layout issues are left to their iteration and noted).

---

## R1 — Dashboard · `Lifey 1 Dashboard.dc.html` (1.1 dark, 1.2 light, 1.3 HU)

**Goal:** the Today screen answers "where is my day" at a glance, with one hero (remaining kcal).

**Current code:** `features/dashboard/presentation/dashboard_screen.dart` (965 lines),
`widgets/stat_card.dart`, `widgets/calorie_sparkline_card.dart`,
`widgets/sponsorship_ended_card.dart`; `features/water/presentation/widgets/water_card.dart`,
`add_water_sheet.dart`; `features/streaks/presentation/widgets/streak_chip_row.dart`,
`recap_ready_card.dart`; `features/onboarding/presentation/widgets/onboarding_banner.dart`.

**Target layout (top → bottom), screen margin 20, gap 16:**
1. `LifeyHeader`: overline = locale date ("Thursday, 24 Sep" / "Csütörtök, szeptember 24."),
   title = greeting ("Good morning, Anna"); actions = chat (44 px, calorie-orange unread dot)
   and monogram avatar (opens a menu: Profile & settings, and "Trainer view" for trainers —
   today's `trainer_view_menu.dart`). **No logout icon.**
2. Streak strip: one 44 px pill on `card` — 🔥 streak (calories colour), 💧 water streak (text3
   when 0), 🏋 workout streak (primary), then "Week in review ›" in primary → `/recap`.
3. Contextual cards (only when present): onboarding banner, sponsorship-ended card.
4. **Hero calorie card** (`LifeyCard.hero`, r30, pad 20): left = 144 px ring (stroke 15,
   calories colour) with `AnimatedNumber` "1 739" (34/800) + "kcal left", below it
   "Eaten **621** · Goal **2 360**"; right = three macro rows (label 13/600 text2, value
   "29 / 129 g", 7 px `MetricBar` in the macro colour) and, under protein only, a tinted chip
   "100 g to go". Over budget: ring switches to over state, text "212 kcal over".
5. Two half-width `MetricTile`s: Water ("0.99 / 2.6 L", 48 dp `+` opening the water sheet) and
   Steps ("6 412 of 10 000").
6. Full-width Weight `MetricTile`: "64.5 kg" + `DeltaChip` (↓ 0.1 kg in `decrease`), subline on
   its own row: "Latest entry · today" (fixes the HU "Legutóbbi bejegy…" truncation).
7. "This week" `LifeyBarChart`: header "avg 1 631 kcal", goal line, today highlighted.
8. Recap-ready card (when present).
9. "TODAY'S MEALS" section label + "See all" → `ListGroup` rows (icon holder, meal name, "Breakfast
   · 07:15", trailing kcal) + two buttons under it: "+ Meal" (tonal) and "Photo" (camera →
   AI estimate).
10. "RECENT WORKOUTS" + "See all" → `ListGroup` rows (strength: "Wed 17:30 · 34 min · 2
   exercises" + "★ Rate" chip when the rating nudge applies; cardio: "Tue 07:45 · 5.21 km · 28
   min" + kcal).
11. Bottom padding `s56` + nav height.

**Data:** everything exists (`DashboardData`, `weeklyCalories`, `RecentWorkout.needsRatingNudge`,
streaks, water, steps, weight). Step goal: see R1.4.

### R1.1 — Mobile UI: logout moves to Settings (prerequisite) ✅
- Files: `settings/presentation/settings_screen.dart`, `dashboard_screen.dart`.
- Add an "Account → Log out" row at the bottom of Settings with a confirmation dialog whose copy
  describes **today's** behaviour ("Your data on this phone is removed. Changes not yet synced
  will be lost." — R5.6 improves both behaviour and copy). Then remove the dashboard logout icon.
- **Verify:** log out from Settings; the dashboard has no logout; widget test for the dialog.

*As built:* the row is the last one in Settings › Account (heart-coloured icon + label, so it reads as
the destructive action; the debug gallery group stays below it). `LogoutDialog`
(`settings/presentation/widgets/logout_dialog.dart`) follows the "Log out · confirm" canvas frame:
48 px heart-tinted icon holder (radius 14 — the 4-step scale, the canvas draws 16), 22/800 title, 15/500
text-2 body, Cancel (secondary) + Log out (heart fill, text = heart hue at 10 % lightness ≈ the canvas
`#2A0F0C`; white in light) side by side. **Above 115 % text scale the two buttons stack** so
"Kijelentkezés" is never squeezed or truncated. Copy is EN/HU (`logOutLabel`, `logOutDialogTitle`,
`logOutDialogMessage`; `logOutTooltip` deleted with the dashboard icon) and describes today's
behaviour — no "uploaded first" promise as in the canvas, because `logout()` does not sync first (R5.6).
Tests: `test/features/settings/presentation/widgets/logout_dialog_test.dart` (EN copy, cancel / confirm /
barrier, HU at 100 / 130 % × dark / light without overflow).

### R1.2 — Mobile UI: dashboard header + streak strip ✅
- Files: `dashboard_screen.dart`, `streak_chip_row.dart`, `trainer_view_menu.dart` (entry via
  avatar menu), `lifey_format.dart` (`dayLabel`).
- Migrate the dashboard to `CustomScrollView` + `LifeyHeader`; greeting by time of day (existing
  strings if present, else new ARB keys); avatar via `MonogramAvatar`.
- **Verify:** HU date is fully Hungarian; unread dot appears with an unread message; trainers
  still reach the trainer view.

*As built:* `DashboardScreen` no longer has a `Stack` of floating bar + `ListView`: the body is a
`CustomScrollView` — pinned `LifeyHeader` (overline = `LifeyFormat.dayLabel`, title = "Good
morning, Anna" via `greeting{Morning,Afternoon,Evening}Name`, the plain greeting when the account
has no first name), then a `SliverPadding` (20 px side margin, `s56` + nav/safe-area + banner at the
bottom) around the still-old cards, which R1.3–R1.6 replace. Actions: chat `HeaderIconButton` with
the calorie-orange unread dot, and `DashboardAvatarMenu` — the 44 px `MonogramAvatar` (initials from
the name, the uploaded photo when there is one) opening **Profile & settings** and, for trainers,
**Trainer view** (`switchTrainerView`, extracted from `TrainerViewMenu`, which the trainer shell
keeps until R6). The Settings icon is gone from the dashboard header with the logout icon (R1.1);
the avatar menu is now the only way to Settings from Today. The "Today" title and the separate
`_DayGreeting` are gone (the title *is* the greeting). Pull-to-refresh starts below the pinned header
(`edgeOffset`).
`StreakChipRow` is the canvas strip: one pill on the card surface (hairline ring + top edge, no
layout-adding border), one **icon + count per streak** — flame = calories, walk = steps, drop =
water, dumbbell = workouts, each in its metric colour (workouts: brand olive), muted text-3 icon /
text-2 count at 0 — and "Week in review ›" in primary at the end, which wraps to two lines instead of
truncating in HU at 130 %. The whole strip is the tap target (→ `/recap`). It sits directly under the
header; the recommended-workout card, onboarding banner and sponsorship card follow it. Tests:
`streak_chip_row_test.dart` (icons/order/colours, label only when tappable, HU × 4 streaks at 360 dp ×
100/130 %), `dashboard_avatar_menu_test.dart` (monogram, fallback, 48 dp target, client vs trainer
items, HU label).

### R1.3 — Mobile UI: hero calorie card ✅
- Files: new `dashboard/presentation/widgets/calorie_hero_card.dart`, remove the calorie/macro
  `StatCard` usages from `dashboard_screen.dart`.
- Protein "to go" chip uses `TintedChip` (protein); count-up + ring/bars animate from previous
  values; only the delta animates after logging a meal.
- **Verify:** widget tests — remaining vs over-budget states; HU "Szénhidrát 88 / 313 g" fits at
  1.3 (value wraps under the label instead of truncating).

*As built:* `CalorieHeroCard` (`dashboard/presentation/widgets/calorie_hero_card.dart`) on
`LifeyCard.hero`: a 144 px `ProgressRing` (calories) whose centre is an `AnimatedNumber` →
`MetricValue` 34, the "Eaten **621** · Goal **2 360**" line under it (one ARB sentence with real
placeholders, split at render time so the two numbers can be bold — `dashboardHeroEatenGoal`), and
three macro rows to the right (`Wrap` label ↔ `29 / 129 g`, `MetricBar` in the macro colour,
`AppMotion.staggered(i)` between the bars) with the protein `TintedChip` ("100 g to go" / "még 100 g").
The macro row's value drops under the label instead of truncating (verified at 360 dp × 130 % in HU).
Whole card taps to `/nutrition` (the old calorie card did). Extras beyond the canvas, decided here:
- **Over budget:** the ring closes and runs its second lap (R0.9), the number becomes the overage and
  the caption "kcal over" takes the `negative` colour; on exactly the goal it is "0 kcal left".
- **No calorie goal** (a fresh account): empty ring, the number is what was eaten, caption "kcal
  eaten", no "Eaten · Goal" line. A macro without a goal shows just its value, no bar, no chip.
- Screen readers get one sentence ("1,739 kilocalories left" / "… over the goal" / "… eaten"), not the
  counting digits.
Removed with the old cards: `proteinMoreBadge` (`kcalLeftBadge` / `kcalOverBadge` stay — the meal
editor still uses them until R2). Tests: `calorie_hero_card_test.dart` (canvas numbers in EN and HU,
over / exactly-on-goal, no goals, semantics, tap, HU × 360 / 411 dp × 100 / 130 % × dark / light with no
ellipsis).

### R1.4 — Mobile UI: water / steps / weight tiles + effective step goal ✅
- Files: `water_card.dart` → restyled as `MetricTile` (or replaced; keep the file if other
  screens use it), `stat_card.dart` (delete if unused afterwards), `dashboard_screen.dart`,
  `features/settings/domain/user_settings.dart` (`effectiveDailyStepGoal` = setting ?? 10 000).
- Decision: one getter used by every consumer (tile, stats goal line, step-goal notification) so
  the displayed goal and the notified goal can't disagree — call out in the PR that users with
  no step goal now get 10 000 everywhere.
- **Verify:** "6 412 of 10 000" with no goal set; `+` on water opens the restyled sheet.

*As built:* `DashboardTiles` (`dashboard/presentation/widgets/dashboard_tiles.dart`): water + steps in an
`IntrinsicHeight` row of `MetricTile`s, weight full width under them. **Water** — "0.99 / 2.6 L" (value
`litres`, unit `dashboardWaterOfGoal`), bar, the 48 dp `+` (tooltip "Log water") → the add sheet; with
no water goal just "0.99 L" and no bar. **Steps** — "6,412 of 10,000" against
`UserSettings.effectiveDailyStepGoal`; the tile appears only with step data (no health integration → the
water tile takes the full width, as the old card layout did). **Weight** — value, `DeltaChip.arrow`
against the previous entry (**blue for a loss, calorie orange for a gain, never green** — the old
green/red badge judged a direction the tile can't know the goal for), the "Latest entry · today /
yesterday / Sep 22" line on its own row (the HU truncation fix), and a new `ds/Sparkline` (120 × 56, 2.5 px
round stroke, r 4.5 end dot — the canvas svg) over the last 10 entries, drawn from two entries up. Weight
tile taps to `/weight`. `WaterCard` deleted (its only user was the dashboard); `StatCard` stays — the
statistics screen still uses it (R4). The five ARB keys the old cards used (`waterAmountLabel`,
`waterAmountNoGoalLabel`, `todaysStepsLabel`, `latestEntryLabel`, `todaysCaloriesLabel`) are deleted.
- **Effective step goal:** `UserSettings.defaultDailyStepGoal = 10000` and one getter,
  `effectiveDailyStepGoal` (a stored 0 counts as unset). Used by the dashboard tile, the statistics goal
  line (steps now always have one) and `StepGoalNotifier` (**users with no step goal now get the
  "goal reached" notification at 10 000 steps**). The native home-screen widget snapshot keeps the explicit
  goal (`stepGoal` stays null when unset — its test pins that, and the Kotlin/Swift side can't be checked
  here); align it when the widgets are next touched. Settings shows the
  default instead of "—" and pre-fills the edit sheet with it; the stored value stays null until the user
  edits it. **Streaks and the weekly recap keep the explicit `dailyStepGoal`**: a default isn't a
  commitment, and a steps streak for someone who never tracked steps would be a permanent "0" in the strip.
Tests: `dashboard_tiles_test.dart` (canvas numbers, bars, own goal, add button ≥ 48 dp, no-water-goal,
no-step-data layout, delta directions, relative day, sparkline data, HU × 360 / 411 dp × 100 / 130 % ×
dark / light), `sparkline_test.dart`, `effective_step_goal_test.dart`.

### R1.5 — Mobile UI: weekly calorie bar chart ✅
- Files: `calorie_sparkline_card.dart` → replaced by a `LifeyBarChart` card (rename to
  `weekly_calories_card.dart`).
- **Verify:** the average ignores today; goal line at the calorie goal; HU weekday letters.

*As built:* `WeeklyCaloriesCard` (`weekly_calories_card.dart`, replaces `calorie_sparkline_card.dart`)
on `LifeyCard` around the R0.13 `LifeyBarChart` (96 px plot, calorie colour, dashed line at the calorie
goal, today's bar in full colour, weekday letters under the bars — HU: P Szo V H K Sze Cs). Header:
"This week" 15/700 on the left, "avg **1,712** kcal" on the right with the number bold (new
`core/format/emphasis.dart` — the ARB sentence keeps real placeholders and the number is swapped in
at render time; the calorie hero now uses it too). The average goes through
`averageExcludingPartialToday(ignoreZero)`: today is left out, and a day with nothing logged is an empty
column that doesn't count (0 kcal means "not logged"); with no complete day there is no average text.
Every bar has a screen-reader label ("Thursday, 621 kcal") and the chart a summary. Removed ARB keys
`thisWeekCaloriesLabel`, `avgCaloriesBadge`. Also fixed on the way: `_buildWeeklyCalories` stepped back
with `today.subtract(Duration(days: i))`, which lands an hour off across a DST change and would have
picked the wrong calendar day — it now uses field arithmetic. Tests: `weekly_calories_card_test.dart`
(canvas week, average excludes today / empty days / no complete day, goal line, semantics, HU labels and
fit × 360 / 411 dp × 100 / 130 % × dark / light), `emphasis_test.dart`.

### R1.6 — Mobile UI: today's meals + recent workouts lists ✅
- Files: `dashboard_screen.dart` (meal group + recent workout tiles → `ListGroup`/`ListRow`),
  "+ Meal" / "Photo" buttons (Photo = existing AI estimate entry, hidden when AI is unavailable
  exactly as today).
- **Verify:** "2 exercises" / "1 exercise" plural; the rating chip opens the existing feedback
  sheet.

*As built:* two sections, each a `SectionLabel` ("TODAY'S MEALS" / "RECENT WORKOUTS" + a "See all" text
button, new `dashboardSeeAll`) over one `ListGroup`. `ListGroup` gained a `footer` (inside the card, no
divider before it) for the meals card's quick actions.
- **`TodayMealsSection`:** one row per meal type with entries. A meal the user named shows the name over
  "Breakfast · 07:15"; an unnamed one shows its type over its first three foods and the time ("Apple,
  Almonds · 08:27") — both canvas rows; several meals of a type → the type, earliest time. Trailing kcal
  total. Icon holders per type (breakfast = carbs colour, snack = protein as drawn; lunch = calories,
  dinner = fat, chosen so the four differ). Under the rows, aligned with their text: **"+ Meal"** (tinted
  brand olive; → the meal editor, like the Nutrition FAB) and **"Photo"** (surface-2; → the editor
  straight into the AI estimate). Both are 36 px pills in a 48 dp touch box. Without meals: the hint
  and the two buttons.
- **`LogMealScreen(startWithPhoto: true)`:** the Photo action reuses the editor's existing estimate flow
  (offline message, credit check, picker, estimate sheet) instead of duplicating it, and closes the screen
  again if nothing was added (cancelled / offline / failed pick) so the user is never stranded on an empty
  meal; when the credits are gone the paywall route is left on top rather than popped. **"Hidden when AI is
  unavailable" as today** = today it is never hidden — the editor's button stays and reports "offline" —
  so Photo is always shown and behaves the same way.
- **`RecentWorkoutsSection`:** strength = template name (else "Strength") over "Wed 17:30 · 34 min ·
  2 exercises" (`LifeyFormat.weekdayTime`, plural ARB), brand-olive dumbbell; cardio = the activity name
  over "Tue 07:45 · 5.21 km · 28 min", the activity's own icon and colour (running = calorie orange, as
  the canvas), duration = **moving** time. `RecentWorkout` gained `distanceMeters` / `movingSeconds`
  (from `session.cardio`). Trailing: "In progress" chip → **"★ Rate"** chip (36 px, star in the record
  colour, 48 dp box) when `needsRatingNudge` — it rates without opening the session → else the kcal when
  known. Imperial users get miles via `CardioFormatter` (its dot decimal is left as is — the HU + imperial
  combination is rare and out of R1). First three sessions, as before.
- **Dropped:** the "N strength · M cardio" breakdown line under the workouts heading (docs/cardio/56 §4) —
  the canvas has no place for it; it can come back as a stats-screen detail in R4. The muscle-group tint of
  the strength badge is gone too (one brand-olive holder, per the canvas).
Tests: `dashboard_lists_test.dart` (both canvas rows in EN and HU, named / unnamed / multiple meals, three
foods max, empty states, callbacks, touch boxes, per-type tint, plural, moving time, miles, rating chip
rates without opening, kcal fallback, in progress, HU × 360 / 411 dp × 100 / 130 % × dark / light),
`lifey_format_test.dart` (`weekdayTime`).

### R1.7 — Mobile UI: add-water sheet + water sources screen ✅
- Files: `water/presentation/widgets/add_water_sheet.dart` (canvas "Add water": 3 × 64 px
  tinted amount tiles 0.25 / 0.5 / 1.0 L, header "0.99 / 2.60 L" in water colour),
  `add_water_source_sheet.dart`, `water_sources_screen.dart` (`AppBar` → `LifeySubpageHeader`).
- **Verify:** add 0.25 L from the dashboard tile; tile count-up animates.

*As built:* `showAddWaterSheet` (in `add_water_sheet.dart`) opens the design-system `showLifeySheet` —
title "Add water" / "Víz hozzáadása" (`addWaterTitle`, which replaces `logWaterTitle`; the dashboard tile's
+ tooltip reads the same), today's total in the water colour on the right, live from
`todayWaterTotalProvider` ("0.99 / 2.60 L", two decimals in the sheet as the canvas draws it; "0.99 L"
without a goal). The body: **three 64 px tiles** 0.25 / 0.5 / 1.0 L (water at its chip tint, radius 14 —
the concentric step for a sheet of 30 with 20 padding, the canvas draws 18 — value 18/800, "L" 12/600
under it; one tap logs and closes, a spinner replaces the value while it saves), then the saved sources
(caps label + chips) and the custom amount (v2 in-sheet field, "L" suffix, an "Add" button), which the
canvas doesn't draw but which are existing features and stay. Amounts follow the locale (0,25 / 0,5 /
1,0). `showLifeySheet` gained `useRootNavigator` so the sheet still covers the bottom nav as the old
`showModalBottomSheet(useRootNavigator: true)` did. `showAddWaterSourceSheet` does the same for the
water-source form: title from the sheet, the forced `OutlineInputBorder`s removed so the v2 fields show.
`WaterSourcesScreen`: `LifeySubpageHeader`, the sources as one `ListGroup` (water-tinted holder, name,
"0.75 L"), the sync marker kept, and **Delete moved into a ⋮ menu** (Edit / Delete, delete still asks)
instead of a bare trash button beside the edit target (§1 point 5); the FAB uses the v2 theme. `amountLitersLabel`
deleted. Tests: `water_ui_test.dart` (header + tiles in EN / HU, no-goal, one-tap log, sources, custom
amount with a decimal comma and the error path, sources screen list / ⋮ menu / confirm / edit / new /
empty, HU × 100 / 130 % × dark / light).

**R1 derived screens (R1.8 ✅):** weekly recap (`streaks/presentation/weekly_recap_screen.dart`) → subpage
header + `LifeyCard`s + `MetricValue` (R1.8 if it doesn't fit in R1.2). Onboarding banner and
sponsorship card → `LifeyCard` with primary / clay accents.

*As built (R1.8):* the four contextual cards of the Today screen — onboarding banner, weekly-recap-ready,
recommended workout, sponsorship-ended — are one new component, `NoticeCard`
(`shared/widgets/ds/notice_card.dart`, gallery section "Notice cards"): a `LifeyCard` whose surface is
tinted 12 % (10 % light) with the accent, a 44 px icon holder, title 15/700 and body 13 text-2, the
call-to-action as a 48 dp text button **under** the text (not squeezed beside it, so HU at 130 % wraps),
a 48 dp close button, optional overline / trailing / whole-card tap. No border any more. Accents: brand
olive for the app's own nudges, **clay (`palette.role`) for the trainer's sponsorship notice**. The
recommended workout keeps its play icon as `trailing` and its overline in sentence case (caps are for
section labels only). The old tests tap `Icons.close_rounded` now.
The **weekly recap** screen: `LifeySubpageHeader` (it is pushed outside the shell, so no nav-collapse
listener), the week pager as two `HeaderIconButton`s around a 20/800 range that is finally locale-aware
(`LifeyFormat.shortDate`: "szept. 14. – szept. 20." — the old bare `DateFormat('MMM d')` printed English in
HU), each section a caps `SectionLabel` over a `LifeyCard`: workouts (count + minutes + km, the dot strip now
with weekday letters and `control`-coloured empty dots), nutrition (average as a 28 px `MetricValue`, then a
`LifeyBarChart` — axis and weekday letters — instead of the hand-rolled stubs; an unlogged day is an empty
column), weight (start → end as `MetricValue` with a direction-coloured `DeltaChip`, the old green/orange
"good/bad" convention dropped as on the dashboard), goals (one `ListGroup` with a row per goal). Decimals
and the km figure follow the locale. Tests: `notice_card_test.dart`, `weekly_recap_screen_test.dart`
(updated formats; HU range and weekday letters; a full week at 360 dp × 100 / 130 % × both themes).

**R1 acceptance** (plus the §4.1 emulator review logged in §12)**:** 1.1 / 1.2 / 1.3 canvases reproduced; no card-in-card; scrolled state shows the
scrim; nothing truncated in HU at 1.3.

---

## R2 — Nutrition · `Lifey 2 Nutrition.dc.html` (2.1–2.4)

**Goal:** the day budget is always visible and every entry shows what remains.

**Current code:** `nutrition/presentation/nutrition_screen.dart` (331, header + 4 tabs),
`meals_tab.dart` (413), `log_meal_screen.dart` (1 284, meal edit), `macros_tab.dart` (538),
`foods_tab.dart` (330), `widgets/add_food_sheet.dart`, `add_meal_entry_sheet.dart`,
`add_macros_sheet.dart`, `meal_estimate_sheet.dart`, `copy_day_sheet.dart`,
`duplicate_meal_dialog.dart`, `ai_credit_chip.dart`, `barcode_scanner_screen.dart`;
`recipes/presentation/recipes_tab.dart`, `create_recipe_screen.dart`,
`widgets/log_recipe_sheet.dart`, `recipes/generation/presentation/recipe_wizard_sheet.dart`,
`generated_recipe_screen.dart`.

**Target spec:**
- **Header** (2.1): large title "Nutrition", actions `content_copy` (copy a whole day → existing
  `copy_day_sheet`) and barcode scanner. Tabs Meals · Recipes · Foods · Macros as the restyled
  `pill_tab_bar`.
- **Meals (2.1):** a 7-day **week strip** (Fri…Thu; each day = weekday, date, 28 px mini
  `ProgressRing` of that day's kcal vs goal; selected day = primary tint pill). Tapping a day
  selects it; a calendar icon opens the former "All" view. Under it the **day budget card**:
  "621 / 2 360 kcal" + "1 739 left" (calories), a `RatioBar` of P/C/F share, and
  "29 / 129 g P · 88 / 313 g C · 20 / 66 g F" with each letter in its metric colour. Meals in one
  `ListGroup`: icon holder, name, "Breakfast · 07:15", trailing kcal, P/C/F mini values, the
  ingredient line wrapping to 2 lines (no "Bluebe…"). Copy per meal = long-press menu. FAB
  "+ Meal".
- **Meal edit (2.2):** subpage header with **Save in the header**; meal-type choice chips
  (✓ Breakfast / Lunch / Dinner / Snack); date-time row ("Thu, 24 Sep · 07:15 ▾"); "FOODS · 3"
  `ListGroup` rows "Rolled oats — 60 g · 8 g protein — 227 kcal — ⋮" (delete lives in ⋮); three
  equal action tiles "Add food" (primary tint), "Macros only", "From photo"; a **floating
  summary panel** pinned above the keyboard/bottom: "Meal total 383 kcal · 23 g P · 58 g C · 7 g
  F" and "Today after this meal: 1 356 kcal left".
- **Add food sheet (2.2):** search field with barcode icon inside; recent/favourite food chips;
  selected food card "Banana · per 100 g · 89 kcal · ☆"; **quantity is the hero**: large
  stepper (− 163 g +, 56 dp buttons) + quick chips (100 g, 150 g, last used amount);
  live preview "+145 kcal → 1 594 kcal left"; full-width "Add to meal".
- **Recipes (2.3):** entry card "✨ Generate a recipe — From what's in your fridge, sized to your
  goals ›" (opens `recipe_wizard_sheet`; offline / no key → R0 error state); filter chips All ·
  Favourites · High protein · < 400 kcal; **2-column grid** of photo cards (image or striped
  neutral placeholder, star, name, "520 kcal · 46 g P" in metric colours, "+ Log" button).
  FAB "+ Recipe".
- **Macros (2.4):** "Today" card: big "621 / 2 360 kcal" + 26 % and **three macro rings**
  (each its own goal share); "LAST 7 DAYS" `ListGroup`: date, kcal, a `RatioBar` per day,
  "P 104 C 188 F 58".

**Data:** all derivable. Week-strip rings need per-day kcal for 7 days (`daily_macros.dart` /
`day_meals_summary.dart`). "High protein" = protein ≥ 30 % of recipe kcal (define as a constant
in `recipes/domain`, unit-tested); "< 400 kcal" per serving. "Last used amount" chip only if
`food_usage.dart` carries it; piece-based chips ("½ pc", "1 pc") need a per-food piece weight
the model doesn't have → **non-goal** (§6).

### R2.1 — Mobile UI: nutrition header + tab bar ✅
- `nutrition_screen.dart`: `LifeyHeader`, copy-day and scanner actions; `pill_tab_bar` restyled.
- **Verify:** copy-day sheet opens from the header; tabs switch with fade-through.

*As built:* `NutritionScreen` is a `NestedScrollView`: pinned `LifeyHeader` (30/800 "Nutrition", shrinks to
the 52 px row as the active tab scrolls) with the copy-day and barcode-scanner `HeaderIconButton`s on
every tab, then the `PillTabBar` (20 px margin now) as a pinned `LifeyPinnedSliver` — the bar stays while
the title collapses. The tabs are the `TabBarView` body and no longer take a `topPadding` (the nested
scroll view starts them under the bar). **Search** (Recipes and Foods only) is a third round header
button that swaps the header for `LifeySearchHeader` (field + close button, same height as the collapsed
row); the canvas draws no search, this keeps the existing function — `searchTooltip`,
`closeSearchTooltip`. The old Today / Week / All `DateRangeFilterButton`s are gone from the header:
Meals gets its day selection in R2.2, Macros loses its range chip in R2.8 (the canvas has a fixed
"Last 7 days"); until then Meals shows today and Macros the week. Test: `nutrition_screen_test.dart`
(header, copy-day sheet, search open/close per tab).
`mealTypeStyle` moved to `nutrition/presentation/widgets/meal_type_style.dart` (dashboard + nutrition share it).

### R2.2 — Mobile UI: week strip replaces the Today / Week / All filter ✅
- New `nutrition/presentation/widgets/week_strip.dart`; `meals_tab.dart`; the calendar icon
  keeps the old All view reachable.
- **Verify:** selecting a past day shows its meals; ring fill matches that day's kcal/goal; HU
  weekday abbreviations.

*As built (R2.2 and R2.3 landed together, one commit):* the Meals tab is a `ListView` on 20 px margins:
`WeekStrip` (seven equal cells, 72 tall, weekday 11/600 over a 30 px calorie `ProgressRing` with the date
inside; the selected day is a `nested` pill with a 1.5 px primary outline and a primary weekday) → `DayBudgetCard`
(`621 / 2,360 kcal`, `TintedChip` "1,739 left" / "212 over", the P/C/F `RatioBar` — segments are `g × 4|4|9 /
calorie goal`, so the empty stretch is what is left —, and the three "29 / 129 g P" lines with the value bold in
its metric colour; macros without a goal show just grams, no calorie goal → no chip and the bar shows the
macros' share) → one `ListGroup` of `MealListRow`s (44 icon holder tinted per meal type, name / kcal,
"Breakfast · 07:15" / P C F in colour, the foods line wrapping to two lines; time order, oldest first, as in
the canvas). The selected day is `selectedMealDayProvider` (null = today; `effectiveMealDay` drops a pick that
has left the strip) and its meals come from the new `MealRepository.watchDay` / `mealsOnDayProvider` — a
day-bounded query, so a busy week can't fall off `mealControllerProvider`'s 40-meal page. "+ Meal" and the
empty state's "Add meal" log onto the selected day (`LogMealScreen.initialDate`). **The old Today / Week / All
filter is gone:** the last seven days are the strip, and the header's calendar button opens the new
`AllMealsScreen` (day-grouped, paged, free-history boundary) for anything older. Empty day: `EmptyStateCard`
(new, extracted from `EmptyView`) "No meals yet today" + Add meal + **Copy a day** — it replaces the one-tap
"Copy yesterday" button (`copyYesterdayButton` deleted; the sheet lists yesterday first). Per-meal copy moved
into the row's **long-press menu** (Edit / Duplicate / Delete in a `LifeySheet`); swipe-to-delete with its
confirmation is kept, and the duplicate dialog is rebuilt on tokens like `LogoutDialog` (its five colour
literals gone). Hungarian macro letters are new ARB keys (`macroLetterProtein/Carbs/Fat` = F / Sz / Zs; EN P / C / F).
Tests: `meal_days_test`, `week_strip_test`, `day_budget_card_test`, `meal_list_row_test`, `meals_tab_test`
(replaces `meals_tab_copy_yesterday_test`).

### R2.3 — Mobile UI: day budget card + meal list rows ✅ (built with R2.2, see its notes)
- `meals_tab.dart`, new `widgets/day_budget_card.dart`; per-meal copy → long-press menu
  (`duplicate_meal_dialog` restyled, its 5 colour literals removed).
- **Verify:** 0-meal day shows the R0 empty state ("No meals yet today" + Add meal / Copy a
  day); long ingredient lists wrap to 2 lines.

### R2.4 — Mobile UI: meal edit screen layout ✅
- `log_meal_screen.dart`: subpage header with Save, type chips, date-time row, food rows with ⋮,
  three action tiles.
- Keep the existing opt-in behaviour of the ingredient editor (hidden by default, opens on
  button press) — do not auto-expand it.
- **Verify:** edit and save an existing meal; delete a food via ⋮.

*As built (R2.4 and R2.5 landed together):* `LogMealScreen` is a `Scaffold` with `LifeySubpageHeader` (back, 20/800 "Edit meal" / "Log meal",
**Save** as a filled button) over a 20 px `ListView`: the four meal types as `ChoiceChip`s (the R0.8 chip theme: olive fill and a check on
the selected one), the date-time as a 56 px `LifeyCard` row ("Thu, 24 Sep · 07:15" + a chevron, tap = the pickers), `SectionLabel`
"FOODS · 3" over a `ListGroup` of food rows (name, "60 g · 8 g protein", "227 kcal", and a **⋮ menu — Edit / Remove**; the × is gone,
tapping the row still edits the amount), then three equal `_ActionTile`s: **Add food** (primary tint), **Macros only**, **From photo**
(the AI credit chip sits under its label; dimmed offline, tapping explains why, as before). The screen still **autosaves** every change
(unchanged behaviour — an empty meal is never persisted, the estimate / initial-food flows rely on it), so **Save = finish**: it waits for
a save in flight and closes. The floating summary is `MealSummaryPanel` in `bottomNavigationBar` (so it rides above the keyboard and the
safe area): "Meal total" with the count-up kcal, three tinted macro tiles, and "Today after this meal · 1,739 kcal left" over a `RatioBar`
whose first segment is the day's other meals and the second — paler — this meal. **Deviation:** the canvas shows 1 356 kcal left for the
383 kcal breakfast (2 360 − 621 − 383), i.e. it counts the meal twice; the plan's §9 risk 3 asks for the correct 1 739, so the meal's saved
version is excluded (`MealBudgetPreview.othersKcalOf(excludeClientId:)`, unit-tested for a new and an edited meal). The line names the day
when the meal is not on today's date, and needs a calorie goal (without one the panel is just the total). The old protein "left" bar is
dropped (the canvas has none). Removed ARB keys: `estimateFromPhotoButton`, `kcalLeftBadge`, `kcalOverBadge`. Tests:
`meal_budget_preview_test`, `log_meal_screen_layout_test`; `log_meal_screen_estimate_test` finds "From photo".

### R2.5 — Mobile UI: floating meal summary with "after this meal" preview ✅ (built with R2.4, see its notes)
- `log_meal_screen.dart`, new `widgets/meal_summary_panel.dart`. "Today after this meal" =
  day's other meals + this meal's current draft (exclude the meal's saved version to avoid
  counting it twice — see §9 risk 3).
- **Verify:** unit test for the remaining-after-meal calculation for a new and an edited meal.

### R2.6 — Mobile UI: add-food sheet with quantity hero ✅
- `widgets/add_food_sheet.dart` (and `add_meal_entry_sheet.dart` if it shares the layout);
  barcode icon inside the search field.
- **Verify:** stepper ± and chips update "+N kcal → M kcal left" live; barcode path unchanged.

*As built:* `AddMealEntrySheet` (also used by the recipe editor) is now: title "Add food" + close ×, a search field (search icon, the
**barcode scanner inside it** — a scanned code that matches a food already in the catalogue picks it, an unknown one goes through the
existing `AddFoodSheet(initialBarcode)` lookup / create), the recent foods as `ActionChip`s, and — once a food is picked — its card with a
primary outline: name, "per 100 g · 89 kcal", the **quantity hero** (44/800 number that is still a real text field, so an exact amount can be
typed, flanked by two 56 dp − / + buttons in 10 g steps, never below 1 g), quick chips (100 g, 150 g and the food's last-used amount, the one
equal to the current value selected), and a live "**+95 kcal** / 1 g protein → 1,643 kcal left" line. The remaining-after figure is now
the meal **day's** goal minus that day's saved meals minus what this entry adds (the change only when editing an entry) — not just today,
via `mealsOnDayProvider`; without a calorie goal only the "+N kcal" part shows. Full-width "Add to meal" (Save in edit mode).
The suggestion list opens only once something is typed (the recents are the empty-field shortcut; an open list would sit on top of them and
on the card) and is restyled (`_FoodOptions`, name + kcal rows). Behaviour kept: edit mode locks the food, `preselectedFood` prefills the
last-used grams once and hides the recents, hand-typed grams are never overwritten by a chip. **Not built:** the ☆ favourite on a food (a
`Food` has no favourite flag) and the piece chips "½ pc / 1 pc" (no per-food piece weight — §6 non-goal). ARB: `addFoodToMealTitle` is
now "Add food", new `addToMealButton`, `entryFoodPer100(NoKcal)`, `quantityDecrease/IncreaseTooltip`, `entryPreviewKcal/Protein`,
`entryBudgetLeft/Over` (locale-formatted numbers); removed `foodFieldLabel`, `recentFoodsLabel`, `mealEntryImpactPreview`,
`mealEntryBudgetLeft/Over`. Tests: `add_meal_entry_sheet_test` (stepper, clamp, chips, per-100 g line, plus the prefill cases) and
the initial-food / foods-tab tests use "Add to meal".

### R2.7 — Mobile UI: recipes grid, AI entry card, filter chips ✅
- `recipes_tab.dart`, `log_recipe_sheet.dart`; placeholder painter for image-less recipes.
- **Verify:** filters combine with search; offline → generate card shows the error state.

*As built:* `RecipesTab` (now stateful, it holds the filter) is a 20 px list: the **"Generate a recipe" card** (`LifeyCard` in the primary
tint, a 52 px icon holder, "From what's in your fridge, sized to your goals", the AI credit chip under it when there is a credit count,
a chevron; dimmed offline — tapping still explains, as before), the four **filter chips** All · Favourites · High protein · < 400 kcal
(single-select `ChoiceChip`s in a horizontal scroller; combined with the header search — "search hides the generate card"), and a **two-column
grid** built as rows of two `IntrinsicHeight` cards so a wrapped name never breaks the pair. `RecipeGridCard`: a 4:3 photo (the recipe photo,
or `RecipePhotoPlaceholder` — 45° neutral stripes with a quiet icon; the canvas' "recipe photo" caption is mock text and is not drawn), the
☆ / ★ on it (40 px circle on a 70 % scrim, 48 dp target, yellow when set), the name (2 lines, never cut), "520 kcal · 46 g P" per
serving in the metric colours, the trainer badge when there is one, and a full-width "+ Log". Tap edits, **long-press opens Edit / Duplicate /
Delete** — where the old duplicate button and the swipe-to-delete went (a grid has no swipe), so delete is now: long-press → Delete →
confirmation. The description line of the old card is not shown. `recipe_filter.dart`: "High protein" = protein kcal (4 × g) ≥ 30 % of the
recipe's kcal (`highProteinCalorieShare`), "< 400 kcal" = per serving (`lowCalorieServingLimit`), unit-tested incl. the canvas recipes.
`generateRecipeWithAiButton` now reads "Generate a recipe" (HU "Recept generálása"). `LogRecipeSheet` only got its date label through
`LifeyFormat` (it was an English-only `DateFormat`). The pinned tab bar of the `NestedScrollView` (R2.1) now sits on the header's scrim too:
content scrolls beneath it, and without the backing it showed through the gap between the title row and the bar (found here). Removed ARB
keys: `perServingCaloriesProteinLabel`, `totalCaloriesProteinLabel`, `logAsMealButton`, `duplicateRecipeAria`. Tests: `recipe_filter_test`,
`recipes_tab_grid_test` (chips, search combination, empty, favourite, menu, 360/411 dp × 1.3 HU), `recipes_tab_generate_test` updated.

### R2.8 — Mobile UI: macros tab rings + 7-day ratio rows ✅
- `macros_tab.dart`.
- **Verify:** rings over 100 % use the over state; ratio bars sum to 100 %.

*As built:* `MacrosTab` (now a plain `ConsumerWidget`, no range parameter) is a 20 px list: the **Today card** — "Today", the count-up
`621` 44/800 with "/ 2,360 kcal" and a `TintedChip` with the share of the goal ("26 %"), and **three 88 px `ProgressRing`s** (protein, carbs,
fat), each against its *own* goal with `29 / 129 g` in the middle and the macro's name in its colour under it (past a goal the ring runs the
second lap; without a goal the ring stays empty and shows only the grams; no calorie goal → no chip) — then `SectionLabel` "LAST 7 DAYS" over
one `LifeyCard` of day rows: date (`shortDayLabel`), "1,765 kcal", a `RatioBar` of the day's split (each macro's kcal — 4 / 4 / 9 per gram — over the
day's sum, so it **always adds up to 100 %**; unit-tested) and "P 104 · C 188 · F 58" in secondary grey as drawn. "Last 7 days" = the seven
days before today that have meals (a day without a meal has no row); older days are in "All meals". The Today / Week / All range chip is gone with
its header button (R2.1). The free-history window still cuts the list with the boundary row. Removed ARB keys: `macrosTodayKcalLeft/Over`,
`macrosTodayProteinLeft/Over`, `noMacroDataInRangeTitle`; new `macrosLastDaysTitle`. Test: `macros_tab_test` (rings vs goals, over-goal lap, no goals,
no data, week window, HU letters, 360/411 dp × 1.3 light). The canvas bars stop short of the track's end (mock proportions); ours split the whole bar.

**R2 derived screens (R2.9, may split) ✅:** `foods_tab.dart` (ListGroup rows, FAB),
`add_macros_sheet.dart`, `meal_estimate_sheet.dart`, `ai_credit_chip.dart` (TintedChip),
`barcode_scanner_screen.dart` (subpage header over camera, scrim), `create_recipe_screen.dart`,
`generated_recipe_screen.dart` ("Recipe proposal" — the canvas explicitly names it as a subpage
header user), `recipe_wizard_sheet.dart`.

*As built (R2.9, one commit):* **Foods tab** — the paged list is now one grouped card (each lazily built `_FoodRow` carries the card surface,
the first / last round the group's corners, hairlines between), a `ListIconHolder`, "89 kcal · 1 P · 23 C · 0 F (per 100 g)" with the locale
formatting and F / Sz / Zs letters, the round `+` (tinted, 48 dp target) that logs it into a new meal; swipe-to-delete with its confirmation
kept. **`AiCreditChip`** is a `TintedChip` (heart at zero credits, the clay role colour at one, secondary text colour otherwise; still
tappable → paywall only at zero). **Copy-a-day sheet** — one `ListGroup` of day rows with `LifeyFormat` day labels (was an English-only
`DateFormat`). **Barcode scanner** — `LifeySubpageHeader` on its scrim over the camera (`extendBodyBehindAppBar`). **Recipe editor
(`CreateRecipeScreen`)** — rebuilt like the meal editor: `LifeySubpageHeader` with Save (autosave stays; Save flushes a pending text edit and
closes), themed name / description fields, the servings stepper and favourite switch as `LifeyCard`s, "INGREDIENTS · n" over a `ListGroup` with
a ⋮ menu (Edit / Remove), the *Add food* / *Macros only* tiles, and the floating `MealSummaryPanel` ("Recipe total"; `label` parameter);
the dashed placeholder and the frosted floating header are gone. **Generated recipe** — subpage header ("Recipe proposal"), 20 px margins,
`SectionLabel`s, tokenised radii. `MealEstimateSheet` / `RecipeWizardSheet` got their radius literals moved to tokens; `AddMacrosSheet` and
`AddFoodSheet` needed nothing. New tests: `create_recipe_screen_test`. Not exercised on the emulator: the barcode camera, the estimate and
wizard sheets, the generated-recipe screen (their behaviour is unchanged and covered by the existing widget tests).

**R2 acceptance** (plus the §4.1 emulator review logged in §12)**:** log a meal from the week strip through the add-food sheet to Save without
leaving the new UI; 2.1–2.4 reproduced in dark and light.

---

## R3 — Workouts · `Lifey 3 Workouts.dc.html` (3.1–3.3)

**Goal:** in live screens the current task (rest, next set, moving time) gets the biggest
number; PR ↑ and 🏆 have one consistent colour language everywhere.

**Current code:** `workouts/presentation/workouts_screen.dart`, `sessions_tab.dart`,
`templates_tab.dart`, `exercises_tab.dart`, `log_session_screen.dart` (2 873 — rest banner
`_RestBanner`, `_restAdjustment` +15 s at ~l.2364), `cardio_session_screen.dart` (4 300),
`cardio_summary_screen.dart`, `widgets/exercise_session_card.dart`,
`workout_success_dialog.dart` (21 colour literals), `hr_zone_panel.dart`, `route_painter.dart`,
`elevation_profile_chart.dart`, `music_sticky_button.dart`, `music_player_sheet.dart`,
`box_score_stepper.dart`; domain `personal_record.dart`, `cardio_personal_record.dart`,
`best_effort_calculator.dart`.

**Target spec:**
- **Sessions list (3.1):** header "Workouts" with a `tune` (filter) icon; tabs Sessions ·
  Templates · Exercises; **week summary** row of three numbers (3 workouts · 96 min · 5.2 km
  this week); list grouped under "Today" / "Earlier this week" / older week headers; one row
  anatomy for strength and cardio: icon holder, title, metrics line ("58 min · 11 sets · 4 280
  kg" / "Tue 07:45 · 5.21 km · 5:19 /km · 156 bpm"), details line (exercise names), and when
  relevant a 🏆 "2 PRs" `record` chip; the Health Connect source on its own line ("Heart rate
  from Health Connect"). No trash icon per row — delete via long-press and the detail page.
  FAB "▶ Start".
- **Live strength (3.2):** subpage header "Push day · 2 of 3 exercises" with elapsed timer chip;
  **rest card as hero**: "Rest 1:28" at 44 px, draining bar, "+15 s" and "Skip", and
  "Next: Bench Press · set 2 · 47.5 kg × 8"; last 5 s → calories colour + pulse. Exercise card:
  name, "Best 50 kg × 8 · e1RM 63.3 kg", ⋯; set table header SET · PREV · KG · REPS; **52 dp
  rows**, KG/REPS as filled inputs, 40 dp check button; done row = green (`improvement`) tint,
  PREV stays faint; ↑ in `improvement`, 🏆 in `record`. "+ Add set". **Floating bottom bar in
  place of the nav:** music button + "⚑ Finish workout".
- **PR sheet (3.2 "Workout done · PRs"):** trophy, "2 new personal records", "Push day · 58 min
  · 4 280 kg volume", rows per record (trophy/↑ icon, exercise, record kind "Heaviest set" /
  "Estimated 1RM" / "Better than last time", value, `DeltaChip` "+2.5 kg"), "Continue". Plays
  the one-shot celebration.
- **Live cardio (3.3):** header "Running · GPS · Auto-pause on" + music; **moving time 104 px**;
  distance and pace at 40 px; heart-rate row "♥ 152 bpm · Zone 3 · Tempo" with a zone bar;
  a large round pause button above; "Slide to finish" track starting with a red stop knob.
- **Cardio detail (3.3):** subpage header "Running · Tue, 22 Sep · 07:45" + ⋮; route map card
  with km splits; **distance hero 52 px**; one row of metrics with uniform labels (duration,
  pace, elevation, avg HR, calories — "Calories" lowercase exception removed); "Heart rate
  zones" card: combined stacked zone bar, per zone "Z3 Tempo · 9:41 · 35 %", footnote in text3
  "Zones use your max HR of 190 bpm (220 − age). Change in Settings." (only if max HR is
  editable in Settings — else drop the last sentence).

**Data:** week summary derivable from sessions. PR count per session: derive in
`application/` from `personal_record.dart` / `cardio_personal_record.dart` (R3.2 below) — if a
session-level lookup is expensive, compute once per list build, not per row.

### R3.1 — Mobile UI: workouts header + tabs + week summary ✅
- `workouts_screen.dart`, `sessions_tab.dart`; filter moves to the header icon.
- **Verify:** filter still works; week summary matches the list for the current week (same week
  definition as streaks/recap — docs/37).

*As built:* `WorkoutsScreen` is a `NestedScrollView` like the Nutrition screen (R2.1): pinned `LifeyHeader` "Workouts" with the round
**`tune` filter button** (Sessions and Exercises tabs; a dot on it while a non-default filter is on; none on Templates), the pill tab bar
pinned under it on the header's scrim, the tabs as the body (no `topPadding` any more). The old popup menus are gone: the button opens a
`LifeySheet` — **Sessions:** "PERIOD" (Today / Week / All) and "TYPE" (All, Strength, Cardio and every activity) as choice chips that
apply at once; **Exercises:** the muscle group. `SessionsTab` now leads its list with the recommended-workout card, the **week summary**
(`WeekSummaryRow`: three equal-height tiles — 30/800 number over a wrapping label: "3 workouts this week · 96 min this week · 5.2 km this
week", miles for imperial) and the upcoming section. `computeWeekSummary` uses **the weekly recap's rules** (Monday–Sunday local week, started
sessions finished or not, finished sessions' effective minutes, DISTANCE + MACHINE cardio distance) and counts the whole week whatever the
list is filtered to. Tests: `week_summary_test`, `week_summary_row_test` (canvas numbers, singular, miles, HU, 360/411 dp × 1.3, equal
tile heights), `workouts_screen_test` (header, filter sheet, dot, no filter on Templates). The session rows themselves are still the old
cards until R3.3.

### R3.2 — Mobile data: PR count per session for the list ✅
- `workouts/application/` new provider `sessionPrCountsProvider` (map sessionId → count) built
  from the existing PR domain; unit tests.
- **Verify:** a session that set a PR reports ≥ 1; editing an older session re-computes.

*As built:* `computeSessionPrCounts` (`workouts/application/session_pr_counts.dart`) replays the whole cached history oldest to newest and
returns a `clientId → count` map (`sessionPrCountsProvider`, one recompute per change of the sessions — not per row). Strength: one record
per **(exercise, `PrType`)** pair the session set, judged against the exercise's earlier sessions *and* the earlier sets of the same session
(a bench press with a new heaviest weight and a new estimated 1RM = 2, three heavier sets in a row = still one "heaviest set"); cardio: one
per `CardioPrType` broken against the earlier cardio sessions; an unfinished session has none; the strength and cardio engines stay
separate. Editing an older session re-judges every later one because nothing is stored. Tests: `session_pr_counts_test` (11 cases incl. the
canvas "2 PRs", same-session ordering, ties, edit re-judging, input order, cardio).

### R3.3 — Mobile UI: session list rows + day grouping ✅
- `sessions_tab.dart` (row anatomy, grouping headers, PR chip, long-press delete).
- **Verify:** HU "(Egészségügyi adatok)" source line never truncates; delete still reachable.

*As built:* the Sessions list is the week summary, then **one grouped card per week bucket** under `SectionLabel` headers — "TODAY",
"EARLIER THIS WEEK", "LAST WEEK", and "Sep 7 – Sep 13" for each older Monday–Sunday week (`groupSessionsByWeek`, unit-tested incl. Monday
and the year boundary). The rows are lazily built `GroupedListItem`s (new `ds/grouped_list_item.dart`, extracted from the R2.9 foods list,
which uses it now too): the surface, rounded first/last, hairlines, optional swipe-to-delete. `SessionRow` is the one anatomy for strength
and cardio: a 44 px icon holder (dumbbell in the primary tint for strength, the activity's own icon and colour for cardio — the round
`ActivityChip` is gone from the list), the title (template name, activity name, "Strength" when a session has no template) with the
`TintedChip` trophy **"2 PRs"** in the `record` colour, a bright **metrics line** — strength "Wed 17:30 · 34 min · 7 sets · 4,280 kg" (lb
for imperial), cardio "Tue 07:45 · 5.21 km · 5:19 /km · 156 bpm" (pace for runs, km/h for rides, the duration for machine and game
sessions, the heart rate in the heart colour) — glued with no-break spaces so it wraps only at the dots, and a details line: the
exercises, or "Heart rate from Health Connect / Apple Health" (own line, so the Hungarian source never truncates). "Today" rows leave the
date out, this and last week name the weekday, older weeks the date. The trash icon per row is gone: **long-press → Open / Delete**
(confirmation kept), swipe-to-delete also kept; the route thumbnail of a GPS run stays at the row's end, an unfinished session shows
an "In progress" chip on its metrics line. The FAB is "▶ Start". Removed: `healthStatsLine`, `enrichedFromWatchTooltip` (the watch
icon), the per-row `deleteWorkoutTooltip`. Tests: `session_groups_test`, `session_row_test` (metrics, dating, PR chip singular / none,
imperial, HU, 360/411 dp × 1.3), `sessions_tab_groups_test`; the cardio / kind-filter suites were adapted to the new row.

### R3.4 — Mobile UI: live strength — rest hero card ✅
- `log_session_screen.dart` (`_RestBanner` → new `widgets/rest_hero_card.dart`).
- **Verify:** +15 s and Skip behave as today; last-5-s colour change; reduced motion = no pulse.

*As built:* `RestHeroCard` (`widgets/rest_hero_card.dart`) replaces `_RestBanner` (and its two chip / icon helpers): a `nested` card with a 1.5 px primary outline —
"REST" in the section-label style over the countdown at **44/800**, **"+15 s"** (surface-3) and **"Skip"** (primary fill) as 48 dp-tall
buttons, an 8 px **bar that drains** from full to empty, and "**Next: Bench press · set 2 · 60 kg × 8**" under it (the first row still to do,
looking from the exercise of the last logged set on; the load is the row's own or last time's, without one only the set is named; nothing left
= no line). `RestState` holds the maths and is unit-tested: **the last five seconds (inclusive) turn the number into the calorie colour and
pulse it once a second** (scale 1 ↔ 1.06; no animation time under reduced motion), reaching the target turns it into the overtime count-up
"+0:12" in the negative colour (Skip stays, +15 s goes, the bar is empty), a "+15 s" tap pushes the target out, a zero target is overtime at
once; with the rest timer off it is the plain elapsed count-up without buttons or bar. The buttons shrink (≤ 55 % of the width) rather than
push the number out at 130 % Hungarian ("Kihagyás"). The behaviour behind the buttons (`_restAdjustment`, the rescheduled notification, the
Live Activity update, skip) is the old code, moved unchanged. **The header came with it** (it decides where the card sits): the frosted
floating bar is a `LifeySubpageHeader` — the template name, the subtitle "2 of 3 exercises" (the first exercise that is not complete yet,
`workoutExerciseProgress`), and pills on the right for the elapsed time, the watch, the live heart rate and calories (`_HeaderPill`, 44 px on
surface-2). The card is pinned above the list in a `Column` instead of `Positioned` maths with a hard-coded banner height. The set table
and the bottom bar are still the old ones (R3.5 / R3.6). New ARB: `restSkipLabel`, `restNextSet`, `restNextSetLoad`, `workoutExerciseProgress`.
Tests: `rest_hero_card_test` (state boundaries, canvas card, callbacks, ≥ 48 dp buttons, colour + pulse, reduced motion, overtime, timer off, no
"Next" line, 360/411 dp × 1.3 HU).

### R3.5 — Mobile UI: live strength — exercise card + set rows ✅
- `exercise_session_card.dart`, set row widgets in `log_session_screen.dart`.
- **Verify:** 52 dp rows, 40 dp check; done tint animation 250 ms + haptic; ↑ / 🏆 colours.
  Re-check the known empty-lines bug (memory: workout-session-empty-lines-bug) is not made worse.

*As built:* `ExerciseSessionCard` is a `LifeyCard` with the exercise's **name (20/800) over "Best 50 kg × 8 · e1RM 63.3 kg"** (from the exercise's `PrBaseline`,
absent until the history loads or without a weighted set), the ⋯ menu, and the set table under an uppercase **SET · PREV. · KG · REPS** header
(labels shrink to their column rather than overflow — "SZETT" at 130 %). Rows are **52 dp** (`kSetRowHeight`): the set number, the faint PREV
(tap = the editor pre-filled with last time), **KG and REPS as filled 44 dp pills** (a plan row shows its own value, or last time's faintly
until it is logged; tap opens the editor as before) and a **40 dp check button** (`kSetCheckSize`). A done row gets the **improvement-green tint**
(250 ms, none under reduced motion) with bare bright values, the set number and the filled check in the same green; ↑ is the `improvement`
colour, ↓ the negative colour, the trophy the `record` colour (scale-in, still respecting reduced motion) — the colour language of the
list and the celebration, the hard-coded greens / reds / gold are gone. The **check** works on the existing data model: a done row is
reopened; a plan row that already has weight and reps is marked done (`onRowMarkDone`, which the screen already had); one without them is
logged with last time's set (`onRowEdit` → stamps `doneAt`, like the editor does), and with nothing to log it opens the editor.
**Relocated:** the × of a plan row is gone — long-press a row for **Duplicate / Remove** (double-tap still duplicates); "+ Add set" is a
plain primary text button (double-tap prefills, as before). The compact editor is now a `LifeySheet` "Edit set" with the themed fields (the
outlined-border override removed). Logic, `SetRow` / `ExerciseBlock`, the PR recomputation and autosave are untouched, so the known
empty-lines behaviour (memory `workout-session-empty-lines-bug`) is neither better nor worse. New ARB: `setNumberLabel`, `exerciseBestLine`,
`exerciseBestLineWithOneRm`, `setDoneLabel`. Tests: `exercise_session_card_test` (best line, 52 / 40 dp, tint, faint PREV, ↑ / dash / trophy,
all three check paths, editor Save, long-press menu, Add set, 360/411 dp × 1.3 HU light).

### R3.6 — Mobile UI: live strength — floating music + finish bar ✅
- `log_session_screen.dart`, `music_sticky_button.dart`.
- **Verify:** bar sits where the nav would be, respects safe area; finish uses the flag icon.

*As built:* `WorkoutActionBar` (`widgets/workout_action_bar.dart`) is the one floating bar of a running strength session: the **music button** (60 × 60,
`nested` surface, radius 22, blur kept; its attention dot now the theme's negative colour instead of the `Color(0xFFD66B5A)` literal) and
**"⚑ Finish workout"** (60 dp tall, radius 22, the **flag icon** — never the check of a set). It sits at the bottom edge where the nav bar would be
(root route, no shell), 16 dp above the safe area, on a short fade of the page colour so the list scrolls under it instead of showing between
the buttons. `WorkoutActionBar.reservedHeight(safeBottom)` is what the list keeps free under its last item (it replaced the hand-added
`safeBottom + 24 + 54 + 16`). Finish shows a spinner and does nothing while a save is in flight; the running-session gating, the music flow
and `_finishWorkout` are unchanged. Tests: `workout_action_bar_test` (flag icon, no check, music left of Finish, 60 dp, above the safe area with the
16 dp gap, reserved height, saving state, 360/411 dp × 1.3 HU).

### R3.7 — Mobile UI: PR celebration sheet ✅
- `workout_success_dialog.dart` → sheet per spec (removes 21 colour literals).
- **Verify:** 0 PRs → no trophy header (plain done state); multiple PR kinds listed; animation
  runs once.

*As built:* the celebration is now a **bottom sheet** (`widgets/workout_success_sheet.dart`, renamed from `workout_success_dialog.dart`;
`showWorkoutSuccessSheet`, root navigator, 88 % max height, the sheet's own handle and the surface-2 sheet theme). Top: a **96 dp trophy** in the record
colour with a 10 dp halo and the title **"2 new personal records"** (28/800; a plural key, HU singular noun), then the summary line
**"Push day · 58 min · 4,280 kg volume"** (template name · duration · Σ weight × reps of the done sets — `computeWorkoutVolume`; parts that are
unknown are left out). Below, one `ListGroup`: a **row per record** — trophy `ListIconHolder` in `mc.record`, the exercise, the kind
("Heaviest set" / "Estimated 1RM" / "Most reps at 60 kg"), the new value 20/800 ("50 kg", "12 reps") and the **gain in `mc.improvement`
("+2.5 kg")** measured against the exercise's `PrBaseline` (none when there was no earlier record) — then a row per exercise that only got
better ("Better than last time", up-arrow in `mc.improvement`, the top weight and the biggest single-set gain; up to 5 with "+N more"; exercises that
set a record are not repeated). Several sets that each beat the old record collapse to the best one per kind, so the title counts what is listed
(`recordEntryCount`; `totalPrCount`/chips are unchanged). **Without a record** the sheet is the plain done state: check-circle in the improvement
colour, "Great workout!" and the improvement count, no trophy. The **animation runs once** (`AppMotion.celebration`, 1.2 s): the trophy pops in
(30 %), then the rows fade/slide in 60 ms apart; the confetti is gone, and under reduced motion everything is in place at once. The 21 colour
literals are gone (only tokens). ARB: added `workoutDonePrTitle`, `workoutDoneVolume`, `workoutDonePrKind*`, `workoutDoneBetterThanLast`; removed
`workoutSuccessPrTitle/PrSubtitle/PrSectionLabel/ImprovementsSectionLabel`. The 12 old `computeWorkoutProgress` tests are unchanged; 10 new ones
cover the deltas, the collapse, 0 PRs, the one-shot animation, reduced motion and no overflow at 411/360 dp × 1.3 HU light.

### R3.8 — Mobile UI: live cardio screen ✅
- `cardio_session_screen.dart` (hero moving time, metrics, HR zone row, pause, slide-to-finish
  with red stop knob). Large file: touch the layout build methods only.
- **Verify:** accidental stop impossible without a full slide; pause/resume unchanged; all
  sport variants (run, bike, hike, game — docs/cardio/60, 62) still render their extra metrics.

*As built:* the live cardio screen follows canvas 3.3. **Header** (`_ActivityHeaderBar`): flat, the 44 dp activity chip, the name 20/800 over one status line
("● GPS · Auto-pause on", dot and text in the state's colour — GPS green, weak GPS amber, no GPS/indoor neutral; the two parts are separate `Text`s so
"GPS" stays findable) and, where the canvas has the music button, the auto-pause settings button (44 dp circle). **No music button:** the cardio
screen has no music-controller lifecycle (the strength screen activates/deactivates it) and wiring it in is a feature, not a restyle — left out on purpose.
**Hero:** the **moving time is always the hero** (104 px, centred, "MOVING TIME" spaced label; 82 while an interval plan plays) — the old "distance
takes over the big slot" rule (DD-5) is gone, so `_DominantMetric` lost its badge/tap. **Distance and pace** are two `LiveMetricCard`s (`widgets/cardio_live_cards.dart`:
label in sentence case over a 40 px number with its unit; "ESTIMATED" badge on distance while the signal is weak, pace blanks to "No signal"; the empty
distance card is the tappable "type it in" tile with an edit glyph); the MACHINE and GAME layouts keep their three tiles, now the same card at 28 px. **Heart-rate row**
(`LiveHeartRateCard`): "♥ 152 bpm", a "Zone 3 · Tempo" chip and a five-segment zone bar with the current zone lit; shown only while there is a reading. The zone
is the reading against **220 − age** (`domain/hr_zones.dart`; up to 60/70/80/90 % of the maximum = Z1–Z4, above Z5; age from the profile's birth date) — without
a birth date the row is just the reading. Zone colours come from the metric colours (blue, green, gold, orange, red; `hrZoneColor`, reused by R3.9).
**Controls:** one 96 dp pause disc with a 10 dp halo, centred, glyph only (label is its tooltip/semantics); the old side circles are gone — the
interval plan's "skip" circle stays on the right, the distance is edited on its card, the heart rate has its row, auto-pause settings sit in the header
(ARB `autoPauseCircleLabel`/`distanceCircleLabel` removed). **Slide to finish:** a 64 dp pill track with a **red stop knob** (heart colour, stop square), "Slide to finish »",
the fill grows in red under the knob; the logic is untouched (a tap or a short drag never finishes; ≥ 75 % or a 600 ms hold does). Paused/auto-paused
cards, the location card and the waypoint bar are unchanged apart from the 20 dp gutter. ARB: `liveHeartRateZoneChip`, `cardioStatusAutoPauseOn/Off`. Tests: the
existing cardio-screen suites were adapted to the sentence-case labels, the tooltip'd pause and the 104 px hero; new: `hr_zones_test`, `cardio_live_cards_test`
and four layout tests in `cardio_session_screen_distance_test`.

### R3.9 — Mobile UI: cardio detail + HR zone card ✅
- `cardio_summary_screen.dart`, `hr_zone_panel.dart` (5 colour literals out), `route_painter.dart`
  colours from tokens.
- **Verify:** zone percentages sum to 100 (largest-remainder rounding, unit test); footnote in
  text3.

### R3.10 — Mobile UI: list and picker screens ✅
- Templates tab, Exercises tab, `template_picker_screen`, `activity_picker_screen`, `exercise_detail_screen`, `create_template_screen`, `interval_plan_editor_screen`, `upcoming_sessions_section`
  onto the v2 components (headers, `LifeyCard`, `ListGroup`, `TintedChip`, tokens).
- **Verify:** every screen reachable from Workouts uses the subpage header; no `AdaptiveAppBar` left in `features/workouts`.

*As built:* **Pickers:** `TemplatePickerScreen` and `ActivityPickerScreen` are `LifeySubpageHeader` + `SectionLabel` + `ListGroup`s of `ListRow`s (the activity picker keeps its "grew from a sheet"
character: no back arrow, a close `HeaderIconButton`); template rows keep their muscle-group chips as `TintedChip`s. **Detail / editors:** `ExerciseDetailScreen`, `CreateTemplateScreen` and
`IntervalPlanEditorScreen` swap the floating `AdaptiveAppBar` capsule for `Scaffold.appBar: LifeySubpageHeader` (the edit action is a `HeaderIconButton`, the autosave spinner an action);
their `Stack` + hand-measured `contentTop` is gone. **Tabs:** the template and exercise cards are `LifeyCard`s with `ListIconHolder`s, the muscle-group chips `TintedChip`s, delete-swipe in the
negative colour; the trainer-scheduled "Upcoming" cards are `LifeyCard`s with a `SectionLabel`. `QuickStartSheet` and `LogCardioSheet` already used the DS sheet/list components (R3.3) and are unchanged.
**R3.fix-1 (shared, found in the emulator review of this step): the pinned header stack hid the top of a tab.** A `NestedScrollView` with pinned slivers needs the overlap absorbed — otherwise the first
rows of a tab sit *under* the collapsed title/tab bar (and a short tab opened after a scrolled long one was out of sight altogether: Templates showed an empty screen until pulled down). `LifeyHeader` got a
`bottom` slot (the pill tab bar) so title + tabs are one sliver, `SliverOverlapAbsorber` wraps it, `OverlapInsetScope` hands the handle(s) down and every tab's scroll view starts with an `OverlapInsetSliver`
(`SliverOverlapInjector`; empty when a tab is used on its own). Applied to **Workouts** (Sessions/Templates/Exercises) and — same defect — **Nutrition** (its title/search row and tab bar stay two slivers, each on its own
handle; Meals/Recipes/Foods/Macros lists became `CustomScrollView`s). Regression tests in `header_test`. Each Workouts tab also has its own `PageStorageBucket` so keyless scrollables cannot restore each other's offset.

### R3.11 — Mobile UI: sheets ✅
- `add_exercise_sheet`, `add_exercise_to_session_sheet`, `add_set_sheet`, `post_workout_feedback_sheet` + `rpe_selector`, `music_player_sheet`, `music_provider_picker_sheet`, `game_setup_sheet`, `box_score_stepper`,
  `gps_explainer_sheet`, `cardio_session_settings_sheet`, `interval_plan_picker_sheet` onto `showLifeySheet` / DS tokens.
- **Verify:** every sheet has the DS handle, surface-2 and radius 30, no colour literal, no overflow at 360 dp × 1.3 HU.

*As built:* **One handle for every sheet:** the theme's `bottomSheetTheme` now draws Material's drag handle (`showDragHandle: true`, used by 17 workout call sites) as the design system's — 36 × 4 in `text3` at 60 % — so
every sheet, `showLifeySheet` or not, opens with the same handle on the same surface-2 / radius-30 sheet. **Colour literals out:** the music sheet's error dot (`0xFFD66B5A`) and the delete-session dialog's accent are the
theme's negative colour; the cardio summary's record gold (`0xFFD8B35A` ×3, PR banner/dialog/best-effort rows) is `mc.record` — the same "🏆 always carbs-gold" as the strength screens — its manual-edit badge a `TintedChip`; the
auto-pause accent (`0xFFC49A6C`) is one `autoAccent` (calories orange) and the finish overlay scrim / selected-chip colours come from the palette. Every `BorderRadius.circular(n)` in the sheets is an `AppRadius` token
(`box_score_stepper`, `game_setup`, `interval_plan_picker`, `add_exercise_to_session`, `cardio_session_settings`, `rpe_selector`). **Overflow fixes found by the new `sheets_layout_test` (411/360 dp × 1.3, HU, dark + light):** the GPS
explainer and the post-workout feedback sheet now scroll (they were taller than a small phone at large text); the RPE anchor labels ("Very easy" / "Maximal effort") share the row instead of overflowing it by 196 dp in Hungarian;
the box-score stepper's three columns (basketball) overflowed a 360 dp phone even at 100 % — its buttons are 36 / 50.4 dp instead of 40 / 56 (still 1.4 × wider `+`), and its hint wraps. Not restyled (already on tokens, no
findings): `add_exercise_sheet`, `add_set_sheet`, the music sheets' layout, `interval_plan_picker_sheet` — they get the new handle; their inner font sizes stay (text-scale tested through their existing suites).

**R3 derived screens (R3.10–R3.11):** templates tab, exercises tab, `exercise_detail_screen`,
`create_template_screen`, `template_picker_screen` (AppBar → subpage header),
`activity_picker_screen`, `quick_start_sheet`, `log_cardio_sheet`, `interval_plan_editor_screen`,
`interval_plan_picker_sheet`, `add_exercise_sheet`, `add_exercise_to_session_sheet`,
`add_set_sheet`, `post_workout_feedback_sheet` + `rpe_selector`, `music_player_sheet`,
`music_provider_picker_sheet`, `game_setup_sheet`, `box_score_stepper`, `gps_explainer_sheet`,
`cardio_session_settings_sheet`, `upcoming_sessions_section`, `upcoming_workout_card`,
`recommended_workout_card`, `elevation_profile_chart`. Split R3.10 = list/picker screens,
R3.11 = sheets.

**R3 acceptance** (plus the §4.1 emulator review logged in §12)**:** a full strength session (sets, rest, PR, finish, celebration) and a full
cardio session (start, pause, slide to finish, detail) on the new UI in dark and light.

*As built:* **Header:** the summary uses the design system's `LifeySubpageHeader` — back, "Running" over "Tue, Sep 22 · 07:45", and a ⌚ `TintedChip` when the numbers
came from a watch (the old capsule and the identity row are gone; the canvas's ⋮ is not drawn — nothing sits behind it, every metric is edited by tapping it).
**DISTANCE family:** `CardioDetailHero` (`widgets/cardio_detail_hero.dart`) — the distance as a **52 px hero** (tap edits it, "Edited" tag when hand-entered) with the duration
beside it — then `CardioMetricStrip`: pace/speed, elevation, heart rate, calories in **one card under one label style** (sentence case — "Calories" is no longer the odd one out;
HR number in the heart colour, calories in the calories colour; four across, two by two on a narrow phone or at large text). The tiles that have no place in the strip
(highest point, backpack weight, running cadence) stay as cards under it. MACHINE and GAME keep their layouts on the same card tokens. **HR zone card** (`HrZonePanel`,
one card for every family): "Heart rate zones" + the verdict chip, a 12 dp stacked bar (3 dp gaps, pill segments; unmeasured remainder hatched), then per zone
"Z3 · Tempo · 9:41 · 35 %" — **the percentages come from `HrZoneBreakdown.percents`, the largest-remainder split that always adds to 100** (unit-tested, plus a widget test on
the rendered texts) — and the footnote in `text3`. The five zone colours are the metric colours (`hrZoneColor`, shared with the live row); the five colour literals, the per-row bars
and the easy/hard end labels (ARB removed) are gone. The canvas's footnote "max HR of 190 bpm (220 − age). Change in Settings." is **not** used: the stored zones come from the watch
against the profile's own maximum ("Never estimated" — the existing note stays, in text3), and there is no max-HR setting. `RoutePainter` colours now come from the palette
(`nested` background, calories end marker, carbs waypoints, text labels). Tests: the summary suite adapted to sentence-case labels and the subpage header; new
`hr_zone_panel_test` (rows, sum 100, footnote colour, zone colours, partial coverage, overflow at 411/360 × 1.3 HU light, hero/strip) and 5 `percents` cases in `hr_zone_breakdown_test`.

---

## R4 — Weight + Statistics · `Lifey 4 Weight Stats.dc.html` (4, 5)

**Goal:** each screen = one hero number + one readable chart; only aggregates that mean
something for the metric.

**Current code:** `weight/presentation/weight_screen.dart` (578),
`widgets/add_weight_sheet.dart`, `widgets/goal_progress_card.dart`;
`statistics/presentation/statistics_screen.dart` (586), `application/stat_chart_data.dart`,
`stat_summary_data.dart`, `stat_metric_controller.dart`, `stat_kind_filter_controller.dart`,
`stats_range_controller.dart`, `domain/stat_metric.dart` (18 metrics, 4 aggregation types),
`stat_summary.dart`; trend logic from docs/76 (smarter weight trend).

**Target spec — Weight (4):**
- Header "Weight" + ⋮ (existing menu items). Hero: overline "Current · today 07:02",
  **64.5 kg at 64 px**, two `DeltaChip`s "↓ 0.1 today" and "↓ 1.4 in 30 d".
- Goal band: "Start 67.9 · Goal 62.0 kg · 2.5 to go" with a progress track (goal from onboarding,
  editable in Settings).
- Segmented 7 d / 30 d / 90 d / All above the chart; `TimeSeriesChart` with 3 Y labels, grid,
  daily line + fill, dotted 7-day average, today emphasised; legend "Daily · 7-day average".
- "HISTORY" `ListGroup`: "64.5 kg · Today · −0.1" with signed chips (`decrease` blue for down,
  `increase` orange for up). FAB "+ Log".
- **Log sheet:** 72 px value, 56 dp ±0.1 buttons, "Yesterday 64.6 kg" reference, date-time row
  "Today · 07:02 ▾", Save. The line "Also saved to Health Connect" appears **only if** the app
  actually writes weight to Health Connect / HealthKit (today it only imports — so it stays
  hidden; §6).

**Target spec — Statistics (5):**
- Header "Stats" + calendar icon (custom range, existing). **Metric chips**, horizontally
  scrolling, each in its metric colour; selected = tint + border in that colour.
- Hero: "Daily average · last 30 days" overline, **"8 532 steps"**, trend `DeltaChip`
  "↓ 4 % vs prior 30 d".
- Chart per metric (table below), then three side stats as a row of small labelled values,
  then the 7 d / 30 d / 90 d / All switcher **under** the chart (thumb reach).
- Count metrics grouped by week with the footnote "Grouped by week so a single day never looks
  like a spike."

| Metric (`StatMetric`) | Hero | Chart | Side stats (no "Total" unless it means something) |
|---|---|---|---|
| calories | daily avg kcal | daily bars + goal line | lowest · highest · days on target |
| protein / carbs / fat | daily avg g | daily bars + goal line | lowest · highest · days ≥ goal |
| water | daily avg L | daily bars + goal line | lowest · highest · days ≥ goal |
| steps | daily avg | line + 30-d avg | lowest · highest · total |
| weight | latest | line + 7-d avg | lowest · highest · change in period |
| workoutCount | count | **weekly** bars | per week (trend) · most in a week · total time |
| workoutMinutes | total time | weekly bars | avg per workout · longest · per week |
| activeCalories | daily avg | daily bars | highest · total |
| cardioSessions | count | weekly bars | per week · most in a week |
| cardioDistance | total km | weekly bars | longest · avg per session |
| cardioMovingMinutes | total | weekly bars | longest · avg per session |
| cardioElevationGain | total m | weekly bars | highest session |
| cardioAvgPace | weighted avg pace | line | fastest · slowest |
| maxHeartRate | highest | line | avg of session maxima |
| cardioMaxAltitude | highest | line | — |
| cardioHardZoneMinutes | total | weekly bars | per week |

(Confirm each row against `stat_summary_data.dart` in R4.5; the table is the target, the
existing aggregation types are the constraint.)

### R4.1 — Mobile UI: weight hero + goal band ✅
- `weight_screen.dart`, `goal_progress_card.dart` → goal band.
- **Verify:** no goal set → band shows a "Set a goal" action instead of zeros.

*As built:* `WeightScreen` is a `CustomScrollView` under the v2 `LifeyHeader` ("Weight", collapsing to the 52 dp row; pull-to-refresh starts below it) with one **hero card**
(`LifeyCard.hero`): **`WeightHeroHeader`** — the overline "Current · today 07:02" (the time it was logged; a date when the latest weigh-in is older) over the weight at **64 px** (`MetricValue`, fixed
under text scaling) and, beside it, the two changes as `DeltaChip.arrow`s — "↓ 0.1 today" (vs the previous day's weigh-in; "since last" when the latest isn't today) and "↓ 1.4 in 30 d" (only with ≥ 7 days
inside the window; the 30-day chip is the improvement green when it moved toward the goal, the calorie orange when away, the weight blue with no goal). Number and chips are one `Wrap`: at 360 dp × 1.3 the chips
drop under the number instead of squeezing it. **`WeightGoalBand`** replaces the old `GoalProgressCard`: "Start 67.9 · Goal **62.0 kg** · 2.5 kg to go" over an 8 dp `MetricBar` in the weight colour
(start = the first weight ever recorded, goal from onboarding, progress clamped 0–100 %, "Goal reached" once within 0.2 kg or past it), with the docs/76 projection ("−0.3 kg/week · At this rate, around …",
wrong-way / too-slow / not-enough-data) as tertiary text under the track. **No goal → a "Set a goal weight" action** (opens the profile editor), never zeros. Numbers come from the pure
`computeWeightHeadline` (`application/weight_headline.dart`, 14 unit tests: canvas values, two entries a day, short history, gain/loss goals, reached, drift) behind `weightHeadlineProvider`. The header's ⋮ holds "Import from
Health" and is only drawn while Health is connected (that is its only item); "+ Log" is the shell's extended FAB (`logFabLabel`). ARB: `weightCurrentToday/On`, `weightDeltaToday/SinceLast/30d`, `weightGoalStart`,
`weightGoalBandGoal/Reached`, `weightSetGoalAction`, `weightChartLegendDaily`, `weightMoreTooltip`; range labels now "7 d / 30 d / 90 d / All" ("7 n … Mind").

### R4.2 — Mobile UI: weight chart + range switcher ✅
- `weight_screen.dart` on the upgraded `TimeSeriesChart`; 7-day average from the docs/76 trend.
- **Verify:** single entry → one point, no average line; gaps don't draw fake lines.

*As built:* inside the hero card, `LifeySegmented` (7 d · 30 d · 90 d · All; **30 d is the default**, the canvas' — the controller's doc said month but returned week) and the v2 `TimeSeriesChart`: 3 Y labels with grid,
daily line with the gradient fill, **the 7-day average dotted** (`TrendStyle.dotted`), the last point emphasised, legend "Daily · 7-day average" (the average only when one is drawn). **Decision D-R4.1 (§10 Q4):
follow the canvas** — the daily line leads, the average is dotted; docs/76's D-W3 style (bold trend) stays as `TrendStyle.emphasized` for other callers. A single entry is one point with no average and no legend entry for
it; an empty range says so instead of drawing (tests). One fix on the way: the empty state of the screen (`EmptyView` is a scroll-fill) must sit in a bounded `SliverFillRemaining`, not `hasScrollBody: false`.

### R4.3 — Mobile UI: weight history rows with signed chips ✅
- `weight_screen.dart`.
- **Verify:** sign and colour follow the direction; U+2212 minus; 0.0 change has no sign.

*As built:* "HISTORY" (`SectionLabel`) over lazily built `GroupedListItem` rows (one card, hairlines, radius 22 at the ends): the weight in 19/800 with its unit, "Today / Yesterday / Mon, Sep 21" under it (localized), and a
`DeltaChip.signed` — "−0.1" with a real U+2212, "+0.6" in the calorie orange for a gain, the weight blue for a loss, "0.0" neutral and unsigned; the oldest entry has none. The free-history boundary row and the
Health import (now in the ⋮ menu) are kept. Tests: `weight_screen_test` (title, hero, switcher, chart style, FAB, signs and colours, single entry, empty, range switch, no overflow at 411/360 dp × 1.3 HU dark + light) and
`weight_hero_test` (chips, colours, the goal band states).

### R4.4 — Mobile UI: log-weight sheet
- `add_weight_sheet.dart`.
- **Verify:** ±0.1 steps don't accumulate float error (step in grams internally, unit test);
  imperial units still work if enabled in Settings.

### R4.5 — Mobile data: per-metric summary definitions
- `statistics/application/stat_summary_data.dart` (+ `domain/stat_summary.dart`): the table
  above as a pure function `summaryFor(metric, points, range)` + "vs prior period" trend with
  equal-length window and today's partial day excluded; unit tests per metric.
- **Verify:** weight has no total; prior period 0 → trend hidden, not "∞ %".

### R4.6 — Mobile UI: metric chips + hero + side stats
- `statistics_screen.dart`. Decision to confirm (§10 Q1): the canvas shows All · Strength ·
  Cardio in the same chip row as the metrics; plan = metrics in the chip row, the kind filter
  as a small segmented control that appears only for workout-derived metrics.
- **Verify:** switching metric recolours chip, hero and chart; HU labels fit.

### R4.7 — Mobile UI: stats charts incl. weekly bucketing + period switcher under the chart
- `statistics_screen.dart`, `stat_chart_data.dart` (week bucketing helper, unit-tested).
- **Verify:** 30 d workout count shows ~5 weekly bars, not 30 mostly-zero days.

**R4 derived screens:** none beyond the above (statistics_tab in trainer detail is R6).

**R4 acceptance** (plus the §4.1 emulator review logged in §12)**:** 4 and 5 canvases reproduced in dark and light (Weight light and Stats light
frames exist in the canvas); every metric shows a sensible hero and side stats.

---

## R5 — Auth, onboarding, chat, settings · `Lifey 5 Onboarding Chat Settings.dc.html` (6–8)

**Goal:** secondary screens use the same header, list and button system as the main tabs.

**Current code:** `auth/presentation/login_screen.dart`, `register_screen.dart`,
`forgot_password_screen.dart`, `change_password_screen.dart`;
`onboarding/presentation/onboarding_screen.dart` (954), `onboarding_edit_screen.dart`,
`widgets/option_card.dart`, `confirm_save_details_dialog.dart` (10 colour literals),
`onboarding_banner.dart`; `chat/presentation/chat_thread_screen.dart`,
`conversation_list_screen.dart`, `chat_search_screen.dart`, `new_conversation_sheet.dart`,
`widgets/message_bubble.dart`, `chat_composer.dart`, `chat_avatar.dart`, `day_divider.dart`,
`conversation_tile.dart`, `chat_attachment_view.dart`; `settings/presentation/settings_screen.dart`
(1 637), `notification_settings_screen.dart`, `widgets/subscription_tile.dart`.

**Target spec:**
- **Login (6):** logo tile "L", "Welcome back", one-line promise "Sign in to pick up where you
  left off. Your logs stay on this phone, even offline."; filled inputs with leading icons
  (mail, lock); "Forgot password?"; **"Sign in" is always primary**; "or" divider; "Continue
  with Google" secondary (outlined); "New to Lifey? Create account".
- **Onboarding (6):** top row "Skip"; **6-segment progress bar** + "Step 4 of 6"; step 4 "How
  active are you?" as a **single-column radio list** (5 rows: icon, title, description) +
  "Primary goal" choice chips (Lose weight / Maintain / Build muscle); step 5 "Your suggested
  plan": calorie hero 60 px, "BMR 1 384 · TDEE 2 145 · +10 % surplus", `RatioBar` + grams + %
  for P/C/F, water tile, footnote "You can change these anytime in Settings → Body & goals",
  full-width "Apply these goals", then "Back" / "Not now" smaller. On the Health step "Not now"
  leaves the connection off (verify, don't assume).
- **Chat thread (7):** `LifeySubpageHeader` with avatar, "Mark Trainer", "Your trainer · online",
  search icon (mute moves into ⋮). Bubbles: own = primary olive, trainer = `card` surface,
  15 px text, timestamps and ✓✓ under the bubble; day divider "Today". Composer: 48 dp field,
  round send button, blur scrim behind the bar.
- **Settings (8):** large title; profile card (monogram "AK", name, e-mail, "Pro" chip);
  "PREFERENCES" group (Units segmented Metric/Imperial, Theme Light/Dark/Auto, Language ›);
  "DAILY GOALS" card with Edit and **six small tiles** with metric dots (Calories, Protein,
  Carbs, Fat, Water, Steps — steps shows 10 000 default via R1.4); "INTEGRATIONS" (Health
  Connect with an honest subline "Off · weight and steps are logged by hand", Notifications
  "3 on ›"); "ACCOUNT" → Log out at the bottom, with the confirmation dialog.

### R5.1 — Mobile UI: login + register + forgot/change password
- `login_screen.dart`, `register_screen.dart`, `forgot_password_screen.dart`,
  `change_password_screen.dart` (AppBar → subpage header).
- **Verify:** Google sign-in unchanged; keyboard doesn't cover the primary button.

### R5.2 — Mobile UI: onboarding frame — segmented progress, skip, button hierarchy
- `onboarding_screen.dart` (shared scaffold for all steps).
- **Verify:** every step shows "Step n of 6"; back/skip behaviour unchanged.

### R5.3 — Mobile UI: onboarding activity list + goal chips
- `onboarding_screen.dart`, `option_card.dart` → radio `ListRow`.
- **Verify:** HU descriptions wrap, never 3-line clipped cards.

### R5.4 — Mobile UI: onboarding suggested-plan hero
- `onboarding_screen.dart`; `confirm_save_details_dialog.dart` restyled (literals out);
  `onboarding_edit_screen.dart` (AppBar → subpage header).
- **Verify:** numbers equal today's calculation (no maths change); "Not now" on Health step
  really leaves it off.

### R5.5 — Mobile UI: chat thread, composer, bubbles
- `chat_thread_screen.dart`, `message_bubble.dart`, `chat_composer.dart`, `day_divider.dart`,
  `chat_avatar.dart` (→ `MonogramAvatar` where it shows initials).
- **Verify:** bubbles readable in both themes (own bubble text = onPrimary); the 3 known Windows
  attachment test failures are unchanged, nothing new fails.

### R5.6 — Mobile data: logout uploads pending changes first, and says so honestly
- `auth/application/auth_controller.dart` `logout()`: before clearing, if online, run one
  `SyncEngine.sync()` with a short timeout; count what is still in the outbox; the dialog
  (R1.1) shows the canvas copy ("Unsynced changes … will be uploaded first. Your data on this
  phone is removed.") when the outbox is empty or online, and a warning variant "N changes
  couldn't be uploaded and will be lost" otherwise.
- **Verify:** unit test with a fake sync engine: online → sync called before clear; offline →
  warning count; clearing still happens after (the cross-account leak fix from #43 must hold).

### R5.7 — Mobile UI: settings grouped lists + goals tiles + account section
- `settings_screen.dart` (large file: split into section widgets under
  `settings/presentation/widgets/` as you go), `subscription_tile.dart`,
  `notification_settings_screen.dart` (AppBar → subpage header).
- **Verify:** every existing setting is still reachable (list them in the PR); HC subline
  matches the real state.

**R5 derived screens (R5.8):** `conversation_list_screen.dart`, `conversation_tile.dart`,
`chat_search_screen.dart`, `new_conversation_sheet.dart`, `chat_attachment_view.dart`;
`my_trainers` and `trainer_invite` client-side screens; subscription / paywall screens get the
tokens only (their layout is governed by docs/landing_page/69).

**R5 acceptance** (plus the §4.1 emulator review logged in §12)**:** register → onboarding → dashboard → chat → settings → logout, all on the new
system, no plain `AppBar` left in these features.

---

## R6 — Trainer view · `Lifey 6 Trainer.dc.html` (9.1–9.2)

**Goal:** the trainer shell is the same family as the client app — same olive, chips, cards —
with the role shown by a clay "TRAINER" mark, not a second green.

**Current code:** `shared/widgets/trainer_shell.dart` (`accentColor: scheme.tertiary`),
`features/trainer/shared/trainer_view_badge.dart` (tertiary on purpose — now changes),
`trainer/clients/presentation/trainer_clients_screen.dart`, `widgets/client_card.dart`,
`client_sort_chips.dart`, `compliance_badges.dart`, `weight_sparkline.dart`;
`trainer/client_detail/presentation/client_detail_screen.dart`, `tabs/*` (overview, workouts,
nutrition, weight, steps, schedule, statistics), `widgets/*`; `trainer/schedule`,
`trainer/assignments`, `trainer/programs` (`program_detail_screen.dart` has an AppBar),
`trainer/invites` (`trainer_invites_screen.dart` AppBar), `trainer/settings/trainer_settings_screen.dart`
(AppBar); domain `trainer_client.dart` (`workoutsPerWeek`, `weightTrend`, `missedWorkoutCount`,
`lastActivityAt`, `lastWeightAt`), `compliance.dart`.

**Target spec:**
- **Clients (9.1):** header with clay "TRAINER" mark, "My clients", actions add-person and chat;
  sort chips Recent activity · Least active · Most missed · Weigh-in due; **client card**:
  monogram, name, status line ("Active today" / "Last seen 4 days ago"), three KPIs (Avg kcal ·
  Workouts / wk · Weight Δ), a weight sparkline, warning chips ("Missed 2 sessions",
  "Weigh-in due" in calories tint; "🏆 2 PRs this week" in record tint). Bottom nav: Clients,
  Calendar, Assigned, Programs in the client nav style.
- **Client detail (9.1):** subpage header (monogram, name, "Client since 24 Sep 2026", ⋮);
  **underlined, horizontally scrolling tab bar** (Overview · Workouts · Nutrition · Weight ·
  Steps · Schedule — Statistics too, as today); actions **right under the tabs**: "Message",
  "Schedule"; "LAST 7 DAYS" 2×2 KPI tiles with goal-relative sublines ("69 % of goal", "all
  planned done", "84 % of goal", "hard, not maximal"); weight trend card.
- **Tablet (9.2, 1280×800):** navigation rail (96) · client list (400, search, selected client
  gets an olive border) · detail (flex). KPIs in 4 columns; weight trend and "Upcoming" sessions
  side by side.

**Data:** Weight Δ derivable from `weightTrend`; workouts/wk exists; warnings exist
(`compliance.dart`). **Avg kcal (7 d) and PRs this week are not in `trainer_client.dart`** →
R6.2 (optional backend) + R6.3; until then the card shows two KPIs and no PR chip.

### R6.1 — Mobile UI: trainer shell into the client family
- `trainer_shell.dart` (accent → primary), `trainer_view_badge.dart` (clay "TRAINER" mark with
  `palette.role`), `trainer_view_menu.dart`.
- **Verify:** no `tertiary` used as an accent anywhere under `features/trainer` (grep); both
  themes.

### R6.2 — Backend (optional): client list summary gains `avgCalories7d` and `prCount7d`
- Use the `backend-feature-slice` skill for the endpoint that feeds the trainer client list;
  two nullable read-only fields computed from existing tables (ownership-scoped to the
  trainer's clients); no migration expected — if one turns out necessary, use the
  `flyway-migration` skill and say so in the PR.
- **Verify:** controller test for a client with and without meals/PRs in the window.

### R6.3 — Mobile data: parse the two new fields (nullable)
- `trainer/clients/domain/trainer_client.dart`, its data mapper; tolerate absence.
- **Verify:** unit test for payloads with and without the fields.

### R6.4 — Mobile UI: clients list + client card
- `trainer_clients_screen.dart`, `client_card.dart`, `client_sort_chips.dart`,
  `compliance_badges.dart` (→ `TintedChip`), `weight_sparkline.dart` (tokens).
- **Verify:** null KPIs are hidden, not "0"; sorting unchanged.

### R6.5 — Mobile UI: client detail header, tab bar, actions, overview KPIs
- `client_detail_screen.dart`, `client_detail_header.dart`, `client_tab_body.dart`,
  `tabs/overview_tab.dart`, `metric_card.dart`, `trend_chart_card.dart`.
- **Verify:** HU "Táplálkozás", "Ütemezés" not truncated; underline follows the active tab.

### R6.6 — Mobile UI: remaining client-detail tabs
- `tabs/workouts_tab.dart`, `nutrition_tab.dart`, `weight_tab.dart`, `steps_tab.dart`,
  `schedule_tab.dart`, `statistics_tab.dart`, `session_card.dart`, `history_card.dart`,
  `session_detail_sheet.dart`, `session_comment_sheet.dart`, `nutrition_goals_sheet.dart`,
  `read_only_badge.dart`. Reuse R3/R4 components (session rows, weight chart, stats hero).
- **Verify:** each tab in both themes; read-only states still obvious.

### R6.7 — Mobile UI: tablet three-column layout
- Where the current tablet breakpoint lives (`trainer_shell.dart` / `trainer_clients_screen.dart`).
- **Verify:** 1280×800 emulator: rail 96 · list 400 · detail flex; selection updates the right
  pane without navigation; phone layout unchanged.

**R6 derived screens (R6.8):** trainer calendar/schedule, assignments (+ widgets), programs
(`program_detail_screen.dart` AppBar → subpage header), invites (`trainer_invites_screen.dart`
AppBar), `trainer_settings_screen.dart` (AppBar).

**R6 acceptance** (plus the §4.1 emulator review logged in §12)**:** trainer flow on phone and tablet looks like the client app with a clay role
mark; no second green.

---

## R7 — Sweep and cleanup (general, closing)

**Goal:** nothing left on the old system; the old system deleted.

### R7.1 — Tooling: style-debt audit script
- `mobile/tool/design_audit.dart` (or `.sh`): counts per file `fontSize:`, `Color(0x`,
  `BorderRadius.circular(`, `AppBar(`, `AdaptiveAppBar(`, deprecated `AppRadius` aliases outside
  `core/theme/` and `shared/widgets/ds/`. Run it at the end of every iteration and paste the
  totals in the PR (the §2 baseline: 396 / 70 / 348 / 14 / 16).
- **Verify:** script output matches a manual grep.

### R7.2 — Mobile UI: remaining undesigned screens
- Whatever the audit still lists (expected: `placeholder_screen`, `offline_banner`,
  `sync_status_indicator`, `origin_trainer_badge`, `activity_chip`, `history_boundary_row`,
  `confirm_delete_dialog` (6 literals), subscription screens tokens-only, ads containers).
- **Verify:** audit totals near zero (literals left only where justified by a comment).

### R7.3 — Mobile UI: delete `AdaptiveAppBar` and the deprecated radius aliases
- Remove `adaptive_app_bar.dart`, `AppRadius` aliases, `AppCurve.collapse`, old
  `AppDuration` if unused, `stat_card.dart` if unused.
- **Verify:** `flutter analyze` clean with zero deprecation infos.

### R7.4 — Docs: close the loop
- Update this plan's Status and mark finished steps ✅; update `docs/04-mobile-app.md` UI
  section and `docs/design/README` pointers (20 superseded by 77); note in
  `docs/REMAINING-WORK.md` the deferred items from §6; update the tinted-chip backlog note as
  resolved.

**R7 acceptance** (plus the §4.1 emulator review logged in §12)**:** audit clean, one header system, one nav, one card, one chip; docs current.

---

## 5. Order of work and milestones

| Milestone | Steps | You can look at |
|---|---|---|
| **M1 — New look everywhere** | R0.1–R0.5, R0.6, R0.10, R0.11 | Whole app on new palette/type/nav + gallery |
| **M2 — Component kit complete** | R0.7–R0.9, R0.12–R0.14 | Gallery = canvas "Alapkomponensek" |
| **M3 — Today** | R1.1–R1.7 | Dashboard canvas reproduced (**smallest worth-using release**) |
| **M4 — Daily logging** | R2.1–R2.9 | Meal logging end-to-end |
| **M5 — Training** | R3.1–R3.11 | Strength + cardio sessions end-to-end |
| **M6 — Progress** | R4.1–R4.7 | Weight + stats |
| **M7 — Around the app** | R5.1–R5.8 | Auth → onboarding → chat → settings |
| **M8 — Trainer** | R6.1–R6.8 | Trainer on phone and tablet |
| **M9 — Clean** | R7.1–R7.4 | Old system gone |

R7.1 (the audit script) is cheap and useful early — it may be pulled forward into M1.
R2–R6 depend only on R0, not on each other, so their order can change (e.g. R5 before R3) if
priorities change; the canvas priority order (dashboard, nutrition, workouts, …) is the default.

---

## 6. Non-goals (deferred)

- **Piece-based portion chips** ("½ pc", "1 pc") in the add-food sheet — needs a per-food piece
  weight in the food model + sync. Gram chips only for now.
- **Sharing a PR / workout as a chat card** (canvas 7 "Megosztható eredmények") — chat
  attachments are images only (`chat/domain/chat_message.dart` `ChatAttachment`); a new
  attachment kind needs chat-service work. Own plan later.
- **Writing weight to Health Connect / HealthKit** — the app imports only; the "Also saved to
  Health Connect" line stays hidden until a write path exists.
- **Web redesign** — the Next.js app shares the palette today (see the light `secondary` note
  in `app_theme.dart`); it will diverge after R0.1. Follow-up plan for `web/`.
- **Watch apps, iOS widget / Live Activity, Android widget / ongoing notification** — native
  styling, not covered. Colour alignment is a follow-up.
- **Material Symbols** icon font (D-R0.10).
- **New features or data** beyond R6.2's two read-only fields (D-R0.15).
- **Golden-image tests** (D-R0.11).
- **Max-HR setting**, if it doesn't exist yet — the cardio footnote drops its last sentence.

---

## 7. Edge cases

- **Over budget:** remaining kcal negative → "212 kcal over", ring over state, calories/negative
  colour — dashboard hero, nutrition budget, macro rings, "after this meal" preview.
- **Zero / empty data:** no meals, no weight, no workouts this week, new account with no goals →
  R0 empty states; never "0 / 0", never NaN %, never a chart with an axis of 0–0.
- **First weight entry:** no delta chips, no 7-day average, goal band without "start".
- **Very long values:** 5-digit kcal ("12 345"), 3-digit weights (imperial "142.3 lb"),
  "4 280 kg" volume, 10-exercise session names — must wrap, not truncate.
- **HU + 130 % text scale** simultaneously on every screen's verification pass.
- **Imperial units:** every new hero/delta/sheet respects the Units setting (weight ±0.1 lb
  step, distance in miles, pace /mi).
- **Midnight rollover while open:** dashboard "today", week strip and "today" bar re-evaluate on
  app resume.
- **Offline:** AI entry points (Photo, Generate a recipe) show the error state; everything else
  works (offline-first unchanged).
- **Trainer viewing a client:** read-only screens reuse client components without edit actions.
- **Reduced motion:** all count-ups/rings/celebrations land instantly on the final value.
- **Small phones (360 dp width) and tablets:** hero card ring + macros side by side must wrap to
  stacked below ~360 dp.
- **Locale week start:** week strip, weekly bars and "this week" summaries use one shared week
  definition (the one streaks/recap use).

---

## 8. Test plan and PR split

**Tests by layer:**
- *Unit:* contrast pairs (R0.1), motion zero-duration (R0.2), formatting EN/HU (R0.4), chart
  helpers — ticks, average excluding today, weekly bucketing (R0.13, R4.7), "after this meal"
  remaining (R2.5), PR count per session (R3.2), zone % largest-remainder (R3.9), weight step
  arithmetic (R4.4), per-metric summaries + prior-period trend (R4.5), logout sync ordering
  (R5.6), trainer DTO parsing (R6.3), backend controller test (R6.2).
- *Widget:* no overflow at 1.3 + HU for each redesigned screen's key widget (hero card, meal row,
  set row, client card, settings group); semantics labels on the bottom nav; ≥ 48 dp hit areas;
  count-up doesn't restart on rebuild; over-budget states.
- *Manual (per step):* the §4 checklist.
- *Emulator review (per iteration):* §4.1 — the full dark/light × EN/HU matrix, text scale 1.3,
  reduced motion, every canvas frame side by side, the iteration's demo flow; results in §12.

**Commit / PR split:** one commit per step, pushed straight to `feature/mobile-redesign` (§4).
At the end of each iteration — after its emulator review (§4.1) — the branch is proposed for
merge into `main` as one PR per iteration, so the branch never drifts far; because the app is
unreleased (D-R0.1) such a merge doesn't need to be a release. Nothing goes to `main` without
the user's go-ahead. Derived-screen steps that grow beyond one session split by folder.

---

## 9. Risk checkpoints where a failure would be silent

Reviewers should stare at these; each produces a wrong look or number, not an error.

1. **Protein vs primary swap (R0.1):** any code using `colorScheme.primary` to mean protein, or
   `metricColors.protein` to mean "selected", now renders the wrong colour without failing.
   Grep both in every iteration's files.
2. **Light-theme tinted chips (R0.4/R0.7):** using the dark-theme metric colour as text on a
   light tint silently fails AA. Only `TintedChip` may build a tinted chip.
3. **Double-counted meal in "after this meal" (R2.5):** editing a saved meal must subtract its
   stored version, or the preview is off by the whole meal.
4. **Rounded sums (R0.4):** summing already-rounded kcal makes meal totals disagree with the day
   total by ±1–3. Round at display only.
5. **Partial today in averages (R0.13, R4.5):** including today's half-logged day lowers the
   weekly average and the "vs prior" trend every morning.
6. **Weekly bucketing boundaries (R4.7, R3.1):** a different week start than streaks/recap makes
   "this week" disagree between screens.
7. **Count-up from 0 on rebuild (R0.5):** a provider refresh re-animates every number — looks like
   data reloaded; test that equal values don't animate.
8. **Nav labels hidden visually (R0.11):** dropping the `Semantics` label on inactive tabs breaks
   TalkBack/VoiceOver without any visual sign.
9. **Logout dialog promising an upload that doesn't happen (R1.1/R5.6):** today `logout()` wipes
   the outbox. The dialog copy must match the behaviour at every point in the rollout — R1.1
   ships the honest "will be lost" copy; only R5.6 may switch to "uploaded first".
10. **Step goal default (R1.4):** a display-only default would show 10 000 while notifications use
    `null`; one `effectiveDailyStepGoal` everywhere.
11. **HR zone percentages (R3.9):** naive rounding gives 99 % or 101 %.
12. **Hidden bottom content (R0.10/R0.11):** `extendBody` + floating nav hides the last row unless
    every scroll view pads by nav height + `s56`.
13. **Blur cost (R0.10/R0.11):** `BackdropFilter` on low-end Android can drop frames; limit blur
    to nav, header scrim and sheets — never inside list items.
14. **`textTheme` slot meanings shift (R0.3):** a screen still using `displayLarge` for a 34 px
    value renders at 72 px — or clips inside a fixed-height box and looks "fine" at a glance.
15. **Health Connect honesty (R5.4/R5.7):** the settings subline and onboarding "Not now" must
    reflect the real permission state, not the last UI choice.

---

## 10. Open questions (decide before the step, not blocking the plan)

1. **R4.6 — stats kind filter placement.** The canvas puts All · Strength · Cardio in the metric
   chip row. Plan: separate small segmented control, only for workout metrics. Confirm or keep
   the canvas literally.
2. **R6.2 — do we want the backend fields at all?** If not, the client card ships with two KPIs
   and no PR chip permanently.
3. **Greeting copy (R1.2)** — time-of-day greeting ("Good morning/afternoon/evening") or a fixed
   one? Canvas shows "Good morning, Anna" only.
4. **R4.2 — which weight line leads.** The canvas makes the daily weight line the hero and the
   7-day average dotted; docs/76 D-W3 decided the opposite (the smoothed trend is what should
   read, the raw line steps back). Both are built (`TrendStyle`); keep D-W3, or follow the
   canvas?

---

## 11. After implementation

- Update `Status:` here and tick ✅ per step as they land.
- `docs/04-mobile-app.md` — replace the UI/theme section with a pointer to R0 of this doc and to
  `shared/widgets/ds/`.
- `docs/design/20-design-implementation-tasks.md` — add a "superseded by
  docs/redesign/77-mobile-redesign-plan.md" line at the top.
- `docs/REMAINING-WORK.md` — add the §6 deferred items.
- Follow-up plans to open: web palette alignment, chat result-sharing card, piece-based
  portions, native widgets/watch colour alignment.

---

## 12. Review log

One entry per iteration-end emulator review (§4.1). Format: `### R<n> — <date> — <device(s)>`,
then *Matches*, *Deviations (intended)* with decision ids, *Bugs* with the fix step that closed
each.

### R0 — 2026-09-25 — Pixel_10 AVD (1080 × 2424, 420 dpi = 411 × 923 dp, API 37)

Scope: the debug design gallery (`lifey:///debug/design`) in light/dark × EN/HU × 100/130 %,
against `Lifey Design System.dc.html`; plus the logged-in screens with a seeded local account
(`anna.kovacs@lifey.test`, local dev backend only) and the login screen — to confirm the R0
theme doesn't break the not-yet-migrated screens.

**Matches**
- Colour tokens, text tiers and their contrast ratios, metric colours + 16 % chip tints (light
  and dark), brand-only-for-controls.
- Type scale roles, tabular hero numbers that stay fixed at 130 % while body text grows.
- Formatting (HU `17 519`, `64,5`, `szept. 24.`, U+2212 deltas), spacing ladder, 4-step radii
  with nested = parent − inset, elevation e0–e3 (float + blur), motion durations, press scale.
- Icons (outlined/filled pairs), cards, section labels, tinted/delta/record chips, monogram
  avatars, buttons, chips, segmented control, list rows, inputs (focus/error ring), dialog,
  snackbars, rings (incl. overflow lap), metric bars, tiles, headers, bottom nav (HU
  "Áttekintés" fits), sheets, empty/error states, bar and line charts.

**Deviations (intended / transitional)**
- Old screens: scrolled content under the status bar on dashboard/settings (R1/R5 header
  migration), light-theme cards grey because old code uses `surfaceContainerHigh` (slots not
  re-mapped on purpose, D-R0.3), old segmented controls and stats formatting (`17518.6 kcal`,
  EN dates in HU — R4), logout icon on the dashboard (R1.1), avatar from the e-mail (R5),
  weight delta in green (R1.4), "Oats & berries" crowding its date after body 14 → 16 (R2.3).
- Weight trend style: canvas dotted average vs docs/76 D-W3 — both are `TrendStyle` options,
  R4.2 decides (§10 Q4).
- The floating upcoming-workout card overlapping content is pre-existing (not R0).

**Bugs (all fixed on `feature/mobile-redesign`)**
- Chip labels rendered with no colour — RawChip resolves only `labelStyle.color` per state →
  R0.fix-1.
- PillTabBar at the design's 20 px margin misaligned with 12 px legacy content → per-screen
  opt-in margin, R0.fix-2.
- Login/register/password/chat-search/composer fields picked up the v2 fill; email + password
  merged into one grey block with an invisible divider → `filled: false`, outline divider,
  R0.fix-3.
- Body/label slots showed Material's +0.25–0.5 px tracking (null letterSpacing merged with M3
  geometry by `Theme.of`); units inherited the number's −3 % ("621/2,360kcal") → explicit 0,
  R0.fix-4.
- RatioBar segments were 0 px tall (childless ColoredBox in a Row) — every ratio bar showed an
  empty track → R0.fix-5.
- Gallery empty-state frame too short for HU (gallery only) → R0.fix-6.
- PillTabBar labels wrapped and were clipped in HU at 130 % ("Étkezések", "Receptek") → scale
  down to fit, R0.fix-7.

R0.fix-1, -4, -5 and -7 have widget tests that fail without the fix; fix-3 (login fields) and
fix-6 (gallery) were verified on the emulator only. Full suite green except the 3 known Windows
chat-attachment failures.


### R1 — 2026-09-25 — Pixel_10 AVD (1080 × 2424, 420 dpi = 411 × 923 dp, API 37)

Scope: the Today screen against `Lifey 1 Dashboard.dc.html` (1.1 dark top + scrolled, 1.2 light, 1.3 HU),
rendered from the canvas with Playwright at 2.625× and put next to emulator screenshots; plus the flows —
avatar menu → Settings → Log out (dialog, cancelled), the add-water sheet (0.25 L tile → total and bar
update), Photo (opens the picker, dismissing it closes the empty meal screen), weekly recap, water sources
(list, ⋮, new-source sheet with the keyboard). Seeded account `anna.r1@lifey.test` (local dev backend
only; the canvas' numbers: 2 360 kcal goal, 383 + 239 kcal of meals today, a week of meals, 30 weights
ending 64.5 / 64.6, 0.99 L water, a "Push day" the day before, a run, a workout streak). Matrix covered:
dark EN, light EN, dark HU, light HU at ×1.3, plus scroll-to-the-end (last row clears the nav).

**Matches**
- Header (date overline, 30/800 greeting, chat button, monogram avatar), streak strip (icon + count,
  muted zero, "Week in review ›"), hero card (144 px ring, remaining kcal, Eaten · Goal, three macro rows
  with bars, "111 g to go" chip), water / steps tiles with the 48 dp `+`, weight tile with the delta chip
  and sparkline, "This week" bars with axis, dashed goal line, today highlighted, both section lists
  with icon holders, dividers, "+ Meal / Photo", "★ Rate", the running row with kcal — value for value
  and in both themes. Light uses white cards with shadow and the darker metric colours as drawn.
- HU (1.3): "Csütörtök/Péntek, szeptember 25.", "Jó reggelt, Anna", "kcal maradt", "még 111 g", "Víz /
  Lépések / Súly", "Legutóbbi bejegyzés · ma", "Ezen a héten", "átl."; at ×1.3 nothing is truncated:
  "Szénhidrát" drops its value under the label, "Evett … · Cél …" wraps, tiles and rows grow.
- Log-out dialog, Add-water sheet, water-source sheet and the recap screen follow the design system
  (sheet 30 radius + handle, tinted 64 px tiles, in-sheet fields, section labels over cards).

**Deviations (intended)**
- Numbers: EN groups with a comma ("1,737"), the canvas shows a space; HU decimals use a comma
  ("64,5 kg", "1,24 / 2,6 L") where the HU frame draws dots (R0.4 decision).
- Onboarding banner is shown (the seeded account has not finished onboarding) — the canvas frames
  have none; it uses `NoticeCard` (R1.8).
- Steps read 0 / 10 000: no Health data on the emulator. The tile only appears when step data exists
  (as the old card did) and now defaults its goal to 10 000 (R1.4).
- Logged-in Settings still has the pre-R5 look (floating bar, old rows) with the new Log out row.

**Bugs (fixed on `feature/mobile-redesign`)**
- The scrolled header row said "Good morning, Anna"; the canvas says "Today" → `LifeyHeader.collapsedTitle`
  and the EN nav label "Dashboard" → "Today" (canvas nav), R1.fix-1 (header test asserts the cross-fade and
  that screen readers get only the expanded title).
- The section label rows are 48 dp tall (the "See all" target) and the old 24 dp gaps around them put
  sections ~40 dp apart instead of 16 → gaps removed, `RecapReadyCard` spaces above itself, R1.fix-1
  (verified against the scrolled canvas frame; layout numbers, no widget test).
- HU at ×1.3 the workout meta line broke inside "34 | perc" and started a line with "·" → no-break
  spaces inside each part and before the dot, R1.fix-2 (`dashboard_lists_test` compares the glued string).

**Not exercised on the emulator** (covered by widget tests only): the unread-dot on the chat button (no
chat messages seeded), the sponsorship-ended card, the recommended-workout card, over-budget ring
state, the "Remove animations" pass, imperial units.

### R2 — 2026-09-25 — Pixel_10 AVD (1080 × 2424, 420 dpi = 411 × 923 dp, API 37)

Scope: Nutrition against `Lifey 2 Nutrition.dc.html` — 2.1 Meals (week strip, budget card, grouped rows), 2.2 Edit meal + Add
food sheet, 2.3 Recipes, 2.4 Macros — rendered from the canvas with Playwright at 2.625× and put next to emulator screenshots, plus the
flows: **the demo flow** (week strip → Thu → "+ Meal" → Add food → Apple chip → Add to meal → Save → back on Thu with the new row and
the rings/budget updated), long-press menu on a meal, edit an existing meal, the add-food sheet with a chip and the numeric keyboard.
Seeded account `anna.r1@lifey.test` (the R1 data + four recipes). Matrix covered: dark EN, light EN, dark HU, light HU at ×1.3 (Meals, the
editor and the add-food sheet), dark EN with animations removed (Macros, Recipes tabs).

**Matches**
- Header (30/800 title, round copy-day and scanner buttons), pill tab bar, week strip (Fri…Thu, 30 px calorie rings, selected day in a primary
  outline), budget card (621 / 2,360 kcal, "1,739 left" chip, P/C/F bar, coloured gram lines), meal rows (icon holder, name / kcal, meta +
  P C F in colour, foods line) — value for value, dark and light. Edit meal: Save in the header, choice chips with the check, date row,
  "FOODS · n" group with ⋮, three equal tiles, floating summary (Meal total, tinted macro tiles, "after this meal" with the paler
  segment). Add food: search with the scanner inside, recent chips, the outlined food card with the − / + hero, quick chips,
  "+95 kcal → 1,643 kcal left", full-width "Add to meal". Recipes: entry card, chips, two-column grid with placeholder photos, star, "+ Log".
  Macros: Today card with three rings and the 26 % chip, "LAST 7 DAYS" rows.
- HU: "Étrend", "Étkezések / Receptek / Ételek / Makrók", weekday abbreviations Szo…P, "1 737 maradt", macro letters F / Sz / Zs,
  "Ma az étkezés után", "Étkezés szerkesztése"; at ×1.3 nothing is cut off (tile labels shrink in the card, "Szénhidrát" fits).
- With animations removed the rings, bars and numbers show their final value at once; nothing else moves.

**Deviations (intended)**
- Numbers: EN groups with a comma ("2,360"), the canvas a space; HU decimals/thousands per `LifeyFormat` (R0.4).
- The header has a **search** button on Recipes / Foods and a **calendar** ("All meals") button on Meals in addition to the two canvas buttons
  (R2.1 / R2.2 — the canvas draws neither, both are needed for existing functions).
- "1,739 left" in the editor instead of the canvas' "1,356": the canvas counts the edited meal twice; the plan (§9 risk 3) asks for the correct
  figure (R2.5). Bars on the Macros rows split the whole bar (100 %) where the canvas stops short.
- Not built: ☆ favourite on a food and the "½ pc / 1 pc" chips (no such data — §6); the recipe photo caption of the mock.
- The 7-day strip / "Last 7 days" are the last days *with meals*; older days live in "All meals". The old Today / Week / All filter is gone.
- A live language change leaves the shell's "+ Meal" FAB label in the old language until the tab is left and re-entered (the label is pushed
  to the shell once per tab activation — pre-existing).

**Bugs (fixed on `feature/mobile-redesign`)**
- The pinned tab bar of the `NestedScrollView` showed the list scrolling *through* the gap between the title row and itself → the pinned
  sliver sits on the header's scrim (found while checking Recipes; part of R2.7).
- At HU ×1.3: the editor's title ended in "Étkezés szerkes…", the "Étel hozzáadása" tile broke mid-word over three lines and "Szénhid…" was cut in the
  summary tile → `LifeySubpageHeader` titles shrink to fit instead of ellipsizing, the three action tiles stop scaling text at 115 % and
  tighten their padding, the macro tile label shrinks (R2.fix-1; covered by the 360 / 411 dp × 1.3 HU layout tests).

**Not exercised on the emulator** (covered by widget tests only): the barcode camera, AI photo estimate, recipe wizard and generated recipe,
recipe long-press menu / photo, over-goal state of the budget and rings, no-goal accounts, imperial units, a free-tier account with the history boundary.

### R3 — 2026-09-25 — Pixel_10 AVD (1080 × 2424, 420 dpi = 411 × 923 dp, API 37)

Scope: Workouts against `Lifey 3 Workouts.dc.html` — 3.1 sessions list, 3.2 live strength (rest hero, set rows, PR language, floating bar) and the PR sheet, 3.3 live cardio and the cardio
detail — canvas frames rendered with Playwright at 2.625× and put next to emulator screenshots, plus the flows: **the strength demo flow** (start Push day from the recommended card → edit set 2
to 67.5 kg → check → PR trophy + rest hero counting down → Finish workout → "How hard was this workout?" → Skip → PR sheet with the +2.5 kg / +3.2 kg deltas → Continue → back on the list with the
"2 PRs" chip) and **the cardio flow** (Cardio → Running → start without GPS → pause → Resume → slide to finish → detail). Seeded account `anna.r1@lifey.test` (the R1/R2 data plus the strength/run history
of `seed_r3.py`). Matrix covered: dark EN, light EN, dark HU ×1.3, light HU (Exercises tab), dark HU ×1.3 with **Remove animations** on (start Push day → PR → feedback → PR sheet), plus the new
template picker and the Templates / Exercises tabs.

**Matches**
- Sessions list: large "Workouts" title with the filter button, pill tabs, recommended card, the three week-summary tiles, "TODAY / EARLIER THIS WEEK / LAST WEEK" labels over grouped cards, session rows with the
  gold "🏆 2 PRs" chip, the heart-rate row in the heart colour, "In progress" chip, the "Start" FAB — dark and light.
- Live strength: subpage header ("Push day / 1 of 2 exercises", timer chip), rest hero (REST 1:28 in 44/800, +15 s and Skip 48 dp buttons, draining bar, "Next: Bench press · set 3 · 60 kg × 8"; overtime "+41:16"
  in the orange), exercise card (name 20/800, "Best 65 kg × 8 · e1RM 82.3 kg", SET · PREV. · KG · REPS header, 52 dp rows, 40 dp checks), done row in the green tint with ↑ and the gold trophy, the floating
  music button + "⚑ Finish workout" bar with the fade. The "Edit set" sheet is the DS sheet.
- PR sheet: 96 dp trophy in its halo, "2 new personal records", "Push day · 202 min · 1,040 kg volume", one grouped card of rows (trophy holder, exercise, "Heaviest set" / "Estimated 1RM", value 20/800,
  "+2.5 kg" in the improvement green), full-width Continue — the same layout as the canvas; with animations removed everything is in place from the first frame.
- Live cardio: header (activity chip, "Running", status line, settings button), "MOVING TIME" over the 104 px time, Distance and Pace cards with the edit glyph on the empty one, the 96 dp pause disc with its halo,
  the 64 dp slide track with the red stop knob; paused state greys the numbers and shows the manual-pause card, the full-width Resume and the slide bar. Detail: subpage header with the date, 52 px distance and the
  duration beside it, the metric strip (the seeded run has no zones/route/HR, so the zone card and route map are covered by widget tests only).
- Pickers and tabs: "Choose template" (subpage header, one grouped card of Empty workout / Cardio, "TEMPLATES" with the muscle-group chips), Templates and Exercises tabs as cards with icon holders and
  tinted chips, both themes; HU strings ("Edzések, Sablonok, Gyakorlatok, Válassz sablont, Következik: …, Legnehezebb szett, Becsült 1RM, Húzd a befejezéshez") fit at ×1.3 with nothing truncated.

**Deviations (intended)**
- No music button in the cardio header (no music lifecycle on that screen; the settings button sits in its place) — R3.8.
- The PR sheet is as tall as its content, the canvas frame stretches it to 77 % of the screen with Continue at the bottom — R3.7 (a sheet is not made taller than its rows).
- The canvas's zone-card footnote ("max HR of 190 bpm (220 − age)") is not used — the stored zones come from the watch against the profile's own maximum — R3.9.
- Exercises named twice ("Bench press" / "Bench Press") are seed data, not a bug.

**Bugs (fixed on `feature/mobile-redesign`)**
- The pinned title + tab bar hid the top of the tab under them: with the header collapsed the first rows were behind it, and Templates opened after a scrolled Sessions list was *empty* (the card was above the
  fold; only a pull-down revealed it). Same defect on Nutrition → **R3.fix-1**: title and tab bar are one absorbed sliver, each tab starts with an `OverlapInsetSliver` (Workouts and Nutrition; `header_test`).
- The RPE sheet's "Very easy / Maximal effort" anchors were packed on the left after the R3.11 overflow fix → **R3.fix-2** (`Expanded` at both ends; `sheets_layout_test` asserts both edges).
- Exercises / Templates lists used a 12 dp gutter under a 20 dp header and tab bar, and a hand-rolled section header → **R3.fix-3** (20 dp, `SectionLabel`).
- HU at ×1.3: the "SZETT" and "ELŐZŐ" column labels ran together and the previous-set hint touched the KG pill → **R3.fix-4** (label inset like its values, right inset on the hint; test).
- The cardio detail's date line was English in Hungarian ("Fri, Sep 25 · 18:01") → **R3.fix-5** (`LifeyFormat`; HU test).
- Found by the new sheet layout tests before the review: the GPS explainer and the post-workout sheet overflowed a 360 dp phone at large text, the box-score stepper overflowed it even at 100 %
  → fixed in R3.11.

**Not exercised on the emulator** (widget tests only): the zone card, route map and splits (the seeded run has none), the game / indoor-bike layouts, imperial units, offline.
