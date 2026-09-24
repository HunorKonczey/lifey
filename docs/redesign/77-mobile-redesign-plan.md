# 77 – Mobile Redesign (Design System v2)

Status: in progress — R0.1–R0.6 done
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

### R0.7 — Mobile UI: surface + text components

- Files in `shared/widgets/ds/`: `lifey_card.dart` (variants `card` r22/e1/pad 16, `hero`
  r30/e2/pad 20–22, `nested` surface-2 r = parent − padding), `section_label.dart` (12/16 caps
  +8 %, optional trailing "See all" text button), `tinted_chip.dart` (D-R0.4; 26 px tall, 10 px
  horizontal padding, 12/700), `delta_chip.dart` (signed change using `decrease`/`increase`;
  `record` 🏆 and `improvement` ↑ variants), `monogram_avatar.dart` (initials from first + last
  name, fallback first letter of e-mail; primary tint bg; 44 px default).
- **Verify:** gallery section per component, dark/light/HU/1.3; widget test that the monogram
  for "Anna Kovács" is "AK" and for no name falls back to the e-mail initial.

### R0.8 — Mobile UI: list rows, buttons, chips, inputs, dialogs (themes)

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

### R0.9 — Mobile UI: progress components

- Files in `shared/widgets/ds/`: `progress_ring.dart` (size, stroke, track `control`, round
  caps, animated fill 900 ms enter curve; over-goal state: full ring in `negative` +
  outer overflow arc), `metric_bar.dart` (7 px track r7, animated), `ratio_bar.dart` (stacked
  P/C/F segments with 2 px gaps), `metric_tile.dart` (icon + label, `MetricValue`, optional
  subline, optional 48 dp trailing action, optional `DeltaChip`; half-width and full-width).
- Stagger helper for "60 ms between macros".
- **Verify:** gallery with 0 %, 22 %, 100 %, 130 % states; widget test that a value above goal
  renders the over state and never a > 360° sweep.

### R0.10 — Mobile UI: `LifeyHeader` (large title) + `LifeySubpageHeader` + status-bar scrim

- Files: `shared/widgets/ds/lifey_header.dart` (sliver: optional overline (date) 13–14/600 text2,
  large title 30/800 −2 %, trailing 44 px round actions incl. unread dot and monogram avatar;
  collapses on scroll to a 20 px title row), `lifey_subpage_header.dart` (back button + title +
  optional subtitle/avatar + actions, same scrim), `status_bar_scrim.dart` (bg @ 88 % + blur
  pinned under the status bar on every screen).
- Coexists with `AdaptiveAppBar` — no screen migrates in this step except the gallery and
  `placeholder_screen.dart` (the smallest real user, as proof).
- **Verify:** placeholder screen: scroll a long list — nothing visible under the status bar;
  title collapses 30 → 20; TalkBack reads the title once.

### R0.11 — Mobile UI: bottom nav — active tab expands into a labelled pill

