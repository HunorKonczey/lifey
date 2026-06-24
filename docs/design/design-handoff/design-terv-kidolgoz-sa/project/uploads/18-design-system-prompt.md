# Lifey – Modern Design System & Redesign Prompt

> **Purpose of this file:** a single, self-contained prompt you can hand to Claude
> (or any capable design/implementation agent) to produce a complete, modern visual
> redesign of the Lifey Flutter app. It is written so the same agent can *implement*
> the result in the existing codebase — it documents every screen, feature, tool,
> and constraint, plus the explicit design direction the product owner asked for.
>
> Stack reminder: **Flutter + Material 3**, state via `flutter_riverpod`, routing via
> `go_router` (`StatefulShellRoute.indexedStack`), offline-first local cache via
> `drift`, charts via a **custom** `TimeSeriesChart` (no `fl_chart`), i18n via
> `flutter_intl` (English + Hungarian, never hardcode strings — add ARB keys).

---

## 0. The prompt (copy/paste this to start)

> You are redesigning **Lifey**, an offline-first personal fitness & nutrition
> tracker built in Flutter (Material 3, Riverpod, go_router, drift). Produce a
> cohesive **modern dark-first design system** and apply it across every screen
> listed in §3. You will also implement it, so every proposal must be buildable
> with the existing stack — no new heavy dependencies without justification, no
> hardcoded strings (use the ARB/`AppLocalizations` keys), never edit `*.g.dart`.
>
> Deliver, in order:
> 1. A **design system** (§2): color tokens, typography scale, spacing, radius,
>    elevation/shadow, iconography, motion. Centralize it in
>    `lib/core/theme/app_theme.dart` as a real `ColorScheme` + `ThemeData` (stop
>    using a bare `colorSchemeSeed`). Add a `lib/core/theme/app_tokens.dart` for
>    semantic tokens (spacing, radii, durations) if helpful.
> 2. The **adaptive navigation chrome** (§1) — the collapsing bottom bar and the
>    slim top bars are the headline feature; build these as reusable shared
>    widgets and wire them into `MainShell` and each screen's `AppBar`.
> 3. Per-screen redesign notes + the actual widget changes (§3).
>
> Honor the **non-negotiable visual direction** in §1 and §2.1 exactly.

---

## 1. Non-negotiable visual direction (product owner's brief)

These are explicit requirements — treat them as acceptance criteria.

### 1.1 Dark, high-contrast, brown-green identity
- **Dark theme is the hero.** Deep, genuinely dark background (near-black, not
  washed-out grey), built on a **warm brown-green ("barnás zöld") accent**. Think
  olive / moss / forest-green primaries with warm brown undertones in the
  surfaces, not the current cold teal.
- **High contrast** between surfaces, text, and accent so it reads cleanly on a
  phone outdoors. Provide a matching (less critical) light theme from the same
  token set.

### 1.2 Rounded everything
- Generous **rounded corners** on cards, sheets, buttons, the nav bars, inputs,
  and chips. Define a radius scale (e.g. sm/md/lg/pill) and use it consistently.

### 1.3 Minimalist labels + icons everywhere
- **Minimal text in menus** — short labels, lots of breathing room.
- **Icons on everything**: every nav destination, every app-bar action, every
  list section, every metric card, every FAB. Use the existing `Icons.*` set as a
  baseline (see §3 for the per-feature icon map) and keep outline/filled pairs for
  unselected/selected states.

### 1.4 Slimmer, floating top & bottom bars (don't span full width)
- Both the **top bar and bottom bar should feel modern and NOT fill the entire
  screen width/edge-to-edge**. Inset them from the screen edges (margins), give
  them rounded corners and a subtle floating shadow/blur so content scrolls
  *under* them.

### 1.5 Scroll-reactive collapsing bottom bar (Revolut-style) — headline feature
- **On scroll down:** the bottom bar **shrinks toward the center**, becomes a
  compact rounded **pill**, and **labels disappear — only the icons remain**
  (like the Revolut app).
- **On scroll up:** it **expands again** back to the full labelled bar.
- The transition must be **smooth/animated** (not a hard snap), driven by scroll
  direction (and ideally velocity), and must not fight the system gesture insets.
- **The top bars behave the same way and also carry icons everywhere** — the top
  app bar collapses to a slim, compact strip (title shrinks / actions condense to
  icons) as you scroll down, and re-expands on scroll up.

**Implementation guidance for §1.4–1.5:**
- Build a shared `lib/shared/widgets/adaptive_bottom_nav.dart` that wraps the
  current `NavigationBar` destinations but renders a custom, animated floating
  pill. Drive collapse state from a `ScrollController` / `NotificationListener<
  UserScrollNotification>` exposed by the shell so any tab's scrollable can feed
  it. Use `AnimatedContainer` / `AnimatedSize` / implicit animations or an
  `AnimationController` for width, padding, label opacity, and corner radius.
