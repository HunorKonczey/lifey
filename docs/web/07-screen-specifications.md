# Lifey Web — Képernyő-specifikációk

> Képernyőnkénti, megvalósítható spec a `Lifey Web.dc.html` mockup **17 frame-je** alapján.
> Minden képernyőnél: **elrendezés**, **felhasznált komponensek** ([`06`](06-design-system-web.md)),
> **adatforrás** ([`05`](05-api-integration.md)), **állapotok**, **fő interakciók**.
> A frame-számok a mockupra hivatkoznak.

Legenda: 🟢 teljes weben · 🟡 részleges (mobil-specifikus rész kihagyva) · 📖 csak olvasható.

---

## 0. App-shell (frame 02)

- **Sidebar** (`--surface-high`, `--r-nav`, beúsztatott): logó (`eco`) + Lifey felirat; nav-elemek
  Dashboard / Nutrition / Workouts / Weight / Water / Steps / Statistics; alul Settings + user-blokk.
  Aktív elem `--primary` háttér + `fill` ikon. **Rail** módban (768–1279px) csak ikonok.
- **TopBar** (62px): oldal-cím + breadcrumb; jobbra globális `<DatePicker>`, kereső, `<ThemeToggle>`,
  `<UserMenu>` (avatar). A dátumválasztó értéke az egész app közös lokál-napja.
- **Tartalom**: adatdús, többoszlopos grid; a `(app)/layout.tsx` rendereli a shellt, az oldalak a
  tartalmat.

---

## 1. Auth — login / register (frame 16)

- **Elrendezés:** centrált, márkás kártya `--bg` háttéren; logó-badge (`eco`, `--primary`),
  „Welcome back" cím + tagline. Email + jelszó input (`--r-input`, ikon prefixszel), jelszó-mutató
  szem-ikon, „Forgot password?", nagy elsődleges „Sign in" gomb, alul „Create one" link.
- **Komponensek:** auth-card, `Input` ikonnal, primary `Button`.
- **Adat:** `POST /auth/login`, `POST /auth/register` → `AuthResponse`. Refresh tárolás: 04 §5.
- **Állapotok:** submit loading (gomb spinner), mező-validáció Zod-ból (email formátum, jelszó
  ≥8 karakter), szerverhiba toast (rossz hitelesítés → inline a jelszó alatt).
- **Interakció:** sikeres login → redirect `/dashboard`; register → auto-login vagy login-ra irány.

---

## 2. Dashboard (frame 03 sötét / 05 világos; állapotok: frame 04)

- **Elrendezés:** fő oszlop + jobb keskeny „This week" oszlop (268px).
  - **Hős kalória-kártya** (`<HeroMetricCard>`): nagy szám / cél, gradiens progress, „On track"
    chip vagy maradék-kcal; cél-tónus (túllépve → negatív).
  - **Makró-sor** (3 `<MacroRing>`): fehérje / szénhidrát / zsír, körkörös progress + szám/cél.
  - **Víz / Lépés / Testsúly sor**: `<WaterCard>` (szegmens-poharak + +250/+500/Cup),
    lépés `<StatCard>` (progress a célhoz), testsúly `<StatCard>` (érték + heti trend nyíl,
    kattintásra Weight oldal).
  - **Recent workouts** lista (utolsó session-ök, sorok a session-részletre visznek).
  - **Jobb oszlop:** mini Calories/Weight vonal + Workouts oszlopdiagram + „Streak" kártya.
- **Adat (párhuzamos query-k):** `statistics/daily?date=`, `meals` (mai), `weights` (utolsó),
  `water-entries` (mai), `steps` (mai), `workout-sessions` (utolsó N). Célok: `settings`.
- **Állapotok:** kártyánkénti skeleton; üres napra `<EmptyState>` „Nincs még adat ma" + gyors-add
  gombok; szekciónkénti `<ErrorState>` „Újra".
