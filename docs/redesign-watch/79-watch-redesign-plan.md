# 79 – Watch Redesign (Design System v2, watch extension)

Status: planned — not started (plan written 2026-10-02)
Scope: watch — Apple Watch app (`mobile/ios/LifeyWatch/`, SwiftUI, watchOS 10+) · Wear OS app
(`mobile/android/wear/`, Compose for Wear OS) · design system · docs. **No backend, no phone-app, no
watch↔phone protocol change.**
Depends on: the Claude Design output in this folder — `Lifey Watch Design System.dc.html` + four screen
canvases `Lifey Watch 1 … 4` — commissioned by [watch-redesign-prompt.md](watch-redesign-prompt.md); the
mobile v2 system it extends, [docs/redesign/77-mobile-redesign-plan.md](../redesign/77-mobile-redesign-plan.md)
(token decisions D-R0.2 – D-R0.4 reused for the dark values) and the web extension
[docs/redesign-web/78-web-redesign-plan.md](../redesign-web/78-web-redesign-plan.md) (same plan shape).
Supersedes the token values of [docs/watch/41-watch-design-prompt.md](../watch/41-watch-design-prompt.md) §2
and the visual specs of [docs/watch/42-watch-design-implementation-plan.md](../watch/42-watch-design-implementation-plan.md);
the behaviour specs of docs/watch/43, 44, 48, 49, 50 and docs/cardio/55, 60, 62 stay authoritative.
Branch: `feature/watch-redesign` (integration branch with the canvases and this plan); one long-lived PR
`feature/watch-redesign → main` collects every step commit of every iteration.

---

## 0. How to read this plan

The plan has **five main iterations — one per design file** — and **Apple Watch and Wear OS never share
an iteration**. The design-system canvas covers both platforms, so its iteration is split into two
platform sub-iterations that are planned, built and reviewed separately:

| Iteration | Platform | Design source (in `docs/redesign-watch/`) | What it delivers | Demo at the end |
|---|---|---|---|---|
| **X0a** | Apple Watch | `Lifey Watch Design System.dc.html` (D1–D4, 01–08) | v2 tokens in `LifeyColors.swift`, radius/spacing/size classes, Plus Jakarta Sans numerals, motion + haptic map, the 15 watch components, AOD primitives, DEBUG design gallery | Gallery on the 45 mm and 41 mm simulator; every existing screen already on the v2 palette |
| **X0w** | Wear OS | `Lifey Watch Design System.dc.html` (D1–D4, 01–08) | Same tokens value-identical in `LifeyColors.kt`, Wear Compose **Material 3**, scaffolding (TimeText, page indicator, TransformingLazyColumn, swipe-to-dismiss), PJS numerals, the 15 components, ambient primitives, JVM tests + token parity test, debug gallery, CI build | Gallery on the 227 dp and 192 dp emulators; every existing screen already on the v2 palette |
| **X1** | Apple Watch | `Lifey Watch 1 Apple Watch Strength.dc.html` (AW1.1–AW1.22) | Phone-driven strength workout: metric page with the hero rule, log page + stepper + status slot, rest + "Mehet!" rim, controls, exercise picker, effort, ending, summary | A full phone-driven strength session on the simulator |
| **X2** | Apple Watch | `Lifey Watch 2 Apple Watch Start Standalone Cardio.dc.html` (AW2.1–AW2.23, optional AW2.24–25) | Idle + picker + all types, standalone mode (mark, handoff tap, summary + sync), cardio (distance, machine, team sport field/bench, no HR), Health-denied, Always-On variants | Standalone quick strength → summary → sync; a run and a basketball game; wrist-down AOD |
| **X3** | Wear OS | `Lifey Watch 3 Wear OS Strength.dc.html` (W1.1–W1.16) | Phone-driven strength workout on the round screen: metric page, log page + EdgeButton stepper, rest edge ring + "Mehet!" ring, controls, exercise list, effort | A full phone-driven strength session on the emulator pair |
| **X4** | Wear OS | `Lifey Watch 4 Wear OS Start Standalone Cardio.dc.html` (W2.1–W2.19, optional W2.20–21) | Idle + picker + all types, "already running" error, standalone mode, cardio, ambient variants; Material 2 removed | Standalone quick strength → summary → sync; a run and a basketball game; ambient mode |

> **Id clash warning.** The Wear canvases (files 3 and 4) number their own frames `W1.x` and `W2.x`. In
> this plan `W1.5` always means *a frame of `Lifey Watch 3 Wear OS Strength.dc.html`*, never an iteration.
> Iterations are `X…` (R and W are taken by the mobile and web plans); steps are `X1.4`, `X0w.7`, ….

**Two tracks.** X0a → X1 → X2 is the Apple track; X0w → X3 → X4 is the Wear track. The tracks share
nothing but token values (guarded by a parity test, D-X0.2), so they can run in parallel. Apple steps
need a Mac session (xcodebuild + watchOS simulator); Wear steps run on the Windows machine with the
`Wear_OS_Large_Round` emulator. Recommended single-person order: **X0.0, X0a, X0w, X1, X3, X2, X4**
(each platform's strength flow lands before its secondary screens; X0w.3's parity test needs X0a.1).

**Smallest thing worth using:** X0a.1 / X0w.1 alone put every screen on the v2 palette (the token swap
recolours everything through the aliases, D-X0.1). The smallest *redesigned* slice is **X0a + X1** (or
**X0w + X3**): the strength workout — the flow people use most on the wrist — is fully on v2 for that
platform. Everything after can pause without leaving the app inconsistent-looking.

Every iteration has the same shape: **goal → design source (frames) → canvas notes = requirements →
current code → steps (prompt-sized) → iteration review (§4.1 / §4.2)**. **No iteration counts as done
until its review is written up in §12.** Steps are the unit of work: one platform, one session,
independently mergeable.

### 0.1 Opening the canvases

The canvases load `./support.js` (the canvas runtime), which this folder does not have yet — X0.0 copies
it. Serve the folder and open the files in a browser:

```bash
python -m http.server 5520 --directory docs/redesign-watch
```

The canvases are Hungarian. Every frame has a caption block: frame id, the PDF screenshot it answers
(`← AW-15`, `← W-14`; the PDFs `lifey-watch-jelenlegi-allapot.pdf` / `lifey-wear-jelenlegi-allapot.pdf`
are not in the repo), **"Változott"** (what changed), **"Miért"** (why), **"Megtartva"** (kept), the v2
element it carries over, and the exact SF Symbol / `Icons.Filled` names. **Every "Változott" and
"Megtartva" note is a requirement**; the steps below restate them as acceptance bullets. Items marked
**⚑** in a canvas are text-catalogue changes (§3, D-X0.13).

### 0.2 Frame index (the ids every step cites)

**Design System** (`Lifey Watch Design System.dc.html`)

| Frame | Shows |
|---|---|
| D1 · HERO | The hero is always the workout's unit: elapsed time (strength), distance / moving time / play time (cardio); HR is always level two in its own fixed slot; rest countdown takes the hero slot |
| D2 · BETŰ | Plus Jakarta Sans for numbers only (800 / 700, tabular); all text in the system font; PJS bound to text styles |
| D3 · „MEHET!” | Rim flash instead of a full green screen; timing 150 / 250 / 700 ms unchanged |
| D4 · HÁTTÉR | Screen background is true `#000`; the v2 dark tone ladder above it |
| 01 Tokenek | v1 → v2 colour table, text tiers with contrast on black, `ghost`, primary-only-for-controls, standalone mark, metric + role chips, status colours, cardio activity accents |
| 02 Tipográfia | Styles `hero / metric / value / title / body / label / aod-hero` with sizes for 45 / 41 mm and 227 / 192 dp, Apple text-style and Wear M3 mapping, rules (tabular, scale caps, units, caps, deliberate line breaks) |
| 03 Forma, térköz, méretosztályok | Radius 8 / 14 / 22 / 30 / pill / circle; spacing 2 / 4 / 6 / 8 / 12; margins 8 % (Apple) and 12 % + 20 % top/bottom (Wear); size-class table |
| 04 Komponensek | 15 components with states: 01 header chip · 02 metric reading · 03 set segment bar · 04 circle button · 05 status pill · 06 rest countdown · 07 "Mehet!" flash · 08 stepper · 09 list row · 10 compact chip / EdgeButton · 11 effort · 12 summary tile + sync row · 13 bench frame · 14 ghosted · 15 cardio field |
| 05 Oldalak és korona | Pager stays (3 pages strength, 2 cardio); crown does not page; back = watchOS nav button / Wear swipe-to-dismiss; TransformingLazyColumn, TimeText, ScrollIndicator |
| 06 Hiányzó pulzus | One missing-HR rule for both platforms and both workout types |
| 07 Mozgás és haptika | v2 durations and curves on the watch; haptic table (unchanged, mapped to visuals); reduced motion |
| 08 Always-On | What stays, how it looks, time without seconds, rest end time, burn-in and APIs, new keys |

**Apple Watch 1 — Strength** (`Lifey Watch 1 Apple Watch Strength.dc.html`, 45 mm 198×242 pt unless noted)

| Frame | PDF | Shows |
|---|---|---|
| AW1.1 | AW-15 | Metric page: hero time 48 › HR 28 › kcal 19, segment bar "2/4" |
| AW1.2 | AW-16 | Paused: header chip turns clay "SZÜNETELTETVE", stopped time in text-3 |
| AW1.3 | AW-17 | No HR + long exercise name (2-line wrap) |
| AW1.4 | — | Metric page, 41 mm |
| AW1.5 | AW-08 | Log page: primary "+1" circle, raised "Módosítás" circle with clay icon, labels under circles |
| AW1.6 | AW-09 | Logging pending: ghosted pair + "Naplózás…" pill |
| AW1.7 | AW-10 | Set logged (≈ 1.2 s): success-tint circle with check + "3/4 szett", "Naplózva" pill |
| AW1.8 | AW-11 | Logging failed (≈ 2.5 s): error pill with icon |
| AW1.9 | AW-12 | Phone unreachable: neutral pill |
| AW1.10 | AW-13 | Stepper · reps |
| AW1.11 | AW-14 | Stepper · weight (4-char value) |
| AW1.12 | AW-29 | Log page 41 mm with the "Gyakorlatok" compact chip |
| AW1.13 | AW-18 | Rest countdown: hero above an 8 pt white bar, "Következő" line, HR + kcal |
| AW1.14 | AW-19 | Last 5 s: hero + fill in the calories colour, 1 Hz pulse |
| AW1.15 | AW-20 | "Mehet!" rim flash |
| AW1.16 | — | Rest, 41 mm |
| AW1.17 | AW-21 · AW-38 | Controls: "Vége" (error tint) + "Szünet" (control) |
| AW1.18 | AW-22 | Paused controls: "Folytatás" primary + "Gyakorlatok" chip |
| AW1.19 | AW-23 | Exercise picker with the watchOS nav back button, segment bars, selected = control + check |
| AW1.20 | AW-24 | Effort (RPE): white number, 10-segment scale, real "Kihagyás" button |
| AW1.21 | AW-25 | Finish on the iPhone: left-aligned status pattern + indeterminate progress |
| AW1.22 | AW-26 | Summary (phone workout): check beside the title, full-width time tile, Health row |

**Apple Watch 2 — Start, standalone, cardio, errors, Always-On** (`Lifey Watch 2 Apple Watch Start Standalone Cardio.dc.html`)

| Frame | PDF | Shows |
|---|---|---|
| AW2.1 | AW-01 | Idle: leaf in a card holder, PJS "Lifey", full-width 48 pt start button |
| AW2.2 | AW-02 | Picker top: quick strength (icon holder 36), template rows with chevron, cardio rows with tinted icon circles |
| AW2.3 | AW-03 | Picker bottom: "Minden edzéstípus" with its own control-circle icon |
| AW2.4 | AW-04 | No synced plans yet: text-2 hint with sync icon |
| AW2.5 | AW-05 · AW-06 | All activity types: large title in content, collapsing into the nav bar |
| AW2.6 | AW-27 | Standalone quick strength: 26 pt mark, 2-line free-format summary |
| AW2.7 | AW-28 | Mark tapped: raised + sync glyph for 1.5 s, "Folytatás a telefonon…" pill (⚑ new key) |
| AW2.8 | AW-29 | Standalone log page with the "Gyakorlatok" chip |
| AW2.9 | AW-30 · AW-31 | Standalone summary waiting for sync: sync row under the title, above the fold |
| AW2.10 | AW-32 | Standalone summary synced: success tint, 250 ms switch in place |
| AW2.11 | AW-33 | Cardio distance (run): hero 48 white, HR as on strength, pace field row |
| AW2.12 | AW-34 | Cardio machine (indoor bike): moving time hero, two stacked field rows |
| AW2.13 | AW-35 | Team sport on the field: gross time in the HR row, "Padra" 46 pt |
| AW2.14 | AW-36 | Team sport on the bench: clay rim, stopped play time text-3, gross time clay |
| AW2.15 | AW-37 | Cardio without HR: same rule as AW1.3 |
| AW2.16 | — | Team sport, 41 mm (hero 40, button 44) |
| AW2.17 | AW-07 | Health access denied: left-aligned status pattern, control button |
| AW2.18 | — | Health denied, 41 mm |
| AW2.19 | AW-37 (hint) | HR explanation sheet |
| AW2.20 | new | AOD metric page |
| AW2.21 | new | AOD rest: "~1 p", "Mehet 9:42-kor" (⚑ `aod_minutes`, `aod_rest_until`) |
| AW2.22 | new | AOD cardio |
| AW2.23 | new | AOD bench |
| AW2.24 | optional | Smart Stack widget — **not in the base scope** |
| AW2.25 | optional | Complications — **not in the base scope** |

**Wear OS 1 — Strength** (`Lifey Watch 3 Wear OS Strength.dc.html`, round 227 dp unless noted)

| Frame | PDF | Shows |
|---|---|---|
| W1.1 | W-14 | Metric page: HR 16 → 28 sp with "bpm", narrow exercise block with segment bar, TimeText, HorizontalPageIndicator |
| W1.2 | W-15 | Paused: clay header chip |
| W1.3 | W-16 | HR permission missing: the HR slot is an M3 Button (two deliberate lines) → system permission prompt (⚑ key split) |
| W1.4 | — | Metric page, 192 dp |
| W1.5 | W-07 | Log page: primary "+1", raised "Módosítás", 78 dp circles |
| W1.6 | W-09 | Set logged: success tint; pill where the page dots sit |
| W1.7 | W-08 · W-10 · W-11 | Pending · failed (2-line pill) · phone unreachable |
| W1.8 | W-12 | Stepper · reps with EdgeButton confirm |
| W1.9 | W-13 | Stepper · weight, 192 dp (number 34 sp, ± 40 dp / 48 target) |
| W1.10 | W-17 | Rest: 6 dp edge ring (full-screen CircularProgressIndicator) |
| W1.11 | W-18 | Last 5 s: ring remainder + hero in calories colour, 1 Hz pulse |
| W1.12 | W-19 | "Mehet!" 9 dp primary ring |
| W1.13 | W-20 · W-34 | Controls: the same two circles as Apple; decorative exercise card gone |
| W1.14 | W-21 | Paused: "Folytatás" primary + secondary EdgeButton "Gyakorlatok" |
| W1.15 | W-22 | Exercise list: no corner arrow, M3 Button pills, selected = raised + check |
| W1.16 | W-23 | Effort: real "Kihagyás" button (40 dp), "Edzés lezárása" EdgeButton |

**Wear OS 2 — Start, error, standalone, cardio, ambient** (`Lifey Watch 4 Wear OS Start Standalone Cardio.dc.html`)

| Frame | PDF | Shows |
|---|---|---|
| W2.1 | W-01 | Idle: 52 dp M3 Button, Material "Eco" leaf, TimeText |
| W2.2 | W-02 · W-03 | Picker: every row an M3 Button pill, highlighted = raised + icon circle |
| W2.3 | W-05 | All activity types |
| W2.4 | W-06 | Error "another workout is running": calories-colour warning tint, "Rendben" EdgeButton |
| W2.5 | W-24 | Standalone quick strength: 24 dp mark (48 target), 2-line centred summary |
| W2.6 | W-25 | Mark tapped: raised background; template name ≤ 14 chars + ellipsis in the header |
| W2.7 | W-26 | Standalone log page: circles 74 dp + secondary EdgeButton |
| W2.8 | W-27 | Standalone summary waiting for sync |
| W2.9 | W-28 | Standalone summary synced |
| W2.10 | W-29 | Cardio distance: hero 48 sp white, HR 28 sp, boxless pace |
| W2.11 | W-30 | Cardio machine: two boxless values, labels wrap to 2 lines |
| W2.12 | W-31 | Team sport on the field: "Padra" EdgeButton |
| W2.13 | W-32 | Team sport on the bench: clay edge ring |
| W2.14 | W-33 | Cardio without HR (permission route if the cause is permission) |
| W2.15 | — | Team sport, 192 dp (hero 38, EdgeButton 46 dp) |
| W2.16 | W-33 (hint) | HR explanation as an M3 AlertDialog |
| W2.17 | new | Ambient metric page (±4 dp burn-in shift) |
| W2.18 | new | Ambient rest |
| W2.19 | new | Ambient bench |
| W2.20 | optional | Launcher Tile — **not in the base scope** |
| W2.21 | optional | Ongoing Activity — **not in the base scope** |

---

## 1. What we're building

1. **The v2 design system on both watches** — the mobile v2 dark tokens, radius scale, tone-ladder
   depth and motion, unchanged in value, **extended** where the wrist needs more: a true-black screen,
   size classes computed from the dial, Plus Jakarta Sans numerals bound to platform text styles,
   crown/rotary rules, Always-On, and 15 watch components with their states.
2. **One hierarchy for every active screen** (D1): the workout's unit is the hero (elapsed time on
   strength; distance / moving time / play time on cardio), HR is level two in a fixed slot, everything
   else level three. Same rule on both platforms and both workout types.
3. **Every watch screen restyled** — Apple Watch (38 states in the PDF) and Wear OS (34 states): idle,
   picker, all types, active strength (metrics, log, stepper, rest, "Mehet!", controls, exercise picker,
   effort), ending, summary, standalone mode, cardio (distance, machine, team sport), errors, permission.
4. **Fixes the design called out** (prompt "Amit mindenképp javíts"): v1 palette and radii; primary used as
   text and large fills (time, "+1", the full green "Mehet!"); no dominant number; four different
   missing-HR presentations; squeezed screens (team sport, no HR, paused, Wear stepper, Wear controls,
   standalone summary); tiny targets (effort back, standalone mark, "Kihagyás"); Wear corner arrows outside
   the round display, two component languages, faded ScalingLazyColumn edges, the meaningless
   "Gyakorlat" card on the cardio controls page; truncated Hungarian strings.
5. **Always-On** (new): AOD/ambient variants of the active screens (metrics, rest, cardio, bench) on both
   platforms.
6. **Wear Compose Material 3** replaces Material 2 (D-X0.8).
7. **Nothing functional changes** (prompt "Keretek"): phone-driven and standalone behaviour, sync states,
   rest-vibration timing, the set-logging flow (pending → confirmed / failed), the protocol payloads —
   only their appearance. Exceptions are UI-only and called out: Apple's tap feedback on the standalone
   mark (AW2.7), the Wear HR permission route on cardio (W2.14), tap-to-explain on the HR slot (AW2.19,
   W2.16), Wear back = swipe-to-dismiss (W1.15, W1.16).

