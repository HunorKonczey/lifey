# 48 – F5b terv: Reps/súly állítása a watchról

Státusz: **F5b KÉSZ, 2026-07-26** — mindkét platform kódja lezárva (S1–S12), és a kézi végpróbák (S8 iOS, S13 Android) is lefutottak: a fejlesztő eszközön visszaigazolta, hogy a flow működik. A regressziós kör (S14) zöld.
Az előfeltétel **teljesült**: az F5a kód kész (43-doc §11 S1–S13) **és** a kézi végpróbák (S9 iOS, S14 Android) lefutottak — a fejlesztő 2026-07-26-án eszközön visszaigazolta, hogy az egy-tapos flow működik. A §11 nyitott kérdései **mind eldöntve** (2026-07-26); designer-jóváhagyásra váró tétel nem maradt.

**Az F5b közvetlen kiváltó oka** — az F5a eszközös használata során: ha a gyakorlatnak nincs több kitöltetlen tervezett sora (vagy terv nélkül, ad-hoc került fel), akkor minden watch-tap egy **üres** szettet rögzít. Ez az F5a-ban szándékos és dokumentált viselkedés (43-doc §5.2/4 — a watch nem küld értéket, a telefon azt logolja, ami a sorban van), de a gyakorlatban kevéssé hasznos; ezt a hiányt zárja be ez a terv.

Kapcsolódó dokumentumok:
- [43-watch-f5-set-logging-plan.md](43-watch-f5-set-logging-plan.md) — az F5a terv; a §12 az itt feloldandó **crown/rotary ütközést** írja le, a §3.4 jegyzi az `log_adjust_*` kulcsokat, a §5.2 a telefon-oldali sor-választást.
- [44-watch-f6-standalone-plan.md](44-watch-f6-standalone-plan.md) — a D-F6.8 fix `reps = 10`-et használ standalone módban **kifejezetten azért, mert az F5b még nincs meg**; a §4.1 protokoll már ma is visz `reps`-et szettenként, hogy ez a terv ne bontson protokollt.
- `docs/watch/design/Lifey Watch Design.dc.html` — **AW 10** (Apple Watch) és **W 09** (Wear OS) frame: „F5 — crown adjust (secondary, ships later)” / „F5 — rotary adjust (secondary)”, plusz az „F5/F6 string keys” tábla `log_adjust_*` sorai.
- [41-watch-design-prompt.md](41-watch-design-prompt.md) — §4/3: az adjust „clearly secondary”, az egy-tapos út a fő.

---

## 0. Design-szinkron napló (2026-07-26)

Amit a canvas **megad**:

| # | Design-elem | Frame | Következmény erre a tervre |
|---|---|---|---|
| 0.1 | Fejléc `tune` ikon + „ADJUST”, **secondary barna** `#C49A6C` | AW 10 / W 09 | A barna a „mellékút” jelölése — a `LifeyColors.secondary` token már létezik mindkét platformon, új szín nem kell |
| 0.2 | Szegmens-pár: **Reps** (kiválasztva) / **Weight** | AW 10 / W 09 | Két állítható mező, egyszerre egy aktív; váltás tappal (a Wear-jegyzet explicit: „toggle via tap”) |
| 0.3 | Nagy szám + fel/le chevron (AW), ill. **rotary-ív** a bezelen (W 09) | AW 10 / W 09 | A stepper értékét a crown/rotary lépteti; a chevronok **visszajelzés**, nem feltétlenül gombok |
| 0.4 | Alatta caption: „reps · 60 kg” | AW 10 / W 09 | A *másik* (épp nem szerkesztett) érték is látszik — egy sorban, kis szedéssel |
| 0.5 | Primary gomb: **„Log 12 reps”** | AW 10 / W 09 | Explicit megerősítés — az adjust **nem** logol magától az érték állításakor |
| 0.6 | „Revealed only by rotating the crown while on the log page — the one-tap »as planned« flow never sees it; **2 s idle dismisses back**” | AW 10 jegyzet | Reveal-gesztus + auto-dismiss; a reveal ütközik a lapozással → **D-F5b.1** |
| 0.7 | Kulcsok: `log_adjust_title` / `_reps` / `_weight` / `_confirm` | string-tábla | §5 — négy kulcs, a `_confirm` paraméteres (`Log {n} reps`) |

Amit a canvas **nem** ad meg, és ez a terv dönti el:

| # | Hiány | Hol döntjük el |
|---|---|---|
| 0.8 | Honnan jön a stepper **kezdőértéke** (a „12” és a „60 kg”) | **D-F5b.2** — protokoll-bővítés, ez a terv legnagyobb rejtett munkája |
| 0.9 | **Lépésköz** és határok (reps ±1? súly ±2,5 kg?) | **D-F5b.5** |
| 0.10 | Mértékegység (a frame „kg”-ot ír, de a Settingsben van `UnitSystem`) | **D-F5b.4** |
| 0.11 | Mi történik, ha a telefon időközben **másik sorra lépett**, mint amire a prefill vonatkozott | **D-F5b.6** + §8 |
| 0.12 | A `Weight` szegmens **súly-lépés tizedessel** (2,5) hogyan fér ki a korongon | S7/S12 vizuális kör |

---

## 1. Cél és scope

**Cél:** a user az óráról ne csak *„+1 szett, ahogy terveztem”*-et tudjon logolni (F5a), hanem **konkrét ismétlésszámmal és súllyal** is — telefon-elővétel nélkül. A telefon marad a mester: a watch továbbra is csak eseményt küld, de az esemény immár **hozhat értékeket is**.

**A valós fájdalom, amit megold** (F5a használat közben derült ki): ha a gyakorlat tervezett sorai már mind készen vannak — vagy a gyakorlat terv nélkül, ad-hoc került fel —, akkor az F5a minden tapre egy **üres** (súly/ismétlés nélküli) szettet rögzít, mert a watch nem tud értéket küldeni, a telefon pedig azt logolja, ami a sorban van (43-doc §5.2/4). Ez a viselkedés az F5a-ban szándékos és dokumentált, de a gyakorlatban kevéssé hasznos.

### V1 scope (F5b)

1. **Adjust-nézet** a log-lapon, a designnak megfelelő reveal-lel (AW 10 / W 09) — a crown/rotary ütközés feloldásával (**D-F5b.1**).
2. **Reps és súly stepper**, kezdőértékkel a telefonról (**D-F5b.2**).
3. A `logSet` protokoll **opcionális** `reps`/`weight` mezőkkel (visszafelé kompatibilis — **D-F5b.6**).
4. Telefon-oldal: az értékekkel érkező esemény a **meglévő** `_handleRowEdit` útra kötve (**D-F5b.3**).

