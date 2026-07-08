# Lifey Web — Részletes fejlesztési tervezet

Cél: a meglévő Lifey funkciók elérése **webes felületen**, kezdetben egyfelhasználós módban (saját magamnak), úgy felépítve, hogy a későbbi **személyi edző** szerepkör ráépíthető legyen.

A backend (Spring Boot REST API + JWT/refresh + PostgreSQL) **marad**. A web egy új kliens.

A terv fázisokra (`F0`–`F10`) van bontva. Minden fázis önállóan szállítható (deployolható) értéket ad. A lépések szándékosan apró, ellenőrizhető egységek.

---

## Tech stack

| Réteg | Választás | Indok |
|---|---|---|
| Framework | Next.js (App Router) + TypeScript | SSR + statikus oldalak, routing, nagy ökoszisztéma |
| UI | Tailwind CSS + shadcn/ui | gyors, konzisztens, nem zár be |
| Szerver-state | TanStack Query | cache, refetch, optimistic update a REST API-hoz |
| Form | React Hook Form + Zod | típusbiztos űrlapok, backend DTO-khoz illeszthető |
| Grafikon | Recharts | súly/statisztika diagramok |
| i18n | next-intl | a `settings.language`-hez kötve |
| HTTP | natív `fetch` wrapper | access token + automatikus refresh interceptor |
| Teszt | Vitest + Playwright | unit + E2E |
| Lint/format | ESLint + Prettier | |
| Hosting | Vercel (vagy Docker self-host) | |

---

## Mappa-struktúra (cél)

A monorepo bővül egy `web/` mappával (a `mobile/` és `backend/` mellé). A web belül **feature-alapú** csomagolás, hogy tükrözze a backendet.

```
web/
  src/
    app/                      # Next.js App Router (routes)
      (auth)/login, register
      (app)/dashboard, nutrition, workouts, weight, water, steps, statistics, settings
    features/                 # feature-alapú: auth, nutrition, workouts, weight, water, steps, statistics, settings
      <feature>/
        api.ts                # végpont-hívások
        hooks.ts              # TanStack Query hookok
        components/
        schemas.ts            # Zod sémák
        types.ts
    components/ui/            # shadcn/ui
    lib/                      # apiClient, auth, query-client, utils
    i18n/                     # next-intl konfig + üzenetek
  public/
  .env.local
```

---

## F0 — Alapozás és infrastruktúra

1. `web/` mappa létrehozása a monorepóban.
2. Next.js projekt init: `create-next-app` (App Router, TypeScript, ESLint, Tailwind, `src/` dir).
3. Prettier + ESLint szabályok beállítása, `format`/`lint` scriptek.
4. Tailwind + **shadcn/ui** init; alap komponensek hozzáadása (button, input, dialog, card, table, toast, dropdown).
5. **Design tokenek** átemelése a meglévő design rendszerből (`docs/design/18-design-system-prompt.md`) → színek, tipográfia, spacing Tailwind configba.
6. TanStack Query provider beállítása (`QueryClientProvider`, dev tools).
7. `.env.local`: `NEXT_PUBLIC_API_BASE_URL` (lokál: `http://localhost:8080`).
8. **API client** (`lib/apiClient.ts`): bázis URL, JSON helperek, hibakezelés (a backend `GlobalExceptionHandler` válaszformátumához igazítva).
9. Alap layout shell: üres `(app)` layout placeholderrel (sidebar + header jön F1-ben).
10. Git: `web/` hozzáadása, alap CI lépés (`lint` + `build`) — lásd F9.