**When nothing is "on":** there is no flag (D-X0.1). Before X0a.1 / X0w.1 the apps look as today; after
them every screen renders the v2 palette through the legacy aliases; after its iteration a screen also
has the new layout.

---

## 2. Current state (what already exists)

| Area | Where | Relevance |
|---|---|---|
| Apple tokens | `mobile/ios/LifeyWatch/Theme/LifeyColors.swift` (96 lines, v1: `bg #161611`, `primary #9DAE6B`, `heart #D97F7F`, `calories #E0915A`, `tertiary`, `negative`, `error*`, `ghostedOnSurface #46463E`, `standaloneIndicator #777264`, cardio accents) · `LifeyShapes.swift` (8 / 16 / 20 / 24) | Values replaced (X0a.1–2); legacy names aliased, deleted in X2.15 |
| Apple sizing | `DynamicSizing.swift` (`screenPaddingFraction 0.08`, log circle fractions, `compactScreenWidth 190`) | Folded into `WatchMetrics` (X0a.2), deleted X2.15 |
| Apple screens | `Views/ActiveWorkoutView.swift` (1 742 lines: `CardioActiveContent`, `CardioMetricsPage`, `DistanceMachineMetricsContent`, `GameMetricsContent`, `CardioHeartRateRow`, `CardioMetricBox`, `HeaderChip`, `MetricReading`, `HeroMetricRow`, `ExerciseCard`, `LogPage`, `AdjustPage`, `MetricsPage`, `ControlsPage`, `ExerciseListChip`, `ControlButton`, `ExerciseListView`, `ExerciseListRow`, `RestHeroView`, `GoFlashView`) · `EffortSelectorView` · `EndingView` · `HealthDeniedView` · `IdleView` · `StandalonePickerView` (`TemplateRow`, `CardioRow`, `AllTypesRow`, `AllActivityTypesView`) · `SummaryView` (`StatTile`) · `ContentView` | Restyled per iteration; presentational content split out first (X1.1) |
| Apple fonts | System only (95 `.font(` calls, 10 `minimumScaleFactor`); no `UIAppFonts` in `LifeyWatch/Info.plist` | PJS numerals bundled (X0a.3) |
| Apple project | `Runner.xcodeproj/project.pbxproj` uses classic groups (no file-system-synchronized groups): **every new Swift or font file needs four manual entries** (PBXFileReference, PBXBuildFile, the `LifeyWatch` group, the target's Sources/Resources phase) — see docs/watch/44 §S9 | Rule in §4; `plutil -lint` + duplicate-id check after each edit |
| Apple strings | `LifeyWatch/Localizable.xcstrings` (source `en`, `hu`; 447 entries) | New keys flagged ⚑ only (D-X0.13) |
| Apple AOD / reduced motion | Nothing (`isLuminanceReduced` 0×, `accessibilityReduceMotion` 0×) | New (X0a.4, X0a.10, X2.12–14) |
| Wear tokens | `ui/theme/LifeyColors.kt` (90, value-identical v1 + `primaryContainer`, `secondaryContainer`, `tertiaryContainer`) · `LifeyShapes.kt` · `LifeyTheme.kt` (Wear **Material 2** `Colors` + `Typography` with `tnum` on display/title) | Values replaced (X0w.1); M3 theme added (X0w.2); M2 removed (X4.16) |
| Wear sizing | `ui/DynamicSizing.kt` (`SCREEN_PADDING_FRACTION 0.08`, log circle fractions, `COMPACT_SCREEN_WIDTH 200.dp`) | Folded into `WatchMetrics` (X0w.5), deleted X4.16 |
| Wear screens | `ui/ActiveWorkoutScreen.kt` (2 574 lines: `CardioActiveScreen`, `CardioMetricsPage`, `DistanceMachineMetricsContent`, `GameMetricsContent`, `CardioHeartRateRow`, `CardioMetricBox`, `StrengthActiveWorkoutScreen`, `PageDots`, `LogPage`, `LogCircle`, `AdjustCircle`, `LogStatusLine`, `LogStatusPill`, `AdjustOverlay`, `AdjustStepButton`, `AdjustFieldSegment`, `MetricsOrRestPage`, `ControlsPage`, `ExerciseListChip`, `ExerciseListScreen`, `ExerciseListRow`, `HeaderChip`, `HeartRateReading`, `MetricReading`, `ExerciseCard`, `GoFlash`, `RestHero`) · `EffortSelectorScreen` · `ErrorScreen` · `IdleScreen` (`LeafMark` hand-drawn) · `StandalonePickerScreen` (`TemplateRow`, `CardioRow`, `AllTypesRow`, `AllActivityTypesScreen`) · `SummaryScreen` (`StatTile`, `SyncChip`) | Restyled per iteration; split into files first (X3.1) |
| Wear components | M2 `Chip` (23×), `ScalingLazyColumn` (8×), wear-foundation `HorizontalPager` with `rotaryScrollableBehavior`, no `TimeText`, no `PositionIndicator`, corner back arrows | Replaced by M3 (X0w.2, X0w.12) |
| Wear navigation | `MainActivity` switches on `SessionStateHolder.phase` (IDLE / ACTIVE / ERROR / SUMMARY); effort, exercise list, adjust, all-types are `remember { mutableStateOf(false) }` overlays; activity theme `Theme.DeviceDefault` (system swipe-to-dismiss on the activity) | Overlays get `SwipeToDismissBox` + `BackHandler` (X0w.12) |
| Wear haptics | `ExerciseService.kt`: rest end 400 ms one-shot, set confirmed 60·80·60 waveform, failed pattern, adjust `EFFECT_TICK` | Unchanged timing; only mapped (X0w.7) |
| Wear strings | `res/values/strings.xml` (HU default) + `res/values-en/strings.xml` (94 lines each) | New / split keys flagged ⚑ only |
| Wear ambient | None — the activity is not ambient-aware, the system shows the watch face on wrist-down | `AmbientLifecycleObserver` (X0w.13, X4.13) |
| Tests / CI | No Wear unit tests, no watch test target, no CI for either watch (`mobile-ci.yml` builds the Flutter app only) | Wear JVM tests + CI job (X0w.3–4); Apple: previews + gallery + xcodebuild (D-X0.11) |
| Emulators / sims | `Wear_OS_Large_Round` AVD exists (454 px @ 320 dpi = 227 dp); no 192 dp AVD; Apple builds were done on a Mac with `xcodebuild … -scheme Runner` (docs/watch/44) | 192 dp AVD created at the X0w review; Apple sims chosen at the X0a review |
| Fonts on disk | `mobile/assets/fonts/PlusJakartaSans-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf` (≈ 129 KB each) + `OFL.txt`; **no Light (300)** | Subset source for 700 / 800; 300 from upstream (D-X0.6) |
| Mobile v2 reference | `mobile/lib/core/theme/app_tokens.dart` (dark palette, metric colours), `contrast.dart`, `features/workouts/domain/activity_type.dart` (`activityTypeColor`) | Values and the contrast maths are ported, not re-invented |

---

## 3. Key design decisions

### D-X0.1 Retheme in place on the integration branch — no v1/v2 flag; legacy names alias until the last iteration

Same call as mobile D-R0.1 and web D-W0.1: the app is not released, a flag would double every view, and
because screens read colour through `LifeyColors`, a value swap gives unmigrated screens most of the new
look at once. New names are added, **old names stay as aliases re-pointed at the nearest v2 token**, each
iteration moves its own files, and the platform's last iteration deletes the aliases (Apple X2.15, Wear
X4.16). Rejected: a big-bang rename in X0 (an unreviewable diff across 4 000+ lines of views).

### D-X0.2 Token values: the v2 dark tables, `#000` screen, Swift ↔ Kotlin value-identical, guarded by a parity test

New names mirror the mobile `AppPalette` so a value can be looked up across all four clients:

| Token | Value | Replaces (alias target) | Use |
|---|---|---|---|
| `bg` | `#000000` | `trueBlack`, `bg #161611` | Screen (D4: the only deliberate deviation from mobile `#12130E`) |
| `card` | `#1A1C15` | `surface` | Card, list row, ghosted background |
| `nested` | `#22251C` | `container`, `primaryContainer` | Tile, neutral status pill |
| `control` | `#2C2F24` | `containerHigh` | Secondary button, standalone mark, selected row (Apple) |
| `raised` | `#36392D` | `containerHighest` | Raised circle ("Módosítás"), selected row (Wear), mark tapped |
| `outline` | `#45483B` | `outline` | **AOD only** (outlined bars and rings) |
| `text` / `text2` / `text3` | `#F2F1E6` / `#B6B5A5` / `#8F8F80` | `onSurface` / `onSurfaceVariant` / — | 19.4 / 10.3 / 6.3 : 1 on black; text3 min 13 pt |
| `ghost` | `#5E5F55` | `ghostedOnSurface` | **New**: disabled content (D-X0.10) |
| `primary` / `onPrimary` | `#B5C47C` / `#1A1F0A` | `primary`, `positive` / `onPrimary` | **Controls only** — never text, never a large fill |
| `heart` | `#E07F76` | `heart` | HR |
| `calories` | `#EC9A66` | `calories`, `negative` | kcal; also the **warning** role (rest last 5 s, "already running") |
| `success` | `#93C98C` | `tertiary`, `tertiaryContainer` | "Naplózva", synced, set-logged circle (the v2 leaf green; no protein metric on the watch, so no clash) |
| `error` | = `heart` `#E07F76` | `error`, `errorContainer` (as tint), `onErrorContainer` | v2 error state — **always with an icon**, so the shape separates it from HR |
| `clay` | `#C49A6C` | `secondary`, `secondaryContainer` (as tint) | Side path: paused, bench, "Módosítás" icon, stepper header |
| `standaloneMark` | glyph `text2` on `control` | `standaloneIndicator` | The standalone mode mark |

- **Tinted chip/pill rule** (v2 D-R0.4 dark): background = role @ 16 %, content = role @ 100 %. One helper
  (`Color.tint` / `LifeyColors.tint(_)`) builds it; no screen writes `.opacity(0.16)` itself.
- **Cardio activity accents** (icon + header-chip label only, never the hero) follow the mobile v2
  `activityTypeColor` mapping, **not** the canvas sample hexes (the canvas still shows the v1 values
  `#E0915A`, `#B08AC8`, … — the same "token rule over canvas sample" tie-break as web D-W0.5):
  run `calories #EC9A66` · walk `steps #C593CC` · hike `#6E9A6A` (mobile `tertiary`, unchanged) ·
  cycling `clay #C49A6C` · indoor bike `carbs #E2BE62` · basketball `fat #A3A1DB` · football
  `water #74B6D6` · other `text2`.
- Removed with the aliases: v1 `tertiary`, `negative`, `errorContainer`, `onError`, `onErrorContainer`
  (canvas 01 note).
- **Parity guard:** a Wear JVM test (X0w.3) parses `mobile/ios/LifeyWatch/Theme/LifeyColors.swift` and
  asserts every token name ↔ hex equals `LifeyColors.kt`. Rejected: a shared generated token file — it
  would need a codegen step in two build systems for ~25 constants.

### D-X0.3 One hierarchy: hero = the workout's unit; HR is level two in a fixed slot

