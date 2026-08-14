# 55 – Cardio: óra-integráció (Apple Watch + Wear OS)

Státusz: **TERV.** Iteráció: **C5** (a watch-GPS-rész a C4a-ra épül).
Előzmény: [51-cardio-overview-plan.md](51-cardio-overview-plan.md),
[53-cardio-mobile-plan.md](53-cardio-mobile-plan.md).
Watch-alapok (kötelező előolvasás): [../watch/40-watch-app-plan.md](../watch/40-watch-app-plan.md),
[../watch/44-watch-f6-standalone-plan.md](../watch/44-watch-f6-standalone-plan.md) (standalone),
[../watch/49-watch-f6b-template-sync-plan.md](../watch/49-watch-f6b-template-sync-plan.md) (picker-feltöltés).

Érintett meglévő kód:
- Dart-híd: `mobile/lib/core/watch/watch_workout_service.dart`,
  `watch_template_sync_controller.dart`, `features/workouts/application/watch_template_sync.dart`,
  `watch_session_merge.dart`, `standalone_session_processor.dart`,
  `presentation/watch_session_plan.dart`, `watch_mirror_signature.dart`, `watch_set_log_decision.dart`
- watchOS: `mobile/ios/LifeyWatch/` (`WorkoutManager.swift`, `PhoneConnector.swift`,
  `StandaloneSessionPayload.swift`, `StandaloneSessionStore.swift`, `Views/`)
- Wear OS: a `mobile/android` alatti watch-modul (Health Services `ExerciseClient`)

---

## 1. Mit ad hozzá az óra a cardióhoz

Erősítő edzésnél az óra „kényelmi” funkció volt. Cardiónál **ez a mérőműszer**: a pulzus, a
pulzuszóna-eloszlás és a valós kalória csak innen jöhet, kültéren pedig az Apple Watch saját GPS-e
akkor is mér, ha a telefon a zsebben marad — vagy otthon.

Három szint, ebben a sorrendben építve:

| Szint | Mit tud | Iteráció |
|---|---|---|
| **W1 — tükrözés** | A telefonon indított cardio elindítja az órán a helyes típusú workoutot; az óra méri a pulzust/kalóriát; a telefon lezárásakor az óra is zár és összegzést küld | C5 |
| **W2 — egyesített picker** | Az órai indító-listán a tervek **és** a cardio típusok együtt, **gyakoriság szerint rendezve** | C5 |
| **W3 — standalone cardio** | Telefon nélkül indított cardio az óráról, később szinkronizálva | C5 |
| **W4 — watch-GPS** | Kültéri nyomvonal az óráról, ha a telefon nincs a usernél | C5 után, C4a-ra épül |

---

## 2. Aktivitástípus-térkép (R6 kezelése)

A watch app ma **fixen** `traditionalStrengthTraining` / `STRENGTH_TRAINING` konfigurációval
indul. Ha minden cardio így indulna, a rendszer kalóriabecslése és a mozgásgyűrű-kreditelés is
hibás lenne. Ezért az indító payload kap egy `activityType` mezőt, és a natív oldal így képezi le:

| `ActivityType` | watchOS `HKWorkoutActivityType` | `locationType` | Wear OS `ExerciseType` |
|---|---|---|---|
| `INDOOR_BIKE` | `.cycling` | `.indoor` | `BIKING_STATIONARY` |
| `RUNNING` | `.running` | `.outdoor` (terem esetén `.indoor`) | `RUNNING` |
| `WALKING` | `.walking` | `.outdoor` | `WALKING` |
| `HIKING` | `.hiking` | `.outdoor` | `HIKING` |
| `BASKETBALL` | `.basketball` | helyszín szerint | `BASKETBALL` |
| `FOOTBALL` | `.soccer` | helyszín szerint | `FOOTBALL_SOCCER` |
| `OTHER_CARDIO` | `.other` | `.unknown` | `WORKOUT` (általános) |
| *(erősítő)* | `.traditionalStrengthTraining` | `.indoor` | `STRENGTH_TRAINING` |

### D-C5.1 — A `locationType` a `venue` mezőből jön, nem találgatásból

A `GAME` család `venue` mezője (`INDOOR`/`OUTDOOR`, [52 §2.2](52-cardio-domain-backend-plan.md))
közvetlenül vezérli a `locationType`-ot. Ez nem kozmetika: az outdoor jelzés kapcsolja be a GPS-t
és változtatja a kalória-modellt. Ha a `venue` nincs megadva, a `GAME` alap `.indoor` (a
konzervatív, akkukímélő ág), a `DISTANCE` alap `.outdoor`.

### D-C5.2 — Az adattípus-készlet is típusfüggő

