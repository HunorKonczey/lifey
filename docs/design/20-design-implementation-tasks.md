# Lifey – Design implementation tasks (step-by-step prompts)

> **Mi ez?** A redesign (`18-design-system-prompt.md` + a `design-handoff/`
> mockupok) lebontva **kis, egymásra épülő, tisztán vizuális** lépésekre. Minden
> lépés egy **önállóan beilleszthető prompt** — egyesével haladunk, mindegyik
> után build + gyors ellenőrzés.
>
> **Hatókör:** CSAK design / restyle. Új funkció / adatmodell **NEM** — azok a
> `19-new-features.md`-ben vannak. Ahol egy mockup-elem hiányzó funkcióból
> táplálkozna, placeholder/kihagyás + `// TODO(new-feature #…)` jegyzet.
>
> **Forrás-igazság (értékek, ikonok, layout):**
> - Tokenek + komponensek: `Lifey Redesign.dc.html` (Design System blokk).
> - Képernyők (dark hero + light dashboard): ugyanott, 01–08.
> - Collapse-mechanika (élő JS): `Lifey Nav Prototype.dc.html` (a `<script>` a végén).
>
> **Globális szabályok minden lépéshez** (CLAUDE.md + mobile/CLAUDE.md):
> - Material 3, Flutter; `flutter_riverpod`, `go_router`, `drift`. Nincs új nehéz
>   dependency indoklás nélkül (a betűtípus bundle kivétel, lásd 3. lépés).
> - **Soha** ne szerkessz `*.g.dart`-ot; `@riverpod` után `dart run build_runner build`.
> - **Nincs hardcode-olt szöveg** — ARB / `AppLocalizations` kulcsok (EN + HU).
> - Megőrizni a `domain/data/application/presentation` rétegezést.
> - A meglévő widgeteket **restyle**-oljuk, nem forkoljuk (`StatCard`, `WaterCard`,
>   `TimeSeriesChart`, tabok, FAB-ok, empty/error view-k).
> - Minden lépés végén: `flutter analyze` tiszta + (ahol értelmes) gyors futtatás
>   dark **és** light témán, EN **és** HU lokálon.

---

## Token-referencia (gyors)

**Dark (hero):** bg `#161611` · surface `#1C1E16` · container `#22241B` ·
high `#2A2C20` · highest `#32342A` · **primary** `#9DAE6B` (moss-olive) ·
secondary `#C49A6C` (brown) · tertiary `#6E9A6A` (forest) · onSurface `#F1F0E4` ·
onSurfaceVariant `#A8A899` · muted `#777264`.
**Light:** bg `#F3F2E8` · surface `#FFFFFF` · container `#ECEBDE` ·
primary `#586E38` · secondary `#8A6A42` · tertiary `#4A7A52` · onSurface `#1E1F18` ·
variant `#5C5C50` · outline `#CDCBBC`.
**Semantic:** positive `#9DAE6B` (light `#4A7A52`) · negative/over `#E08A52`.
**Metric accents (dark / light):** calories `#E0915A`/`#D27A3E` · protein
`#9DAE6B`/`#586E38` · carbs `#D8B35A`/`#B8902F` · fat `#8E8EC4`/`#6A6AB0` ·
steps `#B08AC8`/`#8A6AB0` · weight `#8AA0B4`/`#5E7A92` · water `#6FA8C4`/`#4E8AA8` ·
heart `#C46A6A`.
**Radius:** sm 8 · md 16 · lg 24 · pill (stadium). Kártya ~20–24, nav 28–30,
gomb/FAB 16–18, input 18. **Spacing:** 4pt alap (4/8/12/16/24/32).
**Motion:** 150/250/350 ms; collapse easing `cubic-bezier(.2,.8,.2,1)`.
**Type:** Plus Jakarta Sans (400–800), tabular numerals a metrikákhoz.

---

## Fázis 1 — Alapok (foundation)

### 01 · Base ColorScheme + ThemeData (dark + light)
**Prompt:**
> A `mobile/lib/core/theme/app_theme.dart`-ban cseréld le a `colorSchemeSeed`-es
> `AppTheme`-et **valódi** `ColorScheme.dark` és `ColorScheme.light` definíciókra
> a fenti token-értékekkel (forrás: `Lifey Redesign.dc.html` Color blokk).
> Állítsd be a `ThemeData`-t mindkét témára: `useMaterial3: true`, `scaffold-
> BackgroundColor` = bg token, `surface`/`surfaceContainer*` szintek a megadott
> lépcsőzéssel, `onSurface`/`onSurfaceVariant`. Ne stilizálj még komponenseket —
> csak a `ColorScheme` + alap `ThemeData` legyen kész, hogy az egész app a
> barnás-zöld palettára váltson. Ne nyúlj a layouthoz. Build + nézd meg dark és
> light témán.

