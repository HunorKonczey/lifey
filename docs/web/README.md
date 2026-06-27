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

| Fájl | Tartalom |
|---|---|
| [`01-feature-inventory.md`](01-feature-inventory.md) | A jelenlegi funkciók leltára → mi használható weben, mi maradjon mobil-only, és a jövőbeli edző-rész vázlata |
| [`02-development-plan.md`](02-development-plan.md) | Részletes, fázisokra bontott, sok lépéses fejlesztési tervezet |
| [`03-design-brief.md`](03-design-brief.md) | Design tervezet a **Claude design**-nak: a mobil szín-/komponens-tokenek + webre optimalizált, adatdús elrendezés, funkciónként |

## Scope

- **1. fázis (most):** egyfelhasználós web — saját magamnak, a meglévő funkciók webes elérése.
- **2. fázis (később, röviden tervezve):** szerepkörök (`ROLE_TRAINER`), kliens-hozzárendelés személyi edzőkhöz.
