# Lifey Web — Részletes feladat-lebontás

> A [`02-development-plan.md`](02-development-plan.md) a fázisokat (F0–F10) és a mérföldköveket adja.
> Ez a fájl ugyanazt **task-szintre** bontja: konkrét, pipálható feladatok, függőségek és
> „definition of done" (DoD). A technikai részleteket a [`04`](04-frontend-architecture.md)–
> [`08`](08-backend-gaps-and-changes.md) tartalmazza; itt csak hivatkozunk rájuk.

Jelölés: `[BE]` backend-munka (lásd `08`), `[FE]` frontend. Függőség: „⟸ #x".

---

## Sprint 0 — Alapozás (F0)

- [ ] `[FE]` Gyökér `web/` mappa + `create-next-app` (App Router, TS, ESLint, Tailwind, `src/`).
- [ ] `[FE]` Prettier + ESLint szabályok, `lint`/`format`/`typecheck` scriptek.
- [ ] `[FE]` shadcn/ui init + alap primitívek (button, input, dialog, table, tabs, dropdown, toast).
- [ ] `[FE]` Design tokenek `globals.css`-be (06 §1–§4): sötét/világos CSS változók, radius, type.
- [ ] `[FE]` `lib/env.ts` — `NEXT_PUBLIC_API_BASE_URL` validált betöltés (Zod).
- [ ] `[FE]` `lib/api/client.ts` váz (bázis URL, JSON helper, `ApiError` leképezés — 04 §7).
- [ ] `[FE]` TanStack Query provider + `queryClient` + `queryKeys` gyár (05 §12).
- [ ] `[FE]` Üres `(app)` layout placeholder (a valódi shell az F1-ben).
- [ ] `[BE]` **CORS** konfiguráció a web originre (08 §1). ⟸ blokkoló
- [ ] `[BE]` **Refresh-cookie** döntés + implementáció (08 §1, A opció). ⟸ blokkoló
- [ ] `[FE/BE]` `[BE]` OpenAPI→TS típusgenerálás pipeline (08 §8) — opcionális, de korán hasznos.

**DoD:** a Next.js app elindul, eléri a backend egy végpontját CORS-hiba nélkül, a tokenek a CSS-ben.

---

## Sprint 1 — Auth és app-váz (F1)

- [ ] `[FE]` Zod sémák: `loginSchema`, `registerSchema` (05 §2 validációkkal). ⟸ S0
- [ ] `[FE]` `features/auth/api.ts`: register/login/refresh/logout/logoutAll.
- [ ] `[FE]` **Token store** (memória) + `useSession()` (user, roles) — 04 §5.2.
- [ ] `[FE]` **Refresh interceptor** single-flight queue (04 §5.3). ⟸ refresh-cookie
- [ ] `[FE]` **Login** oldal (frame 16): RHF + Zod, loading, inline + toast hibák (07 §1).
- [ ] `[FE]` **Register** oldal.
- [ ] `[FE]` `middleware.ts` route-guard + `(app)` redirect (04 §5.4).
- [ ] `[FE]` **App-shell**: `<Sidebar>` (teljes + rail), `<TopBar>` (cím, `<DatePicker>`, `<ThemeToggle>`,
  `<UserMenu>`) — 07 §0. Logout/logout-all bekötve.
- [ ] `[FE]` **i18n** (next-intl) HU/EN váz + nyelvváltó a `settings.language`-ből.
- [ ] `[FE]` **Témázás** mechanizmus (04 §8): CSS-vars váltás, FOUC-elkerülő inline script, `SYSTEM`.
- [ ] `[FE]` Globális UI: toast, `<Skeleton>`/`<EmptyState>`/`<ErrorState>` komponensek (06 §6.3), error boundary.

**DoD:** be-/kijelentkezés működik, a session refresh-sel életben marad, védett oldalak guardoltak,
téma- és nyelvváltás megy.

---

## Sprint 2 — Dashboard (F2)

- [ ] `[FE]` `features/statistics` + `features/settings` API/hookok (daily, settings).
- [ ] `[FE]` Dashboard adat-aggregálás: párhuzamos query-k (meals, weights, water, steps, sessions,
  daily, settings) a topbar-dátumra (07 §2).
