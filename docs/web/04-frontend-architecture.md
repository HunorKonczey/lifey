# Lifey Web — Frontend architektúra (technikai)

> Ez a dokumentum a **hogyan épül fel** kérdésre felel: futási modell, mappa-struktúra,
> állapotkezelés, auth/token-életciklus, API-kliens, hibamodell, i18n, témázás, routing.
> A *mit* (funkciók) a [`01-feature-inventory.md`](01-feature-inventory.md), a *milyen sorrendben*
> a [`02-development-plan.md`](02-development-plan.md), a *hogy nézzen ki* a
> [`06-design-system-web.md`](06-design-system-web.md) + [`07-screen-specifications.md`](07-screen-specifications.md).

---

## 1. Alapelvek

1. **Online-first.** Nincs offline cache, nincs lokális DB-szinkron (ellentétben a mobillal).
   Minden adat élőben jön a `/api/v1/...` REST API-ból. Ebből következik: minden adatos
   nézethez **skeleton / empty / error** állapot kell (lásd design brief §2.9).
2. **A backend nem változik a web kedvéért, ha elkerülhető.** Ahol mégis kell backend-módosítás
   (CORS, refresh-cookie, lapozás, statisztika-idősor), azt a
   [`08-backend-gaps-and-changes.md`](08-backend-gaps-and-changes.md) gyűjti egy helyre, döntéssel.
3. **Feature-alapú csomagolás**, ami tükrözi a backend `com.lifey.<feature>` szerkezetét — így a
   két oldal mentális modellje egyezik.
4. **Típusbiztonság végig.** A backend DTO-k → Zod sémák → TS típusok. A séma az igazságforrás
   futásidőben (validálja az API-választ is), a típus build időben.
5. **Szerepkör-kész.** Az auth ma `ROLE_USER`/`ROLE_ADMIN`, de a JWT `roles` claim bővíthető.
   A frontendet úgy építjük, hogy a `ROLE_TRAINER` (F10) ráépülés, ne átépítés legyen.

---

## 2. Tech stack és indoklás

| Réteg | Választás | Indok |
|---|---|---|
| Framework | **Next.js 15 (App Router) + React 19, TypeScript** | route-groupok, middleware-alapú auth-guard, SSR/CSR keverhető |
| Renderelés | **döntően CSR a védett appban**, SSR csak a shellnek | az adat user-specifikus és élő → nincs értelme szerver-cache-elni; lásd §3 |
| UI primitívek | **Tailwind CSS v4 + shadcn/ui (Radix alatta)** | hozzáférhető primitívek, token-vezérelt témázás CSS változókkal |
| Szerver-state | **TanStack Query v5** | cache, refetch, optimistic update, query-invalidáció a REST mutációkhoz |
| Form + validáció | **React Hook Form + Zod** | a backend Bean Validation szabályok 1:1 leképezhetők (lásd `05`) |
| Grafikon | **Recharts** | súly/statisztika idősorok, area/line/bar; reszponzív konténer |
| Drag & drop | **dnd-kit** | edzéssablon gyakorlat-sorrend (mockup 08. frame) |
| i18n | **next-intl** | HU/EN, a `settings.language`-hez kötve |
| Dátum | **date-fns** (+ `date-fns-tz`) | a backend `Instant`/`LocalDate` kezeléshez, lokál-nap határhoz (lásd §6) |
| Ikon | **Material Symbols Rounded** | a mobil ikonkészlet azonossága (mockup ezt használja) |
| Teszt | **Vitest** (unit) + **Playwright** (E2E) | sémák/hookok + fő user-flow-k |
| Lint/format | **ESLint + Prettier** | |
| Hibakövetés | **Sentry** (F8) | |
| Hosting | **Vercel** vagy Docker self-host | |

> Új framework bevezetése a root `CLAUDE.md` szerint indoklást igényel — a fentiek mind a
> brief-ben/dev-tervben már rögzített választások kibontásai, nem új irány.

---

## 3. Renderelési stratégia (Next.js App Router)

A védett app **kliensoldali** (`"use client"` a data-komponenseknél), mert:
- minden adat a bejelentkezett userhez kötött és gyakran változik (élő naplózás),
- a token memóriában él (nem szerver-session), így a szerver nem tud a user nevében fetch-elni
  anélkül, hogy a tokent cookie-ba tennénk — és az access tokent **nem** tesszük cookie-ba.

| Réteg | Render | Megjegyzés |
|---|---|---|
| `(auth)/login`, `register` | SSR shell + CSR form | publikus, statikusan kiszolgálható váz |
| `(app)/layout` (sidebar+topbar) | SSR shell, CSR data | a navigáció statikus, a user-menü adata kliensből |
| `(app)/**` oldalak | CSR + TanStack Query | skeleton SSR-ből, adat hidráció után |
| `middleware.ts` | Edge | csak a refresh-cookie **jelenlétét** nézi → guard (lásd §5.4) |