### 02 · Design tokens fájl (spacing / radius / motion / accents)
**Prompt:**
> Hozz létre `mobile/lib/core/theme/app_tokens.dart`-ot: spacing konstansok
> (`space4..space32`), radius skála (`radiusSm=8, radiusMd=16, radiusLg=24`,
> `radiusPill=StadiumBorder`), motion `Duration`-ök (`fast=150, base=250,
> slow=350 ms`) és a collapse easing `Curve` (`Cubic(.2,.8,.2,1)`). Add hozzá a
> **metrika-accent** színeket (calories/protein/carbs/fat/steps/weight/water/
> heart) és a **semantic** (positive/negative) színeket téma-érzékenyen (dark/
> light variáns) — pl. egy `AppColors` extension a `ColorScheme`-en vagy egy
> `ThemeExtension`. Még ne kösd be sehova; csak a tokenek álljanak rendelkezésre.

### 03 · Tipográfia – Plus Jakarta Sans + TextTheme
**Prompt:**
> Bundle-öld a **Plus Jakarta Sans** (.ttf, 400/500/600/700/800) fontot a
> `mobile/`-ba (assets a `pubspec.yaml`-ban — offline-first, **ne** runtime
> `google_fonts`). Állíts be egy egységes `TextTheme`-et az `app_theme.dart`-ban
> a mockup skálája szerint (display 34/800, headline 26/700, title 20/700,
> body 15/500, label 13/600), és a nagy metrika-számokhoz használj **tabular
> numerals**-t (`FontFeature.tabularFigures`) ahol metrikát írunk ki. Indokold a
> font-dependency-t a commitban (CLAUDE.md). Build, ellenőrizd a betűt.

---

## Fázis 2 — Adaptív navigáció (a redesign zászlóshajója)

### 04 · Megosztott collapse-signal (scroll-irány vezérlő)
**Prompt:**
> Készíts egy megosztott "collapse" jelzőt, ami a scroll **irányából** vezérli a
> sávok össze-/széthúzását, pontosan a `Lifey Nav Prototype.dc.html` végi JS
> szerint: induláskor kibontva; `scrollTop < 20` → mindig kibontva; lefelé
> görgetés (és még nincs összehúzva) → összehúz; felfelé (és össze van húzva) →
> kibont; `|dy| < 5` küszöb alatt ignorál. Flutterben ezt
> `NotificationListener<UserScrollNotification>` (vagy `ScrollController`) +
> egy `ValueNotifier<bool> collapsed` / kis Riverpod controller adja, amit a
> shell és a sávok közösen olvasnak. Még ne kösd a UI-ra — csak a jelzés és egy
> egyszerű teszt/Smoke legyen kész. (Hely: `lib/shared/widgets/` vagy
> `lib/core/`.)

### 05 · Adaptív bottom nav (kibontott ↔ ikon-only pill)
**Prompt:**
> Készítsd el `lib/shared/widgets/adaptive_bottom_nav.dart`-ot a mockup szerint
> (Redesign "Adaptive bottom nav" komponens + 01 vs 02 képernyő): **lebegő**,
> a szélektől behúzott (`left/right` margó), lekerekített sáv (`radius 28–30`),
> lágy árnyékkal; tartalma az 5 destináció (Home/Food/Train/Weight/Stats) a
> meglévő ikonokkal (outline = inaktív, **filled = aktív**, primary szín).
> Kibontott: ikon + rövid címke. Összehúzott (a 04-es jelzőre): **középre
> zsugorodó pill, csak ikonok** (`StadiumBorder`, címkék eltűnnek), animálva
> (`AnimatedContainer`/`AnimatedSize` + opacity, 250–400 ms, collapse easing).
> Az aktív tab logika maradjon a `MainShell` `goBranch`-é — ez a widget csak a
> megjelenítés + tap-callback. Még ne cseréld le a `MainShell` `NavigationBar`-ját.

### 06 · Adaptív app bar (kibontott ↔ slim strip)
**Prompt:**
> Készítsd el `lib/shared/widgets/adaptive_app_bar.dart`-ot a mockup szerint
> (01 expanded vs 02 collapsed top strip): **lebegő, behúzott**, lekerekített
> (`radius 24` kibontva, `18` összehúzva), `backdrop blur` + lágy árnyék;
> bal oldalt cím (kibontva nagyobb, opcionális al-sor; összehúzva kisebb),
> jobb oldalt **ikon-akciók** mindig (pl. settings/logout, vagy back).
> A kibontott↔slim váltást a 04-es megosztott jelző vezérli, a bottom navval
> **szinkronban**, ugyanazzal az easinggel. Készíts egy egyszerű, paraméterezett
> API-t (`title`, opcionális `subtitle`, `leading`, `actions`). Még ne kösd be a
> képernyőkre.