### V1-ben tudatosan NEM cél

- **Gyakorlat-váltás a watchról** — a telefon dönti el, melyik gyakorlat aktív, ezen az F5b nem változtat.
- **Már belogolt szett szerkesztése/visszavonása** az óráról — a korrekció a telefonon történik (az F5a §7.1 elfogadott maradék-kockázatával azonos elv).
- **Mértékegység-váltás** (kg ↔ lbs) — lásd **D-F5b.4**.
- **Előzmény-alapú okoskodás a watchon** (pl. „a múltkori 3. szetted 62,5 kg volt”) — ha kell ilyen, azt a **telefon** számolja ki és küldi prefillként; a watch soha nem okosabb a telefonnál.
- Az F6a standalone `reps = 10` defaultjának lecserélése — az **F6b** feladata, de az F5b teszi lehetővé (**D-F5b.8**).

---

## 2. Alapdöntések

### D-F5b.1 — A crown/rotary ütközés feloldása *(a terv legfontosabb nyitott döntése)*

A 43-doc §12 által előre jelzett ütközés **valós, és a kódban ma is így áll**:

- **watchOS** (`Views/ActiveWorkoutView.swift`): a `TabView` kapja a forgatást —
  `.digitalCrownRotation($crownRotation, from: 0, through: 2, by: 1, sensitivity: .low, …)`, kétirányú `crownRotation ↔ selectedPage` kötéssel.
- **Wear** (`ui/ActiveWorkoutScreen.kt`): a `HorizontalPager` kapja —
  `rotaryScrollableBehavior = RotaryScrollableDefaults.snapBehavior(pagerState)`.

Vagyis a designban leírt reveal („forgasd a crownt a log-lapon”) ma **lapozni fog**, nem adjustot nyitni. Három út:

| Opció | Mellette | Ellene |
|---|---|---|
| **(a) A log-lap elnyeli a forgatást** (saját `focusable` + lokális crown/rotary-binding); lapozni onnan csak swipe-pal lehet | Design-hű, pontosan a rajzolt reveal | A **default lapon** (ide érkezik a csuklóemelés) megszűnik a legfontosabb navigációs affordancia; a user lapozni akar, és adjustot kap — meglepő, és pont a leggyakoribb lapon |
| **(b) Long-press a korongon nyitja az adjustot**, utána a crown/rotary lépteti az értéket | Nulla ütközés; a lapozás mind a 3 lapon egységes marad; a long-press szabványos „másodlagos akció” gesztus mindkét platformon | Eltér a rajzolt reveal-szabálytól; a long-press kevésbé felfedezhető (de a design maga is „clearly secondary”-nak nevezi ezt az utat) |
| **(c) Kis „Adjust” gomb a log-lapon** | Felfedezhető, nulla gesztus-ütközés | Elveszi a helyet a korongtól, amit az F5a §3.1 pont azért csinált óriásira („5× a 48 px minimum”); vizuálisan is szembemegy a „one huge tap target” döntéssel |

**Javaslat: (b).** Indoklás: az (a) ára aránytalan — a log-lap az **első/alapértelmezett** lap, a crown ott a lapozás elsődleges eszköze, és ezt egy másodlagos funkcióért feláldozni rosszabb csere, mint egy kevésbé felfedezhető reveal-gesztus. A (c) a korong méretét bontja meg, ami az F5a egyik kifejezett design-nyeresége volt.

**ELDÖNTVE (2026-07-26): (b) — long-press a korongon.** Ez felülírja a canvas explicit reveal-szabályát (0.6); a design szándéka („secondary, a fő flow soha nem látja”) sértetlen marad, csak a gesztus más. Két kiegészítés tartozik a döntéshez:

- **Felfedezhetőségi ellensúly:** a (b) egyetlen valós hátránya, hogy a long-press rejtett. Ezt egy **apró, nem-interaktív `tune` glyph** oldja meg a korong alsó részén, a „+1 szett” felirat alatt, `LifeyColors.secondary` (barna) színnel — ugyanaz a barna, amivel a design az adjustot mint mellékutat jelöli (0.1). Nem vesz el tap-területet (a korong egésze marad a tap-target), de jelzi, hogy van egy másodlagos akció. Ez a terv kiegészítése a designhoz képest, nem a canvasból jön.
- **Implementációs csapda:** a long-press **nem indíthatja el egyszerre a sima tapet is** (különben egy adjust-nyitás egyúttal logolna is egy szettet a régi értékekkel). watchOS-en a `Button` action + `.onLongPressGesture` együtt **mindkettőt** eltüzelheti — a korongot ezért ne `Button`-ként, hanem `.gesture(ExclusiveGesture(LongPressGesture(), TapGesture()))`-szel kell kötni (a hosszú nyomás nyer). Wearen a `combinedClickable(onClick =, onLongClick =)` ezt magától helyesen kezeli. **Ez az S7/S12 lépés első ellenőrzendő pontja.**

### D-F5b.2 — A stepper kezdőértékét a **telefon** küldi, a watch nem találgat

A stepper nem indulhat 0-ról vagy fix 10-ről: az „állítok egy kicsit a terven” flow csak akkor gyors, ha a **releváns** értékről indul. A watch viszont ma nem tudja, mi az a releváns érték — a `WorkoutSessionState` (`core/workout_session_notifier/workout_session_notifier_service.dart`) ma **nem visz sem súlyt, sem ismétlést**:

```
exerciseName, setsDone, setsTotal, totalSetsDone,
lastSetAtEpochMs, restEndsAtEpochMs, restTotalSeconds, restRemainingSeconds
```

**A döntés:** a `WorkoutSessionState` bővül két opcionális mezővel — `nextSetWeight` (`double?`) és `nextSetReps` (`int?`) —, amiket a telefon **ugyanabból a sorból** számol, amit egy watch-tap logolna. Prioritás:

1. a cél-sorban lévő érték, ha ki van töltve (tervezett/előtöltött súly-ismétlés);
2. különben a gyakorlat **előző teljesítménye** az adott pozícióra (`ExerciseBlock.previousSets[index]` — a `PreviousSetHint {weight, reps}` már létezik és be van töltve, `_loadPreviousPerformance`);
3. különben az adott blokk **utolsó készre jelölt** sorának értéke (ugyanabban a sessionben);
4. különben `null` → a watch a saját defaultjáról indul (reps 10, súly 0), és ezt vizuálisan is jelzi (nincs mit „módosítani”, ez új adat).