### Backend oldali előfeltételek (kis változások)
11. **CORS** konfiguráció: a web origin engedélyezése (`localhost:3000` dev, prod domain). Spring Security `CorsConfigurationSource` — `allowCredentials=true` a cookie-hoz.
12. **Refresh token web-re:** ma a refresh token a válasz body-ban jön. Webhez biztonságosabb **httpOnly + Secure + SameSite cookie**. Döntés:
    - **A) Cookie (ajánlott):** backend a `/login` és `/refresh` válaszban `Set-Cookie`-val küldi a refresh tokent; a web nem fér hozzá JS-ből (XSS-védettebb). Kis backend-módosítás.
    - **B) Body (gyorsabb start):** a web a refresh tokent memóriában/`localStorage`-ban tárolja. Egyszerűbb, de XSS-re érzékenyebb.
    - → Indulj **A)**-val, ha belefér; különben B) és később migrálj.

**F0 kész, ha:** a Next.js app elindul, eléri a backend egy public végpontját CORS hiba nélkül.

---

## F1 — Auth és app-váz

13. Zod sémák: `loginSchema`, `registerSchema`.
14. `features/auth/api.ts`: `register`, `login`, `refresh`, `logout`, `logoutAll`.
15. **Login oldal** (`/login`): React Hook Form + Zod, hibakijelzés, loading state.
16. **Register oldal** (`/register`).
17. **Token-tárolás:** access token memóriában (React state / Query cache); refresh az F0-ban választott módon.
18. **Refresh interceptor:** 401 esetén automatikus `POST /refresh`, majd az eredeti kérés újrajátszása; ha a refresh is bukik → kiléptetés a loginra. Egyidejű 401-ek esetén egyetlen refresh (request queue).
19. **Auth context / session hook:** `useSession()` (bejelentkezett user, szerepkörök).
20. **Védett útvonalak:** Next.js `middleware.ts` + `(app)` route group; nem bejelentkezett user → `/login`.
21. **App shell:** reszponzív **sidebar** (Dashboard, Nutrition, Workouts, Weight, Water, Steps, Statistics, Settings) + header (user menü, logout).
22. **Logout** és **logout-all** bekötése a header/settings menübe.
23. **i18n setup** (next-intl): nyelvi fájlok (HU/EN), nyelv a `settings.language`-ből; nyelvváltó.
24. Globális UI állapotok: toast (siker/hiba), loading skeletonok, üres állapotok, hibahatár (error boundary).

**F1 kész, ha:** be tudok jelentkezni, a session a refresh-sel életben marad, a védett oldalak működnek, ki tudok lépni.

---

## F2 — Dashboard

25. `features/statistics/api.ts` + hookok: `daily`.
26. Adat-aggregálás a dashboardhoz (párhuzamos query-k: meals, weights, water, steps, sessions, statistics/daily).
27. **Napi kalória + makró kártya** (cél vs. aktuális, progress).
28. **Aktuális testsúly kártya** + mini trend.
29. **Vízbevitel kártya** (mai mennyiség, gyors +/- gomb).
30. **Lépésszám kártya** (mai érték).
31. **Legutóbbi edzések** lista (utolsó N session).
32. Dátumváltó (ma / korábbi nap megtekintése).
33. Reszponzív elrendezés (desktop grid → mobil egymás alá).

**F2 kész, ha:** a dashboard egy pillantásra mutatja a nap állapotát valós adatból.

---

## F3 — Nutrition (ételek, receptek, étkezések)

34. `features/nutrition` API + hookok minden végponthoz (foods, recipes, meals).
35. **Ételek lista** (foods): kereshető táblázat, lapozás (a backend pagination-höz igazítva — `docs/14-pagination-plan.md`).
36. **Étel létrehozás/szerkesztés** modal (kalória, fehérje stb.), Zod validációval.
37. **Vonalkód lekérés** mező: kézi vonalkód beírása → `GET /foods/barcode/{barcode}` → kitöltés.
38. Étel **rejtése** (hidden) kapcsoló.
39. **Receptek lista** + kedvenc szűrő.
40. **Recept szerkesztő:** hozzávalók (foods) hozzáadása, adagszám (servings), számolt összérték.
41. Recept **kedvenc** jelölés.
42. **Étkezés-napló** (meals): napi nézet étkezésekre bontva (reggeli/ebéd/…), név szerint.
43. Étkezés **hozzáadása** ételből vagy receptből, mennyiséggel; élő kalória/fehérje összesítés.
44. Étkezés szerkesztés/törlés; optimistic update.