Wear OS-en az `ExerciseConfig` `dataTypes` halmaza bővül a családtól függően:
`DISTANCE` → `HEART_RATE_BPM`, `CALORIES_TOTAL`, `DISTANCE_TOTAL`, `PACE`, `ELEVATION_GAIN`;
`MACHINE` → `HEART_RATE_BPM`, `CALORIES_TOTAL`, `DISTANCE_TOTAL` (ha a gép nem adja, üres);
`GAME` → `HEART_RATE_BPM`, `CALORIES_TOTAL`. Nem kérünk olyan adattípust, amit a szenzorkészlet
nem tud — a Health Services különben `ExerciseCapabilities` hibát ad.

---

## 3. Egyesített, gyakoriság-rendezett picker (W2)

Ez a felhasználói követelmény: *„az órán ezek az edzések is listázódjanak a templatek mellett,
és a leggyakrabban használtak kerüljenek előre.”*

### 3.1 A rangsor forrása — **ugyanaz a Dart-függvény**, mint a telefonon

A [53 §3.4](53-cardio-mobile-plan.md) `rankQuickStartEntries()`-e az egyetlen igazságforrás
(D-C.8). A watch-payload összeállítója ugyanezt hívja — **nem** másol logikát, és nem talál ki
saját rendezést. Ha a rangsor a telefonon változik, az órán is ugyanúgy változik.

### 3.2 A payload

Az F6b már pushol max 5 tervet az órára (`watch_template_sync.dart`). Ez bővül **egyesített
listává**:

```jsonc
{
  "version": 2,                       // az F6b payload verziója 1 volt
  "entries": [
    { "type": "TEMPLATE", "id": "…uuid…", "title": "Push A", "exerciseCount": 6 },
    { "type": "CARDIO",   "activityType": "RUNNING", "title": "Futás" },
    { "type": "CARDIO",   "activityType": "INDOOR_BIKE", "title": "Szobabicikli" }
  ]
}
```

- **Max 8 elem** (az F6b 5-ös terv-limitje helyett), mert most kétféle bejegyzés osztozik a
  listán. Az óra natívan görgethető, tehát ez scope-döntés, nem UI-korlát — ugyanaz az érvelés,
  mint a D-F6b.1-nél.
- A `title` **előre lokalizált** a telefon nyelvén; az órának nem kell aktivitás-szótárt vinnie.
  (Az F6b ugyanezt csinálja a terv-nevekkel.)
- A `version: 2` mező miatt egy régi natív watch-build a listát vissza tudja utasítani, és a
  „Quick strength” fallbackre esik, ahelyett hogy ismeretlen bejegyzéseket próbálna renderelni.

### D-C5.3 — A quick-start kártya marad legfelül, a rangsor alatta kezdődik

Az F6a/F6b design (AW 13 / W 12) egy kiemelt „Quick strength” kártyát tesz a lista tetejére. Ezt
**nem** bontjuk meg: a kiemelt kártya továbbra is a leggyorsabb út egy szett-alapú edzéshez, a
rangsorolt lista alatta jön. Indok: a kártya vizuálisan más súlyú, és ha a rangsor néha
odatenne, néha nem, a kezelőfelület kiszámíthatatlanná válna.

### 3.3 Frissítés

A lista akkor pusholódik, amikor az F6b-nél is: alkalmazás-háttérbe kerüléskor, session
befejezésekor és pull-szinkron után — **nem** minden képernyő-építéskor
([53 §3.4](53-cardio-mobile-plan.md) stabilitási megkötése).

---

## 4. Élő cardio az órán (W1)

### 4.1 A `WorkoutSessionState` órai változata

A telefonról az órára ma szett-központú állapot megy (`exerciseName`, `setsDone`, `setsTotal`,
`restRemainingSeconds`…). A [53 §5](53-cardio-mobile-plan.md) `kind` + `cardio` blokkja
ugyanezen a csatornán érkezik az órára is; a watch UI `kind` szerint választ képernyőt.

### 4.2 Órai elrendezések

| Család | Fő szám | Másodlagos | Vezérlők |
|---|---|---|---|
| `DISTANCE` | mozgásidő | táv · tempó · **élő pulzus** | szünet/folytatás, kör (lap) |
| `MACHINE` | mozgásidő | pulzus · kalória | szünet/folytatás |
| `GAME` | játékidő | pulzus · zóna-jelző | **pályán/padon** kapcsoló, szünet |

**A pulzus az órán mindig az elsődleges másodlagos metrika** — ez az egyetlen adat, amit csak az
óra tud, és a felhasználó ezért néz oda.

A `GAME` „pályán/padon” kapcsolója az órán is ott van, mert egy meccs alatt a telefon a
táskában van. A kapcsoló állapota mindkét irányban szinkronizálódik (óra ↔ telefon), a meglévő
üzenet-csatornán.

### 4.3 Zárás és összegzés