**Streaming/Suspense:** a lista- és grafikon-szekciókat `Suspense` + skeleton fallback alá tesszük,
hogy a shell azonnal megjelenjen, az adatpanelok pedig fokozatosan töltsenek.

---

## 4. Mappa-struktúra (cél)

A monorepo bővül egy gyökér `web/` mappával (a `mobile/` és `backend/` mellé).

```
web/
  src/
    app/
      (auth)/
        login/page.tsx
        register/page.tsx
        layout.tsx               # centrált, márkás auth-váz
      (app)/
        layout.tsx               # sidebar + topbar shell, auth-guard
        dashboard/page.tsx
        nutrition/page.tsx       # ?tab=foods|meals|recipes
        workouts/page.tsx        # ?tab=sessions|templates|exercises
        weight/page.tsx
        water/page.tsx
        steps/page.tsx
        statistics/page.tsx
        settings/[section]/page.tsx
      layout.tsx                 # <html>, providerek, téma, i18n
      globals.css                # @theme tokenek (lásd 06)
    features/
      <feature>/                 # auth, dashboard, nutrition, workouts,
        api.ts                   #   weight, water, steps, statistics, settings
        queries.ts               # useXxxQuery hookok (TanStack)
        mutations.ts             # useXxxMutation + invalidáció
        schemas.ts               # Zod request/response sémák
        types.ts                 # z.infer<> típusok
        components/              # feature-specifikus UI
    components/
      ui/                        # shadcn/ui generált primitívek
      app/                       # Sidebar, TopBar, DatePicker, ThemeToggle, UserMenu
      data/                      # StatCard, MacroRing, WaterCard, DataTable,
                                 #   TimeSeriesChart, SegmentedControl, MasterDetail
      states/                    # Skeletonok, EmptyState, ErrorState, RetryBoundary
    lib/
      api/
        client.ts                # fetch wrapper (auth + refresh interceptor)
        errors.ts                # ApiError típus, backend hibaformátum leképezés
        queryClient.ts           # QueryClient + defaultOptions
        queryKeys.ts             # központi query-kulcs gyár (lásd 05)
      auth/
        session.ts               # token store (memória) + useSession()
        refresh.ts               # single-flight refresh queue
      format/                    # szám/dátum/mértékegység formázók
      env.ts                     # NEXT_PUBLIC_* validált betöltés (Zod)
    i18n/
      request.ts                 # next-intl konfig
      messages/{hu,en}.json
    middleware.ts                # route guard
  public/
  .env.local
  package.json
```

---

## 5. Auth & token-életciklus

### 5.1 A backend ma
- `POST /auth/login` → `AuthResponse { accessToken, refreshToken, tokenType:"Bearer", expiresIn }`.
- `POST /auth/refresh { refreshToken }` → új pár (**rotáció**: a régi refresh érvénytelenül).
- `POST /auth/logout { refreshToken }` → az adott refresh visszavonása.
- `POST /auth/logout-all` → a user összes refresh tokenje vissza (hitelesített kéréssel).
- A **refresh token jelenleg a válasz body-ban** jön (nincs cookie-támogatás).

### 5.2 Tárolási modell (web)
- **Access token: memóriában** (modul-szintű változó / Query cache), soha nem `localStorage`-ban
  (XSS-felület csökkentés). Lapfrissítéskor elveszik → a refresh-ből épül újra.
- **Refresh token: két opció** (döntés a `08`-ban):
  - **A) httpOnly + Secure + SameSite cookie (ajánlott).** Backend-módosítást igényel
    (`Set-Cookie` a login/refresh válaszban, a `/refresh` és `/logout` olvassa a cookie-ból).
    JS nem fér hozzá → XSS-védettebb. Ekkor a `middleware.ts` is tud guardolni.
  - **B) memória + `sessionStorage` fallback (gyors start).** Nincs backend-módosítás, de
    XSS-érzékenyebb és lapfrissítés után csak `sessionStorage`-ból menthető.
  - → Indulj **A)**-val; ha a backend-cookie csúszik, B) átmenetnek elég.

### 5.3 Refresh interceptor (single-flight)
A `lib/api/client.ts` minden választ figyel:
1. `401` érkezik → ha **nincs** folyamatban refresh, indít egyet (`POST /refresh`).
2. Közben érkező további `401`-ek **ugyanarra a refresh-promise-ra várnak** (queue), nem indítanak
   párhuzamos refresh-t (különben a rotáció miatt egymást érvénytelenítenék).
3. Refresh siker → az új access tokennel **az eredeti kérések újrajátszása**.
4. Refresh bukás → token store ürítése + redirect `/login`-ra, a függő kérések elutasítása.