**F3 kész, ha:** weben létre tudok hozni ételt/receptet és teljes napot tudok naplózni.

---

## F4 — Workouts (gyakorlatok, sablonok, munkamenetek)

45. `features/workouts` API + hookok (exercises, templates, sessions).
46. **Gyakorlat-könyvtár** (exercises): lista kategória + eszköz szűrővel; CRUD.
47. **Edzéssablon-szerkesztő** (templates): gyakorlatok hozzáadása, **cél-szettek**, **sorrend** (drag & drop — weben kényelmes).
48. **Munkamenet indítása** sablonból vagy üresen.
49. **Aktív edzés naplózó:** szett/ismétlés/súly bevitel, gyors léptetés, pihenőidő (lásd `docs/15-set-rest-time-plan.md`).
50. **Edzés mentése** mint session; health mezők olvashatóként (ha vannak).
51. **Edzéselőzmények** lista + egy session részletes nézete.
52. Gyakorlatonkénti **progresszió** (utolsó alkalmak súly/ismétlés trendje).

**F4 kész, ha:** sablont tudok szerkeszteni és egy edzést végig tudok naplózni weben.

---

## F5 — Testsúly, Víz, Lépés

53. **Testsúly:** bevitel (dátummal), előzménytáblázat, **trend grafikon** (Recharts), törlés.
54. **Víz:** források (water-sources) kezelése (CRUD); gyors hozzáadó gombok forrásonként; napi összesítés; bejegyzés törlés.
55. **Lépés:** napi érték megtekintése + **kézi bevitel/szerkesztés** (a mobil szenzoros adat web-only nézete).

**F5 kész, ha:** mindhárom metrikát tudom rögzíteni és előzményben látni.

---

## F6 — Statisztika

56. `statistics` heti/havi hookok.
57. **Idősáv-választó:** napi / heti / havi.
58. **Kalória + makró trend** grafikon az időszakra.
59. **Súlytrend** grafikon.
60. **Edzésvolumen / gyakoriság** grafikon.
61. **Víz / lépés** trendek.
62. Időszak-összehasonlítás (pl. ez a hét vs. előző) — a nagy képernyő előnyét kihasználva.

**F6 kész, ha:** több időtávon átlátom a haladásom egy oldalon.

---

## F7 — Beállítások

63. **Profil:** alapadatok megjelenítés/szerkesztés.
64. **Célok:** napi lépéscél, kalória/fehérje cél (a `settings` mezőkből).
65. **Nyelv:** váltó, `PUT /settings`-be mentve, azonnali UI-frissítés.
66. **Megjelenés:** világos/sötét téma.
67. **Biztonság / munkamenetek:** jelszó (ha van végpont), **„kijelentkezés minden eszközről"** (`logout-all`).

**F7 kész, ha:** a beállítások a backendből jönnek és oda mentődnek.

---

## F8 — Minőség, reszponzivitás, hozzáférhetőség

68. **Reszponzív** ellenőrzés mobil böngészőre (sidebar → bottom nav / drawer kis kijelzőn).
69. **Sötét mód** végigvitele minden képernyőn.
70. **Loading / error / empty** állapotok minden listához.
71. **Hozzáférhetőség:** fókuszállapotok, billentyűzet-navigáció, ARIA, kontraszt.
72. **Unit tesztek** (Vitest): sémák, hookok, util-ek.
73. **E2E tesztek** (Playwright): login → étkezés naplózás → edzés naplózás → kijelentkezés.
74. **Teljesítmény:** kód-szeletelés, kép-optimalizálás, query cache hangolás.
75. **Hibakövetés:** Sentry (vagy hasonló) bekötése.

