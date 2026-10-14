# Lifey – New features implied by the design (backlog, NOT part of the redesign)

> **Mi ez?** A `docs/design/` mockupokon (`18-design-system-prompt.md` +
> `design-handoff/.../Lifey Redesign.dc.html` + `Lifey Nav Prototype.dc.html`)
> több olyan UI-elem szerepel, amihez **jelenleg nincs funkció / adat a kódban**.
> Ezek tetszenek és **később** akarom implementálni — de a mostani redesign
> (lásd `20-design-implementation-tasks.md`) ezeket **NEM** tartalmazza.
>
> A redesign során ezeket az elemeket vagy **kihagyjuk**, vagy a meglévő adatból
> kiszolgálható **statikus / placeholder** változatban jelenítjük meg, és ide
> tesszük a "csináld meg rendesen" jegyzetet.
>
> ⚠️ Mielőtt bármelyiket építenénk: **ellenőrizni kell**, hogy tényleg hiányzik-e
> (a kódbázist csak részben néztem át). Ahol bizonytalan, ott jelölöm.

---

## Állapot (2026-10-14, LIF-114)

Tételenként a kódhoz mérve (mobil; ahol a webnek is van párja, jelölve). A lista létrehozása óta szinte minden elkészült
a redesign részeként; az **egyetlen valóban hiányzó** a jelszó-erősség mérő a mobilon (LIF-157).

| Tétel | Állapot | Hol van |
|---|---|---|
| A1 Napszak-köszöntés | ✅ kész | `dashboard_screen.dart`, ARB `greeting*` |
| A2 Étkezések típus szerint a dashboardon | ✅ kész | `Meal.mealType`, `today_meals_section.dart` (`mealTypeStyle`) |
| A3 Heti kalória-sparkline | ✅ kész | `weekly_calories_card.dart` |
| A4 „maradt / túl" a kalóriánál | ✅ kész | `calorie_hero_card.dart` (a gyűrű a hátralévő kcal-t, túllépésnél a többletet írja) |
| A5 Gazdagabb edzés-csempe | ✅ kész | `recent_workouts_section.dart` (időtartam · gyakorlatszám · kcal) |
| B1 Kereső a Nutrition fejlécben | ✅ kész | `nutrition_screen.dart` (Receptek és Ételek fül) |
| B2 „Recent" gyors-hozzáadás | ◐ részben | a legutóbbi ételek chipjei a bejegyzés-lapon (`recentFoodsByUsage`), egy koppintás kiválasztja az ételt és előtölti az utolsó mennyiséget; **egy koppintásos naplózás nincs** (még a mennyiség-lap jön) |
| C1 Kardió-edzés | ✅ kész | `cardio_session_screen.dart`, `cardio_summary_screen.dart` (`docs/cardio/`) |
| D1 Health-adatok az edzés fejlécében | ✅ kész | `workout_header_pills.dart` (pulzus, kcal), a session `activeCalories` / `averageHeartRate` mezői |
| E1 Elfelejtett jelszó | ✅ kész | `forgot_password_screen.dart`, `AuthController` (web: `forgot-password`) |
| E2 Jelszó-erősség mérő | ❌ mobilon nincs | a webnek van (`PasswordStrength.tsx`); mobil: **LIF-157** |
| F Súly-változás a fejlécben | ◐ részben | `weight_hero_header.dart`: „az utolsó óta" és „30 nap" delta, nem a kiválasztott időszaké |
| F Tappintható chart-pont tooltip | ✅ kész | `time_series_chart.dart` |
| F Lépés „… célból" felirat | ✅ kész | `dashboard_tiles.dart` (`dashboardStepsOfGoal`) |
| F Étel-ikonok | ✅ kész | `mealTypeStyle` (kategória → ikon) |

---

## A. Dashboard

### A1. Greeting / napszak-fejléc — "Good morning · Today"
A redesign felső sávján a dashboardon napszak szerinti köszöntés van
(`Good morning` + `Today`). Jelenleg az AppBar címe a fix `dashboardTabLabel`.
- **Kell:** napszak-logika (reggel/délután/este) + opcionálisan a user neve.
- **Adat:** a user neve nincs a dashboard kontextusban; auth prof­ilból jönne.
- ARB: új kulcsok (`greetingMorning`, `greetingAfternoon`, `greetingEvening`).

### A2. "Today's meals" – étkezés-bontás a dashboardon (Breakfast / Lunch / Dinner)
A Nav Prototype dashboardján az étkezések **meal-type szerint csoportosítva**
jelennek meg (Breakfast/Lunch/Dinner, kcal összeg, chevron a részletekhez).
- **Jelenleg:** a dashboard csak az aggregált napi kalóriát/makrót mutatja, a
  meal-listát a Nutrition → Meals tab tartalmazza, és nincs meal-type fogalom.
- **Kell:** `Meal`-hez meal-type mező (breakfast/lunch/dinner/snack) + napi
  csoportosítás + dashboard szekció. Ez **adatmodell-változás** (backend +
  Flyway migration + drift tábla + ARB).

### A3. Dashboard mini-trend (sparkline) – "This week · calories"
A Nav Prototype dashboardján egy kis heti kalória-sparkline van (avg badge-dzsel).
- **Jelenleg:** a dashboardon nincs grafikon; idősor csak a Weight/Statistics
  tabon van (`TimeSeriesChart`).