**Következmény a kódra:** a cél-sor kiválasztása ma a `decideWatchSetLog()`-ban él (`features/workouts/presentation/watch_set_log_decision.dart`), de az `eventId`/dedup paramétereket is kér. A prefill-számításhoz **ki kell emelni a tiszta sor-választót** (pl. `selectWatchSetLogTarget(blocks, currentBlock) → WatchSetLogTarget?`), és mind a logolás, mind a prefill erre épüljön — így a kettő **garantáltan ugyanarra a sorra** vonatkozik. Ez az F5b első Dart-lépése (S2).

### D-F5b.3 — A logolás a meglévő `_handleRowEdit` úton megy

A telefon-oldalon **nem** kell új logolási kódút. Ma:

- `_handleRowMarkDone(bi, ri)` — csak `doneAt`-et bélyegez (F5a útja);
- `_handleRowEdit(bi, ri, weight, reps)` — beírja a súlyt/ismétlést **és** `doneAt ??= now`, majd `_recomputePrFlags` + (ha a sor még nem volt kész) `_syncRestEphemeralState` + `_rescheduleRestNotification` + `_autoSave`.

A `_handleRowEdit` pontosan az, amire az F5b-nek szüksége van — a rest-indítás, a PR-detektálás és a state-sync ingyen jön vele, ugyanúgy, ahogy az F5a a `_handleRowMarkDone`-tól kapta. **Szabály marad:** a watch-esemény soha nem másolja a rest/persist láncot, csak ezeket a meglévő hívásokat használja.

Vagyis a `WatchSetLogged` kezelése:

- `reps == null && weight == null` → `_handleRowMarkDone` (mai F5a-viselkedés, változatlan);
- egyébként → `_handleRowEdit(bi, ri, weight, reps)`.

### D-F5b.4 — Mértékegység: **mindig kg**, mert a telefon is azt csinálja

A `UserSettings` ismer `UnitSystem { metric, imperial }`-t, **de a workout-felület ma nem használja**: az `add_set_sheet.dart` fixen `suffixText: 'kg'`-ot ír, és sehol nincs átváltás a szettek súlyánál. A watch **nem lehet okosabb a telefonnál** (43-doc §2 alapelve), ezért az F5b is kg-ban dolgozik, konverzió nélkül — a design AW 10 „60 kg” felirata is ezt tükrözi.

Ha valamikor bevezetjük az imperial súlyokat, az **egyszerre** érinti a telefont és mindkét watchot; addig ez nem az F5b feladata. (Külön jegyezve, mert könnyű véletlenül „megjavítani” a watchon, és inkonzisztenciát okozni.)

### D-F5b.5 — Lépésköz és határok

| Mező | Lépés | Alsó/felső határ | Indoklás |
|---|---|---|---|
| Reps | **±1** | 1 … 99 | A telefon validátora is `> 0`-t követel (`add_set_sheet.dart`); 99 fölött nincs valós erőedzés-eset |
| Súly | **±2,5 kg** | 0 … 500 | A tipikus tárcsa-pár lépése; a telefon `>= 0`-t enged (testsúlyos = 0). A 2,5 az egyetlen lépésköz — a „finomabb 1,25” a korongon nem éri meg a plusz interakciót |

A crown/rotary **gyors** forgatása a platform saját gyorsulásával lép többet — nem építünk saját „fast mode”-ot.

### D-F5b.6 — A protokoll visszafelé kompatibilis; a telefon dönt, a watch javasol

A `logSet` üzenet `reps`/`weight` mezője **opcionális** (§4.1). Ez két dolgot ad:

- az F5a egy-tapos útja **bitre változatlan** marad (nem küld értéket → a telefon a mai módon logol);
- egy régebbi watch-build és egy újabb telefon-build (vagy fordítva) nem törik el egymáson.

**Fontos, hogy a küldött érték javaslat, nem parancs a sor kiválasztására**: a watch nem mondja meg, *melyik* sorba menjen — azt továbbra is kizárólag a telefon dönti el a saját aktuális állapotából (43-doc §5.2). Ha a user időközben a telefonon másik gyakorlatra lépett, az érték abba a sorba megy, amit a telefon *most* választ — ez a 43-doc §7.8 esete, továbbra sem hiba.

### D-F5b.7 — Az adjust-nézet nem logol magától; **3 s** tétlenség elveti

A design 0.5/0.6 pontja szerint:

- az érték állítása **önmagában semmit nem logol** — kell a „Log {n} reps” gomb;
- tétlenség (nincs forgatás, nincs tap) után a nézet magától bezáródik, **logolás nélkül**, vissza a log-lapra.

**Az időzítés 3 s, nem a designban írt 2 s** (§11/3): csuklón a 2 s kifejezetten rövid — egyetlen elnézés elveszi a félig beállított értéket. A hosszabb ablak ára nulla, mert a nézet magától semmit nem logol. Egy konstans, platformonként egy helyen — olcsón hangolható, ugyanúgy, ahogy az F5a ack-timeoutja.

### D-F5b.8 — Az F6a standalone defaultja örökli, de nem itt

A 44-doc **D-F6.8** ma fix `reps = 10`, `weight = 0` értékkel logol standalone módban, **kifejezetten azért, mert nincs stepper**, és a §4.1 protokoll már ma is visz `reps`-et szettenként. Amint az F5b stepper-komponense kész, a standalone log **ugyanazt a komponenst** használhatja (a 44-doc §11/1 is így fogalmaz: „ha az F5b feloldja, a standalone log automatikusan örökli”).

**De ez nem az F5b scope-ja** — az F5b-ben a stepper a *remote* (telefonos) úton működik; a standalone bekötése az F6b feladata. Amit az F5b-nek **tennie kell**: a stepper UI-t úgy írni, hogy ne kösse magát a `logSetState` remote állapotgépéhez (a kezdőérték és a „confirm” akció legyen paraméter), különben az F6b-nek újra kell írnia.

---

## 3. UX-viselkedés

### 3.1 Az adjust-nézet állapotai

```
LOG-LAP (F5a, LogSetState.ready)
   │
   │ long-press a korongon  (D-F5b.1 (b) javaslat)
   ▼
ADJUST (reps aktív, kezdőérték a telefonról — D-F5b.2)
   │  crown/rotary  → érték ±1 / ±2,5
   │  tap a "Weight"/"Reps" szegmensre → aktív mező vált
   │  tap "Log {n} reps" ──▶ logSet(reps, weight) ──▶ vissza a LOG-LAPra,
   │                          onnan a MEGLÉVŐ F5a állapotgép fut
   │                          (pending → ack → confirmed/failed)
   └─ 3 s tétlenség vagy vissza-gesztus ──▶ LOG-LAP, logolás nélkül
```