**F8 kész, ha:** a fő folyamatok zöld E2E-vel mennek, mobil böngészőn is használható.

---

## F9 — Build, CI/CD, deploy

76. **Környezeti változók** prod-ra (API URL, cookie domain).
77. **CORS és cookie** prod beállítás (azonos vagy al-domain a web és API közt a SameSite miatt).
78. **CI:** lint + típusellenőrzés + unit + build minden PR-en; E2E nightly.
79. **Deploy:** Vercel (web). Backend marad a meglévő helyén.
80. **Domain + HTTPS**, security headerek (CSP), HSTS.
81. **Monitoring/health** és alap analytics.

**F9 kész, ha:** a web élesben elérhető és a saját adataimat kezeli.

---

## F10 — Jövőbeli rész: Személyi edző (csak vázlat)

> Nem az 1. fázis része volt — időközben elkezdődött és a `docs/personal_trainer/` mappában részletes tervvé és megvalósítássá vált (PT0–PT5 fázisok, köztük az ütemezett edzések, elkészültek; ld. `07-utemterv-es-kockazatok.md`). Az alábbi vázlat az eredeti, kezdeti gondolatmenet — a tényleges lépések a `personal_trainer/` mappában részletesek. Az auth már szerepkör-alapú, így ez **ráépítés**, nem átépítés.

### Backend
82. **Új szerepkör** `ROLE_TRAINER` (és opcionálisan `ROLE_CLIENT`); a JWT `roles` claim már támogatja.
83. **Edző–kliens kapcsolat** tábla (Flyway migráció): `trainer_id`, `client_id`, státusz (meghívott/aktív), időbélyegek.
84. **Meghívó flow:** edző meghív egy klienst (e-mail/kód), kliens elfogad.
85. **Jogosultsági réteg:** az edző **csak a hozzárendelt kliensei** adatait éri el, **olvasásra** (a meglévő ownership-modell kiterjesztése; a kérés a hitelesített userből + kapcsolatból dől el, nem `userId` inputból).
86. **Terv-hozzárendelés:** edző edzéssablont / étrendet rendel a klienshez (új végpontok).
87. **Audit / adatvédelem:** ki mit látott, hozzájárulás (GDPR szempont).

### Web
88. **RBAC a frontenden:** szerepkör-alapú útvonal-védelem és menü (edző nézet vs. saját nézet).
89. **Edző dashboard:** kliensek listája, állapot, legutóbbi aktivitás.
90. **Kliens-részletek (read):** a kliens dashboard/statisztika megtekintése.
91. **Terv-kiosztás UI:** sablon/étrend hozzárendelés a klienshez.
92. **Meghívókezelés UI** (küldés, függőben lévők, visszavonás).

---

## Javasolt sorrend / mérföldkövek

- **M1 (alap használható):** F0 → F1 → F2 → F3 — be tudok jelentkezni és táplálkozást naplózok.
- **M2 (teljes napló):** F4 → F5 — edzés + súly/víz/lépés is megvan.
- **M3 (átlátás):** F6 → F7 — statisztika és beállítások.
- **M4 (éles):** F8 → F9 — minőség + deploy.
- **M5 (később):** F10 — személyi edző.

## Kockázatok / döntési pontok

- **Refresh token tárolása** (cookie vs. body) — biztonság vs. egyszerűség. Ajánlott: httpOnly cookie.
- **Vonalkód** weben — kézi beírás elég-e, vagy kell-e böngészős kamera-szken (WebRTC, kevésbé megbízható).
- **Pagination** — a web listák a meglévő backend lapozáshoz igazodjanak (`docs/14-pagination-plan.md`).
- **Kód-megosztás** mobil↔web — TypeScript típusokat érdemes lehet generálni az API-ból (pl. OpenAPI → TS), hogy ne kézzel tartsd karban.
