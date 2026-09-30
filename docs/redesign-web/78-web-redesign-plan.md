# 78 – Web Redesign (Design System v2, web extension)

Status: plan written, no code yet
Scope: web (client shell, trainer shell, superadmin shell, auth, onboarding — every logged-in page) ·
design system · a handful of optional, read-only backend steps (marked `W<n>.b<k>`) · docs
Depends on: the Claude Design output in this folder — `Lifey Web Design System.dc.html` + nine screen
canvases `Lifey Web 1 … 9` — commissioned by [web-redesign-prompt.md](web-redesign-prompt.md); the mobile
v2 system it extends, [docs/redesign/77-mobile-redesign-plan.md](../redesign/77-mobile-redesign-plan.md)
(token decisions D-R0.2 – D-R0.4 are reused **verbatim**) and
[docs/redesign/Lifey Design System.dc.html](../redesign/Lifey%20Design%20System.dc.html).
Supersedes the token values of [docs/web/06-design-system-web.md](../web/06-design-system-web.md) — its
structure (CSS variables → Tailwind `@theme` → components) is kept, its values and components are not.
Branch: `feature/web-redesign` (integration branch, cut from `main` on 2026-09-27 with this plan and the
canvases); one long-lived PR `feature/web-redesign → main` collects every step commit of every iteration.

---

## 0. How to read this plan

The plan has **eleven iterations**. **W0** is the general foundation (the `Lifey Web Design System.dc.html`
canvas). **W1–W9 map one-to-one onto the nine numbered screen canvases** — iteration `W<n>` implements
`Lifey Web <n> ….dc.html`, and its steps are `W<n>.1`, `W<n>.2`, …. **W10** is the closing sweep for
everything no canvas drew, plus the removal of the old system.

| Iteration | Design source (in `docs/redesign-web/`) | What it delivers | Demo at the end |
|---|---|---|---|
| **W0** | `Lifey Web Design System.dc.html` (DS-01 … DS-07) | v2 tokens on the web, type, one formatter, motion, every web component (table, drawer, modal, toast, menu, fields, date picker), Recharts kit, **one shell for three roles** (sidebar, top bar + date stepper, mobile bottom nav), keyboard layer, dev design gallery | Gallery in both themes; every existing page already on the v2 palette, type and shell |
| **W1** | `Lifey Web 1 Dashboard.dc.html` | Client dashboard: calorie hero, recommended workout, water/steps/weight tiles, 7-day chart, recent workouts, first-steps empty state | Dashboard matches W1-A/B/C/D |
| **W2** | `Lifey Web 2 Nutrition.dc.html` | Meal log + day summary hero, two-pane add-food modal, edit drawer, delete with undo, copy-from-day popover, Foods table + editor panel, recipe cards | Log, edit, delete (undo), copy a meal end to end |
| **W3** | `Lifey Web 3 Workouts.dc.html` | Week-grouped log, read-only session summary, focus-mode live logger (timer, rest hero, set rows, PR), RPE → celebration, cardio summary, template picker | Run a strength session end to end; open a cardio summary |
| **W4** | `Lifey Web 4 Weight Water Steps.dc.html` | Weight hero + trend chart + log table + log drawer; Water ring + source buttons + 14-day bars; Steps hero + 14-day bars | Log a weight, a drink and a step count |
| **W5** | `Lifey Web 5 Statistics.dc.html` | KPI row, honest charts (goal, average without today, gaps, rest days), year view, CSV export | Browse week / month / year; export a CSV |
| **W6** | `Lifey Web 6 Settings Auth Onboarding.dc.html` | Branded login/register, trainer registration path, focused onboarding wizard + plan "wow" + celebration, one-page settings, honest logout | New account → onboarding → settings → logout |
| **W7** | `Lifey Web 7 Trainer Clients.dc.html` | "Needs attention" strip, client cards with real numbers, client detail header + all six tabs, logging heatmap | Trainer triages clients and opens one |
| **W8** | `Lifey Web 8 Calendar Programs Chat.dc.html` | Calendar week grid, program week × day grid with drag, assign drawer with consequences, three-column chat | Build + assign a program; answer a chat |
| **W9** | `Lifey Web 9 Trainer Content Superadmin.dc.html` | Trainer templates / foods & recipes / assigned plans / invites / billing on the table + panel pattern; superadmin in the common shell | Every remaining trainer page + superadmin |
| **W10** | — (derived) | Undesigned leftovers, deletion of legacy tokens and components, audit script, docs | Audit script clean |

**Smallest thing worth using:** W0 + W1. After those two the whole logged-in web is on the v2 palette,
type and shell (sidebar, top bar, bottom nav) and the most-visited page is fully redesigned. Everything
after W1 can pause without leaving the web inconsistent-looking (D-W0.1).

Every iteration has the same shape: **goal → design source (frames) → canvas notes = requirements →
current code → target spec → data → steps (prompt-sized) → verification → acceptance → web UI review
(§4.1)**. **No iteration counts as done until its web UI review (§4.1) is written up in §12.** Steps are
the unit of work: one surface, one session, independently mergeable.

### 0.1 Opening the canvases

The canvases load `./support.js` — the canvas runtime, a copy of `docs/redesign/support.js`, added to
this folder by W0.0. Serve the folder rather than opening files directly (a server lets Playwright
screenshot the frames at a fixed viewport):

```bash
python -m http.server 5510 --directory docs/redesign-web
```

The canvases are in Hungarian; frames show HU unless labelled "EN". Each canvas ends a frame with an
**"Előtte → utána"** (before → after) note list: every note names the PDF screenshot ids it answers
(`client-001`, `trainer-012`, … — see the handoff PDF `lifey-web-jelenlegi-allapot.pdf`), what changed and
which v2 element it carries over. **Every note is a requirement** and is listed per iteration below.

### 0.2 Frame index (the ids every step cites)

| Canvas | Frame id | Viewport · theme · language | Shows |
|---|---|---|---|
| Web Design System | DS-01 | 1440 / 1280 / 1024 / 390 | Grid and breakpoints, content widths, spacing |
| | DS-02 | open 248 / collapsed 76 / 390 | Navigation shell: client, trainer (grouped), superadmin, collapsed + tooltip; top bar with date stepper (HU dark, EN light); mobile bottom nav |
| | DS-03 | light + dark | Data table, popover/menu/tooltip, segmented control + tab bar, modal/drawer/toast, form fields with states, number/time fields, switch, choice tile, date picker (calendar + typed fields) |
| | DS-04 | light | Recharts: weight line (gaps, 7-day average, goal), calories bars (today dashed, goal), the settings code block |
| | DS-05 | light + dark, HU + EN | Empty states (weight HU, nutrition EN), error state, skeleton rule |
| | DS-06 | — | Hover / pressed / focus / disabled; shortcut list; touch targets |
| | DS-07 | — | Formatting table HU/EN; motion table |
| Web 1 Dashboard | W1-A | 1440 · dark · HU | Full dashboard, open sidebar |
| | W1-B | 1024 · light · HU | Collapsed sidebar, full length |
| | W1-C | 390 · dark · HU | Mobile layout, bottom nav |
| | W1-D | card | New user: "first steps" instead of the hero (`onboarding-001`) |
| Web 2 Nutrition | W2-A | 1440 · dark · HU | Meals tab: log (8 col) + day summary hero (4 col) |
| | W2-B | 1440 · dark · HU | Add-food two-pane modal, 880 px |
| | W2-C | panels | Copy-from-day popover, delete confirm, edit-meal drawer with "unsaved" |
| | W2-D | 1440 · light · HU | Foods tab: table + 380 px editor panel |
| | W2-E | 1024 · light · HU | Recipes tab: card grid |
| | W2-F | 390 · dark · HU | Meals on mobile, undo toast above the FAB |
| Web 3 Workouts | W3-A | 1440 · dark · HU | Week-grouped log + 440 px summary of a closed strength session |
| | W3-B | 1440 · dark · HU | Live logger in focus mode (no sidebar): 280 / flexible / 340 columns |
| | W3-C | modals | Finish: 1. RPE, 2. celebration |
| | W3-D | 1024 · light · HU | Cardio summary (run) |
| | W3-E | 390 · dark · HU | Live logger on mobile |
| | W3-F | modal · light | Template picker ("Edzés indítása"), templates-tab note |
| Web 4 Weight Water Steps | W4-A | 1440 · dark · HU | Weight: hero, 30-day chart, log table, log drawer |
| | W4-B | 1280 · light · HU | Water |
| | W4-C | 1280 · light · HU | Steps |
| | W4-D | 390 · dark · HU | Weight on mobile |
| Web 5 Statistics | W5-A | 1440 · dark · HU | Week view: KPI row, nutrition & body, movement |
| | W5-B | card · light | Year view: weekly averages, "not logged yet" band |
| | W5-C | popover + toast | Export |
| | W5-D | 390 · dark · HU | Statistics on mobile |
| Web 6 Settings Auth Onboarding | W6-A | 1440 · light · HU | Login with wrong password |
| | W6-B | 560 form | Trainer registration |
| | W6-C | 390 · dark · HU | Login on mobile |
| | W6-D | 1440 · dark · HU | Onboarding step 4 "Suggested plan", no shell |
| | W6-E | card | Onboarding step 3 goal tiles |
| | W6-F | card | Onboarding finish celebration |
| | W6-G | 1440 · light · HU | Settings on one page + logout modal |
| | W6-H | 390 · dark · HU | Settings on mobile |
| Web 7 Trainer Clients | W7-A | 1440 · dark · HU | "Klienseim": attention strip + client cards |
| | W7-B | 1440 · light · HU | Client detail, Overview tab |
| | W7-C | cards | The other five tabs |
| | W7-D | card · dark | Inactive client header |
| | W7-E | 390 · dark · HU | Trainer clients on mobile |
| Web 8 Calendar Programs Chat | W8-A | 1440 · dark · HU | Calendar week view |
| | W8-B | 1440 · light · HU | Program editor while dragging |
| | W8-C | drawer | Assign program |
| | W8-D | 1440 · dark · HU | Chat: list + thread + client context |
| | W8-E | 390 · dark · HU | Chat thread on mobile |
| Web 9 Trainer Content Superadmin | W9-A | 1440 · light · HU | Trainer templates: table + 520 px editor |
| | W9-B | card · dark | Invites |
| | W9-C | card · light | Assigned plans by client |
| | W9-D | card · light | Billing in trial |
| | W9-E | 1440 · dark · HU | Superadmin users in the common shell |
| | W9-F | card | Trainer request with context |
| | W9-G | card | Role history timeline |

---

## 1. What we're building

1. **The v2 design system on the web** — the mobile v2 tokens, type, radii, depth and motion unchanged
   (they are the Lifey identity), **extended** where the web needs more: a 12-column grid with
   breakpoints, one navigation shell for three roles, a top bar with the global date stepper, data
   tables, drawers, modals, toasts with undo, menus, tooltips, form fields with every state, a date
   picker, Recharts charts drawn by the v2 chart rules, and hover / focus / keyboard rules.
2. **Every logged-in page restyled** to that system: the client app (dashboard, nutrition, workouts,
   weight, water, steps, statistics, settings), auth + onboarding, the trainer workspace (clients, client
   detail with six tabs, calendar, programs, chat, templates, foods & recipes, assigned plans, invites,
   billing, pending) and superadmin (users, trainer requests, role history).
3. **One shell for three roles.** Client, trainer and superadmin get the same sidebar component with role
   content; the superadmin's separate top-bar header goes away; the trainer's second green (`tertiary`)
   goes away — the trainer role is clay, controls are primary olive everywhere.
4. **Fixes the design called out** (web-redesign-prompt.md "Amit mindenképp javíts"): flat equal cards →
   hero hierarchy; broken 390 px layouts (Nutrition, Settings, overflowing tab bars, clipped trainer client
   header); charts with clipped axes, overshooting monotone curves, missing days drawn as 0, no goal line;
   raw decimals (`166.68 g`), raw keys (`workouts.activityTypes.CYCLING`, `ROLE_USER`), English dates in HU;
   no confirmation or undo on delete; a poor live workout logger (no timer, no rest, no PR, no
   celebration); a read-only finished session opening in the editable logger; nearly empty trainer client
   cards and the "Klienseid" modal covering the page; empty states that show zeros instead of a next step.
5. **Wide screens used.** 8 + 4 column pages (work area + context panel), list + detail panes, tables
   with side editors — no narrow panels floating in empty space.
6. **Both themes and both languages are first-class**: dark-first, light with its own text-safe values;
   HU is the length yardstick (no truncation), EN is checked on every review.
7. **Small UX relocations the design specifies** (not new features): logout moves into the account menu
   and the bottom of Settings, always with a confirmation; the weekly-report switch moves from the trainer
   nav into the account menu; the stats type filter moves into the "Movement" section header; the
   finished workout opens as a summary, editing is a separate action.

**When nothing is "on":** there is no feature flag (D-W0.1). Before W0 lands the web looks as today;
after W0.1 every app page renders the v2 palette (the marketing pages keep theirs, D-W0.2); after W0.20–
W0.24 every page sits in the new shell; after its iteration a page also has the new layout.

---

## 2. Current state (what already exists)

| Area | Where | Relevance |
|---|---|---|
| Tokens | `web/src/app/globals.css` (281 lines): `--bg`, `--surface*`, `--primary`, `--secondary`, `--tertiary`, `--on-surface*`, `--muted`, `--metric-*`, `--goal-*`, `--r-*`, `--dur-*`; Tailwind v4 `@theme inline` maps them to utilities | Values replaced (W0.1–W0.2), names aliased then deleted (W10.3) |
| Marketing | `app/(marketing)`, `app/(marketing-bare)`, `components/marketing/**` — use the same variables (`--muted` 95×, `--bg` 87×, `--surface-container` 68×, `--primary` 63×, `--secondary` 39×, `--tertiary` 17×); its own newer design; CI runs Lighthouse, axe (`e2e/marketing`) and the JS budget on it | **Out of scope, must not change** (D-W0.2) |
| Font / icons | `next/font` Plus Jakarta Sans 400–800 (`app/layout.tsx`); Material Symbols Rounded via Google Fonts `<link>` (FILL axis 0..1 available) | Kept; `Icon` component standardises FILL (D-W0.10) |
| Client shell | `app/(app)/layout.tsx` → `components/layout/Sidebar.tsx` (227; 248/74 px, local `collapsed` state not persisted, logout button, avatar) + `TopBar.tsx` (91; title, date stepper with `format(date, "MMM d")` — English in HU, future days allowed, on every page) + `ThemeToggle.tsx` | Replaced by `AppShell` (W0.20–W0.22) |
| Trainer shell | `app/(admin)/admin/layout.tsx` → `components/layout/AdminSidebar.tsx` (262; flat list, `tertiary` accent, weekly-report switch inside nav); no top bar; hamburger button | Onto `AppShell` (W0.23) |
| Superadmin shell | `app/(superadmin)/superadmin/layout.tsx` (153; own top header with tabs) | Onto `AppShell` (W0.24) |
| UI primitives | `components/ui/`: `Dialog.tsx` (54; max-w-md, no focus trap, no focus return), `ConfirmDialog.tsx`, `SegmentedControl.tsx`, `Switch.tsx`, `DatePicker.tsx` (231), `TimePicker.tsx` (122), `Toaster.tsx` (64; bottom-right, stacked, coloured fills, no undo) | Rebuilt in `components/ds/` (W0.7–W0.17); old files deleted W10.3 |
| Data components | `components/data/`: `DataTable.tsx` (185), `HeroMetricCard`, `KpiCard`, `StatCard`, `MacroRing`, `Sparkline`, `TimeSeriesChart` (+ `Lazy`), `WaterCard` | Replaced (W0.15, W0.16, W0.18–W0.19) |
| States | `components/status/`: `EmptyState`, `ErrorState`, `ErrorBoundary`, `Skeleton` | Restyled in place (W0.17) |
| Charts | Recharts 3.9 in only two files (`TimeSeriesChart.tsx`, `Sparkline.tsx`); `PaceBarChart`, `ElevationProfileChart`, `RouteSvg`, `HrZonePanel` are hand-drawn SVG | Two chart wrappers (D-W0.9); SVG charts restyled in W3 |
| Formatting | `lib/utils/format.ts` (`humanizeEnum` only), `lib/utils/units.ts`, `features/workouts/cardioFormat.ts`, `date-fns` `format(...)` for display, scattered `toFixed` | One `lifeyFormat` (D-W0.8) |
| i18n | `next-intl`, `messages/en.json` + `hu.json` (1 220 lines each), locale from settings or `navigator.language` (`lib/hooks/useLocale.ts`) | Kept; key-parity test + typed messages (W0.4) |
| Styling debt | **1 356** inline `style={{…}}` objects and **63** hex literals in app TSX (excluding marketing); radius via `rounded-[var(--r-*)]` (card 72, input 105, lg 49, md 33, pill 58, sm 54); `tertiary` used in 122 places | Moved file by file as each iteration touches them; W10.1 audits the rest |
| Tests | Vitest in **node** environment (`src/**/*.test.ts`, pure logic only, no component tests); Playwright: `chromium` (backend-dependent, local) and `marketing` (CI) projects; CI `web-ci.yml`: lint, typecheck, unit, build, JS budget, Lighthouse, marketing e2e | New `ds` Playwright project against the dev gallery, CI-able (D-W0.12) |
| Domain helpers to reuse | `features/nutrition/{budget,copyMeal,usage,logRecipePortion}.ts`, `features/workouts/{progress,recommendation,bestEfforts,hrZoneBreakdown,paceBarGeometry,cardioTiles}.ts`, `features/trainer/{compliance,program}.ts`, `features/statistics/aggregate.ts`, `lib/hooks/useDateStore.ts` | Reused; missing mobile derivations are **ported** (PRs, week groups, weight trend) |
| Mobile v2 (reference implementation) | `mobile/lib/shared/widgets/ds/`, `mobile/lib/shared/widgets/charts/chart_math.dart`, `mobile/lib/core/format/lifey_format.dart`, `mobile/lib/core/theme/{app_theme,app_tokens,contrast}.dart`, `mobile/lib/features/workouts/domain/{personal_record,session_groups,week_summary}.dart`, `mobile/lib/features/weight/domain/weight_trend.dart` | The web ports the **rules and the pure functions**, with the same test cases, so both clients show the same numbers |
| Backend fields already there but unused on the web | `TrainerClientResponse.avgCalories7d`, `.prCount7d` (mobile R6.2); settings push toggles (`workoutReminderEnabled`, `trainerCommentPushEnabled`, `trainerGoalsPushEnabled`, `programAssignedPushEnabled`), `restTimerEnabled`, `defaultRestSeconds`; `Exercise.restSeconds`; `SuggestGoalsResponse.bmr/.tdee`; `UserDetails.targetWeightKg`; `RecipeResponse.imageUpdatedAt` | Used by W1, W3, W4, W6, W7 — no backend change needed |

---

## 3. Key design decisions

### D-W0.1 Retheme in place on the integration branch — no v1/v2 flag

Same call as mobile D-R0.1: the v2 values replace the old ones; no `designV2` flag, no parallel
component tree. The app is not released (no users to shield from a half-migrated look), a flag would
double every restyled component for months, and because pages read colour through CSS variables, a
token swap gives unmigrated pages most of the new look at once. Work happens on `feature/web-redesign`.

### D-W0.2 The v2 palette is the app default; the marketing tree pins its own palette

The marketing pages share `globals.css` but already have a newer, separate design, a Lighthouse
contrast gate and an axe suite. Changing the variables in place would silently recolour them. Decision:
`:root` / `[data-theme]` get the v2 values; the two marketing layouts render a
`data-surface="marketing"` marker and `globals.css` restores the legacy values under
`:root:has([data-surface="marketing"])` (and its `[data-theme="light"]` variant). Server-rendered, so no
flash; applies to portals too, because the selector is on `:root`.
Rejected: (a) changing values globally (recolours marketing, breaks its CI thresholds); (b) scoping v2 to
a wrapper class around the app shell — modals and toasts portal into `<body>` and would escape the scope.
`app/not-found.tsx` belongs to marketing (it is the public 404) and gets the marker too.

### D-W0.3 v2 token names mirror the mobile `AppPalette`; legacy names stay as aliases until W10

New CSS variables use the mobile names so a value can be looked up across clients:
`--bg --card --nested --control --raised --float --scrim --text --text-2 --text-3 --hairline --outline
--primary --on-primary --primary-tint --on-primary-tint --role --role-tint --heart --grid` and metrics
`--m-kcal --m-protein --m-carbs --m-fat --m-water --m-steps --m-weight --m-heart`, plus the semantic
roles `--improvement` (= protein), `--record` (= carbs), `--decrease` (= weight), `--increase` (=
calories). Tailwind colours (`@theme inline`): `bg card nested control raised fg fg-2 fg-3 hairline
primary on-primary primary-tint role role-tint heart m-kcal …` → `bg-card`, `text-fg-2`,
`text-m-protein`. (`text-text-2` would be unreadable, hence `fg-*` as the Tailwind key only.)

The legacy variables stay, **re-pointed** at the nearest v2 token in the app scope, so the 1 356 inline
styles don't have to move in W0; each iteration moves its own files; W10.3 deletes the aliases.
Rejected: a big-bang rename in W0 (unreviewable diff across every feature).

| Legacy | Dark → v2 | Light → v2 |
|---|---|---|
| `--surface` | `--card` | `--card` |
| `--surface-container` | `--nested` | `--nested` |
| `--surface-high` | `--control` | `--card` (it is white today) |
| `--surface-highest` | `--raised` | `--control` |
| `--on-surface` / `--on-surface-variant` / `--muted` | `--text` / `--text-2` / `--text-3` | same |
| `--secondary` | `--role` (clay) | `--role` |
| `--tertiary`, `--tertiary-container`, `--on-tertiary-container` | `--primary`, `--primary-tint`, `--on-primary-tint` — the second green disappears | same |
| `--border` | `--hairline` | `--hairline` |
| `--error`, `--error-container` | `--heart`, heart @ 16 % | `--heart`, heart @ 12 % |
| `--metric-kcal … --metric-hr` | `--m-kcal … --m-heart` | same |
| `--goal-positive` / `--goal-negative` | `--m-protein` / `--m-kcal` | same |
| `--r-sm / --r-md / --r-input / --r-card / --r-lg / --r-nav` | `8 / 14 / 14 / 22 / 22 / 30` | same |
| `--shadow-float` | `--e1` | `--e1` |

`--success-*` and `--scrim-celebration` stay untouched until W3.9 deletes the old success dialog.

### D-W0.4 Values: exactly the mobile v2 tables; one chip rule; a contrast test guards them

| Token | Dark | Light |
|---|---|---|
| `--bg` | `#12130E` | `#F4F2E9` |
| `--card` (surface-1) | `#1A1C15` | `#FFFFFF` |
| `--nested` (surface-2) | `#22251C` | `#F0EEE3` |
| `--control` (surface-3: chip, input, track) | `#2C2F24` | `#E6E4D6` |
| `--raised` (surface-4) | `#36392D` | `#DCDAC9` |
| `--float` (sidebar-on-scroll, top bar, bottom nav) | `#282C20` @ 82 % + blur 24 | `--bg` @ 86 % + blur 24 |
| `--scrim` (top bar when content scrolls under) | `--bg` @ 82 % + blur 24 (DS-02) | same |
| `--text` / `--text-2` / `--text-3` | `#F2F1E6` / `#B6B5A5` / `#8F8F80` | `#1C1D16` / `#56574B` / `#6B6C5F` |
| `--hairline` = `--grid` | `rgba(242,241,230,.07)` | `#E6E4D6` |
| `--outline` | `#45483B` | `#CDCBBC` |
| `--primary` / `--on-primary` | `#B5C47C` / `#1A1F0A` | `#4E6530` / `#FFFFFF` |
| `--primary-tint` / `--on-primary-tint` | primary @ 16 % / `#D6E2A6` | primary @ 12 % / primary |
| `--role` (clay) / `--role-tint` | `#C49A6C` / clay @ 16 % | `#7E613C` / clay @ 12 % |
| `--m-kcal` | `#EC9A66` | `#9D4602` |
| `--m-protein` | `#93C98C` | `#34742F` |
| `--m-carbs` | `#E2BE62` | `#7F5D00` |
| `--m-fat` | `#A3A1DB` | `#5A57A8` |
| `--m-water` | `#74B6D6` | `#1A6C8F` |
| `--m-steps` | `#C593CC` | `#83488D` |
| `--m-weight` | `#98ADC0` | `#50667A` |
| `--m-heart` = `--heart` | `#E07F76` | `#A73831` |

The light metric set is mobile's R0.1 decision (all eight at oklch L 0.50, canvas hue and chroma); the
web canvases already use exactly these hexes (e.g. W1 light calories `#9D4602`, W2 light protein
`#34742F`). **Tinted chips** (mobile D-R0.4): dark = metric @ 16 % background + metric text; light = metric
@ 12 % + the light metric text. Only `TintedChip` builds one. `src/lib/theme/contrast.ts` (a port of
`mobile/lib/core/theme/contrast.dart`) + `contrast.test.ts` assert every text tier on bg/card/nested ≥ 4.5,
every metric on its own chip tint ≥ 4.5 in both themes, and `--on-primary` on `--primary` ≥ 4.5 — this
closes the web half of the "tinted-chip contrast" backlog item.

### D-W0.5 Radius: four steps + pill; the 4-step rule wins over individual canvas samples

`--r-tag 8` (tag, set row, tooltip), `--r-control 14` (input, button, icon holder, nav item, table
toolbar), `--r-card 22` (card, sidebar, table container), `--r-hero 30` (hero card, modal, drawer's inner
edge, sheet), `--r-pill`. Nested = parent − inner padding (`calc(var(--r-card) - 16px)` helper classes).
Where a canvas sample is off-scale it snaps to the scale, as on mobile (R0.8): the Google button's "16"
(W6 note) → 14, the collapsed-nav tooltip's 10 → 8, the canvas logo tile's 12 → 14. The frame corner 18
and the phone-frame 36 are canvas chrome, not UI.

### D-W0.6 Grid and breakpoints come from DS-01; Tailwind breakpoints are redefined to match

| Name | Width | Columns · gap | Side margin | Sidebar | Content |
|---|---|---|---|---|---|
| desktop · base | 1440 | 12 · 24 | 32 | open 248 | max 1 320 |
| desktop · small | 1280 | 12 · 20 | 24 | open 248 | fluid |
| tablet | 1024 | 8 · 20 | 24 | **collapsed 76** by default | fluid |
| mobile | 390 | 4 · 12 | 20 | none — bottom nav | fluid |

- Tailwind v4 `@theme`: keep `md` 768, `lg` 1024, `xl` 1280; set `--breakpoint-2xl: 90rem` (1440 — no
  current usages of `2xl:`) and add `--breakpoint-3xl: 100rem` (1600). Above 1600 the grid stops growing
  and the extra width splits evenly left/right; the sidebar stays at the left edge.
- Page = main column + side panel; the typical desktop split is **8 + 4** (work area left, context
  right: day summary, details, editor). Below 1024 the side panel drops under the main column or becomes
  a drawer. Reading columns (settings text, chat bubbles) max 720.
- Spacing stays v2: card padding **20 on desktop, 16 on mobile**, 24 between cards, 32 between sections.
  Dense views (table, calendar) have denser *rows*, not smaller gaps.
- One `PageGrid` component (`cols`, `gap` per breakpoint) + `span` props, instead of ad-hoc
  `grid-template-columns` per page.

### D-W0.7 Type scale as Tailwind utilities; numbers always tabular; units next to the number

| Utility | Spec | Use |
|---|---|---|
| `type-display-xl` | 72/68 · 800 · −3 % | weight hero, rest timer, log-weight drawer value |
| `type-display` | 48/48 · 800 · −2.5 % | onboarding plan kcal |
| `type-headline` | 30/36 · 800 · −2 % | onboarding headline, celebration title |
| `type-page` | 26/1.15 · 800 · −2 % | **top-bar page title** (DS-02) |
| `type-title` | 20/26 · 700 · −1 % | card, modal (22 on drawers per DS-03 → `type-title-l` 22/1.2 · 800) |
| `type-title-s` | 16/22 · 700 | list-row title |
| `type-body` | 15/22 · 500 | default body (`body` font-size is already 15) |
| `type-body-s` | 13/18 · 500 | meta, footnotes |
| `type-label` | 12/16 · 700 | small labels; `type-section` adds CAPS + 8 % tracking (section labels only) |
| `type-button` | 15/1 · 700 (14 in dense toolbars) | buttons, nav items |
| `type-table-head` | 13/1 · 600, sentence case, never CAPS | table headers (DS-03) |

Off-scale hero numbers (the dashboard ring's 56, KPI 26–34, tile 28) come from `num-[size]` = 800,
−3 %, `tabular-nums`. `MetricValue` renders number + unit, unit at 0.42 × in `--text-2` (tiles: 0.5 ×, as on
mobile), with an `aria-label` sentence ("859 kilocalories left"). CAPS only on 12 px section labels.
Browser zoom is not clamped anywhere (the web counterpart of mobile D-R0.8): layouts are verified at
200 % zoom (§4.1).

### D-W0.8 One formatter for client and trainer screens, on `Intl`; missing translation fails the build

`src/lib/format/lifeyFormat.ts` — `createFormat(locale)` + `useFormat()` — ports
`mobile/lib/core/format/lifey_format.dart` and implements DS-07:

| Function | HU | EN |
|---|---|---|
| `weight(69.6)` | `69,6 kg` | `69.6 kg` |
| `litresOfGoal(1.6, 2.5)` | `1,6 / 2,5 L` | `1.6 / 2.5 L` |
| `integer(17519)` + unit | `17 519 kcal` | `17,519 kcal` |
| `grams(166.68)` | `166,7 g` (max 1 decimal) | `166.7 g` |
| `shortDate` | `szept. 26.` | `Sep 26` |
| `longDate` | `2026. szept. 27., szombat` | `Saturday, Sep 27, 2026` |
| `dayLabel` (top bar) | `Ma · szept. 27., szombat` | `Today · Sat, Sep 27` |
| `relative` | `tegnap 18:20`, `3 napja` | `yesterday 6:20 PM`, `3 days ago` |
| `time` | `18:00` (24 h, **never seconds**) | `6:00 PM` |
| `pace` | `5:48 /km` | `5:48 /km` |
| `compactAxis` | `2,4 e` | `2.4k` |
| `signedDelta` | `−0,4 kg` (U+2212), `+1`, `±0 kg` | `−0.4 kg` |
| `roleLabel` | `Kliens · Edző · Superadmin` | `Client · Trainer · Superadmin` |
| `activityLabel`, `mealTypeLabel`, … | via messages, never `humanizeEnum` for display | same |

Rules in its doc comment: round only at display time, never sum rounded values; `date-fns` stays for
date **arithmetic** only (`addDays`, week starts) — every displayed date goes through `lifeyFormat`
(the top bar's `format(date, "MMM d")` is the "English date in HU" bug). Week start = Monday in both
languages (the same definition as mobile streaks/recap).
**Missing translation = build error:** `src/i18n/messages.d.ts` declares next-intl's `AppConfig.Messages`
from `messages/en.json`, so a missing key is a type error in `npm run typecheck`, and
`src/i18n/messages.test.ts` asserts `en.json` and `hu.json` have identical key sets and matching ICU
placeholders.

### D-W0.9 Recharts stays; two wrappers + ported chart math cover every chart

The prompt fixes Recharts. `src/components/ds/charts/`:
- `chartMath.ts` — port of `mobile/lib/shared/widgets/charts/chart_math.dart` with its test cases:
  `niceAxisMax` (top rounds up to two significant digits: 2 360 → 2 400, 12 612 → 13 000; small
  integer counts get one step of headroom; the goal counts toward the top), `yAxisTicks` (0 / exact half /
  max), `averageExcludingPartialToday(points, today, { ignoreZero })`, `weeklyBuckets`, `movingAverage(7)`
  over calendar days with gaps.
- `LifeyBarChart` — DS-04 bar rules: `YAxis width={44} tickCount={3} tickFormatter={compactAxis}
  axisLine={false} tickLine={false}`, `CartesianGrid vertical={false} stroke="var(--grid)"`,
  `ReferenceLine y={goal} strokeDasharray="5 5"` with a "cél 1 900" label, today = **dashed outline, no
  fill, excluded from the average**, past bars metric @ 60 % (dark) / 80 % (light), bar top radius 6,
  optional "met goal" check glyph above a bar (steps), optional value labels (cardio distance), rest-day
  dot on the axis (volume), legend row.
- `LifeyLineChart` — DS-04 line rules: `type="linear"` (never `monotone`: no overshoot, no invented
  valley), `connectNulls={false}` (a missing day is a gap, not 0), `strokeWidth={3} dot={false}`, a
  7-day average series, a dashed goal `ReferenceLine`, emphasised last point, X ticks
  `interval="preserveStartEnd"` with `shortDate`, "no data" band for empty ranges, legend.
- Animation: `isAnimationActive={!reduced}`, `animationDuration={900}`.
- Charts are loaded with `next/dynamic` (`ssr: false`) from app pages only — never imported by the root
  layout or marketing (the JS-budget script caught a 95 KB Recharts leak before).
Rejected: a second chart library or hand-drawn SVG for new charts. The existing hand-drawn SVGs (pace
bars, elevation, route, HR zones) are restyled to the same axis tokens in W3, not rewritten.

### D-W0.10 Icons: Material Symbols Rounded, FILL 0 inactive / FILL 1 active, through one `Icon`

The web already loads the variable Symbols font. `Icon({ name, fill, size, weight })` sets
`font-variation-settings` so "active nav item = filled icon" (DS-02) is one prop; icon-only buttons
**must** pass a label (it becomes the tooltip and `aria-label`, D-W0.17). No new icon dependency.

### D-W0.11 Components are in-house in `src/components/ds/`; behaviours are small in-house hooks

One folder with an `index.ts` barrel, so "is this page on v2?" is a grep for `@/components/ds`. No
component library (prompt constraint; `docs/web/README.md` mentions shadcn/ui but the code never adopted
it). Behaviours live in `src/lib/a11y/`: `useFocusTrap`, `useFocusReturn`, `useRovingFocus`,
`useDismiss` (Esc + outside click), `useAnchoredPosition` (anchor rect, flip, clamp to viewport),
`useUnsavedGuard`. Rejected: Radix / Floating UI — they would be justified if positioning edge cases pile
up; that is §10 Q3, decided at W0.11, not before. `components/ui`, `components/data` are superseded and
deleted in W10.3; `components/status` is restyled in place.

### D-W0.12 Verification = a dev design gallery + pure-function tests + a CI Playwright project on the gallery

- **Design gallery** `/dev/design` (`app/(dev)/dev/design/page.tsx`, returns `notFound()` when
  `NODE_ENV === "production"`): every `ds` component with fixture data, toolbar for theme, locale,
  reduced motion and a width switch (1440 / 1024 / 390 iframe-free: a max-width container). The web
  counterpart of mobile's debug gallery (D-R0.11).
- **Vitest (node)** for every pure function: formatting, contrast, chart math, trend, PRs, week groups,
  undo timing, CSV, derivations.
- **Playwright project `ds`** (`e2e/ds/*.spec.ts`) against the gallery: no backend, so it runs in CI next
  to `marketing` — keyboard behaviour (focus trap, Esc, focus return, roving focus, shortcuts), axe
  (`@axe-core/playwright`, already a dev dependency) with zero serious/critical violations in both
  themes, no horizontal scroll at 390.
- **No screenshot goldens** — CI runs on ubuntu, development on Windows; font rendering differs (same
  reason as mobile D-R0.11). Visual comparison is the iteration-end review (§4.1).
Rejected: adding jsdom + Testing Library for component tests — the gallery + Playwright covers the same
behaviours in a real browser with a dependency already present.

### D-W0.13 Motion: v2 durations + the web additions, one reduced-motion switch

CSS variables `--dur-hover 120ms`, `--dur-menu 160ms` (close 100), `--dur-modal 200ms`, `--dur-toast
200ms`, `--dur-drawer 300ms`, `--dur-sheet 350ms`, `--dur-count 600ms`, `--dur-fill 900ms`,
`--dur-celebrate 1200ms`, `--stagger 60ms`; curves `--ease-standard cubic-bezier(.2,0,0,1)`, `--ease-enter
cubic-bezier(.05,.7,.1,1)`, `--ease-exit cubic-bezier(.3,0,.8,.15)`. A `@media (prefers-reduced-motion:
reduce)` block sets every duration to `0ms`; `useReducedMotion()` does the same for JS/Recharts.

| Motion | Spec (DS-07) |
|---|---|
| Hover | 120 ms tone change, standard curve, no movement |
| Menu / popover | 160 ms opacity + 4 px from the trigger side; close 100 ms |
| Modal | 200 ms, scale 0.96 → 1 + fade, scrim 40 %; < 768 the v2 sheet (350 ms) |
| Drawer | 300 ms from the right, enter curve; the list behind does not move |
| Toast | 200 ms from 12 px below; undo bar drains linearly over 6 s; hover pauses |
| Numbers, rings | count-up 600 ms **from the previous value** (never from 0 on refetch); fills 900 ms from 0 on first appearance, 60 ms stagger; on a date change only the difference animates |
| Set done | 250 ms row tint + check; PR trophy pops once |
| Celebration | 1.2 s staggered entrance, trophy pops once, never loops |

### D-W0.14 One shell, three roles, route-driven chrome

`src/components/shell/AppShell.tsx` renders sidebar + top bar + content + bottom nav; the three route
groups keep their own guards (`(app)`, `(admin)`, `(superadmin)`) and pass a role config
(`clientNav`, `trainerNav`, `superadminNav` in `components/shell/navConfig.ts`). A per-route
`chrome` config decides: page title key, whether the **date stepper** shows (only pages that have a day:
dashboard, nutrition, water, steps, trainer client detail), what occupies the top-bar centre otherwise
(statistics period switcher, weight range switcher, calendar range), and `focus` mode (live workout,
onboarding: no sidebar, no top bar). Rejected: three shells (the drift that made superadmin look like a
different product) and one merged route group (the guards differ).

### D-W0.15 Overlay grammar: modal = short decision, drawer = edit in context, toast = something happened

- **Modal** (480 / 640 / 880, `--r-hero`): confirmation, RPE, celebration, focused task (add food).
  Centred in every theme (the left-shifted `fix2-003/004` dialog), initial focus on the **safe** button,
  Esc = cancel, focus trapped and returned; < 768 it becomes the v2 bottom sheet.
- **Drawer** (480–560, from the right, radius 30 on the inner edge): editing next to the list (edit
  meal, log weight, schedule, assign). Sticky header and footer; Esc and scrim click close; unsaved
  changes ask first.
- **Toast**: bottom centre, inverse surface (the v2 dark palette in both themes), one at a time; deletes
  always carry "Visszavonás / Undo" + the 6 s bar; errors don't auto-dismiss; above the FAB on mobile.
- **Popover / menu**: row "⋯" menus, copy-from-day, export, date popover. The last, destructive item is
  heart-coloured and ends with "…" — a confirmation follows.
One `OverlayRoot` portal under `<body>` owns z-order (toast > modal > drawer > popover > top bar).

### D-W0.16 Delete = confirm, then a 6-second undo that really undoes: the DELETE is deferred

`useUndoableDelete(entity, id, request)`: the row disappears optimistically (TanStack Query cache), the
toast runs 6 s, **the DELETE request is sent when the toast expires**, on "Undo" nothing is sent and the
cache is restored. On `pagehide` / route change / a second delete the pending one is flushed immediately
(`fetch(..., { keepalive: true })` with the in-memory access token). Rejected: delete immediately and
re-create on undo — the re-created entity gets a new id, which breaks mobile delta-sync references,
trainer assignments pointing at recipes/templates, and meal copies.

### D-W0.17 Keyboard layer: in-house `useHotkeys`, a `?` help overlay, tooltips on every icon button

Shortcuts (DS-06): `N` new entry on the current page · `/` search · `←` / `→` previous / next day · `T`
today · `[` toggle sidebar · `G` then a letter to switch page (`G D` dashboard, `G N` nutrition, `G W`
workouts, `G S` statistics …, the letter shown in the collapsed-nav tooltip) · `?` help. Tables: `↑/↓`
row, `Enter` open, `Shift+F10` row menu. Never fire while focus is in a text field or a modal owns focus.
Tooltips: inverse surface, 400 ms delay, also on keyboard focus, mandatory on icon-only buttons.

### D-W0.18 Hover, focus, targets (DS-06)

Hover = one surface step lighter (dark) / `--nested` (light), 120 ms; cards don't lift; only a fully
clickable card gets a pointer cursor. **Focus ring = keyboard only (`:focus-visible`): 2 px `--bg` gap +
2 px `--text` ring** (`box-shadow: 0 0 0 2px var(--bg), 0 0 0 4px var(--text)`) — AA on every surface
and independent of the brand colour; replaces today's inset primary outline. Form fields keep their own
focus style: 2 px primary border + 4 px primary halo (DS-03). Touch targets < 768 ≥ 44 px; desktop icon
buttons 32–40 px visual with a ≥ 32 px hit area.

### D-W0.19 Pure redesign: every element that needs data the API doesn't have is derived, hidden or an optional read-only backend step

Nothing new is persisted. Each gap found in the canvases, and its fate:

| Canvas element | Frame | Today | Decision |
|---|---|---|---|
| Clay chip "Célok: Szabó Bence" / "set by your trainer on Sep 12" / "he gets notified" | W1-A, W2-A, W6-G | Settings don't record who set the goals or when | **Hidden** — needs persisted attribution → Non-goal §6, §10 Q1 |
| Weight time "ma 07:02", weight note column | W1-A, W4-A | `WeightResponse` is `date` + `weight` only | Relative date only ("ma", "szept. 26."); no note column, no time field in the drawer → §6 |
| Weight "expected date", 7-day average, pace | W4-A | Derivable | Port `weight_trend.dart` (W1.6) |
| Food servings ("1 pohár · 150 g"), fibre, sugar, food favourites, Own vs Catalogue | W2-A/B/D | Not in the food model | Gram chips (100 g, last used) only; no fibre/sugar row; the "Favourites" filter = favourite **recipes**; one food list → §6 |
| Recipe photo | W2-E | **Exists** (`imageUpdatedAt`, thumbnail endpoint) | Show the photo when present, the macro-tint icon otherwise (the canvas assumed it was new data) |
| "Bence ajánlása" chip on a recipe | W2-E | A client can't tell an assigned copy from their own recipe | Hidden → §6 |
| PR 🏆 / ↑ marks, week grouping, template "last used" | W1, W3 | Derivable | Port `personal_record.dart` (must match backend `PersonalRecordCounter`), `session_groups.dart`, `week_summary.dart` |
| Rest timer default | W3-B | `Exercise.restSeconds`, `settings.defaultRestSeconds`, `restTimerEnabled` | Used as is |
| Onboarding BMR / TDEE explanation | W6-D | `SuggestGoalsResponse.bmr/.tdee` | Used as is |
| Settings: "daily summary e-mail", client "weekly report", separate kg/lb and L/fl oz | W6-G | Real toggles are the push flags; units are one `unitSystem` | Show the **real** toggles; one "Units" segmented control (Metric / Imperial) |
| Trainer client card: kcal % of goal | W7-A | `avgCalories7d` exists; the goal needs one request per client | Optional **W7.b1** adds `dailyCalorieGoal` to `TrainerClientResponse` (read-only); without it the card shows avg kcal, no % |
| Workouts this week "4 / 4", next session, program week | W7-A | Derivable from one `calendarSessions(from, to)` call + program assignments | Derived (W7.1) |
| Logging heatmap, activity feed | W7-B | Derivable from `clientMeals`, `clientWorkoutSessions`, `clientWeights` | Derived (W7.7) |
| "Emlékeztető küldése", "Gratulálok", "Válasz" | W7-A/D | No reminder endpoint | Opens the chat with a prefilled draft — no new endpoint |
| Trainer edits the client's step goal | W7-C | No endpoint | Read-only goal → §6 |
| Trainer comment on a meal | W7-C | Only workout-session comments exist | Hidden; workout comments stay → §6 |
| Calendar drag to move / Shift+drag to copy | W8-A | No move endpoint (only cancel) | Optional **W8.b1** (`PATCH /trainer/scheduled-sessions/{id}`), needs a go-ahead (§10 Q2); without it events aren't draggable, click → peek → "Reschedule" = cancel + schedule |
| Assign drawer "we'll shift conflicts by 1 hour" | W8-C | No auto-shift | Conflicts are **counted and named**, not shifted |
| Chat "online" dot, shared-workout card with "Áthelyezés" | W8-D | Presence isn't exposed; attachments are images only | Hidden → §6 (same as mobile 77 §6) |
| Invite "Elfogadva" history, shareable join link, "Emlékeztető" | W9-B | Pending invites with `expiresAt`; no link, no reminder | Pending + expired (from `expiresAt`); "Újraküldés" = cancel + re-invite; no link row → §6 |
| Superadmin KPIs, user names, trainer column, last login, global role history | W9-E/G | `SuperAdminUserResponse` = email, roles, createdAt; role audit per user | Optional **W9.b1** (names + trainer), **W9.b2** (KPI endpoint), **W9.b3** (global audit); without them: e-mail column, no KPI row, per-user history in a drawer; last login → §6 |
| Trainer request "Végzettség" | W9-F | Not collected | Hidden; motivation, expected clients, account age shown |

The optional backend steps are read-only aggregations over existing tables (the mobile R6.2 precedent)
and each UI step tolerates their absence.

### D-W0.20 Web logout is honest by construction

The web keeps no local outbox, so the confirmation copy is W6-G's: "Minden adatod a fiókodban van, újra
belépve ugyanitt folytatod. A mobilappban bejelentkezve maradsz." — true today (logout revokes the web's
refresh token only). Logout lives in the account menu (W0.20) and at the bottom of Settings (W6.12), both
opening the same `LogoutDialog`, initial focus on "Mégse".

---

## 4. Shared rules for every step

- Follow `web/AGENTS.md`: this is Next.js 16 — read the relevant guide in `node_modules/next/dist/docs/`
  before touching routing, layouts, `next/dynamic` or metadata.
- **No hard-coded strings** — every new or changed text goes into **both** `messages/en.json` and
  `messages/hu.json` with the same key (ICU plurals for counts: "1 gyakorlat / 1 exercise", "2
  exercises"). HU copy is the canvas text; EN copy follows DS-02/DS-05's EN examples. No raw enum keys
  or `ROLE_*` values on screen.
- **No hard-coded hex, `px` radius or `font-size` in files a step touches** — tokens, `type-*` utilities,
  `ds` components. A step that touches a file also moves that file off the legacy variables (D-W0.3) and
  off `components/ui` / `components/data`.
- Numbers and dates only through `lifeyFormat` (D-W0.8); no `toFixed` for display, no `date-fns`
  `format` for display.
- Keep behaviour identical unless the step says otherwise; relocations are called out explicitly.
- **Per-step checklist** (in `web/`): `npm run lint` · `npm run typecheck` · `npm test` · `npm run build`
  · `npx playwright test --project=ds` (once W0.5 lands) · `npm run check:js-budget` when the step
  touches `app/layout.tsx`, `globals.css` or anything the marketing tree imports · a quick look in the
  browser at **1440 dark HU and 390 light EN** of every page the step touched, plus the canvas frame the
  step names.
- **Every step ends with one commit, pushed** to `feature/web-redesign` (so it lands on the open redesign
  PR), message `Web: <what> (redesign W<n>.<m>)`, after the checklist passes; the step heading gets a ✅
  in this doc in the same commit, and a short *As built* note when the result deviates from the spec.
  The PR description's iteration checklist is ticked when an iteration's web UI review (§4.1) is logged.

### 4.1 Iteration-end web UI review (mandatory, every W)

After the last step of **every** iteration (W0 … W10), a thorough check in a real browser that every new
design element the iteration built looks and behaves the way the canvas describes. Tests and the gallery
catch structure; this catches what only the running app shows: real data, scroll, overlays, keyboard,
animation, navigation, both roles.

**Setup (once, reused every iteration):**
- Backend `:8080` and Postgres per `RUNNING.md`; chat service `:8081` (`chat/`, `mvnw spring-boot:run`);
  web `:3000` started with `NEXT_PUBLIC_CHAT_BASE_URL=http://localhost:8081/api/v1` (a local
  `/client-config` returns an empty chat URL). `next dev` daemonizes — the server is up even if the
  background runner reports it as failed.
- A `.claude/launch.json` entry (`web-dev`) so the in-app browser preview can start and drive it.
- Demo data from the handoff seed script (`lifey-web-redesign-handoff/capture-scripts/`, accounts
  `*.09271425@lifey.demo`): a client with a canvas-like day (≈ 1 041 / 1 900 kcal, three meals, 1,6 L water,
  6 412 steps, 30 days of weights with gaps, strength sessions with a PR, a run with splits and HR zones),
  a trainer with five clients (one inactive for 6 days, one with unread chat, one with a new PR), a
  program, pending and expired invites, a superadmin, a pending trainer request.
- The canvases served from this folder (§0.1).

**Procedure:**
1. Walk every page and overlay the iteration touched in this matrix: **1440 × 1024, 1280 × 800,
   1024 × 768, 390 × 844** · **dark and light** · **HU and EN** (browser context `locale: "hu-HU"` / `"en-US"`
   and the account language setting), plus one pass at **200 % browser zoom** (a 1280 window = 640 CSS
   px) and one with **`prefers-reduced-motion: reduce`** emulated.
2. For **every canvas frame of the iteration** (§0.2) take an app screenshot of the same state (same
   viewport, theme, language, selected tab/row/overlay) and put it next to the canvas frame rendered at
   the same width. Recharts pages: set the viewport height to the page's `scrollHeight`, wait ~2.8 s, then
   shoot (a `fullPage` shot re-animates the lines away). Log in through `/login` per browser context —
   refresh tokens are single-use. On Git Bash use `MSYS_NO_PATHCONV=1` for `/route` arguments.
3. Check against the canvas, **item by item**:
   - layout: grid spans, column widths, order, the 8 + 4 split, what moves where at 1024 and 390, no
     horizontal scroll at 390, nothing hidden under the top bar or the bottom nav;
   - spacing and radii (4-step scale), depth (tone ladder in dark, shadow in light — no borders);
   - colour: metric colours only on their metric, primary only on controls, clay only for the trainer
     role, heart for destructive, chip tints (D-W0.4);
   - type: hero numbers and page titles at the canvas size, tabular numbers, unit beside the number;
   - formatting: HU `69,6 kg`, `szept. 26.`, `18:00`, `2,4 e`; EN `69.6 kg`, `Sep 26`, `6:00 PM`,
     `2.4k`; no raw keys, no `ROLE_`, no ISO dates, no seconds; HU strings never truncated;
   - **every "Előtte → utána" note of the canvas** (listed per iteration below) — each is a requirement,
     checked by its PDF id;
   - states: hover, pressed, focus-visible, disabled, empty, error, loading skeleton (after 300 ms);
   - keyboard: Tab order, visible focus everywhere, the iteration's shortcuts, Esc and focus return on
     every overlay, `?` lists what the page supports;
   - motion: count-up from the previous value, ring/bar fills, drawer/modal/toast timings, celebration,
     and that reduced motion lands on the final state instantly;
   - charts: axis labels never clipped, goal line dashed, today dashed and excluded from the average, gaps
     not drawn as 0, legends present;
   - accessibility: axe on every touched page in both themes — zero serious/critical; ≥ 44 px targets at
     390; screen-reader names on icon buttons;
   - health: no console errors, no unexpected 4xx/5xx in the network log.
4. Exercise the **flows**, not just the screens: the iteration's demo flow from the §0 table, including
   the undo path of every delete and the unsaved-changes path of every drawer.
5. Write the result into **§12 Review log**: date, browser + version, viewports, *Matches*, *Deviations
   (intended)* with their decision ids, *Bugs*. Every bug becomes an extra step `W<n>.fix-<k>` (own commit),
   and the affected part is re-checked.
6. Send the side-by-side screenshots to the user. Screenshots are **not committed** (repo size); the
   review log is the durable record.

**The iteration is done when its review log entry has no open bug.**

---

## W0 — Foundation (general) · `Lifey Web Design System.dc.html`

**Goal:** everything web-wide that W1–W9 build on. After W0 every logged-in page renders the v2
palette, type and shell, and every component the screen canvases use exists in the gallery.

**Design source:** DS-01 … DS-07 (§0.2) for the web extension; the mobile
`docs/redesign/Lifey Design System.dc.html` for the unchanged token, type, radius, depth and motion
values (already decided in 77 D-R0.2 – D-R0.13).

**Principles every later step is held to** (web-redesign-prompt.md + DS header):
1. *One hero number per page* — remaining kcal, current weight, rest time, moving distance.
2. *Colour means data* — metric colours only on their metric; primary olive only on controls; clay only
   for the trainer role.
3. *Fewer boxes, more groups* — rows in one card with dividers; **never a card inside a card**.
4. *Hungarian is the yardstick* — sized for the longest HU label ("Ételeim & receptjeim"), no ellipsis.
5. *Wide means more side by side* — a page that leaves a half-empty right column is not done.

### W0.0 — Docs: make the canvases openable ✅
- Files: `docs/redesign-web/support.js` (copy of `docs/redesign/support.js`), `docs/redesign-web/README.md`
  (reading-order table).
- The DS canvas links "Lifey Design System.dc.html" relative to this folder; the mobile canvas lives in
  `../redesign/` — noted in the README (the canvas file itself is not edited).
- **Verify:** `python -m http.server 5510 --directory docs/redesign-web`, every canvas renders all frames.

*As built:* landed with the plan commit itself (the branch's first commit), so the canvases are openable
from the PR.

### W0.1 — Web UI: v2 colour tokens, legacy aliases, marketing pin, contrast test ✅
- Files: `web/src/app/globals.css`, `app/(marketing)/[locale]/layout.tsx` and
  `app/(marketing-bare)/[locale]/layout.tsx` + `app/not-found.tsx` (the `data-surface="marketing"`
  marker), `web/src/lib/theme/contrast.ts` + `contrast.test.ts` (new).
- Add the D-W0.4 tokens for dark (`:root`) and light (`[data-theme="light"]`), the semantic roles and the
  `@theme inline` colour keys (D-W0.3). Re-point every legacy variable per the D-W0.3 table inside the
  app scope; restore today's legacy values under `:root:has([data-surface="marketing"])` (D-W0.2).
- Test: WCAG relative luminance, the assertions in D-W0.4, plus "legacy `--tertiary` resolves to
  `--primary`" as a token-map test (parse `globals.css`, no browser needed).
- Grep and list in the commit body (fixed by the owning iteration, not here): uses of `--metric-protein`
  / `--primary` that mean the *other* thing (today light `--metric-protein` **equals** `--primary`
  `#586E38`, so the swap silently changes meaning), and `--tertiary` used as a trainer accent.
- **Verify:** contrast test green; `/dashboard`, `/admin`, `/superadmin/users` show the v2 bg/cards in both
  themes; `/hu` (marketing) is pixel-identical before/after (compare two screenshots); `check:js-budget`
  unchanged.

*As built:* `--float`, `--primary-tint`, `--role-tint`, `--scrim` and the two repointed `--*-container`
aliases use `color-mix(in srgb, …)` rather than pre-computed rgba, so `--scrim` (defined once, referencing
`var(--bg)`) automatically tracks the theme without a light-mode override. Verified in a real browser
(`/login`, dark and light) rather than `/dashboard` — the dashboard needs auth; the login page is app-scope
and unauthenticated, and showed the v2 tokens correctly in both themes. `/hu` confirmed pixel-identical
before/after in both themes via the marketing pin. Grep of `--metric-protein` / `var(--primary)` /
`--tertiary` usage (left for each owning iteration, not fixed here): `--tertiary` is used as the trainer
accent throughout `components/layout/AdminSidebar.tsx`, `app/(admin)/**`, `features/trainer/**` (~60
files) — cleared in W0.23. Light `--metric-protein` equalled `--primary` (`#586E38`) before this step; call
sites that relied on that coincidence to mean "primary" rather than "protein" need a look when their file
moves off the legacy names — none found reading `--metric-protein` for a primary-coloured accent rather
than the protein macro, but the two are no longer equal in v2 (light protein `#34742F` vs. primary
`#4E6530`), so a visual regression there would show as a metric-tinted element turning slightly warmer.

### W0.2 — Web UI: radius, spacing, elevation, blur, motion and breakpoint tokens ✅
- Files: `globals.css`, `web/src/lib/hooks/useReducedMotion.ts` (new) + test.
- `--r-tag/control/card/hero/pill` + legacy aliases (D-W0.5); `--e1 --e2 --e3` and the top light edge as
  inset shadows (`--edge-card inset 0 1px 0 rgba(255,255,255,.035)`, hero .05, float .07; none in light);
  `--blur-float 24px`; motion variables and the reduced-motion block (D-W0.13); `--breakpoint-2xl 90rem`,
  `--breakpoint-3xl 100rem` (D-W0.6); `--content-max 1320px`, `--reading-max 720px`, `--sidebar-w 248px`,
  `--sidebar-w-collapsed 76px`.
- **Verify:** `useReducedMotion` test (media query mocked); no layout change on existing pages beyond
  radii; build green.

*As built:* `--r-sm/md/input/lg/nav` and `--shadow-float` are also read directly by the marketing tree
(29 files, mostly via the `rounded-*` Tailwind utilities) — not caught by the D-W0.2 colour-only pin, so
the marketing `:has()` blocks in W0.1 got a second pass here restoring the pre-v2 radius and shadow values
inside `data-surface="marketing"`. Elevation (`--e1/e2/e3`, `--edge-*`) and the breakpoint/grid variables
are new names the marketing tree never referenced, so they needed no pin. Per the D-W0.3 table,
`--shadow-float` resolves to `--e1`, which is `none` in dark (v2 cards get their depth from surface tone,
not a shadow) — harmless today since nothing in the app scope reads `--shadow-float` yet (only marketing
did, now pinned), but worth knowing before a future step reaches for the legacy name expecting a visible
shadow. `useReducedMotion.test.ts` tests the non-reactive `prefersReducedMotion()` export by stubbing
`window.matchMedia` directly (the project's `vitest` environment is `node`, no jsdom/Testing Library per
D-W0.12) — the reactive `useReducedMotion()` hook itself is exercised once real components use it, from
W0.6 onward.

### W0.3 — Web UI: type utilities, `MetricValue`, `Icon` ✅
- Files: `globals.css` (`@utility type-*`, `num-*`, `.tabular` kept), `src/components/ds/MetricValue.tsx`,
  `src/components/ds/Icon.tsx`, `src/components/ds/index.ts` (barrel).
- Spec D-W0.7 and D-W0.10. `MetricValue({ value, unit, size, unitRatio, label })` renders tabular
  number + smaller unit in `--text-2` and one `aria-label` sentence.
- **Verify:** gallery arrives in W0.5 — until then a temporary check on `/dashboard`; typecheck.

*As built:* verified `type-headline` on `/login` (unauthenticated, app-scope) rather than `/dashboard`
(needs auth) — computed style matched the D-W0.7 spec exactly (30px/800/36px/−2%) once cleared of the
element's pre-existing Tailwind classes, then reverted (no lasting change to that file). Off-scale hero
numbers use a plain `.num` class with `font-size` set per instance by `MetricValue`, not a `num-[size]`
functional Tailwind utility — sizes vary continuously (28, 32, 56…) and a component prop is simpler than
generating arbitrary-value utility classes for it. `MetricValue`/`Icon` aren't wired into any page yet
(no consumer until W1); the dev gallery (W0.5) is the first place they render for real.

### W0.4 — Web UI: one formatting layer + typed messages + key parity ✅
- Files: `src/lib/format/lifeyFormat.ts` + `lifeyFormat.test.ts`, `src/lib/format/useFormat.ts`,
  `src/i18n/messages.d.ts`, `src/i18n/messages.test.ts`, `messages/en.json` + `hu.json` (label maps:
  roles, activity types, meal types, recurrence, occurrence status).
- Functions per D-W0.8, ported case by case from `mobile/test/core/format/lifey_format_test.dart`
  (negatives, 0, 999.95, 17 518.6, U+2212, HU weekday abbreviations H K Sze Cs P Szo V).
- Call sites are **not** migrated here — each iteration migrates its own.
- **Verify:** unit tests EN + HU; `npm run typecheck` fails when a key is removed from `en.json` (try it
  once, revert); parity test fails when a key is missing from `hu.json`.

*As built:* `src/i18n/messages.d.ts` became `src/i18n/messagesShape.ts` (a plain `.ts` file, not a
declaration file) and does **not** use next-intl's documented `AppConfig.Messages` global augmentation.
A trial run of that augmentation broke 47 files: the app ships two independent message catalogs (this
`messages/{en,hu}.json` for the authenticated app, `messages/marketing.{en,hu}.json` for the marketing
tree via `src/i18n/request.ts`) sharing one `next-intl` import, and dozens of existing call sites pass a
route- or state-driven `string` key (e.g. the top bar's page title) rather than a literal — both break
under a single global typed shape. Kept the "missing key = `npm run typecheck` failure" guarantee with a
narrower, self-contained mechanism instead: a mutual-assignability check between `Shape<typeof en>` and
`Shape<typeof hu>` (every string leaf → `true`), which only checks key shape and touches no other file
in the app; verified it actually fails by deleting a key and restoring it. Untangling the two catalogs
and typing every dynamic `t()` call site is real, separate work — worth its own step before `AppConfig.
Messages` can be turned on for real per-call-site key checking.

`messages.test.ts`'s ICU-placeholder check (the other half of D-W0.8, using `@formatjs/icu-
messageformat-parser` — the same parser next-intl uses internally, added as an explicit devDependency
since a plain regex can't tell a real `{name}` argument from a plural branch's literal text, e.g.
`{count, plural, one {client} other {clients}}`) caught a real, pre-existing bug while landing: Hungarian's
`dashboard.streakDays` didn't reference `{count}` at all, so the streak page silently dropped the number in
Hungarian. Fixed in `messages/hu.json` alongside the new `labels` namespace, since the test can't pass
otherwise. `useFormat()`'s enum-label lookups (`roleLabel`, `activityLabel`, `mealTypeLabel`,
`recurrenceLabel`, `occurrenceStatusLabel`) read a new top-level `messages/*.json` `"labels"` namespace
rather than the existing scattered ones (`workouts.activityTypes`, `superadmin.roleNames`, `nutrition.
breakfast`…) — those differ in exact wording from the D-W0.8 examples (the new `labels.roles.ROLE_USER` is
"Kliens" per the plan's "Kliens · Edző · Superadmin"; the existing `superadmin.roleNames.ROLE_USER` says
"Felhasználó") and migrating each call site off the old ones is each feature's own job, not this step's.

### W0.5 — Web UI: dev design gallery skeleton + the `ds` Playwright project ✅
- Files: `app/(dev)/dev/design/page.tsx` (+ `layout.tsx` with `Providers`), `src/components/ds/gallery/*`
  (section registry), `playwright.config.ts` (project `ds`, `testDir: ./e2e/ds`), `e2e/ds/gallery.spec.ts`,
  `.github/workflows/web-ci.yml` (run `--project=ds` next to `marketing`).
- Toolbar: theme, locale, reduced motion, width (1440 / 1024 / 390). Sections so far: colour swatches with
  live contrast ratios (✗ under 4.5), type scale, spacing, radius, elevation, motion demo, icon FILL demo,
  formatting table (DS-07 rows rendered through `lifeyFormat`).
- `notFound()` in production builds (test: `next build && next start`, `/dev/design` → 404).
- **Verify:** `npx playwright test --project=ds` green locally and in CI; axe zero serious/critical in both
  themes.

*As built:* sections so far are colour (live contrast ratios via a new `parseCssColor`, reading actual
computed `:root` values through a `useCssVar` hook + `MutationObserver` on `data-theme` — not a hard-coded
palette table, so it can't drift from `globals.css`), type, radius/spacing/elevation, motion (a replayable
fill bar per duration), icons (`Icon` at FILL 0/1 and five weights) and formatting (every `lifeyFormat`/
`useFormat` function against real output). Fields/date-picker/overlays/table/charts sections are added by
their own steps (W0.9–W0.19), not stubbed here. `--heart` has no defined "on-heart" foreground in D-W0.4 —
it's a text/icon colour, not a fill — so the colour section shows it that way (text on card, like every
other metric) rather than as a filled swatch that axe correctly flagged at 2.48:1. The type-scale demo
stacks the utility name above the sample instead of side by side: at 72px a single Hungarian word can be
wider than the 390px gallery column even after wrapping, so competing for horizontal room was never going
to work — this is a gallery layout choice, not a `type-display-xl` bug. Added `--force-reduced-motion`
(a plain rule beside the `@media` block) plus `setForcedReducedMotion()`/a same-tab event so the toolbar's
toggle drives both CSS transitions and `useReducedMotion()` consumers (from W0.6 on) without touching the
OS setting. Verified the production 404 by hand (`next build`; `.next/server/app/dev/design.meta` reports
`"status": 404`) rather than through Playwright, since the `ds` project's `webServer` is `next dev`
(`NODE_ENV=development`) same as every other e2e project here.

### W0.6 — Web UI: motion primitives ✅
- Files: `src/components/ds/AnimatedNumber.tsx`, `AnimatedFill.tsx` (drives rings and bars),
  `src/lib/motion/stagger.ts`.
- `AnimatedNumber` keeps the last shown value and animates old → new (600 ms, rAF, tabular so width is
  stable); the first render shows the value without counting from 0; a TanStack refetch with an equal
  value does nothing; reduced motion = final value on the first frame. `AnimatedFill` animates from 0 on
  first appearance, afterwards only the difference (D-W0.13).
- **Verify:** `e2e/ds/motion.spec.ts` — re-render with the same value: no animation frames; reduced
  motion: final text immediately; gallery "Motion" section.

*As built:* the reduced-motion and "already correct on mount" paths were originally a direct, synchronous
`setDisplay(...)` inside the effect body — the project's `react-hooks/set-state-in-effect` lint rule
correctly flags that (it can cascade renders); moved the reduced-motion snap into a single
`requestAnimationFrame` callback instead (still "the final value on the first frame", per D-W0.13, just
not before any frame has painted), and dropped the mount-time set entirely since `useState(value)` already
shows the right number. `e2e/ds/motion.spec.ts`'s "no animation frames" check ended up sampling the
rendered text repeatedly rather than counting `requestAnimationFrame` calls globally — the gallery page
has other legitimate rAF traffic (React's own scheduler, devtools) unrelated to `AnimatedNumber`, so a
global counter was flaky; asserting the visible text never flickers tests the actual user-facing guarantee
directly. `AnimatedFill` is a render-prop component (`children: (animatedValue) => ReactNode`) rather than
something that draws its own bar/ring — `ProgressRing`/`MetricBar` don't exist until W0.16, so it can't
know their markup yet; the gallery demo shows the shape a consumer would use. It reuses one `durationMs`
for both the first-appearance fill and later difference-only updates, rather than switching from 900ms to
600ms on update the way `AnimatedNumber` always uses 600ms — D-W0.13 doesn't specify a duration for a
fill's *non-first* update, only that only the difference animates, so this keeps one predictable knob
until a real consumer's canvas frame says otherwise.

### W0.7 — Web UI: surfaces and text components ✅
- Files in `src/components/ds/`: `Card.tsx` (`card` r22 / pad 20 (16 < 768) / e1 in light + edge in dark;
  `hero` r30 / pad 24–28 / e2; `nested` `--nested`, r = parent − padding; `interactive` adds hover +
  pointer + press 0.98), `SectionLabel.tsx` (12/16 caps + optional trailing "Mind / See all" link),
  `TintedChip.tsx` (26 small / 32 medium, D-W0.4 rule, optional icon), `DeltaChip.tsx` (arrow / signed,
  colour by semantic direction with a goal-aware override: a loss toward a lower goal is *improvement*
  green — W4 note), `RecordChip.tsx` (🏆 carbs gold), `ImprovementChip.tsx` (↑ protein green),
  `Avatar.tsx` (monogram from first + last name, e-mail fallback; photo when present; stable hue per
  person like mobile `MonogramAvatar.colorFor`; optional **role ring**: clay for trainer, neutral for
  superadmin — DS-02), `CountPill.tsx` (unread badge, primary pill).
- **Verify:** gallery sections "Cards & labels", "Chips & avatars"; `avatar.test.ts` ("Anna Kovács" →
  "AK", no name → e-mail initial); axe.

*As built:* `Card`'s `interactive` hover uses a flat `background: var(--nested)` in both themes via a new
`.lifey-card-interactive` class, not D-W0.18's full per-theme tone-step ladder (one surface step lighter in
dark) — that system doesn't exist until W0.18 lands; this is a placeholder the later step replaces.
`TintedChip`'s tint alpha (16% dark / 12% light, D-W0.4) is a new `--chip-tint` CSS variable rather than a
hard-coded percentage in the component, so `color-mix(in srgb, ${color} var(--chip-tint), transparent)`
resolves per theme automatically. `DeltaChip`'s `goalDirection` prop implements the W4 note precisely: a
delta moving *toward* the goal renders `--improvement` green regardless of its raw sign, and one moving
*away* from it renders `--heart` (not attempted in the plan's own one-line description, but the natural
complement — a chip that only ever turns green and never signals "wrong direction" would be half the
feature). `initialsFor`/`colorForSeed` are exported as named functions from `Avatar.tsx` rather than static
members of a class (no `MonogramAvatar.initialsFor`-style namespacing in this codebase's component
convention) — verified byte-for-byte against `mobile/lib/shared/widgets/ds/monogram_avatar.dart`'s
algorithm, including the exact hashing (`codeUnits`/`charCodeAt` agree for the BMP), so the same seed
produces the same colour on both clients.

### W0.8 — Web UI: buttons, icon buttons, tooltip, segmented control, tabs, switch, choice tile, focus ring ✅
- Files: `src/components/ds/Button.tsx` (primary, secondary = nested + hairline, tonal = primary tint,
  ghost, danger = heart; heights 40 desktop / 44 < 768 / 52 auth / 56 large CTA; r14; 15/700; pressed
  one tone lighter, no ripple), `IconButton.tsx` (32–40 visual, required `label` → `Tooltip` +
  `aria-label`), `Tooltip.tsx` (inverse surface, r8, 400 ms, on hover **and** focus, shows an optional
  shortcut chip), `SegmentedControl.tsx` (replaces `components/ui/SegmentedControl.tsx`: pill track
  `--control`, selected `--card` pill with e1 in light / `--raised` in dark, 13/600 → 700 selected;
  radiogroup semantics with arrow keys), `Tabs.tsx` (page sections, underline 3 px primary or pill
  variant, **horizontal scroll < 768 with the selected tab scrolled into view** — `client-079`),
  `Switch.tsx` (restyle), `ChoiceTile.tsx` (selected = tint + 2 px primary ring + ✓; radio or checkbox
  group, arrows + Space — `onboarding-006`), `Checkbox.tsx` (22 px, r7→8).
- `globals.css`: replace the `:focus-visible` outline with the D-W0.18 ring; keep `[data-ring-frame]` for
  wrapped inputs but with the field focus style.
- **Verify:** `e2e/ds/controls.spec.ts` — every button/chip hit area ≥ 32 px desktop, ≥ 44 px at 390;
  segmented and choice groups move with arrows; tooltips appear on focus; focus ring visible on
  `--bg`, `--card`, `--nested`, `--primary` in both themes (axe + a computed-style check).

*As built:* found and fixed a real cross-cutting bug while building the ring: an inline `style.boxShadow`
(Card's e1/e2, a selected segment's lifted pill, a checked ChoiceTile's ring) always wins over a
stylesheet rule regardless of specificity, so the naive `:focus-visible { box-shadow: … }` from the plan's
own wording was silently swallowed on every component that draws its own shadow. Fixed by exposing the
ring as `--shadow-focus` (default `0 0 0 0 transparent` — not the `none` keyword, which is invalid as one
layer of a multi-layer `box-shadow` list and broke `--e1`/`--segment-shadow`/the light `--edge-*` tokens
the same way once they were combined with it) and having each such component append
`, var(--shadow-focus)` to its own shadow. `e2e/ds/controls.spec.ts`'s ring check caught this directly
(the segmented-control assertion failed until the fix landed) — a genuinely useful test, not a rubber
stamp. Also gave interactive `Card` real keyboard support (`role="button"`, `tabIndex`, Enter/Space →
`onClick`) since a focus-ring test on a div with no way to reach it by keyboard would have been hollow.
`axe` also caught two unrelated contrast bugs while re-running against the growing gallery: `Avatar`
hard-coded a 16% tint regardless of theme (should read `--chip-tint`, 12% in light) and additionally
blended toward `var(--bg)` the way mobile's `MonogramAvatar` does — correct for mobile's scaffold-centric
placement, but `--bg` on the web is warmer/darker than white, so even at the right 12% alpha a
water-tinted avatar fell to 4.44:1 outside a card. Both fixed: `--chip-tint` for the alpha, blending
toward `transparent` instead of `--bg` so it composites against whatever it actually sits on (verified
≥ 4.5:1 for all eight metrics at 12%/16% once on a card, the way every real call site places one). The
"Chips & avatars" gallery section is now wrapped in a `Card` for the same reason — chips and avatars are
never placed directly on bare `--bg` in the real app, and the gallery demo shouldn't be the one place that
does. Tooltip and IconButton are CSS-only (`:hover`/`:focus-within`), not yet on `useAnchoredPosition`
(that primitive doesn't exist until W0.11), so they always open above their trigger with no flip.

### W0.9 — Web UI: form fields with every state ✅
- Files: `src/components/ds/field/{Field,TextField,PasswordField,NumberField,TimeField,TextArea,ReadOnlyField}.tsx`,
  `src/lib/forms/rhf.ts` (react-hook-form + zod adapters).
- States (DS-03 light + dark): default (`--control` fill, no border), hover (`--raised` dark / surface-3
  light), focus (2 px primary + 4 px halo), error (heart ring + icon + message "Legalább 8 karakter kell
  (most 6)."), disabled, **read-only = plain text, no field shape** (`client-032`: "Kliens · csak
  olvasható"). Label above, hint below, 52 px tall on auth pages, 44 in dense panels.
- `NumberField`: unit inside the field, − / + steppers, `step`, **max. 1 decimal, locale decimal
  separator on display and input** ("166,7 g", not "166.68 g"), arrow keys ± step, Shift ± 10 × step.
- `TimeField`: 24 h (EN 12 h display), never seconds ("18:00", not "18:00:00" — `trainer-023`), quick
  chips (e.g. 17:30 / 18:30).
- **Verify:** `numberField.test.ts` (HU "166,7" ↔ 166.7, EN "166.7", clamp, rounding); gallery "Fields";
  axe — every field has a label and its error is `aria-describedby`.

*As built:* `TimeField` types 24-hour ("17:30") while focused and shows the locale's own display at rest
via `lifeyFormat.time` ("18:00" HU, "6:00 PM" EN) — not full bidirectional 12-hour text parsing, which adds
real ambiguity ("5:30" — AM or PM?) for a field whose whole job is picking one unambiguous moment; typing
is genuinely a different interaction from reading, so this doesn't cheat the display requirement, and no
native `<input type="time">` is used anywhere (its per-browser chrome the design system doesn't control).
`useZodForm` (src/lib/forms/rhf.ts) needed one `as any`/`as never` pair at the `zodResolver()` call:
Zod 4's generic internals don't unify against an arbitrary `S extends ZodType<FieldValues>` the way they do
against a schema TypeScript sees concretely at a real call site — the wrapper's return type (`z.infer<S>`)
is what every caller actually depends on, and stays fully checked; only the internal resolver wiring is
cast. Two more `set-state-in-effect` lint hits (W0.6's fix, same rule) in `NumberField`/`TimeField`'s
external-value resync — moved to React's "adjust state during render" pattern (comparing a `prevValue`
tracked in state) instead of a `useEffect`, which needs no cast and is the documented fix for exactly this
"state derived from a prop" shape. Found a third, unrelated CSS trap while giving `TextArea` a top-aligned,
growable field shape: `globals.css` has no `@layer`, so its custom classes (`.lifey-field`, etc.) are
unlayered and always outrank a Tailwind utility on the same property regardless of source order —
`items-start` silently lost to `.lifey-field`'s own `align-items: center`. Fixed with another custom class
(`.lifey-field-autoheight`) rather than a Tailwind utility; noted for every later step, since it'll recur
for any component overriding this file's own classes.

### W0.10 — Web UI: date picker, two modes; no native date input anywhere ✅
- Files: `src/components/ds/date/CalendarPopover.tsx` (month grid Monday-first, today filled primary,
  selected ring, dots = "has data" via a prop, future days muted/disabled by prop, ←/→/↑/↓/PageUp/PageDown
  keyboard), `src/components/ds/date/DateFields.tsx` (typed segments in locale order — HU year · month ·
  day, EN month · day · year; for far dates like birth dates — `onboarding-004`), `DateButton.tsx`
  (trigger showing `lifeyFormat.longDate`).
- Replaces `components/ui/DatePicker.tsx` / `TimePicker.tsx` at their call sites in each owning
  iteration; grep `type="date"` / `type="time"` and list the call sites in the commit (`client-020`).
- **Verify:** `e2e/ds/date.spec.ts` (keyboard, disabled future, typed HU and EN order); gallery.

*As built:* the grid needed a real ARIA row structure axe caught immediately — `role="grid"` requires
`role="row"` children with `role="gridcell"` nested inside them, not 42 gridcells as direct children.
Fixed with a `display: contents` row wrapper per week: it satisfies the ARIA tree without breaking the
`grid-cols-7` CSS layout, which needs the cells as direct grid-item children to place correctly. axe also
caught the muted (out-of-month/disabled) day styling: `opacity: 0.35` dims the background along with the
text, and the resulting contrast fell under AA in both themes — switched to a plain `color: var(--text-3)`
(already verified ≥ 4.5:1 on every surface) instead of fading. Keyboard model is a separate "focused
cursor" from the committed selection (arrows move `focusedDate`, Enter/Space calls `onChange`) rather than
selecting on every arrow press — the more common date-grid pattern, and it means `disableFuture` only has
to guard the one commit path. `DateFields`' per-segment `aria-label` includes the field's own label
("Birth date – month") rather than just the segment name: an `aria-label` always wins over an associated
`<label>` for the accessible name, so the bare segment name alone would have made every date field's first
input impossible to distinguish from another by screen reader users.

### W0.11 — Web UI: popover, menu and row "⋯" menu ✅
- Files: `src/lib/a11y/{useAnchoredPosition,useDismiss,useRovingFocus,useFocusReturn}.ts`,
  `src/components/ds/Popover.tsx`, `Menu.tsx` (`MenuItem` icon + label + shortcut; destructive last item
  in heart with "…"), `RowMenuButton.tsx` (the table/list "⋯", 32 px, opens on click and `Shift+F10`).
- 160 ms open / 100 ms close; flips above when there is no room below; closes on Esc and outside click;
  focus returns to the trigger.
- Decide §10 Q3 here (in-house positioning vs Floating UI) and record it as *As built*.
- **Verify:** `e2e/ds/menu.spec.ts` (arrow navigation, typeahead, Esc, focus return, flip near the bottom
  edge at 390 × 844).

*As built:* §10 Q3 decided **in-house positioning**, not Floating UI — `useAnchoredPosition` is ~30 lines
(measure the trigger, flip above when `window.innerHeight - rect.bottom` is under the panel height, clamp
horizontally to the viewport) and the full `e2e/ds/menu.spec.ts` suite (including the edge-flip case at a
squeezed 500px-tall viewport) passed against it without needing a second iteration. Revisit only if a later
step's overlay needs something this can't do (nested/scrollable-ancestor tracking, `middleware`-style
collision avoidance) — nothing so far has. `Popover` portals straight to `document.body` rather than a
shared `OverlayRoot`, since that component doesn't exist until W0.12; W0.12 can fold this in once
modal/drawer/toast exist to actually contend for z-order with. The flip test used a 500px-tall viewport
rather than 390×844 (a *narrow* phone, not a *short* one) — the edge case `useAnchoredPosition` flips for
is running out of vertical room, which a 390-wide viewport alone doesn't exercise.

### W0.12 — Web UI: modal + mobile sheet ✅
- Files: `src/lib/a11y/useFocusTrap.ts`, `src/components/ds/overlay/{OverlayRoot,Modal,Sheet,ConfirmModal}.tsx`.
- Widths 480 / 640 / 880, `--r-hero`, `--nested` fill in dark / white in light, scrim 40 %, 200 ms
  0.96 → 1; centred; initial focus on the element marked `data-autofocus` (the safe button in
  `ConfirmModal`); Esc = cancel; scroll inside the modal, not the page; < 768 renders as `Sheet` (handle
  36 × 4, radius 30 on top, 350 ms, safe-area aware). `ConfirmModal` = DS-03 sample: 48 px tinted icon
  holder, 22/800 title, body, "Mégse" + danger action; buttons stack when they don't fit (HU at 200 %).
- **Verify:** `e2e/ds/modal.spec.ts` (trap, Esc, focus return, scroll lock, sheet at 390); gallery.

*As built:* `--modal-bg` (`--nested` dark / `--card` light) and `--modal-scrim` tokens added to
`globals.css`, plus `lifey-modal-enter` / `lifey-scrim-enter` / `lifey-sheet-enter` keyframes; the
mobile/desktop split uses the existing `useMediaQuery("(max-width: 767px)")` from W0-earlier rather than a
new hook. Fulfilled W0.11's own As-built promise: introduced a real `OverlayRoot` (a dedicated DOM node
under `Providers`, via `getOverlayContainer()`) and retrofitted `Popover.tsx` to portal there instead of
straight to `document.body`, so overlay z-order can now be coordinated on siblings once drawer/toast exist
(D-W0.15). Caught two real bugs against the gallery + e2e: (1) `Sheet` didn't forward `aria-label`, so the
mobile shape rendered as an unlabelled dialog while the desktop `Modal` had a real accessible name —
fixed by threading `aria-label` through `Modal` → `Sheet`; (2) focus never returned to the trigger after
Esc/outside-click — `useFocusTrap`'s effect (which moves focus into the dialog) ran *before*
`useFocusReturn`'s effect (which captures `document.activeElement`) because of hook declaration order, so
it captured the dialog's own newly-focused child instead of the trigger. Fixed by calling `useFocusReturn`
before `useFocusTrap` in `Modal`. `e2e/ds/modal.spec.ts` scopes every `dialog` role query by accessible
name, since the gallery's own "Date picker" section keeps a `CalendarPopover` (also `role="dialog"`) open
by default — a bare `getByRole("dialog")` matches both.

### W0.13 — Web UI: drawer ✅
- Files: `src/components/ds/overlay/Drawer.tsx`, `src/lib/a11y/useUnsavedGuard.ts`.
- 480 / 520 / 560 wide, from the right, 300 ms enter curve, radius 30 on the inner edge, sticky header
  (13/600 overline + 22/800 title + 40 px close) and footer (secondary + primary, 44 px, r14), Esc and
  scrim click close, **unsaved changes ask first** (a small `ConfirmModal`: "Elveted a változásokat?").
  < 768 it becomes a full-height `Sheet`.
- **Verify:** `e2e/ds/drawer.spec.ts` (Esc closes — the recorded bug `trainer-011`; dirty form asks; focus
  return).

*As built:* `Drawer` composes the existing primitives rather than adding new ones — `useFocusReturn` +
`useFocusTrap` (same ordering fix as W0.12: capture focus before the trap moves it), the shared
`OverlayRoot`, and `Sheet` reused for its < 768 shape via a new `fullHeight` prop (100dvh instead of the
short-decision 85vh cap, and `flex flex-col overflow-hidden` on the panel instead of the default
`overflow-y-auto`, so the header/footer stay sticky and only the body scrolls). The unsaved-changes guard
(`useUnsavedGuard(isDirty, onClose)`) intercepts Esc, the scrim click, and the header ×, routing all three
through one `requestClose()` that only shows the confirm when `isDirty`; the confirm itself is the existing
`ConfirmModal` (a `Modal`), portaled into the same `OverlayRoot` and stacking correctly on top of the
open drawer without any z-index coordination beyond DOM order. Copy is placeholder English ("Discard
changes?" / "Keep editing"), matching the DS-level pattern of `ConfirmModal`'s own gallery sample — real
i18n keys land when a feature (W7.12's schedule drawer, closing the `trainer-011` loop) actually consumes
it. Added a `type-overline` utility (13/600) alongside the existing type scale for the header's overline
line, and `--dur-drawer`/`lifey-drawer-enter` (translateX) were already anticipated by W0.12's own comment
in `globals.css`.

### W0.14 — Web UI: toast with undo + `useUndoableDelete` ✅
- Files: `src/components/ds/overlay/Toast.tsx` (replaces `components/ui/Toaster.tsx`),
  `src/lib/hooks/useToast.ts` (API kept: `show(message, variant)`; new `showUndo(message, onUndo,
  onCommit)`), `src/lib/hooks/useUndoableDelete.ts` + `useUndoableDelete.test.ts`.
- Bottom centre (above the FAB and bottom nav < 768), inverse surface, 52 px tall, radius
  `--r-control` 14 (the DS-03 sample draws 18 — equidistant from 14 and 22; it snaps to the control step
  because a toast is a single-line control bar, D-W0.5), one at a time (a new toast replaces the old one and **flushes** its
  pending delete), 6 s linear bar, hover and focus pause, error variant sticky with a close button,
  `aria-live="polite"` (errors `assertive`).
- `useUndoableDelete` per D-W0.16: optimistic cache removal, deferred DELETE, restore on undo, flush on
  `pagehide` / route change / the next delete, error → restore + error toast.
- **Verify:** unit tests with fake timers (commit at 6 s, no request on undo, flush on second delete,
  hover pause extends); `e2e/ds/toast.spec.ts`.

*As built:* the `show(message, variant)` API is untouched — all 40+ existing call sites keep working —
`showUndo` is purely additive. All timer/pause/flush state (a single in-flight `setTimeout`, remaining-ms
bookkeeping, the pending commit) lives in the `useToast` zustand store as module-level state, not in the
`Toast` component or in `useUndoableDelete` itself — `useUndoableDelete`'s actual orchestration is a plain
exported function (`undoableDelete`, not a hook), specifically so `useUndoableDelete.test.ts` can call it
directly with `vi.useFakeTimers()` instead of needing `renderHook`/Testing Library, which this project
doesn't have (D-W0.12: node-environment Vitest, no jsdom). "Inverse surface" is implemented as two fixed
tokens (`--toast-bg`/`--toast-fg`, the v2 **dark** palette's `--nested`/`--text`) defined once at `:root`
and never re-pointed inside `[data-theme="light"]` — deliberately different from `Tooltip`'s approach
(swapping `--text`/`--bg`), because a toast needs one constant look in both themes rather than a per-theme
inversion. The deferred DELETE always goes through a new `keepaliveDelete()` in `lib/api/client.ts`
(`fetch(..., { keepalive: true })` with the in-memory access token) rather than the normal `api.delete()` —
not only for the pagehide/flush path but for the ordinary 6 s-elapsed commit too, since `keepalive` is
harmless in the normal case and having one code path avoids a fetch call that behaves differently
depending on why it fired. Route-change and `pagehide` flushing both live in `Toast.tsx` (always mounted
via `Providers`) rather than in `useUndoableDelete` itself, since the hook is only mounted for the
duration of the triggering action, not for the app's whole lifetime. Added a `common.undo` message key
(EN/HU) since none existed. No existing call site was migrated onto `useUndoableDelete` yet — that happens
per-feature as each iteration reaches its own delete flow.

### W0.15 — Web UI: data table v2 ✅
- Files: `src/components/ds/table/{DataTable,TableToolbar,TablePagination,useTableKeyboard}.tsx`
  (replaces `components/data/DataTable.tsx`).
- DS-03 table: container card r22; toolbar = search (320 × 40, r14, `/` focuses it), filter chips (40,
  pill), density segmented (comfortable **56** / compact **44** row), primary action; header 40 px,
  13/600, sentence case; sort arrow on the active column, faint arrow on hover elsewhere; numbers
  right-aligned with a smaller unit; optional **metric dot** in a column header (the macro columns); row
  hover `--nested`, selected row primary @ 8 % + 3 px inset primary bar; **one "⋯" per row, no icon
  rows**; footer "18 étel · 1–5. sor" + page buttons; ↑/↓ moves the active row, Enter opens,
  `Shift+F10` opens the row menu. **< 768 every row renders as a card row** (title, meta line, value,
  "⋯").
- Generic over a column definition (`{ key, header, align, width, metricDot, render, sort }`).
- **Verify:** `e2e/ds/table.spec.ts` (sort, keyboard, density, card rows at 390); gallery with the DS-03
  foods sample.

*As built:* `useTableKeyboard.ts` (not `.tsx` — it returns no JSX, matching every other hook file in
`lib/a11y`/`lib/hooks`). The desktop `<table>` reuses the roving-tabindex pattern from `Menu.tsx`
(`rowRefs` + focus-on-`activeIndex`-change) rather than a new primitive, and the active row's focus ring
comes for free from the existing global `:focus-visible` → `--shadow-focus` mechanism once real DOM focus
moves there — no separate "active" visual state needed. `RowMenuButton` (W0.11) gained optional
`open`/`onOpenChange` props so `DataTable`'s own `Shift+F10` handler (fired while the *row*, not the "⋯"
button, holds focus) can open a specific row's menu — it stays fully backward compatible (omit both, it
manages its own state as before). "Filter chips" and "primary action" are a single generic `filters`/
`action` `ReactNode` slot on `TableToolbar` rather than a dedicated filter-chip subsystem, since no
concrete filter shape exists yet; a real feature iteration can build a chip row inside that slot. The
container reuses `Card`'s "card" variant *styling* (radius, `--e1`, `--edge-card`) copied inline rather
than the `Card` component itself, since `Card`'s own fixed padding can't be zeroed via a Tailwind
utility override (the established unlayered-class gotcha) and the table's toolbar/rows/footer each need
their own padding. Two real bugs surfaced building the DS-03 gallery sample: the sort-direction arrows
were hand-rolled `<span>`s instead of the `Icon` component, so their ligature text ("arrow_upward") wasn't
`aria-hidden` and leaked into each column header's accessible name; and giving every row's "⋯" the same
default "More actions" label (fine for a single row) collided across 10+ rows at once, so `DataTable`
takes an optional `rowMenuLabel` to disambiguate them (e.g. "More actions for Chicken breast"). Not
migrated onto the sole existing consumer (`FoodsView.tsx`) yet — that happens at its own nutrition
iteration, same as every other DS component replacing a `components/ui`/`components/data` original.

### W0.16 — Web UI: progress components ✅
- Files: `src/components/ds/progress/{ProgressRing,MetricBar,RatioBar,SegmentBar,MetricTile}.tsx`
  (replace `components/data/MacroRing.tsx`, `KpiCard`, `StatCard`, `HeroMetricCard` at their call sites
  per iteration).
- Ports mobile R0.9: ring stroke = 15/160 of the size, track `--control`, round caps from 12 o'clock,
  over-goal second lap in the same colour with a soft shadow; `MetricBar` 7 px; `RatioBar` 10 px with
  3 px gaps (kcal ÷ goal when a total is given, else 100 % split); `SegmentBar` = the W1 water tile's 10
  segments (full, partial @ 45 %, empty `--control`); `MetricTile` = icon + label + meta ("utoljára
  14:10"), value, bar/segments, subline, optional trailing quick actions and a "⋯".
- **Verify:** gallery states 0 / 22 / 100 / 130 %; `ringSweeps.test.ts` (never > 360° + one lap).

*As built:* `ProgressRing`/`MetricBar`/`RatioBar`'s math (`ringSweeps`, the stroke = 15/160 formula, the
12-o'clock start, the over-goal second-lap-with-shadow, `RatioBar.fractions`) is ported byte-for-byte from
mobile's `progress_ring.dart`/`metric_bar.dart`, verified against the actual Dart source rather than the
plan summary alone. The ring itself is SVG (`stroke-dasharray`/`dashoffset` + a `rotate(-90)` transform to
start at 12 o'clock), not Canvas — simpler to reason about in React and no cap-seam artifact to special-case
at a closed 100% lap the way Canvas needed. Both `ringSweeps` (co-located in `ProgressRing.tsx`, per the
`Avatar.tsx`/`avatar.test.ts` precedent) and `RatioBar.fractions` get their own pure-function test file.
Reused the existing `AnimatedFill` (W0.6) and `MetricValue` (W0.7, whose own doc comment already
anticipated a tile's 0.5 `unitRatio`) rather than re-deriving mobile's separate `AnimatedFill`/value-text
logic. `SegmentBar` has no mobile precedent — the plan's own text flags it as a W1 water-tile design — so
it's a fresh implementation: a segment is full, a fixed 45%-filled "partial" (the one segment straddling
the boundary, a deliberately constant mark rather than its exact fractional remainder, to avoid a
sliver-thin fill), or empty. `MetricTile` adds the plan's own web-only `meta` (small header text) and
`rowMenu` (a `RowMenuButton`) alongside the ported mobile layout, since the DS-03 web spec calls for them
and mobile's `metric_tile.dart` doesn't have them; the mobile canvas's overhanging 48dp corner quick-add
button wasn't ported as-is (no web canvas confirms that exact treatment) — `actions` is a plain inline
header slot instead. No existing call site (`MacroRing`/`KpiCard`/`StatCard`/`HeroMetricCard`) was migrated
yet — happens per-feature at its own iteration, same as every other DS-v2 component so far.

### W0.17 — Web UI: empty, error and loading states ✅
- Files: `components/status/{EmptyState,ErrorState,Skeleton}.tsx` (restyled in place, APIs kept),
  `src/components/ds/states/DelayedSkeleton.tsx`.
- `EmptyState` (DS-05): tinted icon holder (metric colour or primary), 17/700 title that says what to do,
  body with the payoff ("Egy mérés után látod, mennyi van hátra; három után a heti trendet."), primary +
  optional secondary action. `ErrorState`: `sync_problem` icon in heart tint + heart hairline ring, title
  "Nem sikerült betölteni a …", reassurance ("A többi oldal működik; a naplózott adatod nem veszett el."),
  "Újrapróbálás" + "Részletek" (expands the error code). `DelayedSkeleton`: renders only after 300 ms,
  shaped like the final layout, static under reduced motion.
- **Verify:** gallery "States" in HU and EN; existing call sites still compile.

*As built:* both components keep their exact existing prop names — `icon`/`title`/`body`/`action`
(`EmptyState`) and `message`/`onRetry`/`inline` (`ErrorState`) — so all 36 existing call sites compile
unchanged (`tsc --noEmit` across the whole project, not just the two files); new DS-05 behaviour is
additive-only: `EmptyState` gained `secondaryAction`/`color` (default `--primary`), `ErrorState` gained
`entity` (parameterizes the title via a new `status.errorTitleFor` message key, "Couldn't load {entity}" /
"Nem sikerült betölteni: {entity}") and `code` (the "Details" toggle, local `useState`, no new dependency).
17/700 snapped to the existing `type-title-s` (16/700) — 17 isn't itself a scale step and is far closer to
16 than to `type-title`'s 20, matching D-W0.5's snap-to-scale rule. `Skeleton.tsx` itself needed no prop
changes, but its `.skeleton-pulse` animation had no reduced-motion handling at all (kept pulsing under both
the OS setting and the gallery's forced toggle) — fixed by routing its duration through a new
`--dur-skeleton` token, following the exact same 0ms-under-reduced-motion pattern every other `--dur-*`
token already uses, rather than inventing a separate mechanism. Caught a real AA contrast failure building
the gallery's "States" section: `ErrorState`'s inline "Details" link used `--text-3` (tuned against the
page background) on top of the heart-tinted inline background, dropping under 4.5:1 in both themes; fixed
to `--text` (proven passing at that same background by the adjacent message text). No existing call site
was migrated onto the new `entity`/`code`/`secondaryAction` props yet — same per-feature-iteration pattern
as every other W0 step.

### W0.18 — Web UI: chart math + `LifeyBarChart` ✅
- Files: `src/components/ds/charts/chartMath.ts` + `chartMath.test.ts`, `LifeyBarChart.tsx`,
  `LifeyBarChart.lazy.tsx` (`next/dynamic`, `ssr: false`, skeleton placeholder).
- D-W0.9. Unit tests ported from `mobile/test/shared/widgets/charts/bar_chart_test.dart` (ticks for max
  0, 7, 2 360, 13 000; average excludes today; ignoreZero).
- **Verify:** gallery "Bar chart" = DS-04 calories sample (V H K Sze Cs P Ma, goal 1 900, today dashed,
  average 1 812 without today); `check:js-budget` unchanged.

*As built:* `chartMath.ts` bundles all five functions the plan's D-W0.9 lists under one file — `niceAxisMax`
and `yAxisTicks` are genuinely in mobile's `chart_math.dart`; `averageExcludingPartialToday` too, ported
with its exact `bar_chart_test.dart` cases (including the "value logged at 00:10 is still today" edge
case). `weeklyBuckets` and `movingAverage` aren't actually in `chart_math.dart` despite the plan text's
phrasing — the real sources are `features/statistics/domain/metric_summary.dart`'s `weekStart`/`weeklySums`
(consolidated here as one `weeklyBuckets`, tested against its exact `metric_summary_test.dart` case) and
`features/weight/domain/weight_trend.dart`'s `movingAverage` (ported with its exact gap-aware,
days-not-samples window logic) — verified against the actual Dart source rather than trusting the plan
summary. Confirmed by reading mobile's actual `bar_chart.dart` that today's dashed/unfilled outline and the
60%/80% theme-dependent past-bar opacity are **not** existing mobile behavior to copy — current mobile bars
are solid-highlighted-or-45%-flat-opacity with no dashed-today treatment (only the goal line is dashed
there) — so `LifeyBarChart`'s bar rendering follows this plan's own DS-04 spec directly rather than porting
mobile pixels; only the five `chartMath` functions are literal ports. Implemented as a Recharts `<Bar
shape={...}>` custom render (a rounded rect, uniformly on all four corners rather than top-only, since
Recharts has no built-in per-corner radius on a custom shape and a full custom path wasn't worth it for a
short bar where the difference is barely visible) so the same shape function can also draw the optional
"met goal" check glyph, an optional value label, and a rest-day dot on the baseline — all from one place
per bar. The dark/light branch for past-bar opacity reads the existing `useTheme` zustand store (resolving
`"system"` against a live media query) rather than a one-off `document.documentElement` read, so it updates
immediately if the viewer flips the toggle without a remount. Kept out of the main `ds/index.ts` barrel
entirely (component and lazy wrapper both) — D-W0.9's own text warns about a prior 95KB Recharts leak into
marketing, and importing by direct path (`@/components/ds/charts/LifeyBarChart.lazy`) is the safer
insurance against a future barrel-wide import accidentally pulling it in; `check:js-budget` numbers are
byte-for-byte identical to before this step, confirming no leak.

### W0.19 — Web UI: `LifeyLineChart` (and `TimeSeriesChart` callers keep working) ✅
- Files: `src/components/ds/charts/LifeyLineChart.tsx` (+ `.lazy.tsx`), `components/data/TimeSeriesChart.tsx`
  (becomes a thin adapter over `LifeyLineChart` with today's defaults, deleted in W10.3).
- D-W0.9 line rules; `movingAverage` with gaps; "no data" band; goal line; last point 12 px with a 4 px
  card-colour ring; legend "napi mérés · 7 napos átlag · cél".
- **Verify:** gallery = DS-04 weight sample (aug. 18. – szept. 27., gaps, 72 / 68,5 / 65 axis, goal 65 kg);
  the existing weight/statistics/trainer charts still render.

*As built:* unlike `chartMath.yAxisTicks`'s 0-anchored scale (right for a bar count), the line chart's own Y
axis spans the data's actual value range — a new `lineAxisTicks(dataMin, dataMax, goal)` local to
`LifeyLineChart.tsx` (floor/ceil to whole numbers, exact midpoint), not a mobile port (no canvas or Dart
source names this specifically); it reproduces the exact 72/68.5/65 example. `TimeSeriesChart` really did
become a thin adapter, not just a note-for-later: all four existing call sites
(statistics/weight/`ClientStatisticsTab`/`ClientStepsTab`) pass a `SeriesPoint[]` with a pre-formatted date
*string*, not a real per-point `Date` — `LifeyLineChart` needs a real `Date` for its own bookkeeping
(last-point lookup, the average calculation), so `LineChartPoint` gained an optional `label` override that
takes priority over the auto-formatted `shortDate(date)`; the adapter feeds it synthetic sequential dates
(pure internal plumbing, gaps/average impossible on old plain-number data anyway) plus each point's
original string as `label`, so the X axis still shows exactly what the caller always passed. `tsc --noEmit`
across the whole project — not just the two chart files — confirms all four call sites still compile
against the new signature; `check:js-budget` numbers are unchanged, same reasoning and same
direct-path-only import discipline as W0.18's `LifeyBarChart`. The tooltip the old `TimeSeriesChart` had
(hover to see the exact value + unit) moved into `LifeyLineChart` itself rather than being dropped — an
adapter silently losing an interactive feature its callers already relied on isn't "keeping call sites
working."

### W0.20 — Web UI: sidebar v2 (client) + account menu ✅
- Files: `src/components/shell/{AppShell,Sidebar,SidebarItem,AccountMenu,LogoutDialog,navConfig}.tsx`,
  `src/lib/hooks/useSidebarState.ts`, `app/(app)/layout.tsx` (uses `AppShell`), delete
  `components/layout/Sidebar.tsx` usage for the client.
- DS-02 "KLIENS · nyitott 248": floating panel 12 px from the viewport edge, `--card`, r22, padding
  16 / 12; logo row (36 px tile r14, "Lifey" 20/800, collapse button 32 px `left_panel_close`); items
  44 px, r14, icon + 15/600 label, gap 12; **active = filled primary pill, FILL 1 icon, 15/700**; hover
  `--nested` 120 ms; divider; "Beállítások"; user chip at the bottom (36 px avatar, name 14/700, e-mail
  12/500, `unfold_more`) = **account menu**: Beállítások, Téma (Rendszer / Világos / Sötét), Nyelv,
  Kijelentkezés… → `LogoutDialog` (D-W0.20).
- Collapsed 76 (DS-02 "ÖSSZECSUKOTT"): 48 × 44 items, tooltip with label + `G` shortcut after 400 ms on
  hover **and** focus; `[` toggles; state persisted per device (`localStorage`, try/catch); **default
  collapsed at 1024–1279**, open ≥ 1280.
- Client items: Áttekintő · Táplálkozás · Edzések · Testsúly · Víz · Lépések · Statisztika + Beállítások
  (EN: Overview, Nutrition, Workouts, Weight, Water, Steps, Statistics, Settings); icons
  `space_dashboard restaurant fitness_center monitor_weight water_drop directions_walk bar_chart
  settings`. Width fixed at 248 (sized for HU "Ételeim & receptjeim" in the trainer nav).
- **Verify:** `e2e/ds/shell.spec.ts` on a gallery shell demo (collapse, persistence, tooltips, account menu,
  logout dialog focus on "Mégse"); real `/dashboard` in both themes.

*As built:* `AppShell` is deliberately thin this step — it owns the new `Sidebar` plus the still-old
`components/layout/TopBar.tsx` (its redesign is W0.21) and the avatar-blob-URL plumbing lifted verbatim from
the old sidebar; `app/(app)/layout.tsx`'s own local function was also literally named `AppShell`, so it's
renamed to `AppGate` (auth guard + locale/date sync only) to free the name for the real component. `Sidebar`
takes `user`/`avatarUrl`/`collapsed`/`onLogout` as props rather than reading `useSessionStore` itself, so the
gallery's `ShellSection` demo (fixture user, no auth) is the *same* component real pages use, not a parallel
mock — `e2e/ds/shell.spec.ts` runs against it directly. Two role-gated jump links (`ROLE_TRAINER` → `/admin`,
`ROLE_SUPER_ADMIN` → `/superadmin/users`) are carried over unchanged from the old sidebar; they aren't in the
DS-02 canvas, which only speaks to the plain client nav, but dropping them would have silently broken
existing navigation for dual-role users. `Téma`/`Nyelv` in the account menu reuse Settings' own dual-write
pattern (`useTheme`/`useLocale` for the immediate visual change, `settingsApi.update` so it survives
`AppGate`'s settings-query resync on refocus, which would otherwise silently revert a `useLocale`-only
change) rather than being new, disconnected controls — when the settings fetch fails (no backend in this
environment, and CI's `ds` project has none either) they simply don't render, same graceful-without-crashing
shape as every other query-backed gallery section. Logout is **not** styled destructive (`ConfirmModal`'s
`destructive={false}`, a `--primary` icon tint, "Cancel" default focus) since D-W0.20's whole point is that
nothing is lost; `common.signOutConfirmBody` (the only place it was used) is updated in place to the plan's
honest copy rather than adding a parallel key, which also fixes the copy for the trainer/superadmin
`AdminSidebar`'s still-old `SignOutButton` (unmigrated until W0.23) for free. The collapse-default breakpoint
read (`window.innerWidth`) is set in a mount effect rather than a `useState` lazy initializer — reading it
synchronously on the client's first render would silently mismatch the server's render, the exact hydration
bug just fixed project-wide in `useMediaQuery` (see the CI fix below); the one-frame flash from "open" to
"collapsed" on a narrow screen is the accepted trade-off, same as `DelayedSkeleton`/`FormattingSection`.
Below 768px, `Sidebar` still renders as the old full-height overlay drawer (`useUiStore`'s `drawerOpen`,
restyled to the new DS-02 look) rather than being hidden outright — the bottom nav that actually replaces it
is W0.22, not yet built, and shipping this step with mobile navigation silently broken in between wasn't
acceptable; the closed drawer is now `aria-hidden`/`inert` (the old sidebar was neither), fixing a real
`ds`-gallery test collision once its "Close menu" button joined the same page as `controls.spec.ts`'s
substring-matched "Close" query. Collapsed-tooltip shortcut letters (`G D/N/W/S` come from D-W0.17; `E`
weight/`A` water/`P` steps/`C` settings/`T` trainer/`Y` superadmin are this step's own pick, filling gaps the
plan's own list left open) are cosmetic only — `useHotkeys` doesn't exist until W0.25, so `G <letter>`
doesn't actually navigate yet. Not achievable in this environment: the real `/dashboard` in both themes
(D-W0.20's other verify bullet) — no backend (`java`/`mvn` not on `PATH`), so the deepest available check is
`ShellSection`'s fixture-data gallery demo, `tsc --noEmit` across the whole project, and the full lint /
vitest / `ds` + `marketing` Playwright / build / `check:js-budget` suite, all green.

**Also fixed in passing (not part of W0.20's own scope, found while investigating a failing CI run the user
flagged mid-step):** two pre-existing hydration mismatches were corrupting the whole `/dev/design` gallery
tree on load in CI and cascading into unrelated modal/drawer/menu/toast/motion test flakiness —
`useMediaQuery` read `window.matchMedia` synchronously in a `useState` lazy initializer (hydration-unsafe the
same way this step's own sidebar-breakpoint read would have been; fixed with `useSyncExternalStore` and a
fixed `false` server snapshot) and `FormattingSection` computed `new Date()` directly during render (can
straddle a real clock tick between the server render and hydration; deferred to state set after mount).
Committed separately as `056b2ad`.

### W0.21 — Web UI: top bar + global date stepper ✅
- Files: `src/components/shell/{TopBar,DateStepper,routeChrome}.ts(x)`, `lib/hooks/useDateStore.ts`
  (unchanged API; `setDate` refuses future days).
- DS-02 "Felső sáv": sticky; transparent over `--bg` at the top, **float surface (82 % bg + blur 24) +
  hairline once content scrolls under**; page title left (`type-page`, 26/800), centre slot, tools right
  (theme 40 px round button; trainer client pages add a breadcrumb "Klienseim › Nagy Kata" in the title
  slot — W7).
- `DateStepper`: 40 px round ‹ › buttons + a centre pill (`calendar_today` + "Ma" 15/700 + "szept. 27.,
  szombat" 14/600); another day: the date is the main label and a "Vissza a mai napra / Back to today"
  chip appears; **next is disabled on today** (faint arrow); click the pill → `CalendarPopover` (dots =
  days with a logged meal, from the meals query already cached for the week); keys ← / → / T when no field
  has focus.
- `routeChrome.ts` per D-W0.14: dated pages `/dashboard /nutrition /water /steps /admin/clients/[id]`;
  none on `/onboarding`, `/settings`, `/statistics` (its own period control goes in the centre in W5),
  `/weight` (range switcher, W4).
- **Verify:** `dateStepper.test.ts` (future refused, label HU/EN); keyboard ←/→/T on `/dashboard`; the
  title no longer mismatches the date format in HU.

*As built:* the pill's two-weight label ("Ma" 15/700 + the full weekday date 14/600) isn't new formatting
logic — `lifeyFormat.dayLabel(date, today)` (D-W0.8) already returns exactly this as one string ("Ma ·
szept. 27., szombat" / bare "szept. 26., péntek" on any other day); `DateStepper` just splits on `" · "` to
give the "Ma"/"Today" word its own weight, rather than duplicating the todayWord/format logic. The
`CalendarPopover` D-W0.10 already built (month grid, `disableFuture`, an optional `hasData` dot per day) is
reused as-is for the pill's popover — no new calendar code needed. **Not wired:** the "dots = days with a
logged meal" bullet — there is no cached *range* query to read from; `queryKeys.meals` only has `byDate`
(a single day) and `all()` (unbounded), not a week. Adding a week-range endpoint/query is backend/feature
work, out of scope for a shell step (same D-W0.19 "derived, hidden, or an explicit non-goal" discipline as
every other canvas/API gap this session) — `CalendarPopover`'s `hasData` prop is simply left unset for now;
whichever W-step gives nutrition a real week query should pass it in. `useDateStore.setDate`'s new
future-clamp reuses `isFuture` from `ds/date/monthGrid.ts` (already used by `CalendarPopover` for the same
purpose) instead of a second implementation. `routeChrome.ts` only implements the title-key/date-stepper
split this step needs — D-W0.14's centre-slot swap (statistics/weight) and `focus` mode (no chrome) are
that function's own later additions, not stubbed out ahead of time. Not achievable in this environment: the
real `/dashboard` keyboard/title check (no backend) — covered instead by `dateStepper.test.ts` (vitest) plus
new `e2e/ds/dateStepper.spec.ts` and a `DateStepperSection` gallery demo (next-disabled-on-today, the "Back
to today" chip, the `T` shortcut, the calendar popover), and the full lint / vitest / `ds` + `marketing`
Playwright / build / `check:js-budget` suite, all green.

### W0.22 — Web UI: mobile shell below 768 — bottom nav + "Több" sheet ✅
- Files: `src/components/shell/{BottomNav,MoreSheet,MobileHeader}.tsx`.
- DS-02 "768 px alatt": the mobile app's floating bottom nav (68 px, r30, `--float` + blur, e3; active
  = primary pill with icon + label, others 48 × 48 icons) with **four items + "Több"**: client
  Áttekintő · Táplálkozás · Edzések · Testsúly · Több (sheet: Víz, Lépések, Statisztika, Beállítások);
  trainer Klienseim · Naptár · Chat · Tervek · Több. Header: title + avatar (account menu), the date
  stepper **under the title, full width**. Content bottom padding = nav + 16 so the last row is visible.
  FAB slot (right, above the nav) used by W2/W4.
- The hamburger and the drawer-style sidebar (`useUiStore.drawerOpen`) go away.
- **Verify:** 390 × 844 in both roles: no horizontal scroll, every item ≥ 44 px, last list row visible,
  "Több" sheet keyboard-operable.

*As built:* `BottomNav`/`MoreSheet`/`MobileHeader` take their nav items as props rather than reading a role
off session state, same "generic component, real wiring per role in its own step" split as `Sidebar`
(W0.20): only the client `AppShell` actually mounts them (replacing its own W0.20/21 interim mobile overlay
drawer + hamburger, which are now dead code and removed from `Sidebar.tsx`/`TopBar.tsx` — both are
desktop-only, >=768px, from this step on); the "both roles" verify bullet is satisfied by demoing a trainer
config in the gallery only, since the real trainer `AppShell` wiring is W0.23. That trainer demo reuses
`AdminSidebar.tsx`'s existing nine routes/icons/`admin.nav` i18n keys (a `namespace` field added to
`NavItemDef` so one component can resolve labels from either "nav" or "admin.nav") rather than inventing new
ones — the plan's own "Klienseim · Naptár · Chat · Tervek" four-item row names a "Tervek" grouping that
doesn't exist as a single route yet (that regrouping is W0.23's own "TARTALOM" redesign), so this picks four
of today's real nine instead (Klienseim, Naptár, Chat, Programok) and puts the rest in "Több". `MoreSheet` is
a thin wrapper over the existing `Modal` rather than a new overlay — `Modal` already becomes exactly this
shape below 768px, with focus trap/Esc/scrim-close already built and tested, so wrapping it is what makes
"keyboard-operable" free instead of a second implementation to get right. The FAB slot D-W0.22 mentions
("used by W2/W4") isn't built — nothing consumes it yet, and adding an empty slot for a future caller is the
kind of speculative code the redesign's own discipline (D-W0.19) argues against. One CI-only wrinkle found
while writing `e2e/ds/mobileShell.spec.ts`: at 390px the "Több" button sits under the dev-only TanStack Query
devtools toggle (always mounted via `Providers`, present in `next dev` and therefore in the `ds` project's
webServer too, though never in production) — clicking it via the mouse hit the devtools icon instead, so the
test focuses the button and presses Enter rather than clicking, which incidentally is a stronger check of
"keyboard-operable" anyway. `shell.spec.ts` (W0.20) needed a locator fix too: both it and this step's own
gallery demo now have a link named "Dashboard" on the same page, so its assertions are scoped to `#shell`
the same way `AccountMenu`'s tests were already scoped to `#lifey-overlay-root`. Not achievable in this
environment: 390x844 on the real authenticated app in both roles (no backend) — covered instead by
`e2e/ds/mobileShell.spec.ts` against the new `MobileShellSection` gallery demo (both role configs, hit
areas, no horizontal scroll, the sheet), and the full lint / vitest / `ds` + `marketing` Playwright / build /
`check:js-budget` suite, all green.

### W0.23 — Web UI: trainer shell onto `AppShell` ✅
- Files: `app/(admin)/admin/layout.tsx`, `navConfig.ts`, delete `components/layout/AdminSidebar.tsx`
  usage; weekly-report switch → `AccountMenu` (reads/writes `trainerApi.preferences` — `trainer-004`).
- DS-02 "EDZŐ · csoportosítva": clay **EDZŐ** badge under the logo; groups **KLIENSEK** (Klienseim,
  Naptár, Chat + unread `CountPill`, Meghívók), **TARTALOM** (Edzésterveim, Programok, Ételeim &
  receptjeim, Kiosztott tervek), **FIÓK** (Számlázás, Saját nézet = switch to the client app); user chip
  with a clay avatar ring and "Edző · PRO". Controls primary, no `tertiary` anywhere in the shell.
  `/admin/pending` keeps its chrome-less layout (restyled in W9.6). Billing banner stays above content.
- **Verify:** every `/admin/*` page renders in the new shell; chat badge live (the chat stream is still
  held by the layout); `grep -r "tertiary" src/components/shell` empty.

*As built:* this step is the one D-W0.14 actually asked for and W0.20 deferred — `AppShell`/`Sidebar`/
`AccountMenu` are now genuinely the *one* shell every role shares, not client-only components a trainer
shell would duplicate. `Sidebar` gained `groups: NavGroup[]` (a flat single group for the client, three
labelled groups — KLIENSEK/TARTALOM/FIÓK, `admin.nav.groupClients/groupContent/groupAccount`, new keys this
step — for the trainer), plus `roleBadge`/`roleRing`/`showSettingsRow`/`trainerPrefs`; `AppShell` grew the
matching props with client-shaped defaults, so `(app)/layout.tsx`'s own call site barely changed. The client
sidebar's role-gated trainer/superadmin jump links (preserved unchanged since W0.20, not itself in the DS-02
canvas) moved out of `Sidebar` into a new `clientGroupsFor(user)` in `navConfig.ts`, since `groups` is now
supplied by the caller rather than computed inside the component. The user chip's hand-rolled avatar circle
(client, mobile header) is replaced with the DS `Avatar` component (`src/components/ds/Avatar.tsx` — built in
an earlier W0 step but never actually used until now): real initials instead of the e-mail's first letter,
and the `roleRing` prop this step specifically needs for the clay trainer ring. The "Edző · PRO" chip
subtitle is real billing data, not decoration — `AppShell` queries `queryKeys.billing.entitlements()`
(`AdminBillingBanner`'s own query key, so it shares the cache instead of double-fetching) only when
`roleRing === "trainer"`, and maps `TrainerPlan` through the existing `admin.billing.planStarter/planPro/
planStudio` keys (D-W0.8: never a raw enum on screen) rather than hardcoding "PRO". `routeChrome.ts` moved
from a `"nav"`-namespaced key to a full dotted path (`"admin.nav.clients"` etc.) so one function can title
both the client and trainer routes, matched longest-prefix-first so `/admin/billing` doesn't get shadowed by
the bare `/admin` entry — covered by a new `routeChrome.test.ts`. The weekly-report-email switch moved from
its old fixed sidebar row into `AccountMenu` behind a new `trainerPrefs` prop, reusing the exact
`trainerApi.preferences` query/mutation `AdminSidebar.tsx` already had (same query key, same toast copy) —
not a rebuilt feature, just relocated. `components/layout/AdminSidebar.tsx` and `SignOutButton.tsx` (its only
other user was the client sidebar, already retired in W0.20) are both deleted outright, not just unwired.
`/admin/pending`'s chrome-less exception and the `useChatStream` call that keeps the sidebar's live unread
badge working while a trainer is elsewhere in the app are both preserved verbatim in the new `AdminGate`
(renamed from `AdminShell` for the same reason `(app)/layout.tsx`'s gate was renamed in W0.20 — the real
`AppShell` needed the name). Gallery coverage: `ShellSection`'s existing Client/Trainer toggle (from W0.20)
now drives the real generalized props instead of a stand-in, and a new `e2e/ds/trainerShell.spec.ts` checks
the group headers and the role badge render (scoped past a text-matching wrinkle: a badge's `<span>`'s raw
DOM text also includes its icon's Material Symbols ligature name, e.g. "fitness_center", so an exact-text
locator for "TRAINER" only ever matches the plain chip-subtitle span, not the badge — noted in the test, not
a bug). Not achievable in this environment: every real `/admin/*` page in the new shell, live chat badge (no
backend) — covered instead by the gallery demo, `grep -r tertiary` (empty, confirmed), and the full lint /
vitest / `ds` + `marketing` Playwright / build / `check:js-budget` suite, all green.

### W0.24 — Web UI: superadmin shell onto `AppShell` ✅
- Files: `app/(superadmin)/superadmin/layout.tsx` (the top header with tabs is deleted), `navConfig.ts`.
- DS-02 "SUPERADMIN · ugyanaz a héj": neutral **RENDSZER** badge; items Felhasználók, Edzői kérelmek
  (+ pending count), Szerepkör-történet (route added in W9.9 — hidden until then), Saját nézet; user chip
  "Admin · Superadmin" with a neutral ring.
- **Verify:** `/superadmin/users`, `/superadmin/trainer-requests` in the shell, both themes, 390.

*As built:* by far the smallest of the three shell migrations, precisely because W0.23 already generalized
`AppShell`/`Sidebar`/`AccountMenu` — this step is closer to *configuration* than new component work.
`SUPERADMIN_NAV_ITEMS`/`SUPERADMIN_NAV_GROUPS` (flat, one unlabelled group, new `"superadmin"`-namespaced
items reusing the already-existing `superadmin.usersTitle`/`trainerRequestsTitle`/`backToOwnView` keys) and
the layout rewrite were the only genuinely new pieces; "Szerepkör-történet" is deliberately left out of the
nav entirely rather than added-but-hidden, since its route doesn't exist until W9.9 and a shell shouldn't
link to a 404. One real gap the plan's own wording exposed: D-W0.23 calls for a *clay* EDZŐ badge but D-W0.24
a *neutral* RENDSZER one — `Sidebar`'s `roleBadge` prop only carried `{icon, label}` with a single hardcoded
clay style, which would have painted the superadmin badge clay too; fixed by deriving the badge's tone from
the already-passed `roleRing` (trainer → clay fill, anything else → a neutral `--outline` ring), rather than
growing the prop surface with a redundant tone field `roleRing` already implies. The "+ pending count" on
Edzői kérelmek is a real, live query (`trainerRequestApi.pending({page:0,size:1})`, reading just
`totalElements`) — the same "if the data is real, fetch it; if it isn't, don't fake it" line as W0.23's
billing-plan chip, generalized in `Sidebar`'s existing badge slot (until now hardcoded to the trainer's chat
key) rather than a second bespoke badge mechanism. `BottomNav` gained a `showMore` flag (default true) since
superadmin's three items fit without an overflow sheet at all — `AppShell` hides both the trigger and
`MoreSheet` together when `moreSheetItems` is empty, instead of shipping a "Több" button that opens nothing.
Gallery: `ShellSection`'s toggle is now three-way (Client/Trainer/Superadmin) on the same generalized props,
plus a new `e2e/ds/superadminShell.spec.ts` (flat nav, the neutral badge, no dedicated Settings row). Not
achievable in this environment: the real `/superadmin/*` pages in the new shell, both themes, 390 (no
backend) — covered instead by the gallery demo and the full lint / vitest / `ds` + `marketing` Playwright /
build / `check:js-budget` suite, all green.

### W0.25 — Web UI: keyboard shortcut layer + help overlay ✅
- Files: `src/lib/hooks/useHotkeys.ts` + `useHotkeys.test.ts`, `src/components/shell/ShortcutHelp.tsx`,
  shell wiring (`[`, `G …`, `?`, `/`, `←/→/T` from W0.21).
- D-W0.17. Pages register their own `N` handler and search target through a small context
  (`usePageShortcuts({ onNew, searchRef })`); `?` lists global + page shortcuts in HU/EN.
- **Verify:** unit tests (ignored inside inputs/textarea/contenteditable and while a modal is open; `G`
  chord timeout 1 s); `e2e/ds/shortcuts.spec.ts`.

*As built:* one global listener, three collaborating pieces. `useHotkeys` (called once by `AppShell`) owns
`G <letter>` (resolved against the *current role's* own `NavItemDef.shortcut` letters via `matchGoTo`, 1 s
chord window from `createChordTracker`), `?` and the page-registered `N` / `/`; both the tracker and the
matcher are framework-free pure functions, so the timeout and the resolution are covered by fake-timer
Vitest tests in the node-only env (D-W0.12) rather than needing jsdom. Pages register through a tiny zustand
store (`usePageShortcuts({ onNew, newLabel, searchRef })` — a page can't push context *up* to the shell that
owns the listener, so a context provider was the wrong shape), which clears itself on unmount so the next
route never inherits a stale `N`. "Never while a modal is open" is `isOverlaySuppressing()`: `Modal` and
`Drawer` both lock `body` scroll, which is the cheapest reliable "something else owns focus" read without a
second global overlay store; the existing `[` (sidebar) and `←/→/T` (date stepper) listeners kept their own
code but now share that guard and `isTypingTarget`, so all shortcuts agree. `ShortcutHelp` is a `Modal`
listing "This page" (only when the page registered something), global and table shortcuts (the table row
conventions are DataTable's own, W0.15), HU/EN under a new `shortcuts.*` namespace. Two scope notes: DataTable
already handles `/` for its own search locally, and no real feature page registers `N` yet — wiring pages
belongs to their W1+ iterations, this step ships the mechanism. Gallery: `ShortcutsSection` mounts the same
`useHotkeys` + `ShortcutHelp` pair with a fake page, and `e2e/ds/shortcuts.spec.ts` covers `?`, `G W`, the
chord timeout, `N`, `/`, typing in a field and an open modal. While running the `ds` project on the last day
of a month (2026-09-30) an old W0.10 test failed and exposed a real `CalendarPopover` bug: with
`disableFuture`, arrow/PageDown could rove keyboard focus onto a disabled future day, which can't take focus,
so focus was dropped (and at a month's end unmounted with the view swap). Fixed in the component (`focusDate`
clamps to today) and the spec now asserts the clamp (Left/Right and PageUp/PageDown) instead of racing it.
Not achievable in this environment: the real authenticated pages in the shell (no backend) — covered by the
gallery demo and the full lint / vitest / `ds` + `marketing` Playwright / build / `check:js-budget` suite.

**W0 derived screens:** none — but because tokens change in place, every page changes colour in W0.1
and moves into the shell in W0.20–W0.24. Click through every client, trainer and superadmin page after
W0.1–W0.4 and after W0.24; list anything unreadable in the commit; fix only true breakages (unreadable
text, broken layout), leave layout work to its iteration.

**W0 acceptance** (plus the §4.1 review logged in §12): the gallery shows every component of DS-01 …
DS-07 in both themes and both languages; contrast test green; `ds` project green in CI; every logged-in
page runs in the new shell on the v2 palette; marketing unchanged.

**W0 web UI review focus:** the gallery against DS-01 … DS-07 frame by frame (grid overlay at 1440 /
1280 / 1024 / 390, sidebar open / collapsed / tooltip, top bar HU dark + EN light, bottom nav, table,
menu, tooltip, segmented + tabs, modal, drawer, toast with undo, fields in every state, both date picker
modes, both charts, empty / error / skeleton, hover / focus / pressed / disabled, the formatting table,
motion timings); then a pass over **every** existing page in the new shell (client, trainer, superadmin,
auth, onboarding) in both themes at 1440 and 390, listing breakages (fixed as `W0.fix-<k>`) and layout
issues left to their iteration; plus the marketing home `/hu` and `/en` unchanged.

---

## W1 — Dashboard · `Lifey Web 1 Dashboard.dc.html` (W1-A … W1-D)

**Goal:** the day on one screen, calories as the hero; the desktop width filled edge to edge.

**Canvas notes = requirements** (each checked in the W1 review):

| Note | PDF ids | Requirement |
|---|---|---|
| Kalória hős gyűrűvel | client-001 | 220 px ring, 56 px number, eaten / goal beside it, three macro bars with grams left; hero card r30; ring 900 ms |
| Az asztali szélesség kitöltve | client-001 | 12-column grid, three rows: hero + recommended workout · three metric tiles · weekly chart + recent workouts; no empty right column; 8 + 4 split |
| Csempék, amelyek mondanak valamit | client-001, client-002 | Water: quick add on the tile. Steps: one colour (steps purple), "cél elérve" text + check, no second bar colour. Weight: weekly change chip, goal and kg left, relative date instead of ISO |
| Heti grafikon célvonallal | client-001 | Bar chart with Y axis, dashed 1 900 goal, today's partial day = dashed outline and **not in the average** |
| Olvasható edzéssorok | client-001 | Icon + name + one meta line (pace, distance, volume) left, date right; PR chip in the row; "Kerékpározás", never `CYCLING` |
| Tablet és mobil | client-078, client-086 | 1024: collapsed sidebar, hero full width. 390: mobile layout + floating bottom nav instead of the hamburger; date stepper under the title, full width |
| Üres állapot = első lépések | onboarding-001 | New account: a "first steps" card instead of zero tiles: what's done, what's next, one button each |

**Current code:** `app/(app)/dashboard/page.tsx` (393 lines, all sections inline), `components/data/
{HeroMetricCard,KpiCard,StatCard,MacroRing,WaterCard,Sparkline}.tsx`, `components/app/OnboardingBanner.tsx`,
`features/workouts/components/RecommendedWorkoutCard.tsx` + `recommendation.ts`,
`features/nutrition/{budget,copyMeal}.ts`, `features/water/api.ts`, `features/steps/api.ts`,
`features/weight/api.ts`.

**Target layout — W1-A, 1440 dark HU** (12 columns, gap 24):
1. **Row 1.** `CalorieHero` — span 8, `Card.hero` r30, padding 28: left a **220 px ring** (calories) with
   `AnimatedNumber` **859** (56/800) + "kcal maradt"; beside it "Elfogyasztva **1 041 kcal**" and "Napi
   cél **1 900 kcal**"; three macro rows (grid `96px | bar | 150px`: label 14/600 `--text-2`, 7 px
   `MetricBar` in the macro colour, "68 / 120 g · még 52 g" right); buttons "＋ Étkezés hozzáadása"
   (primary, `N`) and "Tegnapi vacsora másolása" (secondary, `content_copy`; W1.3). The clay "Célok:
   Szabó Bence" chip is **not built** (D-W0.19).
   `RecommendedWorkout` — span 4, `Card.hero` r30, padding 24: "MAI JAVASLAT" section label + "utoljára
   szept. 23.", title "Láb + core" (20/800), meta "6 gyakorlat · kb. 50 perc · 18 szett", the first three
   exercises with "4 × 8" on the right, "▶ Edzés indítása" (primary, full width).
2. **Row 2.** Three `MetricTile`s, span 4 each, r22, padding 20:
   *Víz* — "utoljára 14:10", **1,6 / 2,5 L**, 10-segment bar, quick buttons "+ 0,25 L", "+ 0,5 L" (the
   user's two most used water sources; fallback 0.25 / 0.5 L), "⋯" (→ Water page, manage sources).
   *Lépések* — "cél 9 000", **6 412**, steps-purple bar, "Még 2 588 lépés · kb. 25 perc séta" (100
   steps/min, constant in `features/steps/walking.ts`); at ≥ goal: ✓ + "Cél elérve", same colour.
   *Testsúly* — date meta ("ma", "tegnap", "szept. 25."), **69,6 kg**, `DeltaChip` "−0,4 kg / hét"
   (weekly pace from the trend, W1.6; goal-aware colour), "Cél 65 kg · még 4,6 kg".
3. **Row 3.** `WeekCaloriesCard` — span 8, padding 22/24: "Az elmúlt 7 nap"; header stats "átlag
   **1 823 kcal**" (without today) · "célon belül **5 / 6** nap" · "edzés **4**"; `LifeyBarChart` 7 bars
   (V H K Sze Cs P Ma), Y "2,4 e / 1,2 e / 0", dashed "cél 1 900", today dashed outline.
   `RecentWorkouts` — span 4, padding 8 0: "Utolsó edzések" + "Mind" link; four rows: 40 px tinted icon
   (strength = primary tint, cardio = heart tint), name + `RecordChip` "🏆 PR", meta ("52 perc · 6 240
   kg · 18 szett", "5,2 km · 30:10 · 5:48 /km"), relative date right ("tegnap", "szept. 25.").

**W1-B, 1024 light:** collapsed sidebar; hero full width with the three macros in a 3-column row under
the ring; the three tiles in one 3-column row; recommended workout + recent workouts side by side
(2 columns); the chart full width; tile copy shortens ("Még 2 588 a 9 000-ig", "−0,4 kg a héten").
**W1-C, 390 dark:** mobile header (title + avatar), date stepper full width under it; compact hero (ring +
"1 041 / 1 900", macros as three mini rows), "＋ Étkezés" + a copy icon button; compact recommendation
with a ▶ icon button; water + steps tiles 2-up, weight tile full width (span 2); recent workouts (3
rows); bottom nav with "Áttekintő" active.
**W1-D first steps:** replaces hero + tiles while the account has **no meal ever and no weight ever**:
"Szia, Anna! Három lépés, és kész a napod képe." + "A csempék addig nem mutatnak nullát — mindegyik azt
mondja meg, mi a következő lépés."; three rows with state icons: *Célok beállítva* (done when a calorie
goal exists — else CTA → `/onboarding`), *Első étkezés naplózása* (CTA "Naplózás" → add-food modal),
*Súly rögzítése* (CTA → log-weight drawer). The existing `OnboardingBanner` merges into this card.

**Data:** everything exists. Weekly pace and "7 days" need the trend port (W1.6); PR chips need the PR
port (W1.10); "last water at" = latest water entry today; "within goal n / 6" counts past days with
0 < kcal ≤ goal (today excluded, zero days excluded).

### W1.1 — Web UI: dashboard page grid + section components ✅
- Files: `app/(app)/dashboard/page.tsx` (becomes composition only), new
  `features/dashboard/components/*.tsx` shells, `components/ds/layout/PageGrid.tsx` (D-W0.6).
- Move the existing sections unchanged into their slots at 1440 / 1024 / 390 (W1-A/B/C order); no visual
  redesign of the cards yet.
- **Verify:** the three widths show the canvas order; no horizontal scroll at 390.

*As built:* The dashboard page is now composition only: `features/dashboard/useDashboardData.ts` owns the ten
queries and the day's derived figures (today's meals / water / steps, sorted weights, sessions newest-first,
the recommendation, the streak, macro totals) and hands one `data` object to five section shells —
`HeroSection`, `RecommendedSection`, `TilesSection`, `WeekSection`, `RecentWorkoutsSection` — each the pre-
redesign card moved unchanged into its slot (W1.2–W1.10 replace them one by one; `OnboardingBanner` stays
above the grid until W1.11). `PageGrid` / `GridItem` (`components/ds/layout/PageGrid.tsx`, D-W0.6) are a CSS
grid — 4 cols / gap 12 at mobile, 8 / 20 from md, 12 / 20 from xl, gap 24 from 2xl (`--breakpoint-2xl: 90rem`
and `--breakpoint-3xl: 100rem` added to the theme) — where `GridItem` passes per-breakpoint `span` and `order`
as custom properties that each fall back to the breakpoint below, so the three canvas layouts are data, not
markup: 1280+ is hero 8 | workout 4 · tiles 12 · week 8 | recent 4; 1024 is hero · tiles · workout 4 | recent
4 · week; 390 stacks hero, workout, tiles, recent, week. One deliberate call: spans are explicit per
breakpoint (no `min(span, cols)` clamp) because CSS `span` only takes an integer literal, so a base span above
4 would silently create implicit columns — the prop types document the ceilings (≤4 / ≤8 / ≤12). Verified on
the real app with the demo data at 1440, 1024 and 390 (correct order, no horizontal scroll, no console
errors), plus a gallery "Page grid" section and `e2e/ds/pageGrid.spec.ts` (column count and gap per width, 8 +
4 on one row at 1440, the order flip at 1024, full-width stacking at 390) and `pageGrid.test.ts` for the
custom-property mapping.

### W1.2 — Web UI: `CalorieHero` ✅
- Files: `features/dashboard/components/CalorieHero.tsx`, `features/nutrition/budget.ts` (reuse).
- Spec row 1 left. States: remaining (canvas); **over budget** — ring second lap, number = overage,
  caption "kcal túllépés" in `--m-kcal`; **no calorie goal** — empty ring, number = eaten, caption "kcal
  elfogyasztva", no "Napi cél" line; macro without a goal = value only, no bar. Whole card is not a
  link (the buttons are the actions). HU at 200 % zoom: macro value wraps under its label.
- **Verify:** `calorieHero.test.ts` for the three states' copy/number selection; 1440 dark vs W1-A.

*As built:* `CalorieHero` is split in two: `CalorieHeroView` (presentational — kcal, goal, three macro
`{value, goal}` pairs, `onAdd`, an optional `secondaryAction` slot for W1.3, a goals-hint flag) and the
connected `CalorieHero` that feeds it the day's totals and owns the add-meal flow. The view is what the
gallery's "Calorie hero" section shows in all three states, so `e2e/ds/calorieHero.spec.ts` asserts them on
fixtures instead of depending on whatever the demo account ate today. The copy/number choice is a pure
function, `heroState()` (+ `macroRowState()`) in `features/dashboard/calorieHero.ts`, covered by
`calorieHero.test.ts`: under budget shows kcal left with the ring at eaten/goal; exactly on the goal is still
"left" (0), not over; over budget shows the overage, the ring's second lap (`ProgressRing` already draws it)
and the caption in `--m-kcal`; no goal (or a goal of 0 — never divided by) shows what was eaten, an empty ring
and no "Daily goal" line; a macro without a goal is value-only with no bar. The card is a plain `Card.hero`,
not interactive. Two calls the plan left open: the ring diameter is 220 only in the 1440 frame (168 at 1280
where the hero shares its row with the workout card, 184 when it spans the full width at 1024, 128 on a phone,
via `useMediaQuery` — the page renders a skeleton first, so there's no SSR mismatch), and the macro rows
change shape per width instead of shrinking the bar to a stub — label | bar | value on one line at 2xl, label
+ value over a full-width bar at 1280 (the first cut left 35 px bars), three stacked columns at 1024 and mini
rows at 390, all from one markup with `order`/grid classes. "Add meal" opens the existing `AddMealEntryDialog`
(meal type from `defaultMealType()`, on the viewed day; W2.6 replaces that dialog) and registers the `N`
shortcut through `usePageShortcuts`, which is also listed in the `?` help ("Add meal"). The old
`HeroSection`/`HeroMetricCard`/`MacroRing` row is gone from the dashboard (`HeroMetricCard` and `MacroRing`
stay in `components/data` until W10's sweep). The old "set your goals" link lives on under the buttons when
neither a calorie nor a protein goal exists. Checked on the real app at 1440 (HU), 1280, 1024 (light) and 390.

### W1.3 — Web UI: "copy yesterday's <meal>" quick action ✅
- Files: `features/nutrition/copyMeal.ts` (+ `suggestCopy()` and tests), `CalorieHero.tsx`.
- Rule: the next meal type by local time (before 10:30 breakfast, before 15:00 lunch, before 17:30
  snack, else dinner) that has **no entry today** and **had one yesterday** → "Tegnapi vacsora másolása";
  otherwise the button is hidden. One click copies with the existing copy mutation and shows a toast with
  undo (`useUndoableDelete` on the created meal).
- **Verify:** unit tests for the time boundaries and the "already logged" case.

*As built:* `features/nutrition/copyMeal.ts` gains `mealTypeForClock()` (before 10:30 breakfast, before 15:00
lunch, before 17:30 snack, else dinner — the boundaries are exclusive, so 10:30 is already lunch) and
`suggestCopy(meals, now)`, which returns `{ mealType, source }` only when today has no meal of the clock's
type and yesterday had one (the latest, if it had several) — otherwise null and the button isn't rendered;
twelve unit tests cover every boundary minute, midnight and late night, "today's other types don't hide it",
"only yesterday counts" and the multiple-meals pick. `CopyYesterdayButton` is the hero's `secondaryAction`: a
secondary `Button` ("Tegnapi vacsora másolása" / "Copy yesterday's dinner", the meal name lower-cased through
`labels.mealTypes`, so it never shows a raw enum), icon-only with an aria-label below 640 px. It is only
offered while the dashboard is on today, because "yesterday" means the day before now — browsing a past day
hides it. One click posts `copyMealPayload(source, today)` (keeping the original time of day), invalidates the
meals query (so the hero ring and the week card refresh on their own) and raises the toast "Tegnapi vacsora
átmásolva · Visszavonás". One deviation from the plan's wording: the plan says `useUndoableDelete`, but that
helper is the opposite direction (an item that already exists has its DELETE deferred until the undo window
ends), while here the item is created immediately and Undo deletes it — so the button calls the toast store's
`showUndo` directly (Undo → `DELETE /meals/{id}`; a failed delete shows the error toast). Verified against the
real backend: with a seeded meal for yesterday the button appears, the click creates the meal and the hero
jumps to the new total, Undo sends exactly one `DELETE` and the button returns; the seeded meal was removed
afterwards. No Playwright spec — the `ds` project has no backend, so the logic lives in the unit tests and the
flow was driven on the real app.

### W1.4 — Web UI: `RecommendedWorkout` ✅
- Files: `features/workouts/components/RecommendedWorkoutCard.tsx` (rewritten), `recommendation.ts` (reuse;
  add "last performed" from session history).
- Spec row 1 right; estimated minutes = the template's median past duration, else 8 min / exercise;
  sets = sum of template sets; "▶ Edzés indítása" starts the session exactly as today. No recommendation →
  the card shows the template picker entry ("Válassz sablont") instead of disappearing (keeps the grid).
- **Verify:** 1440 / 1024 / 390 layouts; starting a workout still works.

*As built:* The dashboard gets a new presentational `features/workouts/components/RecommendedWorkout.tsx` (a
`Card.hero`, padding 24) and the old `RecommendedWorkoutCard` stays only for `SessionsView`, which W3 rewrites
— so the workouts page didn't have to change in this step. The numbers come from a pure
`summarizeTemplate(template, sessionsDesc, exerciseNames)` (`features/workouts/recommendedSummary.ts`, 8 unit
tests): exercise count and summed target sets; the estimate is the median duration of the template's finished
sessions, rounded to 5 minutes (minimum 5), ignoring unfinished sessions, zero-length ones (the demo's "Push
nap · 0 perc") and other templates, and falls back to 8 minutes an exercise; `lastPerformed` is the newest
finished session of the template; the first three exercises carry their names (a new `exercises` query in
`useDashboardData`). One thing the canvas' "4 × 8" needed that the data doesn't have: templates store only
`targetSets`, no target reps — so the reps are the median of the sets the user last logged for that exercise
(newest session that contains it); an exercise never logged shows "4 sets" / "4 szett" instead of inventing a
rep count. The start button keeps the existing contract (`/workouts?start=<templateId>`; verified on the real
backend that it lands on the workouts page and creates the session — deleted again afterwards). With no
suggestion the same grid cell becomes a template picker ("Válassz sablont", button opens the workouts page on
its Templates tab), so the slot beside the hero never collapses. Copy in HU matches the canvas: "MAI
JAVASLAT", "utoljára szept. 23.", "4 gyakorlat · kb. 40 perc · 12 szett". Gallery section "Recommended
workout" shows with-history, no-history and the picker, covered by `e2e/ds/recommendedWorkout.spec.ts`.

### W1.5 — Web UI: water tile ✅
- Files: `features/dashboard/components/WaterTile.tsx` (replaces `components/data/WaterCard.tsx` here),
  `features/water/quickSources.ts` + test (two most used sources in the last 30 days).
- Spec row 2 "Víz"; quick add posts a water entry now; "⋯" menu: "Vízforrások kezelése", "Víz oldal".
- **Verify:** unit test for source ranking; adding updates the segments with a 900 ms fill of the delta
  only.

*As built:* The old `WaterCard` is deleted; `features/dashboard/components/WaterTile.tsx` is a `MetricTile`
(icon, "Víz", meta "utoljára 09:29" = the newest entry of the viewed day, value "0,75" with unit "/ 2,5 L", 10
segments at 8 px) whose two quick-add buttons come from a pure `rankQuickSources()`
(`features/water/quickSources.ts`, 8 tests): saved sources ranked by entries in the last 30 days (a tie goes
to the more recent use, then the lower id; entries older than 30 days, in the future, without a source or
pointing at a deleted source don't count), padded from the 0.25 / 0.5 L defaults when fewer than two qualify
and never offering a default volume a used source already covers. A click posts a water entry stamped "now"
(noon for another day, `logTimestampFor`) optimistically — the segments fill at once and roll back with an
error toast if the POST fails; the "⋯" button opens a `Menu` with "Vízforrások kezelése" (→ `/water#sources`,
the sources card on the water page got an `id` and `scroll-mt`) and "Víz oldal". Three supporting changes:
`MetricTile` gained a `footer` slot and a per-tile segment `height` (the canvas' quick-add row sits below the
bar, not in the header); `SegmentBar` now runs through `AnimatedFill`, so the first appearance fills from 0
and a later change animates only the difference — during the motion the fill runs continuously across the
segments and at rest it settles into the resting shapes (full / one fixed 45 % partial / empty) — covered by a
gallery demo with an add button and `e2e/ds/segmentBar.spec.ts` (the four already-full segments stay full mid-
flight, the end state is exact); `lifeyFormat` got `litres()` and `litreNumber()` so "0,25 L" and "1,6" come
from DS-07 rather than ad-hoc `toFixed`. Verified on the real backend: the buttons read "+ 0,75 L" (the demo
user's most used source) and "+ 0,25 L" (default fill), a click adds exactly one entry and fills the bar, the
menu navigates to the sources card; the entry created for the check was deleted afterwards. The unit next to
the number renders at the DS tile ratio (13 px), a little smaller than the canvas' "/ 2,5 L" — left as the
shared `MetricTile` spec rather than special-casing one tile.

### W1.6 — Web data: weight trend port ✅
- Files: `features/weight/trend.ts` + `trend.test.ts` — port of `mobile/lib/features/weight/domain/
  weight_trend.dart` (docs/76 decisions): 7-day average over calendar days with gaps, weekly pace (kg /
  week), "since start" delta, projected goal date only when the pace points toward the goal and the
  remaining distance / pace ≤ 52 weeks.
- **Verify:** the mobile test cases pass unchanged in TS.

*As built:* `features/weight/trend.ts` is a line-for-line port of `weight_trend.dart`: the same constants
(7-day window, two entries minimum, 28-day rate window, four points over fourteen days before it names a date,
0.2 kg "reached" tolerance), `movingAverage` measured in calendar days rather than samples, and `projectGoal`
with the same five states (`onTrack`, `reached`, `wrongWay`, `tooSlow`, `notEnoughData`), the trend (not the
last raw weigh-in) as the current value, least-squares slope for the rate and the ETA counted from today.
Every case of `weight_trend_test.dart` is ported one for one in `trend.test.ts` and passed unchanged — the
window rule, a single entry, the gap, the six projection outcomes, gaining toward a higher goal and the null
cases. Two deliberate differences from a mechanical translation: day arithmetic goes through whole calendar
days (`dayNumber` from `Date.UTC`) instead of `ms / 24h`, so a daylight-saving change (the window crossing 29
March in Europe) can't push a point over a window edge — Dart's local `Duration` arithmetic has that edge and
a new test pins the web behaviour; and the ported types are plain objects (`state` is a string union, absent
values are `undefined`). Three small helpers sit beside the port for W1.7 and the later weight page:
`weightPoints()` (API weigh-ins → oldest-first one-per-day points on local midnights), `weeklyPace()` (the
trend's slope per week, signed like the scale, null below the same 4-points / 14-days floor the projection
uses, and tested to agree exactly with `projectGoal`'s rate) and `sinceStart()` (latest minus first). One
discrepancy in the plan's own text: it says the projected date needs remaining / pace "≤ 52 weeks", while
docs/76 D-W6 and the mobile code refuse only beyond 730 days — the port follows mobile so the two clients show
the same date for the same data (a 53-week estimate still shows; the two-year refusal case is in the tests).

### W1.7 — Web UI: steps tile + weight tile ✅
- Files: `features/dashboard/components/{StepsTile,WeightTile}.tsx`, `features/steps/walking.ts`.
- Spec row 2 "Lépések" and "Testsúly". Effective step goal = settings goal or the same default the
  mobile app uses (`effectiveDailyStepGoal`, 77 R1.4) — one helper, used everywhere. Weight tile with no
  entry → `EmptyState` compact: "Mérd meg magad" + "Súly rögzítése".
- **Verify:** goal reached shows ✓ in steps purple (no green); HU weight "69,6 kg", chip "−0,4 kg / hét".

*As built:* `StepsTile` and `WeightTile` replace the old `StatCard`s (each a presentational `…View` for the
gallery plus a thin connected wrapper), and `TilesSection` now lays the row out per the canvas: three equal
tiles from 768, water and steps 2-up with weight full width on a phone, using the page grid's own gap. Steps:
one purple for the bar, "cél 9 000" in the header, "Még 2 588 lépés · kb. 25 perc séta"
(`features/steps/walking.ts`: 100 steps a minute, rounded to 5, never under 5) — shortened to "Még 2 588 a 9
000-ig" below 1280 — and at or past the goal a ✓ with "Cél elérve" painted in the *same* purple as the bar (a
spec compares the two computed colours, so a green can't creep in). The same file holds
`effectiveDailyStepGoal()` (the user's positive goal, else mobile's 10 000 default), now used by the dashboard
and the steps page — the settings page's own field keeps showing what is stored. Weight: the meta is a day
word ("ma", "tegnap", else "szept. 27." — a new `relativeDay()` in `lifeyFormat`), the value via
`weightNumber()`, a `DeltaChip` with the weekly pace from `weeklyPace()` (W1.6; absent until the trend has
four points over two weeks) whose colour is goal-aware from the onboarding target weight (a new `user-details`
query in `useDashboardData`, 404 = no goal, not an error), shortened to "−0,4 kg a héten" below 1280, and "Cél
65 kg · még 4,6 kg" (or "Cél elérve" within the 0.2 kg tolerance). A fresh account gets a compact `EmptyState`
("Mérd meg magad" + "Súly rögzítése" → `/weight` until W1.11/W4 add the drawer) — `EmptyState` gained a
`compact` mode for tiles. Fixes found while checking the real page at four widths: `MetricValue` sized its
unit in `em` of the *wrapper*, not of the number, so every unit ("kg", "kcal", "/ 2,5 L") rendered at roughly
half its intended size — it is now `round(size × unitRatio)` px; `MetricTile` is a container (`@container`) so
its header meta and the water tile's "⋯" react to the tile's own width — on a 2-up phone tile the meta hides
and the "⋯" moves to the header instead of squeezing three buttons into 137 px; `MetricTile.subline` may be a
node (the ✓) and it takes a `unitRatio`. `e2e/ds/dashboardTiles.spec.ts` covers all six states on a gallery
section (steps under/over goal, weight with goal and losing pace, gaining without a goal, goal reached, empty)
plus the 1024 shortening.

### W1.8 — Web UI: 7-day calories card ✅
- Files: `features/dashboard/components/WeekCaloriesCard.tsx` (uses `LifeyBarChart`), the dashboard's
  weekly query (reuse the existing meals range query).
- **Verify:** average excludes today and zero days; "célon belül 5 / 6"; today dashed; axis never clipped
  at 1024.

*As built:* `WeekCaloriesCard` replaces the old "This week" + streak stack (`WeekSection` is deleted, and the
streak computation is dropped from `useDashboardData` — the canvas has no streak card and
`features/statistics/streak.ts` stays for the statistics iteration). The numbers come from two pure functions
in `features/dashboard/weekCalories.ts` (11 tests): `weekDays(meals, endDate, now)` — seven calendar days
ending on the day the dashboard shows, each with its summed calories, with only the *real* today flagged
partial (browsing a past day makes all seven complete; a month boundary works) — and `weekStats(days, goal,
sessionStartTimes, now)`: the average reuses the DS chart math (`averageExcludingPartialToday` with zero days
ignored, since 0 kcal means "didn't log"), "within goal" counts complete days with 0 < kcal ≤ goal (exactly on
the goal counts, an unlogged day doesn't) out of the complete days — the "6" in "4 / 6 nap", which stays 6
even when one of those days is empty — and is absent without a goal, and the workouts are the sessions started
inside the seven days (today included). The card is a `Card` with the plan's 22/24 padding: title, the three
stats (átlag · célon belül · edzés) wrapping under it on narrow widths, and the lazily-loaded `LifeyBarChart`
with the dashed goal line, today as a dashed unfilled outline and "Ma"/"Today" spelled out as its label; days
with nothing logged draw no bar. `e2e/ds/weekCalories.spec.ts` runs a fixed week on a gallery section (with
and without a goal): the header arithmetic, seven labelled columns with today spelled out, the dashed goal
line, the dashed today outline, no within-goal stat / goal line without a goal, and at 1024 all three Y-axis
labels inside the card. Two things learned about Recharts 3 while writing those: it paints axis labels as SVG
`<text>` in its own layer, *outside* `.recharts-xAxis`/`.recharts-yAxis` (those groups hold empty tick
shells), so a spec must match text over the whole chart; and Playwright's `getByText` doesn't find SVG text,
so it uses `locator("text")`. The dashboard's old `thisWeek` / `avgCalories` / `streak…` message keys are now
unused — left for W10's sweep. Checked on the real page at 1440 (HU) and 1024 (light): 4 / 6 nap, átlag 1 550
kcal, edzés 3, axis "1,9 e / 950 / 0".

### W1.9 — Web data: personal-record derivation port ✅
- Files: `features/workouts/personalRecords.ts` + test — port of `mobile/lib/features/workouts/domain/
  personal_record.dart` (docs/38: max weight, max reps at a weight, estimated 1RM; recomputed from
  history), **same definition as backend `trainer/PersonalRecordCounter.java`** (the trainer card's
  `prCount7d`).
- **Verify:** the mobile test cases; a fixture where the backend counter and the TS function agree.

*As built:* `features/workouts/personalRecords.ts` ports `personal_record.dart` — Epley `estimateOneRepMax`,
the immutable `PrBaseline` (`baselineFromSets` / `extendBaseline`: max weight and best 1RM exclude 0 kg sets,
max reps per *exact* weight includes them), strictly-greater `detectPrs` that never fires a kind without a
baseline value to beat, `computePrHistory` and `detectPrsInOrder` — and adds what the backend's definition
needs on top, so the dashboard and the trainer card count the same thing: `SetFact`, `recordsBySession()`
(sets of one exercise judged against the running best, each record kind counted **once per exercise per
session** — three ever-heavier sets in a row are one "heaviest set") and `countRecordsSince()` (=
`PersonalRecordCounter.countSince`), plus `setFactsFromSessions()` which feeds them from API sessions
(finished strength sessions only — in-progress and cardio sessions aren't history — oldest first, each
session's sets by time). `personalRecords.test.ts` has 32 tests in two parts: every case of
`personal_record_test.dart` ported unchanged, and every case of `PersonalRecordCounterTest.java` with the same
data and the same expected counts. The plan asked for a fixture where backend and TS agree; beyond the shared
cases, I also ran the TS function over the real demo accounts through the API and compared with what the
running backend reports as `prCount7d` on the trainer's client list — Kata 15 = 15, Levente 15 = 15, Réka 13 =
13, Máté 17 = 17, Dóra 19 = 19, all five equal. Nothing renders in this step; `recordsBySession()` is what
W1.10's row chip reads.

### W1.10 — Web UI: recent workouts list ✅
- Files: `features/dashboard/components/RecentWorkouts.tsx`, `features/workouts/activityType.ts` (labels
  through messages — no `humanizeEnum`), `features/workouts/cardioSummaryLine.ts` (reuse for meta).
- Spec row 3 right; row click opens the session summary (W3.4 route; until W3 lands, today's session
  view).
- **Verify:** no raw activity key in HU or EN; PR chip on the session that set a record.

*As built:* `RecentWorkouts` replaces the old list (`RecentWorkoutsSection` deleted): a `RecentWorkoutsView`
(rows in, so the gallery can show every state) plus a connected wrapper that builds the rows. Each row is a
button with a 40 px tinted tile — strength in the primary tint with the dumbbell, cardio in the heart tint
with the activity's own icon (`activityTypeIcon`) — the name, a `RecordChip` "PR" when that session set a
record, one meta line and a relative day on the right ("tegnap", "szept. 25." via `relativeDay`). Names never
show a raw key: cardio goes through `useFormat().activityLabel` (the `labels.activityTypes` catalog, "Séta"),
strength shows the template name or the exercises; the meta is "40 perc · 6 342 kg · 12 szett" for strength
(an unfinished session says "folyamatban", zero-length or set-less parts are left out rather than shown as 0)
and the existing `buildCardioSummaryLine` for cardio, so it stays identical to the workouts list. The PR flag
comes from `recordsBySession(setFactsFromSessions(...))` (W1.9), computed once in `useDashboardData` — on the
demo account Láb + core and Pull nap carry the chip, the other two rows don't. A row opens the session through
a new `?open=<sessionId>` deep link on the workouts page (`SessionsView` gained `autoOpenSessionId`, handled
once like the existing `?start=`, and the URL is cleaned afterwards) — the plan's "today's session view until
W3's summary route exists". "Mind" links to `/workouts`; below 640 px the fourth row drops (W1-C shows three);
an account with no sessions gets a compact empty state with a start button instead of an empty card. The
gallery section is titled "Recent workouts list" because the card's own h3 is "Recent workouts" and a
duplicate heading broke role queries. `e2e/ds/recentWorkouts.spec.ts` covers the rows and meta, the PR chip
only on the flagged row, words not keys, the two tints differing while two strength rows match, keyboard
focus, the phone row count and the empty state. Verified on the real app with the demo data, including the
click-through to the session.

### W1.11 — Web UI: first-steps card ✅
- Files: `features/dashboard/components/FirstSteps.tsx`, `components/app/OnboardingBanner.tsx` (removed
  from the dashboard).
- Spec W1-D; each step completes independently; the card disappears once a meal and a weight exist.
- **Verify:** a fresh demo account shows it; logging a meal ticks step 2 without reload.

*As built:* `FirstSteps` (a presentational `FirstStepsView` + a connected wrapper) is the W1-D card: "Szia,
Anna! Három lépés, és kész a napod képe." with the tiles-won't-show-zeros line, and three rows on a nested
surface — a 32 px state icon (done = filled primary with a check announced as "Kész", pending = the metric-
coloured icon on a control disc), title, detail, and a primary button on every pending step. *Célok beállítva*
is done once a calorie goal exists (its detail then reads "1 850 kcal · 110 g fehérje"; pending it asks to set
them and goes to `/onboarding`), *Első étkezés naplózása* opens the existing add-meal dialog (and the card
registers the `N` shortcut, since the hero that normally owns it isn't on screen), *Súly rögzítése* goes to
`/weight` until the W4 log-weight drawer exists. The rule is a pure module, `firstSteps.ts` (9 tests):
**fresh** = no meal ever and no weight ever, **complete** = a meal and a weight (goals are a setting, not a
log, so they're not required), and `showFirstSteps` — a fresh account shows the card in place of hero + tiles
and, once it has shown, it **stays** while the user works through it, which is what lets "logging a meal ticks
step 2 without reload" be true instead of the whole card vanishing and the zeroed hero jumping back; it ends
when both exist or the user dismisses it (the ✕, remembered per browser like the banner it replaces). Two
decisions the plan's wording left open: an established account that merely has no weight never sees the card
(the W1.7 weight tile has its own empty state for that), and the card is only decided once the meals and
weights queries have actually loaded, so it can't flash for an account with history. `OnboardingBanner` is
deleted (the card's first step is its replacement); its `onboarding.banner*` message keys are left for the W10
sweep. Verified on the real stack with a throwaway test account registered on the local backend for this
check: the card shows instead of hero and tiles, the week chart and recent list keep their own empty states,
and after adding a meal through the dialog step 2 turned into a check while the dialog was still open and the
chart drew today's dashed 400 kcal bar — no reload. Gallery section "First steps" (goals done / nothing done /
meal done) and `e2e/ds/firstSteps.spec.ts` cover the states, the buttons-only-on-pending rule and the dismiss
button.

**W1 acceptance** (plus §4.1 in §12): W1-A/B/C/D reproduced; no zero tiles for a new account; every
number formatted per DS-07.

**W1 web UI review focus:** W1-A at 1440 dark HU (and light EN), W1-B at 1024 light, W1-C at 390 dark,
W1-D with a fresh account; flows: log a meal from the hero (N), copy yesterday's meal + undo, quick-add
water, start the recommended workout, date stepper to yesterday and back (←, T) — hero and chart
animate only the difference.

---

## W2 — Nutrition · `Lifey Web 2 Nutrition.dc.html` (W2-A … W2-F)

**Goal:** log on the left, the day's budget always visible on the right; adding a food is one
keyboard-driven two-pane dialog; nothing is deleted without undo.

**Canvas notes = requirements:**

| Note | PDF ids | Requirement |
|---|---|---|
| Napló + összesítő, két súllyal | client-004 | One card per meal: icon, time, item count, kcal total in the header; items below on one line — name + quantity left, three macros with metric dots, kcal right; carbs and fat always visible |
| A Napi összesítő lett a hős | client-004 | Right panel = hero card: ring, kcal left, three macro bars (goal attribution chip: D-W0.19, not built) |
| Kétpaneles étel-hozzáadás | client-005, client-006, client-007 | 880 px modal: left search + filters (Saját, Receptek, Kedvencek, Legutóbbiak), right preview with quantity chips, meal-type segmented control and the "utána marad" line; fully keyboard-operable |
| Szerkesztés mentéssel, törlés megerősítéssel | extra-001, extra-002 | Quantity max 1 decimal, HU decimal comma; explicit Save / Discard with "Nem mentett változás"; delete → confirm modal → undo toast |
| Másolás: melyik nap, mely étkezések | extra-003 | The copy button opens a popover: day chips, the day's meals with checkboxes; the empty dinner card keeps a one-click "Tegnapi vacsora · 612 kcal" |
| Ételek: táblázat + szerkesztő panel | extra-004, extra-005, extra-006 | Sortable, filterable table, metric dots on macro headers, one ⋯ per row; the panel warns when macros don't add up to the kcal (quick portions: D-W0.19, not built) |
| Receptek a meglévő adatból | client-008, client-009 | Dominant-macro tint icon (or the photo), kcal per serving large, macro ratio bar; "528 kcal / adag" not "528 / serving" (trainer chip: not built) |
| Mobil: egy hasáb | client-079, client-087 | 390: summary as a compact card above the list, tabs as a 3-part segmented control, FAB above the bottom nav, toast above the FAB |

**Current code:** `app/(app)/nutrition/page.tsx` (32), `features/nutrition/components/{MealsView (309),
MealCard (108), AddMealEntryDialog (614), FoodsView (277), FoodEditor (200), RecipesView (208),
RecipeEditor (287), LogRecipeDialog (196), RecipeImageUploader, RecipeThumbnail}.tsx`,
`features/nutrition/{budget,copyMeal,usage,logRecipePortion,mealTypeDefault}.ts`,
`lib/hooks/useUiStore.ts` (`nutritionTab`).

**Target spec:**
- **Header (W2-A):** top bar "Táplálkozás" + date stepper; under it `Tabs`: Étkezések · Ételek **18** ·
  Receptek **3** (counts as small `--text-3` numbers); right of the tabs "Másolás korábbi napról"
  (secondary, `event_repeat`) and "＋ Étel hozzáadása `N`" (primary). The tab is in the URL
  (`?tab=meals|foods|recipes`) instead of `useUiStore`, so links and reloads keep it.
- **Meals tab (W2-A, 8 + 4):** left, one `MealCard` per logged meal (breakfast 07:15, lunch, snack): header
  = 40 px tinted icon (meal-type colour from the canvas: breakfast carbs, lunch protein, snack kcal,
  dinner fat), "Reggeli", meta "07:15 · 3 tétel" (recipe: "12:30 · recept, 1 adag"), kcal total right,
  "＋" (add to this meal) and "⋯" (Szerkesztés, Másolás…, Törlés…); item rows grid `1fr | 220 | 80 | 36`,
  left inset 74: name + quantity ("150 g · 1 pohár" → **"150 g"** only, D-W0.19), P / C / F with 8 px
  metric dots, kcal, row "⋯" on hover/focus. Meal types without an entry get an **empty slot card**
  ("Vacsora — Még nincs naplózva · 859 kcal fér bele", copy-yesterday chip "Tegnapi vacsora · 612 kcal",
  "＋ Hozzáadás"). Right, sticky: `DaySummary` hero — "NAPI ÖSSZESÍTŐ", ring + **859** "kcal maradt",
  "Elfogyasztva 1 041 kcal · Cél 1 900 kcal", three macro bars "68 / 120 g" (no fibre/sugar row).
- **Add food (W2-B):** `Modal` 880, grid `400px | 1fr`. Left: search field (autofocus, `esc` hint),
  filter chips **Mind · Saját ételek · Receptek · Kedvencek (favourite recipes) · Legutóbbiak**, "6
  TALÁLAT", result rows (name, source line "Saját · legutóbb ma reggel" / "Recept · 1 adag 412 kcal",
  "73 kcal / 100 g"), active row `--nested` + 3 px primary bar; footer hint "↑ ↓ választás · Enter
  hozzáadás · Tab mennyiség". Right: selected item title + source, quantity `NumberField` (g) + chips
  "100 g" and the last used amount ("150 g"); "Étkezés" segmented (Reggeli · Ebéd · Snack · Vacsora,
  default by time, `mealTypeDefault.ts`); a 4-column macro preview (Kalória 110 · Fehérje 15 g ·
  Szénhidrát 5,4 g · Zsír 3 g); the line "Utána marad **749 kcal** · fehérje még 37 g"; "Mégse" +
  "Hozzáadás a vacsorához". Recipes use `logRecipePortion.ts` (servings instead of grams).
- **States (W2-C):** copy-from-day `Popover` (chips "Tegnap · szept. 26.", "szept. 25.", "Másik nap" →
  `CalendarPopover`; the day's meals with checkboxes and kcal; "A mai naphoz adódik, nem írja felül."; "1
  étkezés másolása"); delete `ConfirmModal` ("Törlöd a snacket? 2 tétel, 134 kcal. Utána még 6
  másodpercig visszavonhatod.") → undo toast; edit-meal `Drawer` ("Reggeli szerkesztése", "Nem mentett
  változás" chip, item rows `1fr | 120 | 64` with quantity fields, focus ring on the edited one,
  "Elvetés" + "Mentés").
- **Foods tab (W2-D, light):** `DataTable` + 380 px editor panel: toolbar search ("Keresés /"), primary
  "＋ Új étel"; columns Név ↑ · kcal / 100 g · Fehérje · Szénhidrát · Zsír (metric dots) · Utoljára
  (from `usage.ts`: "ma", "szept. 25.") · ⋯ (Szerkesztés, Duplikálás, Naplózás ma, Törlés…); selected row
  opens `FoodEditor` in the panel: Név, Alapmennyiség 100 g, Kalória, Fehérje / Szénhidrát / Zsír, the
  info line "A makrók 72 kcal-t adnak ki — ez 1 kcal-lal tér el." (info when the rounded 4P + 4C + 9F
  differs from kcal; warning tone above 10 %), "Mégse" + "Mentés". Filter chips Saját / Katalógus /
  Kedvencek and the portions block are **not built** (D-W0.19).
- **Recipes tab (W2-E, 1024 light):** 3-column card grid (2 at < 1024, 1 at 390): photo (thumbnail
  endpoint) or a 56 px dominant-macro tint icon; name (16/800), "4 adag · 5 hozzávaló", **528 kcal /
  adag**, `RatioBar` P/C/F, "F 38 g · Sz 58 g · Zs 14 g" in metric colours, "Naplózás" (tonal) + "⋯"; "＋
  Új recept" primary in the tab row.
- **Mobile (W2-F):** compact summary card (ring + "859 maradt" + three mini macro rows) above the list;
  tabs = 3-part `SegmentedControl`; meal cards with item rows "150 g · F 15"; FAB "＋ Étel"; toast
  "Snack törölve · Visszavonás" above the FAB.

**Data:** everything used exists; see D-W0.19 for what is not built.

### W2.1 — Web UI: nutrition header, tabs in the URL ✅
- Files: `app/(app)/nutrition/page.tsx`, `lib/hooks/useUiStore.ts` (`nutritionTab` removed).
- **Verify:** `?tab=foods` deep link; tab counts; `N` opens add food on every tab.

*As built:* The page is now a header plus the active tab: DS `Tabs` (underline) — Étkezések · Ételek **18** ·
Receptek **4** — with the copy and add actions to the right. `Tabs` gained an optional `count` (a small
`--text-3` number after the label, separated by a real space so the accessible name reads "Ételek 18", not
"Ételek18"; gallery demo + spec). The tab lives in the URL: `features/nutrition/nutritionTab.ts`
(`parseNutritionTab` — anything missing or unknown is the meals tab — and `nutritionTabHref`, where meals is
the bare `/nutrition`; 5 tests round-trip it) and the page uses `useSearchParams` + `router.replace(…, {
scroll: false })`, so `?tab=foods` deep links, reloads and the back button keep it; `nutritionTab` is removed
from `useUiStore`. The counts come from the same `foods` / `recipes` list queries the tabs and the add dialog
already use (hidden foods — the one-off "enter macros" entries — aren't counted), so they add no new request
shape. "＋ Étel hozzáadása **N**" is primary and registers the `N` shortcut through `usePageShortcuts` (listed
in `?` as "Étel hozzáadása") on every tab; it opens the existing `AddMealEntryDialog` with the clock's meal
type until W2.5/W2.6 replace it. "Másolás korábbi napról" (secondary, `event_repeat`) shows on the meals tab
and opens the existing copy-previous-day confirm through a tiny shared store (`nutritionUi.ts`), which
`MealsView` now reads instead of its own local flag — W2.9 swaps that confirm for the day-chip popover.
Verified on the real app: `?tab=foods` selects the tab and survives a reload, clicking tabs rewrites the URL
(meals drops the query), `N` opens add-food on all three tabs, the copy button appears on meals only. The
recipes count on the demo account is 4 (the canvas shows 3).

### W2.2 — Web UI: meals tab layout + `DaySummary` hero ✅
- Files: `features/nutrition/components/{MealsView,DaySummary}.tsx`.
- **Verify:** 8 + 4 at 1440/1280, summary sticky; at 1024 the summary sits above the list; W2-A side by side.

*As built:* The meals tab is now a `PageGrid` (W1.1's): the meal list spans 8 and the new `DaySummary` 4 from
1280 — the summary wrapper is `sticky top-6` there — and below 1280 the summary moves above the list via
`order` (W2-A/B at 1440/1280/1024; the phone layout is W2.12). `DaySummaryView` is the canvas' right-hand
hero: the "NAPI ÖSSZESÍTŐ" label, a 112 px ring with **859** and "kcal maradt", "Elfogyasztva 1 041 kcal" and
"Cél 1 900 kcal" beside it, and three macro rows "68 / 120 g" with `MetricBar`s — no fibre or sugar rows. It
deliberately reuses the dashboard hero's pure `heroState` / `macroRowState`, so the two screens can't disagree
about what is left: under budget it shows the remainder, over budget the overage with the caption in
`--m-kcal` (a macro past its goal is painted the same), and without a calorie goal what was eaten with no goal
line; a macro without a goal shows its value only. The old hand-rolled panel (prominent "remaining" lines,
plain bars, meal and item counts and its own "copy previous day" button) is gone — the copy action lives in
the page header since W2.1. The remaining-budget helpers in `budget.ts` stay for the add dialog until W2.6.
Gallery section "Day summary" (remaining / over / no goal, on the canvas' 1 041 / 1 900 day) and
`e2e/ds/daySummary.spec.ts` cover the three states and the macro rows; checked on the real page at 1440 (HU,
dark), 1024 (light) and 390.

### W2.3 — Web UI: `MealCard` v2 + item rows ✅
- Files: `features/nutrition/components/{MealCard,MealItemRow}.tsx`.
- **Verify:** HU long food names wrap to two lines, never truncate; macros always visible; row "⋯"
  reachable by keyboard.

*As built:* `MealCard` is rewritten on the DS `Card` with a new `MealItemRow`. The header is a 40 px icon tile
tinted in the meal type's colour (`mealTypeStyle.ts`: breakfast carbs, lunch protein, snack kcal, dinner fat,
all metric tokens), the type as the title, "7:15 · 3 tétel" under it (DS-07 time, so "7:15 AM · 3 items" in
EN), the kcal total, a "＋" (add to this meal) and a "⋯" with Szerkesztés / Másolás / Törlés… (the Menu adds
the ellipsis to the destructive one). A recipe meal — the meals `LogRecipeDialog` creates carry the recipe's
name — is one row for the whole portion ("Csirkés rizstál brokkolival · 420 g", meta "12:30 · recept"), a food
meal lists its foods. Rows are the planned 4-column grid (`1fr | 220 | 80 | 36`, left inset 74 so they line up
under the title): the name (wraps to a second line, never truncates — a spec checks a 70-character Hungarian
name gets more than one line and no ellipsis or hidden overflow), grams only under it (no household units,
D-W0.19), protein / carbs / fat each behind an 8 px metric dot in **whole grams** as on the canvas (always
visible, with screen-reader labels), the kcal, and a row "⋯" that is transparent until hover *or focus-within*
— so it can be tabbed to — and always shown on a phone. `MealsView` lists the types in the canvas order
(breakfast, lunch, snack, dinner) as bare cards; a type with nothing logged still shows the old dashed add /
copy-yesterday buttons until W2.4 replaces them with slot cards. The row "⋯" offers Edit only for now — W2.8
adds "delete item" there. `MealCard` is also the trainer's read-only view of a client's day
(`ClientNutritionTab`), which has no handlers: it simply draws no actions and gets the new look for free (W8
reworks that screen). Two small fixes the spec run caught: a unit next to a number needs a real space, not a
margin, or the accessible name reads "379kcal". Gallery section "Meal card" (multi-item breakfast with the
long name, recipe lunch, one-item snack, a read-only card) + `e2e/ds/mealCard.spec.ts` (7 tests); checked on
the real page on 27 Sep (the canvas' 859 / 1 041 day): two recipe cards with their rows and dots.

### W2.4 — Web UI: empty meal-type slot cards ✅
- Files: `features/nutrition/components/EmptyMealSlot.tsx`, `copyMeal.ts` (`suggestCopy` from W1.3).
- **Verify:** slot shows the "fér bele" budget; one-click copy + undo.

*As built:* `EmptyMealSlot` replaces the dashed "add to…" / "copy yesterday" buttons for a meal type with
nothing logged: a quiet nested `Card` (no dashed outline — a spec asserts it) with the type's icon on a
control disc, the name, "Még nincs naplózva · 1 900 kcal fér bele" (the fits-in-budget part only when a
calorie goal exists *and* something is left — over budget or no goal says just "Még nincs naplózva"), a
secondary one-click chip "Tegnapi vacsora · 438 kcal" when the day before the viewed day had meals of that
type (still only offered while viewing today, as before) and a tonal "＋ Hozzáadás". The copy now goes through
a new shared hook, `useCopyMeals(date)`: it creates a *new* meal for each source (original time of day, never
overwriting), refreshes the list, and raises the toast "Tegnapi vacsora átmásolva · Visszavonás" whose Undo
deletes exactly the meals that copy created — the same direction-of-undo reasoning as the dashboard button
(`showUndo` rather than `useUndoableDelete`, which defers a DELETE of something that already exists); W2.9's
popover will reuse it. The old full-width "copy the whole previous day" confirm stays until W2.9. Verified
against the real backend with two meals seeded for yesterday (removed afterwards): both slots show their chips
with the right kcal, one click adds the dinner card and hides its chip, Undo sends exactly one `DELETE` and
the chip returns. Gallery section "Empty meal slot" (with copy, budget only, no goal, used up) and
`e2e/ds/emptyMealSlot.spec.ts`.

### W2.5 — Web UI: add-food modal, search pane ✅
- Files: `features/nutrition/components/addFood/{AddFoodModal,FoodSearchPane}.tsx`,
  `features/nutrition/usage.ts` (recents, last used amount); `AddMealEntryDialog.tsx` is retired at the
  end of W2.6.
- Filters, result ranking (exact prefix > recent > rest), keyboard ↑/↓/Enter/Tab, empty result → "Új
  étel létrehozása «joghurt» néven".
- **Verify:** `foodSearch.test.ts` (ranking, filters); keyboard-only add in the browser.

*As built:* The new dialog's shell and its left pane exist and are tested; it is not yet wired into the
nutrition page (that happens with its right pane in W2.6, where `AddMealEntryDialog` is retired), so the
plan's "keyboard-only add in the browser" is verified here on the gallery's version with a stub preview and
again on the real app at the end of W2.6. **Search logic** is pure, in `features/nutrition/foodSearch.ts` (16
tests in `foodSearch.test.ts`): rows are the user's foods (not the hidden one-off "enter macros" foods) and
recipes; filters are All / My foods / Recipes / Favourites (favourite recipes) / Recent; matching ignores case
and accents; with a query, names that **start with** it come first (an exact match before a longer prefix),
then inside each group recently logged rows, then a word that starts with the query before a mere substring,
then the newest use, then the alphabet; with no query the list leads with what you logged lately, then what
you log often (≥ 2 times), then the rest alphabetically, and Recent is just the lately-logged rows. A recipe
carries kcal per serving and per 100 g of the dish (from its ingredients). `usage.ts` gained
`computeRecipeUsage` — a logged recipe is a meal carrying the recipe's name, so usage is found by that name
within the same 90-day window (2 tests); "last used amount" was already `lastGrams` in `FoodUsage`. **The
pane** (`addFood/FoodSearchPane.tsx`) is an ARIA combobox/listbox: autofocused search field with an `esc`
hint, the five filter chips as toggle buttons (`aria-pressed`), "4 TALÁLAT" as a live region, rows with name,
source line ("Saját · legutóbb tegnap 08:00" / "Recept · 1 adag 412 kcal") and "73 kcal / 100 g", the active
row on `--nested` with a 3 px primary bar and scrolled into view; ↑ / ↓ move (and stop at the ends rather than
wrap), Enter adds the active row, Tab jumps to the quantity, a row click selects it and does the same; an
empty result offers "Új étel létrehozása „joghurt” néven". **The shell** (`addFood/AddFoodModal.tsx`) is an
880 px `Modal` with the planned `400px | 1fr` grid — `AddFoodModalView` takes items and usage (gallery-
friendly), `AddFoodModal` adds the three queries — and the right pane is whatever the caller renders, reading
the dialog through `useAddFoodContext()` (highlighted row, a quantity-input callback, a commit hook for
Enter). Two platform fixes the keyboard spec exposed: `useFocusTrap` wrapped focus on top of a Tab that a
field had already handled (the search field moving focus to the quantity, now the last focusable, got bounced
back to the first) — it now ignores `defaultPrevented` Tabs; and the React Compiler lint rejects reading ref
objects off a render-prop argument, which is why the preview slot is context, not a function. Gallery section
"Add food dialog" and `e2e/ds/addFoodSearch.spec.ts` (10 tests: autofocus, recents first, source lines,
ranking, the full keyboard flow type → ↓ → Tab → 150 → Enter, Enter with the default quantity, the active
marker, no wrap, every filter, the create shortcut, Esc).

### W2.6 — Web UI: add-food modal, preview pane + submit ✅
- Files: `features/nutrition/components/addFood/FoodPreviewPane.tsx`, `features/nutrition/budget.ts`
  (`remainingAfter(entry)`), delete `AddMealEntryDialog.tsx`.
- "Utána marad" subtracts the **stored** version when editing an existing meal (risk 3).
- **Verify:** `budget.test.ts` (new entry vs editing an existing entry); W2-B side by side; 390 = sheet.

*As built:* The right pane (`addFood/FoodPreviewPane.tsx`: a presentational `FoodPreviewPaneView` plus the
connected `FoodPreviewPane`) completes the dialog, and `AddFoodFlow` wires it to the app — every add-food
entry point now opens it: the page header's button and `N`, each slot's "Hozzáadás" and each meal card's "＋"
(starting on that meal type), the dashboard hero and first-steps card, and the foods table's "log today"
(search pre-filled with the food's name and its row highlighted). The pane shows the highlighted row's name
and source, the quantity as a `NumberField` (grams, or servings for a recipe) with the "100 g" and last-used
chips, the meal type as a `SegmentedControl` (starting from the caller's, else the clock's), four macro tiles,
"Utána marad **750 kcal** · fehérje még 37 g" with a two-tone bar, and Mégse + "Hozzáadás a vacsorához" (an
ICU `select`, so the Hungarian dative is right for each meal). The budget arithmetic is
`remainingAfter(consumed, goals, add, replaces?)` in `budget.ts` (5 new tests): `replaces` takes the stored
version of an entry being edited out first — the plan's risk 3 — so the W2.7 drawer can't double-count; for a
new entry it is simply omitted. Recipe macros come from `recipeMacros.ts` (7 tests): the recipe API carries
only kcal and protein per ingredient, so carbs and fat are worked out from the foods the ingredients point at.
To make "type 150, Enter" work, `NumberField` gained `inputRef`, `liveUpdate` (report every parseable
keystroke so the preview follows what's typed), `selectOnFocus` and `onEnter`. What submit does: a food goes
into the day's latest *plain* meal of that type (a recipe meal — one with a name — is never extended with
loose foods) or starts one, a recipe always becomes its own meal named after it, its ingredient grams scaled
by servings via `logRecipePortion.buildEntries`; then the meals refresh and a toast says "Hozzáadva: Vacsora".
The empty result hands the typed name to the foods tab (`?tab=foods&new=…`), which opens its editor with it.
Verified on the real app, keyboard only: `N` → "görög" → Tab → 150 → Enter adds the meal (one `POST`), and a
second `N` → "alma" → 180 → Enter *extends the same meal* (one `PUT`, still one card); the test meals were
deleted afterwards. **Deviation from the plan:** `AddMealEntryDialog.tsx` is not deleted in this step — it
still backs "edit meal" in `MealsView` and is removed in W2.7 together with its replacement, the edit drawer,
so there is no commit in which editing has no UI. Gallery: the "Add food dialog" section now runs the real
preview pane; `e2e/ds/addFoodPreview.spec.ts` (10 tests) covers quantity/chips/live macros, "left after this"
and its "over" flip, meal type and the submit label, recipes by servings, cancel and the empty result.

### W2.7 — Web UI: edit-meal drawer ✅
- Files: `features/nutrition/components/EditMealDrawer.tsx`.
- **Verify:** unsaved guard on Esc/scrim; "166,7 g" round-trips; Save disabled until dirty.

*As built:* `EditMealDrawer` (a presentational `EditMealDrawerView` plus the connected drawer) replaces the
old auto-saving dialog for "edit meal", and `AddMealEntryDialog.tsx` is now deleted — nothing references it.
The drawer is the DS `Drawer` (480) titled "Reggeli szerkesztése" with one row per food: name, a `NumberField`
for the quantity (one decimal, the locale's comma) and the kcal, which follows the quantity live; the footer
is "Elvetés" (closes) and "Mentés", **disabled until something really changed**, and the "Nem mentett
változás" chip appears under the title with the first change. Two rules live in pure `mealEdit.ts` (9 tests):
a row counts as changed only if it differs from what the drawer *showed* — the stored quantity at one decimal,
so typing 166,7 against a stored 166.685… is not a change and editing away and back ends clean — and untouched
rows are saved with their **stored, unrounded** quantity, never a rounded copy. Verified against the real
backend: a meal seeded with 100.123456 g shows "100,1", typing "166,7" enables Mentés and the chip, Esc asks
"Elveted a módosításokat?", Folytatom returns to the drawer, Mentés sends one `PUT` and the stored values are
166.7 and — untouched — exactly 75; the test meal was deleted afterwards. Three platform fixes found on the
way: (1) **a real `Drawer` bug** — its Esc listener was attached once per open and kept the *first* render's
unsaved-guard, so a form that became dirty after opening closed on Esc without asking (the gallery's own spec
only ever made it dirty *before* opening); it now reads the current guard through a ref; (2) the drawer's
discard prompt, its close button and `NumberField`'s ± buttons were hard-coded English — they go through
`common.*` now ("Elveted a módosításokat?", "Elvetés", "Folytatom a szerkesztést", "Csökkentés / Növelés");
(3) the drawer's `badge` slot sits under the title, because beside it a Hungarian title was cut to "Reggeli
szerkeszté…". `NumberField` also takes an `aria-label` for fields with no visible label. Gallery section "Edit
meal drawer" and `e2e/ds/editMealDrawer.spec.ts` (9 tests, including the Hungarian copy and the decimal
comma).

### W2.8 — Web UI: delete meal / item with confirm + undo ✅
- Files: `MealCard.tsx`, `MealItemRow.tsx` (deleting the last item deletes the meal — say so in the
  confirm copy), `useUndoableDelete` wiring.
- Behaviour change (called out): delete was immediate with no confirmation.
- **Verify:** undo restores the meal without a network call; after 6 s exactly one DELETE; navigating away
  flushes it.

*As built:* Deleting a meal or one food now asks first with the DS `ConfirmModal` and then goes through the
undo toast (D-W0.16) instead of firing a request: the card leaves the list at once, a "Reggeli törölve ·
Visszavonás" toast runs for 6 s, and the real request is sent only when that window closes — or when the user
navigates away, which flushes it (`keepalive`). Undo puts the card back and sends **nothing**. Two entry
points in `MealsView`: the header "⋯" deletes the meal ("Törlöd a reggelit? 3 tétel, 344 kcal. Utána még 6
másodpercig visszavonhatod."), and each food row's "⋯" now has a destructive Delete next to Edit ("Törlöd:
Édesburgonya? 110,5 g, 95 kcal …"); the dialog's initial focus is the safe "Mégsem". The API has no per-item
endpoint, so removing one food is a deferred `PUT /meals/{id}` of the remaining entries, carrying each
untouched row's **stored, unrounded** quantity (and the meal's own `dateTime`, type and name); removing the
*last* food deletes the whole meal and the dialog says so ("Ez az étkezés utolsó tétele, ezért az egész
étkezés törlődik"). A recipe meal shows one row for the whole portion, so its row "⋯" deletes the meal, not a
single ingredient. Helper layer: `undoableDelete` gained an optional `commit` (used instead of `DELETE path`),
`client.ts` a `keepalivePut`, and a failing deferred request restores the card and shows the error toast (3
new unit tests → 13 in `useUndoableDelete.test.ts`). The old auto-firing `ConfirmDialog`/mutation, the
`isDeleting` prop and four dead messages are gone. Verified against the real backend (two seeded test meals,
removed afterwards): item delete → confirm → row gone → Undo → no request and the row is back; item delete →
after 6 s exactly one `PUT` and the stored entries are 100 and 121 (the other rows untouched); meal delete →
after 6 s exactly one `DELETE`; meal delete then navigating to the dashboard inside the window → the `DELETE`
is sent and the meal is gone on the backend. Gallery "Meal card" section gained a "Delete requested" log and
two specs in `e2e/ds/mealCard.spec.ts` (food row → item delete; recipe row → meal delete).

### W2.9 — Web UI: copy-from-day popover ✅
- Files: `features/nutrition/components/CopyFromDayPopover.tsx`, `copyMeal.ts`.
- **Verify:** copying 2 meals from yesterday adds them to the selected day, never overwrites; success toast
  with undo.

*As built:* "Másolás korábbi napról" now opens a day-chip popover instead of the old "copy the whole previous
day?" confirm. `CopyFromDayPopover.tsx` has a presentational `CopyFromDayView` (the DS `Popover`, 392 wide,
anchored to the page-header button) and a connected wrapper that reads the meals the log already loads and
copies through `useCopyMeals`. Inside: chips "Tegnap · szept. 29." / "szept. 28." / "Másik nap" (the viewed
day minus one and two; "Másik nap" unfolds the DS month grid, future days disabled, a dot on every day that
has a logged meal, and the chip then reads "Másik nap · szept. 12."), the chosen day's meals as rows with a
checkbox, the meal type's tinted icon, "07:07 · 2 tétel" (a recipe shows its name) and kcal, the note "A mai
naphoz adódik, nem írja felül." (or "{nap} napjához …" when a past day is being viewed) and a primary "N
étkezés másolása" that counts the ticked meals and is disabled at zero; a day with nothing logged says so.
Everything starts ticked on the first chip each time it opens, and the first chip takes focus (a frame late,
so the Popover's focus-return still remembers the real trigger — Esc returns to the button). Copies are **new
meals** at the source meal's time of day on the viewed day (`copyMealPayload`), so nothing is overwritten; the
success toast "2 étkezés átmásolva" has Undo, which deletes exactly the meals that copy created. Pure helpers in
`copyFromDay.ts` (8 tests: quick days across month ends and DST, a day's meals in time order, logged-day keys,
chip mapping). The old confirm, its `copyMealsMutation`, the `nutritionUi.ts` store it needed (the popover
state now lives in the page next to its button) and four dead messages are removed. Verified on the real
backend (seeded meals, removed afterwards): with one lunch already logged today, copying yesterday's two meals
sent two `POST /meals`, today went from 1 to 3 meals (the lunch untouched), unticking dinner changed the
button to "1 étkezés másolása", and Undo sent two `DELETE`s and returned to 1. Gallery section "Copy from day
popover" and `e2e/ds/copyFromDay.spec.ts` (10 tests, incl. the calendar dots, the empty day, focus return,
reopening reset and the Hungarian copy).

### W2.10 — Web UI: foods table + editor panel ✅
- Files: `features/nutrition/components/{FoodsView,FoodEditor}.tsx`, `features/nutrition/macroCheck.ts` +
  test.
- **Verify:** sorting by every column, `/` focuses search, row ⋯ "Naplózás ma" opens the add-food modal
  preselected; mismatch info line thresholds.

*As built:* The foods tab is now the DS `DataTable` plus a 380 px editor panel, both presentational
(`FoodsTable.tsx`, `FoodEditor.tsx`) under a connected `FoodsView`. The table works on the whole food list —
the query the tab's count and the add-food dialog already use — so every column sorts across all foods,
"Utoljára" included (from `usage.ts`: "ma", "tegnap", "szept. 25.", "—" for a food not logged in 90 days): Név
· kcal / 100 g · Fehérje · Szénhidrát · Zsír (each macro header with its metric dot) · Utoljára, a search
field (placeholder "Keresés /", `/` focuses it, matches ignore accents and case and need every word —
`foodsTable.ts`, 4 tests), "＋ Új étel", "18 étel · 1–15" paging and one "⋯" per row: Szerkesztés, Duplikálás
(creates "X (másolat)", "(másolat 2)"… and opens it in the editor), Naplózás ma (the add-food modal
preselected on that food, logging to today) and a destructive Törlés… (a `ConfirmModal`, then the W2.8 undo
toast: the food leaves the list at once, Undo sends nothing, the real `DELETE` — a soft delete on the backend,
so meals that used the food keep it — goes out after 6 s). Clicking a row opens the editor beside the table
from 1280 (above it below that; the phone layout is W2.12): Név, a fixed "Alapmennyiség 100 g", Kalória /
Fehérje / Szénhidrát / Zsír as DS `NumberField`s (two decimals, the locale's comma), an optional barcode with
a "Keresés" lookup for a new food (OpenFoodFacts prefill, or the existing food if the barcode is already
yours), "Mégsem" + "Mentés". **Mentés stays disabled until something really changed** (`foodEdit.ts`, 9
tests): a number counts as changed only at the two decimals the field shows, so tabbing through a stored
13.3333 is not an edit, and untouched numbers are saved exactly as stored. The **macro line**
(`macroCheck.ts`, 7 tests) appears while typing — "A makrók 72 kcal-t adnak ki — ez 1 kcal-lal tér el." — as a
grey info note for any gap up to 10 % of the kcal and a red warning above it (kcal 0 with macros is a
warning); it never blocks saving, and it updates live so it cannot shift "Mentés" away between mouse-down and
click (found in the gallery spec: with blur-only commits the click was lost). A duplicate name comes back as a
409 and shows under the name field. Called out: the editor no longer has the "hidden from search" switch and
the table never listed hidden foods anyway (the backend list and the tab count exclude them), the always-
visible "Add to meal" button moved into the row menu, and the barcode box moved from the toolbar into the new-
food editor. Three platform fixes found on the way: (1) **`DataTable` sorted text by code point**, so
"Édesburgonya" landed after "Zabpehely" — it now uses `Intl.Collator` for the current locale (numeric-aware);
(2) its `/` shortcut now answers only when its own search box is on screen (several tables per page, e.g. the
gallery); (3) the toolbar's "Row density / Comfortable / Compact" and the header cells were hard-coded English
/ wrapped — now `common.*` ("Kényelmes / Kompakt") and `whitespace-nowrap`. Verified against the real backend
(throwaway "ZZ W210" foods, removed afterwards; 18 foods before and after): 15 rows on page one with "18 étel
· 1–15", `/` focuses the search, all six columns sort both ways (Név Alma → Zabpehely, Zsír Édesburgonya →
Mandula, …), a new food with kcal 200 and macros giving 165 shows the red line "…165 kcal-t adnak ki — ez 35
kcal-lal tér el.", Mentés sends one `POST`, editing kcal to 205 one `PUT` (stored 205), Duplikálás one `POST`
and opens "ZZ W210 teszt (másolat)", Naplózás ma opens the modal with the food, and delete → Visszavonás sends
nothing while a second delete sends exactly one `DELETE` after the window. Gallery section "Foods table and
editor" (18 foods) and `e2e/ds/foodsTable.spec.ts` (10 tests: headers/count, Last used, every column's sort,
search, row menu, editor open/Save gating, untouched tabbing, the three macro-line tones, new food + lookup,
Hungarian); the gallery can't assert `/` focus because its Shortcuts demo answers `/` as well — that one was
checked on the real page.

### W2.11 — Web UI: recipe cards + log-recipe modal ✅
- Files: `features/nutrition/components/{RecipesView,RecipeCard,LogRecipeDialog,RecipeEditor}.tsx`,
  `features/nutrition/recipeTint.ts` + test (dominant macro by kcal share).
- **Verify:** photo when present, tint icon otherwise; "kcal / adag" in HU, "kcal / serving" in EN.

*As built:* The recipes tab is now a grid of `RecipeCard`s and the "log as meal" dialog and the recipe editor
are DS overlays. **Cards** (`RecipeCard.tsx`, presentational): the photo (`RecipeThumbnail`, 56 px) or a 56 px
icon holder in the colour of the recipe's **dominant macro** (`recipeTint.ts`, 5 tests: biggest share of kcal
with protein and carbs at 4 kcal/g and fat at 9 — protein `egg_alt`, carbs `bakery_dining`, fat `water_drop`,
a neutral book when there are no macro data), the name (16/800, two lines, never truncated), "4 adag · 3
hozzávaló", the **kcal per serving** at 28/800 with "kcal / adag" ("kcal / serving" in EN, never a bare "/
serving"), a P/C/F `RatioBar` by kcal share, "F 55 g · Sz 58 g · Zs 8 g" with each part in its metric colour,
a tonal "Naplózás" and a "⋯" (Szerkesztés, Duplikálás, Törlés…; "Kiosztás" first in the admin view). The top
of the card opens the editor; the actions sit outside that button so nothing is nested. The column count
follows the **pane**, not the viewport (container queries: 1 below 560 px, 2 from 560, 3 from 840), so the
sidebar is accounted for. `RecipesView` now works on the whole recipe list (the query the tab's count uses)
plus the food list, because the recipe API carries only kcal and protein per ingredient — carbs and fat come
from the foods (`recipeMacros.ts`); search ignores accents and case, "Kedvencek" is a toggle chip, and "＋ Új
recept" is in the page's tab row on this tab (a controlled `creating` prop; the admin view, which has no such
row, still draws its own). Duplicate is one click with a toast (the confirm was noise for a non-destructive
action); **delete is confirm → undo toast** like W2.8 — the card leaves at once, Undo sends nothing, the
`DELETE` goes out after 6 s — so every delete in W2 is now undoable. **Log dialog** (`LogRecipeModal` +
connected `LogRecipeDialog`): DS `Modal`, meal type as a `SegmentedControl`, "Egy adag rögzítése" switch (on
by default for a multi-serving recipe) with a split stepper and the line "Minden hozzávaló 4 részre oszlik, te
egyet naplózol belőle.", "Hozzávalók módosítása" with a `NumberField` of grams per ingredient (0 leaves it
out, a reset button per overridden row) and a preview of exactly what will be logged — kcal **and** F / Sz /
Zs, where the old one showed kcal and an untranslated "protein" (`scaledMacros`, 3 new tests → 14 in
`logRecipePortion.test.ts`). **Editor** (`RecipeEditor`): a DS `Drawer` (520) with DS fields; the auto-save
engine (debounced, one request at a time) is unchanged, and the header now says so — "A módosítások
automatikusan mentődnek" / "Mentés…" / what is still missing; the footer has "Törlés…" (confirm + undo) and
"Kész". Verified against the real backend (throwaway "ZZ W211" recipe and a logged meal, removed afterwards; 4
recipes and 155 meals before and after): four cards with the right kcal per serving (528 = the API's total
over 4), the modal's preview matches the card, logging a snack sends one `POST /meals` with 3 entries, "Új
recept" in the tab row creates the recipe by auto-save (one `POST`), changing the servings sends one `PUT`,
and deleting from the editor closes it, Undo sends nothing and a second delete sends exactly one `DELETE`
after the window. Two platform bugs found on the way: (1) **the toast sat at the same z-index as drawers**
(both `z-[60]`, the drawer later in the DOM), so a toast raised while a drawer was open — "Undo" after
deleting from the editor — was covered and unclickable; it is `z-[70]` now, matching D-W0.15's toast > modal >
drawer; (2) the first focus in a modal landed on its close icon, whose tooltip then hung clipped at the top —
the log dialog has no close icon (Esc and "Mégsem" do that). Gallery section "Recipe cards and log modal" and
`e2e/ds/recipeCards.spec.ts` (14 tests: card content, the four tints, the favourite star, wrapping names,
actions and menu, 3 → 1 columns, Hungarian, and the modal's preview, split, overrides, reset, payload, Esc and
Hungarian).

### W2.12 — Web UI: nutrition at 390 ✅
- Files: the W2 components' responsive variants; FAB via the W0.22 slot.
- **Verify:** W2-F side by side; toast above the FAB; no overlap with the bottom nav.

*As built:* Nutrition now has its phone shape (W2-F, client-079/087), built from the W2 components' own
responsive variants and the FAB slot D-W0.22 promised. **Tab row** (`NutritionHeader.tsx`, extracted from the
page so it can be shown in the gallery): under 768 px the three tabs are one full-width `SegmentedControl`
(`fullWidth`, 44 px segments) — "Étkezések · Ételek 18 · Receptek 4" — with "Másolás korábbi napról" as an
icon beside it on the meals tab; from 768 the underline tabs and the button row are unchanged. **FAB**
(`Fab.tsx`): an extended 56 px primary pill, bottom right, 96 px above the bottom (16 px over the floating
nav's top edge), `z-30` so every sheet covers it; "＋ Étel" on meals and foods, "＋ Recept" on recipes (`aria-
label` still "Étel hozzáadása" / "Új recept"). While mounted it publishes `--fab-clearance: 72px` on the root,
which the shell adds to `<main>`'s bottom padding (the last card scrolls clear of it) and the toast adds to
its offset. **Toast**: its bottom offset is now `--toast-bottom` — 24 px on desktop, 92 px on a phone (above
the nav, which it used to overlap on *every* page) plus the FAB's 72 px, so "Snack törölve · Visszavonás" sits
12 px above the FAB (164 px from the bottom, measured on the real app: toast bottom 680, FAB top 692). **Day
summary** under 768 px is the compact card: a 92 px ring with what is left ("1 345 kcal maradt") beside three
mini macro rows — no title, no eaten / goal block — so the first meal is on the first screen. **Meal rows**:
name + "150 g · F 15" with the kcal and "⋯" on the right (carbs and fat stay in the desktop row and the edit
drawer); the 74 px indent is 16 px. **Panels**: the copy-from-day popover, 392 px wide, is the same panel as a
bottom sheet under 768 px (`Modal`'s phone shape) instead of spilling off the screen; the foods editor is a
`Drawer` (a sheet on a phone) below 1280 px instead of a card stacked above the table, with the discard guard
("Elveted a módosításokat?" on Esc with unsaved edits, checked on the real app), and a side panel from 1280 as
before (`FoodEditor` got `bare` and `onDirtyChange`); the foods table drops the density switch under 768 px,
where rows are cards anyway. **Platform bugs found at 390**: (1) every `IconButton`'s tooltip is an absolutely
positioned, invisible span — one near the right edge widened `<main>`'s scrollable area to 427 px and focus
then slid the whole page 37 px sideways (caught by probing `main.scrollWidth` after a menu click; the gallery
check only looked at the document); tooltips are `display: none` under 768 px now (there is no hover anyway);
(2) the doubled ellipsis in the row menus ("Törlés……") — `Menu` already ends a destructive label with "…", so
the foods and recipes `menuDelete` strings lost theirs. Verified on the real app at 390 × 844 with seeded
meals (removed afterwards): no horizontal scroll, the compact summary, three rows "100 g · F 20", the FAB,
delete → toast above the FAB → Undo, FAB → add-food sheet, copy sheet, foods editor sheet with the discard
guard, recipes FAB → the recipe editor sheet. Gallery section "Nutrition on a phone" and
`e2e/ds/nutritionMobile.spec.ts` (14 tests: segmented tabs ≥ 44 px with counts, the copy icon, the FAB's label
per tab and its geometry, the toast's clearance, the compact summary, the rows, no sideways scroll, the copy
sheet, the foods cards, the desktop shapes at 1440 — no FAB, no clearance, title kept, toast 24 px — and
Hungarian).

**W2 acceptance** (plus §4.1, logged in §12 ✅): W2-A … W2-F reproduced; every delete undoable; keyboard-only meal logging.

**W2 web UI review focus:** all six frames; flows: add food by keyboard only (N → type → ↓ → Tab → 150 →
Enter), edit quantity to 166,7 and discard, delete a meal + undo + delete again and wait 6 s, copy two
meals from yesterday, create a food whose macros don't add up, log a recipe portion; EN pass for
"serving" / "left after this".

---

## W3 — Workouts · `Lifey Web 3 Workouts.dc.html` (W3-A … W3-F)

**Goal:** a readable weekly log, a finished session that reads like a summary, and a live logger with
timer, rest and records that ends in a celebration.

**Canvas notes = requirements:**

| Note | PDF ids | Requirement |
|---|---|---|
| Napló hetekre bontva, heti összesítővel | client-011 | Week groups with count, time, volume, distance in the header; type filter Mind / Erősítő / Cardio; every row has an icon; activity labels, not raw keys |
| Lezárt edzés = olvasható összefoglaló | fix2-001, fix2-003 | A closed session opens in a summary panel (time, volume, RPE, records, best set per exercise with ↑), editing is a separate button |
| Élő napló: időmérő, haladás, pihenő | extra2-005, live-001, live-002 | Focus mode without the sidebar: running time, set progress and Finish in the header; rest time is the hero (72 px) with ±15 s and skip; exercise list with state on the left |
| Szett-sorok, amelyekben a szám a fő | live-001, live-002 | Previous value kept; kg and reps in 18 px bold fields; a done set gets a green tint; ↑ and 🏆 in the row immediately |
| Befejezés: RPE, aztán ünneplés | live-003, finish-001, finish-002 | RPE step with the reason; then a celebration modal (trophy, time, volume, sets, records) instead of a toast |
| Cardio: a kiemelés a legjobbat jelenti | client-013 | Split chart with a pace Y axis and average line, the **fastest** km highlighted; HR zones as bars; route only with GPS data |
| Sablonválasztó információval | fix2-002, client-014, client-015 | Each template shows exercise count, estimated time, last used; the recommended one marked; empty workout possible; modal centred in both themes |
| Mobil élő napló | client-080 | 390: rest as a floating bottom panel, 44 px set fields, the next exercise collapsed |

**Current code:** `app/(app)/workouts/page.tsx` (51), `features/workouts/components/{SessionsView (248),
SessionLogger (284), TemplatesView (378), ExercisesView (269), CardioSessionDetail (206),
CardioSplitsTable, PaceBarChart (93), HrZonePanel (143), ElevationProfileChart, RouteSvg, WeatherCard,
BestEffortsCard, CalorieCard, TotalWorkCard, WaypointsList, WorkoutSuccessDialog (176),
PostWorkoutFeedbackDialog (105), RecommendedWorkoutCard, ActivityChip}.tsx`,
`features/workouts/{progress,recommendation,paceBarGeometry,hrZoneBreakdown,cardioTiles,…}.ts`.

**Target spec:**
- **Log (W3-A, grid `1fr | 440px`):** top bar "Edzések" (no date stepper); `Tabs` Edzések · Sablonok ·
  Gyakorlatok; actions "Cardio rögzítése" (secondary, `directions_run`) and "▶ Edzés indítása `N`"
  (primary); chips Mind · Erősítő · Cardio. Week groups: "Ez a hét · szept. 22–27." with "4 edzés · 3 ó
  12 p · 19 360 kg · 20 km"; rows grid `40 | 1fr | auto | 90`: tinted icon (strength primary, cardio
  heart), name + "🏆 PR", meta "5 gyakorlat · 18 szett · 52 perc" / "30:10 · 5:48 /km · 152 bpm", main
  value right ("6 240 kg", "5,2 km"), day "P · szept. 26."; selected row `--nested` + 3 px primary bar.
- **Summary panel (W3-A right, 440):** "péntek, szept. 26. · 17:40–18:32", "Push nap" + "⋯"; three stats
  Idő 52 perc · Volumen 6 240 kg · RPE 7 / 10; record hero chip "🏆 Új rekord · Bench Press — 50 kg × 8 ·
  eddig 47,5 kg × 8"; exercises: name, "4 szett · 45 / 47,5 / 50 / 50 kg × 8", best set right with ↑ when
  it beat last time; "↻ Ismétlés ma" (tonal: starts a session from the same template) + "✎ Szerkesztés"
  (opens the logger in edit mode). Trainer comments (existing) show under the header. At < 1280 the panel
  is a `Drawer`; at 390 a full page.
- **Live logger (W3-B, focus mode — route `/workouts/session/[id]`, `chrome: "focus"`):** header "×"
  (leave, asks when unsaved sets exist), "Láb + core", "9 / 18 szett · 2 / 6 gyakorlat", elapsed **24:18**
  (from `startedAt`, tabular), "⚑ Befejezés" (primary). Columns `280 | 1fr | 340`:
  left exercise list with state dots (done ✓ protein tint, current ▶ primary, next ○) + "＋ Gyakorlat
  hozzáadása"; centre the current exercise card: "Guggolás", "4 × 8 · pihenő 2:00 · legjobb eddig
  60 kg × 8", "⋯", set table grid `56 | 1fr | 120 | 120 | 56` (Szett · Előző · kg · Ismétlés · ✓), rows:
  number chip, "57,5 kg × 8", kg and reps `NumberField`s 18/800, 🏆/↑ inline, check button; done rows
  get the protein tint and a ✓; "+ Szett", "Megjegyzés" (only if the session has a notes field — else
  omitted); the next exercise collapsed ("Román felhúzás · Következő · 3 × 10 · legutóbb 45 kg × 10");
  right the **rest hero**: "PIHENŐ", **1:12** (72/800), "a 2:00-ból · utána 4. szett", "−15 mp", "+15 mp",
  "Kihagyás", a draining bar; below "Eddig ma": Volumen 3 420 kg, Rekord 1 🏆. Footer hint "Tab a
  következő mező · Enter szett kész · Space pihenő szünet · ↑/↓ ±2,5 kg".
- **Finish (W3-C):** `Modal` 480 "Milyen nehéz volt?" + "Az edződ ebből látja, mikor emeljen a
  terhelésen.", 10 RPE chips (7 selected: "7 · Kemény, de ment"), "Kihagyás" + "Tovább"; then the
  celebration `Modal`: 🏆, "Kész a Láb + core!", "Két új rekord. Ez volt a héten a 4. edzésed.", three
  stats (51 perc · 7 480 kg volumen · 18 szett), record rows "🏆 Guggolás 62,5 kg × 8", "Összefoglaló"
  (→ summary panel) + "Kész"; 1.2 s stagger, trophy pops once, static under reduced motion.
- **Cardio summary (W3-D, 1024 light):** back arrow, "Futás", "csütörtök, szept. 25. · 07:10", "⋯"; hero
  card r30 with four stats (Táv 5,2 km · Idő 30:10 · Átlagtempó 5:48 /km · Átlagpulzus 152 bpm); a
  `1.4fr | 1fr` row: "Kilométerenként · leggyorsabb 5:32 · 3. km" pace bars (taller = faster, Y axis
  5:30 / 6:00 / 6:30, dashed average 5:48, fastest bar full heart colour, others 35 %, the last partial
  km proportional "0,2") and "Pulzuszónák" (Z1–Z5 rows `72 | bar | 48`, % and time); footnote about the
  route map appearing only with GPS points. Existing extra cards (weather, best efforts, elevation,
  waypoints, splits table) stay below, restyled.
- **Mobile logger (W3-E):** header "×", name, "9 / 18 szett", 24:18; set rows `28 | 1fr | 76 | 60 | 44`
  with 44 px fields; the rest as a floating bottom panel above the safe area ("PIHENŐ 1:12", "+15",
  "Kihagy").
- **Template picker (W3-F):** `Modal` "Edzés indítása": template tiles (icon, name + "Javasolt" chip,
  "6 gyakorlat · kb. 50 perc", "5 napja"), selected = tint + 2 px primary ring; "Üres edzés sablon nélkül
  · Indítás". The **Sablonok** tab uses the same tiles as a list with the selected template in a right
  panel (drag reorder + set stepper kept — `client-015`); with nothing selected the panel shows
  template usage over the last 4 weeks.

**Data:** PRs from W1.9; week groups from W3.2; rest from `Exercise.restSeconds` → `settings.
defaultRestSeconds` (respect `restTimerEnabled`); RPE is the existing post-workout feedback field;
"Ismétlés ma" = the existing start-from-template call.

### W3.1 — Web UI: workouts header, tabs, type filter ✅
- Files: `app/(app)/workouts/page.tsx`, `lib/hooks/useUiStore.ts` (`workoutsTab` → URL `?tab=`).
- **Verify:** tabs deep-link; `N` opens the template picker.

*As built:* the workouts page has its W3-A header. The tab lives in the URL (`workoutsTab.ts`: `?tab=templates`,
`?tab=exercises`, sessions is the bare route; unknown values fall back to sessions) exactly like nutrition's, so
`workoutsTab` left `useUiStore` and the dashboard's "pick a template" link is `/workouts?tab=templates`; the
`?start=` / `?open=` deep links still land on the sessions tab. From 768 px: the `Tabs` underline row with
"Edzés indítása `N`" (primary) to the right; under 768 px the tabs are a full-width `SegmentedControl` and the start
action is the FAB ("＋ Edzés"). Below the tabs, on the sessions tab, the type chips **Mind · Erősítő · Cardio**
(`aria-pressed`; `matchesTypeFilter`: strength = everything that is not cardio, so sessions from before the kind
column still show) filter the list, with an empty state when a type has no sessions. The page now owns the
start-dialog state — `SessionsView` shows the dialog and lost its own "Edzés indítása" button — so `N` (and the
FAB) open it from any tab (from templates/exercises it first switches to sessions); W3.5 replaces the dialog with the
template picker. **Deviation:** the plan's secondary "Cardio rögzítése" button is *not* built — the web has no
cardio-recording flow (docs/cardio/58 D-W.2: the web reads, never edits cardio), so the button would be dead.
Verified on the real app (demo account): `?tab=exercises` selects Gyakorlatok, `N` there switches to Edzések
and opens the start dialog, the chips split 31 sessions into 12 cardio + 19 strength, no sideways scroll; unit tests
for the tab parsing, the href round trip and the filter.

### W3.2 — Web data: week grouping + week summary ✅
- Files: `features/workouts/sessionGroups.ts` + test — port of `mobile/lib/features/workouts/domain/
  {session_groups,week_summary}.dart` (Monday weeks; count, moving time, volume, distance).
- **Verify:** the mobile test cases; a week spanning a month boundary.

*As built:* `features/workouts/sessionGroups.ts` ports the mobile `session_groups.dart` + `week_summary.dart`: `weekStartFor` (local-midnight Monday), `groupSessionsByWeek(sessions, now)` → one `SessionWeek` per calendar week (`thisWeek` / `lastWeek` / `olderWeek`, `weekStart`, `weekEnd` = Sunday for the "szept. 22–27." label, the sessions in input order, empty weeks never returned) and `summarizeSessions` → count, seconds, volume kg, distance m. **Web differs from the phone** in one place: no separate "Today" group — the web list is one group per week, as W3-A shows. Rules kept from the mobile summary: a session counts when it *started* in the week, finished or not; time is the finished sessions effective duration (`movingSeconds`, else finished − started; a running session adds 0); distance is DISTANCE and MACHINE cardio only (a football match distance is not comparable). Volume is Σ weight × reps. `sessionGroups.test.ts` (8 tests): the mobile group cases (order, Sunday/Monday edge, year boundary, empty), a week spanning a month boundary (Mon 28 Sep – Sun 4 Oct stays one group with the right range), and the summary rules. Pure data — nothing renders it until W3.3, so no browser check.

### W3.3 — Web UI: week-grouped session list ✅
- Files: `features/workouts/components/{SessionsView,SessionRow,WeekHeader}.tsx`.
- **Verify:** W3-A left column side by side; PR chips; `CYCLING` → "Kerékpározás".

*As built:* the sessions list is one card per calendar week (W3.2's `groupSessionsByWeek`) under a `WeekHeader` — "Múlt hét · szept. 21–27." left, "6 edzés · 3 ó 32 p · 18 383 kg · 16,2 km" right; the current and previous week are named, older weeks show only their dates ("aug. 31. – szept. 6." across a month), and a part with nothing in it (no lifting, no distance) is left out instead of "0 kg" (`weekLabels.ts`, tested in both languages). `SessionRow` replaces the inline row: grid `40 | 1fr | auto | 90` with the tinted 40 px icon (strength primary, cardio heart, the activity's own icon — `CYCLING` reads "Kerékpározás"), the name, the "🏆 PR" `RecordChip` and "Folyamatban" chip, the meta line ("4 gyakorlat · 12 szett · 40 p" / the existing cardio summary line + avg heart rate), the main value right (volume "6 342 kg", distance "6,2 km", else the time) and the day ("P · szept. 25."); a selected row is `--nested` with a 3 px primary bar (the prop is ready for W3.4's panel). **PR chips** come from `recordsBySession` over the *whole* history, not the filtered list, so a type filter never changes what counts as a record. Under 768 px the day column folds into the meta line so the name keeps its width (55 px → 205 px measured at 390) and the hover-only delete button is hidden there (W3.4's panel gets the ⋯ menu). Two bugs found on the real app: a session under a minute showed "0 p" (now nothing), and Hungarian drops the thousands space on four digits ("6342 kg") — `formatKg` forces grouping. Verified on the demo account at 1440 and 390: week headers and sums, 18 PR chips, no sideways scroll.

### W3.4 — Web UI: closed-session summary panel ✅
- Files: `features/workouts/components/SessionSummary.tsx`; `SessionsView` opens it instead of the logger.
- Behaviour change (called out): a finished session no longer opens editable.
- **Verify:** best set ↑ vs the previous session (`progress.ts`); "Szerkesztés" still reaches the editor;
  drawer at 1024.

*As built:* a finished strength session now opens as its summary, not the editor (the called-out behaviour change). `SessionsView` keeps two ids — `selectedId` (the summary) and `activeId` (the editor / cardio detail): a finished strength row selects, a still-running one goes back to its logger, cardio to its detail (W3.10 redesigns that), and `?open=` deep links follow the same rule. From 1280 px the page is the W3-A grid `1fr | 440px` with the panel sticky on the right (a placeholder card until something is selected, the row gets `--nested` + the 3 px bar); below 1280 px it is a 480 `Drawer` (a sheet at 390). `SessionSummary.tsx`: "péntek, szept. 25. · 17:30–18:10", the name, "⋯" (delete, with a `ConfirmModal`), the trainer comment under the header when there is one, three stats (Idő · Volumen · RPE 9 / 10, "—" for what is missing), the **record hero** ("🏆 Új rekord · Deadlift — 68,5 kg × 10 · eddig 64,1 kg × 12"), each exercise with its set line ("3 szett · 66 / 66 / 68,5 kg × 8" when the reps match, "36×12 / 36×8 kg" when not), its best set on the right and a green ↑ when that set beat the previous session's best (same template first — `progress.previousSets`), then "↻ Ismétlés ma" (tonal; starts a session from the same template, or the same exercises when there was none) and "✎ Szerkesztés" (the editor, with its existing "Vissza az előzményekhez"). The data is `sessionSummary.ts` (8 tests): records are judged against finished strength sessions that started *before* this one, so a later session never hides an earlier record; climbing within a first session counts like the list's PR chip (same `detectPrs` definition) and then has no "eddig" line. Verified on the demo account at 1440 (panel 440 px wide, placeholder → summary, selected row, Szerkesztés → logger) and 1024 (drawer 480, Esc closes, a session with no sets says so). Not run against the real app: "Ismétlés ma" (it would create a session) and the delete confirm.

### W3.5 — Web UI: template picker modal ✅
- Files: `features/workouts/components/TemplatePicker.tsx`, `recommendation.ts`.
- **Verify:** recommended marked; empty workout starts; centred in light and dark (`fix2-003/004`).

*As built:* the hand-rolled start dialog (a dark-scrim div with plain buttons) is gone; "Edzés indítása" / `N` / the FAB open `TemplatePicker.tsx` on the DS `Modal` (480, centred in both themes, a bottom sheet under 768 px). One tile per template: a tinted `list_alt` icon, the name, a "Javasolt" chip on the recommended one, "4 gyakorlat · kb. 40 perc" and "7 napja" / "ma" / "még nem volt" on the right; the recommended template is listed first and preselected (else the first tile), the selection is the primary tint with a 2 px inset primary ring (`role=radio` tiles, double-click or Enter starts it), "Üres edzés sablon nélkül" (ghost) starts an empty workout and "▶ Indítás" the selected template; no templates → only the empty workout and the existing hint. The numbers come from `templatePicker.ts` (7 tests) on top of W1.4's `summarizeTemplate` — the estimate is the template's median past duration, else 8 minutes an exercise, rounded to 5 — and the last-used day count compares local calendar midnights, so it is right across a DST change (25 Oct) and a month boundary. Verified on the demo account at 1440: the modal's centre is exactly the viewport's (720, 450), six tiles, "Pull nap · Javasolt" first and selected, picking another moves the selection; at 390 it is the sheet with no sideways scroll. Not clicked: "Indítás" (it would create a session). **Gap:** the light-theme check of `fix2-003/004` was not possible here — the pane's colour-scheme emulation does not flip the app's theme — so the modal's `--modal-bg` in light is covered only by the W0 modal spec; the W3 review pass must look at it.

### W3.6 — Web UI: live logger focus-mode frame ✅
- Files: `app/(app)/workouts/session/[id]/page.tsx`, `features/workouts/components/live/{LiveHeader,
  ExerciseRail,ElapsedTimer}.tsx`, `routeChrome.ts` (`focus`).
- **Verify:** no sidebar/top bar; timer survives reload (derived from `startedAt`); leaving with
  unsaved sets asks.

*As built:* the set logger is its own route, `/workouts/session/[id]`, and it is the first `chrome: "focus"` page: `routeChrome` gained `chrome: "standard" | "focus"` (prefix `/workouts/session/`, so `/workouts` stays standard; 1 new test) and `AppShell` renders focus routes as a bare window — no sidebar, top bar, bottom nav or shortcut help, and the `G`-chord hotkeys are suppressed. Every way into a strength session now goes there: starting one (picker, dashboard `?start=`, "Ismétlés ma"), "Szerkesztés" in the summary, a still-running row; cardio keeps its detail view on the workouts page. The old `SessionLogger.tsx` is deleted — its draft / save / finish logic moved to `live/LiveSession.tsx` unchanged (RPE dialog and success dialog stay until W3.9), its set table to `live/ExerciseCard.tsx` (one exercise at a time, rebuilt in W3.7). **Header** (`LiveHeader`): "×", the name with "12 / 16 szett · 4 / 4 gyakorlat", the clock, "Mentés" (secondary) and the primary "⚑ Befejezés" — a finished workout reopened for editing shows "✓ Mentés" there instead. **Clock** (`ElapsedTimer`): `elapsedSeconds(startedAt, finishedAt, now)` is a pure function of the timestamps, re-read every second and on `visibilitychange`, so a reload or a throttled tab cannot drift it and a finished session stops at its own length (measured on the real app: 0:02 at start, 0:11 after a reload, 0:14 three seconds later). **Rail** (`ExerciseRail`, `liveSession.ts`: 14 tests): done ✓ in the protein tint, current ▶ with the primary ring, next ○, each with "3 / 3"; under 1024 px it lies down as a horizontal strip. **Leaving**: "×" or a reload/close asks ("Kilépsz mentetlen szettekkel?" · Maradok / Kilépés mentés nélkül, plus `beforeunload`) when the drafts differ from what the server has (`hasUnsavedSets` compares exercise · weight · reps, order-free, ignoring undone and zero-rep rows); a clean session leaves straight away. Verified on the demo account at 1440: no sidebar, the header and rail above on a finished session, adding a set then "×" shows the confirm and "Maradok" stays, discarding lands on `/workouts` with the chrome back; a workout started from the picker opens in focus mode with "0 / 12 szett · 0 / 4 gyakorlat" and a running clock (the test session was deleted afterwards). **Deviations / open:** "＋ Gyakorlat hozzáadása" is not built — the old logger never could add an exercise either, so it needs an exercise picker of its own (proposed for W3.7); the centre and right columns are the old table and nothing yet (`280 | 1fr`; the 340 px rest hero is W3.8); the mobile shape is W3.13.

### W3.7 — Web UI: set rows + PR marks + keyboard ✅
- Files: `features/workouts/components/live/{ExerciseCard,SetRow}.tsx` (replaces `SessionLogger.tsx`
  internals), `personalRecords.ts`.
- **Verify:** `setRowKeyboard` e2e on the gallery demo (Tab/Enter/↑↓); 🏆 appears the moment a record set
  is marked done; done tint 250 ms.

*As built:* the set table is now `SetRow` (W3-B, live-001/002) inside an `ExerciseCard` that shows one exercise at a time. The grid is `56 | 1fr | 120 | 120 | 56 | 32` — the number chip, the previous session ("57,5 kg × 8"), kg and reps as 18/800 `NumberField`s (the −/+ steppers are hidden: ↑/↓ step the weight 2,5 kg and the reps 1, `selectOnFocus`), 🏆 or ↑ in the row, the check, remove. A done row takes the protein tint with a 250 ms transition. The card header reads "4 × 10 · legjobb eddig 36,9 kg × 10"; under it the next exercise is a collapsed tile ("Következő") and the footer hint lists the keys. **Behaviour change (called out):** a new row starts *undone* — ticking it is what logs the set — and a running workout opens with one prefilled undone row per planned set (`seedDrafts`: the previous session's value for that row, else the row above), so usually only the check is left to do; a finished workout being edited gets no extra rows. **Marks** (`rowMarks`): a done row is judged against the exercise's history before this session plus the done rows above it, so 🏆 appears the moment the set is ticked (same `detectPrs` definition as the list chip and the summary); ↑ shows only when it beats the same row last time and is not already a record. **Keyboard:** Tab moves between fields, Enter in kg or reps commits, ticks the row and focuses the next row's kg field, on the last row it adds a set first. Tests: `liveSession.test.ts` grew to 21 (marks, seeding), and `e2e/ds/setRows.spec.ts` (7, on the new gallery section "Live logger set rows") drives the whole path — 18 px / 800 fields, Enter → next row, Enter on the last row adds and focuses, typed values kept, ↑/↓ steps, 🏆 vs ↑, done tint. Verified on the real app at 1440 (a finished workout in edit mode): fields 96 px wide at 18 px, 🏆 on the row that set a record, no sideways scroll. Not done here: Space pauses rest (W3.8 owns the rest timer).

### W3.8 — Web UI: rest hero panel ✅
- Files: `features/workouts/components/live/{RestHero,useRestTimer}.ts(x)` + `restTimer.test.ts`.
- Starts when a set is done; ±15 s; Space pauses; the last 5 s turn `--m-kcal` and pulse (static under
  reduced motion); `restTimerEnabled = false` → panel shows only "Eddig ma".
- **Verify:** unit tests (derived from timestamps, not intervals — survives tab throttling).

*As built:* the right column of the live logger (340 px from 1280, under the card from 1024, full width below) is `RestHero` — "PIHENŐ", the remaining time as the hero (72/800, `role=timer`), "a 1:30-ból · utána 2. szett", −15 mp / +15 mp / Szünet / Kihagyás, a draining bar — and below it "EDDIG MA" with the volume and the record count so far (every done row; records counted with the same `rowMarks`). **The countdown is a pure state machine** (`restTimer.ts`, 14 tests): a running timer stores the moment it ends, a paused one the milliseconds it had left, so the display is a function of `now` — a throttled tab or a late read gives the right number; `useRestTimer` only re-reads the clock four times a second and on `visibilitychange`. ±15 s moves the end (never below 0) and grows the "of" total when it passes it so the bar never overshoots; Space pauses / resumes (ignored while typing, on a button or under a modal); the last five seconds turn `--m-kcal` and pulse (`.rest-urgent`, off under the OS setting and the gallery's forced reduced motion); at zero it says "Mehet a következő szett". **It starts when a set is ticked** (not when an already-done row is edited, not in a finished workout being edited) for the exercise's own rest, else `settings.defaultRestSeconds`, else 90 s (clamped 5 s – 15 min); `restTimerEnabled = false` hides the rest card and leaves "Eddig ma". **Data finding:** the plan says `Exercise.restSeconds`, the field is `Exercise.defaultRestSeconds` — the web types now have it (and `settings.restTimerEnabled` / `defaultRestSeconds`). That also fixed a latent bug: the web exercise editor sent a PUT without it, which **cleared an exercise's rest time set on the phone**; it now sends it back untouched (W3.12 adds the field to the editor). Verified on the real app (throwaway workout, deleted afterwards): idle card, ticking a set starts 1:30 with "utána 2. szett", 1:30 → 1:28 after two seconds, Space freezes it at 1:28 for two more seconds, "Eddig ma" volume follows the ticked set. Not exercised in the browser: ±15 / Kihagyás / the pulse (unit-tested / CSS only).

### W3.9 — Web UI: finish flow — RPE modal → celebration modal ✅
- Files: `features/workouts/components/finish/{RpeModal,CelebrationModal}.tsx`; delete
  `WorkoutSuccessDialog.tsx`, `PostWorkoutFeedbackDialog.tsx`, the `--success-*` / `--scrim-celebration`
  tokens and the confetti keyframes.
- **Verify:** skip RPE still finishes; records list matches the summary; reduced motion static.

*As built:* finishing a workout is now two DS modals instead of a hand-rolled dialog and a conditional confetti popup. **RpeModal** (`finish/RpeModal.tsx`, `Modal` 480): "Milyen nehéz volt?" + "Az edződ ebből látja, mikor emeljen a terhelésen.", ten 44 px RPE chips (`role=radio`), the picked one named underneath ("7 · Kemény, de ment" — ten level names in both languages), the optional note kept, "Kihagyás" (still finishes the workout) and "Tovább" (needs a number); from a finished workout it changes the saved rating. **CelebrationModal** (`finish/CelebrationModal.tsx`): 🏆, "Kész a Pull nap!", "Szép munka. / Egy új rekord. / 2 új rekord. Ez volt a héten a 4. edzésed." (ICU plural, =0 / =1 / other), Idő · Volumen · Szett, one gold row per record ("🏆 Guggolás 62,5 kg × 8"), "Összefoglaló" (opens the summary panel via `/workouts?open=<id>`) and "Kész". **It is always shown when a workout is finished** — the old popup only appeared when at least two metrics beat last time, and the "Workout finished" toast is gone. The numbers come from `finishSummary.ts` (4 tests), which builds the finished session from the ticked drafts and runs it through `summarizeSession` — so the modal's records and the summary panel's agree by construction — and counts the week's workouts including this one once (DST-safe window). **Motion:** the trophy pops once (`.celebrate-trophy`, 600 ms) and the stagger is `--dur-celebrate` × a per-item fraction (`.celebrate-in`, 0 → 0.75 of 1.2 s), so both the OS reduced-motion setting and the gallery's forced toggle (which zero `--dur-celebrate`) make it static. **Deleted:** `WorkoutSuccessDialog.tsx`, `PostWorkoutFeedbackDialog.tsx`, the `--success-*` and `--scrim-celebration` tokens (both themes), `dialogEnter` / `.workout-success-card`, the confetti keyframes, `computeWorkoutProgress` / `isWorkoutSuccess` and their tests (only the old popup used them; `previousSets` and `delta` stay), and nine i18n keys per language. Verified on the real app with a throwaway workout (deleted afterwards): Befejezés → the RPE modal, picking 7 shows "7 · Kemény, de ment", Tovább → the celebration (title, subtitle, Idő / Volumen / Szett, the trophy animation running, 0.4 s fades) → Összefoglaló lands on `/workouts` with the summary panel showing "RPE 7 / 10". Not seen in the browser: a celebration *with* record rows (the demo data gave none for one easy set; the rows are covered by `finishSummary.test.ts`) and the reduced-motion pass — both for the W3 review.

### W3.10 — Web UI: cardio summary ✅
- Files: `features/workouts/components/{CardioSessionDetail,PaceBarChart,HrZonePanel,CardioSplitsTable,
  ElevationProfileChart,WeatherCard,BestEffortsCard}.tsx`, `paceBarGeometry.ts` (fastest highlight,
  proportional last km — test).
- **Verify:** W3-D side by side at 1024 light; fastest (not slowest) km highlighted; zone percentages sum
  to 100 (`hrZoneBreakdown.ts` largest remainder).

*As built:* the cardio summary (W3-D, client-013) leads with a hero card and a chart row. `CardioSessionDetail` for DISTANCE sessions: the session header as a DS `Card` (icon, "Futás", the date, the RPE chip, "Csak olvasható"), then a `Card variant="hero"` with four 28/800 stats — **Távolság · Időtartam · Átlagtempó · Átlagpulzus** ("6,20 km · 38:07 · 6:09 /km · 151 bpm"; a stat the session cannot supply is left out) — then a `1.4fr | 1fr` row: the pace chart and the heart-rate zones; the old tile grid keeps only what the hero does not say (elevation, peak altitude, backpack, GAP), a line under the splits explains that the route map appears only with GPS points, and the existing extra cards (best efforts, weather, route, elevation profile, waypoints, splits table) stay below. Other families keep their tiles. **Pace chart** (`PaceBarChart`, now a `Card`): "Kilométerenként · leggyorsabb 5:24 · 2. km", a Y axis with the 30 s marks inside the range (5:30 / 6:00 / 6:30, thinned to three), the dashed average line labelled with its pace, the **fastest** kilometre (the smallest duration — taller = faster) in full `--heart` and the others at 35 %, and the last partial kilometre **proportional**: `PaceBarGeometry` now takes the split's `distanceMeters` and draws the tail at an average kilometre's height × its share of a kilometre (200 m → a fifth, never below a 6 % sliver), labelled "0,2"; without a known length it keeps the old flat stub. The tail's own short duration still never enters the scale (existing tests unchanged, 8 new ones for proportion and `axisTicks`). **HR zones:** rows are `72 | bar | 48` with the zone chip + name, the bar, and "34 %" over the time; the percentages now come from `wholePercents` — largest-remainder rounding — so they add up to exactly 100 (the old per-row `Math.round` could show 99 or 101; 5 tests incl. thirds → 34/33/33). Verified on the demo account at 1440 (hero four stats, six bars with exactly one fastest, fastest label "5:24 · 2. km", average "5:43", zones 9/34/34/20/3 = 100, `1.4fr | 1fr` columns, the no-GPS note, no sideways scroll) and at 390 after a reload (hero 2 × 2, single column, nothing overflows). **Open:** the demo data has no partial tail and no GPS route, so the proportional "0,2" bar and the with-GPS route layout were checked only by the geometry tests; the light-theme side-by-side with W3-D is for the W3 review. Noticed in the seed data, not a bug here: the chart's mean of the km splits (5:43) differs from the hero's overall pace (6:09) because the seeded splits do not add up to the session's time.

### W3.11 — Web UI: templates tab list + editor panel ✅
- Files: `features/workouts/components/TemplatesView.tsx` (+ `TemplateEditorPanel.tsx`, dnd-kit kept).
- **Verify:** drag reorder + set stepper work by mouse and keyboard; 4-week usage when nothing is selected.

*As built:* the Templates tab now uses the picker's tiles. `TemplateTile` (shared with `TemplatePicker`, which lost its own markup): the tinted icon, the name with "Javasolt", "4 gyakorlat · kb. 40 perc", "5 napja" — selected = primary tint + the 2 px ring (`aria-current` in the list, `role=radio` in the picker). The list keeps the templates' own order (`pickerTemplates(…, recommendedFirst = false)`); a row's duplicate / schedule / assign actions sit under its tile with the same `data-testid`s the trainer specs use (`template-row`, `assign-template`, `schedule-template`) — the trainer's own templates page embeds this same view. **Layout** as on the sessions tab: from 1280 px a `1fr | 440px` grid with a sticky panel, below it the editor is a 520 `Drawer` with the unsaved-changes guard (`isTemplateDirty`). **Nothing selected → usage:** "Az elmúlt 4 hét" lists every template with four small bars (one per Monday-based week, the current week last) and "4×" for the window (`templateUsage.ts`, 5 tests: week buckets, the exact four-week window, ordering, sessions without / with an unknown template). **Editor** (`TemplateEditorPanel`): DS `TextField` for the name, the exercise rows with the drag handle and the set stepper (DS `IconButton`s with "One set more / fewer" labels, never below 1), the search-and-add list, Save (needs a name and an exercise), and **Delete now asks first** (`ConfirmModal`) — it used to delete immediately. **Reorder works by mouse and keyboard:** dnd-kit's `KeyboardSensor` was missing, so the handle was mouse-only; with it Space lifts, ↑/↓ move, Space drops. Verified in a real browser by `e2e/ds/templateEditor.spec.ts` on the new gallery section "Template editor" (6 tests: rows, stepper floor, keyboard reorder, mouse reorder, remove + add, Save disabled) and on the demo account at 1440 (six tiles, the usage panel with 24 bars, selecting a tile opens the editor with its four exercises, the tile marked current). Notes: the keyboard test waits 300 ms after the arrow because dnd-kit measures the new target on the next frame; the old per-tile muscle-group chips are gone (the spec's tile has no place for them); the editor's rest-time field is not here — W3.12 adds it to the exercise editor.

### W3.12 — Web UI: exercises tab on `DataTable` ✅
- Files: `features/workouts/components/ExercisesView.tsx`.
- **Verify:** sort, search `/`, ⋯ menu; card rows at 390.

*As built:* the exercises tab is the foods tab's twin. `ExercisesView` renders the DS `DataTable` — columns **Gyakorlat** (a 32 px tile in the muscle group's metric colour + the name), **Kategória** (tinted chip), **Eszköz**, **Pihenő** ("2:00", or "alapértelmezett" in grey), all four sortable (no own rest sorts below every set one, no muscle group / equipment last), the search box focused by `/` (accent- and case-insensitive, reusing the foods table's matcher), muscle-group filter chips for the groups that exist, "＋ Új" and the `⋯` per row (Szerkesztés, Törlés…). Under 768 px every row is a card (name, "Mell · Súlyzórúd", the rest on the right). **Delete is now confirm → undoable:** `ConfirmModal`, then the row leaves the table and a toast offers Visszavonás for six seconds before the DELETE goes out (it used to be immediate). **Editor** (`ExerciseEditorPanel`): from 1280 px a 380 px sticky panel beside the table, below it a 480 `Drawer` with the discard guard; DS `TextField` / `TextArea` / `NumberField`, and a new DS **`SelectField`** (native `<select>` in the field shape with a chevron, `.lifey-field select` in `globals.css`) for muscle group and equipment. **New: the rest time.** "Pihenő egy szett után" (seconds, 15 s steps, 0 = the Settings default, "Az alapértelmezett" resets it) writes `Exercise.defaultRestSeconds`, which W3.8's rest timer reads — W3.8 already stopped the web editor from wiping it, now it can be set. `exerciseRequest` always sends it back (`exerciseEditor.test.ts`, 7 tests: the wire body, trimming, dirty detection; `exerciseUi.test.ts`, 4: rest formatting, colours, icons). Shared pieces moved to `exerciseUi.ts` (`muscleGroupColor`, `exerciseIcon`, `formatRest`). Verified on the demo account at 1440 (headers, sortable, search, the editor opening at 380 px with two selects and the rest field, 44 px fields) and at 390 (cards, nothing overflows). **Not exercised in the browser:** saving a rest value (the test harness fills the field without the blur that commits a `NumberField`, so it saved without one — the request shape is unit-tested instead), the delete toast / undo, and sorting clicks. The demo data has no muscle groups or equipment, so the chips and the chip column were only seen empty.

### W3.13 — Web UI: live logger at 390 ✅
- Files: the `live/` components' mobile variants.
- **Verify:** W3-E side by side; 44 px targets; the rest panel never covers the active row's fields.

*As built:* the live logger has its phone shape (W3-E, client-080), all from the existing components' responsive variants. **Set rows** use `28 | 1fr | 76 | 60 | 44` under 768 px (`SET_GRID_CLASS`, shared by the column header and every row; the desktop `56 | 1fr | 120 | 120 | 56 | 32` from 768): the number chip is 28 px, kg and reps are 44 px tall 18/800 fields (76 and 60 wide, steppers hidden), the check is a 44 px button, and the remove cross is left to the desktop row. **Rest** becomes a floating panel over the bottom, 12 px above the safe area (`RestHero` under 768 px): "PIHENŐ 1:30", +15, pause, "Kihagy" and a 4 px draining bar, with the same timer state as the desktop card (the last five seconds still turn `--m-kcal`); "Eddig ma" stays in the page. **It never covers the work:** while a rest runs the page gets `pb-32`, and every set row has `scroll-margin-bottom`, so the last row and a focused field scroll clear of the panel (measured: last row bottom 441, panel top 988 at the bottom of the page). **Header** is one compact line — "×", name, "0 / 12 szett", the clock at 16 px, a save icon and "⚑ Befejezés" — and the next exercise stays a collapsed tile under the card. The page padding is 12 px instead of 24. Verified on the real app at 390 (throwaway workout, deleted afterwards): grid `28px 1fr 76px 60px 44px`, field height 44, widths 76 / 60, check 44, remove hidden, no sideways scroll, ticking a set raised the floating panel 12 px above the bottom with "PIHENŐ | 1:30 | +15 | pause | Kihagy". **Open:** the header measured 75 px because the name and the "Befejezés" label wrap on the narrowest width — acceptable, but worth a look in the review; the soft keyboard (the viewport shrinking under a focused field) cannot be exercised in this pane, so "the rest panel never covers the active row's fields" is shown by the measured clearance and the scroll margin, not with a real keyboard.

**W3 acceptance** (plus §4.1, logged in §12 ✅): W3-A … W3-F reproduced; a strength session from start to celebration
without a mouse.

**W3 web UI review focus:** all six frames; flows: start from the picker, log 4 sets with a record by
keyboard, adjust and skip rest, finish with RPE → celebration → summary, reopen from the list (summary,
not editor), "Ismétlés ma", open a cardio session with and without GPS; reduced-motion pass of the
celebration.

---

## W4 — Weight, Water, Steps · `Lifey Web 4 Weight Water Steps.dc.html` (W4-A … W4-D)

**Goal:** each metric page = one hero number, the goal always visible, the trend instead of the noise.

**Canvas notes = requirements:**

| Note | PDF ids | Requirement |
|---|---|---|
| A cél mindig látszik | client-018 | Hero with the 72 px current weight, start and goal on a band, kg left and the projected date from the trend; dashed goal line on the chart |
| Trend a napi zaj helyett | client-018, client-019 | Measurements as faint dots, the **7-day average as the bold line** (matches docs/76 D-W3 — the mobile canvas's reverse question, 77 §10 Q4, doesn't arise); gaps not invented; Y axis 44 px with HU decimals; X "szept. 13."; today's point emphasised |
| Napló táblázatként, a diagram alatt | client-018 | Entries below the chart, full width: date, weight, change chip, ⋯; a loss is a green chip when the goal is to lose |
| Nagy számos rögzítés | client-020 | Drawer with a 72 px number, ± stepper, keyboard; Hungarian date picker, no native "09/27/2026" field |
| Víz: gyűrű, forrás-gombok, heti trend | client-021, client-022 | "1,6 / 2,5 L" HU format; big quick buttons per water source; today's entries deletable via ⋯; 14-day bars with a goal line |
| Lépések: egy szín, a cél jel | client-023, client-024 | All bars steps purple; "goal reached" = a check above the bar + dashed 9 000 line, no second colour; HU day names; today dashed; edit from the hero |
| Mobil | client-081, client-083 | Hero, range switcher, simplified curve (average + goal), short list, FAB to log; Water and Steps reached from "Több" |

**Current code:** `app/(app)/weight/page.tsx` (182), `app/(app)/water/page.tsx` (250),
`app/(app)/steps/page.tsx` (135), `features/{weight,water,steps}/{api,types}.ts`,
`components/data/{TimeSeriesChart,HeroMetricCard,WaterCard}.tsx`.

**Target spec:**
- **Weight (W4-A, 12 columns):** top-bar centre = range `SegmentedControl` **30 nap · 90 nap · 1 év · Mind**,
  right "＋ Súly rögzítése `N`". Hero span 4, r30, padding 28: date meta ("ma", D-W0.19 — no time),
  **69,6 kg** (`type-display-xl`), chips "−0,4 kg a héten" + "−2,4 kg aug. 18. óta" (goal-aware colour),
  a start → goal band "Kezdés 72 kg · Cél 65 kg" with the current position, "Még 4,6 kg · a mostani
  tempóval dec. közepére" (projection only when W1.6 allows it, else just "Még 4,6 kg"), two stats "7 napos
  átlag 69,8 kg" · "Tempó −0,42 kg / hét". Chart span 8: "Az elmúlt 30 nap", legend "mérés · 7 napos
  átlag · cél", `LifeyLineChart` (dots for measurements, bold average, dashed "cél 65 kg", Y "72 / 68,5 /
  65", X "aug. 29. · szept. 13. · ma"). Log table span 8 (below the chart): columns Dátum ("Péntek,
  szept. 26.") · Súly · Változás (`DeltaChip` vs the previous entry) · ⋯ (Törlés… — the API has no
  update; "Szerkesztés" = delete + create with the same date, done inside the drawer as one action).
  No note column (D-W0.19). The log drawer opens on the right (the canvas draws it in the span-4 slot).
- **Log-weight drawer:** "Súly rögzítése", − / **69,6 kg** / + (72 px, step 0,1; ↑/↓ ±0,1, Shift ±1, Enter
  saves), `DateButton` "Ma, szept. 27." (no time row), "Mentés"; hint "↑/↓ ±0,1 kg · Shift ±1 kg · Enter
  mentés". Prefilled with the last weight. Imperial users step 0,1 lb.
- **Water (W4-B, 1280 light, `1fr | 1fr`):** left hero: ring **64 %**, "1,6 / 2,5 L", "Még 0,9 L · kb. 4
  pohár" (glasses = remaining ÷ the most used source's volume, fallback 0,25 L), "Gyors hozzáadás" 4
  source tiles ("+0,25 L · Víz · pohár", …), "Vízforrások kezelése" (→ drawer with the existing sources
  CRUD). Right: "Mai bejegyzések" list (icon per source, "Tea · 14:10", "0,3 L", ⋯ → Törlés… with undo).
  Full width below: "Az elmúlt 14 nap", "átlag 2,2 L · cél teljesítve 6 / 13 nap", `LifeyBarChart` 14
  bars, met days full colour, others 45 %, dashed "cél 2,5 L", today dashed.
- **Steps (W4-C, 1280 light, `1fr | 0.5fr × 3`):** hero "Ma eddig" + "✎ Szerkesztés" (edits today's
  count in a small drawer), **6 412**, "Még 2 588 a 9 000-es célig · kb. 25 perc séta"; three stats
  "14 napos átlag 8 240" · "Cél teljesítve 6 / 13 nap" · "Legjobb nap 12 480 · szept. 21.". Chart "Az
  elmúlt 14 nap", legend "✓ cél elérve · 9 000", all bars steps purple, ✓ above met bars, dashed goal,
  Y "14 e / 7 e / 0", today dashed.
- **Mobile (W4-D):** hero (69,6 kg, chip, "Cél 65 kg · még 4,6 kg"), range segmented, simplified chart
  (average + goal only), last 3 entries, FAB "＋ Súly".

**Data:** all exists; trend from W1.6; "13 days" = the 14-day window without today.

### W4.1 — Web UI: weight hero ✅
- Files: `features/weight/components/WeightHero.tsx`, `app/(app)/weight/page.tsx`.
- **Verify:** no-goal account: no band, no "még"; first entry: no deltas, no average (§7).

*As built:* the weight page is on the 12-column `PageGrid` and leads with `WeightHero` (a `Card variant="hero"`, padding 28, span 4 from 1280 with the chart and — from W4.3 — the log beside it in span 8): the last weigh-in's relative date ("szept. 27."), **69,6 kg** at 72 px (`type-display-xl`), two goal-aware `DeltaChip`s — "−0,6 kg a héten" and "−2,4 kg aug. 18. óta" (green when the move is toward the goal, heart-coloured away from it, neutral without a goal) — the start → goal band ("Kezdés 72 kg · Cél 65 kg", whole numbers without ",0", a progress bar with the position dot, `role=progressbar`), "Még 4,6 kg · a mostani tempóval dec. végére" and two stats, "7 napos átlag 69,8 kg" · "Tempó −0,38 kg / hét". All numbers come from `weightHero.ts` (`buildWeightHero`, 10 tests) on top of W1.6's trend helpers, so the page and the dashboard tile name the same pace and date: the week delta is the latest weigh-in minus the newest one at least seven days older (null in the first week); the band position is `(start − latest) / (start − goal)` clamped 0…1 and works for a gaining goal too (null when start = goal); the goal comes from `userDetails.targetWeightKg` (a 404 before onboarding is "no goal"). **Edge cases (§7), each a test:** no goal → no band, no "még", no projection; a single entry → no deltas, no average, no pace; goal reached (within 0,2 kg) → "Cél elérve" with the band full; moving away → band 0; the date phrase only when the projection is on track ("elejére / közepére / végére" by thirds of the month, ICU `select`, English "at this pace mid Dec"). The old in-chart "current weight" header is gone (the hero is the number now); the chart and the history keep their W4.0 form until W4.2 / W4.3. Verified on the demo account (69,6 kg at 72 px; "−2,4 kg aug. 18. óta" is exactly the canvas' number; the band, "Még 4,6 kg · … dec. végére", 7-day average 69,8 kg, pace −0,38 kg / hét; no sideways scroll). **Plan correction:** the plan says the log drawer must replace an existing entry for that date because "the API allows one entry per date" — the backend has no such constraint (`POST /weights` always inserts, the list is ordered by date then recording time), so W4.4 handles a same-day entry as "replace after a confirm" on the client.

### W4.2 — Web UI: weight chart + range switcher ✅
- Files: `features/weight/components/WeightChart.tsx`, `routeChrome.ts` (range in the top-bar centre).
- **Verify:** gaps stay gaps; "1 év" uses weekly averages (`weeklyBuckets`); goal line inside the axis
  range or the axis extends to include it (unlike W5's week view, where it is noted in the header).

*As built:* the chart (`WeightChart`, a `Card` titled "Az elmúlt 30 nap / 90 nap / év", "Minden mérés") follows docs/76 D-W3: the **measurements are faint dots and the 7-day average is the bold line**. `LifeyLineChart` got two props — `emphasis="average"` (the raw line is hidden and each measurement is a 3 px dot at 40 %; the average line is solid, 3 px, full colour; the newest point keeps its card-coloured ring) and `threeXLabels` (first, middle and last label only: "szept. 1. · szept. 15. · ma", today's point labelled "ma") — and its Y ticks no longer round a half-way value, so the canvas' "72 / 68,5 / 65" reads "68,5" (whole numbers keep the compact form); the goal line "cél 65 kg" is dashed, lifted off the axis (`offset -16`) so it no longer collides with "ma", and the axis always extends to include the goal. **Series** (`weightSeries.ts`, 8 tests): 30 / 90 days are one point per *calendar day* with null where there is no weigh-in — gaps stay gaps, nothing is interpolated; **1 év** is weekly means (Monday weeks over 52 weeks, an empty week is a null) and draws no second average line, as does a long "Mind" (daily up to 120 days of history, weekly beyond). **Range switcher:** `30 nap · 90 nap · 1 év · Mind` (`SegmentedControl`) lives in the **top bar's centre** on desktop through a new `useTopBarCentre` slot (`useTopBarSlot.ts` + `TopBar`: a page-provided node wins over the date stepper and clears itself on unmount), and above the chart, full width, under 768 px where there is no top bar. Verified on the demo account with real Chromium (1440): the switcher in the top bar, 18 dots + the average line in 30 days, 25 dots in 90, weekly points in "1 év", the dashed goal inside the axis, Y "72 / 68,5 / 65", X "szept. 1. · szept. 15. · ma". The dashboard-era `TimeSeriesChart` adapter keeps the old look for the statistics page until W5.

### W4.3 — Web UI: weight log table ✅
- Files: `features/weight/components/WeightLogTable.tsx` (`DataTable`), undoable delete.
- **Verify:** change chip colours follow the goal direction (lose → down is green; gain → up is green;
  no goal → neutral).

*As built:* the history list beside the chart is now the log table below it, full width of the chart column (span 8 from 1280): `WeightLogTable` on the DS `DataTable` with **Dátum** ("Vasárnap, szept. 27." — weekday spelled out and capitalised, `logDateLabel`), **Súly** ("69,6 kg"), **Változás** (a `DeltaChip`: "↓ −0,2 kg") and one `⋯` per row; all three columns sort, ten rows a page, "24 bejegyzés" underneath, and under 768 px every row is a card (date, the signed change, the weight). `logTable.ts` (5 tests) builds the rows: newest first, each with its change against the previous entry *in time*, rounded to the one decimal the scale shows (69,8 → 69,6 is −0,2, never −0,19999), same-day entries ordered by id. **Change chips follow the goal direction** — lose-weight goal: a drop is the green `--improvement`, a rise the heart colour; gain: the mirror; no goal: neutral `--decrease` / `--increase` — and the first-ever entry shows "—". **Delete is confirm → undoable:** "Törlés…" → `ConfirmModal` ("Törlöd a(z) 69,6 kg bejegyzést?") → the row leaves the table and a toast offers Visszavonás; the `DELETE /weights/{id}` goes out only when the six-second window closes (the old × deleted immediately with no confirm). The "Szerkesztés" item arrives with the drawer in W4.4. No note column (D-W0.19). Verified with real Chromium on the demo account: the three sortable headers, the first rows ("Szombat, szept. 26. · 69,8 kg · ±0,0 kg", "Péntek, szept. 25. · 69,8 kg · ↑ +0,3 kg"), delete → the row is gone → Visszavonás → back, and **zero** `DELETE` requests both right after the undo and after waiting out the window. Not seen: a real delete that goes through (W4.4's flow test creates and removes a throwaway entry), the card rows at 390 (W4.7).

### W4.4 — Web UI: log-weight drawer ✅
- Files: `features/weight/components/LogWeightDrawer.tsx`.
- **Verify:** keyboard stepping, Enter saves, HU "69,6"; an existing entry for that date is replaced after
  a confirm (the API allows one entry per date — verify at the step and note it).

*As built:* "Súly rögzítése" is a drawer (`LogWeightDrawer`, 480, the DS `Drawer` with its discard guard): the weight as a **72 px number** between − and + (`WeightStepper`; type it, click the steppers, or ↑/↓ = 0,1 kg, Shift+↑/↓ = 1 kg, Enter saves), the hint "↑/↓ ±0,1 kg · Shift ±1 kg · Enter mentés", the date as the DS `DateButton` that opens the month grid (future days disabled, a dot under days that already have an entry — no native "09/27/2026" field and no time row), and "Mentés". It opens prefilled with the last weigh-in and focused on the number (`data-autofocus`); `N` and the page's "＋ Súly rögzítése" open it, a table row's new "Szerkesztés" opens it on that entry. The old inline add form is gone. `logWeight.ts` (10 tests) holds the rules: values are rounded to 0,1 kg and clamped to 20 … 500; **the API can only create and delete, so an edit is "create the new entry, then delete the old one" as one action** (create first, so a failure never leaves the day empty), and — because, as found in W4.1, the backend *does not* limit a day to one entry — saving onto a day that already has one **replaces it after a confirm** ("Erre a napra már van bejegyzés: 69,9 kg. A mentés felülírja." · Mégsem / Felülírás); editing onto another day with an entry removes both the edited entry and that day's. **Bug found by the flow test and fixed:** pressing Enter right after typing saved the *previous* value — Enter commits the text and saves in the same tick, and `save` read the not-yet-updated state; `onEnter` now hands over the committed value. Verified with real Chromium on the demo account, keyboard only: `N` → the drawer opens with "69,6" prefilled and the number focused → ↑↑↑ then Shift+↓ then Shift+↑ gives 69,9 (the arithmetic is tenth-exact) → Enter → a new row "Szerda, szept. 30. · 69,9 kg · +0,3 kg"; `N` again, type "70,2", Enter → the replace confirm → Felülírás → still one entry for the day, now 70,2; then ⋯ → Törlés… → confirm → after the undo window exactly the expected requests (`POST 69,9`, `POST 70,2`, `DELETE` of the replaced entry, `DELETE` of the last) and the log is back to its original 24 entries. **Not built:** imperial users' 0,1 lb step — the web has no unit switch anywhere (every weight is kg), so it stays with the phone; the drawer is a full-height sheet under 768 px via the DS `Drawer`, to be checked in W4.7.

### W4.5 — Web UI: water page ✅
- Files: `app/(app)/water/page.tsx`, `features/water/components/{WaterHero,WaterSourceTiles,
  WaterEntriesList,WaterSourcesDrawer,WaterTrendCard}.tsx`, `features/water/quickSources.ts` (W1.5).
- **Verify:** W4-B side by side; undo on an entry; sources drawer Esc/unsaved guard.

*As built:* the water page is the W4-B layout on the 12-column grid — hero left (span 6), "Mai bejegyzések" right (span 6), "Az elmúlt 14 nap" across the bottom — driven by the top bar's date stepper as before. **`WaterHero`**: the `ProgressRing` with "64 %" in it, "1,6 / 2,5 L", "Még 0,9 L · kb. 4 pohár" (the remaining litres in units of the **most used source's volume**, fallback 0,25 L — `containersLeft`, never 0 while something is left; "Cél elérve" at the goal), **four big tiles** ("＋0,25 L · Pohár") that log an entry on a tap — the user's four most used sources (`rankQuickSources` gained a `limit`-fill `defaults` argument; the page uses 0,25 / 0,5 / 0,33 / 1 L to top up, the dashboard tile keeps its two) — the old "egyéni mennyiség" as a `NumberField` + "Hozzáadás" (so nothing the old page could do is lost), and "Vízforrások kezelése". The add is still optimistic with a rollback. **`WaterEntriesList`**: newest first, a tinted icon per source (a cup for tea / coffee), "Tea · 14:10", "0,3 L", and a `⋯` with "Törlés…" → `ConfirmModal` → **undoable** (the old × deleted at once). **`WaterSourcesDrawer`** (also opened by `/water#sources`, the dashboard tile's menu): the saved sources — a click edits one (the API's PUT was unused on the web before), the bin removes one undoably, "＋" adds one — with the DS fields, and an Esc / scrim / × guard when the form is half filled ("Elveted a módosításokat?"). **`WaterTrendCard`** + `waterStats.ts` (`waterWindow`, 7 tests): 14 bars ending on the selected day — goal days in the DS past-bar colour, the others at **45 %** (new `dimmed` flag on `LifeyBarChart`), today a dashed outline, the dashed goal line, day-of-month X labels with "ma", "átlag 2,5 L · cél teljesítve 3 / 13 nap": **today is left out of both** (a half-drunk day neither drags the average nor counts as a miss; 13 complete days when today is in the window) and sums round to the millilitre so 0,1 + 0,2 meets a 0,3 goal. The chart got two small props for small-number metrics: `yFormat` and `yMax` — the default axis printed "0,0 / 2,05 / 4,1" for litres, it now reads "0 / 2,5 / 5" (whole litres on top). Verified with real Chromium on the demo account (1440): hero "0,0 / 2,5 L · 0 % · Még 2,5 L · kb. 3 pohár", the four tiles (Kulacs 0,75 · Pohár 0,25 · Bögre 0,3 · Palack 0,5 — the account's own sources, most used first), tap → `POST /water-entries` with the source id, the total 0,75 / 2,5 L and one entry; delete → Visszavonás → zero `DELETE`s; delete again and wait → exactly one `DELETE /water-entries/…`; the sources drawer lists the sources and its discard guard appears after typing a name and pressing Esc. **Note:** "kb. 3 pohár" says "glass" while the unit is the most-used source (a 0,75 L Kulacs here) — that is the plan's rule ("the most used source's volume"); the word stays "pohár".

### W4.6 — Web UI: steps page ✅
- Files: `app/(app)/steps/page.tsx`, `features/steps/components/{StepsHero,StepsStats,StepsTrendCard,
  EditStepsDrawer}.tsx`, `features/steps/stats.ts` + test (average, met days excluding today, best day).
- **Verify:** W4-C side by side; ✓ glyphs only above met bars; HU day letters.

*As built:* the steps page is the W4-C layout — `1fr | 0.5fr × 3` from 1280 (hero on top of three stats below that), "Az elmúlt 14 nap" under it — driven by the top bar's date stepper. **`StepsHero`**: "MA EDDIG" (the date on another day), **0 / 6 412** at 72 px, "Még 2 588 a 9 000-es célig · kb. 25 perc séta" or, at the goal, a ✓ and "Cél elérve · 9 000" in the *same* steps purple (no second colour), and "✎ Szerkesztés". **`StepsStats`**: "14 napos átlag 7 577", "Cél teljesítve 4 / 13 nap", "Legjobb nap 11 285 · szept. 25.". **`stats.ts`** (`stepsWindow`, 7 tests) is where the rules live: 14 days ending on the selected day; the average and the met-day tally **leave today out** (13 complete days when today is in the window — a half-walked day neither drags the average nor counts as a miss) and the average skips days with nothing recorded (no count is not a day of zero steps); the best day looks at the whole window, today included; exactly the goal counts as met. **`StepsTrendCard`**: all bars steps purple, the dashed goal line "9 000", today a dashed outline, HU weekday letters ("Cs P Szo V H K Sze … ma"), the legend "✓ cél elérve · 9 000", and a ✓ **only over complete days that met the goal** — today never claims one. **Chart bug found and fixed:** `LifeyBarChart`'s `metGoal` ✓ was an icon-font `<span>` inside the `<svg>`, which is never rendered — the glyph was invisible everywhere it was used; it is now an SVG circle with a check path (the capture shows four ✓ for the 4 / 13 met days). **`EditStepsDrawer`**: a small drawer with one `NumberField` (step 100, Enter saves, focused on open, the discard guard when changed) that creates or updates the day's count. **Platform fix (the same stale-closure bug W4.4 found, now fixed where it lives):** the DS `NumberField`'s `onEnter` now hands the caller the value it just committed — reading the parent's state in that tick saved the previous number; the water page's "egyéni mennyiség" Enter used to have the same bug and now uses it too. Verified with real Chromium on the demo account (1440): the hero, the three stats, the chart with its four ✓, then Szerkesztés → "12345" → Enter → `POST /steps` and the hero "12 345 · Cél elérve · 9 000", edited back to 0 (`PUT`) and the throwaway record removed — the account is as it was. Not built: the canvas' "Legjobb nap" as a link, and the FAB's behaviour at 390 is W4.7.

### W4.7 — Web UI: the three pages at 390 ✅
- Files: responsive variants; FAB per page (weight "＋ Súly", water "＋ Víz", steps "✎").
- **Verify:** W4-D side by side; Water and Steps via "Több".

*As built:* the three pages have their phone shape (W4-D, client-081/083), from the desktop components' own responsive variants. **Weight at 390:** the hero is the number at 56 px, this week's `DeltaChip` and one line "Cél 65 kg · még 4,6 kg" ("Cél elérve" at the goal) — the band, the second chip and the two stats stay on the desktop card; the range switcher is a full-width `SegmentedControl` above the chart (there is no top bar to hold it); the chart is the **simplified curve — the 7-day average and the dashed goal only** (`LifeyLineChart` got a `dots` prop; the legend drops "mérés" with the dots), 200 px tall; the log is a short list of the **last three** weigh-ins with "Minden bejegyzés (24)" for the rest; the FAB "＋ Súly" opens the log drawer (a sheet on a phone). **Water:** the custom-amount row stacked instead of spilling its "Hozzáadás" button off the screen (the page scrolled sideways inside `<main>`); the FAB "＋ Víz" is one tap — it logs the most used source, the first tile, and its `aria-label` says which ("Kulacs hozzáadása (0,75 L)"). **Steps:** the hero full width, then the three stats as a compact three-column row, the chart below with its ✓ marks, the FAB "✎ Lépés" opening the edit drawer. **Water and Steps stay behind "Több"** — the bottom bar holds the first four client destinations (Áttekintő, Táplálkozás, Edzések, Testsúly) and `CLIENT_MORE_SHEET_ITEMS` the rest, already so since W0.22. Verified with real Chromium at 390 × 844 on the demo account: none of the three pages scrolls sideways (document or `<main>`), and the captures show the compact weight hero with the average-only chart, the stacked water controls and the three-up steps stats with the ✓ bars. **Not exercised at 390:** the log and edit drawers as sheets and the water FAB's tap (the desktop flows cover their logic); the W4 review takes the soft-keyboard-free phone states through axe.

**W4 acceptance** (plus §4.1, logged in §12 ✅): W4-A … W4-D reproduced.

**W4 web UI review focus:** the four frames plus water/steps at 390 and weight at 1024; flows: log a
weight by keyboard, replace today's weight, delete + undo, switch 30 d → 1 év, quick-add each water
source, delete a drink + undo, edit today's steps; empty states for a fresh account (DS-05 weight
empty).

---

## W5 — Statistics · `Lifey Web 5 Statistics.dc.html` (W5-A … W5-D)

**Goal:** honest charts — goal, average, empty days and today's partial day handled separately.

**Canvas notes = requirements:**

| Note | PDF ids | Requirement |
|---|---|---|
| Oszlop, ahol az adat alkalmi | stats-001, stats-002 | Volume and cardio distance are **bar** charts: a value only on workout days, a rest day is a dot on the axis; no waves between 0 and peaks, no invented valleys (`type="linear"`, `connectNulls={false}`) |
| Cél, átlag, ma | stats-001 | Calories: dashed 1 900 goal and a dotted average; today dashed and excluded from the average; every chart has a legend |
| Tengelyek, amelyek elférnek | stats-001, onboarding-012 | Y axis 44 px, 3 labels, compact ("2,4 e"); no clipped "000" or "’0.5"; HU day names and dates |
| A delta színe a jelentést követi | stats-001 | Green = better toward the goal, orange = worse, grey = neutral; weight −0,4 kg green "javulás" when losing; a step decrease orange |
| Évnézet: heti átlag, üres időszak jelölve | stats-003 | Weekly averages; months before logging started get a hatched "Még nem naplóztál" band; no "+1659" against an empty previous year — "Nincs előző évi adat" |
| A típusszűrő csak a mozgásra hat | stats-004, stats-005 | The Strength / Cardio filter sits in the "Mozgás" section header, visibly not filtering calories and weight |
| Export választással és visszajelzéssel | client-031 | Popover: period, data sets, CSV (UTF-8); after download a toast with the file name |

**Current code:** `app/(app)/statistics/page.tsx` (208; computes from the full meal / weight / water /
steps / session lists), `features/statistics/{aggregate,api,types}.ts` + `aggregate.test.ts`,
`components/data/{TimeSeriesChart,KpiCard}.tsx`.

**Target spec:**
- **Top bar (W5-A):** title "Statisztika"; centre = period `SegmentedControl` **Hét · Hónap · Év** + a
  period stepper "‹ szept. 21–27. ›" (future periods disabled); right "⤓ Exportálás". No date stepper.
- **KPI row:** 6 tiles (`repeat(6,1fr)`, 3 × 2 at 1024, 2 × 3 at 390 showing the first 4): Átlag kalória
  1 823 kcal "−77 a célhoz"; Testsúly −0,4 kg "javulás · előző hét −0,3"; Edzések 5 "+1 · előző hét 4";
  Volumen 19 360 kg "+2 % · előző hét"; Cardio táv 20 km "+7,7 km"; Átlag lépés 8 240 "−8 %" — icon in the
  metric colour, value, `DeltaChip` good / bad / neutral + context line.
- **"TÁPLÁLKOZÁS ÉS TEST"** (2 columns): *Kalória* — "átlag 1 823 · a mai nap nélkül", bars, dashed goal,
  dotted average line, today dashed, legend "cél 1 900 · átlag · ma, folyamatban". *Testsúly* — "69,6 kg ·
  cél 65 kg", line with dots, a missing measurement joined by a **dotted** segment (`connectNulls` on a
  separate dotted series only), footnote "A célvonal (65 kg) ebben a heti skálában a tengely alatt van —
  a fejléc mutatja."
- **"MOZGÁS"** (3 columns) with the `Mind · Erősítő · Cardio` segmented control in the section header:
  *Edzésvolumen* "19 360 kg" bars on workout days, rest-day dots; *Cardio táv* "20 km · 2 alkalom" bars
  with value labels (14,8 · 5,2); *Lépések* "átlag 8 240" purple bars + dashed 9 000. One footnote each
  (the canvas sentences).
- **Year view (W5-B):** "Kalória · 2026", "heti átlag · naplózás aug. 17-től", "Nincs előző évi adat",
  weekly bars, the months before the first log as a hatched band "Még nem naplóztál", X "jan. … nov.", "ma"
  marker.
- **Export (W5-C):** `Popover` "Adatok exportálása": Időszak (Ez a hét · 30 nap · Minden adat), data sets
  as checkboxes (Étkezések és makrók · Testsúly · Edzések és szettek · Víz és lépések), "CSV · UTF-8",
  "Letöltés" → toast "✓ lifey-2026-09-21_27.csv letöltve".
- **Mobile (W5-D):** header with the export icon, period segmented, 2 × 2 KPIs, one chart per card
  (calories first), bottom nav.

**Data:** everything from the lists the page already loads; exports are built client-side (no backend).

### W5.1 — Web UI: statistics top bar controls ✅
- Files: `app/(app)/statistics/page.tsx`, `features/statistics/components/PeriodControl.tsx`,
  `routeChrome.ts`.
- **Verify:** period in the URL (`?period=week&start=2026-09-21`); stepping stops at the current period.

*As built:* the statistics top bar is the W5-A one: the title, then in the centre the **Hét · Hónap · Év** switch and a "‹ szept. 28. – okt. 4. ›" period stepper (the forward arrow is disabled on the current period), and **Exportálás** right beside the theme toggle — the top bar gained a `trailing` slot for it (`useTopBarTrailing`, same contract as the W4.2 centre slot). On a phone there is no top bar, so the export and the stacked full-width switch + stepper open the page (W5-D; the 390 pass is W5.9). `features/statistics/period.ts` (11 tests) is the period model: **calendar** weeks (Monday start), months and years instead of the old rolling 7 / 30 / 365 days, stepping with `shiftPeriod`, `canStepForward` stopping at the current period, the period before it for every delta, and the URL form `?period=week&start=2026-09-21` — a missing, malformed or future `start` falls back to the current period and `start` snaps to the period's first day; switching the view keeps the viewed time in view (a week in August → that August). The page reads and writes the query with `router.replace`, so a view is linkable and survives a reload. Two formatters joined `lifeyFormat` for the labels: `dateRange` ("szept. 21–27." / "Sep 21 – 27", both months when the span crosses one) and `monthYear`. The page body is still the old one fed by the new range — W5.2–W5.6 replace it. `routeChrome` needed no change: statistics was never a dated route, so there is no date stepper to hide. Verified in Chromium on the demo account: the stepper reads "szept. 28. – okt. 4.", next is disabled, ‹ writes `?period=week&start=2026-09-21`, "Hónap" switches to `?period=month&start=2026-09-01` and "2026. szeptember".

### W5.2 — Web data: series shaping and honest deltas ✅
- Files: `features/statistics/aggregate.ts` (+ tests): per-day series with `null` gaps, weekly averages for
  the year, "complete period" rule (a delta only between two complete periods — the current one counts as
  complete only for sums, never for averages that include today), goal-direction semantics for each KPI,
  first-log date for the hatched band.
- **Verify:** unit tests incl. an empty previous year, today excluded, rest days.

*As built:* `features/statistics/periodStats.ts` (27 tests) builds everything a period shows in one pure call, `buildPeriodStats({ raw, period, start, now, goals })`. **Series:** one slot per day (week, month) or per calendar week clipped to the year (year view); a day with nothing is `null`, never 0 — calories, weight, steps (a recorded 0 counts as no count, as on the steps page) and cardio leave gaps, volume marks a *finished* slot with no workout as a rest day (the dot) while today and the future are simply not drawn. **Averages leave today out** (calories, steps — and in the year view the weekly means too); sums (workouts, volume, km) include it. **Deltas** are only made between figures that mean the same thing: an empty previous period gives `delta: null` and `previous: null` (the page says "Nincs előző adat / évi adat"), never "+1659"; a running period's *sum* against a finished one can only be good or neutral — fewer workouts so far than last week is grey, not orange, because the week isn't over. **Colour follows meaning** (`deltaTone`): steps / workouts / volume / km up = good, down = bad; weight change is good when it moves toward the goal weight (neutral with no goal, neutral for a zero change); calories are compared with the **goal** ("−77 a célhoz", green within ±10 %, orange beyond in either direction) and, with no goal set, with the previous average in grey. Also here: the year view's first-log date and the number of empty leading weeks for the hatched "Még nem naplóztál" band, and `weightScale` — the weight chart's Y range is the data padded a little and widened to the goal only when that costs ≤ 40 % more height, otherwise the goal stays off-scale and `goalOutsideScale` drives the footnote. `RawData` moved to `types.ts` (re-exported from `aggregate.ts`, which the page still uses until W5.6 removes it together with `KpiCard` / `TimeSeriesChart` here). The Strength / Cardio filter does not change any number — it only decides which Mozgás cards are shown (W5.5), which is what the canvas note asks for.

### W5.3 — Web UI: KPI row ✅
- Files: `features/statistics/components/KpiRow.tsx` (`MetricTile` compact variant; replaces `KpiCard`).
- **Verify:** colours per note "A delta színe…"; HU/EN.

*As built:* `features/statistics/components/KpiRow.tsx` replaces the old four `KpiCard`s with the canvas' six tiles — **Átlag kalória · Testsúly · Edzések · Volumen · Cardio táv · Átlag lépés** — built on the DS `MetricTile`, which gained a `compact` variant (the chip and the context line share one wrapping row under a 28 px value, `valueSize` for the 22 px phone tiles) instead of a second tile component. Six across from 1280, 3 × 2 at 768–1279, two columns at 390 showing the first four (W5-D). The chips are `ToneChip`s in three colours only: **green** (`--improvement`) toward the goal, **orange** (`--m-kcal`) worse, **grey** neutral — the tone comes from `periodStats`, never from the sign. Calories read "−77 · a célhoz" (against the goal; with no goal set, against the previous average in grey), weight shows the period's change ("−0,4 kg") with the word **javulás / romlás** and "előző hét −0,3", workouts "+1 · előző hét 5", volume and steps a percentage, cardio a km difference — and a figure with nothing behind it shows "—" with its reason ("Legalább két mérés kell", "Nincs naplózott nap"), a delta against an empty previous period shows "Nincs előző adat" (year view: "Nincs előző évi adat"). The page feeds it `buildPeriodStats` with the goals from settings (kcal, steps) and onboarding (goal weight); the old `KpiCard` is no longer used here (it goes with the old chart cards in W5.6). `lifeyFormat` gained `number(value, maxDigits)` (no trailing zero: "20", "14,8", "19 360"). Checked in Chromium on the demo account for the week of 21 Sep: 1 608 kcal "−292 a célhoz" in orange (more than 10 % under 1 900), −0,4 kg "javulás", 6 workouts "+1", 18 383 kg "+5 %", 16,2 km, 7 843 steps "+1 %".

### W5.4 — Web UI: nutrition & body section ✅
- Files: `features/statistics/components/{CaloriesChartCard,WeightChartCard}.tsx`.
- **Verify:** average dotted line value = the header number; goal below the axis noted.

*As built:* the **TÁPLÁLKOZÁS ÉS TEST** section is two cards side by side from 1280 (one column below), each a `ChartCard` (title 16/700, figure on the right, the chart, a **legend row drawn with the marks themselves**, one footnote). **`CaloriesChartCard`** draws the `LifeyBarChart` — one bar per day, a day without a meal an *empty column* (never a 0 bar), today a dashed outline, the dashed goal line "cél 1 900", and a new **dotted average line** whose value is exactly the header's "átlag 1 608 · a mai nap nélkül" (both come from `stats.calories.average`, which leaves today out; the "a mai nap nélkül" note shows only while the viewed period contains today). **`WeightChartCard`** is a dedicated Recharts line: the measurements solid with dots (the last one ringed), and a **second, dotted series with `connectNulls` drawn underneath** that joins the two measurements either side of a missing day — the solid series never bridges, so a gap is visible and never a 0 or an invented slope; the Y range is `weightScale` (data padded, widened to the goal only when it is close), the dashed goal line is drawn only when it fits and otherwise the footnote says "A célvonal (65 kg) ebben a heti skálában a tengely alatt van — a fejléc mutatja." plus "Hiányzó mérés pontozott összekötés." when a gap was bridged. **`LifeyBarChart` got four opt-in props** (nothing existing changes): `average` (the dotted line), `bandBefore` (a hatched band over the first N columns with a caption — W5.6), `marker` (a thin "ma" line through one column — W5.6) and per-datum `axisLabel` (what the X axis prints, `""` prints nothing, so `label` becomes a unique key); `features/statistics/chartAxis.ts` (3 tests) makes the labels: weekday names with today as "Ma", or for a month the 1st as "szept. 1." and every fifth day, or for a year a month name over the first week of each month. `lifeyFormat` got `monthShort`. The old calories and weight `TimeSeriesChart` cards are gone from the page; the three movement cards are the next step. Checked in Chromium (week of 21 Sep, 1440): the header and the dotted line agree at 1 608, weight "69,6 kg · cél 65 kg" with Y "69 / 69,8 / 70,5", both series present and the goal-off-scale footnote shown, no console errors.

### W5.5 — Web UI: movement section with its type filter ✅
- Files: `features/statistics/components/{MovementSection,VolumeChartCard,CardioDistanceCard,
  StepsChartCard}.tsx`.
- **Verify:** switching Erősítő/Cardio leaves the nutrition section untouched; rest days are dots.

*As built:* the **MOZGÁS** section (`MovementSection`, `MovementCards`) has the **Mind · Erősítő · Cardio** segmented control in its own header row, right of the caps label and its hairline — visibly *inside* the section, so it reads as filtering these cards and not the calories and weight above (the old page put it beside the period switch, which suggested it filtered everything). Mind shows **Edzésvolumen · Cardio táv · Lépések** in three columns from 1280 (two at 768, one below); Erősítő drops the cardio card, Cardio drops the volume card, steps always stay — the filter decides which cards are drawn and never changes a number, and the page has no other consumer of it (the KPI tiles are unfiltered). **Volume:** a bar on a workout day and a small dot on the axis for a *finished* rest day (`isRestDay`; today and the future are simply empty), so the chart never falls to 0 and climbs back; total kg in the header ("18 383 kg"). **Cardio:** one bar per session day with its value over it (week view; month and year skip the labels, 30+ columns would collide), "16,2 km · 2 alkalom" — the session count now counts only sessions that contributed a distance (DISTANCE and MACHINE families, as on mobile). **Steps:** one colour, the dashed goal line, today dashed and out of "átlag 7 843". Every card has a legend and its canvas footnote; a card with no data says so in a sentence. The HU key `trainingVolume` now reads "Edzésvolumen" (canvas) instead of "Edzésmennyiség". The page no longer uses `TimeSeriesChart`, `KpiCard` or the old card — only `aggregate` remains, for the interim CSV, until W5.7. Checked in Chromium: Erősítő leaves volume + steps, Cardio leaves cardio + steps, and the calories card's text is identical before and after.

### W5.6 — Web UI: month and year views ✅
- Files: the chart cards' period variants, `features/statistics/components/NoDataBand.tsx`.
- **Verify:** W5-B side by side; "Nincs előző évi adat".

*As built:* the month and year views come from the same `buildPeriodStats` slots, so there is no second code path: **month** is one column per day with the 1st as "szept. 1.", every fifth day numbered and today "Ma" (30 labels would not fit a third-width card); **year** is one column per calendar week — calories, weight, steps as the weekly mean of the days that have a value, volume and cardio as weekly sums — with a month name over the first week of **every second month** ("jan. márc. máj. …", the canvas' own rhythm; naming all twelve overprinted in the three-up movement row). The year view's calories card is W5-B: "Kalória · 2026" / "heti átlag · naplózás aug. 17-től", the months before the first meal under a **hatched "Még nem naplóztál" band** (the new `bandBefore` overlay of `LifeyBarChart` — plain absolutely-positioned boxes over the plot area, using the chart's own margin numbers, instead of a separate `NoDataBand` component), a thin **"ma" line** through the current week (`marker`), and the chip **"Nincs előző évi adat"** with every KPI delta saying the same instead of comparing with an empty year (no "+1659"). Two honesty fixes found here: a finished slot with no workout is a rest-day dot **only from the first thing the account ever recorded** (`firstData`) — the year view would otherwise have drawn a row of dots for every week of January to August that predates the account — and `weightScale` now returns whole-and-half-kilo ends over a whole-kilo span so the middle tick is a clean 70 rather than "70,3". Checked in Chromium on the demo account: the year view shows the band from jan. to aug. 17, the marker, the chip and "—"-free KPIs with "Nincs előző évi adat"; the month view labels "szept. 1. · 5 · 10 … · Ma" and the weight chart joins its gaps with dotted segments ("hiányzó mérés" in the legend).

### W5.7 — Web data: CSV export builder ✅
- Files: `features/statistics/exportCsv.ts` + test (UTF-8 **with BOM** so Excel opens HU accents; `;`
  separator for HU locale, `,` for EN; ISO dates inside the file). **One CSV per chosen data set**,
  downloaded in sequence, named `lifey-<from>_<to>-<set>.csv` (a single set keeps the canvas name
  `lifey-2026-09-21_27.csv`). Rejected: a ZIP (would need a zip dependency for a rare action).
- **Verify:** unit tests for escaping, BOM, separators.

*As built:* `features/statistics/exportCsv.ts` (15 tests) is the pure builder, with no backend call: `exportRange` (the **viewed period** — cut at today while it is still running — **30 nap**, or **Minden adat** from the first recorded day), `buildCsv` for one data set and `buildExport` for a choice of sets, plus `downloadCsvFiles`, which saves the files one after the other with a short gap so the browser does not block a burst of downloads. **One CSV per chosen set** (Étkezések és makrók: a row per meal entry with type, food, grams, kcal and the three macros; Testsúly; Edzések és szettek: a row per set with exercise, reps, kg and volume, and one row per cardio session with activity, km and minutes; Víz és lépések: a row per day that has either), named `lifey-2026-09-21_27.csv` for a single set — the canvas name, the end shortened to what differs from the start — and `lifey-2026-09-21_27-weight.csv` when several are chosen. **Made to open in Excel as it is:** UTF-8 **with a BOM** (Hungarian accents), `;` and a decimal comma for Hungarian but `,` and a point for English (a comma separator puts a whole Hungarian row in one cell, and "69.6" becomes a date), ISO dates and 24-hour times, plain numbers with no grouping, CRLF line ends, RFC 4180 quoting — and any text that starts with `=`, `+`, `-` or `@` gets a leading apostrophe so a food named `=HYPERLINK(…)` cannot run when the sheet is opened. Column headers come in from the caller (translated), so the builder stays free of i18n. Not done: a ZIP (would need a dependency for a rare action, as planned).

### W5.8 — Web UI: export popover + toast ✅
- Files: `features/statistics/components/ExportPopover.tsx`.
- **Verify:** downloads open in Excel/LibreOffice with correct accents; toast names the file(s).

*As built:* **Exportálás** (top bar, right beside the theme toggle; a round download icon in the phone header) opens the W5-C popover, `ExportControl`: "Adatok exportálása", **Időszak** as three chips — the period on screen ("Ez a hét" when it is the current one, otherwise its range, e.g. "szept. 14–20."), **30 nap**, **Minden adat** — the four data sets as DS checkboxes on a nested surface (Étkezések és makrók, Testsúly, Edzések és szettek ticked, Víz és lépések not, as on the canvas), "CSV · UTF-8" and **Letöltés** (disabled with nothing ticked). It builds the files with `exportCsv.ts`, downloads them one after the other and closes, and a **success toast names what was saved** — "lifey-2026-09-21_27.csv letöltve", or "4 fájl letöltve: …" for several. The popover anchors to a wrapping span (so the labelled button and the icon button share one code path), closes on Esc / outside click and returns focus to its trigger through the DS `Popover`. The interim CSV of W5.1 and the old `aggregate.ts` (with its test) are **deleted** — nothing imports them any more; the cardio definitions its parity tests pinned (DISTANCE + MACHINE families, games excluded, no 0 km for a session with no distance, every session counted in "Edzések") live on in `periodStats.test.ts`. Checked in Chromium on the demo account (week of 21 Sep): the popover opens with the canvas' defaults; with all four sets ticked four downloads are triggered named `lifey-2026-09-21_27-meals|weight|workouts|waterSteps.csv`, each starting with the UTF-8 BOM (EF BB BF), `text/csv;charset=utf-8`, `;` separated with decimal commas ("2026-09-22;69,6", "Tojás;157,4;225;19,8"), accents intact in the headers ("Étkezés", "Mennyiség (g)"); the toast lists the files. Not verified here: opening the files in Excel / LibreOffice themselves (no spreadsheet on this machine) — the BOM, separator and decimal mark are the three things that decide it, and each is asserted in `exportCsv.test.ts`.

### W5.9 — Web UI: statistics at 390 ✅
- **Verify:** W5-D side by side; charts' Y axes not clipped at 358 px card width.

**W5 acceptance** (plus §4.1): W5-A … W5-D reproduced; no chart draws a missing day as 0.

**W5 web UI review focus:** the four frames; flows: week → month → year, step back a year, filter
Cardio, export two data sets; check each chart's axis at 1024 and 390, both languages ("2,4 e" /
"2.4k").

---

*As built:* at 390 the page follows W5-D: the `MobileHeader` carries the title, then the **full-width Hét · Hónap · Év switch** (44 px segments), the period stepper with the **export as a round download icon** beside it (`PeriodControl` got an `endSlot` for it), the **2 × 2 KPIs** (first four; Edzések and Volumen show their chips and "előző hét" lines, the last two tiles are hidden), then one chart per card, calories first, with the floating bottom nav clear of the content. The Mozgás filter becomes a full-width 44 px switch *under* its label (the small 32 px one would miss the 44 px touch target). Checked at 390 × 844 in Chromium on the demo account: document and `<main>` are both 390 wide (no sideways scroll), every chart card is 358 px with its 326 px plot, and each Y axis reads whole — "1,9 e / 950 / 0", "70 / 69 …", "6,4 e / 3,2 e / 0", "12 e / 6 e / 0" — in the 44 px axis column with nothing clipped; the three filter segments and the period segments measure 44 px.

## W6 — Settings, auth, onboarding · `Lifey Web 6 Settings Auth Onboarding.dc.html` (W6-A … W6-H)

**Goal:** a branded first minute, a focused wizard with a "wow" plan, and all settings on one page with an
honest logout.

**Canvas notes = requirements:**

| Note | PDF ids | Requirement |
|---|---|---|
| Márka-felület a belépés mellett | auth-001, auth-008 | Two-column login: dark brand panel (value promise + two real components: ring, record) left, form right; on mobile the form starts at the top, the main button near the thumb |
| Google-gomb a Lifey nyelvén | auth-001, auth-007 | Same shape and height as the other buttons (52 px), Google logo; surface-2 in dark, not a black-blue bar |
| Hiba, amit nem lehet nem észrevenni | auth-002, auth-004 | HU error text with an icon, red field rings, a form-level error in a tinted box; 13–14 px, AA |
| Magyar mezősorrend, edzői út jelölve | auth-003, auth-006 | Surname first ("pl. Kovács"); trainer registration gets a clay "Edzői fiók" badge + a stepper (Fiók · Jelentkezés · 14 nap ingyen) |
| Varázsló héj és dátumléptető nélkül | onboarding-002, onboarding-005, onboarding-006 | Full screen, a step summary on the left; choice tiles selected = tint + ring + check; birth date as typed year / month / day fields |
| A „wow” pillanat nagy számokkal | onboarding-007, onboarding-008 | The plan in one sentence, the calculation under it, a hero with kcal and four tiles with reasons; the finish celebrates and points to the next step |
| Beállítások egy lapon, szekciókkal | client-032, client-033, client-034, client-037 | One scrolling page, the left sub-menu as anchors; short settings as segmented controls per row; "Kliens · edző: …" instead of `ROLE_USER`; the mobile notification types here too |
| Őszinte kijelentkezés | client-039, client-084 | At the bottom, with a confirmation that says what happens to the data, focus on "Mégse"; on mobile Settings becomes list rows |

**Current code:** `app/(auth)/{layout,login/page,register/page,forgot-password/page}.tsx`,
`features/auth/{components/GoogleSignInButton,schemas,store,api}.ts(x)`; `app/(app)/onboarding/page.tsx`
(247, 5 steps: Welcome, About you, Body, Lifestyle & goal, Suggested plan) +
`features/onboarding/components/{GenderBirthDateFields,HeightField,BodyFields,LifestyleGoalFields,
OptionCard,ConfirmSaveDetailsDialog}.tsx`; `app/(app)/settings/page.tsx` (461, several panels) +
`features/settings/components/AvatarUploader.tsx`; trainer path: `?next=` + `signupSource` in
`register/page.tsx` → `/admin/pending`.

**Target spec:**
- **Auth layout (W6-A):** `grid 1fr | 1fr` at ≥ 1024: left dark brand panel (always dark, in both themes):
  logo, "Étrend, edzés és az edződ, egy helyen.", "Ugyanaz a fiók, mint a mobilappban. Amit ott
  naplózol, itt azonnal látod — és az edződ is.", two floating real components (a `ProgressRing` "859 kcal
  maradt", a `RecordChip` card "🏆 Új rekord · Guggolás · 62,5 kg × 8") with static demo values; right the
  form column (max 440). < 1024 the brand panel collapses to the logo row (W6-C).
- **Login:** "Üdv újra!", "Lépj be az e-mail címeddel vagy Google-fiókkal.", Google button (52, r14,
  `--nested` in dark), divider "vagy e-maillel", E-mail, Jelszó + "Elfelejtetted?" link + visibility
  toggle, form-level error box (heart tint, icon, "Hibás e-mail cím vagy jelszó. Ellenőrizd, vagy kérj új
  jelszót."), "Belépés" (52, full width), "Még nincs fiókod? Regisztráció".
- **Register (W6-B):** Vezetéknév · Keresztnév (surname first in HU, first name first in EN), E-mail,
  Jelszó + strength meter (4 segments, "Erős jelszó"); trainer path (`signupSource` / `next=/admin/…`):
  clay "Edzői fiók" badge + stepper "1. Fiók · 2. Jelentkezés · 3. 14 nap ingyen", title "Hozd létre az
  edzői fiókod", CTA "Tovább a jelentkezéshez".
- **Onboarding (W6-D/E/F, `chrome: "focus"`):** `grid 340 | 1fr`: left rail with the logo, the four
  steps and their answers ("Rólad — Nő · 1994. máj. 14.", "Testalkat — 168 cm · 72 kg", "Életmód és cél —
  Mérsékelten aktív · fogyás", "Javasolt terved — Most"; done ✓ protein tint, current → primary), "Kihagyás,
  később beállítom" at the bottom. The Welcome step stays as the intro screen before the rail appears.
  Step 3 (W6-E): "Mi a fő célod?" three `ChoiceTile`s (Fogyás "Heti 0,25–0,75 kg" · Súly tartása · Izomépítés
  "Enyhe kalóriatöbblet"), radiogroup, one click selects and enables "Tovább". Step 4 (W6-D): "4 / 4 ·
  Javasolt terved", headline "Napi 1 850 kcal-lal heti fél kilót fogysz, izomvesztés nélkül." (sentence
  built from goal + rate), the calculation "alapanyagcsere 1 384 kcal, napi energiaigény 2 345 kcal
  (mérsékelten aktív), mínusz 495 kcal a fogyáshoz" (from `bmr`, `tdee`, `calories`), hero row
  `minmax(300px,1.4fr) | 1fr × 4`: 🔥 **1 850** "kcal / nap" + tiles Fehérje 115 g "1,6 g / testsúly-kg —
  megőrzi az izmot", Szénhidrát 205 g "az energia 44 %-a", Zsír 62 g "az energia 30 %-a", Víz 2,5 L "35 ml /
  kg"; "← Vissza", "Most nem", "Célok alkalmazása". Finish (W6-F): celebration modal "Kész a terved,
  Anna!" + "Kezdd a mai első étkezéssel — az Áttekintő megmutatja a következő lépéseket." → dashboard
  (replaces the success toast).
- **Settings (W6-G, 1440 light):** `grid 220 | minmax(0,760)`: left sticky anchor list (Profil · Napi célok ·
  Megjelenés és egységek · Értesítések · Biztonság · Kijelentkezés; the section in view highlighted).
  *Profil*: avatar (uploader), "Nagy Kata", "kata.nagy@demo.hu · Kliens" (+ "· edző: Szabó Bence" only if
  the client's trainer name is available from an existing endpoint — verify at W6.9, else omitted),
  "Profil szerkesztése" (drawer with user details). *Napi célok*: five tiles (Kalória 1 900 kcal ·
  Fehérje 120 g · Szénhidrát 210 g · Zsír 63 g · Víz 2,5 L) in metric colours + "Szerkesztés" (drawer);
  the clay attribution line is not built (D-W0.19). *Megjelenés és egységek*: rows with segmented
  controls — Téma (Rendszer · Világos · Sötét), Nyelv (Magyar · English), Mértékegység (Metrikus ·
  Angolszász; one control, D-W0.19). *Értesítések*: the real toggles — workout reminder, trainer comment,
  trainer goals, program assigned, chat + chat quiet hours (`TimeField`s). *Biztonság*: change password
  (drawer). *Kijelentkezés*: "Ezen az eszközön. A naplózott adataid megmaradnak." + "Kijelentkezés…" →
  `LogoutDialog`: "Kijelentkezel?", "Minden adatod a fiókodban van, újra belépve ugyanitt folytatod. A
  mobilappban bejelentkezve maradsz.", "Mégse" (focused) + "Kijelentkezés".
- **Settings mobile (W6-H):** profile row, list rows with icon + label + current value + chevron (Napi
  célok 1 900 kcal · Megjelenés Sötét · Nyelv Magyar · Egységek kg · L · Értesítések "3 be" · Biztonság),
  each opening its section as a sheet; "Kijelentkezés…" at the bottom.

### W6.1 — Web UI: auth layout with the brand panel ✅
- Files: `app/(auth)/layout.tsx`, `features/auth/components/BrandPanel.tsx`.
- **Verify:** 1440 light + dark, 1024, 390 (brand panel reduced); the marketing header link still works.

*As built:* the auth layout is W6-A: `grid 1fr | 1fr` from 1024 px — the **dark brand panel** (`BrandPanel`: logo, "Étrend, edzés és az edződ, egy helyen.", the same-account sentence, and two real components with static demo values — a `ProgressRing` with "859 kcal maradt" and a `RecordChip` card "Új rekord · Guggolás · 62,5 kg × 8") beside the form column (max 440). The panel is **dark in both themes** through a new `.dark-island` class in `globals.css` that re-declares the dark values of the tokens such a surface reads (so the ring and chip inside keep their dark look under `[data-theme="light"]`; reusable for any future always-dark surface). Below 1024 the panel collapses to the logo row (`LifeyLogo`) and the form starts at the top with its main button pinned near the thumb. The old centred card is gone from every auth route (login, register, forgot-password all render inside the new column until W6.3/W6.4 restyle their content).

### W6.2 — Web UI: login form, Google button, error states ✅
- Files: `app/(auth)/login/page.tsx`, `features/auth/components/GoogleSignInButton.tsx` (restyle only — the
  GIS script handling is unchanged).
- **Verify:** wrong password → form error + field rings; screen reader announces the error.

*As built:* the login page is the canvas: "Üdv újra!", "Lépj be az e-mail címeddel vagy Google-fiókkal.", the **Google button first**, a divider "vagy e-maillel", then the DS `TextField` / `PasswordField` at the 52 px auth size (the password label row carries "Elfelejtetted?"), "Belépés" as a full-width 52 px `Button`, "Még nincs fiókod? Regisztráció". **Errors you cannot miss:** a wrong password no longer pins the message on the password field — both fields get the red ring (new `invalid` prop on `Field` / `TextField` / `PasswordField`: the ring without a message of its own, `aria-invalid` set) and a **heart-tinted `FormErrorBox`** with an icon and "Hibás e-mail cím vagy jelszó. Ellenőrizd, vagy kérj új jelszót." sits above the button as `role="alert"`, so a screen reader announces it; field-level validation messages (bad e-mail, short password) still show under their field. The show/hide-password button's label was hard-coded English; it is now `common.showPassword / hidePassword` in both languages. **Google button:** `GoogleSignInButton` keeps the official GIS-rendered button (its own iframe can neither be 52 px tall nor restyled — the old Q5 rule stands; the script handling is untouched), now placed above the divider and sized to the column (GIS caps it at 400 px); **deviation:** it is the 40 px official button, not the canvas' 52 px custom one. Checked with Playwright at 1440 light / dark, 1024 and 390 dark: the wrong-password state shows both rings and the box, the panel reduces to the logo row at 390, the button sits at the bottom.

### W6.3 — Web UI: register + trainer path ✅
- Files: `app/(auth)/register/page.tsx`, `features/auth/components/{PasswordStrength,TrainerSignupStepper}.tsx`.
- **Verify:** HU field order surname-first, EN first-name-first; trainer path shows clay badge + stepper
  and still lands on `/admin/pending`.

*As built:* the register form is W6-B on the DS fields at 52 px: **Vezetéknév · Keresztnév** side by side (surname first in Hungarian, first name first in English — the order follows the UI language; placeholders "pl. Kovács" / "pl. Anna"), E-mail, Jelszó with a **strength meter** (`PasswordStrength` + `passwordStrength.ts`, 3 tests: four segments and a word — "Gyenge jelszó", "Elfogadható", "Erős jelszó", "Nagyon erős jelszó" — from length, case mix, a digit and a symbol; it adds no rule the backend lacks, 8 characters stay the only requirement), "Fiók létrehozása" and the Google button above. The **confirm-password field is gone** (the canvas has none; the show/hide toggle replaces it), so \`registerSchema\` lost \`confirmPassword\` — a deliberate behaviour change called out here. **Trainer path** (\`?next=/admin/…\`, as the trainer-request CTAs send): a clay **"Edzői fiók"** badge (\`--role\` tint) with the stepper "**1. Fiók** · 2. Jelentkezés · 3. 14 nap ingyen" (\`TrainerSignupStepper\`, current step bold), the title "Hozd létre az edzői fiókod", the CTA "Tovább a jelentkezéshez", no Google button (the request needs an e-mail account) — and the submit still logs in and follows \`next\` to \`/admin/pending\` (the code path is unchanged, only the chrome differs). Checked with Playwright in both languages: HU labels read Vezetéknév | Keresztnév | Email | Jelszó, EN First name | Last name | Email | Password; an empty submit rings and explains the three fields in red with text; a typed "Abcdefg1!x" shows four green segments and "Nagyon erős jelszó".

### W6.4 — Web UI: forgot / reset password
- Files: `app/(auth)/forgot-password/page.tsx`.
- **Verify:** every step in both themes and languages.

### W6.5 — Web UI: onboarding frame + left rail + typed birth date
- Files: `app/(app)/onboarding/page.tsx`, `features/onboarding/components/{OnboardingRail,
  GenderBirthDateFields}.tsx` (`DateFields`), `routeChrome.ts` (`focus`).
- **Verify:** no sidebar/top bar; rail answers update live; "Kihagyás" keeps today's skip behaviour.

### W6.6 — Web UI: onboarding choice tiles
- Files: `features/onboarding/components/{LifestyleGoalFields,OptionCard}.tsx` → `ChoiceTile`.
- **Verify:** arrows + Space operate the radiogroup; "Tovább" enabled on the first selection.

### W6.7 — Web UI: suggested-plan hero
- Files: `features/onboarding/components/SuggestedPlan.tsx`, `features/onboarding/planSentence.ts` + test.
- **Verify:** sentence for lose / maintain / gain in HU and EN; numbers match `SuggestGoalsResponse`.

### W6.8 — Web UI: onboarding finish celebration
- Files: `features/onboarding/components/OnboardingDoneModal.tsx`.
- **Verify:** lands on the dashboard with W1's first-steps card ticking "Célok beállítva".

### W6.9 — Web UI: settings page frame + anchors + profile section
- Files: `app/(app)/settings/page.tsx` (split into `features/settings/components/sections/*.tsx`),
  `SettingsAnchorNav.tsx` (IntersectionObserver).
- **Verify:** anchors scroll and highlight; role label never `ROLE_USER`.

### W6.10 — Web UI: goals + appearance sections
- Files: `sections/{GoalsSection,AppearanceSection}.tsx`, `GoalsDrawer.tsx`.
- **Verify:** theme and language apply immediately and persist to settings; units switch re-formats every
  open number.

### W6.11 — Web UI: notifications + security sections
- Files: `sections/{NotificationsSection,SecuritySection}.tsx`, `ChangePasswordDrawer.tsx`.
- **Verify:** toggles round-trip the fields this client doesn't model (the existing `SettingsRequest` rule);
  quiet hours "22:00", never "22:00:00".

### W6.12 — Web UI: logout section
- Files: `sections/LogoutSection.tsx` (uses the W0.20 `LogoutDialog`).
- **Verify:** focus on "Mégse"; Esc cancels; logout lands on `/login`.

### W6.13 — Web UI: settings at 390
- Files: `features/settings/components/SettingsMobileList.tsx`.
- **Verify:** W6-H side by side; no two-column layout below 768 (`client-084`).

**W6 acceptance** (plus §4.1): W6-A … W6-H reproduced; new account → onboarding → dashboard without a
toast; logout confirmed everywhere.

**W6 web UI review focus:** the eight frames; flows: wrong password, Google button (render only),
register as client and as trainer, full onboarding with skip and without, change every settings row, log
out from the account menu and from Settings; 200 % zoom on the login and the plan step.

---

## W7 — Trainer: clients + client detail · `Lifey Web 7 Trainer Clients.dc.html` (W7-A … W7-E)

**Goal:** the trainer first sees who needs them today, then everyone else with real numbers; a client's
page reads at a glance and never clips.

**Canvas notes = requirements:**

| Note | PDF ids | Requirement |
|---|---|---|
| Nincs felugró „Klienseid” modal | trainer-001 | The modal goes; a "Ma figyelmet igényel" strip at the top: inactive client, unread message, new record — one button each |
| Az inaktivitás az első, amit látsz | trainer-002, trainer-012 | Inactive client's card has a heart-coloured "6 napja inaktív" line; the "Figyelem" sort keeps them first; on the client page the same as a header band with a reminder button |
| Kártyák valódi számokkal | trainer-002 | Each card: last activity, 7-day calorie compliance, weekly workouts as dots, 30-day weight change against the goal direction, next scheduled workout, program week — all from today's API (+ the optional W7.b1 field) |
| Clay a szerep, primary a vezérlő | trainer-002, trainer-004 | No second green: EDZŐ badge, avatar ring and program chip clay; buttons and the active nav primary; the weekly-report switch moved to the account menu (W0.23) |
| Kliens-fejléc, amely nem vágódik le | trainer-005 | Avatar, name, goals and programme, four actions right (Üzenet, Ütemezés, Kiosztás, ⋯) in a wrapping row; KPIs relative to the goal (1 823 / 1 900 kcal, 96 %) |
| Naplózási hőtérkép | trainer-005, trainer-008 | 4 weeks × 7 days: meal / workout / weigh-in per day as dots — the main overview element |
| Mobil edzői nézet | trainer-061, trainer-066 | Bottom nav (Klienseim · Naptár · Chat · Tervek · Több), the alert above the list, clients as rows with their compliance |

Plus the W7-C card notes: Statistics tab = W5 charts with integers and the goal ratio (`trainer-006`,
no "11 256,254 kcal"); Steps tab = goal line, one colour (`trainer-007`; the "Cél módosítása" action is
not built, D-W0.19); Meals tab = the W2 log read-only (`trainer-008`; meal comments not built); Workouts
tab = the W3 weekly log, a click opens the summary in a drawer, no raw `CYCLING` (`trainer-009`);
Schedule tab = weekly timeline with status chips (`trainer-010`), the schedule drawer closes on Esc and
scrim click (`trainer-011`).

**Current code:** `app/(admin)/admin/page.tsx` (162), `features/trainer/components/{ClientCard (215),
ClientListModal (87), NeedsAttentionSection (74), ClientSortSelect, ComplianceBadges, ClientAvatar}.tsx`,
`features/trainer/compliance.ts`; `app/(admin)/admin/clients/[clientId]/page.tsx` (142),
`ClientDetailHeader (123)`, `Client{Overview (235), Statistics (107), Steps (64), Nutrition (351),
Workouts (384), Schedule (136)}Tab.tsx`, `ScheduleTimeline`, `ScheduleList`, `ScheduleWorkoutDrawer (388)`,
`AssignToClientDrawer (230)`, `UnassignButton`; `features/trainer/{api,types}.ts`.

**Target spec:**
- **Klienseim (W7-A, 1440 dark):** title "Klienseim" + subline "5 aktív kliens · 2 függő meghívó"; tools:
  search "Kliens keresése /" and "＋ Kliens meghívása" (primary). **"MA FIGYELMET IGÉNYEL · 3"**: three
  cards in a row — inactive (heart tint icon + heart hairline ring, "Kiss Dóra · 6 napja inaktív", "Két
  ütemezett edzés kimaradt a héten.", "Üzenet"), unread chat (primary tint, "Horváth Máté · 2 olvasatlan",
  the last message quoted, "Válasz"), new record (carbs tint 🏆, "Tóth Réka · új rekord", "Guggolás
  70 kg × 6 tegnap" when derivable, else "3 új rekord a héten", "Gratulálok"); CTAs open the chat with a
  prefilled draft (D-W0.19). **"MINDEN KLIENS"**: sort segmented Figyelem · Név · Utolsó aktivitás, view
  toggle grid / table (`grid_view`, `table_rows`). Cards 3 per row: avatar (stable hue) + name + last
  activity line ("ma 14:10 · víz"; heart "6 napja inaktív"), "⋯"; three mini KPIs — Kalória · 7 nap
  **96 %** (bar; avg kcal only when W7.b1 is absent), Edzés · hét **4 / 4** (dots), Súly · 30 nap
  **69,6 kg** "−1,9 kg · cél felé" (green toward goal, orange against, neutral "tartás"; "nincs mérés");
  footer "📅 H, szept. 29. · Láb + core" / "Kimaradt: H, Sze" / "Nincs ütemezve" + clay program chip "4
  hetes · 3. hét". Side card "2 függő meghívó" (e-mails, "3 napja", "Meghívók kezelése →"). Table view
  = `DataTable` with the same fields.
- **Client detail (W7-B, 1440 light, collapsed sidebar):** top bar breadcrumb "Klienseim › Nagy Kata" +
  the date stepper (for the day-based tabs). Header card: 56 px avatar, "Nagy Kata" (26/800), meta "34
  éves · 168 cm · cél: fogyás · kliens aug. 17. óta" + clay chip "4 hetes alapozó · 3. hét"; actions
  "Üzenet" · "Ütemezés" · "Kiosztás" · "⋯" (Kliens eltávolítása…) wrapping under the name when narrow.
  `Tabs` (underline): Áttekintés · Statisztika · Lépések · Étkezések · Edzések · Ütemterv (scrollable at
  390). **Overview**, 12 columns: four KPI tiles span 3 (Kalória · 7 nap átlag **1 823** / 1 900 kcal, bar
  96 %, "96 % a célhoz · 5 / 6 nap célon belül"; Fehérje · 7 nap átlag 104 / 120 g; Edzések a héten 4 / 4
  ütemezett "minden ütemezett kész · 1 rekord"; Testsúly 69,6 kg · cél 65, bar = progress start → goal,
  "−1,9 kg 30 nap alatt"); heatmap span 8 "Naplózás · elmúlt 4 hét" with legend (étkezés `--m-kcal`, edzés
  `--primary`, mérés `--m-weight`), rows = weeks labelled "aug. 31." …, cells with up to three dots, today
  ringed; right column span 4: "Következő · Ütemterv" (three rows "H 29 · Láb + core · 18:00 · program 3.
  hét"), "Legutóbb" feed (🏆 record, meals, weigh-in with relative times).
- **Other tabs (W7-C):** Statisztika = W5 cards scoped to the client, `Hét · Hónap`, "Heti kalória
  **11 256** · cél 13 300 · 85 %", "Fehérje átlag 104 g · cél 120 g", "Volumen 19 360 · +2 %"; Lépések =
  W4 steps chart (read-only goal 9 000); Étkezések = W2 meal cards read-only + "Célok szerkesztése"
  (the existing `nutritionGoalsEditor`, now a drawer — kept, function must not be lost); Edzések = W3
  week list, row → `SessionSummary` in a drawer with the existing session comment box; Ütemterv = weekly
  timeline (`120 | 1fr`: "Ez a hét", "Jövő hét"; rows "H · Láb + core" + status chip Kész / Ütemezve /
  Kimaradt), "+ Ütemezés" → `ScheduleWorkoutDrawer` on the W0.13 drawer.
- **Inactive header (W7-D):** heart band inside the header card: `notifications_active` "6 napja nem
  naplózott semmit. Utolsó aktivitás: szept. 21., Pull nap. Két ütemezett edzés kimaradt." +
  "Emlékeztető küldése" (chat with a prefilled draft).
- **Mobile (W7-E):** header "Klienseim" + clay EDZŐ + avatar; the top alert as one row ("Kiss Dóra · 6
  napja inaktív ›"); client rows (avatar, name, last activity, compliance "96%"); trainer bottom nav.

**Data:** `avgCalories7d`, `prCount7d` (already sent, not yet typed); week workouts / next session / missed
from one `calendarSessions(weekStart, +14 d)` call; program week from `programAssignmentsForClient`
(only on the detail page — the card uses `programName` from the calendar entries and computes the week
from the first occurrence); heatmap + feed from `clientMeals`, `clientWorkoutSessions`, `clientWeights`
over 28 days; attention rules reuse `features/trainer/compliance.ts` thresholds (inactive ≥ its current
day limit); unread counts from the chat hooks already running in the trainer layout.

### W7.1 — Web data: client summary types + signals
- Files: `features/trainer/types.ts` (`avgCalories7d: number | null`, `prCount7d: number`),
  `features/trainer/clientSignals.ts` + test (attention list and order, week dots, next session, weight
  direction vs goal, "last activity" label kind).
- **Verify:** unit tests; the "Figyelem" order = inactive → unread → missed → rest by name.

### W7.2 — Web UI: clients page header, search, remove the modal
- Files: `app/(admin)/admin/page.tsx`, delete `ClientListModal.tsx`.
- Behaviour change (called out): no modal on arrival.
- **Verify:** `/` focuses search; filtering by name and e-mail.

### W7.3 — Web UI: "needs attention" strip
- Files: `features/trainer/components/AttentionStrip.tsx` (replaces `NeedsAttentionSection.tsx`),
  `features/chat/draft.ts` (open a conversation with a prefilled draft).
- **Verify:** empty strip hidden; CTAs land in the right conversation with the draft, nothing sent
  automatically.

### W7.4 — Web UI: client card v2 + sort + grid/table toggle
- Files: `features/trainer/components/{ClientCard,ClientsTable,ClientSortControl}.tsx`, delete
  `ClientSortSelect.tsx`, `ComplianceBadges.tsx`.
- **Verify:** W7-A side by side; toggle persisted per device; missing data shows "—" not 0 %.

### W7.5 — Web UI: pending invites side card
- Files: `features/trainer/components/PendingInvitesCard.tsx`.
- **Verify:** relative dates "3 napja"; link to `/admin/invites`.

### W7.6 — Web UI: client detail header + tabs + inactive band
- Files: `features/trainer/components/ClientDetailHeader.tsx`, `app/(admin)/admin/clients/[clientId]/page.tsx`
  (tab in `?tab=`), `routeChrome.ts` (breadcrumb + date stepper).
- **Verify:** at 1024 and 390 nothing clips (`trainer-005`); actions wrap; the band only for inactive
  clients.

### W7.7 — Web data: heatmap + activity feed derivation
- Files: `features/trainer/clientActivity.ts` + test (28-day grid Monday-first, dots per kind, feed of
  the latest 3–5 events incl. PRs via `personalRecords.ts`).
- **Verify:** unit tests incl. month boundary and a day with all three kinds.

### W7.8 — Web UI: overview tab
- Files: `features/trainer/components/ClientOverviewTab.tsx` (rewritten), `LoggingHeatmap.tsx`,
  `UpcomingSchedule.tsx`, `ActivityFeed.tsx`.
- **Verify:** W7-B side by side; KPI % bars relative to goals; heatmap keyboard-readable (each cell has a
  label "szept. 21., hétfő: étkezés, edzés").

### W7.9 — Web UI: statistics + steps tabs
- Files: `ClientStatisticsTab.tsx`, `ClientStepsTab.tsx` (reuse W5/W4 chart cards with a `clientId` source).
- **Verify:** integers only; goal ratios.

### W7.10 — Web UI: meals tab (read-only) + goals drawer
- Files: `ClientNutritionTab.tsx`, `features/trainer/nutritionGoalsEditor.ts` (reuse).
- **Verify:** no edit/delete affordances on the client's meals; goals save as today.

### W7.11 — Web UI: workouts tab + summary drawer
- Files: `ClientWorkoutsTab.tsx` (W3 `SessionsView` in read-only mode, `SessionSummary` in a `Drawer` with
  the existing comment editor).
- **Verify:** comments save/delete; activity labels translated.

### W7.12 — Web UI: schedule tab + drawer on the W0.13 primitive
- Files: `ClientScheduleTab.tsx`, `ScheduleTimeline.tsx`, `ScheduleWorkoutDrawer.tsx`, `UnassignButton.tsx`.
- **Verify:** Esc and scrim close the drawer (`trainer-011`); unsaved guard; time without seconds.

### W7.13 — Web UI: trainer clients at 390
- **Verify:** W7-E side by side; trainer bottom nav; the detail tabs scroll horizontally with the active
  one in view.

### W7.b1 — Backend (optional): `dailyCalorieGoal` on the trainer client summary
- Files: `backend/.../trainer/dto/TrainerClientResponse.java` (+ nullable `Integer dailyCalorieGoal`, read
  from the client's settings in the same service call that computes `avgCalories7d`),
  `TrainerAccessServiceImpl.java`, controller test.
- No migration, no new table — a read-only field, like mobile R6.2. The web card computes the % when it
  is present and shows avg kcal otherwise. Needs the go-ahead (§10 Q4).
- **Verify:** `./mvnw test -Dtest=TrainerClient*`; the web card shows 96 % with the field.

**W7 acceptance** (plus §4.1): W7-A … W7-E reproduced; no modal on arrival; all six tabs on v2 without
losing any function.

**W7 web UI review focus:** the five frames; flows: triage the three attention cards (each opens the
right chat with a draft), sort by each option, grid ↔ table, open a client and walk all six tabs,
edit nutrition goals, comment on a session, schedule a workout and close the drawer with Esc, an
inactive client's header; 1024 and 390 for header clipping.

---

## W8 — Trainer: calendar, programs, chat · `Lifey Web 8 Calendar Programs Chat.dc.html` (W8-A … W8-E)

**Goal:** the trainer's work tools: a real week view, a draggable program grid, and chat next to the
client's numbers.

**Canvas notes = requirements:**

| Note | PDF ids | Requirement |
|---|---|---|
| Valódi hétnézet | trainer-013, trainer-014 | Days as columns, hours as rows, today highlighted; each event a card (client, workout, status); status = colour bar **+ text** (Kész / Ütemezve / Kimaradt) |
| Húzás, szűrés, gyors ütemezés | trainer-015 | Drag to move, Shift to copy (optional W8.b1); client filter in the header; clicking an empty cell opens the schedule drawer prefilled with that slot |
| Idő másodperc nélkül | trainer-023 | "18:00", not "18:00:00"; EN "6:00 PM" |
| Program = hét × nap rács | trainer-030, trainer-031 | Weeks as rows, days as columns; templates on the left, draggable into cells; copy a week with one button; the row label shows the week's load note |
| Kiosztás következményekkel | trainer-032 | The drawer says how many workouts land in the calendar between which dates and flags conflicts; inactive / already-using clients visible |
| Chat három oszlopban | trainer-040, trainer-041 | Conversation list with unread counts, bubbles in the middle, the client's current numbers and next workouts on the right |
| Megosztott tartalom kártyaként | trainer-042 | Shared workout/meal as a card with an action — **not built** (D-W0.19); the composer gets a primary focus ring, Enter sends |
| Mobil chat | trainer-065 | One column with a back arrow; client info opens as a sheet from the info button |

**Current code:** `app/(admin)/admin/calendar/page.tsx` → `features/trainer/components/{TrainerCalendar
(281), CalendarWeekView (166), CalendarMonthView (180), CalendarAgendaView (113), CalendarSessionPeek
(266), CalendarClientFilter (117), CalendarSkeleton, ScheduleWorkoutDrawer}.tsx`;
`app/(admin)/admin/programs/{page,new/page,[programId]/page}.tsx`, `ProgramGridEditor (393)`,
`ProgramList (136)`, `AssignProgramDrawer (285)`, `features/trainer/program.ts`; `app/(admin)/admin/chat/
page.tsx` (103), `features/chat/components/{ConversationList (244), ChatThread (630), MessageBubble (201),
ChatComposer (227), ChatSearch (155), ChatAttachment (167), ChatAvatar}.tsx`, `features/chat/{hooks,
thread}.ts`.

**Target spec:**
- **Calendar (W8-A, 1440 dark, collapsed sidebar):** top bar "Naptár", centre "‹ szept. 22–28., 2026 ›"
  + "Ma", right `SegmentedControl` Nap · Hét · Hónap, "Minden kliens" filter (popover with checkboxes),
  "＋ Ütemezés" (primary). Grid card r22, `64px | 7 × 1fr`: day headers "H 22 … V 28", today's header a
  primary pill and its column tinted primary @ 4 %; hour rows (07:00 … 20:00) where **runs of empty
  hours collapse** into one row "⤢ 10:00–15:00 · nincs esemény · kinyitás" (click to expand); events =
  cards with a 3 px status bar (Kész protein, Ütemezve primary, Kimaradt heart), client name 13/700,
  "Láb + core · kész" 12/600; legend "Ütemezve · Kész · Kimaradt" (+ "Húzással áthelyezhető · Shift+húzás =
  másolás" only with W8.b1). Empty cell click → `ScheduleWorkoutDrawer` with client unset, date and time
  prefilled; event click → `CalendarSessionPeek` popover (restyled). Month and agenda views restyled on
  the same tokens; "Nap" = one column of the week grid.
- **Program editor (W8-B, 1440 light):** header "← 4 hetes alapozó", meta "4 hét · 12 edzés · 3 kliens
  használja · mentve 2 perce / Nem mentett változás", "Hét másolása" (secondary), "Kiosztás" (primary).
  `280px | 1fr`: left "Sablonok" with search and draggable template rows (`drag_indicator`, name, "6
  gyakorlat · 50 perc"), "+ Új sablon"; right card, grid `88px | 7 × 1fr`: day header H … V, row labels
  "1. hét · 3 edzés" (4th week "terhelés −20 %" only when the week's workouts carry that note — else the
  count), cells = workout tiles (primary tint @ 10 %, 3 px primary bar, name + "6 gyakorlat"; cardio
  templates "30 perc · Z2"), empty cells dashed hairline; while dragging, the target cell shows "Ide
  ejtve: Láb + core" with a 2 px primary ring and the source row goes 45 % opacity; keyboard alternative:
  select a template, focus a cell, Enter places it. "Hét másolása" asks source → target week(s).
- **Assign drawer (W8-C):** "Program kiosztása · 4 hetes alapozó"; "Kinek" checklist (name + state:
  "már használja" disabled, "aktív", heart "6 napja inaktív"); "Kezdés" `DateButton` "H, szept. 29." +
  "Időpont" `TimeField` 18:00; consequence box: "**12 edzés** kerül a naptárba **szept. 29. – okt. 24.**
  között." + conflicts "Tóth Réka naptárában 2 időpont ütközik." (listed; no auto-shift, D-W0.19);
  "Mégse" + "Kiosztás 2 kliensnek".
- **Chat (W8-D, 1440 dark):** three columns (`320 | 1fr | 300`): list with search, rows (avatar, name,
  time, preview — bold when unread, unread `CountPill`, selected `--nested` + 3 px primary bar; "Te: …"
  prefix for own messages); thread: header (avatar, "Horváth Máté", "⋯"; no online dot, D-W0.19), day
  separator "Ma", bubbles max 720 (own = primary fill, radius 18 18 6 18; theirs `--nested`, 18 18 18 6;
  time 12/500), composer (＋ attachment, text area with primary focus ring, send; hint "Enter küldés ·
  Shift+Enter új sor"); right "MÁTÉ ADATAI": Kalória · 7 nap 88 %, Edzés · hét 2 / 3, Testsúly 84,1 kg
  "+0,6 kg · cél felé", "Következő" two rows, "Kliens megnyitása". < 1280 the right panel becomes a drawer
  from an info button.
- **Mobile chat (W8-E):** thread only with back arrow, avatar, name, "ⓘ" → client info sheet; composer
  fixed above the safe area.

### W8.1 — Web UI: calendar header + week grid
- Files: `TrainerCalendar.tsx`, `CalendarWeekView.tsx`, `features/trainer/calendarGrid.ts` + test (hour
  rows, collapsed empty runs, overlapping events side by side).
- **Verify:** W8-A side by side; status readable without colour (text); times without seconds.

### W8.2 — Web UI: empty-cell scheduling + peek popover
- Files: `CalendarWeekView.tsx`, `CalendarSessionPeek.tsx` (on `Popover`), `ScheduleWorkoutDrawer.tsx`.
- **Verify:** clicking 18:00 Friday opens the drawer with that date/time; peek closes on Esc.

### W8.3 — Web UI: day, month and agenda views + client filter
- Files: `CalendarMonthView.tsx`, `CalendarAgendaView.tsx`, `CalendarClientFilter.tsx`.
- **Verify:** the filter persists across views; month cells show counts, not overflowing text.

### W8.4 — Web UI: program editor layout + template rail
- Files: `app/(admin)/admin/programs/[programId]/page.tsx`, `programs/new/page.tsx`,
  `ProgramGridEditor.tsx` (split: `ProgramTemplateRail.tsx`, `ProgramWeekGrid.tsx`).
- **Verify:** W8-B side by side (static); save state line.

### W8.5 — Web UI: drag templates into cells + keyboard placement + copy week
- Files: `ProgramWeekGrid.tsx` (dnd-kit `DndContext` with sensors for pointer **and keyboard**),
  `features/trainer/program.ts` (`copyWeek`, tests).
- **Verify:** drag, keyboard placement and copy week produce the same `ProgramRequest` as the old form
  for the same result (unit test on `program.ts`).

### W8.6 — Web UI: assign-program drawer with consequences
- Files: `AssignProgramDrawer.tsx`, `features/trainer/programConflicts.ts` + test (occurrence dates from
  the program, conflicts against `calendarSessions` ± 60 min).
- **Verify:** counts and date range match what the backend then creates (`occurrenceCount` in the
  response).

### W8.7 — Web UI: programs list on `DataTable`
- Files: `app/(admin)/admin/programs/page.tsx`, `ProgramList.tsx`.
- **Verify:** sort, ⋯ (Szerkesztés, Duplikálás, Kiosztás, Törlés…).

### W8.8 — Web UI: chat three-column layout + client context panel
- Files: `app/(admin)/admin/chat/page.tsx`, `ConversationList.tsx`, `ChatThread.tsx` (layout only — the
  thread logic in `features/chat/thread.ts` is untouched), `features/chat/components/ClientContextPanel.tsx`
  (data from W7.1 signals).
- **Verify:** unread counts live; context panel matches the client's card numbers.

### W8.9 — Web UI: bubbles, composer, search, attachments restyle
- Files: `MessageBubble.tsx`, `ChatComposer.tsx`, `ChatSearch.tsx`, `ChatAttachment.tsx`, `ChatAvatar.tsx`
  (→ `Avatar`).
- **Verify:** Enter / Shift+Enter; focus ring; image attachments unchanged.

### W8.10 — Web UI: chat at 390
- **Verify:** W8-E side by side; info sheet; keyboard doesn't cover the composer (visualViewport).

### W8.b1 — Backend (optional): move a scheduled occurrence
- Files: `backend/.../trainer/controller/WorkoutScheduleController.java` (`PATCH /api/v1/trainer/scheduled-
  sessions/{id}` with `{ scheduledFor, scheduledTime }`, only for `SCHEDULED` status, ownership-scoped),
  service + test; then a web step `W8.5b — Web UI: drag to move, Shift+drag to copy` (copy = create a
  one-off schedule).
- A new write endpoint on existing data (no migration). **Only with the user's go-ahead (§10 Q2)** —
  without it the calendar ships without drag and the legend omits the hint.

**W8 acceptance** (plus §4.1): W8-A … W8-E reproduced; build a 4-week program by drag and by keyboard;
assign with a conflict shown; answer a chat with the context panel open.

**W8 web UI review focus:** the five frames; flows: schedule from an empty cell, peek + cancel an
occurrence, filter one client, switch Nap/Hét/Hónap, build and copy a week in the program editor,
assign to two clients with a conflict, chat: read → reply → open client; 1024 (chat context as drawer)
and 390.

---

## W9 — Trainer content, invites, billing, superadmin · `Lifey Web 9 Trainer Content Superadmin.dc.html` (W9-A … W9-G)

**Goal:** the remaining trainer pages and the system admin on the same shell and the same table + panel
pattern — no separate visual language.

**Canvas notes = requirements:**

| Note | PDF ids | Requirement |
|---|---|---|
| Sablonok táblázatban, szerkesztés panelen | trainer-035, trainer-036 | Sortable table (exercises, time, which clients use it — avatars); the editor in a right panel with drag order and set steppers |
| Mentés hatása kiírva | trainer-037 | The panel footer says how many clients' future workouts the change affects; "Nem mentett" chip |
| Ételeim & receptjeim = W2 táblázat | trainer-046, trainer-047 | The same table + editor panel as the client Foods tab, plus "Kiosztás" in the ⋯ menu |
| Kiosztott tervek kliensenként | trainer-045 | Grouped by client, type icon + status chip; missed items visible; "Visszavonás" from ⋯ with confirmation |
| Meghívók állapottal | trainer-050, trainer-051 | Status as text, relative dates, the next step per row (the shareable link is not built, D-W0.19) |
| Számlázás: mi történik és mikor | trainer-055 | Trial days left on a bar, the expiry date and its consequence in one sentence; the two plans as choice tiles |
| Superadmin a közös héjban | admin-001, admin-002 | The common sidebar with a neutral "RENDSZER" badge (W0.24); users table with role filter, bulk role action, HU role names instead of `ROLE_` |
| Kérelem döntéshez elég adattal | admin-003 | The request card shows the message, expected clients and account age; rejecting asks for confirmation |
| Szerepkör-történet idővonalként | admin-004 | Who changed whose role, when — an icon timeline, not a raw table |

**Current code:** `app/(admin)/admin/workouts/page.tsx` (63, reuses `TemplatesView`),
`app/(admin)/admin/nutrition/page.tsx` (48, reuses `FoodsView` / `RecipesView`),
`app/(admin)/admin/assignments/page.tsx` (126), `invites/page.tsx` (225), `billing/page.tsx` (282) +
`features/billing/components/{PlanChooser,SeatMeter,AdminBillingBanner,BillingBlockedDialog,
TrainerOnboardingChecklist}.tsx`, `pending/page.tsx` (253); `app/(superadmin)/superadmin/{users (284),
trainer-requests (204)}/page.tsx`, `features/superadmin/{api,types,components/UserAvatar}.ts(x)`,
`features/trainer-requests/*`.

**Target spec:**
- **Edzésterveim (W9-A, 1440 light):** title + "7 sablon · 3 használatban", search, "＋ Új sablon";
  `1fr | 520px`: table columns Név ↑ (+ tag line "Erősítő · alsótest") · Gyakorlat · Idő ("50 perc") ·
  Használja (overlapping avatars + "2 kliens" / "senki") · ⋯; selected row primary @ 8 % + bar. Panel:
  "Láb + core", "Nem mentett" chip, close; "6 gyakorlat · 18 szett · kb. 50 perc"; exercise rows
  (`24 | 1fr | 128 | 32`: drag handle, name + "8 ismétlés · 2:00 pihenő", − **4** + set stepper, ⋯),
  "+ Gyakorlat"; footer "A változás a 3 kliens jövőbeli edzéseire vonatkozik." + "Elvetés" / "Mentés".
  Tags come from the template's exercises' muscle groups (derived; none → no tag line).
- **Ételeim & receptjeim:** the W2 Foods table + panel and the W2 recipe cards with "Kiosztás" in ⋯ (opens
  the existing `AssignToClientDrawer` on the drawer primitive).
- **Invites (W9-B):** card "Kliens meghívása": e-mail field + "Küldés"; list rows e-mail, "3 napja
  küldve", status chip (Függő carbs tint · Lejárt neutral), action ("Újraküldés" for expired = cancel +
  re-invite; "Visszavonás…" for pending). No "Elfogadva" rows and no link row (D-W0.19).
- **Assigned plans (W9-C):** groups per client (avatar, name, "3 tétel"), rows: type icon (program
  `view_week`, template `fitness_center`, recipe `menu_book`), name, date ("szept. 8. –", "V, szept. 28."),
  status chip (Aktív · Kész · Ütemezve · Kimaradt), ⋯ → "Visszavonás…" + confirm.
- **Billing (W9-D):** "Jelenlegi csomag · Pro · próbaidő", "Még **9** nap" with a bar, "A próbaidő okt.
  6-án jár le. Utána 5 kliensig ingyenes marad, felette 4 990 Ft / hó.", two `ChoiceTile`s (Alap 0 Ft · 5
  kliensig; Pro 4 990 Ft / hó · korlátlan · programok · export), "Fizetési mód megadása", fine print. The
  existing seat meter, checkout polling and blocked dialog keep their logic, restyled.
- **Pending (trainer request waiting room):** focus-mode page on v2 (clay "Edzői fiók" badge, the stepper
  from W6.3 at step 2, status text).
- **Superadmin users (W9-E, 1440 dark):** title "Felhasználók" + summary line; KPI row (4 tiles) only with
  W9.b2; search "Név vagy e-mail" (320), role segmented Mind · Kliens · Edző · Superadmin, selection
  bar "1 kijelölve · Szerepkör…" (bulk grant/revoke trainer — sequential calls to the existing
  endpoints with a progress toast); table `32 | 1.6fr | 120 | 1fr | 140 | 44`: checkbox, avatar + name
  (e-mail when no name) + e-mail line, role chip (Kliens neutral · Edző clay · Superadmin neutral light ·
  Függő carbs), Edző column (with W9.b1), "Utolsó belépés" → **"Regisztrált"** (`createdAt`; last login not
  tracked, D-W0.19), ⋯ (Szerepkör…, Szerepkör-történet).
- **Trainer request (W9-F):** card: avatar + name/e-mail + "2 napja", the motivation quoted, a definition
  list (Várható kliens 10–15 · Fiók: Kliensként aug. 30. óta), "Elutasítás…" (confirm modal) +
  "Jóváhagyás" (primary). No "Végzettség" row (D-W0.19).
- **Role history (W9-G):** timeline rows (icon: `how_to_reg` primary for grant, `person_remove` heart for
  revoke, `shield_person` neutral), "Szabó Bence: Kliens → Edző", "jóváhagyta: Admin · aug. 12."; per user
  in a drawer from the users table (existing endpoint); the global page `/superadmin/role-history` only
  with W9.b3.

### W9.1 — Web UI: trainer templates table + editor panel
- Files: `app/(admin)/admin/workouts/page.tsx`, `features/workouts/components/TemplatesView.tsx` (trainer
  variant), `features/trainer/templateUsage.ts` + test (clients using a template from assignments /
  schedules).
- **Verify:** W9-A side by side; the impact sentence counts the right clients; unsaved guard.

### W9.2 — Web UI: trainer foods & recipes
- Files: `app/(admin)/admin/nutrition/page.tsx`, `AssignToClientDrawer.tsx`.
- **Verify:** same components as W2 (grep shows no trainer-only copies); assign from ⋯.

### W9.3 — Web UI: assigned plans grouped by client
- Files: `app/(admin)/admin/assignments/page.tsx`, `features/trainer/components/AssignedPlanGroup.tsx`.
- **Verify:** revoke asks and then removes; missed items listed.

### W9.4 — Web UI: invites page
- Files: `app/(admin)/admin/invites/page.tsx`.
- **Verify:** expired computed from `expiresAt`; resend creates a fresh invite; relative dates.

### W9.5 — Web UI: billing page
- Files: `app/(admin)/admin/billing/page.tsx`, `features/billing/components/*`.
- **Verify:** trial, active, over-limit and blocked states (the existing e2e specs `trainer-billing-page`,
  `billing-*` still pass locally).

### W9.6 — Web UI: pending page
- Files: `app/(admin)/admin/pending/page.tsx`.
- **Verify:** `trainer-request-flow.spec.ts` still passes.

### W9.7 — Web UI: superadmin users table + bulk role
- Files: `app/(superadmin)/superadmin/users/page.tsx`, `features/superadmin/components/{UsersTable,
  RoleChip,BulkRoleBar}.tsx`.
- **Verify:** no `ROLE_` on screen; bulk action reports partial failures.

### W9.8 — Web UI: trainer request cards
- Files: `app/(superadmin)/superadmin/trainer-requests/page.tsx`.
- **Verify:** `trainer-request-superadmin-queue.spec.ts` passes; reject confirm focuses "Mégse".

### W9.9 — Web UI: role history drawer (+ global page with W9.b3)
- Files: `features/superadmin/components/RoleHistoryDrawer.tsx`, optional
  `app/(superadmin)/superadmin/role-history/page.tsx`, `navConfig.ts` (item visible only with W9.b3).
- **Verify:** timeline order newest first; actor names when available, else e-mails.

### W9.b1 — Backend (optional): names + trainer on the superadmin user list
- `SuperAdminUserResponse` + `firstName`, `lastName`, `trainerName` (client) / `clientCount` (trainer),
  read-only joins; test.
### W9.b2 — Backend (optional): superadmin KPI endpoint
- `GET /api/v1/superadmin/stats` → active accounts 30 d (by last activity), trainers, clients with a
  trainer, pending requests + oldest age; test.
### W9.b3 — Backend (optional): global role-audit feed
- `GET /api/v1/superadmin/role-audit?page=` with target user e-mail/name; test.

Each needs the go-ahead (§10 Q5); every UI step above works without them.

**W9 acceptance** (plus §4.1): W9-A … W9-G reproduced (minus the D-W0.19 items); the superadmin looks like
the same product.

**W9 web UI review focus:** the seven frames; flows: edit a used template (impact sentence), assign a
recipe from ⋯, revoke an assignment, send / resend / revoke an invite, the billing states from the
existing specs, superadmin: filter, bulk grant, per-user history, approve and reject a request; 390 for
every page.

---

## W10 — Sweep and cleanup (general, closing)

**Goal:** nothing left on the old system; the audit proves it.

### W10.1 — Tooling: style-debt audit script
- Files: `web/scripts/style-debt-audit.mjs` (+ `npm run audit:styles`).
- Counts in `src/` excluding `components/marketing`, `app/(marketing*)`: legacy variables (D-W0.3 list),
  hex literals, inline `style={{` with colour/radius/font-size, `rounded-[var(--r-(sm|md|input|lg|nav))]`,
  imports from `components/ui` / `components/data`, `date-fns` `format(` used in JSX, `toFixed(` in
  components, `humanizeEnum(` in JSX, `type="date"` / `type="time"`. Prints per file; exit code 1 above
  zero for the hard rules (legacy vars, `components/ui|data` imports, native date inputs). Useful early —
  may be pulled into W0 (M1).
- **Verify:** runs in CI after W10.3 as a blocking step.

### W10.2 — Web UI: remaining undesigned screens
- `app/not-found.tsx` is marketing (untouched); in scope: the app error boundary page, chat search results,
  chat attachment viewer, `programs/new` empty state, onboarding Welcome step, any page the audit still
  lists — by analogy with the nearest canvas, each listed in the commit.
- **Verify:** audit shows only intentional exceptions.

### W10.3 — Web UI: delete the legacy aliases and old components
- Delete legacy variables and Tailwind keys from the app scope (the marketing pin keeps its own copy under
  `:root:has([data-surface="marketing"])`), `components/ui/{Dialog,ConfirmDialog,SegmentedControl,Switch,
  DatePicker,TimePicker,Toaster}.tsx`, `components/data/*`, `components/layout/{Sidebar,AdminSidebar,
  TopBar}.tsx`, `lib/hooks/useUiStore.ts` fields no longer used, `humanizeEnum` if unused.
- **Verify:** `npm run audit:styles` exit 0; build, unit, `ds` e2e green; marketing unchanged.

### W10.4 — Docs: close the loop
- This doc's `Status:` and ✅s; `docs/web/06-design-system-web.md` gets a "superseded by
  docs/redesign-web/78-web-redesign-plan.md" line at the top; `docs/web/README.md` pointer;
  `docs/REMAINING-WORK.md` gets the §6 deferred items; `docs/README.md` status row.
- **Verify:** links resolve.

**W10 acceptance** (plus §4.1): audit clean; one shell, one card, one chip, one table, one toast.

**W10 web UI review focus:** a full regression walk of every route in all three roles at 1440 and 390,
dark and light, HU and EN (a short pass per page — the detailed checks were done per iteration),
including the W10.2 screens against their nearest canvas.

---

## 5. Order of work and milestones

| Milestone | Steps | You can look at |
|---|---|---|
| **M1 — New look everywhere** | W0.0–W0.5, W0.20–W0.24 | Every logged-in page on the v2 palette in the new shell; gallery skeleton; marketing untouched |
| **M2 — Component kit complete** | W0.6–W0.19, W0.25 | Gallery = DS-01 … DS-07 |
| **M3 — Today** | W1.1–W1.11 | Dashboard canvas reproduced (**smallest worth-using release**) |
| **M4 — Daily logging** | W2.1–W2.12 | Meal logging end to end, undo everywhere |
| **M5 — Training** | W3.1–W3.13 | Strength session end to end, cardio summary |
| **M6 — Body metrics** | W4.1–W4.7 | Weight, water, steps |
| **M7 — Insight** | W5.1–W5.9 | Statistics + export |
| **M8 — Around the app** | W6.1–W6.13 | Auth → onboarding → settings → logout |
| **M9 — Trainer core** | W7.1–W7.13 (+ W7.b1) | Clients + client detail |
| **M10 — Trainer tools** | W8.1–W8.10 (+ W8.b1) | Calendar, programs, chat |
| **M11 — Everything else** | W9.1–W9.9 (+ W9.b1–b3) | Trainer content, billing, superadmin |
| **M12 — Clean** | W10.1–W10.4 | Old system gone |

W10.1 (the audit script) is cheap and useful early — it may be pulled into M1. W2–W9 depend only on W0
(and W1.6 / W1.9 for the trend and PR ports, which W3, W4, W7 reuse), not on each other; the canvas
priority order (client first, trainer after) is the default. Within W0, W0.20–W0.24 (shell) need only
W0.1–W0.4 and can land before the component kit, which is why M1 is the shell.

---

## 6. Non-goals (deferred)

- **Goal attribution** ("Célok: Szabó Bence", "set by your trainer on Sep 12", "he gets notified") —
  needs persisted who/when on goal changes. Own plan (§10 Q1).
- **Weight time of day and notes** — `WeightResponse` is date-only.
- **Food servings / portions ("1 pohár · 150 g"), fibre, sugar, food favourites, own vs catalogue foods**
  — food model changes (same deferral as mobile 77 §6 piece-based portions).
- **"From your trainer" marker on assigned recipes** — the copy doesn't carry its origin to the client.
- **Trainer meal comments; trainer-edited step goal** — new endpoints/data.
- **Chat presence ("online") and shared workout/meal cards** — chat-service work (same as mobile 77 §6).
- **Invite history (accepted), shareable join link, invite reminders** — invite model changes.
- **Superadmin "last login", trainer-request "qualification"** — not tracked / not collected.
- **Calendar drag-to-move and auto-shifting conflicts** — unless W8.b1 is approved.
- **Marketing pages** — have their own design; only pinned (D-W0.2).
- **Client web chat** — the client nav has no chat today; not added.
- **New features or data** beyond the optional read-only W7.b1, W9.b1–b3 and the W8.b1 endpoint
  (D-W0.19).
- **Screenshot golden tests** (D-W0.12); **a component library** (D-W0.11).

---

## 7. Edge cases

- **Over budget:** remaining kcal negative → "212 kcal túllépés", ring second lap — dashboard hero,
  day summary, add-food "utána marad", onboarding never.
- **Zero / empty data:** a new account, a day with no meals, no weight, no workouts this week, a trainer
  with no clients, a client with no data → DS-05 empty states that name the next step; never "0 / 0", NaN
  %, or an axis of 0–0 (`niceAxisMax(0)` has a test).
- **First weight entry:** no deltas, no 7-day average, no projection; goal band without "Kezdés".
- **Goal in the other direction:** gaining weight (muscle gain goal) flips every weight chip's meaning;
  no goal → neutral chips.
- **Long values and names:** 5-digit kcal ("12 345"), "4 280 kg" volume, 3-digit imperial weights,
  "Csirkés rizstál brokkolival és édesburgonyával", "Ételeim & receptjeim" — wrap, never truncate; HU at
  200 % zoom on every review.
- **Imperial units:** every hero, delta, drawer stepper and chart axis respects `unitSystem` (lb step 0,1;
  miles; pace /mi; fl oz).
- **Midnight / focus return:** "Ma", the date stepper's disabled "next", today bars and the rest timer
  re-evaluate on `visibilitychange` (`useDateStore.syncToday`, already there).
- **Time zones:** the date stepper and "today" use the browser's local day, like the mobile app; the
  trainer sees a client's days as the backend returns them (the client's own local days, R6.2).
- **Undo vs leaving:** closing the tab within 6 s of a delete flushes the DELETE (`keepalive`); if the
  request fails the row reappears with an error toast on the next load.
- **Two tabs open:** a delete undone in one tab doesn't resurrect a row the other tab already dropped —
  TanStack refetch on focus reconciles.
- **Reduced motion:** every count-up, fill, drawer, modal, toast bar and celebration lands on the final
  state instantly; the rest timer still counts (it is information, not decoration).
- **Keyboard only:** every flow in §0's demo column is completable without a mouse, including drag (the
  program grid's keyboard placement).
- **Narrow desktop windows (768–1023):** collapsed sidebar, side panels as drawers — not the phone layout.
- **Trainer viewing a client:** read-only reuse of client components without edit affordances.
- **Role switches mid-session:** "Saját nézet" keeps the date and theme; a trainer demoted by a superadmin
  lands on `/dashboard` (existing guard).

---

## 8. Test plan and PR split

**Tests by layer:**
- *Unit (Vitest, node):* contrast pairs (W0.1), reduced motion (W0.2), formatting HU/EN (W0.4), message
  key parity + typed keys (W0.4), number field parsing (W0.9), undo timing (W0.14), chart math (W0.18),
  weight trend (W1.6), copy suggestion (W1.3), PRs (W1.9), week groups (W3.2), rest timer (W3.8), pace
  geometry (W3.10), steps stats (W4.6), stats shaping + deltas (W5.2), CSV (W5.7), plan sentence (W6.7),
  client signals (W7.1), heatmap (W7.7), calendar grid (W8.1), program copy + conflicts (W8.5, W8.6),
  template usage (W9.1). Ports reuse the mobile test cases verbatim so both clients agree.
- *Component behaviour (Playwright `ds` project on `/dev/design`, CI):* focus trap/return, Esc, roving
  focus, menus, table keyboard, date picker, toast undo, shortcuts, sidebar collapse; axe in both themes;
  no horizontal scroll at 390.
- *Flows (Playwright `chromium`, local, backend):* the existing trainer/billing specs keep passing; add
  `e2e/client-meal-log.spec.ts` (W2 demo flow incl. undo), `e2e/client-live-workout.spec.ts` (W3),
  `e2e/onboarding.spec.ts` (W6).
- *Manual per step:* the §4 checklist.
- *Web UI review per iteration:* §4.1 — the full viewport × theme × language matrix, zoom, reduced
  motion, every canvas frame side by side, every canvas note, the iteration's flows; results in §12.

**Commit / PR split:** one commit per step, pushed to `feature/web-redesign` (§4); **one long-lived PR
`feature/web-redesign → main`** carries all of them, iteration after iteration. Its description holds an
iteration checklist (W0 … W10) ticked as each iteration's web UI review (§4.1) is logged in §12, so
reviewers can read the PR iteration by iteration (commit messages carry the `W<n>.<m>` id). The branch
takes `main` in regularly so it never drifts far. Nothing is merged into `main` without the user's
go-ahead; an intermediate merge after an iteration is possible (the web is unreleased for these screens)
if the user asks for it. Optional backend steps (`W<n>.b<k>`) are separate commits on the same branch,
only after their go-ahead. Steps that grow beyond one session split by component.

---

## 9. Risk checkpoints where a failure would be silent

1. **Protein vs primary (W0.1):** in the light theme today `--metric-protein` *equals* `--primary`; after
   the swap they differ, and any code using one to mean the other renders the wrong colour without an
   error. Grep both in every iteration's files.
2. **Marketing recolour (W0.1, W10.3):** if the `:has()` pin is missed on a marketing route (a new layout,
   the 404), it silently takes the v2 palette; Lighthouse only checks the home page. Screenshot `/hu`,
   `/en/pricing`, the 404 before and after.
3. **Double-counted meal in "utána marad" (W2.6):** editing a saved meal must subtract its stored version.
4. **Rounded sums (W0.4):** summing rounded kcal makes meal totals disagree with the day total by ±1–3.
5. **Partial today in averages (W0.18, W1.8, W5.2):** including today lowers every weekly average each
   morning — and flips "within goal" counts.
6. **Gaps drawn as zero (W0.19, W5):** a `connectNulls` or a `?? 0` in a data mapper turns missing days
   into dips that look like real data.
7. **Week boundaries (W3.2, W5.2, W7.7):** a Sunday-start week on one screen and Monday on another makes
   "this week" disagree.
8. **Count-up from 0 on refetch (W0.6):** TanStack refetches on focus; a component that remounts the number
   re-animates everything — looks like data reloaded.
9. **Undo that doesn't undo (W0.14):** a DELETE sent before the toast expires, or never sent (flush missed on
   route change), leaves the UI and the server disagreeing until the next refetch.
10. **Deferred delete + mobile sync (W0.14):** the mobile app must never see a delete that the web user
    undid — hence no request before commit; verify with the network log, not the UI.
11. **Future-day logging (W0.21):** the stepper must refuse future days, or entries land on dates the
    mobile app and statistics treat as "not yet".
12. **Locale leaks (W0.4):** any remaining `date-fns format` / `toLocaleString()` without the app locale
    renders English (or the browser's locale) inside the HU UI; the audit counts them.
13. **Hidden focus (W0.8):** a component that sets `outline: none` without the ring breaks keyboard use
    with no visual sign for mouse users; the `ds` axe/computed-style checks catch the gallery, the review
    catches pages.
14. **Tooltip-only labels (W0.8, W0.20):** a collapsed-nav item or icon button without `aria-label` works
    visually and is silent to screen readers.
15. **Recharts in the marketing bundle (W0.18):** importing a chart wrapper from a shared module the root
    layout touches adds ~95 KB to every marketing page; `check:js-budget` catches it only on routes it
    checks.
16. **PR definition drift (W1.9):** the web PR chip and the trainer card's `prCount7d` must use the same
    rule as backend `PersonalRecordCounter`, or a client sees a record the trainer doesn't.
17. **Weight chip semantics (W0.7, W4.3):** colouring by sign instead of by goal direction shows a gain
    as "improvement" for someone losing weight.
18. **Settings round-trip (W6.10–W6.11):** saving a section must send the fields this client doesn't model
    unchanged (the existing `SettingsRequest` rule) or it resets other clients' push toggles.

---

## 10. Open questions (decide before the step, not blocking the plan)

1. **Goal attribution (W1, W2, W6)** — do we want a follow-up plan that persists who set the goals and
   when, so the clay chip can ship? Until then it is hidden.
2. **W8.b1 — calendar drag-to-move.** A new write endpoint (`PATCH` a scheduled occurrence). Build it, or
   ship the calendar with click → reschedule only?
3. **W0.11 — positioning.** In-house `useAnchoredPosition` vs adding `@floating-ui/dom` (~10 KB). Decide
   at W0.11 after the menu, tooltip and date popover exist.
4. **W7.b1 — `dailyCalorieGoal` on the client summary.** Without it the card shows average kcal, not %.
5. **W9.b1–b3 — superadmin read endpoints** (names, KPIs, global audit). Any, all, or none?

---

## 11. After implementation

- Update `Status:` here and tick ✅ per step as they land; *As built* notes where the result deviates.
- `docs/web/06-design-system-web.md` — "superseded by docs/redesign-web/78-web-redesign-plan.md" at the
  top; `docs/web/README.md` — pointer to this folder.
- `docs/REMAINING-WORK.md` — add the §6 deferred items; remove the web half of the tinted-chip contrast
  item.
- `docs/README.md` — status of 78.
- `docs/redesign-web/README.md` — iteration table ✅s.
- Follow-up plans to open: goal attribution, food portions (shared with mobile), chat result-sharing card
  (shared with mobile), invite link + history.

---

## 12. Review log

One entry per iteration-end web UI review (§4.1). Format: `### W<n> — <date> — <browser + version>,
<viewports>`, then *Scope* (frames and flows checked), *Matches*, *Deviations (intended)* with decision
ids, *Bugs* with the `W<n>.fix-<k>` step that closed each.

### W0 — 2026-09-30 — Playwright Chromium (bundled, headless), 1440×1024 / 1280×800 / 1024×768 / 390×844

*Scope:* real stack (Postgres, backend `:8080`, chat `:8081`, `next dev`) with the handoff demo data. A scripted
matrix of **3 roles** (client `kata.nagy`, trainer `bence.edzo`, superadmin `admin`) × **HU / EN** × **dark /
light** × the four viewports × **18 pages** (8 client, 8 trainer, 2 superadmin) = **288 captures**, each with
programmatic checks (horizontal overflow, raw i18n keys, `ROLE_`, ISO timestamps, console errors); a sample of
the screenshots viewed by eye per role/viewport/theme. Plus an interactive pass on the real app: `?` help, `G W`
/ `G I`, `[` collapse + persistence, account menu (theme/language, trainer weekly-report switch), logout dialog
default focus, the "More" sheet and its focus return at 390, the date stepper (←/T), the chat unread badge with
the chat service running, a 640×400 viewport (≈ 200 % zoom of a 1280 window) and `prefers-reduced-motion:
reduce`.

*Matches:* one shell on every logged-in page in all three roles — sidebar v2 with grouped trainer nav, the clay
EDZŐ badge vs the neutral RENDSZER badge, plan chip "TRAINER · Pro", live pending-requests badge (12) and chat
unread badge (1); top bar with the global date stepper on dated routes; floating bottom nav + More sheet below
768 px with nothing hidden under it; `?` overlay in HU/EN; no raw keys, no `ROLE_`, no ISO timestamps on any of
the 288 captures; no console errors beyond the pre-existing noise below; both themes legible.

*Deviations (intended):* pages keep their old inner layout until their own iteration (W1 … W9) — e.g. the trainer
pages still show their own page header under the shell's title, and the welcome "Your clients" modal on `/admin`
is the existing once-per-session behaviour. The client demo account's language is pinned to HU in its settings
(settings override the browser locale by design, D-W0.20), so EN client strings were verified in the gallery
(default EN) rather than on the real pages. Not done: a side-by-side of app vs canvas frames (W0 has no derived
screens; the DS-02 shell frames were compared by eye only), and a true browser-zoom pass (emulated by the
640 px viewport). Pre-existing console noise, not W0: 401 on `/client-config` before sign-in, 404 on
`/users/me/avatar` for users without one, dev-only CSP blocks on the Vercel analytics scripts and Google sign-in
on `/login`.

*Bugs* (all closed in the W0 review commit):
- **W0.fix-1** — the sidebar was `self-stretch` (as tall as the *page*), so its account chip sat below the fold
  on any long page. Now a `sticky top-0 h-screen` wrapper in `AppShell`; the gallery's fixed-height frame is
  unaffected.
- **W0.fix-2** — a flipped-above `Popover` (the account menu) was positioned from an *estimated* 240 px height
  and overlapped its own trigger by ~20 px. `useAnchoredPosition` now also returns `bottom` and flipped panels
  are pinned by it; `shell.spec` asserts the menu never overlaps the chip.
- **W0.fix-3** — at 390 px `/admin/nutrition`, `/admin/assignments`, `/admin/invites` and both superadmin pages
  (old fixed-width action cells) dragged the whole page sideways. The mobile `<main>` now `overflow-x-auto`, so
  they scroll inside it and the header/bottom nav stay put; the pages' own 390 layouts stay with their
  iterations (W8/W9).
- **W0.fix-4** — (found earlier, on a month-end `ds` run) `CalendarPopover` with `disableFuture` could rove focus
  onto a disabled day; clamped (W0.25).
- **W0.fix-5** — CI: the `ds` project flaked on GitHub runners (clicks/keys landing before `next dev` hydrated
  the big gallery page). Gallery now sets `data-hydrated`; `e2e/ds/fixtures.ts` makes `goto`/`reload` wait for
  it; the webServer waits on `/dev/design` (pre-compiles it) with a 120 s timeout; the menu-flip spec no longer
  depends on where Playwright happens to scroll. 89/89 green cold with `CI=1`, and 176/176 under 4 workers.

### W1 — 2026-09-30 — Playwright Chromium (bundled, headless), 1440×1024 / 1280×800 / 1024×768 / 390×844

*Scope:* the real stack (Postgres, backend, chat, `next dev`) with the handoff demo data. The dashboard of the
demo client (`kata.nagy`) in the full matrix **4 viewports × dark / light × HU / EN** = 16 full-page captures
(the EN pass switched the account's language setting and restored it afterwards), each with overflow and
console-error checks; the W1 canvas (`Lifey Web 1 Dashboard.dc.html`) rendered in the same browser and compared
frame by frame — W1-A (1440 dark HU), W1-B (1024 light), W1-C (390 dark), W1-D (new account) — and every
"Előtte → utána" note. Flows on the real app: date stepper three days back and `T` home (hero, tiles and the
7-day chart follow the viewed day — on 27 Sep the hero reads **859 kcal left / 1 041 eaten**, the canvas' own
numbers), `N` opens add-meal and is listed in `?`, copy-yesterday + Undo, water quick-add + the "⋯" menu, start
the recommended workout, a recent-workouts row opening its session, a fresh throwaway account getting the
first-steps card and ticking step 2 without a reload; plus a 640×500 viewport (≈ 200 % zoom) and
`prefers-reduced-motion: reduce`.

*Matches:* the three layouts (12-col 8 + 4 with the tiles across and week | recent below; 8-col with hero · tiles
· workout | recent · week; 4-col single column with 2-up water + steps and the floating bottom nav); the 220 px
ring, 56 px number, eaten / goal, three macro bars with "még 52 g"; "MAI JAVASLAT · utoljára szept. 23." with three
exercises and "4 gyakorlat · kb. 40 perc · 12 szett"; water "0,75 L" with segments, quick adds and "⋯"; steps in
one purple with "Még … lépés · kb. … perc séta"; weight with day word, "−0,4 kg / hét" chip (goal-aware),
"Cél 65 kg · még 4,6 kg" and a trend line; the week card with average (today excluded), "4 / 6 nap", workouts, dashed
goal and dashed today; recent workouts with icon tiles, PR chips only where a record was set and no raw activity
key; both themes and both languages legible; no overflow and no console errors in any of the 16 captures; reduced
motion lands on final values.

*Deviations (intended):* the "Célok: <edző>" clay chip isn't built (D-W0.19); the streak card is gone (the canvas has
none); cardio distance in the recent list keeps the shared two-decimal format ("6,20 km") rather than the canvas'
"5,2 km" until W3 touches `cardioFormat`; on a phone the weight tile is the standard tile at full width, not the
canvas' compact single row; Y-axis tops come from `niceAxisMax` (two significant digits), so they follow the data
(1,9 e on the demo week, 2,4 e on the canvas'); `OnboardingBanner` became step 1 of the first-steps card.

*Bugs* (closed in the commit that carries this entry):
- **W1.fix-1** — the weight tile lacked the canvas' trend line; added a dependency-free `TrendSpark` (last 30
  weigh-ins, hidden when the tile is narrower than 260 px).
- **W1.fix-2** — on a phone the recommendation was the full desktop card; it is now the compact W1-C one (title +
  meta and a round ▶ start button, no exercise list).
- **W1.fix-3** — the phone hero repeated the desktop eaten / goal column beside a 128 px ring; it now centres a 156 px
  ring with "1 041 / 1 900" under the caption and drops the side column.
- Found while building, fixed in place (see the step notes): `MetricValue` sized units in `em` of the wrapper so every
  unit rendered at about half size (W1.7). One process slip, caught and corrected: the local verification script reported "done" even though one
  run's production build had failed on a *transient* `next/font/google` download error (W1.11's commit went out before
  I noticed); the build and the whole checklist pass on the committed state, and the script now stops on any failing stage.

### W2 — 2026-09-30 — Playwright Chromium (bundled, headless), 1440×1024 / 1280×800 / 1024×768 / 390×844

*Scope:* the real stack (Postgres, backend, `next dev`) with the handoff demo data. The nutrition page of the demo
client (`kata.nagy`) in the matrix **3 tabs (meals on Sep 27 via ←←←, foods, recipes) × 4 viewports × dark / light ×
HU / EN** = 48 full-page captures (the EN pass switched the account's language setting and restored it), each with
console-error, horizontal-overflow and raw-key / ISO / `ROLE_` / `NaN` checks; the W2 canvas
(`Lifey Web 2 Nutrition.dc.html`) rendered in the same browser and compared — W2-A (meals, 1440 dark), W2-B
(add-food modal), W2-C (copy popover, delete confirm, edit drawer), W2-D (foods), W2-E (recipes), W2-F (390) — and
every "Előtte → utána" note. Flows on the real app, each cleaning up its throwaway data: **keyboard-only logging**
(`N` → type "alma" → ↓ → Tab → 150 → Enter = one `POST /meals`, Alma 150 g), edit a quantity to 166,7 and discard
(Esc → "Elveted a módosításokat?" → Elvetés: no request), delete a meal → Undo (no request) → delete again and wait
6.5 s (exactly one `DELETE`), copy two meals from yesterday (two `POST`s, cards 0 → 2, never overwriting), create a
food whose macros don't add up (red "A makrók 201 kcal-t adnak ki — ez 101 kcal-lal tér el."), log a recipe portion;
**axe** (WCAG 2 A/AA) on the three tabs in both themes: 0 serious / critical on all six; 0 console errors across the
flows. The phone flows (FAB, toast above it, copy sheet, foods editor sheet with its discard guard, recipe editor
sheet) were driven at 390 × 844 while building W2.12.

*Matches:* the meals layout (8 + 4 with the summary sticky on the right from 1280, above the list below it; ring 859
"kcal maradt", eaten 1 041 / goal 1 900, three macro bars "63 / 130 g"), meal cards with tinted icon, "07:15 · 3
tétel", kcal in the header, "＋" and "⋯" and always-visible P / C / F dots; empty slots "Még nincs naplózva · 859 kcal
fér bele" with the quick "Hozzáadás"; the tab row "Étkezések · Ételek 18 · Receptek 4" with the actions beside it
(a segmented control and a FAB at 390); the foods table with metric-dotted headers, "Utoljára", one "⋯" per row and
the 380 px editor with the macro line; recipe cards with the dominant-macro icon, **kcal / adag** in HU and **kcal /
serving** in EN, ratio bar and the coloured macro line, 3 → 2 → 1 columns with the pane; both themes and languages
legible; no raw keys, no ISO dates, no overflow in any capture except the one below; reduced motion is covered by the
component specs.

*Deviations (intended):* the canvas' fibre / sugar tiles, the clay "a napi célokat … állította be" coach note, recipe
meals' "1 adag · 420 g" sub-line (a logged recipe meal stores no serving count — the row shows its grams), portion
chips and the foods tab's Saját / Katalógus / Kedvencek filters are not built (D-W0.19). The demo day differs from
the canvas' (two recipe meals and 1 041 kcal, not three food meals), so the card contents differ while the structure,
totals (859 left) and states match. Recipe-meal rows keep P / C / F and kcal like every other row. `hidden` foods
(one-off macro entries) were never listed and still aren't; the editor has no "hidden" switch. Not done: a true
browser-zoom pass (the 1024 and 390 captures stand in for it) and a side-by-side image of every frame (the canvas
frames were compared by eye, strip by strip).

*Bugs* (closed in the commit that carries this entry):
- **W2.fix-1** — at 390 px in Hungarian the date stepper ("szept. 27., szombat" + the "Vissza a mai napra" chip) was
  420 px wide: the *whole page* slid sideways (document `scrollWidth` 421). The chip is an icon under 768 px (its
  label stays its accessible name); `dateStepper.spec` asserts the stepper fits at 390 in HU.
- **W2.fix-2** — `DataTable` moved focus onto its first row as soon as it mounted (and after every sort), drawing a
  focus ring under row one of every table on page load. Focus now follows the active row only while it is already
  inside the table body; `foodsTable.spec` covers it.
- Found while building and fixed in place (see the step notes): the DS `Drawer`'s stale Esc guard (W2.7), the toast
  hidden behind drawers at the same z-index (W2.11), invisible tooltips widening `<main>` so a focus could slide the
  page sideways at 390 (W2.12), `DataTable` sorting text by code point (W2.10), its `/` answering from off-screen
  tables, and hard-coded English in its toolbar.

### W3 — 2026-09-30 — Playwright Chromium (bundled, headless), 1440×1024 / 1280×800 / 1024×768 / 390×844

*Scope:* the real stack (Postgres, backend, `next dev`) with the handoff demo data, demo client `kata.nagy`. Ten W3 states — sessions list, closed-session summary (panel or drawer), start picker, templates with the usage panel, template editor, exercises table, exercise editor, cardio summary, live logger, live logger with a running rest — × **4 viewports × dark / light × HU / EN** = **160 captures** (the EN pass switched the account's language to ENGLISH through the API and restored it afterwards; the first EN attempt had silently stayed Hungarian because the account's preference wins over the browser locale, which the script now detects), each with console-error, horizontal-overflow (document *and* `<main>`), raw-key / ISO / `ROLE_` / `NaN` checks and **axe** (WCAG 2 A/AA). The captures were looked at in part (1440 dark list + summary, 1440 dark live with rest, 1024 light picker, 390 light live with rest). Flow on the real app, real key events, cleaning up after itself: **a strength session from start to celebration without a mouse** — `N` → the picker opens with focus on "Indítás" → Enter starts → the first kg field → Enter × 3 (three rows done, the rest timer running) → Space pauses it → Shift+Tab back to "Befejezés" → Enter → the RPE modal → a chip (8 · "Nagyon kemény") → "Tovább" → the celebration ("Kész a Pull nap! · Szép munka. Ez volt a héten a 2. edzésed. · 1 026 kg · 3 szett") → "Összefoglaló" lands on the summary panel with RPE 8 / 10. Earlier in the W3 steps, on the real app: the start dialog, closed-session summary at 1440 / 1024, focus mode, the clock surviving a reload, the ticking rest with Space, the RPE → celebration → summary path, the cardio summary at 1440 / 390, the templates tab and the exercises tab, the 390 live logger with its floating rest.

*Matches:* W3-A (week groups with "6 edzés · 3 ó 32 p · 18 383 kg · 16,2 km" headers, tinted icons, "🏆 PR", main value and day, the selected row with its bar, the 440 px summary panel with stats, record hero, best set ↑ and "Ismétlés ma" / "Szerkesztés"); W3-B (focus mode without the shell, the clock, the exercise rail with state dots, 18/800 set fields, the 72/800 rest hero with −15 / +15 / Szünet / Kihagyás and "Eddig ma"); W3-C (RPE modal with the named chips, the celebration modal); W3-D (hero with four stats, the pace chart with axis, average and the fastest km in full heart colour, HR zones adding up to 100 %); W3-E (28 / 1fr / 76 / 60 / 44 rows, 44 px fields, the floating rest panel); W3-F (the picker's tiles, centred in dark and light, the recommended one first and marked; the Templates tab on the same tiles with the usage panel). No raw keys, no ISO dates and no console errors of ours in any capture; the only console lines are dev-environment noise — the Content-Security-Policy refusing Vercel's analytics script and the Google font stylesheet in `next dev`, Google sign-in's "origin not allowed" on the login page, and the login page's own 401 / 403 / 404 lines.

*Deviations (intended):* "Cardio rögzítése" is not built (the web never records cardio, D-W.2); "＋ Gyakorlat hozzáadása" in the live logger is not built (the old logger could not either — it needs its own exercise picker); the plan's 90 px day column is 112 px so "Szo · szept. 26." stays on one line in Hungarian; the session list keeps the recommended-workout card above the history (it is W1's and the dashboard links to it); per-tile muscle chips on the Templates tab are gone. Not done: a true browser-zoom (200 %) pass and a reduced-motion pass of the celebration beyond the CSS mechanism (both durations are the tokens the OS setting and the gallery toggle zero); a celebration *with* record rows on the real app (the demo data's easy sets set none — covered by `finishSummary.test.ts`); the soft keyboard on a phone; a light-theme side-by-side of every canvas frame (the canvas was compared by eye, frame by frame).

*Bugs* (closed in the commit that carries this entry):
- **W3.fix-1** — axe **color-contrast** on the new surfaces, in both themes: `--text-3` text on `--nested` / the primary tint (the tile's "7 napja" 3.36:1, the rail's "0 / 3" 4.17:1, the done row's previous value 3.75:1 in dark; 4.03:1 in light) — now `--text-2`; the "Javasolt" chip (primary on the selected tile's primary tint, 4.25:1) is a solid primary chip; the legacy HR-zone panel's legend text used `--outline` (**1.83:1** dark, **1.63:1** light) — now `--text-3`; the cardio header's RPE chip in `--secondary` on its tint (4.49:1 light) — now `--text`. Afterwards all 160 captures have **0 serious / critical** axe findings.
- **W3.fix-2** — at 390 px the live logger's whole page widened (500 px): the exercise rail's strip sat in a grid track that sized itself to its content; the track is `minmax(0, 1fr)` and the rail `min-w-0` now, so the strip scrolls inside itself.
- **W3.fix-3** — the picker opened with focus on its close button, which raised that button's tooltip over the modal's edge; focus now starts on "Indítás".
- **W3.fix-4** — the live logger's collapsed next-exercise tile read "Következő · 3 ×"; it says "3 szett".
- Found while building and fixed in place (see the step notes): the web exercise editor wiped an exercise's rest time set on the phone (W3.8), the template editor's handle was mouse-only (W3.11), dnd-kit needs a frame before a keyboard move (W3.11 spec), the HR-zone panel's per-row rounding could show 99 or 101 % (W3.10), Hungarian dropping the thousands space on four digits (W3.3).

### W4 — 2026-09-30 — Playwright Chromium (bundled, headless), 1440×1024 / 1280×800 / 1024×768 / 390×844

*Scope:* the real stack (Postgres, backend, `next dev`) with the handoff demo data. Seven W4 states of the demo client `kata.nagy` — weight, weight "1 év", the log-weight drawer, water, the water-sources drawer, steps, the edit-steps drawer — × **4 viewports × dark / light × HU / EN** = **112 captures** (the EN pass switched the account's language to ENGLISH through the API and restored it afterwards; every EN capture is English), plus a second account (`uj.felhasznalo`, handed off as the "fresh" one) over weight / water / steps × the same matrix = **48 more** — each with console-error, horizontal-overflow (document *and* `<main>`), raw-key / ISO / `ROLE_` / `NaN` checks and **axe** (WCAG 2 A/AA). A few captures were looked at (1440 dark weight, water and steps, the 390 weight / water / steps, 1440 light weight, 390 light drawer). Flows on the real app with real key events, each cleaning up after itself: **weight by keyboard** — `N` → the drawer opens with the last weight ("69,6") in the focused 72 px number → ↑↑↑ and Shift+↓ / Shift+↑ (69,9, tenth-exact) → Enter = one `POST /weights`; **replace today's weight** — `N`, type "70,2", Enter → "Erre a napra már van bejegyzés: 69,9 kg. A mentés felülírja." → Felülírás = `POST` 70,2 then `DELETE` of the old entry, still one entry for the day; **delete + undo** — ⋯ → Törlés… → confirm → the row goes → Visszavonás → back, zero `DELETE`s, and the same flow waited out sends exactly one; **water** — a source tile → `POST /water-entries` with its source id, the total and the entry list update, delete → Visszavonás → zero `DELETE`s, delete and wait → exactly one, the sources drawer's discard guard after typing a name and Esc; **steps** — Szerkesztés → 12345 → Enter → `POST /steps`, the hero "12 345 · Cél elérve · 9 000", edited back (`PUT`) and the throwaway record removed; **30 nap → 1 év** (dots and average line in 30 days, weekly points in a year); **empty weight page** (a real empty account cannot be made here, so `GET /weights` was stubbed to `[]` and the user details to 404): the DS empty state with its "Súly rögzítése" action at 1440 dark and 390 light, axe clean, and the drawer opens prefilled with 70 kg.

*Matches:* W4-A (hero at 72 px with the goal-aware chips, the start → goal band, "Még 4,6 kg · a mostani tempóval dec. végére", 7-day average and pace; the chart with faint dots, the bold average, the dashed goal, Y "72 / 68,5 / 65", X "szept. 1. · szept. 15. · ma"; the range switcher in the top bar's centre; the full-width log table below with the change chips); W4-B (ring, "0,0 / 2,5 L", "Még 2,5 L · kb. 3 pohár", four source tiles, the day's entries with ⋯, "Az elmúlt 14 nap" with goal days full and the others at 45 %, the dashed goal); W4-C (hero with Szerkesztés, the three stat cards, all bars steps purple with ✓ over complete goal days and the dashed goal line, HU day letters); W4-D (compact weight hero with the average-only chart and the last three entries, stacked water controls, three-up steps stats, FABs). No raw keys, no ISO dates, and no console errors of ours in any capture; the only console lines are the dev-environment noise listed under W3 (CSP on Vercel analytics and Google fonts in `next dev`, Google sign-in on the login page, the login page's own 401 / 403 / 404).

*Deviations (intended):* imperial users' 0,1 lb step is not built (the web has no unit switch; every weight is kg); the weight log has no note column (D-W0.19); the canvas' "Legjobb nap" is text, not a link; "kb. 3 pohár" says "glass" while the unit is the most used source's volume (the plan's rule); the water page keeps the old "egyéni mennyiség" field, which the canvas does not draw, so nothing the old page could do is lost. Not done: a true browser-zoom (200 %) pass, a real soft keyboard on a phone, a reduced-motion pass of the chart entrances beyond the DS token mechanism, and a side-by-side image of each canvas frame (compared by eye). The "fresh" account is not empty — it has one weigh-in and an odd 168 kg goal in its seed — so the empty weight page was checked with the stubbed responses above.

*Bugs* (closed in the commit that carries this entry):
- **W4.fix-1** — axe **color-contrast** on the goal-aware change chip in the light theme: `--improvement` (= `--m-protein`'s green, #34742F) on its 12 % tint was **4.19:1 on `--nested`** (the table's active row) and 4.34:1 on the page background; light `--improvement` is now #2F6B2A (4.70:1 on nested, 5.42:1 on card). Protein bars keep their green. After it all 160 captures have **0 serious / critical** findings.
- **W4.fix-2** — the log drawer's 72 px number drew a hard black focus box (the global unlayered `:focus-visible` rule beat the `outline-none` utility, the W0 gotcha again); the ring is now a primary 2 px shadow on the wrapper, the input's own outline inline-disabled.
- Found while building and fixed in place (see the step notes): Enter right after typing saved the previous value in the weight drawer and the water custom amount — `NumberField.onEnter` now passes the committed value (W4.4, W4.6); the goal-day ✓ of `LifeyBarChart` was an HTML icon inside an SVG and never rendered (W4.6); the plan's "one entry per date" is not a backend rule (W4.1); the old weight list, water entries and sources were deleted with no confirm and no undo (W4.3, W4.5).

### W5 — 2026-09-30 — Playwright Chromium (bundled, headless), 1440×1024 / 1280×800 / 1024×768 / 390×844

*Scope:* the real stack (Postgres, backend, `next dev`) with the handoff demo data, demo client `kata.nagy`. Six statistics states — week of 21 Sep, month (Sep), year 2026, year 2025 (nothing logged), the Cardio filter, the export popover — × **4 viewports × dark / light × HU / EN** = **96 captures** (the EN pass switched the account's language to ENGLISH through the API and restored it afterwards), each with console-error, horizontal-overflow (document *and* `<main>`), raw-key / ISO / `NaN` checks and **axe** (WCAG 2 A/AA): **0 console errors of ours, 0 overflow, 0 serious / critical axe findings** in all 96. Looked at by eye: HU 1440 dark week and export popover, EN 1440 light year, HU 1024 light month, EN 390 dark week, HU 390 light 2025. Flows on the real app: week → month → year and ‹ across periods with the URL following (`?period=…&start=…`), next disabled on the current period; Mind → Erősítő → Cardio (cards come and go, the calories card's text is identical before and after); the export with all four sets — four downloads named `lifey-2026-09-21_27-<set>.csv`, each with the UTF-8 BOM and `;` / decimal-comma rows — and the toast naming them. The dev-only console noise of W0–W4 is gone too: the 401 on `/client-config` before sign-in, the Vercel scripts blocked by the CSP and Google's button stylesheet (commit `console.fix`).

*Matches:* W5-A (top bar "Hét · Hónap · Év" + "‹ szept. 21–27. ›" + Exportálás; six KPI tiles with green / orange / grey chips — "−292 a célhoz", "javulás · előző hét +0,3", "+1 · előző hét 5", "+5 %", "±0 km", "+1 %"; "TÁPLÁLKOZÁS ÉS TEST" with bars, dashed goal, dotted average equal to the header's 1 608, legend; the weight line with its goal-off-scale footnote; "MOZGÁS" with the filter inside its header, volume bars with a rest-day dot, cardio bars with value labels, steps in one colour with the dashed goal); W5-B (hatched "Még nem naplóztál" band to 17 Aug, "ma" marker, "Nincs előző évi adat", weekly bars); W5-C (popover and toast); W5-D (full-width period switch, 2 × 2 KPIs, one chart per card, export icon). Both themes and languages legible; Y axes whole ("1,9 e / 950 / 0" · "1.9k / 950 / 0") at every width.

*Deviations (intended):* the canvas week is the week of 21–27 Sep with today on the Sunday; the app shows the real today, so the canvas' dashed "today" bar only appears while the viewed period is the current one. The Y axis tops follow `niceAxisMax` (two significant digits) rather than the canvas' "2,4 e". The hatched band is an overlay of `LifeyBarChart`, not a separate `NoDataBand` component. The KPI row is not filtered by the Mozgás filter (the canvas note says the filter must not reach outside its section). Not done: a true browser-zoom (200 %) pass, a reduced-motion pass of the chart entrances beyond the DS token mechanism, opening the exported CSVs in Excel / LibreOffice (no spreadsheet here).

*Bugs* (closed in the commit that carries this entry):
- **W5.fix-1** — the year view of a year *before* logging started (2025) still said "heti átlag · naplózás aug. 17.-től": the first-log date was global, not the viewed year's. It (and the hatched band) now exist only for the year the first meal falls in; `periodStats.test.ts` covers 2025 and 2027.