A meglévő út (`transferUserInfo` / `DataClient`) bővül: az összegzés a pulzus/kalória/health-id
mellett **pulzuszóna-eloszlást**, és — ha az óra mért — **távot és szintemelkedést** is visz.
Ezek a `cardio_details` megfelelő mezőibe kerülnek `source = DEVICE` jelöléssel, és **csak akkor
írják felül** a telefon mérését, ha a telefonnak nincs saját mérése (a kézi érték mindig nyer,
[51 R8](51-cardio-overview-plan.md)).

---

## 5. Standalone cardio (W3)

Az F6a/F6b már megoldotta a nehezét: az óra a mester, lokálisan tárolja a sessiont
(`StandaloneSessionStore`), és a telefon a `standalone_session_processor.dart`-ban dolgozza fel.
A cardio-bővítés ehhez képest:

1. A `StandaloneSessionPayload` kap `kind` + `activityType` + cardio-metrika blokkot (szettek
   helyett). A payload verziószáma nő; a telefon-oldali feldolgozó **mindkét** verziót elfogadja.
2. A `standalone_session_processor` `kind` szerint ágazik: `CARDIO` esetén nem gyakorlatot
   old fel, hanem `cardio_details`-t ír, és a session `templateClientId`/`templateName` mezőit
   üresen hagyja (nincs terve).
3. A `watch_session_merge.dart` és a `watch_set_log_decision.dart` **kihagyja** a cardio
   sessionöket (nincs szett, amit összefésülni) — ez a [53 §0](53-cardio-mobile-plan.md) auditja
   szerinti kötelező érintés.

### D-C5.4 — A telefon-oldali feldolgozó előbb készül el, mint a watch-küldő

Az F6b-ben ez tanulság volt (a T5 azért került előre, hogy a fogadó előbb legyen kész, mint a
küldő). Itt ugyanígy: a `standalone_session_processor` cardio-ága a C5 első lépése, a natív
watch-oldal utána jön. Így egy félkész watch-build sosem termel feldolgozhatatlan adatot.

---

## 6. Watch-GPS (W4)

Apple Watchon a `HKWorkoutSession` `.outdoor` `locationType`-pal magától használja az óra GPS-ét,
és a `HKWorkoutRouteBuilder`-rel útvonalat is menthet. Wear OS-en a Health Services
`LOCATION` adattípusa adja ugyanezt.

Ekkor eldöntendő (**a C4a után, külön mini-terv**): melyik nyomvonal az igazság, ha a telefon és
az óra is mért. Javaslat: a **telefon nyer**, ha van érvényes nyomvonala (több pont, jobb
pontosság), különben az óráé — és az összegzés jelzi a forrást. Két nyomvonalat sosem fésülünk
össze.

---

## 7. Feladatlista (C5)

| # | Lépés | Oldal |
|---|---|---|
| W-1 | `standalone_session_processor` + `watch_session_merge` + `watch_set_log_decision` cardio-ága (D-C5.4) | Dart |
| W-2 | Indító payload `activityType`/`venue` mezője + `WatchWorkoutService` API-bővítés | Dart |
| W-3 | `WorkoutSessionState` `kind`/`cardio` blokk átvitele az órára | Dart + natív |
| W-4 | Egyesített picker payload (`version: 2`) a `rankQuickStartEntries()`-ből | Dart |
| W-5 | watchOS: aktivitástípus-térkép, cardio aktív képernyők (3 elrendezés), picker-sorok | Swift |
| W-6 | Wear OS: `ExerciseType`/`dataTypes` térkép, ugyanazok a képernyők | Kotlin |
| W-7 | Zárás-összegzés bővítés (zónák, táv, szintemelkedés) + telefon-oldali beírás forrás-jelöléssel | mindkettő |
| W-8 | Standalone cardio payload + óra-oldali indítás | mindkettő |
| W-9 | `GAME` pályán/padon kapcsoló kétirányú szinkronja | mindkettő |
| W-10 | Eszközös végpróba mindkét platformon (a watch-docok bevett gyakorlata) | – |

**Design — kész (2026-08-10).** A cardio watch-frame-ek a
[`design/Lifey Cardio Watch Design.dc.html`](design/Lifey%20Cardio%20Watch%20Design.dc.html)
fájlban élnek, a meglévő `docs/watch/design/Lifey Watch Design.dc.html` számozásának
folytatásaként (az ott legmagasabb frame **AW 15 / W 14** volt):

| Frame | Tartalom | Lépés |
|---|---|---|
| AW 16 / W 15 | Egyesített indító lista | C5.4 / C5.6 |
| AW 17–20 / W 16–19 | Aktív cardio ×3 család + GAME padon | C5.5 / C5.6 |
| AW 21 / W 20 | Összegzés + szinkron | C5.7 |
| AW 22 / W 21 | Gyenge jel · nincs pulzus | C5.5 / C5.6 |

A lépések részletei: [59-cardio-implementation-plan.md §9](59-cardio-implementation-plan.md).