- [ ] `[FE]` `<HeroMetricCard>` (kalória, cél-tónus), `<MacroRing>` ×3.
- [ ] `[FE]` `<WaterCard>` (gyors „+", optimistic), lépés/testsúly `<StatCard>`.
- [ ] `[FE]` „Recent workouts" lista; jobb „This week" oszlop (mini-grafikonok, streak).
- [ ] `[FE]` Kártyánkénti skeleton / empty / error; dátumváltó újratölt.
- [ ] `[FE]` Reszponzív grid (desktop → tablet → mobil).

**DoD:** a dashboard egy pillantásra mutatja a kiválasztott nap állapotát valós adatból, minden
állapottal.

---

## Sprint 3 — Nutrition (F3)

- [ ] `[FE]` `features/nutrition` API/hookok (foods, recipes, meals) + Zod sémák (05 §3–§5).
- [ ] `[FE]` **Foods** `<DataTable>` (rendezés, kliens-lapozás), inline szerkesztő, `hidden` kapcsoló (07 §3.2).
- [ ] `[FE]` **Barcode** mező: `GET /foods/barcode/{barcode}` → LOCAL kitölt / OPENFOODFACTS előtölt → POST.
- [ ] `[FE]` **Recipes** rács + kedvenc szűrő + szerkesztő (hozzávalók, servings, számolt összérték) (07 §3.3).
- [ ] `[FE]` **Meals** napi napló `MasterDetail`: étkezés-csoportok + sticky daily summary (07 §3.1).
- [ ] `[FE]` Étkezés-tétel hozzáadás ételből/receptből, élő összeg, optimistic update.
- [ ] `[BE]` (opcionális, ajánlott) `GET /meals?date=` napi szűrő (08 §5). ⟸ enélkül kliens-szűrés.

**DoD:** weben létrehozható étel/recept és egy teljes nap naplózható; minden állapottal.

---

## Sprint 4 — Workouts (F4)

- [ ] `[FE]` `features/workouts` API/hookok (exercises, templates, sessions) + sémák (05 §6).
- [ ] `[FE]` **Exercises** lista kategória/eszköz szűrő-chipekkel + inline szerkesztő (07 §4.3).
- [ ] `[FE]` **Templates** `MasterDetail` szerkesztő: dnd-kit sorrend, cél-szettek, név (07 §4.1).
- [ ] `[FE]` **Session logger**: szett-táblázat (Set/Previous/Kg/Reps/✓), „Add set", finish; pihenőidő
  (`docs/15-set-rest-time-plan.md`); fokozatos PUT-mentés (07 §4.2).
- [ ] `[FE]` **Előzmények** + session-részlet; health mezők **olvashatóként**.
- [ ] `[FE]` **Gyakorlat-progresszió** mini-trend (session-előzményből számolva).

**DoD:** sablon szerkeszthető drag&drop-pal, egy edzés végig naplózható weben.

---

## Sprint 5 — Weight / Water / Steps (F5)

- [ ] `[FE]` **Weight**: trend `<TimeSeriesChart>` (1M/3M/1Y, cél-vonal) + history lista + „+ entry" (07 §5).
- [ ] `[BE]` (opcionális) Weight upsert/azonos-nap viselkedés tisztázása (08 §6).
- [ ] `[FE]` **Water**: összegző + gyors „+" források szerint + sources CRUD (07 §6); optimistic.
- [ ] `[FE]` **Steps**: mai érték + kézi „Edit" + 7-napos oszlopdiagram, cél-vonal (07 §7).

**DoD:** mindhárom metrika rögzíthető és előzményben látszik, minden állapottal.

---

## Sprint 6 — Statisztika (F6)

- [ ] `[BE]` **Statisztika idősor** végpont (08 §2, A opció). ⟸ a trend-grafikonokhoz blokkoló
- [ ] `[FE]` `statistics` heti/havi/series hookok; idősáv-szegmens (Week/Month/Year).
- [ ] `[FE]` KPI-sor (`<KpiCard>` ×4) trend-deltával; export gomb.
- [ ] `[FE]` Grafikon-rács (kalória+makró, súly, volumen, víz+lépés) — 07 §8.
- [ ] `[FE]` Időszak-összehasonlítás (ez vs. előző); grafikononként skeleton/empty/error.

**DoD:** több időtávon, valós idősorból átlátható a haladás egy oldalon.

---

## Sprint 7 — Beállítások (F7)

- [ ] `[FE]` Settings `MasterDetail` al-navigáció (Profile/Daily goals/Units/Theme/Language/Security) (07 §9).
- [ ] `[FE]` Daily goals mezők + mentés `PUT /settings`; érintett nézetek invalidálása.
- [ ] `[FE]` Units / Theme / Language szegmensek (azonnali alkalmazás).
- [ ] `[FE]` Security: logout-all; profil/jelszó mezők olvashatók, amíg nincs végpont (08 §7).

**DoD:** a beállítások a backendből jönnek és oda mentődnek; téma/nyelv azonnal vált.

---

## Sprint 8 — Minőség / reszponzivitás / a11y (F8)

- [ ] `[FE]` Reszponzív ellenőrzés mobil böngészőn (sidebar → drawer/alsó nav, master-detail szétesés).
- [ ] `[FE]` Sötét + világos téma végigvitele minden képernyőn.
- [ ] `[FE]` Minden listához loading/empty/error (audit).
- [ ] `[FE]` A11y: fókuszgyűrűk, billentyűnavigáció (táblázat, drag&drop), ARIA, kontraszt.
- [ ] `[FE]` Unit tesztek (Vitest): sémák, formázók, refresh-queue, queryKeys.
- [ ] `[FE]` E2E (Playwright): login → meal naplózás → session naplózás → statisztika → logout.
- [ ] `[FE]` Teljesítmény: kód-szeletelés, lazy grafikon, query staleTime hangolás.
- [ ] `[FE]` Sentry bekötés.

**DoD:** a fő flow-k zöld E2E-vel mennek, mobil böngészőn is használható, mindkét téma kész.

---

## Sprint 9 — Build / CI/CD / deploy (F9)

- [ ] `[FE]` Prod env (API URL, cookie domain); CORS/cookie prod beállítás (SameSite/al-domain).
- [ ] `[FE/BE]` CI: lint + typecheck + unit + build minden PR-en; E2E nightly.
- [ ] `[FE]` Deploy (Vercel vagy Docker); security headerek (CSP), HSTS, HTTPS.
- [ ] `[FE]` Monitoring/health + alap analytics.

**DoD:** a web élesben elérhető, a saját adatokat kezeli.

---

## Sprint 10 — Személyi edző (F10) — implementálva

> Ez a vázlat a `docs/personal_trainer/` mappa részletes terveivel (01–07) valósult meg, nem szó szerint az alábbi 4 sorral — azok ott vannak kifejtve (backend csomagstruktúra, végpontok, admin UI képernyők, ütemterv). Ez a szakasz csak a kereszthivatkozás miatt marad itt.

- [x] `[BE]` `ROLE_TRAINER` + `ROLE_SUPER_ADMIN`; `trainer_clients` (V41) + `role_audit_log` (V43) táblák (Flyway).
- [x] `[BE]` Meghívó/elfogadás flow (`TrainerInviteService`); jogosultsági réteg (`TrainerAccessService.requireActiveClient`, read-only).
- [x] `[BE]` Terv-hozzárendelés végpontok (`ContentAssignmentService`, deep copy + dedupe, V42).
- [x] `[FE]` RBAC útvonal-védelem (`(admin)`/`(superadmin)` route group-ok) + edző dashboard (kliens-lista, sparkline + metrikák) + kliens-részlet (read-only tabok) + meghívók UI.

---

## Mérföldkövek (emlékeztető a 02-ből)

- **M1** (alap használható): S0→S1→S2→S3.
- **M2** (teljes napló): S4→S5.
- **M3** (átlátás): S6→S7.
- **M4** (éles): S8→S9.
- **M5** (később): S10.

## Globális „minden képernyőre" checklist (per oldal pipálandó)

- [ ] Skeleton, empty, error állapot.
- [ ] Sötét + világos téma.
- [ ] Reszponzív (desktop/tablet/mobil).
- [ ] HU + EN szöveg elfér.
- [ ] Cél-tónus / metrika-színek helyesek (ahol releváns).
- [ ] Query-invalidáció a mutáció után (05 §12).
- [ ] A11y (fókusz, billentyű, ARIA, kontraszt).