Két dolgot érdemes külön kiemelni:

- Az adjust **a tap előtt** él; a megerősítés után az egész visszakerül az F5a már megírt és letesztelt `pending/confirmed/failed` életciklusába (43-doc §3.2). **Nincs második állapotgép.**
- Az adjust-nézet **nem érhető el**, amíg egy korábbi tap `pending` — ugyanaz a `logSetState == .ready` kapu, ami ma a tapet őrzi.

### 3.2 Fázis-kapuzás

Változatlanul az F5a §3.3 szabályai: csak `ACTIVE` fázisban; pause és rest alatt is elérhető; `setsDone == setsTotal` nem tiltja. Az adjust ezen nem lazít és nem szigorít.

### 3.3 Amit a nézet mutat

- **Fejléc**: `tune` ikon + `log_adjust_title`, `LifeyColors.secondary` (barna) — a „mellékút” jelölése (0.1).
- **Szegmens-pár**: `log_adjust_reps` / `log_adjust_weight`, az aktív kitöltött háttérrel.
- **Nagy szám**: az aktív mező értéke, tabuláris számokkal, **egy `−` és egy `+` körgombbal a két oldalán** (utólagos döntés, lásd alább).
- **`−` / `+` gombok** (utólagos döntés, a crown/rotary **mellé**, nem helyette): a stepper eredetileg kizárólag koronával/rotaryval volt állítható, ami tapintással felfedezhetetlen maradt. A két gomb fixen a szám bal és jobb oldalán ül, tapanként **egy lépés**, ugyanazon a `stepLogAdjust(by:)` / `onLogAdjustStepped(steps)` úton, mint a korona — így a clamp, a tétlenség-timer újraindítása és a tick-haptika változatlanul jár hozzá. A gomb **kiszürkül** (nem tűnik el), ha az aktív mező a saját tartománya végén áll (`LogAdjustState.canDecrement/canIncrement`), így a sor nem rendeződik át egy határon. A szám a köztük maradó **teljes szélességet** megkapja, hogy a két találati felület sose mozduljon el a számjegyek számának változásától — cserébe ez az egy sor ~60%-ban belóg a képernyő-padding zónába (a tárcsa függőleges közepén, ahol a kerek kijelző a legszélesebb).
- **Caption**: a nagy szám **mértékegysége + a másik érték**, kis szedéssel. A design „12” fölé „reps · 60 kg”-ot ír (0.4), tehát a szerkezet aszimmetrikus: reps-módban `log_adjust_caption_reps` („reps · 60 kg”), súly-módban `log_adjust_caption_weight` („kg · 12 reps”) — ezért két kulcs, nem egy (§11/2).
- **Primary gomb**: `log_adjust_confirm` a **reps** értékével paraméterezve („Log 12 reps”) — a design szerint akkor is, ha épp a súlyt szerkeszti.

---

## 4. Protokoll

### 4.1 `logSet` bővítés (watch → telefon)

```json
{
  "type": "logSet",
  "sessionClientId": "…",
  "eventId": "<watch-generálta UUID>",
  "loggedAtEpochMs": 1234567890123,
  "reps": 12,
  "weight": 60.0
}
```

- A `reps` és a `weight` **opcionális** (D-F5b.6) — az F5a egy-tapos útja továbbra sem küldi őket.
- **Együtt járnak**: ha az egyik jelen van, a másik is legyen (a nézet mindkettőt megjeleníti és mindkettőnek van értéke a megerősítés pillanatában). A telefon-oldal védekezzen a félig kitöltött esetre: hiányzó `reps` → `_handleRowMarkDone` fallback, ne írjon be `null`-t.
- **`NSNull`-csapda (iOS)**: a `WCSession.sendMessage` property-list-kódolása nem tűri az `NSNull`-t — a kulcsokat **ki kell hagyni**, ha nincs értékük, nem `nil`-ként betenni. Ez a hiba már kétszer megvolt a projektben (40-doc §11.2 `restEndsAtEpochMs`, majd az F5a `rpe`-je), a `PhoneConnector.sendLogSet` jelenlegi kódja is ezt a mintát követi — tartsuk meg.

### 4.2 `WorkoutSessionState` bővítés (telefon → watch)

```
+ nextSetWeight: double?   // a következő watch-tap cél-sorának javasolt súlya
+ nextSetReps:   int?      // ua. ismétlés
```

- A meglévő `toJson()`-be is bekerül; a natív oldalak (`WatchBridge.swift` `sanitizedForPropertyList`, `WatchBridge.kt` `toDataMap()`) a `null`-t **már ma is kiszűrik**, tehát külön kezelés nem kell — de a watch-oldali dekódernek a „kulcs hiányzik” esetet ugyanúgy `null`-ként kell értenie.
- **Nem** kerül be a fázis-kapuzásba: ha nincs érték, az adjust a saját defaultjáról indul (D-F5b.2/4).
- A mező minden state-syncben frissül, tehát a watchon látott kezdőérték **legfeljebb egy sync-nyit** késik — ez elfogadható, mert a megerősítéskor küldött érték úgyis explicit, és a telefon azt írja be.

### 4.3 Ack

Változatlan: `logSetAck { eventId, accepted }` (43-doc §4.3). Az F5b nem ad új üzenettípust.

---

## 5. Lokalizációs kulcsok (HU/EN)

A canvas „F5/F6 string keys” táblája a mérvadó. Androidon `values/strings.xml` (HU, default) + `values-en/strings.xml`, iOS-en `Localizable.xcstrings`, **azonos kulcsnevekkel** (40-doc 8.2/3), pontosan az F5a S1 lépésének mintájára.

| Kulcs | EN | HU | Státusz |
|---|---|---|---|
| `log_adjust_title` | `Adjust` | `Módosítás` | design |
| `log_adjust_reps` | `Reps` | `Ismétlés` | design |
| `log_adjust_weight` | `Weight` | `Súly` | design |
| `log_adjust_confirm` | `Log %1$d reps` | `%1$d ismétlés naplózása` | design (paraméteres) |
| `log_adjust_caption_reps` | `reps · %1$s kg` | `ism. · %1$s kg` | **eldöntve (§11/2)** — a caption, amikor a **reps** az aktív mező |
| `log_adjust_caption_weight` | `kg · %1$d reps` | `kg · %1$d ism.` | **eldöntve (§11/2)** — a caption, amikor a **súly** az aktív |
| `log_adjust_open_a11y` | `Adjust reps and weight` | `Ismétlés és súly módosítása` | **eldöntve** — a long-press akció accessibility-címkéje |
| `log_adjust_decrement_a11y` | `Decrease` | `Csökkentés` | utólag — a `−` gomb accessibility-címkéje (§3.3) |
| `log_adjust_increment_a11y` | `Increase` | `Növelés` | utólag — a `+` gomb accessibility-címkéje (§3.3) |

