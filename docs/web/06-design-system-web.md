# Lifey Web — Design system (implementációs)

> A [`03-design-brief.md`](03-design-brief.md) a *design ágensnek* szóló brief; ez a fájl a
> **fejlesztőnek**: a `Lifey Web.dc.html` mockup tokenjeit konkrét **CSS változókká / Tailwind
> témává** és **komponens-prop-szerződésekké** fordítja. A hex-értékek a mobil app tényleges
> témájából származnak (`mobile/lib/core/theme/`), és a mockup 01. frame-je igazolja őket.

---

## 1. Színtokenek → CSS változók

A `globals.css`-ben (Tailwind v4 `@theme` vagy sima `:root`):

```css
:root {                      /* SÖTÉT — hős téma */
  --bg:                 #161611;
  --surface:            #1C1E16;
  --surface-container:  #22241B;
  --surface-high:       #2A2C20;   /* sidebar, floating sávok */
  --surface-highest:    #32342A;   /* chip, kiválasztott segmented */
  --primary:            #9DAE6B;   /* moss-olive: fő akcent, aktív nav */
  --secondary:          #C49A6C;   /* warm brown */
  --tertiary:           #6E9A6A;   /* forest green */
  --on-surface:         #F1F0E4;   /* elsődleges szöveg */
  --on-surface-variant: #A8A899;   /* halvány szöveg */
  --muted:              #777264;   /* leghalványabb (label, placeholder) */
  --outline:            #3C3E32;
  --error:              #CF6679;
}
[data-theme="light"] {       /* VILÁGOS */
  --bg:                 #F3F2E8;
  --surface:            #FFFFFF;
  --surface-container:  #ECEBDE;
  --surface-high:       #FFFFFF;
  --surface-highest:    #ECEBDE;
  --primary:            #586E38;   /* deeper olive */
  --secondary:          #8A6A42;   /* deep brown */
  --tertiary:           #4A7A52;   /* forest green */
  --on-surface:         #1E1F18;
  --on-surface-variant: #5C5C50;
  --muted:              #9A9A8C;
  --outline:            #CDCBBC;
  --border:             #E2E0D2;   /* világosban a kártyák körvonala */
  --error:              #CF6679;
}
```

> A világos témában a kártyák **1px `--border`** körvonalat kapnak (a mockup 05/11. frame így
> rajzol), sötétben nem (a surface-szintek adják az elválasztást).

---

## 2. Metrika-akcent színek

A dashboard/statisztika kártyák és grafikonok ezeket használják (sötét / világos):

| Metrika | Sötét | Világos | Material ikon |
|---|---|---|---|
| Kalória | `#E0915A` | `#D27A3E` | `local_fire_department` |
| Fehérje | `#9DAE6B` | `#586E38` | `egg_alt` |
| Szénhidrát | `#D8B35A` | `#B8902F` | `bakery_dining` |
| Zsír | `#8E8EC4` | `#6A6AB0` | `water_drop` |
| Lépés | `#B08AC8` | `#8A6AB0` | `directions_walk` |
| Testsúly | `#8AA0B4` | `#5E7A92` | `monitor_weight` |
| Víz | `#6FA8C4` | `#4E8AA8` | `water_drop` |
| Pulzus | `#C46A6A` | `#C46A6A` | `favorite` |

