# Watch redesign — documentation

The redesign of the Lifey **watch apps** (Apple Watch, SwiftUI · Wear OS, Compose) onto the mobile Design
System v2. The design was produced by Claude Design from the brief in
[watch-redesign-prompt.md](watch-redesign-prompt.md); the canvases in this folder are the **source of truth
for values and layout**, and [79-watch-redesign-plan.md](79-watch-redesign-plan.md) turns them into small,
mergeable steps. Branch: `feature/watch-redesign`.

The canvases are `.dc.html` files that load `support.js` from this folder (a copy of
`../redesign-web/support.js`, identical to `../redesign/support.js`). Serve the folder and open them in a
browser:

```bash
python -m http.server 5520 --directory docs/redesign-watch
```

They are written in Hungarian; the plan is in English. The design-system canvas links the mobile
`Lifey Design System.dc.html`, which lives in [`../redesign/`](../redesign/Lifey%20Design%20System.dc.html)
(not copied here; the canvas files are not edited).

## Reading order

| File | What it covers | Iteration |
|---|---|---|
| [79-watch-redesign-plan.md](79-watch-redesign-plan.md) | Decisions (D-X0.x), frame index, iterations with prompt-sized steps, review procedure, review log (§12) | **Start here** |
| [watch-redesign-prompt.md](watch-redesign-prompt.md) | The brief given to Claude Design (HU) | Background |
| [Lifey Watch Design System.dc.html](Lifey%20Watch%20Design%20System.dc.html) | Tokens, type, shape, 15 components, pages + crown, missing HR, motion + haptics, Always-On | X0a, X0w |
| [Lifey Watch 1 Apple Watch Strength.dc.html](Lifey%20Watch%201%20Apple%20Watch%20Strength.dc.html) | AW1.1–AW1.22 phone-driven strength | X1 |
| [Lifey Watch 2 Apple Watch Start Standalone Cardio.dc.html](Lifey%20Watch%202%20Apple%20Watch%20Start%20Standalone%20Cardio.dc.html) | AW2.1–AW2.25 start, standalone, cardio, errors, AOD | X2 |
| [Lifey Watch 3 Wear OS Strength.dc.html](Lifey%20Watch%203%20Wear%20OS%20Strength.dc.html) | W1.1–W1.16 phone-driven strength, round | X3 |
| [Lifey Watch 4 Wear OS Start Standalone Cardio.dc.html](Lifey%20Watch%204%20Wear%20OS%20Start%20Standalone%20Cardio.dc.html) | W2.1–W2.21 start, error, standalone, cardio, ambient | X4 |
| `support.js` | Runtime the canvases need to render — not app code | — |

## Iterations at a glance

| # | Platform | Canvas | Delivers |
|---|---|---|---|
| X0.0 | docs | — | Canvases openable, this README |
| X0a | Apple | Design System | v2 tokens, metrics, PJS numerals, motion/haptics, 15 components, AOD primitives, DEBUG gallery |
| X0w | Wear | Design System | Same on Wear + Material 3, scaffolding, tests, CI |
| X1 | Apple | 1 | Phone-driven strength workout |
| X2 | Apple | 2 | Start, standalone, cardio, errors, Always-On |
| X3 | Wear | 3 | Phone-driven strength workout |
| X4 | Wear | 4 | Start, error, standalone, cardio, ambient; Material 2 removed |

Each iteration ends with a review against its canvas frames (plan §4), logged in plan §12.
