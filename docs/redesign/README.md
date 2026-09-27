# Mobile redesign v2 — documentation

The second visual redesign of the Lifey mobile app. The design was produced by Claude Design
from the brief in [docs/design/21-design-modernization-prompt.md](../design/21-design-modernization-prompt.md);
the canvases in this folder are the **source of truth for values and layout**, and
[77-mobile-redesign-plan.md](77-mobile-redesign-plan.md) turns them into small, mergeable
steps. Status: **plan written, no code yet** (branch `feature/mobile-redesign`).

The canvases are `.dc.html` files that load `support.js` from this folder — open them in a
browser straight from disk. They are written in Hungarian; the plan is in English.

## Reading order

| File | What it covers | Who it's for |
|---|---|---|
| [77-mobile-redesign-plan.md](77-mobile-redesign-plan.md) | Decisions (D-R0.x), iterations R0–R7 with prompt-sized steps, non-goals, edge cases, test plan, silent-failure risks | **Start here.** Everyone |
| [Lifey Design System.dc.html](Lifey%20Design%20System.dc.html) | Principles, colour tokens (dark + light), metric colours, type scale, spacing, radius, elevation, motion, base components | R0 (foundation) |
| [Lifey 1 Dashboard.dc.html](Lifey%201%20Dashboard.dc.html) | Today screen — dark, light, Hungarian | R1 |
| [Lifey 2 Nutrition.dc.html](Lifey%202%20Nutrition.dc.html) | Meals + week strip, meal editor + add-food sheet, recipes, macros | R2 |
| [Lifey 3 Workouts.dc.html](Lifey%203%20Workouts.dc.html) | Sessions list, live strength + PR sheet, live cardio + cardio detail | R3 |
| [Lifey 4 Weight Stats.dc.html](Lifey%204%20Weight%20Stats.dc.html) | Weight (+ log sheet, light), statistics | R4 |
| [Lifey 5 Onboarding Chat Settings.dc.html](Lifey%205%20Onboarding%20Chat%20Settings.dc.html) | Login, onboarding steps 4–5, chat thread, settings + logout confirm | R5 |
| [Lifey 6 Trainer.dc.html](Lifey%206%20Trainer.dc.html) | Trainer clients, client detail, tablet layout | R6 |
| `support.js` | Runtime the canvases need to render — not app code | — |

## Iterations at a glance

| # | Name | Canvas | Milestones |
|---|---|---|---|
| R0 | Foundation: tokens, type, formatting, motion, components, header, nav, sheet, charts, gallery | Design System | M1, M2 |
| R1 | Dashboard | 1 | M3 — smallest worth-using slice |
| R2 | Nutrition | 2 | M4 |
| R3 | Workouts | 3 | M5 |
| R4 | Weight + Statistics | 4 | M6 |
| R5 | Auth, onboarding, chat, settings | 5 | M7 |
| R6 | Trainer view (phone + tablet) | 6 | M8 |
| R7 | Sweep undesigned screens, delete the old system, docs | — | M9 |
