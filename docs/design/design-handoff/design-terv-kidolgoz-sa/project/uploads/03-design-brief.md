# Lifey Web — Design Brief (Claude Design számára)

> **Cél:** ez a fájl egy önálló, bemásolható brief a **Claude design**-nak (vagy bármilyen design ágensnek), amiből megtervezi a **Lifey webes felületét**.
>
> A web **ugyanazt a vizuális identitást** viszi tovább, mint a mobil app (barnás-zöld, sötét-first, lekerekített minden), **ugyanazokkal a szín-tokenekkel és komponens-koncepciókkal**. DE a web **nem** a mobil felnagyítása: kihasználja a nagy képernyőt — több információ egyszerre, több oszlop, master-detail nézetek, táblázatok, egyszerre látható grafikonok.
>
> **Fontos eltérés a mobiltól:** a weben **nincs offline mód**. Minden adat **élőben az API-ból** jön (`/api/v1/...`). Tehát nincs offline banner, nincs lokális szinkron — helyette **minden nézetnek erős loading / empty / error állapota** kell, hogy legyen, és a listák **lapozottak** (pagination).

---

## 0. A prompt (ezt másold be a kezdéshez)

> Te a **Lifey** webes felületét tervezed — ez egy személyes fitnesz- és táplálkozás-követő app. Létezik egy mobil verzió (Flutter, sötét-first, barnás-zöld "moss/olive" identitás); a web **ugyanazt a design rendszert** használja (lásd §2 szín- és tipográfia-tokenek), de **webre optimalizált, adatdús, többoszlopos elrendezésekkel** (§1, §3).
>
> A web egy **REST API-t fogyaszt** (Spring Boot backend). **Nincs offline mód** — minden adat élőben jön, ezért minden képernyőnek tervezz **skeleton loading**, **üres állapot** és **hibaállapot** változatot is. A listák lapozottak.
>
> Szállítsd, sorrendben:
> 1. A **design rendszert** (§2): szín-tokenek (sötét + világos), tipográfia, spacing, radius, árnyék, ikonográfia, mozgás — a megadott hex-értékekkel.
> 2. A **web app-keretet** (§1): bal oldali állandó sidebar navigáció, felső sáv, reszponzív breakpointok.
> 3. **Képernyőnként a részletes design-t** minden funkcióra (§3), beleértve a loading/empty/error állapotokat.
>
> Tartsd be a §2 token-értékeket és a §1 elrendezési elveket pontosan. Sötét a hős téma; a világos ugyanabból a tokenkészletből jön.

---

## 1. Webes elrendezési elvek (a mobiltól való eltérés lényege)

A mobil 5-fül<bottom nav>-os. A web **NEM** ezt másolja. A web:

### 1.1 Állandó bal oldali sidebar (nem bottom nav)
- **Bal oldali, mindig látható navigáció**, ikon + rövid felirat (a mobil ikonkészletet használva, lásd §3).
- **Összecsukható ikon-sávvá** (rail) — szélesebb tartalomhoz a sidebar ikonokra szűkül.
- Destinációk: Dashboard, Nutrition, Workouts, Weight, Water, Steps, Statistics, Settings.
- A sidebar **lekerekített, kicsit beúsztatott** (a mobil floating bar érzését viszi tovább, de álló helyzetben), `surfaceContainerHigh` háttérrel.

### 1.2 Felső sáv (top bar)
- Bal oldalon **oldal-cím** + opcionális **breadcrumb**.
- Középen/jobbra: **globális dátumválasztó** (a legtöbb nézet dátum-érzékeny), **kereső**, **téma-váltó**, **user menü** (kijelentkezés, logout-all).
- Slim, beúsztatott, lekerekített — a tartalom alá görget.

### 1.3 Adatdús, többoszlopos tartalom
- Használd ki a szélességet: **több kártya egy sorban**, **master-detail** (bal lista + jobb részlet/szerkesztő), **táblázatok** rendezéssel/szűréssel, **egyszerre több grafikon**.
- Cél: amiért mobilon görgetni/fülözni kell, az weben **egy képernyőn** elférjen.