> ⚠️ **String-paraméter platform-különbség** (a `log_adjust_caption_reps` érinti): a súly **előre formázott stringként** megy be, és a formátum-jelölő **platformonként más** — Androidon `%1$s`, iOS-en `%1$@`. A táblázat az Android-alakot mutatja. Ez nem új szabály: a meglévő `rest_hero_next_with_sets_format` és az F5a `log_set_context_format` is pontosan így van (iOS `%1$@`, Android `%1$s`). Az `%1$d` (int) viszont **mindkét platformon azonos**, tehát a `log_adjust_confirm` és a `log_adjust_caption_weight` sora betű szerint egyezik.

> A súly formázása: **egész, ha kerek** („60”), egy tizedes egyébként („62,5”) — a tizedesjel lokalizált. Ezt a formázást platformonként egy helyen kell megírni, ne a nézetben szétszórva.

---

## 6. Natív munka

### 6.1 watchOS (`mobile/ios/LifeyWatch/`)

- **`WorkoutManager.swift`**
  - Új publikált állapot az adjust-nézethez: `@Published private(set) var adjustState: LogAdjustState?` (`nil` = nincs nyitva), benne `reps: Int`, `weight: Double`, `field: .reps | .weight`.
  - `beginLogAdjust()` — csak `phase == .active && logSetState == .ready` esetén; a kezdőértéket a `nextSetReps`/`nextSetWeight`-ből veszi (a `applyStateUpdate` már eltárolja), különben D-F5b.2/4 default.
  - `stepAdjust(by:)`, `toggleAdjustField()`, `cancelLogAdjust()` + a **3 s**-os tétlenség-`Task` (D-F5b.7; a `scheduleLogSetSettle` mintájára, minden interakció újraindítja).
  - `confirmLogAdjust()` — a **meglévő** `logSet()`-et hívja, kiegészített payloaddal; az állapotgép onnantól változatlan.
  - `applyStateUpdate(...)` két új paramétere: `nextSetReps`, `nextSetWeight`.
- **`PhoneConnector.swift`** — `sendLogSet(sessionClientId:eventId:loggedAtEpochMs:reps:weight:)`; a `nil` mezőket **kihagyja** (§4.1). Az `applyState` két új mezőt olvas ki.
- **`Views/ActiveWorkoutView.swift`** — új `private struct AdjustPage` (vagy overlay a `LogPage` fölött), az AW 10 szerint; a `LogPage` korongjára `.onLongPressGesture` (D-F5b.1 (b)); az adjust nyitva állapotában a crown a **stepperre** kötve (`.digitalCrownRotation` egy külön, lokális bindinggel — a `TabView` lapozó bindingje ilyenkor nem kap fókuszt).

### 6.2 Wear OS (`mobile/android/wear/`)

- **`SessionStateHolder.kt`** — `logAdjustState: StateFlow<LogAdjustState?>` + `onAdjustOpened/onAdjustStepped/onAdjustFieldToggled/onAdjustCancelled`; a `SessionMetadata` két új mezője (`nextSetReps`, `nextSetWeight`); a `reset()` ezeket is nullázza.
- **`ExerciseService.kt`** — a **3 s**-os tétlenség-timer (D-F5b.7) **itt** fusson (a `logSetJob`/`restVibrationJob` mintájára), ne a Compose-képernyőn — konzisztensen az F5a S12 döntésével (a UI eldobása ne szakítsa meg). A stepper-tick haptika (§11/5) szintén ide tartozik.
- **`PhoneListenerService.kt`** — az `applyStateMessage` két új mezőt olvas.
- **`SummarySender.kt`** — `sendLogSet(...)` két új, opcionális paraméterrel; a `JSONObject.putOpt` már ma is kihagyja a `null`-t.
- **`ui/ActiveWorkoutScreen.kt`** — `AdjustOverlay` composable a W 09 szerint; a `LogCircle`-re `combinedClickable(onLongClick = …)`; nyitott adjustnál a rotary a stepperre kötve (`onRotaryScrollEvent` a lapozó `snapBehavior` helyett, amíg az overlay él).

---

## 7. Telefon-oldali (Dart) munka

1. **`watch_set_log_decision.dart`** — a sor-választás kiemelése tiszta függvénybe (`selectWatchSetLogTarget`), hogy a prefill és a logolás **ugyanazt** a sort lássa (D-F5b.2). A meglévő `decideWatchSetLog` erre épüljön rá, a guard/dedup logika változatlanul.
2. **`workout_session_notifier_service.dart`** — `WorkoutSessionState` + `nextSetWeight`/`nextSetReps` (+ `toJson`).
3. **`log_session_screen.dart`**
   - `_sessionState()` kiszámolja és beteszi a két új mezőt (a D-F5b.2 négylépcsős prioritás szerint);
   - `_handleWatchSetLogged` a `WatchSetLogged.reps`/`weight` megléte szerint választ `_handleRowEdit` és `_handleRowMarkDone` között (D-F5b.3);
   - a dedup/ack ág **változatlan**.
4. **`watch_workout_service.dart`** — `WatchSetLogged` két új, nullable mezővel (`reps`, `weight`); a dekóder a hiányzó kulcsot `null`-ként kezeli.

---

## 8. Hibautak és edge case-ek

| # | Eset | Viselkedés |
|---|---|---|
| 8.1 | Az adjust nyitva, közben a telefon state-syncet küld más `nextSet*` értékkel | A **már nyitott** nézet értékét **nem** írjuk felül (a user épp állítja) — a következő megnyitás veszi az újat |
| 8.2 | Az adjust nyitva, közben a telefonon a user logol egy szettet | 8.1 szerint az érték marad; a megerősítés a telefon *akkori* cél-sorába megy (D-F5b.6, 43-doc §7.8) — nem hiba |
| 8.3 | Az adjust nyitva, közben rest indul | Nem zavarja; a rest a szomszéd lapon fut tovább (43-doc §3.3) |
| 8.4 | Megerősítés, de a telefon nem elérhető | Ugyanaz, mint az F5a-ban: ack-timeout → `failed` (43-doc §7.1). Az adjust addigra bezárult |
| 8.5 | `nextSet*` nincs a state-ben (pl. üres, terv nélküli gyakorlat) | Default: reps 10, súly 0 — és a nézet ezt **nem** tünteti fel „módosításként”, mert nincs mihez képest (D-F5b.2/4) |
| 8.6 | A user 0-ra viszi a repset | A stepper alsó határa 1 (D-F5b.5) — 0-t nem lehet küldeni, egyezik a telefon validátorával |
| 8.7 | Régi watch-build + új telefon-build | A watch nem küld `reps`/`weight`-et → a telefon a mai F5a-úton logol (D-F5b.6) |
| 8.8 | Új watch-build + régi telefon-build | A telefon nem ismeri a mezőket, eldobja őket → a szett a sor meglévő értékeivel megy be. Nem ideális, de nem hibás — és a két oldal együtt szállítható |