### 5.4 Route-védelem
- **Edge `middleware.ts`:** csak a refresh-cookie (A opció) jelenlétét ellenőrzi; ha nincs és a
  cél `(app)/**`, redirect `/login`. Ez gyors, de **nem** hitelesít — a valódi védelmet a kliens
  `useSession()` + a 401→refresh ciklus adja.
- **Kliens guard:** `(app)/layout.tsx` a mountkor megpróbál refresh-elni; siker → render, bukás →
  redirect. A `useSession()` adja a `user`-t és a `roles`-t (RBAC-hoz, F10).

---

## 6. Idő- és dátumkezelés (kritikus)

A backend kétféle időtípust használ — ezt a webnek konzisztensen kell kezelnie:

| Mező | Típus | Web-kezelés |
|---|---|---|
| `meal.dateTime`, `waterEntry.consumedAt`, `session.startedAt/finishedAt`, `exerciseSet.performedAt` | `Instant` (UTC, ISO-8601) | `Date` ↔ ISO string; megjelenítés **lokál időzónában** |
| `weight.date`, `steps.date` | `LocalDate` (`yyyy-MM-dd`) | **időzóna nélkül**, naptári nap; ne konvertáld UTC-re |
| Statisztika `?date=` query | `LocalDate` | **a kliens lokál napját** küldd (a backend a nap-határt ehhez igazítja, lásd `StatisticsController` doc) |

> A globális topbar-dátumválasztó értéke `LocalDate` szemantikájú. A daily statisztikát és a napi
> naplókat erre a napra szűrjük; a meal-/water-listák `Instant`-jeit a kiválasztott lokál-napra
> kell szűrni **kliensoldalon** (a backend ezekre nem ad dátum-szűrőt — lásd `08`).

---

## 7. Hibamodell

A backend `GlobalExceptionHandler`-jét a `lib/api/errors.ts` egységes `ApiError`-rá képezi:

```ts
class ApiError extends Error {
  status: number;            // HTTP
  code?: string;             // backend hibakód, ha van
  fieldErrors?: Record<string,string>; // Bean Validation mező-hibák → RHF setError
  retriable: boolean;        // 5xx / hálózati → "Újra" gomb; 4xx → nem
}
```

- **422/400 mező-hibák** → a Zod/RHF űrlapba (`setError` mezőnként).
- **401** → refresh-ciklus (§5.3), nem ér a UI-ig, ha sikerül.
- **403** → "nincs jogosultság" (F10 RBAC-nál releváns).
- **404** → üres/„nem található" állapot.
- **5xx / network** → `ErrorState` + „Újra" (a mockup 04/17. frame szerint).

A TanStack Query `retry`-t a `retriable` flaghez kötjük (4xx-re nincs retry).

---

## 8. Témázás és i18n

- **Téma:** CSS változók (`:root` = sötét hős, `[data-theme="light"]` = világos), a tokenek a
  [`06-design-system-web.md`](06-design-system-web.md) §1 szerint. A `settings.theme`
  (`LIGHT`/`DARK`/`SYSTEM`) vezérli; `SYSTEM` → `prefers-color-scheme`. SSR-nél FOUC-elkerülés
  egy inline script-tel a `<head>`-ben (a tárolt/rendszer témát a hidráció előtt rárakja).
- **i18n:** `next-intl`, `messages/hu.json` + `messages/en.json`. Az aktív nyelv a
  `settings.language` (`HUNGARIAN`/`ENGLISH`/`SYSTEM`). A `SYSTEM` a böngésző `navigator.language`-ét
  veszi. A számok/dátumok `Intl` API-val, **tabular figures** a metrikákhoz.

---

## 9. Tesztelési stratégia (összefoglaló — részletek a 09-ben)

- **Unit (Vitest):** Zod sémák (kerek- és peremesetek), formázók, `queryKeys`, refresh-queue logika.
- **Komponens (Vitest + Testing Library):** StatCard cél-tónus, DataTable rendezés/lapozás,
  állapot-komponensek.
- **E2E (Playwright):** login → nap naplózása (meal) → edzés naplózása (session) → statisztika →
  logout. Mock vagy ephemerális backend ellen.

---

## 10. Teljesítmény és minőség

- Route-szintű kód-szeletelés (App Router alapból), nehéz grafikon-kód lazy import.
- TanStack Query `staleTime` finomhangolás per-feature (pl. `exercises` ritkán változik → hosszú
  stale; `meals` az aktív napon → rövid).
- Kép/ikon: Material Symbols variable font egyszer, `font-display: swap`.
- A11y: Radix primitívek, fókuszgyűrűk a token szerint, billentyűnavigáció a táblázatokban,
  kontraszt-ellenőrzés mindkét témára.