- **Interakció:** topbar-dátum váltás → minden kártya újratölt; víz „+" optimistic update;
  kártya-kattintás → megfelelő oldal.

---

## 3. Nutrition (frame 06 Meals, frame 07 Foods+Recipes)

Topbar-ban **al-fül szegmens**: Foods / Meals / Recipes (`?tab=`). „+ Add food" / „+ New food"
akció a fejlécben; a dátumválasztó a Meals fülön aktív.

### 3.1 Meals — napi napló (frame 06) 🟢 — `MasterDetail`
- **Bal/fő:** napi idővonal **étkezés-csoportokra** bontva (Breakfast/Lunch/Dinner/Snack ikonnal),
  csoportonként össz-kcal; tételek (név + gramm + „kcal · P"). Kiválasztott csoport `--primary`
  körvonallal. Üres étkezéshez szaggatott „+ Add dinner" sor.
- **Jobb sticky panel (300px):** **Daily summary** — nagy kalória/cél + progress, makró-sávok
  (fehérje/szénhidrát/zsír cél felé), alul „Meals / Items" számláló. Végig látszik naplózás közben.
- **Adat:** `GET /meals` (mai napra kliensoldali szűrés `dateTime` lokál-napjából), `POST/PUT/DELETE
  /meals`. Tétel-hozzáadáshoz `GET /foods` (+ recept). Élő összeg helyben, mentés után szerver.
- **Állapotok:** skeleton csoportok; üres nap → „kezdj egy étkezéssel"; hiba → újra.

### 3.2 Foods — lapozott táblázat + barcode (frame 07) 🟡
- **Elrendezés:** fejléc keresővel + **barcode mezővel** (`barcode_scanner` ikon, kézi beírás) +
  „+ New food". `<DataTable>`: Name (rendezhető) / Kcal / Protein / Carbs / Fat, makró-oszlopok a
  metrika-színekkel, kiválasztott sor kiemelve. **Lapozó** alul („1–4 of 128").
- **Detail:** kiválasztott étel inline szerkesztő (nem modál) — `FoodRequest` mezők + `hidden` kapcsoló.
- **Adat:** `GET/POST/PUT/DELETE /foods`, `GET /foods/barcode/{barcode}` (LOCAL→kitölt; OPENFOODFACTS
  →előtölt, majd POST). Lapozás kliensoldali (08 szerint később backend).
- **Állapotok:** table-skeleton (frame 17); üres „még nincs étel" + „+"; hiba + újra.

### 3.3 Recipes — rács (frame 07) 🟢
- **Elrendezés:** recept-kártyák rácsa (`menu_book` ikon, név, „≈ kcal · N serv.", kedvenc csillag);
  „Favorites" szűrő-chip. Szerkesztő (drawer/inline): hozzávalók (`foods`) + mennyiség, **servings**,
  számolt összérték és adagonkénti érték, kedvenc kapcsoló.
- **Adat:** `GET/POST/PUT/DELETE /recipes`. Kedvenc/adagszám a `RecipeRequest`-ből.

---

## 4. Workouts (frame 08 Templates, frame 09 Session logger + Exercises)

Topbar al-fül: Sessions / Templates / Exercises.

### 4.1 Templates — szerkesztő drag&drop-pal (frame 08) 🟢 — `MasterDetail`
- **Bal (280px):** sablonok listája (ikon + név + „N exercises"), kiválasztott `--primary` körvonal.
- **Jobb szerkesztő:** szerkeszthető név-mező; gyakorlat-sorok **`drag_indicator` fogantyúval**
  (dnd-kit), gyakorlatonként **„Sets" cél-szett** léptető és törlés (`close`). Húzás közben a sor
  elhalványul + enyhe dőlés/árnyék (mockup vizuál). Alul szaggatott „+ Add exercise".
- **Adat:** `GET/POST/PUT/DELETE /workout-templates`. A sorrend a `exercises[]` tömb sorrendje →
  drag után PUT. „+ Add exercise" → `GET /exercises` választó.

### 4.2 Sessions — élő logger + előzmények (frame 09) 🟡📖
- **Élő logger:** fejléc (sablon-név · „Started 18:30 · rest timer 1:30") + „Finish". Gyakorlat-blokk:
  szett-táblázat **Set / Previous / Kg / Reps / ✓** oszlopokkal; aktív szett `--primary` körvonal;
  „Add set". Pihenőidő-kezelés (lásd `docs/15-set-rest-time-plan.md`).
- **Előzmények:** session-lista; egy session részlete a szettekkel; **health mezők**
  (aktív kalória, átlag pulzus) **csak olvashatóként** (`📖`, forrás Apple Health/mobil).
- **Gyakorlat-progresszió:** kis trend a gyakorlat súly/ismétlés alakulásáról (a session-előzményből
  kliensoldalon számolva — nincs dedikált végpont).
- **Adat:** `GET/POST/PUT/DELETE /workout-sessions` (lásd 05 §6.3); a logger fokozatosan PUT-tal ment.

### 4.3 Exercises — könyvtár szűrőkkel (frame 09) 🟢
- **Elrendezés:** kategória + eszköz **szűrő-chipek** (All/Chest/Back/Barbell…), „+ New".
  Sorok ikonnal + „Equipment · Category" + `chevron_right` (inline szerkesztő).
- **Adat:** `GET/POST/PUT/DELETE /exercises`; szűrés kliensoldali a `category`/`equipment` mezőkre.

---

## 5. Weight (frame 12) 🟢 — `MasterDetail`

- **Elrendezés:** fejléc (`monitor_weight`, „Weight", „+ New entry"). Bal/nagy: **trend-grafikon**
  (`<TimeSeriesChart>`) Current nagy számmal + 1M/3M/1Y szegmens + cél-vonal („Goal 76.0 kg · −2.4
  to go"). Jobb: **History** lista (dátum + súly + színes Δ; pozitív zöld / növekedés narancs).
- **Adat:** `GET /weights`, `POST /weights`, `DELETE /weights/{id}`. **Nincs PUT** → javítás törlés+új
  (08 §-ben tisztázandó az azonos-napi felülírás). `WeightRequest.date` = `LocalDate`.
- **Állapotok:** üres „add meg az első súlyod"; chart/lista skeleton; hiba + újra.
- **Interakció:** „+ New entry" inline mező/kis drawer (dátum + súly); Δ a sorrendből számolva.

---

## 6. Water (frame 13) 🟢

- **Elrendezés:** összegző kártya (nagy „1.6 / 2.5 L" + **szegmens-poharak** a célig) + **gyors „+"
  gombok forrásonként** (Glass +250 / Bottle +500 / Can +330). Alatta **Sources** szekció (CRUD
  lista: ikon + név + ml) „Manage" linkkel.
- **Adat:** `GET/POST/DELETE /water-entries`, `GET/POST/PUT/DELETE /water-sources`. A „+" a forrás
  `volumeLiters`-ét tölti elő (a user módosíthatja), majd `POST /water-entries`. Napi szűrés a
  `consumedAt` lokál-napjából.
- **Állapotok:** üres nap → „még nincs víz ma"; források üres → „+ forrás"; hiba + újra.
- **Interakció:** „+" optimistic update (azonnali pohár-kitöltés, hibára rollback).

---

## 7. Steps (frame 14) 🟡

- **Elrendezés:** mai érték nagy számmal + cél-progress + **„Edit"** (kézi bevitel). Alatta
  „Last 7 days" oszlopdiagram (mai kiemelve, cél alattiak halványabbak).
- **Adat:** `GET /steps`, `POST/PUT /steps` (upsert a napra), `DELETE`. `DailyStepCountRequest.date`
  = `LocalDate`, `steps>=0`. Cél a `settings.dailyStepGoal`.
- **Megjegyzés:** weben **csak kézi** (a mobil szenzoros számlálás web-only nézete).

---

## 8. Statistics — multi-chart (frame 10 sötét / 11 világos; állapotok: frame 17) 🟢

- **Elrendezés:** idősáv-szegmens **Week / Month / Year** + export (`ios_share`).
  **KPI-sor** (`<KpiCard>` × 4): Avg calories / Workouts / Weight Δ / Volume — érték + trend (↑↓)
  az előző időszakhoz. **Grafikon-rács** (2×2): Calories & macros (nagy area+line), Weight (cél-vonallal),
  Training volume / week (oszlop), Water + Steps mini.
- **Adat:** `statistics/daily|weekly|monthly?date=`. ⚠️ A jelenlegi válasz **csak skalár összeg** —
  a KPI-számok mennek belőle, de a **trend-grafikonokhoz idősor kell**, amit ma a backend nem ad.
  Megoldás: **08 §2** (ajánlott: új `/statistics/series` végpont; átmenet: napi hívások aggregálása).
  A „vs. előző időszak" delta szintén az idősorból/két lekérésből.
- **Állapotok:** grafikononként chart-skeleton; üres időszak → „Nincs adat erre az időszakra,
  válassz másik tartományt"; API-hiba → inline error sáv „Retry".

---

## 9. Settings (frame 15) 🟢 — `MasterDetail`

- **Elrendezés:** bal **al-navigáció** (Profile / Daily goals / Units / Theme / Language / Security),
  jobb tartalom. A „Daily goals" panel: 6 cél-kártya (Calories/Protein/Carbs/Fat/Water/Steps) a
  metrika-színekkel, mezőkkel; alul Theme szegmens (Light/Dark/System) + „Save changes".
- **Adat:** `GET /settings`, `PUT /settings` (`SettingsRequest`). Mentés → érintett nézetek
  invalidálása (dashboard, statisztika cél-progress; téma/nyelv azonnali alkalmazás).
- **Szekciók:**
  - **Profile** — alapadatok (a `UserResponse`-ból; szerkeszthető mezők, ha van végpont).
  - **Daily goals** — kalória/fehérje/szénhidrát/zsír/víz/lépés cél.
  - **Units** — `UnitSystem` (METRIC/IMPERIAL) szegmens.
  - **Theme** — `ThemePreference` (LIGHT/DARK/SYSTEM) szegmens, azonnali.
  - **Language** — `LanguagePreference` (SYSTEM/ENGLISH/HUNGARIAN), next-intl váltás.
  - **Security** — „Kijelentkezés minden eszközről" (`POST /auth/logout-all`); jelszó (ha lesz végpont).

---

## 10. Globális állapot-galéria (frame 04, 17)

A 04. és 17. frame a **kötelező online-first állapotokat** mintázza, amit minden adatos nézet újrahasznál:
- **Skeleton:** kártya-, táblázat- és grafikon-variáns (`lifeyPulse` animáció).
- **Empty:** ikon-badge + cím + leírás + elsődleges akció.
- **Error:** `cloud_off` + üzenet + „Újra"; valamint **inline error sáv** API-hibához
  („Server returned 503 · GlobalExceptionHandler").

Ezek a [`06` §6.3](06-design-system-web.md) komponensei — képernyőnként nem terveződnek újra, csak
paraméterezve (ikon, szöveg, akció).

---

## 11. Jövőbeli — Személyi edző (vázlat, nem F1)

A sidebar/topbar úgy készül, hogy beférjen: **szerepkör-váltó** a user-menüben (Saját ↔ Edző nézet,
ha `ROLE_TRAINER`), **edző dashboard** (kliens-kártyák), **kliens-részlet** (read-only jelölés),
**terv-kiosztás** drawer, **meghívók**. Ugyanaz a token- és komponens-készlet — részletek a
[`02-development-plan.md`](02-development-plan.md) F10-ben.