- **Kell:** a `TimeSeriesChart` egy kompakt, tengely nélküli "sparkline"
  variánsa + a dashboard controller heti aggregátuma. (Az adat már létezik a
  statistics aggregációból — főleg UI + egy kis sparkline mód.)

### A4. Kalória "left / over" badge — "320 left" / "+180 over"
A kalória kártyán szöveges badge a maradék/túllépés kcal-ról.
- **Jelenleg:** a `StatCard` `ratio` + `goalReached` + `goalTone` alapján csak a
  progress bart színezi; nincs kiírt "maradék/túl" szám.
- **Kell:** egyszerű derived szöveg (`goal - actual`), és ARB kulcsok
  (`kcalLeft`, `kcalOver`). Kicsi, de új megjelenítés. *(Könnyű — akár a
  redesignba is behúzható, ha gyors.)*

### A5. Gazdagabb "recent workout" csempe — időtartam · gyakorlatszám · kcal
A mockup csempéi: `52 min · 6 exercises · 312 kcal`.
- **Jelenleg:** a `RecentWorkout` csempe a dátumot, a gyakorlatneveket és a
  set-számot / "in progress" chipet mutatja.
- **Kell:** session-időtartam (`finishedAt - startedAt`) formázás, gyakorlatszám,
  és az égetett kcal (utóbbi az Apple Health `activeCalories`-ból — lásd D1).

---

## B. Nutrition

### B1. Kereső a Nutrition fejlécben (`search`)
A scrollozott Nutrition fejléc `search` ikont mutat.
- **Kell:** food/recipe kereső (lokális, drift `LIKE`/FTS). Ellenőrizni, van-e
  már bármilyen szűrés a tabokon — ha nincs, ez új funkció.

### B2. "Recent" gyors-hozzáadás a Foods tabon (`add_circle` quick-log)
A mockup egy "Recent" szekciót mutat, ahol egy koppintással (`add_circle`)
naplózható egy korábban használt étel.
- **Kell:** legutóbb használt ételek lekérdezése + 1-kattintásos meal-logolás
  alapértelmezett mennyiséggel. Ellenőrizni a jelenlegi log-meal flow-t.

---

## C. Workouts

### C1. Kardió / futás workout-típus (`directions_run`, "Zone 2 run", táv/km)
A Nav Prototype "Zone 2 run · 6.1 km" kardió bejegyzést mutat.
- **Jelenleg:** a workout modell erősítés-központú (template → exercise → set →
  reps/weight). Nincs táv/idő alapú kardió.
- **Kell:** kardió session-típus (táv, idő, tempó, kcal) — **adatmodell-bővítés**
  backend + migration + drift + UI. Nagyobb feature.

---

## D. Apple Health / integrációk

### D1. Session-szintű Health enrichment a UI-ban — active kcal + avg bpm
A log-session fejlécben `214 active kcal` és `128 avg bpm` kártyák.
- **Állapot:** a `WorkoutSession` domainben **létezik** `activeCalories` és
  `averageHeartRate` (lásd `docs/17-statistics-page-plan.md`), de **ellenőrizni
  kell**, hogy a session-képernyő ténylegesen megjeleníti-e már. Ha nem: csak UI.

---

## E. Auth

### E1. "Forgot password?" flow (login)
A login képernyőn `Forgot password?` link.
- **Jelenleg:** nincs jelszó-visszaállítás (csak login/register, JWT+refresh).
- **Kell:** backend endpoint (e-mail token), mobil flow, ARB. Önálló feature.

### E2. Jelszó-erősség mérő (register)
A register képernyőn 3 szegmenses erősség-jelző ("Strong").
- **Kell:** kliensoldali jelszó-erősség kiértékelés + sáv. Tisztán frontend,
  kicsi.

---

## F. Egyéb apró, design-szintű derived elemek

| Elem | Hol | Megjegyzés |
|---|---|---|
| Weight range-delta ("−1.8 kg" a kiválasztott időszakra) | Weight chart fejléc | Derived a chartadatból; ellenőrizni, van-e már. |
| Statistics tappható chart-pont tooltip (érték + dátum) | Statistics / Weight chart | A `17-statistics-page-plan.md` tervezi; lehet, még nincs kész. Ha nincs: a `TimeSeriesChart` bővítése. |
| Steps "of 9,000 goal" felirat | Dashboard steps kártya | A step-goal **létezik** (settings + backend `V17`); csak a "goal" felirat megjelenítése. Valószínűleg könnyű / a redesign része lehet. |
| Recipe ikon / set_meal / lunch_dining per-étel ikonok | Nutrition listák | Kategória → ikon mapping; ha nincs kategória-adat, fix ikon. |

---

## Hogyan használjuk ezt a listát

1. A **redesign** (`20-...`) során, ahol egy mockup-elem ezekből táplálkozna,
   placeholder/statikus megjelenítést teszünk, **vagy kihagyjuk**, és a kód mellé
   `// TODO(new-feature #A2)` jellegű jegyzetet írunk erre a fájlra hivatkozva.
2. Amikor egy feature-t implementálni akarsz, abból **külön** terv/prompt készül
   (backend + Flyway + drift + Riverpod + UI), a projekt szabályai szerint.
3. Mielőtt bármelyikbe belevágunk: **verifikáljuk a jelenlegi állapotot** (a
   ⚠️-vel jelölt pontoknál biztosan), nehogy meglévőt építsünk újra.