### 1.4 Reszponzív breakpointok
- **≥1280px (desktop):** teljes sidebar + többoszlopos tartalom + master-detail.
- **768–1279px (tablet):** ikon-rail sidebar, 2 oszlop.
- **<768px (mobil böngésző):** sidebar → drawer / alsó nav, egyoszlopos (a mobil app-élményhez közelít).

### 1.5 Megtartott vizuális DNS (a mobilból)
- **Lekerekített minden** (radius skála §2.4).
- **Ikon mindenen** — nav, fejléc-akciók, kártyák, szekciók.
- **Nagy, hangsúlyos metrika-számok** (tabular figures).
- Sötét-first, barnás-zöld akcent.

---

## 2. Design rendszer (pontos tokenek a mobilból)

> Ezek a **mobil app tényleges értékei** (`mobile/lib/core/theme/`). A web ezeket használja CSS változókként.

### 2.1 Színek — SÖTÉT téma (hős)

| Token | Hex | Használat |
|---|---|---|
| `bg` | `#161611` | scaffold háttér, legmélyebb felület |
| `surface` | `#1C1E16` | fő felület (kártyák, list tile ezen ülnek) |
| `surfaceContainer` | `#22241B` | kiemelt kártyák, stat kártyák |
| `surfaceContainerHigh` | `#2A2C20` | sidebar, floating sávok |
| `surfaceContainerHighest` | `#32342A` | chipek, kiválasztott segmented háttér |
| `primary` (moss-olive) | `#9DAE6B` | fő akcent, elsődleges gomb, aktív nav |
| `secondary` (warm brown) | `#C49A6C` | másodlagos akcent |
| `tertiary` (forest green) | `#6E9A6A` | harmadlagos akcent |
| `onSurface` (szöveg) | `#F1F0E4` | elsődleges szöveg |
| `onSurfaceVariant` (muted) | `#A8A899` | másodlagos/halvány szöveg |
| `outline` | `#3C3E32` | körvonalak, elválasztók |
| `error` | `#CF6679` | hibák |

### 2.2 Színek — VILÁGOS téma

| Token | Hex |
|---|---|
| `bg` | `#F3F2E8` |
| `surface` | `#FFFFFF` |
| `container` | `#ECEBDE` |
| `primary` (deeper olive) | `#586E38` |
| `secondary` (deep brown) | `#8A6A42` |
| `tertiary` (forest green) | `#4A7A52` |
| `onSurface` | `#1E1F18` |
| `onSurfaceVariant` | `#5C5C50` |
| `outline` | `#CDCBBC` |

### 2.3 Metrika-akcent színek (kártyák, grafikonok — sötét / világos)

| Metrika | Sötét | Világos | Ikon (Material) |
|---|---|---|---|
| Kalória | `#E0915A` | `#D27A3E` | `local_fire_department` |
| Fehérje | `#9DAE6B` | `#586E38` | `egg_alt` |
| Szénhidrát | `#D8B35A` | `#B8902F` | `bakery_dining` |
| Zsír | `#8E8EC4` | `#6A6AB0` | `water_drop` |
| Lépés | `#B08AC8` | `#8A6AB0` | `directions_walk` |
| Testsúly | `#8AA0B4` | `#5E7A92` | `monitor_weight` |
| Víz | `#6FA8C4` | `#4E8AA8` | `water_drop` |
| Pulzus | `#C46A6A` | `#C46A6A` | `favorite` |
| **Pozitív cél** (elérve) | `#9DAE6B` | `#4A7A52` | — |
| **Negatív cél** (túllépve) | `#E08A52` | `#E08A52` | — |

> A cél-állapot színezés (pl. fehérje elérve = pozitív zöld, kalória túllépve = negatív narancs) a dashboard és statisztika kártyák kulcseleme — vidd át.

### 2.4 Radius skála