- Build a shared `lib/shared/widgets/adaptive_app_bar.dart` (a thin wrapper around
  `SliverAppBar` with `floating: true, snap: true` + a compact collapsed height,
  OR a custom widget mirroring the bottom-bar logic) so the top bar uses the same
  scroll signal and the same collapse animation. Keep the same brown-green tokens.
- Keep one source of truth for "are we collapsed?" so top and bottom move in sync.
- Respect safe areas; the collapsed pill should sit above the home indicator.

---

## 2. Design system to produce

### 2.1 Color tokens (brown-green dark-first)
Define a full Material 3 `ColorScheme.dark` (and `.light`) — don't rely on
`colorSchemeSeed`. Suggested direction (tune for contrast, these are a starting
point, not law):

- `primary`: warm moss/olive green (e.g. ~`#8FA871` / `#A3B57D`)
- `secondary` / `tertiary`: muted brown & deeper forest green accents
- `surface` / `background`: near-black with a warm brown-green tint
  (e.g. `#14150F` … `#1C1E16`), layered surfaces stepping warmer/lighter
- `surfaceContainer*`: the rounded-card backgrounds (the app already uses
  `surfaceContainerHighest` on cards — keep that pattern, retune the values)
- Clear semantic colors for goal states: the dashboard uses `GoalTone.positive`
  (green = good, e.g. protein reached) and `GoalTone.negative` (e.g. calories over
  budget). Keep those readable on dark.
- Keep existing per-metric accent colors usable but harmonize them with the new
  palette (calories=fire/orange, protein=green, carbs=amber, fat=indigo,
  steps=purple, weight=blue-grey). Consider toning them down so they don't clash
  with the brown-green base.

### 2.2 Typography
- One coherent scale mapped onto M3 `TextTheme`. Prefer a clean, slightly rounded
  geometric sans. If adding a font, justify it (e.g. bundle via `pubspec` assets;
  avoid runtime-fetch `google_fonts` if offline-first matters — bundle the .ttf).
- Numbers/metrics should feel prominent (the app is full of big stat values).

### 2.3 Spacing, radius, elevation, motion
- Spacing scale (4/8/12/16/24…). The app currently hardcodes `EdgeInsets.all(16)`,
  `SizedBox(height: 24)`, etc. — centralize into tokens and apply.
- Radius scale (sm ~8, md ~16, lg ~24, pill = stadium).
- Soft, low-spread shadows for the floating bars/cards; avoid harsh elevation.
- Motion: standard durations (e.g. 150/250/350ms) + easing tokens; the nav
  collapse should feel springy but quick.

### 2.4 Reusable components to standardize
- `StatCard` (already exists — `features/dashboard/.../widgets/stat_card.dart`):
  supports `label, value, unit, icon, color, ratio, goalReached, goalTone,
  trailing, onTap`. Restyle to the new system; it's used across dashboard.
- `WaterCard`, the workout/session tiles, empty/error states (`EmptyView`,
  `ErrorView` patterns), `SegmentedButton` range pickers, metric chips, FABs,
  bottom sheets (`showModalBottomSheet` with `showDragHandle: true`).

---

## 3. Full functionality & screen inventory (so nothing is missed)

The app uses a 5-tab bottom shell (`MainShell` + `StatefulShellRoute.indexedStack`)
plus pushed routes for `/settings` and various editors. Auth-gated via `go_router`
redirect (JWT + refresh).

### 3.1 Navigation shell — `lib/shared/widgets/main_shell.dart`
Five destinations (current icons → keep/restyle):
1. **Dashboard** — `dashboard_outlined` / `dashboard`
2. **Nutrition** — `restaurant_outlined` / `restaurant`
3. **Workouts** — `fitness_center_outlined` / `fitness_center`
4. **Weight** — `monitor_weight_outlined` / `monitor_weight`
5. **Statistics** — `bar_chart_outlined` / `bar_chart`

Behavior: tapping the active tab again resets it to its initial route
(`goBranch(initialLocation: ...)`). This is where the adaptive bottom bar (§1.5)
lives.

### 3.2 Dashboard — `features/dashboard/presentation/dashboard_screen.dart`
- AppBar: title + actions `settings_outlined` (→ `/settings`) and `logout`.
  → becomes the adaptive collapsing top bar; actions stay as icons.
- Pull-to-refresh = "sync now" (push + pull).
- Content (a `ListView` today):
  - **Water card** (current liters vs goal, "+" to open `AddWaterSheet`).
  - **Today section**: big **calories** `StatCard` (`local_fire_department`, over-goal
    = negative tone), then a row of **protein / carbs / fat** cards
    (`egg_alt`, `bakery_dining`, `water_drop`), each with goal ratio bars.
  - **Steps** card when available (`directions_walk`, from Apple Health).
  - **Current weight** card (`monitor_weight`) with up/down trend arrow, taps to
    `/weight`.
  - **Recent workouts** list (tiles open the session in edit mode), empty hint
    otherwise.

