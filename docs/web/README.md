# Lifey Web

Ez a mappa a Lifey **webes felületének** tervezési dokumentációját tartalmazza.

A webes kliens a meglévő **Spring Boot REST API-t** fogyasztja (ugyanazt, amit a Flutter mobil app). A backend nem íródik újra — a web egy új kliens a már létező `/api/v1/...` végpontokhoz.

## Stack (rövid összefoglaló)

| Réteg | Választás |
|---|---|
| Framework | **Next.js (App Router) + TypeScript** |
| UI | **Tailwind CSS + shadcn/ui** |
| Szerver-state / API | **TanStack Query** + saját fetch wrapper (token refresh interceptorral) |
| Form + validáció | **React Hook Form + Zod** |
| Grafikonok | **Recharts** |
| i18n | **next-intl** (a backend `settings.language` mezőjéhez illesztve) |
| Auth | JWT access token memóriában + refresh token **httpOnly cookie**-ban |
| Tesztelés | **Vitest** (unit) + **Playwright** (E2E) |
| Hosting | **Vercel** (vagy self-host Docker) |

## Dokumentumok

A `01`–`03` a magas szintű terv (mit / milyen sorrendben / hogy nézzen ki), a `04`–`09` a **mélyebb
technikai tervezet** (hogyan épül fel, pontos API-szerződés, design-implementáció, képernyő-specifikációk,
backend-hiányok, feladat-lebontás).

| Fájl | Tartalom |
|---|---|
| [`01-feature-inventory.md`](01-feature-inventory.md) | A jelenlegi funkciók leltára → mi használható weben, mi maradjon mobil-only, és a jövőbeli edző-rész vázlata |
| [`02-development-plan.md`](02-development-plan.md) | Fázisokra (F0–F10) bontott fejlesztési tervezet + mérföldkövek |
| [`03-design-brief.md`](03-design-brief.md) | Design tervezet a **Claude design**-nak: a mobil szín-/komponens-tokenek + webre optimalizált, adatdús elrendezés, funkciónként |
| [`04-frontend-architecture.md`](04-frontend-architecture.md) | Frontend architektúra: renderelés, mappa-struktúra, állapotkezelés, auth/token-életciklus, hibamodell, idő-/témakezelés, tesztelés |
| [`05-api-integration.md`](05-api-integration.md) | Pontos API-szerződés a tényleges backend kontrollerekből/DTO-kból: végpontok, enumok, TanStack Query kulcsok + invalidáció, ismert korlátok |
| [`06-design-system-web.md`](06-design-system-web.md) | Design tokenek → CSS változók / Tailwind + a mockupból kiemelt komponens-könyvtár (prop-szerződésekkel) |
| [`07-screen-specifications.md`](07-screen-specifications.md) | Képernyőnkénti spec a `Lifey Web.dc.html` 17 frame-je alapján (elrendezés, komponensek, adat, állapotok) |
| [`08-backend-gaps-and-changes.md`](08-backend-gaps-and-changes.md) | Mit nem tud a jelenlegi API, és milyen backend-változás kell a design teljes megvalósításához (döntésekkel) |
| [`09-task-breakdown.md`](09-task-breakdown.md) | Sprintekre/feladatokra bontott, pipálható lebontás függőségekkel és „definition of done"-nal |

> Forrás design: [`../design/design-handoff/design-terv-kidolgoz-sa/project/Lifey Web.dc.html`](../design/design-handoff/design-terv-kidolgoz-sa/project/Lifey%20Web.dc.html) (17 frame: tokenek, app-shell, dashboard, nutrition, workouts, statisztika, weight/water/steps, settings, auth, állapotok).

## Scope

- **1. fázis (most):** egyfelhasználós web — saját magamnak, a meglévő funkciók webes elérése.
- **2. fázis (később, röviden tervezve):** szerepkörök (`ROLE_TRAINER`), kliens-hozzárendelés személyi edzőkhöz.