From D1. Strength: elapsed time is the hero (it never disappears and always ticks — a stable anchor);
HR is level two, in the heart colour, **in the same place and size on strength and cardio, on both
platforms**; kcal is level three; the current set lives on the log page and in the bottom segment bar.
Cardio: distance (distance-based), moving time (machine) or play time (team sport) is the hero, **white**
(the accent moves to the header chip — the old 36 pt accent-coloured hero lost contrast with yellow and
lilac accents). During rest the countdown takes the hero slot. Rejected: HR as hero (it can drop out —
a hero must not vanish) and the current set as hero (that is the log page's job).

### D-X0.4 Missing heart rate: one rule everywhere (DS 06)

Today there are four presentations (Apple strength: row disappears; Apple cardio: "—" + 2-line
explanation; Wear strength: broken heart "--" + permission chip; Wear cardio: "—" + explanation). New
rule, implemented once per platform as `HeartRateSlot`:
1. The slot always keeps its place and size; the layout never jumps.
2. Content: ghost heart + ghost "—" + text3 "nincs pulzus" + ⓘ. No error tone.
3. The explanation ("Lazább a szíj? A mérés fut tovább, az idő pontos.") opens on tap — Apple `.sheet`
   (AW2.19), Wear M3 `AlertDialog` with "Rendben" (W2.16) — and takes no space on the page.
4. Wear only, when the cause is a missing permission: the slot itself is an M3 Button (44 dp) whose tap
   opens the system permission prompt, with two deliberate lines "Pulzusmérés ki" / "érzékelők
   engedélyezése" (W1.3); also on cardio (W2.14 — a new route to the *existing* permission request).
   Apple has no permission API on the watch: tap = the same explanation sheet.
The *cause* detection (no sample yet vs. permission denied) is existing state; the slot only reads it.

### D-X0.5 Size classes: the canvas table is authoritative at the reference sizes; ratios elsewhere; minimums never undercut

One value object per platform, `WatchMetrics(width:)`, computed once at the root from the real dial width
and passed down (SwiftUI `EnvironmentValues.watchMetrics`, Compose `LocalWatchMetrics`):

| Value | AW regular (45 mm, 198 pt) | AW compact (41 mm, 176 pt) | Wear regular (227 dp) | Wear compact (192 dp) | Ratio for other widths |
|---|---|---|---|---|---|
| hero | 48 | 42 | 48 | 40 | 0.24 w (Apple) / 0.21 w (Wear) |
| hero, dense screens (team sport) | 48 | 40 | 48 | 38 | hero − 2 on compact |
| metric | 28 | 25 | 28 | 24 | 0.14 w / 0.12 w |
| value | 19 | 17 | 18 | 16 | — (from the type table) |
| circle button | 78 | 70 | 78 (74 with a secondary EdgeButton, W2.7) | 66 | 0.40 w / 0.34 w |
| button / row height | 48 | 44 | 52 | 48 | — |
| min touch target | 44 | 44 | 48 | 48 | never undercut |
| side margin | 8 % w | 8 % w (≈ 14) | 12 % w; top/bottom 20 % | same | — |

- Class boundary: Apple `< 190 pt` = compact (40 mm SE 162 pt and the 42 mm Series 10/11 187 pt are compact;
  44/45/46/49 mm regular), Wear `< 200 dp` = compact — the existing thresholds.
- Wear chord rule (DS 03): anything in the top or bottom 20 % of the round dial is at most one short line
  or an EdgeButton; `WatchMetrics.chordWidth(y)` gives the usable width at a vertical position.
- Rejected: fixed pt/dp per screen (breaks between the reference sizes — the reason `DynamicSizing` exists).

### D-X0.6 Plus Jakarta Sans for numerals only; three subset weights bundled; text stays system

From D2: hero, metric, value and tile numbers are PJS **800 / 700** with tabular figures — that carries
the Lifey identity; every word (titles, labels, units, buttons) stays in the system font (SF Pro / Wear
system) for legibility, localisation and Dynamic Type. AOD numbers are PJS **300** (canvas 02 `aod-hero`).
- **Subsetting:** the full TTFs are ≈ 129 KB each; the canvas budgets ≈ 90 KB for the family. The three
  weights are subset (fonttools `pyftsubset`, one-off, command recorded in the README) to the glyphs
  numerals need: `0-9 : . , + - − – — / ~ % ×` space, NBSP and NNBSP (U+00A0, U+202F) — units are system
  font — plus `L i f e y` in the ExtraBold subset only, for the idle wordmark (AW2.1, W2.1). ExtraBold and Bold come from `mobile/assets/fonts/`; **Light (300) is not in the
  repo** and is taken from the upstream OFL release (tokotype/PlusJakartaSans) — fetching it needs the
  user's OK at X0a.3. `OFL.txt` ships next to the files on both platforms.
- The same three subset files are committed twice (Apple bundle, Wear `res/font/`) and a JVM test asserts
  they are byte-identical and cover the glyph set (risk §9.2).
- Rejected: PJS for all text (worse at 11–13 pt on a watch, no Dynamic Type benefit, bigger bundle) and
  system-only (loses the identity the prompt asked to carry over).

### D-X0.7 Type styles bound to the platform scale; numbers capped at 115 %, text at 135 %

| Style | Size 45 / 41 mm · 227 / 192 dp | Face | Apple binding | Wear binding (M3 slot) |
|---|---|---|---|---|
| `hero` | 48 / 42 · 48 / 40 | PJS 800, −2 % | `Font.custom(_, size:, relativeTo: .largeTitle)` | `numeralLarge` |
| `metric` | 28 / 25 · 28 / 24 | PJS 800 | `relativeTo: .title2` | `numeralSmall` |
| `value` | 19 / 17 · 18 / 16 | PJS 700 | `relativeTo: .headline` | `titleMedium` (PJS copy) |
| `title` | 17 / 16 · 16 / 15 | system 600 | `.headline` | `titleMedium` |
| `body` | 15 / 14 · 15 / 14 | system 500 | `.body` / `.footnote` | `bodyMedium` |
| `label` | 12 / 11 · 12 / 11 | system 700, +6 %, CAPS | `.caption2` | `labelSmall` |
| `aod-hero` | 48 / 42 | PJS 300 | AOD variant of `hero` | AOD variant of `numeralLarge` |

Rules (canvas 02): every ticking number tabular (`monospacedDigit()` / `fontFeatureSettings = "tnum"`);
**hero and metric grow to at most 115 %, body and label to 135 %**, rows wrap instead of shrinking
(Apple: `@ScaledMetric(relativeTo:)` clamped with `min(scaled, base × cap)`; Wear: sp × `min(fontScale,
cap) / fontScale`); units in the system font at label size, `text2` (Wear gains "bpm": "♥ 128" → "♥ 128
bpm"); CAPS only in the header chip and cardio field labels; phone-supplied cardio labels (KADENCIA, ÁTLAG
TELJESÍTMÉNY) are variable length: one line, wrap to two, never scale below 80 %; status titles max two
lines, button labels max two lines, chips one line — where that fails, the structure changes (icon beside
the title, not above).

### D-X0.8 Wear moves to Compose Material 3; M2 and M3 coexist until X4

The design is drawn in Wear M3 components that M2 lacks: `EdgeButton`, `TransformingLazyColumn` +
transformation spec, `ScreenScaffold`/`AppScaffold` with `TimeText` and `ScrollIndicator`,
`HorizontalPageIndicator`, M3 `Button`/`AlertDialog`, the M3 typography slots `numeralLarge/Small`.
Add `androidx.wear.compose:compose-material3` on the **same version line as `compose-foundation`**
(1.6.2 today; confirm the artifact on Google Maven in X0w.2). Justification for the "no new frameworks"
rule: it is the successor of a library already in use, from the same family, and M2 is deleted at the end
(X4.16) — net zero libraries. `LifeyTheme` provides both themes from the same tokens while screens migrate.
Rejected: building EdgeButton/TransformingLazyColumn look-alikes on M2 (re-implementing platform
behaviour such as the curved bottom edge and rotary handling).

### D-X0.9 Page structure and the crown

Pager stays: strength 3 pages (log · **metrics = default** · controls), cardio 2 (metrics · controls);
rest replaces the metric page in place. Page dots: Apple's system ones; Wear M3 `HorizontalPageIndicator`
on the bottom arc (hidden while an EdgeButton or status pill is shown there). **The crown / rotary does
not page** (no accidental paging with a sweaty hand): every active page fits without scrolling, so the
crown does nothing there; it steps values on the stepper and the effort selector (one detent = one step;
Wear ≈ 24 dp scroll + `EFFECT_TICK`, unchanged) and scrolls lists. Back: Apple = the watchOS 10
navigation bar back button (32 pt visible, 44 target, top left); **Wear has no back arrow** — swipe-to-
dismiss and the hardware back button (on effort that means "back to the workout", as the corner arrow
did). Wear lists use `TransformingLazyColumn` (D-X0.12) with `TimeText` on top and `ScrollIndicator` on
the right whenever the page scrolls.

### D-X0.10 Ghosted is a token pair, not opacity

Disabled = background `card` + content `ghost` (canvas 04/14). Today Apple uses `.opacity(0.75)` and
`ghostedOnSurface #46463E`; on black, opacity makes primary look "dirty green" and its contrast is
unpredictable. One modifier per platform (`.ghosted(_:)` / `Modifier.ghosted`) applies the pair.

### D-X0.11 Verification: debug design gallery + previews + JVM tests on Wear; no screenshot goldens

- **Wear:** a debug-only `DesignGalleryActivity` (`src/debug/`, exported only in debug builds) lists every
  component in every state and **every canvas frame of X3/X4 as a fixture state** (no phone needed), so
  emulator screenshots of a frame are one `adb shell am start` away; `@WearPreviewDevices` /
  `@WearPreviewFontScales` previews per component (`androidx.wear.compose:compose-ui-tooling`, debug only);
  JVM unit tests (`junit`, `testImplementation` only) for every pure function: metrics table, contrast,
  token parity, font coverage, AOD formatting, status priority, HR-slot derivation, rest thresholds.
- **Apple:** a `#if DEBUG` `DesignGalleryView` (long-press on the idle leaf in debug builds) with the same
  component list and AW frame fixtures; `#Preview`s for each component at 45 and 41 mm; `xcodebuild`
  must succeed. No XCTest target is added (a watch test target is a large pbxproj change for little pure
  logic; the Wear JVM tests cover the shared rules, and the Apple formulas are kept line-for-line equal).
- **No screenshot goldens** (fonts render differently on CI and dev machines — same reason as D-R0.11 /
  D-W0.12). Visual comparison is the iteration review (§4.1 / §4.2).
- Prerequisite for fixtures: each screen's **presentational content takes a plain model**, separate from
  `WorkoutManager` / `SessionStateHolder` (X1.1, X3.1).

### D-X0.12 Wear lists: TransformingLazyColumn at ≤ 12 % shrink and ≥ 80 % opacity

The DS frame 05 says edge rows shrink to 85 % and fade to no less than 70 %; the later screen frames (W1.15,
W2.2) say ≤ 88 % scale and ≥ 80 % opacity. The screen frames win (they are more specific and more legible,
which is the stated aim). One `lifeyTransformationSpec()` holds the numbers.

### D-X0.13 Text catalogue: only the flagged changes

Existing keys keep their text. New or split keys, each in both languages (iOS `Localizable.xcstrings`
`en` + `hu`; Wear `values/strings.xml` HU + `values-en/strings.xml` EN):

| Key | Platform | HU | EN | Frame |
|---|---|---|---|---|
| `active_heart_rate_denied_title` | Wear | Pulzusmérés ki | Heart rate off | W1.3 (split of `active_heart_rate_denied_chip`, which is deleted) |
| `active_heart_rate_denied_action` | Wear | érzékelők engedélyezése | allow sensors | W1.3 |
| `aod_minutes` | both | %d p | %d min | AW2.20, W2.17 |
| `aod_hours_minutes` | both | %1$d ó %2$02d p | %1$d h %2$02d min | DS 08 ("1 ó 05 p") — **deviation:** the canvas names only `aod_minutes`, but one format string cannot express both forms |
| `aod_rest_until` | both | Mehet %s-kor | Go at %s | AW2.21, W2.18 (HU "-kor" is invariant, no vowel harmony) |
| `standalone_handoff_pending` | Apple | Folytatás a telefonon… | Continuing on the phone… | AW2.7 |
| heart-rate unit (`active_heart_rate_unit`) | Wear, if absent | bpm | bpm | W1.1 |

Cardio field labels and activity names stay phone-supplied and pre-localised (unchanged); the design
treats them as variable-length text.

### D-X0.14 Motion and haptics: v2 timings on the watch; haptics unchanged and centralised

| Motion | Spec (canvas 07) |
|---|---|
| Tap | 100 ms, circle scales to 0.96, one tone step up; the 300 ms double-tap guard stays |
| Set logged | 250 ms: circle primary → success tint, check draws, the new segment turns success; back after 1.2 s |
| Count-up | 600 ms, **summary tiles only**; ticking numbers never animate, they swap |
| Fill | Rest bar / ring drains linearly once per second; last-5 s colour change 250 ms |
| Page change | System pager / navigation; stepper and rest cross-fade 300 ms with the metric page |
| "Mehet!" | 150 ms in · 250 ms hold · 700 ms out (unchanged timing) |
| "Edzés mentve" | Check pops once, tiles enter with 60 ms stagger |
| Curves | standard `cubic(0.2, 0, 0, 1)`, enter `cubic(0.05, 0.7, 0.1, 1)`, exit `cubic(0.3, 0, 0.8, 0.15)` |
| Reduced motion | Apple `accessibilityReduceMotion`, Wear animator scale 0: all 0 ms, "Mehet!" rim static for 1.1 s, last-5 s pulse off, indeterminate progress stands still |

Haptics keep their events and timing; the canvas only maps them to visuals: set logged = Apple `.success`
/ Wear 60·80·60 ms ↔ circle → success; logging failed = `.failure` / failure pattern ↔ error pill 2.5 s;
rest over = `.notification` / 400 ms (service) ↔ "Mehet!" rim; stepper ± = `.click` (crown: system) /
`EFFECT_TICK` ↔ number swap; limit reached = system ↔ button ghosted. **Rest vibration stays timed from the
watch's own clock (Apple `WorkoutManager`, Wear `ExerciseService`), independent of what is on screen.**

### D-X0.15 Always-On: active screens only, minute resolution, nothing filled

Canvas 08: only the active screens get an AOD variant (metrics, rest, cardio, bench). Kept: hero, HR,
header chip, bench frame. Dropped: buttons, pills, segment bar, kcal and cards. Pure black, no filled
surface; numbers PJS 300 in `text2`; metric colours at 60 %; outlined icons (SF non-`.fill`, Material
`Icons.Outlined`); lit pixels < 10 %. Time without seconds: "12:34" → "12 p" (≥ 1 h "1 ó 05 p"); rest
shows the **end time** ("Mehet 14:36-kor", computed from the existing `restEndsAtEpochMs` in the local
time zone) and "~1 p" rounded **up**; updates once a minute. The stopped play time on the bench keeps its
seconds (it does not change). Back to full display within 300 ms on wrist-raise.
APIs: Apple `@Environment(\.isLuminanceReduced)` + `TimelineView(.everyMinute)`; Wear
`AmbientLifecycleObserver` (`androidx.wear:wear` — new dependency, required for any ambient support) with a
±4 dp per-minute burn-in shift. Rejected: an AOD rendering of every screen (the picker, summary and errors
are not looked at with the wrist down).

### D-X0.16 Optional platform surfaces are separate, gated steps

Smart Stack widget + complications (AW2.24–25) need a new WidgetKit watch extension target; the Tile and
Ongoing Activity (W2.20–21) need a `TileService` and the ongoing-notification binding. They are marked
optional by the canvas, need no new protocol data, and are planned as steps **X2.o1–o2** and **X4.o1–o2**
that start only on an explicit go-ahead (§10 Q1, Q2).

---

## 4. Shared rules for every step

- **One platform per step.** A step touches either `mobile/ios/LifeyWatch/` (+ `Runner.xcodeproj`) or
  `mobile/android/wear/` (+ the CI job), never both. Docs-only steps touch only `docs/`.
- **No hard-coded hex, radius, font size or pt/dp size** in files a step touches — `LifeyColors`,
  `LifeyShapes`, `WatchMetrics`, the type styles. A step that touches a file also moves that file off the
  legacy alias names (D-X0.1).
- **No hard-coded strings**; only the ⚑ keys of D-X0.13 are added. HU is the length yardstick.
- **Behaviour identical** unless the step says otherwise (§1.7 lists the UI-only exceptions). Never move a
  haptic call to a place that depends on screen visibility (D-X0.14).
- **Apple project hygiene:** a new Swift or font file gets all four `project.pbxproj` entries; after the
  edit `plutil -lint mobile/ios/Runner.xcodeproj/project.pbxproj` and a duplicate-object-id check. Prefer
  adding to existing files over new files unless the file split is the point of the step.
- **Per-step checklist — Apple** (Mac session): `xcodebuild -workspace mobile/ios/Runner.xcworkspace
  -scheme Runner -destination 'generic/platform=watchOS Simulator' -configuration Debug build
  CODE_SIGNING_ALLOWED=NO` (or the `LifeyWatch` scheme against a booted simulator) → BUILD SUCCEEDED, no
  new warnings in touched files · the step's frames checked in the DEBUG gallery or the previews on the
  **45 mm and 41 mm** simulator, HU and EN.
- **Per-step checklist — Wear** (from `mobile/android/`): `./gradlew :wear:assembleDebug
  :wear:testDebugUnitTest` green (once X0w.3 lands) · the step's frames checked on the
  `Wear_OS_Large_Round` emulator (and the 192 dp one once it exists) via the gallery, HU and EN.
- **Every step ends with one commit, pushed** to `feature/watch-redesign` (so it lands on the open redesign
  PR), message `Watch iOS: <what> (redesign X<n>.<m>)` or `Watch Wear: <what> (redesign X<n>.<m>)`, after
  the checklist passes; the step heading gets a ✅ in this doc in the same commit, plus a short *As built*
  note when the result deviates from the spec.

### 4.1 Iteration-end review — Apple Watch (X0a, X1, X2)

After the last step of the iteration, a thorough check in a running app that every new element looks
and behaves as the canvas says.

**Setup (once, reused):** a Mac session with Xcode; watchOS simulators **Apple Watch 45 mm and 41 mm**
(Series 7–9 runtimes; if the installed Xcode only offers 42 / 46 mm, use those and note the size in the
log — 42 mm is compact, 46 mm regular), plus one 49 mm Ultra and one 40 mm SE pass for the class edges;
the paired iPhone simulator running the Flutter app against a local backend (`RUNNING.md`) for the
phone-driven flows; a seeded account with templates ("Push nap", "Pull nap"), cardio types and a past
standalone session.

**Procedure:**
1. Walk every screen the iteration touched in this matrix: **45 mm and 41 mm · HU and EN** (scheme
   `-AppleLanguages (hu)` / `(en)`), plus one pass at the **largest non-accessibility text size**
   (`xcrun simctl ui booted content_size extra-extra-extra-large`) and one with **Reduce Motion** on.
2. For every canvas frame of the iteration (§0.2) take a simulator screenshot (`xcrun simctl io booted
   screenshot`) of the same state — gallery fixture **and** the real flow — and put it next to the frame.
3. Check item by item: hero / metric / value sizes per D-X0.5; colour roles (primary only on controls,
   metric colours only on their metric, clay only for side paths, error always with an icon); radii and
   margins; nothing scrolls on an active page; HU strings never truncated, deliberate two-line breaks as
   drawn; tabular numbers don't jitter; every "Változott / Megtartva" note of each frame; touch targets
   ≥ 44 pt (Accessibility Inspector); haptics fire at the D-X0.14 moments; motion timings and the reduced-
   motion end states; AOD frames (X2) by locking the simulator with Always On enabled.
4. Exercise the **flows**: the iteration's demo flow from the §0 table, including the failure paths
   (phone unreachable, logging failed, health denied).
5. Write the result into **§12 Review log**: date, Xcode / watchOS versions, simulators, *Matches*,
   *Deviations (intended)* with decision ids, *Bugs*. Every bug becomes a step `X<n>.fix-<k>` (own commit)
   and the affected part is re-checked.
6. Send the side-by-side screenshots to the user. Screenshots are **not committed**; the log is the record.

### 4.2 Iteration-end review — Wear OS (X0w, X3, X4)

**Setup (once, reused):** AVDs `Wear_OS_Large_Round` (227 dp, exists) and a **192 dp small round** AVD
(Wear OS Small Round profile, 384 × 384 px @ 320 dpi — created at the X0w review), started with
`"$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd <name>`; paired with the `Pixel_10` phone
emulator running the Flutter app for phone-driven flows (as in docs/watch/40 §11); synthetic sensors via
`adb` as before.

**Procedure:**
1. Walk every screen the iteration touched: **227 dp and 192 dp · HU and EN** (`adb shell cmd locale
   set-app-locales com.khunor.lifey --locales hu` / `en`), plus one pass at **font scale 1.3**
   (`adb shell settings put system font_scale 1.3`) and one with animations off (`adb shell settings put
   global animator_duration_scale 0`). Ambient (X4): enable Always-on display on the emulator and send it
   to ambient (`adb shell input keyevent KEYCODE_SLEEP`; confirm the exact trigger at the first X4 review
   and record it here).
2. For every canvas frame take an emulator screenshot (`adb exec-out screencap -p > frame.png`) of the same
   state — gallery fixture (`adb shell am start -n com.khunor.lifey/.debug.DesignGalleryActivity --es
   frame W1.5`) **and** the real flow — next to the frame.
3. Check item by item as in §4.1.3, plus the round-specific items: nothing outside the circle, the 20 %
   top/bottom chord rule, TimeText never overlapped, EdgeButton hugging the bottom arc, page indicator
   hidden under an EdgeButton/pill, list edge rows ≥ 88 % scale and ≥ 80 % opacity, swipe-to-dismiss on
   every overlay (and **not** closing the activity mid-workout), rotary steps the stepper/effort and does
   not page, touch targets ≥ 48 dp.
4. Exercise the flows (demo flow from §0, failure paths, permission denial and grant).
5. Log in §12, bugs → `X<n>.fix-<k>`.
6. Send the side-by-side screenshots to the user; not committed.

**An iteration is done when its review log entry has no open bug.**

### 4.3 Cloud-session review (no Xcode / simulator / emulator)

The cloud sandbox has no Xcode, Android SDK or KVM, so builds and simulator screenshots are not possible
there. The review is then: (1) an automated token check — every hex in `LifeyColors.swift` against the
design-system canvas; (2) the canvases rendered headless with Playwright (React/Babel served from npm copies
via request routing, Google Fonts blocked, so icons show as names); (3) an HTML reconstruction of the
gallery built from the Swift token file and the `WatchMetrics` formulas, compared by eye with the canvas
frames. This does **not** replace a real build and simulator pass; the first Mac session must run the
§4.1 procedure and the `xcodebuild` checklist before the PR merges.

---

## X0.0 — Docs: make the canvases openable ✅

- Files: `docs/redesign-watch/support.js` (copy of the newest canvas runtime, `docs/redesign-web/support.js`;
  if a canvas does not render with it, try `docs/redesign/support.js` and note which one works),
  `docs/redesign-watch/README.md` (reading-order table + iteration table, shape of
  `docs/redesign-web/README.md`), a pointer from `docs/watch/41-watch-design-prompt.md` §2 header to this
  plan ("token values superseded by 79 D-X0.2").
- The DS canvas links `Lifey Design System.dc.html` (the mobile canvas lives in `../redesign/`) — noted in
  the README; the canvas files are not edited.
- **Verify:** `python -m http.server 5520 --directory docs/redesign-watch`; all five canvases render every
  frame and the cross-links between them work.
- *As built:* `docs/redesign-web/support.js` works. The runtime pulls React/Babel from unpkg; in the sandbox
  they are served from npm copies via Playwright request routing (see §4.3). The DS canvas rendered headless.

---

## X0a — Foundation, Apple Watch · `Lifey Watch Design System.dc.html`

**Goal:** everything Apple-wide that X1 and X2 build on. After X0a every Apple Watch screen renders the v2
palette, and every component the AW canvases use exists in the DEBUG gallery at 45 and 41 mm.

**Design source:** D1–D4, frames 01–08 (§0.2); the mobile `docs/redesign/Lifey Design System.dc.html` for
the unchanged values.

**Principles every later Apple step is held to** (DS header): one number per screen; black AMOLED with the
v2 tone ladder above it; finger-sized targets; primary is a control colour; Hungarian is the yardstick.

### X0a.1 — Watch iOS: v2 colour tokens + legacy aliases ✅
- Files: `mobile/ios/LifeyWatch/Theme/LifeyColors.swift`.
- Add the D-X0.2 names and values, the cardio accents per the mobile v2 mapping, a `tint(_:)` helper (16 %).
  Re-point every legacy name at its alias target (`trueBlack`/`bg` → `bg`, `surface` → `card`, `container`
  → `nested`, `containerHigh` → `control`, `containerHighest` → `raised`, `onSurface` → `text`,
  `onSurfaceVariant` → `text2`, `tertiary` → `success`, `negative` → `calories`, `positive` → `primary`,
  `ghostedOnSurface` → `ghost`, `standaloneIndicator` → `text2`, `error` → `error`, `errorContainer` →
  `error.tint`, `onErrorContainer` → `error`, `secondary` → `clay`), each marked
  `@available(*, deprecated, renamed:)` so remaining usages are visible as warnings to burn down.
- Rewrite the enum doc comment: source = this plan D-X0.2 (the old canvas-vs-prompt `heart` note is obsolete).
- **Verify:** build; idle, picker and an active page in the simulator show the v2 olive, `#000` screen,
  new heart/calories.
- *As built:* no Xcode in the cloud session — verified by the screenshot comparison of §4.3, not a build.
  `Color.tint` is `lifeyTint` (avoids clashing with SwiftUI's `.tint` style); added `cardioHiking`
  (`#6E9A6A`) because `tertiary` now aliases `success`; hiking in `cardioActivityTint` uses it.

### X0a.2 — Watch iOS: radius, spacing, `WatchMetrics` size classes ✅
- Files: `Theme/LifeyShapes.swift` (tag 8, control 14, card 22, hero 30; old `chip/button/card/cardLarge`
  aliased to 8/14/22/30), new `Theme/LifeySpacing.swift` (2 / 4 / 6 / 8 / 12), new
  `Theme/WatchMetrics.swift` (D-X0.5 table + ratios + minimums, `isCompact`, `EnvironmentValues.watchMetrics`,
  a root `GeometryReader` in `ContentView` that injects it), `DynamicSizing.swift` (its fractions now read
  from `WatchMetrics`; kept as thin wrappers until X2.15). pbxproj entries for the two new files.
- Nested radius helper: `LifeyShapes.nested(parent:padding:)` (22 − 8 = 14).
- **Verify:** build; a temporary gallery row (or `#Preview`) prints the metrics at 198 / 176 pt and matches
  the table.
- *As built:* no Xcode in the cloud session (verified by §4.3 screenshot comparison). Metrics scale the class table by width/reference width, so the reference sizes return the canvas table exactly; DynamicSizing.isCompact now delegates to WatchMetrics; legacy radius names aliased (chip/button/cardLarge); the root injection wraps ContentView's content in a GeometryReader sized to the proposal.

### X0a.3 — Watch iOS: Plus Jakarta Sans numerals + type styles ✅
- Files: new `mobile/ios/LifeyWatch/Fonts/PlusJakartaSans-{ExtraBold,Bold,Light}-numerals.ttf` + `OFL.txt`
  (subset per D-X0.6; the `pyftsubset` command goes into the README), `Info.plist` (`UIAppFonts`),
  pbxproj (Resources phase), new `Theme/LifeyType.swift`: `Font.lifeyHero/metric/value/aodHero` via
  `Font.custom(_, size:, relativeTo:)` with the 115 % cap (`@ScaledMetric` + clamp), system text styles for
  `title/body/label` with the 135 % cap, `.tabularNumbers()` = `monospacedDigit()`, a `LifeyNumber` view
  (number in PJS + unit in system label `text2`, 2 pt gap, accessibility label "128 beats per minute").
- DEBUG start-up assertion that the three PostScript names resolve (`UIFont(name:size:) != nil`) — risk §9.3.
- **Needs the user's OK** to fetch PlusJakartaSans-Light from the upstream release (D-X0.6, §10 Q4).
- **Verify:** build; a preview shows "12:34", "62,5", "3.42", "—", "1:05:12" in PJS at both sizes; text
  next to them is SF Pro; Dynamic Type at the largest size stops the hero at 115 %.
- *As built:* ExtraBold + Bold subsets (≈ 10 KB each, built with pyftsubset from mobile/assets/fonts, command in Fonts/README.md). The Light (300) subset is NOT bundled — it needs your OK to fetch from upstream (§10 Q4); `lifeyAodHero` falls back to Bold until then. Font availability uses CoreText (UIKit does not exist on watchOS); sizes use @ScaledMetric clamped at 115 % / 135 %. OFL.txt not added to the Resources phase.

### X0a.4 — Watch iOS: motion tokens, reduced motion, haptic map ✅
- Files: new `Theme/LifeyMotion.swift` (durations + curves of D-X0.14 as `Animation` values; a
  `reducedMotion`-aware `withLifeyAnimation`), new `Theme/LifeyHaptics.swift` (one function per event of the
  haptic table wrapping `WKInterfaceDevice.current().play(_)`); the existing `play(` call sites (4) call
  it **from the same place they are today**.
- **Verify:** build; grep shows no direct `WKInterfaceDevice.current().play` outside `LifeyHaptics`; a
  logged set still plays `.success` once.
- *As built:* all 6 `WKInterfaceDevice.play` call sites now go through `LifeyHaptics` from the same place (grep: none left outside it). Events: setLogged ×2, logFailed, restOver, stepperTick (±), syncTap (adoption retry).

### X0a.5 — Watch iOS: DEBUG design gallery skeleton ✅
- Files: new `Views/Debug/DesignGalleryView.swift` (`#if DEBUG`): sections per DS frame (tokens swatches,
  type ramp, metrics readout, then one section per component as later steps add them, then "Frames"
  with AW fixtures added by X1/X2); size override to render a 176 pt column inside a 198 pt screen; entry =
  long-press on the idle leaf in DEBUG builds only (`IdleView.swift`).
- **Verify:** build Debug + Release; the gallery opens in Debug, the long-press does nothing in Release.
- *As built:* gallery = sheet opened by a long-press on the idle leaf, wrapped in `#if DEBUG`; width button toggles the 198 / 176 pt column; AOD toggle is exposed as `EnvironmentValues.galleryAOD` for X0a.11. Sections register in `GallerySection.all`.

### X0a.6 — Watch iOS: header chip, metric reading, set segment bar ✅
- Files: new `Views/Components/HeaderChip.swift`, `MetricReading.swift`, `SetSegmentBar.swift` (pbxproj).
  The existing private structs in `ActiveWorkoutView.swift` are **not** replaced yet (screens switch in X1).
- `HeaderChip` (04/01): icon + CAPS label, `text2` (cardio: accent); paused state turns the whole chip clay
  "SZÜNETELTETVE"; optional standalone mark slot (26 pt `control` circle, 44 pt hit area, tap callback,
  "tapped" state = `raised` + sync glyph).
- `MetricReading` (04/02): icon + number + unit at `metric` (HR) or `value` (kcal) level.
- `SetSegmentBar` (04/03): segments instead of dots, readable up to 8 sets, card width; done = `text`,
  just logged = `success` for 1.2 s, remaining = `raised`; text "2/4"; no plan (quick strength) = no bar,
  only "3. szett · 24 ism.".
- Gallery entries with every state at both sizes.
- **Verify:** gallery shows the DS 04/01–03 samples side by side with the canvas.
- *As built:* named WatchHeaderChip / WatchMetricReading (not HeaderChip / MetricReading) because the old private types of the same names live in ActiveWorkoutView.swift until X1 switches the screens; gallery entries in Views/Debug/GalleryComponents.swift.

### X0a.7 — Watch iOS: heart-rate slot + explanation sheet ✅
- Files: new `Views/Components/HeartRateSlot.swift` (D-X0.4: live / missing; tap → `.sheet` with the
  existing `cardio_no_heart_rate_label` + `cardio_no_heart_rate_hint`, close with X or the crown — AW2.19).
- **Verify:** gallery: live, missing, missing + sheet open; the slot's frame is identical in both states.
- *As built:* spoken form of the live reading is "128 bpm" (number + unit) — no new string key for a sentence form; the slot is `minHeight`-locked to the metric line so live and missing share a frame.

### X0a.8 — Watch iOS: circle button, status pill, ghosted modifier ✅
- Files: new `Views/Components/CircleButton.swift`, `StatusPill.swift`, `Theme/Ghosted.swift`.
- `CircleButton` (04/04): diameter from `WatchMetrics`, styles `primary` (fill + `onPrimary` content),
  `raised` (+ clay icon), `control`, `errorTint`, `successTint` (logged), ghosted; label **under** the
  circle (max two lines); press = 0.96 scale + one tone up (100 ms); 300 ms double-tap guard as a reusable
  modifier (moved, not re-invented, from `LogPage`).
- `StatusPill` (04/05): 28 pt, icon + one line, wraps to two lines left-aligned with radius 22; kinds
  `logged` (success tint), `pending` (nested + hourglass), `failed` (error tint + icon), `unreachable`
  (nested + `text2`), `handoff` (nested, AW2.7); `StatusPill.priority` = failed › unreachable › pending ›
  logged (one pill at a time).
- `.ghosted(_:)` applies `card` + `ghost` (D-X0.10).
- **Verify:** gallery: every style × enabled/ghosted, every pill kind in HU at 41 mm (the failed pill must
  fit one line at 45 mm, AW1.8).
- *As built:* the double-tap guard is a small `DoubleTapGuard` struct in Theme/Ghosted.swift (LogPage keeps its own copy until X1.5 switches over); the pill uses the card radius (22) for both one and two lines; pill copy is supplied by the caller from the existing log_set_* keys (the gallery uses sample text).

### X0a.9 — Watch iOS: rest bar, "Mehet!" rim, stepper, effort scale ✅
- Files: new `Views/Components/RestCountdown.swift`, `GoFlash.swift`, `ValueStepper.swift`, `EffortScale.swift`.
- `RestCountdown` (04/06, Apple variant): hero number above an 8 pt white linear bar (radius 4), "/ 1:30"
  total in `text2`; last 5 s: number + fill `calories`, number pulses 100 → 92 % at 1 Hz (off with reduced
  motion); linear per-second drain.
- `GoFlash` (04/07): `ContainerRelativeShape().strokeBorder(primary, lineWidth: 8)` + white "Mehet!"
  (`rest_go_label`) over any page; 150 / 250 / 700 ms; reduced motion = static 1.1 s.
- `ValueStepper` (04/08): 44 pt ± circles inside the margin, value in PJS between, unit line under it;
  crown = one step per detent (`digitalCrownRotation` with `sensitivity: .low`, detents), bound reached →
  that button ghosted; min scale factor 0.85 for 4-char values (AW1.11).
- `EffortScale` (04/11): `ValueStepper` 1–10 + a 10-segment bar; number white.
- **Verify:** gallery: rest at 0:47 and 0:04, flash (with a "replay" button), stepper at bounds 1 and 99,
  weight "102,5" at 41 mm without truncation.
- *As built:* the stepper's crown uses `sensitivity: .high` (not `.low` as the plan wrote): the existing AdjustPage comment records that `.low` made detents-per-step inconsistent. Reduce Motion: pulse and drain animation off, flash static for 1.1 s.

### X0a.10 — Watch iOS: list row, compact chip, summary tile + sync row, bench frame, cardio field, status screen ✅
- Files: new `Views/Components/ListRow.swift`, `CompactChip.swift`, `SummaryTile.swift` (+ `SyncRow`),
  `BenchFrame.swift`, `CardioField.swift`, `StatusScreen.swift`.
- `ListRow` (04/09): 22-radius card row; highlighted = `nested` + 36 pt icon holder; title wraps to two
  lines; optional trailing chevron; cardio variant with a tinted icon circle (accent @ 16 %).
- `CompactChip` (04/10): 36 pt visible, 44 pt target (today 32).
- `SummaryTile` (04/12): number (PJS `metric`) + one-line `text2` label ("átlag bpm"), count-up 600 ms;
  `SyncRow`: pending (nested, `icloud.and.arrow.up`, title + "n edzés vár szinkronizálásra" second line) /
  synced (success tint), 250 ms tint switch.
- `BenchFrame` (04/13): 4 pt clay stroke following the display radius (`ContainerRelativeShape`); AOD
  variant 2 pt at 60 %.
- `CardioField` (04/15, Apple): one row, value left (PJS `value`) + phone label right (CAPS `label`,
  wraps to two lines, never < 80 % scale).
- `StatusScreen`: left-aligned pattern (icon holder or 26 pt icon, title max 2 lines, subtitle, button
  above the fold) — used by AW1.21 and AW2.17.
- **Verify:** gallery entries for all six at 45 and 41 mm, HU.
- *As built:* the six components are in Views/Components (SyncRow lives in SummaryTile.swift); the count-up is an `Animatable` Text so it really interpolates; gallery sections 04/09–04/15.

### X0a.11 — Watch iOS: Always-On primitives ✅
- Files: new `Theme/LifeyAOD.swift`: `isLuminanceReduced` reader, `AODStyle` (PJS 300 `text2`, metric @
  60 %, outlined SF symbol names via a `symbol(_:filled:)` helper), `aodElapsed(_:)` ("12 p" / "1 ó 05 p"),
  `aodRestUntil(endsAt:)` + `aodRemaining` rounded up, a `MinuteTimeline` wrapper (`TimelineView(.everyMinute)`
  under reduced luminance, the existing per-second schedule otherwise); `Localizable.xcstrings`:
  `aod_minutes`, `aod_hours_minutes`, `aod_rest_until` (HU + EN).
- **Verify:** gallery "AOD" toggle forces the reduced-luminance environment; "12 p", "1 ó 05 p", "Mehet
  9:42-kor" render in HU, "12 min", "Go at 9:42 AM" in EN.
- *As built:* formatters (`elapsed`, `remaining`, `restUntil`, `symbol`) are pure statics in `LifeyAOD`; `AODReader` / `MinuteTimeline` pick reduced luminance or the gallery toggle. Strings aod_minutes / aod_hours_minutes / aod_rest_until added to Localizable.xcstrings (HU + EN). aod-hero falls back to Bold until the Light subset is bundled (§10 Q4).

**X0a review (§4.1) — done in the cloud (§4.3), Mac pass still owed; log in §12:** gallery vs DS frames 01–08 at 45 / 41 mm; every existing screen walked once to
confirm the alias swap broke nothing (colours change, layouts do not).

---

## X0w — Foundation, Wear OS · `Lifey Watch Design System.dc.html`

**Goal:** everything Wear-wide that X3 and X4 build on: v2 tokens value-identical to Apple, Material 3,
round-screen scaffolding, tests and CI, and every component of the W canvases in the debug gallery at
227 and 192 dp.

**Design source:** D1–D4, frames 01–08; the Wear-specific notes in frames 03 (12 % margin, 20 % chords),
04 (M3 Button / EdgeButton for every touchable), 05 (TransformingLazyColumn, TimeText, ScrollIndicator,
no back arrow), 06 (permission slot), 08 (ambient, burn-in).

### X0w.1 — Watch Wear: v2 colour tokens + legacy aliases ✅
- Files: `ui/theme/LifeyColors.kt` (same names and values as Apple X0a.1; `primaryContainer`,
  `secondaryContainer`, `tertiaryContainer` aliased; `@Deprecated(replaceWith = ...)` on legacy names),
  `ui/theme/LifeyTheme.kt` (M2 `Colors` mapped from the new names).
- **Verify:** `:wear:assembleDebug`; idle, picker, active page on the emulator show the v2 palette.
- *As built:* no Android SDK in the cloud session, so nothing was built; values are identical to LifeyColors.swift (checked by script, formal TokenParityTest follows in X0w.3). Added cardioHiking (hiking was tertiary, which now aliases success); the M2 theme maps from the new names.

### X0w.2 — Watch Wear: Compose Material 3 alongside Material 2 ✅
- Files: `mobile/android/wear/build.gradle.kts` (`compose-material3` on the foundation's version line,
  `debugImplementation("androidx.wear.compose:compose-ui-tooling")`), `ui/theme/LifeyTheme.kt`: an M3
  `ColorScheme` from the tokens (primary/onPrimary, surfaceContainer* = card/nested/control/raised,
  background = bg, error = error, outline = outline, onSurface = text, onSurfaceVariant = text2), the M2
  theme kept inside it until X4.16.
- **Verify:** builds; an M3 `Button` and an M2 `Chip` render side by side in a preview with the right
  colours.
- *As built:* UNVERIFIED: Google Maven (dl.google.com) is blocked in the cloud session, so the compose-material3 1.6.2 artifact name/version and the ColorScheme parameter names could not be checked — confirm on the first Windows build. The M3 theme wraps the M2 theme; the M3-vs-M2 side-by-side preview comes with the gallery (X0w.8).

### X0w.3 — Watch Wear: JVM tests — contrast, token parity ✅
- Files: `build.gradle.kts` (`testImplementation("junit:junit:4.13.2")`), new
  `src/test/kotlin/com/khunor/lifey/ui/theme/ContrastTest.kt` (port of `mobile/lib/core/theme/contrast.dart`;
  asserts `text` / `text2` / `text3` ≥ 4.5 on `bg`, `card`, `nested`; every metric/role on its own 16 % tint
  over `bg` ≥ 4.5; `onPrimary` on `primary` ≥ 4.5; `ghost` is exempt — disabled), new
  `TokenParityTest.kt` (reads `../../ios/LifeyWatch/Theme/LifeyColors.swift` relative to the module dir,
  extracts `static let <name> = Color(hex: 0x…)`, compares with `LifeyColors.kt` by reflection).
- Depends on X0a.1 (the Swift values) — the only cross-track dependency; land X0a.1 first (§0 order).
- **Verify:** `./gradlew :wear:testDebugUnitTest` green; changing one hex on either side makes it red.
- *As built:* tests not run (no Android SDK / Google Maven in the cloud). The contrast assertions were pre-computed independently in Python — every pair passes (text3 on nested 4.75, the lowest). Note: #F2F1E6 on black computes to 18.5 : 1, the canvas says 19.4 : 1 (different sRGB threshold constant; no action). The parity test walks up from the module dir to find ios/LifeyWatch/Theme/LifeyColors.swift.

### X0w.4 — CI: build and unit-test the Wear module ✅
- Files: `.github/workflows/mobile-ci.yml` — a job (or step after the Flutter setup, which the wear module
  needs for `flutter.compileSdkVersion` in `gradle.properties`) running `./gradlew :wear:assembleDebug
  :wear:testDebugUnitTest` from `mobile/android`, path-filtered to `mobile/android/wear/**`,
  `mobile/ios/LifeyWatch/Theme/**` (parity) and the workflow file.
- **Verify:** the PR's checks show the job green; a deliberately broken parity hex in a scratch commit
  turns it red (then reverted, not pushed).
- *As built:* added as a step of the existing Mobile CI job instead of a separate job: settings.gradle.kts needs the Flutter plugin loader / local.properties, which `flutter build apk` produces, and the workflow's `mobile/**` filter already includes the module and the Swift token file. Not run here; the first PR run is the check. The deliberate-red parity check from the plan was not possible offline.

### X0w.5 — Watch Wear: radius, spacing, `WatchMetrics`, chord rule ✅
- Files: `ui/theme/LifeyShapes.kt` (8 / 14 / 22 / 30 / pill / circle, legacy aliased), new
  `ui/theme/LifeySpacing.kt`, new `ui/theme/WatchMetrics.kt` (D-X0.5 Wear columns, `LocalWatchMetrics`
  provided from `BoxWithConstraints` in `LifeyTheme`, `chordWidth(y)`), `ui/DynamicSizing.kt` delegating to it.
- Tests: `WatchMetricsTest.kt` — 227 / 192 dp give exactly the table, 200 dp boundary, minimum targets
  never undercut at 170 dp, `chordWidth` at the top 20 % line.
- **Verify:** tests green; build.
- *As built:* not built or run (no Android SDK). The expected test numbers were computed by hand against the formulas (e.g. 12 % of 227 = 27.2 → 27, chord at the 20 % line of 200 dp = 160). WatchMetrics is provided from a BoxWithConstraints in LifeyTheme; DynamicSizing.isCompactScreen now delegates. Legacy shape names aliased (chip/button/cardLarge); card is now 22.

### X0w.6 — Watch Wear: Plus Jakarta Sans numerals + M3 typography ✅
- Files: `src/main/res/font/pjs_numerals_extrabold.ttf`, `pjs_numerals_bold.ttf`, `pjs_numerals_light.ttf`
  (byte-identical to the Apple subsets) + `OFL.txt` noted in the README; new `ui/theme/LifeyType.kt`:
  `FontFamily`, M3 `Typography` with `numeralLarge/numeralSmall/titleMedium` in PJS and system text for the
  rest, `tnum`, the 115 % / 135 % caps (`LocalDensity.fontScale` clamp), a `LifeyNumber` composable (number
  + system unit `text2`, content description); `LifeyTheme.kt` uses it. Wear gains the "bpm" unit key if
  `strings.xml` lacks it (D-X0.13).
- Tests: `FontCoverageTest.kt` — loads each TTF with `java.awt.Font.createFont` and asserts `canDisplay`
  for every D-X0.6 glyph; asserts the Wear and Apple copies are byte-identical.
- **Verify:** tests green; preview of hero/metric/value at font scale 1.0 and 1.3 (`@WearPreviewFontScales`).
- *As built:* not built. Font files are byte-copies of the Apple subsets (res/font, lowercase names; OFL.txt stays next to the Apple copies — a .txt in res/font would break aapt). Glyph coverage was checked with fontTools instead of the JVM test: all numeral glyphs present except U+202F (NNBSP), which the source font itself lacks — dropped from the test and the Fonts README; it falls back to the system font. active_heart_rate_unit (bpm) added in both languages. LifeyType exposes hero/metric/value/aodHero/title/body/label as @Composable TextStyles with the 115 %/135 % font-scale clamp; M3 typography slots numeralLarge/numeralSmall/titleMedium are set from LifeyTheme.

### X0w.7 — Watch Wear: motion tokens, reduced motion, haptic map ✅
- Files: new `ui/theme/LifeyMotion.kt` (durations, `CubicBezierEasing` curves, `rememberReducedMotion()`
  from `Settings.Global.ANIMATOR_DURATION_SCALE == 0f`), new `LifeyHaptics.kt` in the service package
  (functions per event wrapping the **existing** waveforms: 60·80·60, failure, 400 ms, `EFFECT_TICK`);
  `ExerciseService.kt` calls them from the same places (`vibrateRestEnd`, `vibrateLogSetConfirmed`,
  `vibrateLogSetFailed`, `vibrateLogAdjustTick`).
- **Verify:** build; on the emulator with a logged set, logcat shows the same vibrate call sequence as
  before (temporary log line, removed before commit).
- *As built:* not built. `LifeyHaptics` (package com.khunor.lifey) holds the four existing waveforms unchanged; the four private vibrate… functions in ExerciseService now one-line delegates called from the same places, so the logcat before/after comparison of the plan reduces to a diff of identical VibrationEffect values. The motion durations/curves mirror LifeyMotion.swift.

### X0w.8 — Watch Wear: debug design gallery ✅
- Files: new `src/debug/AndroidManifest.xml` + `src/debug/kotlin/com/khunor/lifey/debug/DesignGalleryActivity.kt`
  (exported, debug only): a `TransformingLazyColumn` of sections like X0a.5, an intent extra `frame` that
  jumps straight to one fixture (for `adb`-driven screenshots, §4.2).
- **Verify:** `adb shell am start -n com.khunor.lifey/.debug.DesignGalleryActivity` opens it; the release
  APK's merged manifest does not contain it (`./gradlew :wear:processReleaseMainManifest` + grep).
- *As built:* not built (TransformingLazyColumn from wear-foundation lazy, API unverified offline). Debug-only manifest + activity in src/debug; `--es frame <id>` jumps to a registered fixture (galleryFrames, empty until X3/X4); width and ambient toggles at the top. The release-manifest check (processReleaseMainManifest + grep) is left for the first Windows run.

### X0w.9 — Watch Wear: round-screen scaffolding ✅
- Files: new `ui/components/LifeyScaffold.kt`: `LifeyAppScaffold` (M3 `AppScaffold` + `TimeText`),
  `LifeyScreen` (M3 `ScreenScaffold` with `ScrollIndicator`, optional `edgeButton` slot),
  `lifeyTransformationSpec()` (≤ 12 % shrink, ≥ 80 % opacity, D-X0.12), `LifeyPager` (wear-foundation
  `HorizontalPager` with **rotary paging off**, M3 `HorizontalPageIndicator` that hides when the bottom slot
  is occupied), `DismissibleOverlay` (`SwipeToDismissBox` + `BackHandler` → `onDismiss`).
- **Verify:** gallery: a 12-row list shows the edge rows at the spec; a dismissible overlay closes by swipe
  and by the back key without closing the activity.
- *As built:* UNVERIFIED offline — the M3/foundation signatures (AppScaffold(timeText), ScreenScaffold(scrollState, edgeButton), HorizontalPageIndicator(pagerState), SwipeToDismissBox, HorizontalPager(rotaryScrollableBehavior = null)) are from memory of the 1.5/1.6 API and must be compiled on the first Windows run. Deviation: the ≤ 12 % / ≥ 80 % edge-row spec is recorded as constants (LifeyTransformation) but the library default transformation is used until it can be built against a compiler. The gallery's 12-row list / overlay demo is added with the first screen that uses them (X3.2).

### X0w.10 — Watch Wear: header chip, metric reading, set segment bar, heart-rate slot ✅
- Files: new `ui/components/HeaderChip.kt`, `MetricReading.kt`, `SetSegmentBar.kt`, `HeartRateSlot.kt`.
- As X0a.6 / X0a.7 with the Wear differences: standalone mark 24 dp visible / 48 dp target; template name in
  the header ≤ 14 characters + ellipsis (W2.6); the narrow centred exercise block (96 dp on 192 dp, inside
  the bottom chord); `HeartRateSlot` adds the **permission** state — an M3 Button (44 dp) with ghost heart,
  "—", `active_heart_rate_denied_title` / `_action` on two deliberate lines, tap = callback to the existing
  permission request; the explanation is an M3 `AlertDialog` with the existing "Rendben" key (W2.16).
  Strings: split `active_heart_rate_denied_chip` into the two ⚑ keys (HU + EN); the old key is removed in
  X3.5 when its last usage goes.
- **Verify:** gallery at 227 / 192 dp, HU + EN; the permission slot's two lines never ellipsize.
- *As built:* not built (M3 Button/AlertDialog/ButtonDefaults.filledTonalButtonColors signatures unverified offline). New keys active_heart_rate_denied_title / _action (HU+EN); the old _chip key stays until X3.5. HeartRateSlot has three states (Live / Missing / PermissionDenied) in one min-height frame; the 'nincs pulzus' explanation is an M3 AlertDialog with the existing error_ok_button text. Gallery: debug/ComponentGallery.kt.

### X0w.11 — Watch Wear: circle button, status pill, ghosted modifier ✅
- Files: new `ui/components/CircleButton.kt`, `StatusPill.kt`, `ui/theme/Ghosted.kt`.
- As X0a.8; status pill sits on the bottom chord where the page indicator was, wraps to **two centred
  lines** deliberately on the round screen ("Nem sikerült —" / "próbáld újra", W1.7); circle 78 dp (74
  with a secondary EdgeButton, 66 compact).
- **Verify:** gallery: every style and pill kind at both sizes, HU.
- *As built:* not built. CircleButton is a plain clickable circle (no M3 Button) so the 0.96 press scale and double-tap guard work as on Apple; ghosted is a token pair (Modifier.ghosted + ghostedContent); the failed/unreachable pills wrap to two centred lines via explicit line breaks in the caller's text. The icon name Icons.Filled.ErrorOutline etc. needs the extended icon pack already in the module.

### X0w.12 — Watch Wear: rest ring, "Mehet!" ring, stepper, effort, EdgeButton usage ✅
- Files: new `ui/components/RestRing.kt`, `GoFlash.kt`, `ValueStepper.kt`, `EffortScale.kt`.
- `RestRing` (04/06 Wear): full-screen M3 `CircularProgressIndicator`, 6 dp, white on `control` track,
  hero number in the centre, "/ 1:30" under it; last 5 s: remainder + hero `calories`, 1 Hz pulse; driven
  by the existing `elapsedRealtime`-based state.
- `GoFlash`: 9 dp primary ring where the rest ring was (`CircleShape` border), white "Mehet!", 150/250/700.
- `ValueStepper`: ± 44 dp circles (40 visible / 48 target on 192 dp), number 34 sp on compact, **EdgeButton
  confirm** on the bottom arc ("8 ismétlés naplózása"), rotary ≈ 24 dp = one step + `EFFECT_TICK`.
- `EffortScale`: stepper 1–10 + 10 segments; "Kihagyás" a 40 dp secondary Button; "Edzés lezárása" EdgeButton.
- **Verify:** gallery at both sizes; rotary on the emulator steps the stepper (extended controls ▸ rotary).
- *As built:* not built. M3 CircularProgressIndicator(progress = { }), ProgressIndicatorDefaults.colors and EdgeButton signatures unverified offline. The stepper keeps the proven rotary scheme (≈ 24 dp per step + EFFECT_TICK via LifeyHaptics); on the compact dial the number is the metric style scaled to 34 sp. The 'rotary steps the stepper' emulator check stays with the Windows pass.

### X0w.13 — Watch Wear: list row, summary tile + sync row, bench ring, cardio field, status screen ✅
- Files: new `ui/components/ListRow.kt` (M3 `Button` pill for **every** row incl. quick strength;
  highlighted = `raised` + icon circle; 52 / 48 dp), `SummaryTile.kt` (+ `SyncRow`, centred), `BenchRing.kt`
  (clay ring 4 dp; ambient 2 dp @ 60 %), `CardioField.kt` (boxless: value above, label below, centred,
  two lines max), `StatusScreen.kt` (centred icon, 2-line title, text, **EdgeButton** action).
- **Verify:** gallery entries at both sizes, HU.
- *As built:* not built (M3 Button/EdgeButton/animateColorAsState imports unverified; animateColorAsState is androidx.compose.animation.animateColorAsState). ListRow is an M3 Button pill for every row; SyncRow centred; BenchRing 4 dp (ambient 2 dp @ 60 %); CardioField boxless. Gallery sections 04/09–04/15 added.

### X0w.14 — Watch Wear: ambient primitives ✅
- Files: `build.gradle.kts` (`androidx.wear:wear` for `AmbientLifecycleObserver`), new
  `ui/theme/LifeyAmbient.kt` (`LocalAmbientState`, a `rememberAmbientState()` fed by the observer
  registered in `MainActivity`, the ±4 dp per-minute burn-in offset modifier, `AmbientStyle` with PJS
  Light, metric @ 60 %, `Icons.Outlined` equivalents), formatting functions `ambientElapsed`,
  `ambientRestUntil`, `ambientRemaining` (rounded up), strings `aod_minutes`, `aod_hours_minutes`,
  `aod_rest_until` (HU + EN).
- Tests: `AmbientFormatTest.kt` — 59 s → "~1 p", 12:34 → "12 p", 65:10 → "1 ó 05 p", rest end in the local
  zone across midnight, EN forms.
- Registering the observer here does **not** yet keep the app visible on wrist-down for screens without an
  ambient layout — the screens opt in during X4.13–15. Until then behaviour = today (watch face).
- **Verify:** tests green; gallery "ambient" toggle.
- *As built:* not built / tests not run. Formatting is pure (templates passed in) so the JVM test needs no Android resources. Two assertions in restEndTimeUsesTheLocalZoneAcrossMidnight depend on the JDK's locale data for the short time style (HU 0:01 vs 00:01, NNBSP before PM in newer JDKs) and are normalised in the test — if they still disagree on the CI JDK, loosen to the zone arithmetic only. androidx.wear:wear:1.3.0 added; the observer itself is registered in MainActivity by X4.13 (so the app still shows the watch face on wrist-down until then). Strings aod_* added HU+EN.

**X0w review (§4.2) — done as far as the cloud allows (§4.3); the emulator pass is still owed; log in §12:** gallery vs DS frames at 227 / 192 dp (create the 192 dp AVD first); every existing
screen walked once (colours change, layouts don't); CI job green on the PR.

---

## X1 — Apple Watch strength · `Lifey Watch 1 Apple Watch Strength.dc.html` (AW1.1 – AW1.22)

**Goal:** the phone-driven strength workout is fully on v2: hero rule, one status slot, the rim flash, the
new controls, picker, effort, ending and summary.

**Current code:** `Views/ActiveWorkoutView.swift` (`MetricsPage`, `HeroMetricRow`, `ExerciseCard`,
`HeaderChip`, `MetricReading`, `LogPage`, `AdjustPage`, `RestHeroView`, `GoFlashView`, `ControlsPage`,
`ControlButton`, `ExerciseListChip`, `ExerciseListView`, `ExerciseListRow`), `EffortSelectorView.swift`,
`EndingView.swift`, `SummaryView.swift`.

### X1.1 — Watch iOS: split ActiveWorkoutView into files with presentational content views ✅
- Files: `ActiveWorkoutView.swift` → `Views/Active/{ActiveWorkoutView,MetricsPage,LogPage,AdjustPage,
  RestHero,ControlsPage,ExerciseList,Cardio}.swift` (pbxproj); each page gets a `…Content` view taking a
  plain `struct …Model` (built from `WorkoutManager` by the outer view) so the gallery can render it.
- **No visual or behavioural change** — a move + extraction only.
- Gallery: a "Frames" section with fixtures for AW1.1–AW1.22 (they still show the old look; each later step
  makes its frames match).
- **Verify:** build; a phone-driven session on the simulator behaves exactly as before (log a set, rest,
  adjust, pause, end).
- *As built:* mechanical split by a script (top-level declarations moved verbatim; `private` removed from file-scope types/functions so they can be shared across the new files): ActiveWorkoutView, MetricsPage (+HeaderChip, MetricReading, HeroMetricRow, ExerciseCard), LogPage, AdjustPage, ControlsPage (+ExerciseListChip, ControlButton), ExerciseList, RestHero (+GoFlashView), Cardio. Not compiled. Deviation: the plain `…Model`/`…Content` extraction and the AW1.x gallery fixtures are done per page in X1.2–X1.14 while each page is rewritten, instead of as a no-op refactor first (a second pass over unchanged code would only double the uncompiled risk).

### X1.2 — Watch iOS: metric page — the hero rule (AW1.1, AW1.4) ✅
- Requirements: one hero (elapsed time, `hero`, **white**, not primary) › HR (`metric`, heart colour, via
  `HeartRateSlot`) › kcal (`value`); header chip "ERŐEDZÉS" (`dumbbell`); exercise card with
  `SetSegmentBar` "2/4" at the bottom; card radius from the margin (nested rule); 41 mm: hero 42, metric 25,
  value 17, margin 14, card radius 14 — nothing dropped, no scrolling.
- Replaces `HeroMetricRow`, the old `MetricReading`/`HeaderChip`/`ExerciseCard` usages on this page.
- **Verify:** AW1.1 and AW1.4 fixtures + live session at both sizes.
- *As built:* X1.2–X1.4 land together because they are one view: MetricsContent (plain MetricsModel) = hero time (white; text3 when paused) › HeartRateSlot (always present, so a missing HR keeps its place — X1.4) › kcal › exercise card with SetSegmentBar (name wraps to two lines); paused = the header chip turns clay (X1.3), no extra row. The numbers carry the metric colour as in the canvas (121 heart, 87 calories). HeroMetricRow / ExerciseCard removed; HeaderChip and MetricReading (old) stay for Log/Controls/Rest until their steps. Frames AW1.1–1.4 registered in the new Frames gallery (FramesGallery.swift); the 41 mm frame is a fixed 176 pt device frame. Not compiled.

### X1.3 — Watch iOS: paused metric page (AW1.2) ✅
- The orange "Szüneteltetve" row is gone; the header chip itself turns clay "SZÜNETELTETVE" (`pause.fill`,
  key `active_paused_indicator`), the stopped time fades to `text3`. No extra row, no squeeze.
- **Verify:** pause from the controls page; AW1.2 fixture.

### X1.4 — Watch iOS: missing HR on strength + long exercise names (AW1.3) ✅
- The HR row no longer disappears: `HeartRateSlot` missing state (ghost heart, "—", "nincs pulzus" + ⓘ;
  tap → AW2.19 sheet); kcal does not move up. Exercise name wraps to two lines ("Bulgarian Split Squat"),
  never "Bulgarian Sp…".
- **Verify:** simulator without HR samples; AW1.3 fixture; the slot's position equals AW1.1's.

### X1.5 — Watch iOS: log page — "+1 szett" ready (AW1.5, AW1.12) ✅
- Next set line on top ("Fekvenyomás · 3/4 szett"); filled **primary** circle with dark "+1" (no green
  ring/text); "Módosítás" = `raised` circle with clay `slider.horizontal.3`, label under the circle at full
  size; header chip `timer` + elapsed. 41 mm: circles 70 pt, "Gyakorlatok" compact chip (36 / 44) in the
  status slot (2+ exercises, standalone and phone mode as today).
- **Verify:** AW1.5 / AW1.12 fixtures; tap targets 78 / 70 pt.
- *As built:* X1.5 + X1.6 are one view. LogContent (plain LogModel): next-set line, primary '+1' circle (PJS '+1' in the circle, label 'szett' under it = the localized log_set_button without the '+1'), raised 'Módosítás' circle with the clay icon, and ONE bottom slot: pending / logged / failed / unreachable pill (StatusPill) or, when idle, the 'Gyakorlatok' compact chip. Pending/failed/unreachable ghost both circles with the token pair. The tap rules (canTap, hasLogSetPrefill → stepper, standalone exemption) are kept; the 300 ms guard moved into CircleButton. CircleButton gained centerText. Also: the crown no longer pages the TabView (D-X0.9) — crownRotation state removed from ActiveWorkoutView. Frames AW1.5–1.9, 1.12 registered. Not compiled.

### X1.6 — Watch iOS: logging states in one slot (AW1.6 – AW1.9) ✅
- Pending: both circles ghosted (token pair, no opacity) + "Naplózás…" pill (`hourglass`, `log_set_pending`).
- Confirmed (≈ 1.2 s): the "+1" circle becomes success tint with a check and "3/4 szett"; "Naplózva" pill;
  `.success` haptic; then rest starts (unchanged).
- Failed (≈ 2.5 s): error-tint pill with `exclamationmark.circle.fill`, one line at 45 mm; `.failure`.
- Phone unreachable: neutral pill (nested + `text2`, `wifi.slash`, `phone_unreachable`); never shown in
  standalone mode.
- All pills in the same bottom slot (the chip yields for 2.5 s); priority per `StatusPill.priority`.
  Pending → confirmed / failed flow and the 300 ms guard unchanged.
- **Verify:** fixtures AW1.6–1.9; live: log with the phone app paused (unreachable), with the backend down
  (failed).

### X1.7 — Watch iOS: stepper — reps and weight (AW1.10, AW1.11) ✅
- Only the header is clay ("MÓDOSÍTÁS"), not the whole page; v2 segmented switch "Ismétlés | Súly";
  `ValueStepper` with 44 pt ± inside the margin; caption "ism. · 62,5 kg" / "kg · 8 ism."
  (`log_adjust_caption_weight`); full-width pill confirm "8 ismétlés naplózása" (wraps to two lines).
- Unchanged: reps 1–99, weight 0–500 step 2,5 kg with the locale decimal separator, crown = one step,
  auto-close after 3 s idle.
- **Verify:** fixtures; "102,5" at 41 mm fits without the old 50 % squeeze.
- *As built:* AdjustContent (plain AdjustModel): clay header only, v2 segmented switch Ismétlés|Súly, 44 pt ± circles reaching half into the side margin, big value in the hero style with minimumScaleFactor 0.5, caption, full-width primary confirm that can wrap to two lines. Behaviour unchanged (manager owns steps/bounds/clamp, crown .high, 3 s idle dismiss). Frames AW1.10 / AW1.11 (41 mm, '102,5'). Not compiled; whether '102,5' fits on 41 mm without shrinking below 50 % needs the Mac pass.

### X1.8 — Watch iOS: rest countdown (AW1.13, AW1.14, AW1.16) ✅
- `RestCountdown` in the metric page's hero slot; header chip "PIHENŐ" (`timer`); "Következő · Fekvenyomás
  — 3/4. szett" wraps to two lines (on long names "— 3/4. szett" goes to line two, AW1.16); HR + kcal small
  row. Last 5 s colour + pulse (AW1.14). The bar is white (fill is not a control → not primary).
- **Verify:** fixtures at 0:47 and 0:04; live rest; 41 mm.
- *As built:* RestContent (plain RestModel): chip PIHENŐ, RestCountdown (hero over a white 8 pt bar, warning colour + pulse in the last 5 s), 'Következő …' line up to two lines, small HR + kcal row. The old full-green GoFlashView is gone — ActiveWorkoutView shows GoFlash() (8 pt primary rim following the display shape, white 'Mehet!', 150/250/700 ms, static 1.1 s under Reduce Motion); the haptic and the 1.3 s overlay cycle in ActiveWorkoutView are untouched, so it still overlays whichever page is visible. Old MetricReading removed. Frames AW1.13–1.16 (the gallery DeviceFrame now sets containerShape so the rim has a shape). Not compiled.

### X1.9 — Watch iOS: "Mehet!" rim flash (AW1.15) ✅
- `GoFlash` replaces `GoFlashView`'s full green screen: black background, 8 pt primary rim with the display
  radius, white "Mehet!"; over whichever page is visible; `.notification` haptic unchanged and independent.
- **Verify:** let a rest expire on each of the three pages; reduced motion = static 1.1 s.

### X1.10 — Watch iOS: controls page (AW1.17, AW1.18) ✅
- Two 78 pt circles side by side: "Vége" (error tint, `stop.fill`) + "Szünet" (control, `pause.fill`).
  Paused: "Folytatás" becomes the **primary** circle (`play.fill`), header icon clay pause, "Gyakorlatok"
  compact chip at the bottom (2+ exercises). Cardio uses the same page with the activity icon in the header.
- **Verify:** fixtures; pause → resume → end on the simulator.
- *As built:* ControlsContent (plain ControlsModel): 'Vége' (error tint, stop.fill) + 'Szünet' (control, pause.fill) as two CircleButtons; paused: 'Folytatás' primary play.fill, clay header chip, 'Gyakorlatok' CompactChip. Cardio reuses it with the activity icon/accent in the header. ControlButton and ExerciseListChip removed. Frames AW1.17/1.18. Exercise picker (X1.11) is in the same commit tree: ExerciseListContent with NavigationStack + toolbar back button (cancellationAction, chevron.left), rows = SetSegmentBar in a card, current = control + check; frame AW1.19. Not compiled — whether the cancellationAction item renders as the 32/44 pt nav back button needs the simulator.

### X1.11 — Watch iOS: exercise picker (AW1.19) ✅
- Presented in the `NavigationStack` so the **watchOS 10 nav back button** (32 visible / 44 target) replaces
  the 8 pt arrow; rows = `ListRow` with a `SetSegmentBar` each; selected = `control` + check; names wrap to
  two lines; crown scrolls; tap switches immediately, no confirmation (unchanged).
- **Verify:** fixture; switching exercise on a 3-exercise template updates the log page.

### X1.12 — Watch iOS: effort (AW1.20) ✅
- "Milyen nehéz volt?" title; `EffortScale` (white number, 10 segments); primary "Edzés lezárása"; real
  "Kihagyás" button (38 pt visible, 44 target); back = nav button; fits without scrolling at both sizes.
  Crown 1–10; no note collected (unchanged).
- **Verify:** fixture; end a session with and without an effort value.
- *As built:* X1.12: EffortContent = title, EffortScale (white number, 10 segments, crown 1–10), primary 'Edzés lezárása', real 'Kihagyás' button (38 pt visible / 44 target), back via NavigationStack toolbar; a ScrollView with minHeight stays as a safety net for long titles. X1.13: EndingContent = left-aligned StatusScreen with iphone in text colour, title, subtitle and an indeterminate ProgressView (linear) instead of three static dots. Behaviour (requestEnd / cancelEffortSelection) unchanged. Frames AW1.20, 1.20b (41 mm), 1.21. Not compiled.

### X1.13 — Watch iOS: finish on the iPhone (AW1.21) ✅
- `StatusScreen` left-aligned: icon holder with `iphone` in `text` (not green), "Fejezd be az iPhone-on",
  "Az edzés mentése…", an indeterminate `ProgressView()` that moves (still under reduced motion) instead of
  three static dots.
- **Verify:** fixture; end a phone-driven session.

### X1.14 — Watch iOS: summary — phone workout (AW1.22) ✅
- Check beside "Edzés mentve" (not above — saves a row); full-width time tile with a 28 pt number; "átlag
  bpm" on one line; kcal tile; "Elmentve az Egészség appba" row wraps to two lines above the fold;
  count-up 600 ms, check pops once, 60 ms tile stagger; 6 s auto-dismiss unchanged.
- **Verify:** fixture; the summary after a real session.
- *As built:* SummaryContent (plain SummaryModel): check beside 'Edzés mentve', a full-width time SummaryTile, avg bpm + kcal (+ sets for standalone) tiles side by side, the 'Elmentve az Egészség appba' row wrapping to two lines, SyncRow for standalone (X2.6 refines it). Count-up lives in SummaryTile (600 ms, off under Reduce Motion). The 'check pops once' and 60 ms tile stagger are NOT implemented yet — tiles all count up together; left for the Mac pass. 6 s auto-dismiss untouched (WorkoutManager). Frame AW1.22. Not compiled.

**X1 review (§4.1) — done in the cloud (§4.3), Mac pass still owed; log in §12:** all AW1 frames, demo flow "full phone-driven strength session", failure paths.

---

## X2 — Apple Watch start, standalone, cardio, errors, AOD · `Lifey Watch 2 Apple Watch Start Standalone Cardio.dc.html` (AW2.1 – AW2.23)

**Goal:** every remaining Apple screen on v2, Always-On variants, and the legacy tokens deleted.

**Current code:** `IdleView.swift`, `StandalonePickerView.swift` (`TemplateRow`, `CardioRow`,
`AllTypesRow`, `AllActivityTypesView`), `SummaryView.swift`, `HealthDeniedView.swift`, the cardio views
from X1.1's `Views/Active/Cardio.swift`.

### X2.1 — Watch iOS: idle (AW2.1) ✅
- Leaf (`leaf.fill`) in a `card` holder in primary; "Lifey" in PJS 800 (wordmark — the one place PJS
  carries letters, covered by the ExtraBold subset, D-X0.6); full-width 48 pt primary
  "Edzés indítása", one line; "vagy indítsd a telefonon" in `text2`.
- **Verify:** fixture at both sizes; tap → picker.
- *As built:* IdleContent: leaf in a card holder, 'Lifey' in PJS 800, full-width primary start button (one line, ≥ 44), caption in text2; the DEBUG long-press on the leaf opens the gallery as before. Frames AW2.1 / 2.1b. Not compiled.

### X2.2 — Watch iOS: picker list (AW2.2 – AW2.4) ✅
- `ListRow` everywhere (22 radius): quick strength highlighted (`nested`, 36 pt `bolt.fill` holder — fits
  one line, today three); templates with "5 gyakorlat" + chevron; cardio rows with tinted icon circles
  (activity accent @ 16 %); "Minden edzéstípus" with its own control-circle `apps` icon, only when the type
  list is synced; empty state: `sync` icon + "A tervek a telefonról szinkronizálódnak" in `text2`
  footnote. Max 8 ranked rows, crown scrolls with the system indicator (unchanged).
- **Verify:** fixtures AW2.2–2.4; with and without synced templates.
- *As built:* PickerContent / AllTypesContent (plain PickerModel): ListRow everywhere, quick strength highlighted with the bolt holder (one line), templates with '5 gyakorlat' + chevron, cardio rows with tinted circles, 'Minden edzéstípus' with a control-circle icon only when the type list is synced, empty state = sync icon + the existing standalone_empty_hint. Large title via navigationTitle inside a NavigationStack + cancellationAction back chevron. ListRow got an explicit init (onClick second) plus isDisabled and .controlCircle. Selection/start logic (startTapped, templateTapped, cardioTapped, isStarting) untouched. Frames AW2.2, 2.4, 2.5. Not compiled.

### X2.3 — Watch iOS: all activity types (AW2.5) ✅
- `navigationTitle("Minden edzéstípus")` as a large title in the content that collapses into the nav bar
  on scroll (watchOS 10), never clipped; rows "Futás", "Séta", "Szobakerékpár" untruncated; "Egyéb kardió"
  with a `text2` icon.
- **Verify:** fixture; HU at 41 mm.

### X2.4 — Watch iOS: standalone active — mark and quick strength (AW2.6, AW2.8) ✅
- Header chip with the 26 pt standalone mark (`iphone.slash`, glyph `text2` on `control`, 44 target);
  quick strength (no plan): "Gyors erőedzés" + "3. szett · összesen 24 ismétlés" (`active_sets_free_format`)
  wrapping to two lines inside the card; the page never grows taller than the display. Log page as AW1.5
  with the mark in the header and the "Gyakorlatok" chip in the status slot; never an "unreachable" state
  (local logging).
- **Verify:** start quick strength standalone; fixtures.
- *As built:* X2.4 needed no new view: the standalone mark lives in WatchHeaderChip (26 pt glyph, 44 pt hit area) on the metrics, log, controls and rest pages, quick strength shows 'Gyors erőedzés' + active_sets_free_format through SetSegmentBar's free-form branch, and local logging never reaches the 'unreachable' state (LogPage.requiresPhone). X2.5: the existing isRetryingAdoption window (adoptionRetryFeedbackSeconds) now also shows a handoff StatusPill 'Folytatás a telefonon…' in the log page's status slot (new ⚑ key standalone_handoff_pending, HU+EN); the mark is already shown raised with the sync glyph while retrying. Frames AW2.6–2.8. Not compiled.

### X2.5 — Watch iOS: "sync now" tap feedback (AW2.7) ✅
- Tapping the mark (existing `retryAdoption()`) now shows: mark `raised` + `arrow.triangle.2.circlepath`
  for 1.5 s and a `handoff` pill "Folytatás a telefonon…" (⚑ `standalone_handoff_pending`, HU + EN) in the
  status slot. No behaviour change beyond the feedback.
- **Verify:** fixture; tap on a template-based standalone session with the phone reachable.

### X2.6 — Watch iOS: standalone summary + sync (AW2.9, AW2.10) ✅
- Check beside "Edzés mentve"; `SyncRow` directly under the title, **above the fold** ("Szinkronizálás a
  telefonra" + "2 edzés vár szinkronizálásra"); four compact tiles (idő, szett, átlag bpm, kcal) with
  one-line labels; Health row at the fold, complete when scrolled. Switches live to "Telefonra
  szinkronizálva" (success tint, 250 ms) when the phone acknowledges (unchanged trigger).
- **Verify:** fixtures; finish standalone with the phone off, then on.
- *As built:* SummaryContent: for a standalone summary the SyncRow sits directly under the title and the four tiles (idő, szett, átlag bpm, kcal) form a 2 × 2 grid; the Health row follows. The live pending→synced switch is the existing .standaloneSessionAcked handling in SummaryView; SyncRow animates the tint in 250 ms. Frames AW2.9 / 2.10. Not compiled.

### X2.7 — Watch iOS: cardio — distance and machine (AW2.11, AW2.12) ✅
- Distance: header chip "FUTÁS" in the accent (`figure.run`); "TÁVOLSÁG" label + hero **48 white** "3.42 km";
  HR as on strength (same slot and size); pace as a `CardioField` row ("5:23 /km TEMPÓ"); cycling km/h.
- Machine: hero "MOZGÁSIDŐ 24:10"; two **stacked** `CardioField` rows ("78 rpm KADENCIA", "165 W ÁTLAG
  TELJESÍTMÉNY") — phone labels complete, wrap to two lines; no side-by-side boxes.
- Replaces `DistanceMachineMetricsContent`, `CardioMetricBox`, `CardioHeartRateRow`.
- **Verify:** fixtures; a run and an indoor-bike session started from the phone.
- *As built:* One CardioContent (plain CardioModel) replaces DistanceMachineMetricsContent, GameMetricsContent, CardioHeartRateRow and CardioMetricBox: header chip in the activity accent, phone label + hero in white (dense hero for team sport), HeartRateSlot in the same place as on strength (so 'no HR' is just its missing state — the 86 % squeeze and the 2-line hint are gone; tap opens the explanation sheet), stacked CardioField rows, gross time in the HR row for team sport, 46 pt (44 compact) toggle button, bench = BenchFrame + clay gross time + text3 stopped play time. CardioActiveContent keeps the pager and draws BenchFrame instead of the old 5 pt rim. Field selection rules unchanged (distance shows the tertiary field only; machine shows secondary + tertiary; game shows secondary as gross time). Frames AW2.11–2.16. Not compiled.

### X2.8 — Watch iOS: team sport — field and bench (AW2.13, AW2.14, AW2.16) ✅
- Field: hero "JÁTÉKIDŐ 12:05" (dense hero, D-X0.5); gross time moved into the HR row on the right
  ("15:40 BRUTTÓ IDŐ"); "Padra" button 46 pt (from 66) under the thumb; everything fits without the old
  ~78 % squeeze; 41 mm: hero 40, button 44.
- Bench: `BenchFrame` (4 pt clay rim, kept as the strongest state signal); header "PADON"; stopped play
  time `text3` ("JÁTÉKIDŐ — ÁLL"), the still-ticking gross time clay; "Vissza a pályára" one line, 46 pt.
  Two-way toggle with the phone unchanged.
- Replaces `GameMetricsContent`.
- **Verify:** fixtures; basketball session field ↔ bench toggled from watch and phone.

### X2.9 — Watch iOS: cardio without HR (AW2.15) ✅
- `HeartRateSlot` missing state in the cardio layout; tap → the AW2.19 sheet; the page never exceeds the
  display (old ~86 % squeeze gone).
- **Verify:** fixture; run without HR samples.

### X2.10 — Watch iOS: Health access denied (AW2.17, AW2.18) ✅
- `StatusScreen`: 26 pt `waveform.path.ecg` without a box, title broken deliberately into two lines
  ("Engedélyezd az / Egészség-hozzáférést"), subtitle, "Engedélyek áttekintése" as a **control** button
  above the fold (it only steps back — no Settings API on watchOS). 41 mm: 2-line title, 4-line subtitle,
  button still visible; larger text → scrolls, button at the end.
- **Verify:** fixtures; deny Health access in the simulator.
- *As built:* HealthDeniedContent = StatusScreen (bare icon, ≤ 2-line title, subtitle, control button, scrolls on overflow). Deviation: the canvas breaks the title deliberately ('Engedélyezd az / Egészség-hozzáférést'); that needs a line break inside the existing string, i.e. a text-catalogue change that is not in the ⚑ list, so the title wraps naturally for now. Frames AW2.17 / 2.18. Not compiled.

### X2.11 — Watch iOS: AOD — metric page (AW2.20) ✅
- Under `isLuminanceReduced`: header chip outlined, hero "12 p" PJS 300 `text2`, HR @ 60 % with
  outlined heart, exercise as one quiet line "Fekvenyomás · 2/4"; kcal, card and buttons gone; no filled
  surface; `TimelineView(.everyMinute)`; back to full in ≤ 300 ms on wrist-raise.
- **Verify:** simulator Always On + lock; the full view returns with the correct live seconds.
- *As built:* Each Content view got an isAOD branch (frame 08): outlined chip/icons (LifeyAOD.symbol), hero in minutes (PJS Light → Bold fallback until the Light subset lands), HR and accents at 60 %, no fill, no kcal/card/buttons; rest shows '~1 p' + 'Mehet 9:42-kor' (end time = now + remaining, local zone) with a 2 pt outline line; cardio keeps the phone's distance decimal, collapses the field into one quiet line; the bench keeps a 2 pt rim, the stopped play time with seconds, gross time in minutes (parsed from the phone's 'mm:ss' string — falls back to the string if it cannot be parsed). Live pages switch from the 1 s TimelineView to MinuteTimeline (once a minute under reduced luminance). Also fixed a double side padding on the rest state introduced in X1.8. Frames AW2.20–2.23 (the gallery AOD toggle is not wired into the fixtures; they are rendered with isAOD = true). Not compiled; the wrist-raise ≤ 300 ms return needs a device.

### X2.12 — Watch iOS: AOD — rest (AW2.21) ✅
- "~1 p" hero (minutes, rounded up) + "Mehet 9:42-kor" (`aod_rest_until`, from `restEndsAtEpochMs` in the
  local zone) + "Következő …" line; the bar becomes a 2 pt `outline` line; per-minute refresh; the expiry
  haptic is independent (unchanged).
- **Verify:** lock during a rest; the end time matches the moment the haptic fires.

### X2.13 — Watch iOS: AOD — cardio and bench (AW2.22, AW2.23) ✅
- Cardio: distance keeps its decimal (it comes from the phone, not per second); accent @ 60 %; the field
  row collapses to one quiet line "5:23 /km · tempó".
- Bench: rim stays (2 pt, 60 %); stopped play time keeps seconds; gross time "Bruttó idő 16 p" (minutes).
- **Verify:** lock during a run and on the bench.

### X2.14 — Watch iOS: sweep the remaining Apple screens ✅
- Anything the canvases did not draw but the app has (e.g. the adoption / retry states in
  `ActiveWorkoutView`, `ContentView` transitions, empty exercise lists) moved onto the components and
  tokens; a short list of what was found goes into the *As built* note.
- **Verify:** grep in `mobile/ios/LifeyWatch/Views/` finds no hex literal, no `.font(.system(size:` on a
  number, no `opacity(0.75`, no legacy token name.
- *As built:* Sweep: the only remaining v1 usages were ActiveWorkoutView's black background and the old private HeaderChip (unused after X1/X2) — both gone; DynamicSizing's two call sites (ActiveWorkoutView, Cardio) read WatchMetrics directly. X2.15: LifeyColors / LifeyShapes legacy aliases removed, DynamicSizing.swift deleted with its pbxproj entries (id check: no dangling or duplicate ids). Grep for legacy colour/shape names and DynamicSizing under mobile/ios/LifeyWatch is empty. Remaining '.font(.system(size:' are icon glyph sizes, not numbers. Adoption/retry states were already moved onto the mark + handoff pill in X2.5; empty exercise lists need no UI (the chip is hidden). Wear parity test compares only D-X0.2 names, so removing the Swift aliases cannot affect it — to be confirmed by CI. Not compiled.

### X2.15 — Watch iOS: delete the legacy aliases and `DynamicSizing` ✅
- Files: `LifeyColors.swift` (aliases removed), `LifeyShapes.swift` (old names removed),
  `DynamicSizing.swift` deleted (pbxproj entries removed), the private structs superseded by components
  deleted. The Wear parity test (X0w.3) compares only the D-X0.2 names, never aliases, so removing the
  Swift aliases keeps it green without touching a Wear file — confirm on the PR's CI run.
- **Verify:** build with zero deprecation warnings from LifeyWatch sources; full X2 flow walk.

### X2.o1 — Watch iOS (optional, needs go-ahead §10 Q1): Smart Stack widget (AW2.24)
- New WidgetKit watch extension target, App Group shared with LifeyWatch; `accessoryRectangular`:
  workout name, elapsed, HR, current set; outside a workout a "Gyors erőedzés" launcher. Data from the
  watch's own state only.

### X2.o2 — Watch iOS (optional, needs go-ahead §10 Q1): complications (AW2.25)
- `accessoryCircular`: during rest the remaining time with a white ring, otherwise elapsed; a leaf launcher.
  Tinted faces colour it via the system.

**X2 review (§4.1) — done in the cloud (§4.3), Mac pass still owed; log in §12:** all AW2 frames incl. AOD; demo flows "standalone quick strength → summary → sync",
"run", "basketball field ↔ bench", "Health denied", wrist-down during metrics / rest / run / bench.

---

## X3 — Wear OS strength · `Lifey Watch 3 Wear OS Strength.dc.html` (W1.1 – W1.16)

**Goal:** the phone-driven strength workout on the round screen is fully on v2 and Material 3: same
hierarchy as Apple, platform-native layout (centred column, edge ring, EdgeButton, no corner arrows).

**Current code:** `ui/ActiveWorkoutScreen.kt` (`StrengthActiveWorkoutScreen`, `PageDots`, `LogPage`,
`LogCircle`, `AdjustCircle`, `LogStatusLine`, `LogStatusPill`, `AdjustOverlay`, `AdjustStepButton`,
`AdjustFieldSegment`, `MetricsOrRestPage`, `ControlsPage`, `ExerciseListChip`, `ExerciseListScreen`,
`ExerciseListRow`, `HeaderChip`, `HeartRateReading`, `MetricReading`, `ExerciseCard`, `GoFlash`,
`RestHero`), `ui/EffortSelectorScreen.kt`.

**Wear specifics (canvas 3 header):** no ending or summary screen for a phone-driven workout — after
"Edzés lezárása" the watch returns to idle (unchanged).

### X3.1 — Watch Wear: split ActiveWorkoutScreen into files with stateless content ✅
- Files: `ui/ActiveWorkoutScreen.kt` → `ui/active/{ActiveWorkoutScreen,MetricsPage,LogPage,AdjustOverlay,
  RestHero,ControlsPage,ExerciseList,Cardio}.kt`; each page gets a stateless `…Content(model, callbacks)`
  composable fed by the existing `SessionStateHolder` collection in the outer composable.
- No visual or behavioural change. Gallery "Frames" section with fixtures W1.1–W1.16.
- **Verify:** build + tests; a phone-driven session on the emulator pair behaves exactly as before.
- *As built:* Mechanical split by line range, no behavioural change: ActiveWorkoutScreen (dispatcher + strength state, constants, formatters), MetricsPage (metrics/rest page, ExerciseCard), LogPage (log + adjust), RestHero, ControlsPage, ExerciseList, Cardio (cardio screens + the legacy HeaderChip/MetricReading helpers until X4). Everything file-private became internal; cardioActivityIcon/Tint are imported by StandalonePickerScreen from the new package. Deviation: the stateless …Model/…Content split and the W1.x gallery fixtures are not done here — each page gets its Content when its own step (X3.3–X3.13) rewrites it, and registers its fixtures in galleryFrames then. Not compiled locally; CI is the compiler.

### X3.2 — Watch Wear: active scaffold — TimeText, pager, page indicator, rotary off ✅
- `StrengthActiveWorkoutScreen` inside `LifeyAppScaffold`/`LifeyScreen`; `LifeyPager` (3 pages, metrics
  default, **rotary does not page**); M3 `HorizontalPageIndicator` replaces `PageDots`; `TimeText` on top.
- **Verify:** crown on the metric page does nothing; swipe pages; the indicator hides under an EdgeButton.
- *As built:* StrengthActiveWorkoutScreen is wrapped in LifeyAppScaffold; the three pages sit in LifeyPager (wear-foundation HorizontalPager with rotaryScrollableBehavior = null, M3 HorizontalPageIndicator replaces PageDots, which stays only for the cardio screen until X4); TimeText is drawn directly on the pager branch (ScreenScaffold is only used by scrolling overlays, where the AppScaffold shows it). Unverified until the CI compile; the crown-does-nothing and indicator-hides checks are for the emulator pass.

### X3.3 — Watch Wear: metric page (W1.1, W1.4) ✅
- Header chip "ERŐEDZÉS"; hero 48 white; HR 16 → **28 sp** heart colour **with "bpm"** — level two, not the
  smallest element; kcal at `value`; instead of the card, a **narrow exercise block with `SetSegmentBar`**
  (new on Wear) inside the bottom chord. 192 dp: hero 40, metric 24, value 15, block 96 dp wide.
- **Verify:** fixtures at both sizes; live session.
- *As built:* MetricsPage.kt: MetricsModel + MetricsContent (stateless) and MetricsOrRestPage (the stateful wrapper; the old M2 rest hero is still used while resting until X3.9). Header = ActiveHeader (HeaderChip + the unchanged adoption-request tap on the standalone mark), HeartRateSlot, kcal at value level, ExerciseBlock = SetSegmentBar at half the dial width in the bottom chord (free-form sessions: name + the existing 'set n · reps total' line; no plan: the name only); the block still opens the exercise list. JUST_LOGGED segment (1.2 s success) comes from LogSetState.Confirmed. The old ExerciseCard stays until X3.11. Gallery: DesignGalleryActivity takes --ei width 192 and renders a frame at the chosen dial size; FramesW1.kt registers W1.1/W1.4 (more per step). Unverified until the CI compile.

### X3.4 — Watch Wear: paused (W1.2) ✅
- Header chip turns clay "SZÜNETELTETVE"; content does not shift toward the top arc; the pause still drives
  the local Health Services session (unchanged).
- **Verify:** fixture; pause from controls.
- *As built:* MetricsModel.isPaused = LiveMetrics.isPaused turns the HeaderChip clay 'SZÜNETELTETVE'; the hero/HR/kcal block is the same Column, so the content does not move toward the top arc (the old red 'Szüneteltetve' line under the hero is gone). The pause itself still drives the local Health Services session through ControlsPage (unchanged). Fixture W1.2.

### X3.5 — Watch Wear: HR permission slot + missing HR (W1.3, W2.16) ✅
- The broken heart + separate ellipsized chip are replaced by `HeartRateSlot` permission state (M3 Button
  44 dp, two deliberate lines, tap = system permission prompt) and the missing state (ghost heart, "—", ⓘ →
  `AlertDialog`). Delete the old `active_heart_rate_denied_chip` key (HU + EN) now that nothing uses it;
  `active_heart_rate_denied_placeholder` "--" goes too if unused.
- **Verify:** revoke `BODY_SENSORS` via `adb shell pm revoke`; grant through the slot; fixtures.
- *As built:* The broken-heart + ellipsized chip are gone: HeartRateSlot's permission state (M3 Button, two lines, tap = the existing RequestMultiplePermissions launcher with HEART_RATE_PERMISSIONS) and Missing state (ghost heart, 'nincs pulzus', ⓘ → AlertDialog) were wired in X3.3 via heartRateState(LiveMetrics); this step deletes active_heart_rate_denied_chip (HU+EN) and adds fixtures W1.3 and W2.16. active_heart_rate_denied_placeholder '--' stays: the cardio screen's legacy HeartRateReading still uses it until X4.

### X3.6 — Watch Wear: log page ready (W1.5) ✅
- Primary "+1" circle, `raised` "Módosítás" with clay `Tune` icon, labels under the circles (the "+1 szett"
  no longer breaks inside the circle); circles 85 → 78 dp so the pair stays inside the margin on the widest
  band; header `timer` + elapsed; next-set line.
- **Verify:** fixture; tap targets.
- *As built:* LogPage.kt: LogModel + LogContent (stateless) and the stateful LogPage. CircleButton gained centerText ('+1' in PJS), caption (inner 'n/total') and a11y; circles take WatchMetrics.circleButton (78/66 dp), labels under, 'Módosítás' = Raised with the clay Tune icon, header = timer + elapsed, line = 'exercise · next/total szett' (tap opens the exercise list when there is one — the old list chip is gone from this page). New string log_set_circle_label ('szett'/'set'). The reachability hint (hasConnectedNode) moved up to the strength screen because the pager must know whether a pill occupies the bottom arc; the 300 ms debounce is now CircleButton's DoubleTapGuard. The old LogCircle/AdjustCircle/LogStatusLine/LogStatusPill are deleted; the adjust overlay (old M2) stays in this file until X3.8. Fixtures W1.5–W1.7c.

### X3.7 — Watch Wear: logging states (W1.6, W1.7) ✅
- Ghosted pair while pending; success-tint circle with check + "Naplózva" pill on the bottom chord (where
  the page dots were); failed pill on two deliberate centred lines; "A telefon nem érhető el" neutral
  (nested + `text2`, `SignalWifiOff`); 60·80·60 ms and the failure pattern unchanged.
- **Verify:** fixtures; live with phone disconnected and with the backend down.
- *As built:* All four states live in LogContent (built with X3.6): pending/failed/unreachable ghost the pair (CircleButton.isGhosted → ghosted tone, not just lowered alpha), confirmed = SuccessTint circle with check and 'n/total', one StatusPill on the bottom chord by priority failed › unreachable › pending › logged (logPillKind), and LifeyPager hides the page indicator under it. This step adds the deliberate break after the dash in the failed text ('Nem sikerült —' / 'próbáld újra'). The 60·80·60 ms success and the failure haptics are untouched (LifeyHaptics via ExerciseService). Fixtures W1.6/W1.7/W1.7b/W1.7c.

### X3.8 — Watch Wear: stepper with EdgeButton (W1.8, W1.9) ✅
- Clay header only; segmented "Ismétlés | Súly" short and centred; ± on the widest band inside the
  margin; **EdgeButton** "8 ismétlés naplózása" on the bottom arc replaces the full-width chip (the dense
  stepper fix — nothing overhangs the comfortable zone). 192 dp: number 34 sp, ± 40 / 48. Rotary ≈ 24 dp =
  one step + `EFFECT_TICK` (unchanged).
- **Verify:** fixtures; rotary on the emulator; "102,5" at 192 dp.
- *As built:* AdjustOverlay.kt: AdjustContent (stateless) + the stateful AdjustOverlay inside DismissibleOverlay (swipe/back = SessionStateHolder.onLogAdjustCancelled, never finishes the activity). Clay HeaderChip, short 'Ismétlés | Súly' segment, ValueStepper (± 44/40 dp visible, ≥ 48 target, value in PJS, rotary 24 dp = one step) with the not-edited value as its unit caption, and the EdgeButton '{n} ismétlés naplózása' placed on the bottom arc by the screen (not inside the stepper). SessionStateHolder keeps the real step/clamping; ValueStepper only mirrors the bounds for its ghosted buttons and gained tickOnStep=false so the stepper does not buzz twice (ExerciseService already ticks on every logAdjustState change). The three old M2 composables (AdjustCircle row, AdjustStepButton, AdjustFieldSegment) and ADJUST_ROW_WIDTH_FRACTION are dead and removed with the old file body. Fixtures W1.8/W1.9.

### X3.9 — Watch Wear: rest edge ring (W1.10, W1.11) ✅
- `RestRing` (6 dp at the display edge) replaces the horizontal bar; centred hero "0:47" + "/ 1:30";
  "Következő · …" on two centred lines; HR + kcal row; last 5 s calories colour + pulse. The 400 ms expiry
  vibration stays in the foreground service.
- **Verify:** fixtures; live rest; ring tracks `elapsedRealtime` after a pause/resume.
- *As built:* RestHero.kt: RestModel + RestContent on RestRing (RestRing gained heroOffset and showTotal); 'Következő ·' / 'exercise — n/total. szett' as two deliberate centred lines; HR + kcal at value level on the bottom chord, missing/denied HR = ghost heart + dash (one rule). The countdown still floors remaining ms to whole seconds exactly like the old formatElapsed and is driven by the existing elapsedRealtime LaunchedEffect (restRemainingMs), so it tracks real time after a pause/resume; the last-5-s calories colour + 1 Hz pulse live in RestRing. The old horizontal-bar RestHero is deleted; the page still opens the exercise list on tap. Vertical positions are width fractions (header 14 %, hero centre 41 %, next line 67 %, metrics 13 % from the bottom) and need the emulator check at 227/192 dp. Fixtures W1.10/W1.11.

### X3.10 — Watch Wear: "Mehet!" ring (W1.12)
- 9 dp primary ring where the rest ring drained, white "Mehet!", 150 / 250 / 700 ms over the pager.
- **Verify:** expire a rest on each page; animations off = static 1.1 s.

### X3.11 — Watch Wear: controls (W1.13, W1.14)
- The two stacked M2 chips + decorative exercise card become the same two circles as Apple ("Vége" error
  tint, "Szünet" control); paused: "Folytatás" primary + a **secondary EdgeButton** "Gyakorlatok" (only
  with 2+ exercises; the page indicator hides under it). The card disappears (it was meaningless on cardio).
- **Verify:** fixtures; pause → resume → end.

### X3.12 — Watch Wear: exercise list (W1.15)
- `DismissibleOverlay` — **no top-left arrow**, back = swipe / hardware back; `TransformingLazyColumn`
  with `lifeyTransformationSpec()`; rows = M3 Button pills "Fekvenyomás 2/4 szett"; selected = `raised` +
  check; `ScrollIndicator`; rotary scrolls; tap switches immediately.
- **Verify:** fixture; swipe-back does not close the activity.

### X3.13 — Watch Wear: effort (W1.16)
- `EffortScale` (white number, 10 segments), "Kihagyás" 40 dp real button, "Edzés lezárása" EdgeButton;
  back = swipe-to-dismiss → back to the workout (replaces the invisible corner arrow). Rotary 1–10.
- **Verify:** fixture; end with and without effort; swipe back returns to the controls page.

**X3 review (§4.2):** all W1 frames at 227 / 192 dp; demo flow "full phone-driven strength session";
permission revoke/grant; failure paths.

---

## X4 — Wear OS start, error, standalone, cardio, ambient · `Lifey Watch 4 Wear OS Start Standalone Cardio.dc.html` (W2.1 – W2.19)

**Goal:** every remaining Wear screen on v2/M3, ambient variants, Material 2 and the legacy tokens deleted.

**Current code:** `ui/IdleScreen.kt` (`LeafMark`), `ui/StandalonePickerScreen.kt`, `ui/ErrorScreen.kt`,
`ui/SummaryScreen.kt` (`StatTile`, `SyncChip`), the cardio composables from X3.1's `ui/active/Cardio.kt`,
`MainActivity.kt`.

### X4.1 — Watch Wear: idle (W2.1)
- 32 dp compact chip → **52 dp M3 Button** "Edzés indítása"; Material `Icons.Filled.Eco` replaces the
  hand-drawn `LeafMark` (one source for both platforms); PJS "Lifey"; `TimeText`.
- **Verify:** fixture; tap → picker.

### X4.2 — Watch Wear: picker (W2.2)
- Every row an M3 Button pill (`ListRow`), including quick strength (highlighted: `raised` + icon circle);
  no corner arrow (swipe back to idle); `TransformingLazyColumn` (≤ 12 % shrink); the Chip + card mix gone.
- **Verify:** fixture; with and without synced templates (empty hint as Apple AW2.4, centred).

### X4.3 — Watch Wear: all activity types (W2.3)
- Same pill rows; title inside the top chord (14 sp, one line) that slides under `TimeText` when scrolled.
- **Verify:** fixture; HU at 192 dp.

### X4.4 — Watch Wear: "another workout is running" (W2.4)
- `StatusScreen`: `PriorityHigh` in a calories-tint circle (warning = calories, replaces the v1 `negative`
  orange); title on two deliberate lines; text; "Rendben" as a **control** EdgeButton (acknowledge only).
- **Verify:** fixture; trigger with another exercise app running (as in docs/watch/40 §11).

### X4.5 — Watch Wear: standalone active — mark and quick strength (W2.5)
- 24 dp mark (48 target, today ≈ 16); free-format summary on two centred lines (no "összesen 2…" clipped by
  the circle).
- **Verify:** start quick strength standalone; fixture.

### X4.6 — Watch Wear: sync tap feedback + template header (W2.6)
- The existing 1.5 s sync icon now sits on a `raised` mark background (visible); the template name in the
  header ≤ 14 characters + ellipsis, the full name at the top of the exercise list.
- **Verify:** fixture; tap the mark with the phone reachable.

### X4.7 — Watch Wear: standalone log page (W2.7)
- Header, set line, circles at **74 dp**, secondary EdgeButton "Gyakorlatok" — four rows + two circles no
  longer push onto the bottom arc; no "unreachable" state (local logging).
- **Verify:** fixture; log sets standalone.

### X4.8 — Watch Wear: standalone summary + sync (W2.8, W2.9)
- Check beside the title; `SyncRow` right under it in the widest band; four compact centred tiles; fits at
  full size (old ~85 % squeeze gone); pending (nested) ↔ synced (success tint) live on screen; ≈ 6 s to idle
  (unchanged). No Health row on Wear (the phone writes Health Connect — unchanged).
- **Verify:** fixtures; finish standalone with the phone off, then on.

### X4.9 — Watch Wear: cardio — distance and machine (W2.10, W2.11)
- Distance: hero 30 → **48 sp white**, HR 28 sp (as on strength; today 24 vs 16); pace boxless, centred on
  the bottom chord; km/h for cycling.
- Machine: two boxless values side by side, phone labels under them wrapping to two lines ("ÁTLAG /
  TELJESÍTMÉNY"), no "ÁTLAG TELJESÍ…".
- Replaces `DistanceMachineMetricsContent`, `CardioMetricBox`, `CardioHeartRateRow`; the cardio controls
  page loses the meaningless "Gyakorlat" card (via X3.11's `ControlsPage`).
- **Verify:** fixtures; run + indoor bike from the phone.

### X4.10 — Watch Wear: team sport — field and bench (W2.12, W2.13, W2.15)
- Field: gross time beside HR, boxless; "Padra" EdgeButton; header + label + hero + row + button at full
  size (old ~76 % squeeze gone). 192 dp: hero 38, EdgeButton 46 dp (48 target with the arc extension).
- Bench: clay `BenchRing` (the round shape is an advantage here); EdgeButton inside the ring, "Vissza a
  pályára" one line with the activity icon.
- **Verify:** fixtures; basketball field ↔ bench from watch and phone.

### X4.11 — Watch Wear: cardio without HR, incl. permission route (W2.14)
- `HeartRateSlot` in the cardio layout; when the cause is a missing permission the slot is the permission
  button as on strength (W1.3) — a new route to the existing request (§1.7).
- **Verify:** fixture; run with `BODY_SENSORS` revoked, grant from the slot.

### X4.12 — Watch Wear: sweep the remaining Wear screens
- What the canvases did not draw (adoption/retry states, transient loading, empty exercise list) moved to
  components and tokens; listed in the *As built* note.
- **Verify:** grep in `ui/` finds no `Color(0x`, no `.sp` literal on a number, no legacy token name.

### X4.13 — Watch Wear: ambient — metric page (W2.17)
- The active screen opts in to ambient (`LocalAmbientState`): hero "12 p" PJS Light `text2`, HR @ 60 %
  with `Icons.Outlined.FavoriteBorder`, quiet exercise line; no buttons, pills, indicator, TimeText in
  ambient style; ±4 dp shift per minute; on exit the live seconds are recomputed (no stale frame).
- **Verify:** emulator ambient; exit restores the live view.

### X4.14 — Watch Wear: ambient — rest (W2.18)
- Edge ring as a 2 dp `text3` outline; "~1 p" + "Mehet 9:42-kor"; per-minute refresh; the expiry vibration
  stays in `ExerciseService`.
- **Verify:** ambient during rest; the end time equals the vibration moment.

### X4.15 — Watch Wear: ambient — bench and cardio (W2.19 + derived)
- Bench: clay ring 2 dp @ 60 %; stopped play time with seconds; gross time in minutes; no buttons.
- Cardio: **no Wear canvas frame** — derived from AW2.22 (distance with its decimal, accent @ 60 %, one quiet
  field line), centred; noted as a derived layout in the review log.
- **Verify:** ambient during bench and during a run.

### X4.16 — Watch Wear: remove Material 2, legacy aliases and `DynamicSizing`
- Files: `build.gradle.kts` (drop `androidx.wear.compose:compose-material`), `LifeyTheme.kt` (M3 only),
  `LifeyColors.kt` / `LifeyShapes.kt` aliases removed, `ui/DynamicSizing.kt` deleted, superseded private
  composables deleted.
- **Verify:** `./gradlew :wear:assembleDebug :wear:testDebugUnitTest` green; `./gradlew :wear:dependencies`
  shows no `compose-material:` (M2); full X4 flow walk.

### X4.o1 — Watch Wear (optional, needs go-ahead §10 Q2): launcher Tile (W2.20)
- `TileService` with ProtoLayout Material 3: "Gyors erőedzés" + the first ranked template, from the
  already-synced local cache.

### X4.o2 — Watch Wear (optional, needs go-ahead §10 Q2): Ongoing Activity (W2.21)
- `OngoingActivity` bound to the existing foreground notification: icon on the watch face (ring during
  rest), tap = back to the workout.

**X4 review (§4.2):** all W2 frames incl. ambient at 227 / 192 dp; demo flows as X2's on Wear; M2 gone.

---

## 5. Order of work and milestones

| Milestone | Steps | You can look at |
|---|---|---|
| M0 | X0.0 | All five canvases open from the repo |
| M1 | X0a.1–X0a.11 + review | Apple on the v2 palette; gallery with all 15 components |
| M2 | X0w.1–X0w.14 + review | Wear on the v2 palette + M3; gallery; CI job; parity test |
| M3 | X1.1–X1.14 + review | **Smallest worth using (Apple):** phone-driven strength fully redesigned |
| M4 | X3.1–X3.13 + review | **Smallest worth using (Wear):** phone-driven strength fully redesigned |
| M5 | X2.1–X2.15 + review | Apple complete: start, standalone, cardio, errors, AOD; legacy deleted |
| M6 | X4.1–X4.16 + review | Wear complete: start, error, standalone, cardio, ambient; M2 deleted |
| (M7) | X2.o1–o2, X4.o1–o2 | Optional surfaces, only after a go-ahead |

Tracks: Apple = M1 → M3 → M5 (Mac sessions); Wear = M2 → M4 → M6 (Windows + emulators). Hard
dependency across tracks: X0w.3 needs X0a.1 only.

---

## 6. Non-goals (deferred)

- Smart Stack widget, complications, Tile, Ongoing Activity — optional steps, only on a go-ahead (D-X0.16).
- Any new data on screen that the watch does not already have (prompt "Keretek"): no new protocol fields,
  no backend change, no phone-app change.
- A light theme on the watch (AMOLED, dark only).
- An ending/summary screen for phone-driven workouts on Wear (unchanged platform difference).
- A Settings deep link on Apple (no watchOS API; the Health-denied button only steps back).
- A note field on the effort screen (the watch never collected one).
- PJS for text other than numerals and the "Lifey" wordmark.
- Screenshot golden tests on either platform (D-X0.11).
- An XCTest target for the watch app (D-X0.11; revisit if Apple-only pure logic grows).
- Redesigning the phone-side watch settings / pairing UI (mobile redesign territory).

---

## 7. Edge cases

- **Very long exercise / template names** (HU and seeded EN): two-line wrap on the exercise card, picker,
  "Következő" line; Wear header template name ≤ 14 chars + ellipsis (W2.6) — the full name must be
  reachable in the exercise list.
- **Weight values 4+ characters** ("102,5", "500") at 41 mm / 192 dp — min scale 0.85, never truncated.
- **More than 8 sets** — `SetSegmentBar` stays readable up to 8; above 8 it shows the text "9/12" only.
- **Quick strength (no plan)** — no segment bar; free-format summary; the "Gyakorlatok" chip hidden.
- **One-exercise templates** — "Gyakorlatok" chip / EdgeButton hidden (2+ only, unchanged).
- **HR samples stop mid-workout** — slot switches to missing without moving anything; resumes in place.
- **HR permission granted while on the metric page** (Wear) — slot returns to live without a restart.
- **Rest started while on the log or controls page** — countdown appears on the metric page; the flash
  shows over whichever page is visible.
- **Rest shorter than 5 s** — the last-5 s style applies immediately; no negative numbers.
- **Rest across midnight in AOD** — end time in the local zone; DST change during rest uses the epoch.
- **AOD with < 60 s left** — "~1 p" (rounded up), never "0 p" while rest runs.
- **Elapsed ≥ 1 h** — live "1:05:12" (hero width tabular; fits at 41 mm / 192 dp), AOD "1 ó 05 p".
- **Status pill collisions** — failed during a "Naplózva" display: failed wins and stays 2.5 s.
- **Phone reachable again while "unreachable" pill shows** — pill clears on the next state update.
- **Largest text size / font scale 1.3** — numbers stop at 115 %, text wraps; active pages still fit; the
  Health-denied screen scrolls with the button at the end.
- **Reduced motion** — every animation lands on its end state; "Mehet!" static 1.1 s; pulse off.
- **Wear swipe-right on the first pager page** mid-workout — must not dismiss the activity unexpectedly
  (today's behaviour is the baseline; verify after `LifeyPager`).
- **Wear rotary on the stepper** — steps the value, never pages behind the overlay.
- **Tinted watch faces / AOD colour** (Apple) — outlined symbols and 60 % metric colours stay legible.
- **Standalone mark tap with the phone unreachable** — feedback still shows 1.5 s; the pill must not claim
  a handoff that is not happening: on Apple show the `handoff` pill only when `retryAdoption()` actually
  sends (check its return/state), otherwise the `unreachable` pill.
- **EN strings** — "Continuing on the phone…", "Go at 9:42 AM" (12-hour EN time) fit the same slots.

---

## 8. Test plan and PR split

| Layer | What | Where |
|---|---|---|
| Wear JVM unit | Contrast (all text tiers, tints, onPrimary); Swift ↔ Kotlin token parity; font glyph coverage + byte-identity; `WatchMetrics` table and boundaries; chord width; ambient formatting (minutes, hours, rest-until across midnight, rounding up); `StatusPill.priority`; HR-slot state derivation (live / missing / permission) from the existing state | `mobile/android/wear/src/test/`, run in CI (X0w.4) |
| Wear previews | Every component × state at 227 / 192 dp, font scales | `@WearPreviewDevices`, `@WearPreviewFontScales` |
| Wear gallery | Every component and every W frame fixture; `adb`-addressable | `src/debug/…/DesignGalleryActivity` |
| Apple build | `xcodebuild` per step; DEBUG font assertion | Mac session |
| Apple previews + gallery | Every component and AW frame at 45 / 41 mm | `#Preview`, `DesignGalleryView` |
| Manual — Apple | §4.1 matrix per iteration | Simulators (+ one physical-watch pass before merging to main, §10 Q5) |
| Manual — Wear | §4.2 matrix per iteration | Emulators (+ physical device if available) |
| Flows | Phone-driven strength; standalone strength → sync; run; indoor bike; basketball field ↔ bench; HR missing / permission; Health denied; "already running"; AOD/ambient | Iteration reviews |

**PR split:** one long-lived PR `feature/watch-redesign → main` (the mobile and web precedent); one commit
per step (§4); the PR description carries a checklist of the six (sub-)iterations with the platform in
each line, ticked when its review is logged in §12. If review load demands it, the PR can be cut after M4
(both strength flows) and the rest continues on a follow-up branch — both cuts leave `main` consistent
(D-X0.1).

---

## 9. Risk checkpoints where a failure would be silent

1. **Token drift between Swift and Kotlin.** A hex changed on one side renders a slightly different colour
   with no error. → `TokenParityTest` in CI (X0w.3–4); reviewers check both files change together.
2. **Font subset missing a glyph.** "−" (U+2212), "—", NNBSP or "~" missing → the system silently falls
   back for that glyph and numbers look mixed. → `FontCoverageTest`; the review checks "−0,4", "—",
   "~1 p" visually.
3. **Wrong PostScript name / missing `UIAppFonts` on Apple.** `Font.custom` falls back to SF silently. →
   DEBUG start-up assertion (X0a.3); review compares the "1" and "4" shapes (PJS vs SF differ clearly).
4. **Double logging after the log-page refactor.** If the ghosted pending state or the 300 ms guard is lost
   in X1.1/X1.6 or X3.1/X3.7, a double tap logs two sets — data, not an error. → move the guard as a
   unit, test double-tap in the flow review, check the phone's set count.
5. **Haptics moved behind screen visibility.** Wrapping the vibrations could tie them to a composable /
   view lifecycle and they stop firing with the screen off. → D-X0.14 rule; review the rest-expiry haptic
   with the wrist down (AOD) and the app backgrounded.
6. **Rest end time off by the zone or rounding.** AOD shows "Mehet 9:42-kor" while the haptic fires at
   9:43, or "0 p" while resting. → `AmbientFormatTest` (zone, midnight, ceil); review compares with the
   haptic moment.
7. **Stale seconds after leaving AOD/ambient.** The first frame after wrist-raise shows the minute-old
   value. → recompute on exit (X2.11, X4.13); review raises the wrist mid-minute.
8. **Status pill priority inverted.** A late "Naplózva" hides a "Nem sikerült" → the user thinks the set
   was saved. → `StatusPill.priority` unit-tested (Wear) and mirrored line-for-line (Apple).
9. **HR "missing" vs "permission" misclassified on Wear.** A denied permission shown as "nincs pulzus"
   leaves the user with no way to fix it. → HR-slot derivation test; review revokes the permission.
10. **Rotary paging switched off too broadly.** Disabling rotary on the pager also kills the stepper or
    list scrolling → the stepper silently stops responding to the crown. → review rotates on every overlay.
11. **Swipe-to-dismiss closes the activity mid-workout (Wear).** The service keeps recording, but the
    user lands on the watch face and thinks the workout ended. → review swipes on every overlay and on
    page 0.
12. **Text clipped by the round edge.** Nothing errors when text sits outside the circle. → chord rule +
    review at 192 dp in HU with font scale 1.3.
13. **Cardio accents left on v1 hexes** because the canvas shows them. → D-X0.2 note; parity test checks
    the names, the review checks the run/walk icon colours against the mobile app.

---

## 10. Open questions (decide before the step, not blocking the plan)

- **Q1 (before X2.o1/o2):** go-ahead for the Smart Stack widget and complications (new WidgetKit target,
  App Group, separate signing setup)?
- **Q2 (before X4.o1/o2):** go-ahead for the Tile and the Ongoing Activity?
- **Q3 (X4.6):** should Wear also show the "Folytatás a telefonon…" pill on a mark tap, as Apple does
  (AW2.7)? The Wear canvas (W2.6) draws only the raised mark. Default: follow the canvas (no pill).
- **Q4 (X0a.3):** fetch PlusJakartaSans-Light from the upstream OFL release for the AOD numerals (default),
  or use the Regular (400) already in the repo and accept a heavier AOD (more lit pixels)?
- **Q5 (before merging to main):** is a physical Apple Watch / Wear OS pass required, or are simulators
  and emulators enough for this release-less app (memory: app not released)?

---

## 11. After implementation

- `docs/redesign-watch/README.md`: status "done", iteration table ticked (created in X0.0).
- `docs/watch/41-watch-design-prompt.md` §2 and `docs/watch/42-watch-design-implementation-plan.md`: a
  "superseded by 79" note at the top of the visual sections (values only; behaviour specs stay).
- `docs/watch/40-watch-app-plan.md` §12.1 B4 / B6 (dynamic sizing, tokens): pointer to D-X0.5 / D-X0.2.
- `docs/cardio/55-cardio-watch-plan.md` §2 (accent colours): pointer to D-X0.2.
- Code comments that cite `41-watch-design-prompt.md` §2 for colour values updated to cite this plan.
- Follow-ups: optional surfaces if not done; a physical-device pass if Q5 deferred it.

---

## 12. Review log

*One entry per iteration review (§4.1 / §4.2). Template:*

```
### X<n> review — YYYY-MM-DD
Environment: Xcode / watchOS sim versions (Apple) or emulator images + AVDs (Wear); languages; text sizes
Frames checked: …
Matches: …
Deviations (intended): … (decision id)
Bugs: X<n>.fix-1 … (open / fixed in <commit>)
```

### X0a review — 2026-10-02 (cloud session, §4.3 method)
Environment: no Xcode; Chromium via Playwright; widths 198 / 176 pt; HU sample strings
Frames checked: DS 01 (tokens), 03 (metrics), 04 (all 15 components)
Matches: all 17 token hexes in `LifeyColors.swift` are present in the canvas (`tokens_check`); metric table
reproduced at 198 / 176 (hero 48/42, metric 28/25, value 19/17, circle 78/70, button 48/44, margin 16/14);
component structure and colour roles follow frame 04.
Deviations (intended): `sensitivity: .high` on the stepper crown (existing finding); components
`WatchHeaderChip` / `WatchMetricReading` named to avoid clashing with the old private types; Light 300
subset not bundled (needs OK, Q4).
Bugs: X0a.fix-1 — `SetSegmentBar` had "2/4" beside the bar; canvas has name left / "2/4" right over a
full-width bar → fixed. Open for a Mac pass (could not be checked here): real compile, `UIAppFonts`
registration of the two subsets, crown stepper feel, DS 04/04 shows the label *inside* the 66 pt circle
while AW1.5 puts it under it (decide at X1.5), DS 04/15 sample stacks value over label while the note says
one row (decide at X2.7).


### X0w review — 2026-10-02 (cloud session, §4.3 method — no Android SDK, no Google Maven, no emulator)
Environment: Linux sandbox; Gradle 8.14 + Kotlin 2.0 JVM scratch project for the pure logic; fontTools; Python
Frames checked: DS 01 tokens, 02 type, 03 metrics, 04 components (same canvas file as X0a), 08 ambient strings
Executed (real runs): `AmbientFormatTest` 4/4 and `WatchMetricsTest` 5/5 compiled and run on the JVM from the
repo's own sources (Dp replaced by a shim); token parity Kotlin ↔ Swift: 22 tokens, 0 mismatches (script);
contrast pairs computed independently in Python — all ≥ 4.5 (lowest: text3 on nested 4.75); font coverage by
fontTools — all numeral glyphs present in both subsets.
Not executed (could not be): `ContrastTest`, `TokenParityTest`, `FontCoverageTest` as JUnit (they need the
Android/Compose classpath); every Compose file (M3 `Button`, `EdgeButton`, `AlertDialog`,
`CircularProgressIndicator`, `AppScaffold`, `ScreenScaffold`, `HorizontalPageIndicator`,
`SwipeToDismissBox`, `TransformingLazyColumn` signatures and the `compose-material3:1.6.2` artifact were
written from memory); the 227 / 192 dp gallery screenshots; the CI step.
Matches: hex values and size tables as above; component structure mirrors the Apple components that were
compared with canvas frame 04 in the X0a review.
Deviations (intended): edge-row transformation recorded as constants, library default used (X0w.9); NNBSP
dropped from the glyph set (source font lacks it); Light 300 not bundled (Q4); CI added as a step of the
existing job instead of a new job (X0w.4).
Bugs: none found by the runs above. Open for the Windows pass: first `./gradlew :wear:assembleDebug
:wear:testDebugUnitTest` — expect compile errors in the M3 call sites, fix as `X0w.fix-k`; then create the
192 dp AVD, walk the gallery, check the release manifest has no gallery activity.


### X1 review — 2026-10-02 (cloud session, §4.3 method — no Xcode, no simulator)
Environment: Chromium/Playwright; canvas `Lifey Watch 1 Apple Watch Strength.dc.html` rendered headless (fonts blocked, icons show as names); HTML reconstruction of the frames from the Swift layout values, 198 pt
Frames checked: AW1.1, 1.5, 1.7, 1.10, 1.13, 1.17 (canvas screenshot vs reconstruction); the other frames (1.2–1.4, 1.6, 1.8, 1.9, 1.11, 1.12, 1.14–1.16, 1.18–1.22) only by reading the canvas markup against the code
Matches: structure and order of every compared frame (hero › HR › kcal › card with segment bar; log page: next-set line, primary "+1" with the label under it, raised "Módosítás", one bottom slot; success circle + "Naplózva" pill; stepper: clay header, segmented switch, ± around the value, caption, primary pill; rest: number over a white bar, "Következő" two lines, HR + kcal row; controls: error-tint + control circle). Metric numbers carry the metric colour as in the canvas (found and fixed during the step: the first component draft used white numbers).
Deviations (intended): crown no longer pages the TabView (D-X0.9); `AW1.5` label under the "+1" is derived from `log_set_button` by dropping "+1" (no new key); summary check-pop and 60 ms tile stagger not implemented; the nav back button is a `cancellationAction` toolbar item.
Bugs: none found by the comparison. Open for the Mac pass (could not be exercised): compile of everything in Views/Active, Views/Components and the three rewritten screens; the file-split `private` → internal change (name clashes would show up as redeclaration errors); the `CircleButton` inside `TabView(.page)` (taps vs page swipes); the `cancellationAction` back button size; "102,5" on 41 mm; the three failure paths (phone unreachable, logging failed, backend down); reduced-motion end states; haptic moments.


### X2 review — 2026-10-02 (cloud session, §4.3 method — no Xcode, no simulator)
Environment: Chromium/Playwright; canvas `Lifey Watch 2 Apple Watch Start Standalone Cardio.dc.html` rendered headless (fonts blocked, icons show as names)
Frames checked: AW2.13, AW2.21, AW2.9 (canvas screenshots against the Swift layout); the rest read from the canvas markup against the code
Matches: team-sport field (header chip, label + hero, HR row with the gross time on the right, toggle at the bottom), AOD rest ("~1 p", "Mehet 9:42-kor", 2 pt line, "Következő" text), standalone summary (check beside the title, sync row under it, 2 × 2 tiles).
Fixes from the comparison (X2.fix-1): the on-court play-time label gets the small primary dot (AW2.13); in the AOD rest the "Következő …" line moved to the bottom (AW2.21).
Deviations (intended): no deliberate title line break on the Health-denied screen (needs a text-catalogue change that is not in the ⚑ list); gross-time minutes in the bench AOD are parsed from the phone's "mm:ss" string; the optional Smart Stack widget / complications (X2.o1, X2.o2) were not started — they need your go-ahead (§10 Q1).
Bugs: none open from the comparison. Open for the Mac pass (could not be exercised here): compile of the whole target; picker large-title collapse and nav back button; `MinuteTimeline` really refreshing once a minute under Always On and returning within 300 ms on wrist-raise; `isLuminanceReduced` in the live pages (only fixtures were exercised); the three demo flows (standalone quick strength → summary → sync, a run, basketball field ↔ bench) and Health denied; sync pill/mark timing (adoptionRetryFeedbackSeconds is the existing value, the plan said 1.5 s).

### X0w.fix-1 — 2026-10-02 (first real compile, from the CI log of run 266)
`flutter build apk` builds the `:wear` module too, so the Wear code is compiled on every Mobile CI run (and its errors fail the *Build APK* step). The first compiler output confirmed that `androidx.wear.compose:compose-material3:1.6.2` resolves, and listed 38 errors, all in call sites written from memory: `androidx.compose.material3.Icon` does not exist in this module (→ `androidx.wear.compose.material.Icon`), `AlertDialog(show =` is `visible =`, the Wear pager state is `androidx.wear.compose.foundation.pager.PagerState`, `SwipeToDismissBox` is not in wear-foundation 1.6.2 (→ the Material 2 one, still on the classpath), `ScreenScaffold.edgeButton` is not nullable (two branches), and a top-level property initialisation order in the gallery. Fixed in one commit; more errors may surface behind these.

### X0w.fix-2 — 2026-10-02 (CI run 285, after fix-1)
After fix-1 the Wear module's compiler output shrank from 38 errors to one: the Material 2 `SwipeToDismissBox` takes the *foundation* `SwipeToDismissBoxState`, so `rememberSwipeToDismissBoxState` has to come from `androidx.wear.compose.foundation`, not `androidx.wear.compose.material`. Import swapped. (Each CI cycle is ~15 min because `flutter build apk` runs the Flutter tests first.)

### X0w.fix-3 — 2026-10-02 (CI run for fix-2)
The whole Wear module compiled for the first time (`:wear:assembleDebug` up to date; the one remaining main-source error was fixed by fix-2). The unit-test compile then failed: `java.awt.Font` is not on the Android unit-test classpath. `FontCoverageTest` now reads the TTF `cmap` table itself (a 40-line format-4 reader); run on the real font files in a scratch JVM project it passes 4/4 (glyph coverage of both subsets, wordmark glyphs, Apple/Wear byte identity, font-scale clamp).

### X0w.fix-4 — 2026-10-02 (CI run 287)
The Wear unit tests ran for the first time: 17 of 18 passed (contrast, metrics, ambient formatting, font coverage). `TokenParityTest` failed with `NoSuchMethodException`: `Color` is an inline value class, so `LifeyColors`' getters are name-mangled and reflection cannot find them. The test now uses an explicit name → `Color` map (22 tokens) and fails if the Apple file has a token the map lacks — so a new token still has to be added on both sides.