### 3.3 Nutrition — `features/nutrition/presentation/nutrition_screen.dart`
- `TabBar` with 3 tabs: **Foods**, **Meals**, **Recipes**.
- Context-aware extended FAB per tab: add food / log meal / new recipe.
- Sub-screens/sheets: `log_meal_screen`, `add_food_sheet`, `barcode_scanner_screen`
  (barcode scanning exists in code), `create_recipe_screen`, `recipes_tab`,
  `log_recipe_sheet`.
- Metrics tracked: calories + protein/carbs/fat per food/meal/recipe.

### 3.4 Workouts — `features/workouts/presentation/workouts_screen.dart`
- `TabBar` with 3 tabs: **Sessions**, **Templates**, **Exercises**.
- Context-aware extended FAB: log session / new template / add exercise.
- Sub-screens: `log_session_screen` (start workout, add exercise, add set,
  reps/weight, rest timer, finish), `create_template_screen`, `exercises_tab`,
  `sessions_tab`, `templates_tab`.
- Apple Health enrichment on sessions: active calories burned, average heart rate.

### 3.5 Weight — `features/weight/presentation/weight_screen.dart`
- AppBar title + a `FloatingActionButton` ("+") to add an entry.
- Body: weight history + a `TimeSeriesChart` (custom chart widget under
  `lib/shared/widgets/charts/`). Empty state when no entries.

### 3.6 Statistics — `features/statistics/presentation/statistics_screen.dart`
(see `docs/17-statistics-page-plan.md`)
- A **metric picker** (chips/dropdown) + a **range** `SegmentedButton`
  (week/month/quarter/all).
- **KPI summary cards**: average / sum / min / max / trend (↑/↓ vs previous period),
  using `functions`, `show_chart`, `arrow_upward/downward` icons.
- `TimeSeriesChart` of the selected metric, with tappable points (value + date).
- Metrics: calories, protein, carbs, fat, workout duration, workout count, active
  calories, avg heart rate, water, body weight, total volume lifted.

### 3.7 Settings — `features/settings/presentation/settings_screen.dart` (pushed `/settings`)
- **Units**: metric / imperial (`SegmentedButton`).
- **Theme**: light / dark / system.
- **Language**: system / English / Hungarian.
- **Daily goals** (text fields): calories, protein, carbs, fat, water, daily step
  goal.
- **Manage water sources** button (`water_drop_outlined` → `water_sources_screen`).
- **Apple Health**: `SwitchListTile` to connect (`connectAppleHealthLabel`).

### 3.8 Auth — `login_screen`, `register_screen`
- Clean, branded entry screens consistent with the new dark identity (logo, the
  brown-green accent, rounded inputs and primary button).

### 3.9 Cross-cutting
- **Water**: `add_water_sheet`, `water_card`, `water_sources_screen`.
- **Steps / Apple Health** (`health` package): today's steps on dashboard, step
  goal in settings, health metrics feeding statistics.
- **Offline-first**: every screen must work offline; sync is best-effort. Loading,
  empty, and error states need first-class designs (don't leave bare spinners).
- **i18n**: English + Hungarian. All new copy → ARB keys, never literals.

---

## 4. Implementation constraints & checklist

- Centralize theme in `lib/core/theme/app_theme.dart`; introduce tokens file if
  useful. Wire `ThemePreference` (light/dark/system) from settings to `MaterialApp`.
- Build the two shared adaptive widgets (`adaptive_bottom_nav.dart`,
  `adaptive_app_bar.dart`) and a single shared "collapse" signal/controller.
- Reuse and restyle existing components (`StatCard`, `WaterCard`, tiles, empty/error
  views, `TimeSeriesChart`) rather than forking new ones.
- No new heavy deps without justification (CLAUDE.md rule). Implicit animations and
  `SliverAppBar` cover most of §1 needs natively.
- Never edit generated `*.g.dart`; run `dart run build_runner build` after touching
  `@riverpod` providers.
- Keep four-layer feature structure (`domain/data/application/presentation`).
- Verify on both themes and both locales; check safe-area / notch / home-indicator
  behavior for the floating bars.

## 5. Acceptance criteria (quick pass/fail)
- [ ] Dark, high-contrast, brown-green palette applied app-wide via a real
      `ColorScheme` (no bare `colorSchemeSeed`).
- [ ] Rounded corners everywhere via a radius scale.
- [ ] Icons on every nav destination, app-bar action, and section/card.
- [ ] Top & bottom bars are inset/floating (not edge-to-edge full width).
- [ ] Bottom bar collapses to a centered icon-only pill on scroll-down and
      re-expands on scroll-up, smoothly animated (Revolut-style).
- [ ] Top bar collapses/expands in sync, keeping its actions as icons.
- [ ] All 5 tabs + settings + auth + sheets restyled; loading/empty/error states
      designed; English & Hungarian both render correctly.