**Cél-tónus** (a StatCard kulcsmechanizmusa):
- **Pozitív** (cél elérve, „jó" irány): sötét `#9DAE6B` / világos `#4A7A52`.
- **Negatív** (túllépve, „rossz" irány, pl. kalória a cél fölött): `#E08A52` (mindkét téma).

```css
:root        { --metric-kcal:#E0915A; --metric-protein:#9DAE6B; --metric-carbs:#D8B35A;
               --metric-fat:#8E8EC4; --metric-steps:#B08AC8; --metric-weight:#8AA0B4;
               --metric-water:#6FA8C4; --metric-hr:#C46A6A;
               --goal-positive:#9DAE6B; --goal-negative:#E08A52; }
[data-theme="light"] { --metric-kcal:#D27A3E; --metric-protein:#586E38; --metric-carbs:#B8902F;
               --metric-fat:#6A6AB0; --metric-steps:#8A6AB0; --metric-weight:#5E7A92;
               --metric-water:#4E8AA8; --metric-hr:#C46A6A;
               --goal-positive:#4A7A52; --goal-negative:#E08A52; }
```

---

## 3. Radius, spacing, mozgás

```css
:root {
  --r-sm: 8px;     /* chip, tag, belső elem */
  --r-md: 16px;    /* gomb, kisebb kártya */
  --r-input: 18px; /* input, action sor */
  --r-card: 20px;  /* list-tile / standard kártya */
  --r-lg: 24px;    /* nagy stat / grafikon kártya */
  --r-nav: 28px;   /* sidebar / floating sáv */
  --r-pill: 999px;
  --dur-fast: 150ms; --dur-base: 250ms; --dur-slow: 350ms;
  --ease: cubic-bezier(.2,.8,.2,1);
  --shadow-float: 0 1px 3px rgba(0,0,0,.18); /* lágy, alacsony spread */
}
```
- **Spacing**: 4pt grid → `4 / 8 / 12 / 16 / 24 / 32` (Tailwind `1/2/3/4/6/8`).
- **Árnyék**: csak floating/kártya-szinten, lágy; ne kemény Material-elevation.

---

## 4. Tipográfia — Plus Jakarta Sans

| Szerep | Méret / súly | Tailwind utility (cél) | Használat |
|---|---|---|---|
| displayLarge | 34 / 800, tabular | `text-display` | hős metrika-szám („1 780 kcal", a hero kártyán akár 46px) |
| headlineMedium | 26 / 700 | `text-headline` | oldal-cím |
| titleLarge | 20 / 700 | `text-title` | szekció-cím, kártya-fejléc |
| bodyLarge | 14 / 600 | `text-body-lg` | list-tile cím |
| bodyMedium | 15 / 500 | `text-body` | törzsszöveg, alcím |
| labelMedium | 13 / 600 | `text-label` | címke, chip, tab |
| labelSmall | 11 / 700, ALL CAPS, letter-spacing | `text-label-sm` | szekció-címke |

- **Minden szám/metrika `font-variant-numeric: tabular-nums`** (kártyában, táblázatban igazodjon).
- Font betöltés: `Plus Jakarta Sans` (400–800) + `Material Symbols Rounded` (variable), `swap`.

---

## 5. Ikonográfia

- **Material Symbols Rounded**, a mobil ikonkészlettel azonos.
- Az **aktív** nav-elem és a kiemelt akciók **`fill` variánst** kapnak (`'FILL' 1`), a többi outline.
- Navigációs ikonok (mockup szerint): `dashboard`, `restaurant`, `fitness_center`,
  `monitor_weight`, `water_drop`, `directions_walk`, `bar_chart`, `settings`. Logó: `eco`.

---

## 6. Komponens-könyvtár (prop-szerződések)

A mockup frame-jeiből kiemelt, újrahasznosítható komponensek. shadcn/ui primitíveket
(`Button`, `Input`, `Dialog`, `Table`, `Tabs`, `DropdownMenu`, `Toast`) használjuk alaprétegként.

### 6.1 App-shell
- **`<Sidebar />`** — bal oldali, `--surface-high`, `--r-nav`, beúsztatott. Teljes (248px) és
  összecsukott **rail** (74px) mód. Aktív elem `--primary` háttér + `fill` ikon. Alul user-blokk.
- **`<TopBar title, breadcrumb, actions />`** — slim (62px), `--surface-high`, `--r-card`.
  Bal: cím + breadcrumb. Jobb: `<DatePicker />`, kereső, `<ThemeToggle />`, `<UserMenu />`.
- **`<DatePicker value, onChange />`** — globális lokál-nap választó (`chevron_left/right` + nap).
- **`<UserMenu />`** — avatar, logout, logout-all; (F10: szerepkör-váltó).

### 6.2 Adat-komponensek
- **`<StatCard label, value, unit, icon, color, ratio?, goalReached?, goalTone?, trailing?, onClick? />`**
  — a dashboard/statisztika gerince. `ratio` → progress-sáv; `goalTone` → pozitív/negatív szín.
- **`<MacroRing label, value, goal, color, icon />`** — körkörös progress (SVG, 46px) + szám,
  a makró-kártyákhoz (mockup 03. frame).
- **`<HeroMetricCard />`** — nagy kalória-kártya: szám + „/ cél", gradiens progress, „On track"
  chip vagy maradék-szöveg.
- **`<WaterCard current, goal, sources, onAdd />`** — szegmens-poharak + gyors „+" gombok forrásonként.
- **`<SegmentedControl options, value, onChange />`** — pill-háttér (`--surface-highest`), aktív
  elem akcenttel. (Idősáv week/month/year, téma, mértékegység, nutrition/workout al-fülek.)
- **`<DataTable columns, rows, sort, onSort, pagination />`** — rendezhető fejléc (`arrow_downward`),
  sorok `--surface`-en, **lapozó** (lásd 6.4). Foods/Exercises listához.
- **`<TimeSeriesChart series, goalLine?, range />`** — Recharts area/line; tappolható pontok
  (érték + dátum), opcionális cél-vonal (szaggatott). Súly/statisztika trendekhez.
- **`<MasterDetail list, detail />`** — bal lista + jobb részlet/szerkesztő reszponzív elrendezés
  (Nutrition Meals, Workouts Templates, Settings).
- **`<MetricChip label, color />`**, **`<KpiCard label, value, delta, trend />`** (statisztika KPI sor).

### 6.3 Állapot-komponensek (online-first — KÖTELEZŐ)
- **`<Skeleton variant="card|table|chart" />`** — a tartalom alakját imitálja, `lifeyPulse`
  animáció (`opacity .55↔.28`, 1.4s), `--surface-highest` blokk-szín. Nem csupasz spinner.
- **`<EmptyState icon, title, body, action />`** — ikon-badge + cím + leírás + elsődleges gomb
  („+ Első bejegyzés").
- **`<ErrorState onRetry />`** — `cloud_off` ikon, barátságos üzenet, „Újra" gomb. A
  `GlobalExceptionHandler` 5xx/hálózati hibáihoz.
- **`<InlineError message, detail, onRetry />`** — sorba illeszthető hibasáv (mockup 17. frame).

### 6.4 Lapozás
A backend ma nem lapoz (lásd `05`/`08`). A `<DataTable>` ezért **kliensoldali lapozással** indul
(teljes lista letöltve → oldalakra szeletelve, „1–N of M"), és a prop-szerződés (`pagination`)
úgy van kialakítva, hogy **backend-lapozásra később átkapcsolható** legyen API-csere nélkül a UI-ban.

---

## 7. Reszponzív breakpointok

| Tartomány | Sidebar | Tartalom |
|---|---|---|
| ≥1280px (desktop) | teljes (248px) | többoszlopos grid + master-detail + egyszerre több grafikon |
| 768–1279px (tablet) | ikon-rail (74px) | 2 oszlop, a master-detail jobb panel alá csúszhat |
| <768px (mobil böngésző) | drawer / alsó nav | egyoszlopos, a mobil app-élményhez közelít |

A master-detail kis kijelzőn **lista→részlet navigációvá** esik szét (a részlet teljes szélességben,
vissza-gombbal), nem két szűk oszloppá.

---

## 8. Elfogadási kritériumok (design-implementáció)

- [ ] Pontos sötét + világos token-értékek CSS változókként (§1–§2).
- [ ] Radius-skála (§3) és Plus Jakarta Sans + tabular-nums (§4) mindenhol.
- [ ] Bal sidebar (nem bottom nav), rail-összecsukás; slim topbar dátumválasztóval + user-menüvel.
- [ ] StatCard cél-tónus (pozitív/negatív) működik a célokból (settings) számolva.
- [ ] Minden adatos nézethez skeleton + empty + error (nincs offline banner).
- [ ] Reszponzív: desktop → tablet (rail) → mobil (drawer/egyoszlop).
- [ ] Téma-váltó és HU/EN szövegek elférnek mindkét nyelven.