- Files: `shared/widgets/adaptive_bottom_nav.dart` (visuals rewritten, **public API kept** so
  `main_shell.dart` and `trainer_shell.dart` don't change), `nav_collapse_controller.dart`
  (unchanged logic), `shell_fab.dart` (e2, r14 → extended FAB "＋ Meal" style from the canvases).
- Spec: 68 px tall, r30, `float` + blur 24, e3; active tab = primary pill 48 px tall with icon +
  label (14/700), inactive = 48×48 icon in text2; on scroll-down it flattens to 56 px (no
  separate collapsed pill any more). Every tab keeps a semantics label even when its text is
  hidden. Uses `AppMotion` curves instead of `AppCurve.collapse`.
- **Verify:** widget test — semantics finds all 5 labels; HU "Áttekintés"/"Statisztika" fit at
  1.3; scroll collapses to 56 and back.

### R0.12 — Mobile UI: bottom sheet + empty and error states

- Files: `app_theme.dart` (`BottomSheetThemeData`: r30 top, surface-2, handle 36×4
  `#4A4E3E`-equivalent, backdrop 40 %), `shared/widgets/ds/lifey_sheet.dart`
  (`showLifeySheet` with title row + optional trailing metric text, safe-area aware),
  `empty_view.dart` (64 px icon in tint, title-s, body-s text2, primary + secondary action),
  `error_view.dart` (`cloud_off`, "AI features need a connection…"-style copy slot, Try again).
- Rewire the existing `showModalBottomSheet` helper calls only where it is a one-line change;
  others move with their iteration.
- **Verify:** gallery; open the existing Add water sheet — it already picks up the theme.

### R0.13 — Mobile UI: `LifeyBarChart`

- Files: `shared/widgets/charts/bar_chart.dart`, `test/shared/widgets/charts/bar_chart_test.dart`.
- Spec per D-R0.9. Pure helpers `yAxisTicks(max)` (0 / mid / nice max) and
  `averageExcludingPartialToday(points, now)` with unit tests.
- Bars: r = 6 top corners, inactive days in metric @ 45 %, today full colour, goal line dashed
  text3; weekday letters locale-aware (HU: H K Sze Cs P Szo V).
- **Verify:** unit tests (average excludes today; ticks for max 0, 7, 2 360, 13 000);
  gallery example with the canvas's "This week" data.

### R0.14 — Mobile UI: `TimeSeriesChart` upgrade

- Files: `shared/widgets/charts/time_series_chart.dart`.
- Add: 3-label Y axis, faint horizontal grid, gradient fill under the value line, optional
  dotted average series, emphasised last point, legend row ("Daily · 7-day average"), 3 X
  labels (start/mid/end, locale dates). Existing callers keep working with defaults off.
- **Verify:** existing chart tests green; gallery example matching canvas §4 chart.

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

### R1.1 — Mobile UI: logout moves to Settings (prerequisite)
- Files: `settings/presentation/settings_screen.dart`, `dashboard_screen.dart`.
- Add an "Account → Log out" row at the bottom of Settings with a confirmation dialog whose copy
  describes **today's** behaviour ("Your data on this phone is removed. Changes not yet synced
  will be lost." — R5.6 improves both behaviour and copy). Then remove the dashboard logout icon.
- **Verify:** log out from Settings; the dashboard has no logout; widget test for the dialog.

### R1.2 — Mobile UI: dashboard header + streak strip
- Files: `dashboard_screen.dart`, `streak_chip_row.dart`, `trainer_view_menu.dart` (entry via
  avatar menu), `lifey_format.dart` (`dayLabel`).
- Migrate the dashboard to `CustomScrollView` + `LifeyHeader`; greeting by time of day (existing
  strings if present, else new ARB keys); avatar via `MonogramAvatar`.
- **Verify:** HU date is fully Hungarian; unread dot appears with an unread message; trainers
  still reach the trainer view.

### R1.3 — Mobile UI: hero calorie card
- Files: new `dashboard/presentation/widgets/calorie_hero_card.dart`, remove the calorie/macro
  `StatCard` usages from `dashboard_screen.dart`.
- Protein "to go" chip uses `TintedChip` (protein); count-up + ring/bars animate from previous
  values; only the delta animates after logging a meal.
- **Verify:** widget tests — remaining vs over-budget states; HU "Szénhidrát 88 / 313 g" fits at
  1.3 (value wraps under the label instead of truncating).

### R1.4 — Mobile UI: water / steps / weight tiles + effective step goal
- Files: `water_card.dart` → restyled as `MetricTile` (or replaced; keep the file if other
  screens use it), `stat_card.dart` (delete if unused afterwards), `dashboard_screen.dart`,
  `features/settings/domain/user_settings.dart` (`effectiveDailyStepGoal` = setting ?? 10 000).
- Decision: one getter used by every consumer (tile, stats goal line, step-goal notification) so
  the displayed goal and the notified goal can't disagree — call out in the PR that users with
  no step goal now get 10 000 everywhere.
- **Verify:** "6 412 of 10 000" with no goal set; `+` on water opens the restyled sheet.

### R1.5 — Mobile UI: weekly calorie bar chart
- Files: `calorie_sparkline_card.dart` → replaced by a `LifeyBarChart` card (rename to
  `weekly_calories_card.dart`).
- **Verify:** the average ignores today; goal line at the calorie goal; HU weekday letters.

### R1.6 — Mobile UI: today's meals + recent workouts lists
- Files: `dashboard_screen.dart` (meal group + recent workout tiles → `ListGroup`/`ListRow`),
  "+ Meal" / "Photo" buttons (Photo = existing AI estimate entry, hidden when AI is unavailable
  exactly as today).
- **Verify:** "2 exercises" / "1 exercise" plural; the rating chip opens the existing feedback
  sheet.

### R1.7 — Mobile UI: add-water sheet + water sources screen
- Files: `water/presentation/widgets/add_water_sheet.dart` (canvas "Add water": 3 × 64 px
  tinted amount tiles 0.25 / 0.5 / 1.0 L, header "0.99 / 2.60 L" in water colour),
  `add_water_source_sheet.dart`, `water_sources_screen.dart` (`AppBar` → `LifeySubpageHeader`).
- **Verify:** add 0.25 L from the dashboard tile; tile count-up animates.

**R1 derived screens:** weekly recap (`streaks/presentation/weekly_recap_screen.dart`) → subpage
header + `LifeyCard`s + `MetricValue` (R1.8 if it doesn't fit in R1.2). Onboarding banner and
sponsorship card → `LifeyCard` with primary / clay accents.

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

### R2.1 — Mobile UI: nutrition header + tab bar
- `nutrition_screen.dart`: `LifeyHeader`, copy-day and scanner actions; `pill_tab_bar` restyled.
- **Verify:** copy-day sheet opens from the header; tabs switch with fade-through.

### R2.2 — Mobile UI: week strip replaces the Today / Week / All filter
- New `nutrition/presentation/widgets/week_strip.dart`; `meals_tab.dart`; the calendar icon
  keeps the old All view reachable.
- **Verify:** selecting a past day shows its meals; ring fill matches that day's kcal/goal; HU
  weekday abbreviations.

### R2.3 — Mobile UI: day budget card + meal list rows
- `meals_tab.dart`, new `widgets/day_budget_card.dart`; per-meal copy → long-press menu
  (`duplicate_meal_dialog` restyled, its 5 colour literals removed).
- **Verify:** 0-meal day shows the R0 empty state ("No meals yet today" + Add meal / Copy a
  day); long ingredient lists wrap to 2 lines.

### R2.4 — Mobile UI: meal edit screen layout
- `log_meal_screen.dart`: subpage header with Save, type chips, date-time row, food rows with ⋮,
  three action tiles.
- Keep the existing opt-in behaviour of the ingredient editor (hidden by default, opens on
  button press) — do not auto-expand it.
- **Verify:** edit and save an existing meal; delete a food via ⋮.

### R2.5 — Mobile UI: floating meal summary with "after this meal" preview
- `log_meal_screen.dart`, new `widgets/meal_summary_panel.dart`. "Today after this meal" =
  day's other meals + this meal's current draft (exclude the meal's saved version to avoid
  counting it twice — see §9 risk 3).
- **Verify:** unit test for the remaining-after-meal calculation for a new and an edited meal.

### R2.6 — Mobile UI: add-food sheet with quantity hero
- `widgets/add_food_sheet.dart` (and `add_meal_entry_sheet.dart` if it shares the layout);
  barcode icon inside the search field.
- **Verify:** stepper ± and chips update "+N kcal → M kcal left" live; barcode path unchanged.

### R2.7 — Mobile UI: recipes grid, AI entry card, filter chips
- `recipes_tab.dart`, `log_recipe_sheet.dart`; placeholder painter for image-less recipes.
- **Verify:** filters combine with search; offline → generate card shows the error state.

### R2.8 — Mobile UI: macros tab rings + 7-day ratio rows
- `macros_tab.dart`.
- **Verify:** rings over 100 % use the over state; ratio bars sum to 100 %.

**R2 derived screens (R2.9, may split):** `foods_tab.dart` (ListGroup rows, FAB),
`add_macros_sheet.dart`, `meal_estimate_sheet.dart`, `ai_credit_chip.dart` (TintedChip),
`barcode_scanner_screen.dart` (subpage header over camera, scrim), `create_recipe_screen.dart`,
`generated_recipe_screen.dart` ("Recipe proposal" — the canvas explicitly names it as a subpage
header user), `recipe_wizard_sheet.dart`.

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

### R3.1 — Mobile UI: workouts header + tabs + week summary
- `workouts_screen.dart`, `sessions_tab.dart`; filter moves to the header icon.
- **Verify:** filter still works; week summary matches the list for the current week (same week
  definition as streaks/recap — docs/37).

### R3.2 — Mobile data: PR count per session for the list
- `workouts/application/` new provider `sessionPrCountsProvider` (map sessionId → count) built
  from the existing PR domain; unit tests.
- **Verify:** a session that set a PR reports ≥ 1; editing an older session re-computes.

### R3.3 — Mobile UI: session list rows + day grouping
- `sessions_tab.dart` (row anatomy, grouping headers, PR chip, long-press delete).
- **Verify:** HU "(Egészségügyi adatok)" source line never truncates; delete still reachable.

### R3.4 — Mobile UI: live strength — rest hero card
- `log_session_screen.dart` (`_RestBanner` → new `widgets/rest_hero_card.dart`).
- **Verify:** +15 s and Skip behave as today; last-5-s colour change; reduced motion = no pulse.

### R3.5 — Mobile UI: live strength — exercise card + set rows
- `exercise_session_card.dart`, set row widgets in `log_session_screen.dart`.
- **Verify:** 52 dp rows, 40 dp check; done tint animation 250 ms + haptic; ↑ / 🏆 colours.
  Re-check the known empty-lines bug (memory: workout-session-empty-lines-bug) is not made worse.

### R3.6 — Mobile UI: live strength — floating music + finish bar
- `log_session_screen.dart`, `music_sticky_button.dart`.
- **Verify:** bar sits where the nav would be, respects safe area; finish uses the flag icon.

### R3.7 — Mobile UI: PR celebration sheet
- `workout_success_dialog.dart` → sheet per spec (removes 21 colour literals).
- **Verify:** 0 PRs → no trophy header (plain done state); multiple PR kinds listed; animation
  runs once.

### R3.8 — Mobile UI: live cardio screen
- `cardio_session_screen.dart` (hero moving time, metrics, HR zone row, pause, slide-to-finish
  with red stop knob). Large file: touch the layout build methods only.
- **Verify:** accidental stop impossible without a full slide; pause/resume unchanged; all
  sport variants (run, bike, hike, game — docs/cardio/60, 62) still render their extra metrics.

### R3.9 — Mobile UI: cardio detail + HR zone card
- `cardio_summary_screen.dart`, `hr_zone_panel.dart` (5 colour literals out), `route_painter.dart`
  colours from tokens.
- **Verify:** zone percentages sum to 100 (largest-remainder rounding, unit test); footnote in
  text3.

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

### R4.1 — Mobile UI: weight hero + goal band
- `weight_screen.dart`, `goal_progress_card.dart` → goal band.
- **Verify:** no goal set → band shows a "Set a goal" action instead of zeros.

### R4.2 — Mobile UI: weight chart + range switcher
- `weight_screen.dart` on the upgraded `TimeSeriesChart`; 7-day average from the docs/76 trend.
- **Verify:** single entry → one point, no average line; gaps don't draw fake lines.

### R4.3 — Mobile UI: weight history rows with signed chips
- `weight_screen.dart`.
- **Verify:** sign and colour follow the direction; U+2212 minus; 0.0 change has no sign.

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

*(no reviews yet)*