---

## 9. Tesztelési terv

- **Dart unit**: `selectWatchSetLogTarget` (a kiemelt tiszta függvény) — a mai `decideWatchSetLog`-tesztek mintájára; a prefill-prioritás négy ága (D-F5b.2); `WatchSetLogged` dekódolás `reps`/`weight` nélkül és velük; `_handleRowEdit` vs `_handleRowMarkDone` elágazás.
- **iOS manuális** (szimulátorpár): long-press → adjust nyílik **és közben nem logol** (D-F5b.1 csapdája); crown lépteti; szegmens-váltás; „Log n reps” → a telefonon a **helyes sorba, helyes értékkel** kerül be; 3 s tétlenség elveti; adjust `pending` alatt nem nyílik.
- **Wear manuális** (emulátorpár): ugyanezek rotaryval (a stepper-tick haptikával, §11/5); plusz a Compose-képernyő eldobása nyitott adjust mellett (a 3 s timer a service-ben él → nem akad be).
- **Regresszió**: az F5a egy-tapos útja **változatlan** (nem küld értéket, ugyanaz a sor, ugyanaz az ack-lánc); a 3-lapos lapozás crownnal/rotaryval továbbra is működik **mindhárom** lapon.

---

## 10. Ütemezés és becslés

| Ütem | Tartalom | Becslés |
|---|---|---|
| F5b-design | **D-F5b.1 lezárása a designerrel** (reveal-gesztus) + a §5 három javasolt kulcsa | S |
| F5b.1 | Protokoll (§4) + Dart (§7) + tesztek | M |
| F5b.2 | watchOS adjust-nézet (§6.1) | M |
| F5b.3 | Wear adjust-nézet (§6.2) | M |
| F5b.4 | Kézi végpróbák mindkét platformon (§9) | S–M |

A két natív ág **párhuzamosítható**, a Dart-oldal és a protokoll közös előfeltétel — ugyanaz a szerkezet, ami az F5a-ban bevált.

---

## 11. Döntések (mind lezárva, 2026-07-26)

Nyitott kérdés nem maradt — a kódolás indítható.

1. **Reveal-gesztus (D-F5b.1) → long-press.** A crown-elnyelés (design-hű opció) azért esett ki, mert a log-lap az **alapértelmezett** lap: a crown ott a lapozás elsődleges eszköze, és azt egy másodlagos funkcióért feláldozni rosszabb csere, mint egy kevésbé felfedezhető gesztus. A felfedezhetőségi hátrányt a korongon lévő apró barna `tune` glyph ellensúlyozza (részletek a D-F5b.1 alatt), a tap/long-press ütközés kezelése pedig kötelező ellenőrzési pont az S7/S12-ben.

2. **Caption-kulcsok (§5) → két kulcs, nem egy.** Az egy összevont formátum azért nem jó, mert a caption **aszimmetrikus**: a nagy szám mértékegysége áll elöl, utána a *másik* érték („reps · 60 kg”, illetve súly-módban „kg · 12 reps”). Egy kulccsal ez csak úgy menne, hogy a kód rakja össze a szeparátort és a sorrendet — pont azt vennénk el a fordítótól, ami lokalizálandó. Ezért `log_adjust_caption_reps` + `log_adjust_caption_weight`. A súly **előre formázott stringként** (`%1$s`) megy be, mert a tizedesjel lokalizált (D-F5b.5 alatti formázási szabály).

3. **Auto-dismiss (D-F5b.7) → 3 s, nem 2.** Tudatos eltérés a design 0.6 pontjától: a 2 s csuklón kifejezetten rövid — egyetlen elnézés (a súlytárcsára, a partnerre) elveszi az épp beállított értéket, és a újranyitás után elölről kezdődik az állítás. A hosszabb ablak ára **nulla**, mert a nézet semmit nem logol magától (0.5): a rosszabb kimenetel az, hogy ott marad 1 s-mal tovább. Egy konstans, egy helyen platformonként — ha eszközön 3 s is soknak/kevésnek bizonyul, egysoros hangolás.

4. **Súly-szegmens 0 kg-nál → marad, nem rejtjük el.** A feltételes elrejtés két új állapotot szülne (mikor tűnik el, mi történik, ha a user épp azon áll, hogyan jön vissza), miközben a 0 kg **legitim érték**, nem hibaállapot — a telefon validátora is `>= 0`-t enged. A testsúlyos gyakorlat használója egyszerűen nem nyúl a súly-szegmenshez; ez olcsóbb, mint egy kivétel-ág.

5. **Stepper-haptika → platformonként eltérő, és ez így helyes.**
   - **watchOS**: a `.digitalCrownRotation(… isHapticFeedbackEnabled: true)` **maga adja** a detent-haptikát — sajátot **ne** tegyünk rá, dupla rezgés lenne.
   - **Wear**: a beépített detent-haptika a `rotaryScrollableBehavior`/snap úthoz tartozik, amit az adjust **nem** használ (saját érték-stepper) — itt tehát **kézzel kell** egy rövid tick-et adni lépésenként (`EFFECT_TICK`, vagy `HapticFeedbackType.TextHandleMove`).
   - Mindkét platformon a tick **élesen elkülönül** az F5a logolás-visszajelzésétől (`.success` / dupla pulzus, ill. `.failure` / hosszú pulzus) — a stepper „kattan”, a logolás „megerősít”.

---

## 12. Előfeltétel — **teljesült** (2026-07-26)

Ez a terv az F5a kézi végpróbái (43-doc §11 S9 és S14) után indítható; azok **lefutottak**, a fejlesztő eszközön visszaigazolta, hogy az egy-tapos flow működik. A két dolog, amit bemenetként vártunk tőlük:

- az **ack-timeout** valós latencia melletti helyessége → **az 5 s jónak bizonyult**, marad; az F5b ugyanezt a konstanst örökli (43-doc §10/2);
- a **lapozás érzete** a 3 lapon crownnal/rotaryval → működik, ezért **nem áldozzuk fel** a log-lapon: pontosan ez az érv a D-F5b.1 (a) opciója ellen és a (b) long-press mellett.

Egy dolog viszont **nyitva marad a jövőre**, és nem az F5b feladata: a 43-doc §10/1 auto-lapozás kérdése (rest indulásakor ugorjon-e a pager a rest-lapra). Az F5a-ban „nincs auto-lapozás” maradt, és eszközön ez rendben volt — ha az F5b után mégis zavaróvá válik (mert az adjust miatt többet időzünk a log-lapon), az továbbra is egy `animateScrollToPage`/`selectedPage = 1` sor.

---

## 13. Fejlesztési terv apró lépésekben (F5b)

Minden lépés önmagában fordul, tesztelhető, és nem töri a meglévő F5a-viselkedést. Az „Ellenőrzés” az, amit a lépés végén ténylegesen le kell futtatni/megnézni. Ugyanaz a szerkezet, ami az F5a-ban (43-doc §11) és az F6a-ban (44-doc §12) bevált.

### 13.0 Függőségi gráf és párhuzamosítás

```
S1 (kulcsok, közös)
  └─▶ S2 ─▶ S3        (Dart: cél-sor kiemelés + prefill, esemény + logolás-ág)
             │
             ├─▶ iOS-ág:     S4 ─▶ S5 ─▶ S6 ─▶ S7 ─▶ S8
             └─▶ Android-ág: S9 ─▶ S10 ─▶ S11 ─▶ S12 ─▶ S13
                                                        └─▶ S14 (közös zárás)
```

- **S1–S3 közös előfeltétel** (protokoll + Dart) — utána a két natív ág **teljesen párhuzamos**, nincs köztük közös fájl.
- Mindkét natív ág „telefon-híd → watch-adat → állapotgép → UI” sorrendű, hogy a hídvégek előbb legyenek készen, mint az őket használó felület.
- Ha egy platformon egyedül dolgozol: az S4–S8 és az S9–S13 sorrendje egymással felcserélhető.

---

### S1 — Kulcsok rögzítése *(közös, kód-viselkedés nélkül)* — **kész, 2026-07-26**

**Fájlok:** `mobile/android/wear/src/main/res/values/strings.xml`, `.../values-en/strings.xml`, `mobile/ios/LifeyWatch/Localizable.xcstrings`

**Teendő:**
- A §5 hét kulcsa mindhárom helyre, azonos kulcsnévvel: `log_adjust_title`, `log_adjust_reps`, `log_adjust_weight`, `log_adjust_confirm`, `log_adjust_caption_reps`, `log_adjust_caption_weight`, `log_adjust_open_a11y`.
- HU a `values/strings.xml`-be (default), EN a `values-en/`-be; iOS-en mindkét nyelv az xcstrings-be.
- **A `log_adjust_caption_reps` string-paramétere platformonként más**: Androidon `%1$s`, iOS-en `%1$@` (§5 figyelmeztetés). A többi paraméter `%1$d`, mindkét platformon azonos.

**Ellenőrzés:** mindkét app fordul; a kulcsnevek listája a két platformon karakterre egyezik.

---

### S2 — Dart: cél-sor kiemelése + prefill a state-be *(közös)* — **kész, 2026-07-26**

**Fájlok:** `mobile/lib/features/workouts/presentation/watch_set_log_decision.dart`, `mobile/lib/core/workout_session_notifier/workout_session_notifier_service.dart`, `mobile/lib/features/workouts/presentation/log_session_screen.dart` (+ tesztek)

**Teendő:**
- `selectWatchSetLogTarget(blocks, currentBlock) → WatchSetLogTarget?` tiszta függvény kiemelése; a meglévő `decideWatchSetLog` erre épüljön (guard/dedup változatlan) — D-F5b.2.
- `WorkoutSessionState` + `nextSetWeight` (`double?`), `nextSetReps` (`int?`) + `toJson`.
- `_sessionState()` kitölti a két mezőt a D-F5b.2 négylépcsős prioritása szerint.
- Teszt: a prioritás mind a négy ága; a `decideWatchSetLog` meglévő tesztjei zöldek maradnak.

**Ellenőrzés:** `flutter test` zöld. Viselkedésváltozás nincs (a watch még nem küld/olvas értéket).

---

### S3 — Dart: `logSet` értékek fogadása és logolása *(közös)* — **kész, 2026-07-26**

**Fájlok:** `mobile/lib/core/watch/watch_workout_service.dart`, `.../log_session_screen.dart` (+ tesztek)

**Teendő:**
- `WatchSetLogged` + `reps` (`int?`), `weight` (`double?`); a dekóder a hiányzó kulcsot `null`-ként kezeli.
- `_handleWatchSetLogged`: ha **mindkét** érték megvan → `_handleRowEdit(bi, ri, weight, reps)`, különben a mai `_handleRowMarkDone` (D-F5b.3); a félig kitöltött payload a `_handleRowMarkDone` ágra esik (§4.1).
- Teszt: érték nélkül a mai út fut; értékkel a sor súllyal/ismétléssel megy készre; félig kitöltött payload nem ír `null`-t.

**Ellenőrzés:** `flutter test` zöld; az app kézzel ugyanúgy viselkedik (a watch még nem küld értéket).

---

### S4 — iOS/telefon: `logSet` értékek átengedése — **kész, 2026-07-26**

**Fájl:** `mobile/ios/Runner/WatchBridge.swift`

**Teendő:** a `didReceiveMessage` `"logSet"` ága adja tovább a `reps`/`weight` mezőket az `eventSink`-nek (a meglévő `message["…"]` pass-through mintával). A state-irány (`nextSet*`) külön munkát **nem** igényel: a `state` szótár egészben megy át, a `sanitizedForPropertyList` a `null`-t már ma kiszűri.

**Ellenőrzés:** iOS-app fordul.

---

### S5 — watchOS: küldés + a prefill fogadása — **kész, 2026-07-26**

**Fájl:** `mobile/ios/LifeyWatch/PhoneConnector.swift`, `WorkoutManager.swift`

**Teendő:**
- `sendLogSet(sessionClientId:eventId:loggedAtEpochMs:reps:weight:)` — a `nil` mezőket **kihagyja** (`NSNull`-csapda, §4.1).
- `applyState` kiolvassa a `nextSetReps`/`nextSetWeight`-et; `applyStateUpdate(...)` két új paraméterrel eltárolja.

**Ellenőrzés:** fordul; a watch a state-syncből megkapja a két értéket (log/breakpoint).