### 07 · Shell + képernyők bekötése az adaptív sávokhoz
**Prompt:**
> Kösd össze a darabokat: a `MainShell` (`lib/shared/widgets/main_shell.dart`)
> használja az `AdaptiveBottomNav`-ot a `NavigationBar` helyett, és adja tovább a
> 04-es collapse-jelzőt. Minden top-level képernyő (Dashboard, Nutrition,
> Workouts, Weight, Statistics) `AppBar`-ját cseréld `AdaptiveAppBar`-ra, és a
> képernyők fő görgethetője küldje a `UserScrollNotification`-t a megosztott
> jelzőnek. A tartalom **a lebegő sávok ALATT** görögjön (megfelelő top/bottom
> padding + `SafeArea`/notch + home-indicator kezelés). A `/settings` és a
> pushed editor-képernyők (`log_session_screen`, stb.) is `AdaptiveAppBar`-t
> kapnak (settingsnél back + cím; nincs bottom nav). Ellenőrizd: lefelé görgetve
> mindkét sáv összehúz, felfelé kibont, szinkronban.

---

## Fázis 3 — Megosztott komponensek restyle

### 08 · StatCard + makró-kártyák + WaterCard restyle
**Prompt:**
> Stilizáld át a `StatCard`-ot (`features/dashboard/presentation/widgets/
> stat_card.dart`) és a `WaterCard`-ot a mockup szerint (Redesign Components +
> 01 Dashboard): lekerekített container-felület (`radius 20–24`), bal felül
> metrika-ikon az accent színnel, nagy **tabular** érték + egység, alul vékony
> (`5–8px`) pill-progress a `ratio`-ból, a `goalTone` szerint pozitív (olíva) /
> negatív (`#E08A52`) színnel. A makró mini-kártyák (Protein/Carbs/Fat) a
> per-metrika accentet használják. A `WaterCard` a water-accentet (`#6FA8C4`) és
> a `+` gombot lekerekített négyzetként. Csak vizuális változás — az API
> (`label/value/unit/icon/color/ratio/goalReached/goalTone/trailing/onTap`)
> maradjon. A "320 left / +180 over" badge **NEM** ide tartozik → `19 #A4`.

---

## Fázis 4 — Képernyőnkénti restyle