| Token | Érték | Használat |
|---|---|---|
| `sm` | 8px | chipek, tagek, belső elemek |
| `md` | 16px | gombok, kisebb kártyák |
| `input` | 18px | input mezők, action sorok |
| `card` | 20px | list-tile kártyák |
| `lg` | 24px | nagy stat kártyák, grafikon kártyák |
| `nav` | 28px | sidebar / floating sávok |
| `pill` | 999px | chipek, segmented, kerek elemek |

### 2.5 Spacing (4pt grid)
`4 / 8 / 12 / 16 / 24 / 32` px.

### 2.6 Tipográfia — **Plus Jakarta Sans**

| Stílus | Méret / súly | Használat |
|---|---|---|
| displayLarge | 34 / 800, tabular | hős metrika-számok (pl. „1 780 kcal") |
| headlineMedium | 26 / 700 | oldal-címek |
| titleLarge | 20 / 700 | szekció-címek, kártya-fejlécek |
| bodyLarge | 14 / 600 | list tile címek |
| bodyMedium | 15 / 500 | törzsszöveg, alcímek |
| labelMedium | 13 / 600 | címkék, chipek, tab szöveg |
| labelSmall | 11 / 700 | ALL CAPS szekció-címkék |

> Számok/metrikák **tabular figures**-szel, hogy a kártyákban/táblázatokban igazodjanak.

### 2.7 Mozgás
- Időtartamok: `150ms` (fast), `250ms` (base), `350ms` (slow).
- Easing: standard `ease-in-out`; emelt `cubic-bezier(.2,.8,.2,1)`.
- Lágy, alacsony-spread árnyékok a floating elemeken (ne kemény elevation).

### 2.8 Újrahasznosítandó komponensek (a mobil koncepciók webre)
- **StatCard** — `label, value, unit, icon, color, ratio (progress), goalReached, goalTone, trailing, onClick`. A dashboard/statisztika gerince.
- **WaterCard** — aktuális vs. cél, gyors „+" gombok.
- **Metrika-chip**, **segmented range picker** (week/month/quarter/all), **empty state**, **error state**, **FAB → web: elsődleges gomb / „+ Új" a tartalom fejlécében**.
- **TimeSeriesChart** — a mobil egyéni vonaldiagramja; weben nagyobb, tappolható pontokkal, több egyszerre.
- Modálok helyett weben gyakran **jobb oldali drawer** vagy **inline szerkesztő** (master-detail).

### 2.9 Online-first állapotok (KÖTELEZŐ minden nézethez)
Mivel nincs offline cache, minden adatos nézethez tervezz:
- **Skeleton loading** (ne csupasz spinner) — a kártya/táblázat alakját imitálja.
- **Üres állapot** — ikon + rövid szöveg + elsődleges akció („+ Első bejegyzés").
- **Hibaállapot** — barátságos üzenet + „Újra" gomb (a backend `GlobalExceptionHandler` válaszaihoz).
- **Lapozás** — táblázatok/listák lapozottak; „továbbiak betöltése" vagy oldalszámozó.

---

## 3. Funkciónkénti design (minden funkcionalitás)

> Minden funkcióhoz tartozik a forrás-végpont, a webes elrendezési javaslat, és a kötelező állapotok. A funkciók a backend végpontjaiból származnak.

### 3.0 App-keret
- **Sidebar** (§1.1) + **top bar** (§1.2). A kijelölt nav elem `primary` akcenttel, kitöltött ikonnal; a többi outline ikon `onSurfaceVariant` színnel.

### 3.1 Auth — `login`, `register`
- Két centrált, márkás kártya sötét `bg`-n, `primary` akcenttel, lekerekített inputokkal (`radius.input`), nagy elsődleges gombbal.
- Logó + rövid tagline. Hibák inline (rossz jelszó stb.).
- **Állapotok:** submit loading (gomb spinner), mező-validáció (Zod), szerverhiba toast.

### 3.2 Dashboard
**Forrás:** `statistics/daily`, `meals`, `weights`, `water-entries`, `steps`, `workout-sessions`.
- **Felül dátumválasztó** (ma / korábbi nap).
- **Többoszlopos grid** (a mobil egymás-alá helyett egyszerre látható):
  - **Kalória hős-kártya** (nagy szám, cél-progress, túllépve = negatív tónus) — `local_fire_department`.
  - **Makró kártyák sora**: fehérje / szénhidrát / zsír, cél-arány sávval.
  - **Víz kártya** — aktuális/cél + gyors „+" források szerint.
  - **Lépés kártya** — mai érték (web: olvasható/kézi).
  - **Aktuális testsúly** — trend nyíllal, kattintásra Weight oldal.
  - **Legutóbbi edzések** lista — sorok a session részletre visznek.
- A nagy képernyőn **egy oldalon** elfér az egész nap; jobb oldali keskeny oszlopban „heti összefoglaló" mini-grafikonok.
- **Állapotok:** kártyánként skeleton; üres napra „nincs még adat ma" + gyors-hozzáadás gombok.

### 3.3 Nutrition (Foods / Meals / Recipes)
**Forrás:** `foods`, `meals`, `recipes`.
Web-elrendezés: **felső al-fülek** (Foods / Meals / Recipes) VAGY szegmens-váltó; minden fül **master-detail**.

**Foods**
- **Bal:** kereshető, lapozott **táblázat** (név, kcal, fehérje, szénhidrát, zsír; rendezhető oszlopok; rejtett ételek szűrő).
- **Jobb:** kiválasztott étel **részlet/szerkesztő** inline (nem modál).
- **Vonalkód:** mező a fejlécben — kézi vonalkód-beírás → `GET /foods/barcode/{barcode}` → kitöltés. (Kamera-szken nincs weben.)
- „+ Új étel" a fül fejlécében.

**Meals (napi napló)**
- **Bal/fő:** napi **idővonal**, étkezésekre csoportosítva (reggeli/ebéd/…); minden tétel név + mennyiség + kcal/fehérje.
- **Jobb sticky panel:** **napi összesítés** (kalória/makró cél vs. aktuális, progress) — végig látható naplózás közben.
- Tétel hozzáadása ételből/receptből mennyiséggel; élő összeg-frissítés.

**Recipes**
- **Bal:** receptek rácsa/listája, **kedvenc** szűrővel.
- **Jobb:** recept-szerkesztő — hozzávalók (foods) hozzáadása, **adagszám (servings)**, számolt összérték; **kedvenc** csillag.
- **Állapotok:** táblázat skeleton; üres („még nincs étel/recept" + „+"); hiba + újra.

### 3.4 Workouts (Sessions / Templates / Exercises)
**Forrás:** `workout-sessions`, `workout-templates`, `exercises`.

**Exercises**
- Lapozott **táblázat/rács** kategória + eszköz **szűrőkkel**; inline szerkesztő. „+ Új gyakorlat".

**Templates**
- **Bal:** sablonok listája. **Jobb:** sablon-szerkesztő — gyakorlatok hozzáadása, **cél-szettek**, **sorrend drag & drop** (weben kényelmes).

**Sessions**
- **Edzés-naplózó táblázatként:** gyakorlatonként sorok, szett/ismétlés/súly cellákkal, gyors léptetés, pihenőidő.
- **Előzmények:** lapozott lista; egy session részletes nézete (health mezők — pulzus/aktív kalória — olvashatóként, ha van).
- **Gyakorlat-progresszió:** kis trend-grafikon az adott gyakorlat súly/ismétlés alakulásáról.

### 3.5 Weight
**Forrás:** `weights`.
- **Bal:** előzmény-táblázat (dátum, súly, változás), törléssel. **Jobb/felül:** nagy **TimeSeriesChart** trend.
- „+ Új bejegyzés" a fejlécben (inline mező vagy kis drawer).
- **Állapotok:** üres („add meg az első súlyod"), skeleton, hiba.

### 3.6 Water
**Forrás:** `water-entries`, `water-sources`.
- **Fő:** mai bevitel, **gyors „+" gombok forrásonként** (water-sources), napi összesítés cél felé.
- **Források kezelése:** kis CRUD panel/táblázat (név, mennyiség, ikon/szín).
- Bejegyzések listája törléssel.

### 3.7 Steps
**Forrás:** `steps`.
- Napi lépés-érték **megtekintés + kézi bevitel/szerkesztés** (a mobil szenzoros adat web-only nézete).
- Kis trend-grafikon a napi lépésekről, cél-vonallal (a `settings` napi lépéscél).

### 3.8 Statistics — **a web kiemelt erőssége**
**Forrás:** `statistics/daily|weekly|monthly`.
- **Időtáv-szegmens:** napi / heti / havi (+ opcionálisan negyedév/összes).
- **Több grafikon EGYSZERRE** (a mobil egy-grafikon-egyszerre helyett dashboard-szerű elrendezés):
  - Kalória + makró trend, súlytrend, edzésvolumen/gyakoriság, víz, lépés.
- **KPI összegző kártyák**: átlag / összeg / min / max / **trend ↑↓** az előző időszakhoz képest.
- **Időszak-összehasonlítás** (ez a hét vs. előző) egymás mellett.
- Tappolható pontok (érték + dátum).
- **Állapotok:** grafikononként skeleton; üres időszakra magyarázó üres állapot.

### 3.9 Settings
**Forrás:** `settings`, `logout-all`.
- **Profil** szekció.
- **Napi célok** (kalória, fehérje, szénhidrát, zsír, víz, **napi lépéscél**) — mezők, mentés `PUT /settings`.
- **Mértékegység** (metrikus/imperial) — segmented.
- **Téma** (világos/sötét/rendszer) — segmented, azonnali alkalmazás.
- **Nyelv** (rendszer/EN/HU) — a `settings.language`-hez kötve.
- **Biztonság / munkamenetek:** „Kijelentkezés minden eszközről" (`logout-all`).
- Web-elrendezés: **bal oldali al-navigáció** a beállítás-szekciók közt + jobb oldali tartalom (tipikus settings master-detail).

---

## 4. Jövőbeli rész — Személyi edző (csak vázlat a design-hoz)

> Nem az első kör része; itt csak hogy a sidebar és a szerepkör-váltás vizuálisan beleférjen.
- **Szerepkör-váltó** a top bar user-menüjében (Saját nézet ↔ Edző nézet), ha a usernek van `ROLE_TRAINER`.
- **Edző dashboard:** kliensek kártya-rácsa (állapot, utolsó aktivitás), `primary`/`tertiary` akcentekkel.
- **Kliens-részlet (read):** a kliens dashboard/statisztika nézete, „csak olvasható" jelöléssel.
- **Terv-kiosztás:** sablon/étrend hozzárendelése klienshez (drawer).
- **Meghívók:** függőben/aktív kliensek listája.
- Ugyanaz a token-készlet és komponens-nyelv; csak új képernyők.

---

## 5. Elfogadási kritériumok (gyors pass/fail)
- [ ] A pontos sötét + világos **token-értékek** (§2.1–2.3) alkalmazva CSS változókként.
- [ ] **Lekerekített minden** a radius-skála szerint; **Plus Jakarta Sans** tipográfia.
- [ ] **Bal sidebar** navigáció (nem bottom nav), ikon-rail összecsukással; slim top bar dátumválasztóval + user menüvel.
- [ ] **Adatdús, többoszlopos** elrendezés: master-detail listák, rendezhető/lapozott táblázatok, **egyszerre több grafikon** a statisztikán.
- [ ] **Minden** funkció lefedve (auth, dashboard, foods/meals/recipes, exercises/templates/sessions, weight, water, steps, statistics, settings).
- [ ] **Minden adatos nézethez** skeleton loading + üres + hibaállapot (online-first, nincs offline banner).
- [ ] Metrika-akcentek és **cél-tónus** (pozitív/negatív) átvéve a kártyákra/grafikonokra.
- [ ] Reszponzív: desktop (sidebar + multi-column) → tablet (rail) → mobil böngésző (drawer/egyoszlop).
- [ ] EN + HU szövegek elférnek; téma-váltó működik.