---

### S6 — watchOS: `WorkoutManager` adjust-állapotgép — **kész, 2026-07-26**

**Fájl:** `mobile/ios/LifeyWatch/WorkoutManager.swift`

**Teendő:** a §6.1 szerint — `LogAdjustState` (`reps`, `weight`, `field`), `beginLogAdjust()` (kezdőérték D-F5b.2/4), `stepAdjust(by:)`, `toggleAdjustField()`, `cancelLogAdjust()`, `confirmLogAdjust()` (a meglévő `logSet()`-et hívja értékekkel), **3 s** tétlenség-`Task` minden interakcióra újraindítva, `reset()`-be a nullázás.

**Ellenőrzés:** fordul; unit-teszt-target nincs — a kézi kör az S8.

---

### S7 — watchOS: adjust-nézet + long-press reveal — **kész, 2026-07-26**

**Fájl:** `mobile/ios/LifeyWatch/Views/ActiveWorkoutView.swift`

**Teendő:** `AdjustPage`/overlay az AW 10 szerint (§3.3); a `LogPage` korongján long-press a reveal, **`ExclusiveGesture`-rel**, hogy a tap ne tüzeljen egyszerre (D-F5b.1 csapdája); apró barna `tune` glyph a korongon; `accessibilityLabel(log_adjust_open_a11y)`; nyitott adjustnál a crown a stepperre kötve.

**Ellenőrzés:** szimulátoron a long-press **nem logol**, csak nyit; a crown lépteti; a lapozás a másik két lapon változatlan.

---

### S8 — iOS: kézi végpróba — **kész, 2026-07-26** (fejlesztői eszközös visszaigazolás)

**Teendő:** a §9 iOS-listája.

**Ellenőrzés:** minden eset a §3/§8 szerint viselkedik.

---

### S9 — Android/telefon: `logSet` értékek átengedése — **kész, 2026-07-26**

**Fájl:** `mobile/android/app/src/main/kotlin/com/khunor/lifey/WatchBridge.kt`

**Teendő:** az `emitSetLogged` adja tovább a `reps`/`weight` mezőket (a JSON-ban hiányzó kulcs → `null`). A `nextSet*` a state-JSON-nal automatikusan átmegy.

**Ellenőrzés:** `:app:compileDebugKotlin` zöld.

---

### S10 — Wear: küldés + a prefill fogadása — **kész, 2026-07-26**

**Fájlok:** `.../SummarySender.kt`, `.../PhoneListenerService.kt`, `.../SessionStateHolder.kt`

**Teendő:** `sendLogSet(...)` két új, opcionális paraméterrel (`putOpt` kihagyja a `null`-t); az `applyStateMessage` kiolvassa a `nextSetReps`/`nextSetWeight`-et; `SessionMetadata` két új mezővel.

**Ellenőrzés:** `:wear:compileDebugKotlin` zöld.

---

### S11 — Wear: adjust-állapotgép + timer/haptika — **kész, 2026-07-26**

**Fájlok:** `.../SessionStateHolder.kt`, `.../ExerciseService.kt`

**Teendő:** `logAdjustState: StateFlow<LogAdjustState?>` + `onAdjustOpened/Stepped/FieldToggled/Cancelled`; a **3 s** tétlenség-timer és a **lépésenkénti tick-haptika** (§11/5) az `ExerciseService`-ben fusson (a `logSetJob` mintájára), ne a Compose-képernyőn; `reset()` nullázza.

**Ellenőrzés:** fordul; a flow-átmenetek logból követhetők.

---

### S12 — Wear: adjust-overlay + long-press — **kész, 2026-07-26**

**Fájl:** `.../ui/ActiveWorkoutScreen.kt`

**Teendő:** `AdjustOverlay` a W 09 szerint; a `LogCircle`-ön `combinedClickable(onClick =, onLongClick =)`; `tune` glyph; `contentDescription = log_adjust_open_a11y`; nyitott overlaynél a rotary a stepperre kötve (a lapozó `snapBehavior` helyett).

**Ellenőrzés:** kerek emulátoron a long-press nem logol; a rotary lépteti; a 3 lapos lapozás változatlan.

---

### S13 — Android: kézi végpróba — **kész, 2026-07-26** (fejlesztői eszközös visszaigazolás)

**Teendő:** a §9 Wear-listája.

**Ellenőrzés:** minden eset a §3/§8 szerint viselkedik.

---

### S14 — Közös zárás — **kész, 2026-07-26**

**Teendő:**
- ✅ **Regressziós kör mindkét platformon.** `flutter test`: **386 zöld / 1 bukó** — a bukó a `stat_chart_data_test.dart` dátumfüggő DST-artefaktja, ami `origin/main`-nel bitre azonos és a watch-munkától független (44-doc §11/7). `flutter analyze` tiszta; `:app:compileDebugKotlin` + `:wear:compileDebugKotlin` → `BUILD SUCCESSFUL`; teljes `LifeyWatch` target `-warnings-as-errors` típusellenőrzés → exit 0; a `Runner` target típusellenőrzésében nincs más hiba, mint a már ismert, F5b-független `WorkoutActivityAttributes` csoport.
- ✅ **Az F5a egy-tapos útja bitre változatlan**, kódból igazolva: iOS-en a `handleTap()` a paraméter nélküli `workoutManager.logSet()`-et hívja, Wearen a `SummarySender.sendLogSet(...)` hívás `reps`/`weight` nélkül megy — mindkettőn a defaultok `null`-ok, tehát a payload ugyanaz, mint F5a-ban, és a telefon a `_handleRowMarkDone` ágra esik.
- ✅ **Lokalizációs paritás**: az F5a+F5b 14 kulcsa karakterre egyezik a három fájlban (iOS/HU/EN), az `.xcstrings` érvényes JSON.
- ✅ **S13 (Android élő kézi végpróba) lefutott** — fejlesztői visszaigazolás.
- ✅ `docs/watch/40-watch-app-plan.md` állapottáblázatának F5b-sora „✅ Kész”-re mindkét platformon.
- ✅ **Menet közben javított F6a-hiba** (44-doc §11/8): a log-korong standalone módban a telefon elérhetőségére volt kapuzva mindkét platformon, ami az F6a lokális logolását tette volna használhatatlanná telefon nélkül. Bevezetve egy `requiresPhone` (= `!isStandalone`) feltétel; a telefon-mesterelt út viselkedése változatlan.
- Ha az F6b-t elkezdjük: a stepper-komponens átvétele a standalone logba (D-F5b.8, 44-doc §13/T5).