### 09 · Dashboard
**Prompt:**
> Stilizáld át a Dashboard-ot (`features/dashboard/presentation/dashboard_screen
> .dart`) a 01 mockup szerint: kártya-sorrend és térközök (water → kalória nagy
> kártya → makró-sor → steps+weight sor → recent workouts), a szekciócímek a
> label-stílussal, a recent-workout csempék lekerekített ikondobozzal. Használd a
> 08-as komponenseket és a tokeneket. Ami **nincs még funkció** mögött, azt
> hagyd ki vagy placeholderként, `// TODO(new-feature #…)` jegyzettel a
> `19-new-features.md`-re: greeting (#A1), "Today's meals" bontás (#A2),
> dashboard sparkline (#A3), kalória left/over badge (#A4), gazdag workout-csempe
> (#A5). A steps "of N goal" felirat (a step-goal létezik) bekerülhet.

### 10 · Nutrition (tabok + listák + FAB)
**Prompt:**
> Stilizáld át a Nutrition-t (`nutrition_screen.dart` + `foods_tab`/`meals_tab`/
> `recipes_tab`) a 02 mockup szerint: a 3 tab egy **pill-szegmens**
> (`StadiumBorder`, aktív = primary, inaktív = onSurfaceVariant) a TabBar helyett
> vagy annak átstílusozásával; a lista-sorok lekerekített kártyák bal ikondobozzal
> + cím + makró-alsor; a context-aware **extended FAB** lekerekített (`radius 18`),
> primary. A fejléc `AdaptiveAppBar`. Search (#B1) és a "Recent" quick-add (#B2)
> **NEM** ennek a lépésnek a része → `19`. Csak a meglévő tartalom restyle-ja.

### 11 · Workouts (lista + log session)
**Prompt:**
> Stilizáld át a Workouts tabot (`workouts_screen.dart` + `sessions_tab`/
> `templates_tab`/`exercises_tab`) ugyanazzal a pill-tab + kártyasor mintával,
> és a **log session** képernyőt (`log_session_screen.dart`) a 03 mockup szerint:
> `AdaptiveAppBar` back + cím + **timer chip**; gyakorlat-kártya
> (`radius 22`) set-sorokkal (Set/Kg/Reps + `check_circle`/`radio_button_
> unchecked`), kész set-sor halvány primary háttérrel; "Add set" / "Add exercise"
> lekerekített akciók (utóbbi szaggatott szegély); alul **"Finish workout"**
> primary sáv-gomb. A rest-timer banner stílusát is hozd (primary-tinted). A
> Health-kártyák (active kcal / avg bpm) **csak akkor**, ha az adat már létezik a
> UI-ban — különben kihagyni → `19 #D1`. Kardió-típus (#C1) nincs itt.

### 12 · Weight (chart-kártya + range + history + FAB)
**Prompt:**
> Stilizáld át a Weight tabot (`weight_screen.dart`) a 04 mockup szerint:
> felül chart-kártya (`radius 24`) a jelenlegi súly nagy értékével + range-delta,
> **pill-szegmens** range választó (Week/Month/Quarter/All), és a meglévő
> `TimeSeriesChart` átszínezése a primary olívára (vonal + halvány area-fill +
> pont-jelölők) — a chart-widget vizuális paramétereit igazítsd, **ne** írj új
> chartot. History-sorok lekerekített kártyák fel/le trend-nyíllal (pozitív=olíva,
> emelkedés=barna `#C49A6C`). Lekerekített `+` FAB. A range-delta felirat ha még
> nincs számolva → `19 #F`.

### 13 · Statistics (metrika-chipek + KPI kártyák + chart)
**Prompt:**
> Stilizáld át a Statistics-et (`statistics_screen.dart`) a 05 mockup szerint:
> görgethető **metrika-chip** sor (aktív = primary, ikonnal), **pill-szegmens**
> range, KPI-kártyák (Average/Trend/Min/Max/Total) lekerekítve, ikonnal, tabular
> számokkal (trend nyíllal + színnel), majd a chart-kártya a primary olíva
> `TimeSeriesChart`-tal. A tappható chart-pont tooltip (érték+dátum), ha még
> nincs kész → `19 #F`; egyébként csak vizuális igazítás.

### 14 · Settings (csoportkártyák + szegmensek + goals grid)
**Prompt:**
> Stilizáld át a Settings-et (`settings_screen.dart`) a 06 mockup szerint:
> csoportcímek (label-stílus), **csoport-kártyák** (`radius 20`) sorokkal +
> elválasztókkal; Units/Theme/Language mint **pill-szegmensek** ill. a Language
> mint sor; **Daily goals** 2-oszlopos **grid** kis kártyákkal (ikon + cím +
> érték, calories/protein/water/steps + carbs/fat is), tabular számokkal;
> Integrations csoport: "Manage water sources" sor chevronnel, Apple Health
> **Switch** átstílusozva (primary). Csak megjelenítés — a meglévő mezők/akciók
> maradnak.

### 15 · Auth (Login + Register) – márkás belépő
**Prompt:**
> Stilizáld át a Login és Register képernyőket (`login_screen.dart`,
> `register_screen.dart`) a 07/08 mockup szerint: középre rendezett tartalom,
> `eco` logó lekerekített primary dobozban + halvány radiális glow a háttérben,
> nagy display-cím, lekerekített inputmezők (`radius 18`) bal ikonnal
> (mail/lock/person) + jelszó láthatóság-toggle, primary "Sign in" / "Create
> account" sáv-gomb nyíllal, alul váltó link. A **"Forgot password?"** (#E1) és a
> **jelszó-erősség mérő** (#E2) **csak vizuálisan** kerülhet be statikusként, vagy
> hagyd ki — a működésük a `19`-ben van. Ne adj hozzá auth-logikát.

---

## Fázis 5 — Csiszolás

### 16 · Empty / error / loading állapotok + záró polish
**Prompt:**
> Egységesítsd az empty / error / loading állapotokat (a meglévő `EmptyView`/
> `ErrorView` minták + a Weight/Stats empty állapotai) az új tokenekre: nagy
> halvány ikon, rövid cím + segédszöveg, lekerekített. Cseréld a csupasz
> spinnereket konzisztens, témázott töltőre. Záró pass: nézd át mind az 5 tabot +
> settings + auth + bottom sheet-eket (`showModalBottomSheet`, drag handle) dark
> **és** light témán, EN **és** HU lokálon; ellenőrizd a lebegő sávok safe-area /
> notch / home-indicator viselkedését és a collapse-szinkront. `flutter analyze`
> legyen tiszta.

---

## Sorrend & függőségek

```
01 → 02 → 03            (foundation: szín, token, type — egymásra épül)
        ↓
04 → 05, 06 → 07        (nav: jelző → két widget → bekötés)
        ↓
08                      (megosztott komponensek)
        ↓
09 … 15                 (képernyők — egymástól függetlenek, bármilyen sorrend)
        ↓
16                      (polish, legvégén)
```

A 09–15 képernyő-lépések egymástól függetlenek, így párhuzamosíthatók vagy
tetszőleges sorrendben végezhetők, miután a 01–08 kész. Minden lépés külön
commit; minden lépés után `flutter analyze` + gyors vizuális ellenőrzés.
