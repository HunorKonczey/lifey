# Web redesign — documentation

The redesign of the Lifey **web app** (Next.js, `web/`) onto the mobile Design System v2. The design was
produced by Claude Design from the brief in [web-redesign-prompt.md](web-redesign-prompt.md) (with the
309-page screenshot PDF of the current web as input); the canvases in this folder are the **source of
truth for values and layout**, and [78-web-redesign-plan.md](78-web-redesign-plan.md) turns them into
small, mergeable steps. Status: **done** (W0 – W10 on branch `feature/web-redesign`, one
long-lived PR collecting every step; the review log is §12 of the plan).

The canvases are `.dc.html` files that load `support.js` from this folder (a copy of
`../redesign/support.js`). Serve the folder and open them in a browser:

```bash
python -m http.server 5510 --directory docs/redesign-web
```

They are written in Hungarian; the plan is in English. The design-system canvas links the mobile
`Lifey Design System.dc.html`, which lives in [`../redesign/`](../redesign/Lifey%20Design%20System.dc.html).

## Reading order

| File | What it covers | Who it's for |
|---|---|---|
| [78-web-redesign-plan.md](78-web-redesign-plan.md) | Decisions (D-W0.x), frame index, iterations W0–W10 with prompt-sized steps, the mandatory iteration-end web UI review, non-goals, edge cases, test plan, silent-failure risks | **Start here.** Everyone |
| [web-redesign-prompt.md](web-redesign-prompt.md) | The brief given to Claude Design (HU) | Background |
| [Lifey Web Design System.dc.html](Lifey%20Web%20Design%20System.dc.html) | Web extension of v2: grid, one shell for three roles, top bar + date stepper, table, menu, modal, drawer, toast, fields, date picker, Recharts style, states, hover/focus/keyboard, formatting, motion | W0 |
| [Lifey Web 1 Dashboard.dc.html](Lifey%20Web%201%20Dashboard.dc.html) | Client dashboard — 1440 dark, 1024 light, 390, first steps | W1 |
| [Lifey Web 2 Nutrition.dc.html](Lifey%20Web%202%20Nutrition.dc.html) | Meal log + day summary, add-food modal, edit/delete/copy states, Foods table, Recipes, mobile | W2 |
| [Lifey Web 3 Workouts.dc.html](Lifey%20Web%203%20Workouts.dc.html) | Week log + session summary, live logger, RPE + celebration, cardio summary, template picker | W3 |
| [Lifey Web 4 Weight Water Steps.dc.html](Lifey%20Web%204%20Weight%20Water%20Steps.dc.html) | Weight (hero, chart, log, drawer), Water, Steps, mobile | W4 |
| [Lifey Web 5 Statistics.dc.html](Lifey%20Web%205%20Statistics.dc.html) | KPI row, honest charts, year view, export | W5 |
| [Lifey Web 6 Settings Auth Onboarding.dc.html](Lifey%20Web%206%20Settings%20Auth%20Onboarding.dc.html) | Login, trainer registration, onboarding, settings, logout | W6 |
| [Lifey Web 7 Trainer Clients.dc.html](Lifey%20Web%207%20Trainer%20Clients.dc.html) | Trainer clients, client detail (six tabs), inactive client, mobile | W7 |
| [Lifey Web 8 Calendar Programs Chat.dc.html](Lifey%20Web%208%20Calendar%20Programs%20Chat.dc.html) | Calendar week view, program editor, assign drawer, chat | W8 |
| [Lifey Web 9 Trainer Content Superadmin.dc.html](Lifey%20Web%209%20Trainer%20Content%20Superadmin.dc.html) | Trainer templates, invites, assigned plans, billing, superadmin | W9 |
| `support.js` | Runtime the canvases need to render — not app code | — |

## Iterations at a glance

| # | Name | Canvas | Milestones |
|---|---|---|---|
| W0 | Foundation: tokens, type, formatting, motion, components, shell for three roles, charts, keyboard, gallery | Web Design System | M1, M2 |
| W1 | Client dashboard | 1 | M3 — smallest worth-using slice |
| W2 | Nutrition | 2 | M4 |
| W3 | Workouts | 3 | M5 |
| W4 | Weight, water, steps | 4 | M6 |
| W5 | Statistics | 5 | M7 |
| W6 | Auth, onboarding, settings | 6 | M8 |
| W7 | Trainer: clients + client detail | 7 | M9 |
| W8 | Trainer: calendar, programs, chat | 8 | M10 |
| W9 | Trainer content, invites, billing, superadmin | 9 | M11 |
| W10 | Sweep undesigned screens, delete the old system, docs | — | M12 |

Every iteration ends with a web UI review in a real browser against its canvas frames (plan §4.1),
logged in plan §12.
