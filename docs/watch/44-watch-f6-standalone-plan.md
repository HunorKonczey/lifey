# 44 – F6 terv: Standalone edzésindítás a watchról

Státusz: **F6a KÉSZ, 2026-07-26** — mindkét platform kódja lezárva (S1–S17), a kézi végpróbák (S12 iOS, S18 Android) is lefutottak, a §11/8 F6a-hiba (log-kontroll standalone-ban a telefon elérhetőségére kapuzva) javítva, és a §11/6 platform-aszimmetria (Wear-oldali standalone recovery hiánya) pótolva. Élő teszt a recovery-re (folyamat kilövése + újranyitás) még nem futott.

**Lépések:** S1–S5 közös Dart-előfeltétel; S6 iOS/telefon fogadás+ack; S7 watchOS pending-tár+payload-modell; S8 `PhoneConnector` küldés/retry/ack; S9 `WorkoutManager` standalone módja + D-F6.2 guardok; S10 launcher+picker UI; S11 aktív képernyő deltái + `SummaryView` 4. csempéje és élő sync-chipje; S12 teljes kézi végpróba fizikai eszközön (**user visszaigazolta**); S13 Android/telefon fogadás + puffer + ack; S14 Wear `StandaloneSessionStore` + `SummarySender` küldés/retry + `PhoneListenerService` ack-fogadás; S15 `SessionStateHolder` standalone állapotgép (`SUMMARY` fázis, `StandaloneSummary`) + `ExerciseService` start/end akciók; S16 Wear launcher (`IdleScreen` → `CompactChip`) + `StandalonePickerScreen` + `MainActivity` bekötés; S17 `ActiveWorkoutScreen` standalone deltái + új `SummaryScreen`. A teljes F6a láncolat (start → log → end → summary) **UI-ból végigmegy mindkét platformon**.

**Regressziós ellenőrzés (2026-07-26):** `flutter analyze` tiszta; `:app:compileDebugKotlin` + `:wear:compileDebugKotlin` → `BUILD SUCCESSFUL`; a teljes `LifeyWatch` target (az új `StandaloneSessionPayload/Store`, `StandalonePickerView` fájlokkal együtt) típusellenőrzése hibátlan. `flutter test`: **337 zöld, 1 bukó** — a bukó (`stat_chart_data_test.dart` › „StatsRange.all has no cutoff”) **nem F6a-eredetű**: a statisztika-modul kódja és tesztje bitre azonos az `origin/main`-nel, a hiba dátumfüggő DST-artefakt (a teszt `_day(1000)`-je `Duration(days:)`-szel számol, ami óraátállítást átlépve 23:00-t ad éjfél helyett). Külön jegyezve a §11/7-ben.
Az F6 design-frame-ek megvannak a canvasban (`docs/watch/design/Lifey Watch Design.dc.html`: **AW 12–15**, **W 11–14**, „F6 — standalone start from the watch (v2)” szekció + az „F5/F6 string keys” tábla). Ez a doc a designhoz szinkronizálva van; a §12 a lépésenkénti fejlesztési terv, ami alapján iOS és Android párhuzamosan vihető.

**Előfeltétel — F5a: TELJESÜLT (2026-07-26).** Az F6a a log-kontrollt lokális módban hasznosítja újra, ezért platformonként az adott platform F5a-ága az előfeltétele volt. Az F5a azóta **mindkét platformon teljesen elkészült és eszközön is le lett ellenőrizve** (43-as doc §11 S1–S15, státusz: „F5a KÉSZ, 2026-07-26”) — beleértve a korábban itt hiányzóként jelölt watchOS log-lapot (S8–S9) és a teljes Android/Wear ágat (S10–S14). Az `ActiveWorkoutView`/`ActiveWorkoutScreen` ma **3 lapos** (log ↔ metrika ↔ controls) mindkét platformon.

> A korábbi verzióban itt egy „az F5a nem teljes” táblázat állt, ami mára elavult — az F5a S8–S9 és S10–S14 sorai is elkészültek, és a 43-as doc státusz-fejléce is frissült.

Kapcsolódó dokumentumok:
- [40-watch-app-plan.md](40-watch-app-plan.md) — a fő terv; F6 egy sorban: „Edzés indítása óráról telefon nélkül; a watch lokálisan gyűjt, és kapcsolódáskor a telefon sessiont kreál belőle — külön tervezést igényel (ütközés a resume-prompt logikával)” (§7).
- [41-watch-design-prompt.md](41-watch-design-prompt.md) — §5: az eredeti F6 koncepció-specifikáció (4 frame).
- [42-watch-design-implementation-plan.md](42-watch-design-implementation-plan.md) — D4: design→dev vázlat; ez a doc a részletes kibontása.
- [43-watch-f5-set-logging-plan.md](43-watch-f5-set-logging-plan.md) — a log-set kontroll és a `logSet`-protokoll, amit az F6 lokális módban újrahasznosít; a §12-ben leírt crown/rotary-ütközés az F6-ra is érvényes.
- [45-watch-f5-f6-design-prompt.md](45-watch-f5-f6-design-prompt.md) — az F5/F6 canvas-bővítés design-promptja (**teljesítve**).
- [49-watch-f6b-template-sync-plan.md](49-watch-f6b-template-sync-plan.md) — az F6b (edzésterv-szinkron) részletes, alapos terve; a lenti §13 T1–T6 vázlatát váltja fel/pontosítja.

---

## 0. Design-szinkron napló (2026-07-25)

Mi változott a designhoz képest ebben a docban:

| # | Terület | Korábbi doc-állapot | Design (canvas) | Mostani doc-állapot |
|---|---|---|---|---|
| 0.1 | Idle → launcher | „a design-fázisnak kell eldöntenie” (§7/1) | **AW 12 / W 11**: kompaktabb badge + wordmark, alatta `primary`-fill pill, majd halvány második sor | §3.1 lezárva |
| 0.2 | Picker az ütemezésben | csak F6b | **AW 13 / W 12** kirajzolja az „üres/elavult cache” variánst is (csak „Quick strength” + hint) | **A picker váza az F6a-ba kerül**, a template-sorok F6b-ben töltik fel (§1, §3.3) |
| 0.3 | Standalone-jelző | „javaslat: diszkrét” (§7/3) | **`phonelink_off` glyph a fejlécben**, muted `777264`, se chip, se szöveg; a11y-kulcs `standalone_badge` | §3.4 lezárva |
| 0.4 | Rest-hossz | 90 s javaslat, nyitott kérdés | **1:30 default**, a rest-hero „of 1:30” sora a meglévő `rest_of_format` kulccsal | §3.5 lezárva, a §11 nyitott kérdés törölve |
| 0.5 | Sync-státusz a summaryn | nyitott kérdés (§7/4) | **`sync_pending` chip → `sync_done`** (`tertiaryContainer` + `6E9A6A`), a `sync_queue_count` sor csak 1-nél több pending sessionnél; a szinkron egyébként néma | §3.6 lezárva |
| 0.6 | Aktív képernyő szett-sora | nem szerepelt | **`active_sets_free_format`**: „Set 4 · 32 reps total” — a design **reps-et is mutat** | §3.4 + **D-F6.8**: a reps forrása fix default **10** (a backend a `reps <= 0` szetteket eldobja) |
| 0.7 | String-kulcsok | csak `standalone_session_title` volt nevesítve | 12 kulcs a design táblájában | új **§5** (teljes HU/EN tábla) |
| 0.8 | Session címe | „Watch workout” (`standalone_session_title`) | ugyanaz a kulcs, de **„Quick strength” / „Gyors erőedzés”** | D-F6.3 frissítve (a design a mérvadó) |
| 0.9 | Summary-képernyő | „STANDALONE_SUMMARY sync-státusszal” | **AW 15 / W 14**: 4 csempe (idő, **szettek**, avg bpm, kcal) + sync-chip | §3.6; **iOS-en ma 3 csempe van** (nincs „sets”), **a Wearen pedig egyáltalán nincs summary-képernyő** → D-F6.7 |
| 0.10 | Wear átviteli út | message + lokális pending-tár, DataItem csak tartalék (§4.1) | a W 12/W 14 jegyzete `DataClient`-et ír | **Konfliktus — a mérnöki döntés marad** (D-F6.9); a vizuális állapotok változatlanul élnek |

Ami a designból **nem** került be és miért: semmi. Az F6c (menet közbeni kézátadás) továbbra sincs megtervezve, és a design sem rajzolta meg — a scope változatlan.

---

## 1. Cél és scope

**Cél:** a user **telefon nélkül** (otthon hagyta, lemerült, edzőteremben szekrényben) elindíthasson egy strength-edzést az óráról; a watch lokálisan mér és logol; amikor a telefon legközelebb elérhető, a session **magától megjelenik az appban**, mintha ott rögzítették volna.

### Ütemezett al-fázisok

| Al-fázis | Tartalom |
|---|---|
| **F6a** | Launcher + **picker-váz** (csak „Quick strength” sor + `standalone_empty_hint`), egyetlen „szabad” strength-session lokális szett-számlálással, lokális rest, pending-tár, szinkron-protokoll, telefon-oldali feldolgozó, standalone summary |
| **F6b** | Template-szinkron: a telefon legutóbbi terveinek pusholása, a picker feltöltése, indítás tervből, gyakorlat-léptetés, `exerciseIndex` a payloadban |
| **F6c** *(nem tervezett, csak nevesített)* | Menet közbeni kézátadás (a telefon élőben átveszi a standalone sessiont) — lásd D-F6.1; v2-ben tudatosan nincs |

A picker az F6a-ban azért kerül be vázként, mert a design az „üres cache” állapotot is megrajzolta (AW 13 kis variáns): ha az F6a a launcher-tapot közvetlenül a sessionindításra kötné, az F6b-ben a teljes belépési flow-t át kellene huzalozni. A váz egy egyelemű lista + hint — kicsi, és F6b-ben csak adatot kap.

### Tudatosan NEM cél

- Élő tükrözés a telefonra standalone mód alatt (D-F6.1).
- Standalone **telepítés** (watch app telefon-app nélkül, Play/App Store-ból) — D-F6.4.
- Súly rögzítése az órán (a standalone szettek `weight = 0`-val jönnek létre, a user a telefonon pontosít — D-F6.8).
- Edzésterv-**böngészés** a watchon a szinkronizált néhány friss terven túl.

---

## 2. Alapdöntések (D-F6.1 … D-F6.9)

### D-F6.1 — Standalone alatt a watch a mester, a session végéig

A v1-architektúra (telefon = mester, 40-es doc D4) standalone módban megfordul: **amíg a session él, a watch a kizárólagos igazságforrás**; a telefon a kész, lezárt sessiont kapja meg utólag. Ha a telefon a session **közben** válik elérhetővé, akkor sem történik élő kézátadás — a watch végigviszi, és a végén szinkronizál. Ez radikálisan leegyszerűsíti az állapotgépet (nincs menet közbeni master-csere, nincs kétirányú live-merge), és a 40-es doc kézbesítési-garancia mintáira (queue-olt átvitel) épülhet. A kézátadás F6c-ként nevesítve marad, terv nélkül.

### D-F6.2 — Ütközés a telefon-oldali sessionnel és a resume-prompttal

- **Telefon indít, miközben az órán standalone session fut**: a watch a **meglévő `startRejected` úton** utasítja el (40-es doc §5.3 / B12 — „az órán már fut egy edzés”); a telefon-session ettől még zavartalanul fut watch-mérés nélkül. A mai kód ezt **nem** teszi meg magától, két konkrét helyen kell kiegészíteni:
  - **iOS**: `WorkoutManager.start(configuration:)` első sora `guard phase == .idle` — standalone alatt tehát némán visszatér, a telefon semmilyen visszajelzést nem kap. A `PhoneConnector.applyContext`-ben (ahonnan az új `sessionClientId` érkezik) kell egy ág: ha standalone session fut és a bejövő `sessionClientId` más, `sendStartRejected(sessionClientId:)`.
  - **Wear**: a `PhoneListenerService` a `/start` üzenetre feltétel nélkül elindítja az `ExerciseService`-t; standalone alatt ez a saját, futó exercise-t bántaná. Guard kell: ha standalone aktív → `SummarySender.sendStartRejected(...)`, és az `ExerciseService`-hez hozzá sem nyúlunk.
- **A telefon `state`/`end` üzenetei standalone alatt**: a `SessionStateHolder.onStateSynced` (Wear) és a `WorkoutManager.applyStateUpdate` (iOS) ma minden bejövő state-et alkalmaz — standalone módban ezeket **el kell dobni**, különben a telefon egy párhuzamos sessionjének gyakorlatneve/rest-je átírja a lokális képernyőt. Ugyanígy a `desiredPhase: "ended"` fallback és az `end` parancs sem zárhatja le a standalone sessiont.
- **Standalone session fut az órán ÉS a telefonon is fut egy session**: két független session — a szinkronkor a standalone külön sessionként jön létre. Nem dedupolunk „ugyanaz az edzés lehetett” alapon (a user explicit két helyen indított — az ő döntése; törölni bármelyiket egy tap).
- **Resume-prompt**: a beérkező standalone session **már lezárva** érkezik (`finishedAt` kitöltve), ezért a `WorkoutResumePrompt._findActiveSession` (`s.inProgress`) detektora **definíció szerint nem** akadhat rá — a feldolgozó (§6) közvetlenül lezárt sessiont ír a repositoryba. Tesztben explicit ellenőrizendő (§9), mert a 40-es doc épp ezt az ütközést jelölte fő kockázatnak.

### D-F6.3 — A standalone session adatmodellje: a meglévő session-séma, új mező nélkül

A szinkronkor a telefon a **meglévő** `WorkoutSession`-t hozza létre a meglévő outbox/sync úton (`WorkoutSessionRepository.create`). A séma ellen ellenőrizve (`lib/core/local_db/tables/workout_session_tables.dart`) ez konkrétan a következőket jelenti:

- `clientId` = a watch által generált `standaloneSessionId` (UUID). Ez adja az **idempotenciát**. **Kódváltozás kell**: a `create()` ma maga generálja a clientId-t (`newClientId()`), ezért fel kell venni egy opcionális `String? clientId` paramétert (más hívó viselkedése nem változik).
- `templateName` = a lokalizált `standalone_session_title` („Gyors erőedzés” / „Quick strength”) — ez adja a session-kártya címét; a lokalizálás a **telefon** locale-ja szerint történik a feldolgozóban, nem a watchon.
- **A szettek nem lehetnek gyakorlat nélküliek**: az `exercise_sets` tábla `exerciseClientId`-je `references(Exercises, #clientId)`, a `reps`/`weight` pedig **nem nullable**. A nyitott kérdés ezzel eldőlt: az F6a szettjei egy **generikus gyakorlat** alá kerülnek, aminek a neve **a `standalone_session_title` szövegével azonos** („Gyors erőedzés” / „Quick strength”) — a feldolgozó név szerint keresi, és ha nincs, létrehozza az `ExerciseRepository.create`-tel, így az outboxon ki is megy a szerverre. Egyetlen sor a user gyakorlatlistájában, amit ő maga átnevezhet (átnevezés után a következő standalone session újat hoz létre a default néven — elfogadott, nem követjük id-vel).
- `reps` = `standaloneDefaultReps` (10) a payloadból (D-F6.8), `weight = 0`.
- Gazdagítás (`activeCalories`, `averageHeartRate`, `healthWorkoutId`) ugyanazokba a mezőkbe, mint a watch-summary ma — a ⌚-badge (B15) ingyen működik.
- **Backend-változás: nincs** — a session a normál outbox-úton szinkronizál a szerverre.

### D-F6.4 — A Wear `standalone` manifest-flag marad `false`

A `com.google.android.wearable.standalone: false` (40-es doc §5.1) a **terjesztésről** szól (telepíthető-e a watch app telefon-app nélkül), nem a futásról — a lokális indításhoz nem kell átállítani. Amíg az app fiók-alapú és a telefon-app a belépési pont, a `true` csak támogatási terhet hozna. Ha később app-store-os standalone-terjesztés kell, az külön döntés.

### D-F6.5 — HealthKit / Health Connect írás standalone módban

- **iOS**: változatlan — a watch `HKWorkoutSession`-je a végén `HKWorkout`-ot ment (`finishAndSendSummary` mai kódja), a `healthWorkoutId` a szinkron-payloadban utazik.
- **Android**: a meglévő 7.5.7-minta — **a telefon írja a HC-rekordot** a beérkező payloadból (`HealthService.writeStrengthWorkoutAndGetId`, pontosan úgy, ahogy a `WorkoutResumePrompt._onWatchEvent` teszi ma a summary-nál), a watch csak mér. A standalone-payload `healthWorkoutId`-ja Androidon null-ként érkezik, és a telefon-oldali feldolgozó tölti ki.

### D-F6.6 — Idő-forrás

Standalone módban nincs telefon-`startedAt` — a session ideje **a watch órája** szerint rögzül (`startedAtEpochMs`/`endedAtEpochMs` a payloadban). A watch és a telefon wall-clockja eltérhet; ezt elfogadjuk (a 40-es doc 8.1 idő-eltérés sora ugyanígy döntött), a payload nem hord külön korrekciót. A watchon **futás közben** a mai monoton megoldás marad (`ProcessInfo.systemUptime` / `SystemClock.elapsedRealtime()`), a payload csak lezáráskor konvertál wall-clockra.

### D-F6.7 — A Wearen új SUMMARY fázis kell (iOS-en csak egy csempe)

A design AW 15 / W 14 mindkét platformon summary-t rajzol. Mai kód:

- **iOS**: van `WorkoutPhase.summary` + `SummaryView` — de **3 csempe** (idő, avg bpm, kcal). A designban **4** van: a „sets” csempe standalone módban lokálisan ismert, tehát csak ott jelenik meg (phone-mastered módban a szettszám a telefoné marad — nem hozunk be érte új protokollmezőt).
- **Wear**: a `SessionPhase` ma `IDLE | ACTIVE | ERROR`, az `ExerciseService.endExercise()` a végén `SessionStateHolder.reset()`-tel egyenesen IDLE-be esik — **nincs summary-képernyő**. Az F6a-hoz fel kell venni a `SUMMARY` fázist + `SummaryScreen`-t (auto-dismiss ~6 s, az iOS `summaryAutoDismissSeconds` értékével). Ez az F6a Wear-ágának legnagyobb, nem nyilvánvaló tétele — a 42-es doc D1.3/A5 „a Wear ENDING/SUMMARY pár nincs megtervezve” megjegyzése itt évül el.
- ENDING fázis standalone-ban egyik platformon **sincs** — nincs kire várni, az End megerősítés után egyből zárás + summary.

### D-F6.8 — Reps a standalone szettekben: fix default 10 (nem 0) — **eldöntve 2026-07-25, eszközön megerősítve 2026-07-26**

A design „Set 4 · 32 reps total” sora reps-et feltételez, a backend pedig **eldobja** a `reps <= 0` szetteket (`WorkoutSessionServiceImpl.replaceSets` / `isComplete`: `reps != null && reps > 0 && weight != null && weight >= 0`). A `reps = 0` tehát lokálisan látszó, de a szerver-körút után eltűnő szetteket eredményezne — ez kizárt út.

**A döntés:** minden lokálisan logolt szett **fix `standaloneDefaultReps = 10`** ismétléssel és `weight = 0` súllyal jön létre; a user a telefonon pontosít. Az alternatíva (a watch lokális crown/rotary stepperrel kéri be a reps-et, az F5b design AW 10 / W 09 kontrollja) azért nem az F6a útja, mert a lapozó crown/rotary-val ütközik (43-as doc §12, feloldatlan).

A konstans **egy helyen** éljen platformonként (`WorkoutManager.swift`, ill. `SessionStateHolder.kt`), hogy az F5b bekötésekor egyetlen hívási pont cserélődjön. A protokoll **szettenként visz `reps` mezőt már most** (§4.1), hogy a stepper bevezetése ne bontson protokollt. A `weight = 0` mellékhatása: a generikus gyakorlat PR-baseline-ja 0 kg-os szetteket is lát — mivel a baseline maximumot néz (`PrBaseline.fromSets`), ez nem torzít, és csak erre az egy gyakorlatra vonatkozik.

**Eszközös visszaigazolás (2026-07-26):** a 10-es default a gyakorlatban jónak bizonyult, marad változtatás nélkül.

### D-F6.9 — Wear átvitel: üzenet + lokális pending-tár, nem DataItem

A design W 12 / W 14 jegyzete `DataClient`-alapú szinkront ír. A 40-es doc 7.5.2 tanulsága és a mai kód (`WatchBridge.kt`, `PhoneListenerService`) szerint viszont a DataItem-sync két párosított eszköz Play-services példánya között megbízhatatlan, ezért **minden élő út message-alapú**, a DataItem csak best-effort tartalék. Ezt az F6 sem fordítja meg: a pending sessionök a watch **saját lokális tárában** várnak, és message-ben mennek ki, ack-ig újrapróbálva. A design vizuális állapotai (pending/synced chip) változatlanul érvényesek — csak a transzport más.

---

## 3. Watch-oldali munka

### 3.1 Fázisok és belépési pont

A meglévő fázismodell így bővül (mindkét platformon):

```
IDLE ──„Start workout” tap──▶ PICKER ──„Quick strength”──▶ STANDALONE_ACTIVE
STANDALONE_ACTIVE ──End (effort-selector)──▶ STANDALONE_SUMMARY (sync-státusszal) ──▶ IDLE
```

- Az **Idle képernyő launcherré válik** (AW 12 / W 11): a meglévő brand-moment kompaktabban (badge 0.22 → ~0.19 fraction nagyságrend), alatta `primary`-fill pill (`standalone_start_button`), majd a mai `idle_subtitle` helyére a halványabb `standalone_start_caption` („vagy indítsd a telefonon”). Az `idle_title` („Lifey”) marad.
- A **PICKER** (AW 13 / W 12) az F6a-ban egyelemű: „Quick strength” kártya (`bolt` ikon + `standalone_quick_start` + `standalone_quick_caption`), alatta `standalone_empty_hint`. Platform: watchOS lista-carousel, Wear `ScalingLazyColumn` (a design kimondja, hogy itt a görgetés rendben van, szemben az aktív képernyővel).
- `STANDALONE_ACTIVE` a meglévő ACTIVE-képernyő **változata**, nem új képernyő (§3.4).
- `ENDING` fázis nincs; az End a meglévő effort-selectort hozza fel (a `rpe` a lokális sessionre kerül), majd egyből zárás + `STANDALONE_SUMMARY`.

### 3.2 Lokális perzisztencia és folytatás

- **Pending-session tár**: a lezárt, még nem szinkronizált sessionök listája — watchOS: JSON-fájl az app konténerében (`Application Support`); Wear: `SharedPreferences` (a telefon-oldali `WatchSummaryBuffer` mintájára, ugyanaz a JSONArray-forma). Egy elem = a teljes szinkron-payload (§4.1). Sikeres ack után törlődik.
- **Élő session túlélése**: process-halál/reboot ellen — watchOS: `HKHealthStore.recoverActiveWorkoutSession` induláskor + a session-meta (startedAt, szett-log) folyamatos kiírása a lokális tárba; Wear: a Health Services exercise túléli a service-t, induláskor `ExerciseClient` állapot-lekérdezés + ugyanaz a meta-kiírás. Ha az app úgy indul, hogy élő standalone exercise van, `STANDALONE_ACTIVE`-ba tér vissza.
- Több pending session felhalmozódhat (a user kétszer edz, mire a telefon előkerül) — a tár lista, a szinkron sorban küldi őket, a summary `sync_queue_count` sora ezt mutatja, ha > 1.

### 3.3 Template-cache (F6b)

A telefon által pusholt template-lista (§4.3) lokális cache-be kerül (ugyanaz a tár, külön kulcs); a PICKER ebből épül. Ha a cache üres, a picker az F6a-vázra esik vissza („Quick strength” + `standalone_empty_hint`) — az F6a-flow mindig működik. A cache korát a design nem jeleníti meg, tehát nem is kell.

### 3.4 Standalone aktív képernyő

Két delta a mai F4-pagerhez képest (AW 14 / W 13):

1. **Diszkrét mód-jelző**: a fejléc „STRENGTH” felirata mellé `phonelink_off` glyph, muted `777264` színnel — se chip, se szöveg, se hibaszín (ez normál üzemmód, nem hiba). A11y-címke: `standalone_badge` („Csak óra”).
2. **A log-kontroll lokális módban**: ugyanaz az F5 log-lap, de `logSet()` a lokális ágon fut — **nincs PENDING/ack, a tap azonnal CONFIRMED** (a 43-as doc §2.1 miatt ez iOS-en már egy `if`, lásd `WorkoutManager.logSet()` F6-jelölt elágazáspontját). A szettszámláló lokálisan nő, nincs `setsTotal` (nincs terv), ezért a gyakorlat-kártya a `active_sets_free_format` sort mutatja.

A rest-hero, a GO-flash és a pager-pöttyök változatlanok.

### 3.5 Lokális rest

Standalone módban **nincs telefon-vezérelt rest**: a watch a szett-logoláskor saját, fix hosszú visszaszámlálót indít (**90 s = 1:30**, a design „of 1:30” sorával, a meglévő `rest_of_format` kulccsal). A meglévő rest-hero/GO/haptika kód újrahasznosul, csak a deadline forrása lokális (iOS: `restDeadlineUptime` beállítása közvetlenül; Wear: `SessionStateHolder` új lokális belépési pontja — az `ExerciseService.scheduleRestVibration` figyelője változatlanul működik). F6b-ben a template `restSeconds` mezője felülírhatja a defaultot.

### 3.6 Standalone summary + sync-státusz

AW 15 / W 14: „Workout saved” + **4 csempe** (idő, szettek, avg bpm, kcal) + státusz-chip:

- pending: muted `22241B` chip, `cloud_upload` ikon, `sync_pending` („Szinkronizálás a telefonra”),
- synced: `1A2E1A` chip, `6E9A6A` check, `sync_done` („Telefonra szinkronizálva”) — akkor, ha az ack a summary ideje alatt megérkezik,
- 1-nél több várakozó session esetén egy halvány sor: `sync_queue_count`.

A szinkron egyébként **néma**: se toast, se értesítés, se a watchon, se a telefonon.

---

## 4. Protokoll

### 4.1 `standaloneSessionCompleted` (watch → telefon, queue-olt)

```json
{
  "type": "standaloneSessionCompleted",
  "standaloneSessionId": "<UUID — a leendő session clientId-ja>",
  "templateId": null,
  "startedAtEpochMs": 0,
  "endedAtEpochMs": 0,
  "rpe": null,
  "sets": [ { "loggedAtEpochMs": 0, "reps": 10, "exerciseIndex": null } ],
  "activeCalories": 0.0,
  "averageHeartRate": 0.0,
  "healthWorkoutId": "<iOS: HKWorkout uuid; Android: null>"
}
```

- **Átvitel**: iOS — `transferUserInfo` (pontosan a `PhoneConnector.sendSummary` mintája: sorban áll, kézbesít, amint a telefon elérhető, akár napokkal később); Android — `MessageClient`-küldés (`SummarySender` mintájára, új path: `/lifey/watch/standaloneSessionCompleted`) a lokális pending-tárból, minden trigger-ponton újrapróbálva, amíg ack nem jön (D-F6.9).
- **Retry-triggerek Wearen**: app-indulás (`MainActivity`), a standalone session lezárása, és a `PhoneListenerService` `onCapabilityChanged` hívása (a telefon-node megjelenése).
- **Ack**: a telefon `standaloneSessionAck { standaloneSessionId }` üzenetet küld sikeres (vagy idempotensen dedup-olt) feldolgozás után; a watch ekkor törli a pending-elemet. Ack nélkül a payload a tárban marad és újraküldődik.
- `rpe`: a lokális effort-selector eredménye (null, ha a user átugrotta) — a meglévő `EffortSelectorView`/`EffortSelectorScreen` újrahasznosul.
- `exerciseIndex`: F6a-ban null; F6b-ben a szinkronizált template gyakorlatlistájának indexe (a watch csak indexet küld, a nevek/azonosítók feloldása a telefoné — a payload kicsi marad).

### 4.2 `standaloneSessionAck` (telefon → watch)

```json
{ "type": "standaloneSessionAck", "standaloneSessionId": "…" }
```

iOS: `WCSession.sendMessage` a `Runner/WatchBridge.swift`-ből (a `logSetAck` mintájára), fogadás a `PhoneConnector.session(_:didReceiveMessage:)` `command`-switchében. Android: `WatchBridge.kt` `sendMessage(...)` új parancscal, fogadás a Wear `PhoneListenerService.onMessageReceived`-ben.

Az ack **nem** kritikus üzenet: elvesztése csak újraküldést és telefon-oldali dedupot jelent (§6/3).

### 4.3 `templateSync` (telefon → watch, F6b)

```json
{
  "type": "templateSync",
  "syncedAtEpochMs": 0,
  "templates": [
    { "templateId": "…", "title": "Push day",
      "exercises": [ { "name": "Bench Press", "targetSets": 4, "restSeconds": 90 } ] }
  ]
}
```

- Küldés: app-indításkor és terv-mentés/-módosítás után, a legutóbbi legfeljebb ~5 terv. iOS: `updateApplicationContext` külön kulcs alatt (a state-sync mellett) — a rendszer a legfrissebbet kézbesíti; Android: message-alapú push (a teljes payload az üzenetben) + DataItem best-effort.
- Ez az **első telefon→watch adatirány a session-state-en kívül** — a Dart-oldalon új `WatchWorkoutService`-metódust igényel (§6/4), de a natív csatornák meglévők.
- Kapuzás: a meglévő `watchWorkoutEnabled` settings-kapcsoló.

---

## 5. Lokalizációs kulcsok (HU/EN)

A design „F5/F6 string keys” táblája a mérvadó. Androidon `mobile/android/wear/src/main/res/values/strings.xml` (HU, default) + `values-en/strings.xml`, iOS-en `mobile/ios/LifeyWatch/Localizable.xcstrings`, **azonos kulcsnevekkel** (40-es doc 8.2/3).

| Kulcs | EN | HU | Hol | Státusz |
|---|---|---|---|---|
| `standalone_start_button` | `Start workout` | `Edzés indítása` | AW 12 / W 11 | design |
| `standalone_start_caption` | `or start on your phone` | `vagy indítsd a telefonon` | AW 12 / W 11 | design |
| `standalone_picker_title` | `Start` | `Indítás` | AW 13 / W 12 | design |
| `standalone_quick_start` | `Quick strength` | `Gyors erőedzés` | AW 13 / W 12 | design |
| `standalone_quick_caption` | `No plan needed` | `Terv nélkül is megy` | AW 13 / W 12 | design |
| `standalone_empty_hint` | `Plans sync from your phone` | `A tervek a telefonról szinkronizálódnak` | AW 13 / W 12 | design |
| `standalone_plan_exercises` | `%1$d exercises` | `%1$d gyakorlat` | AW 13 / W 12 | design (F6b) |
| `standalone_badge` | `Watch only` | `Csak óra` | AW 14 / W 13, a glyph a11y-címkéje | design |
| `active_sets_free_format` | `Set %1$d · %2$d reps total` | `%1$d. szett · összesen %2$d ismétlés` | AW 14 / W 13 | design |
| `rest_of_format` | `of %1$s` | `/ %1$s` | rest-hero | F4-ből örökölt |
| `sync_pending` | `Will sync to phone` | `Szinkronizálás a telefonra` | AW 15 / W 14 | design |
| `sync_done` | `Synced to phone` | `Telefonra szinkronizálva` | AW 15 / W 14 | design |
| `sync_queue_count` | `%1$d sessions waiting to sync` | `%1$d edzés vár szinkronizálásra` | AW 15 / W 14 | design |
| `standalone_session_title` | `Quick strength` | `Gyors erőedzés` | **telefon-oldali** session-cím | design |
| `summary_sets_label` | `sets` | `szett` | AW 15 / W 14 negyedik csempe | **javaslat** — a design kirajzolja, de a kulcslistából hiányzik |
| `standalone_start_button_a11y` | `Start a workout on the watch` | `Edzés indítása az órán` | launcher-gomb | **javaslat** |

A `standalone_session_title` az egyetlen kulcs, ami a **telefon** erőforrásaiba is kell (a session-cím a telefon locale-jában készül, §6/3) — a watch-oldali `standalone_quick_start` szövegével azonos.

Az `idle_subtitle` kulcs a launcher bevezetése után feleslegessé válik a watchon; ne töröljük az F6a-ban (a phone-mastered idle-t az F5-ös regresszió még használhatja), csak ne hivatkozzunk rá.

---

## 6. Telefon-oldali munka (Dart + natív híd)

1. **Natív fogadók**
   - **iOS** — `mobile/ios/Runner/WatchBridge.swift`: a `session(_:didReceiveUserInfo:)` ma mindent summary-ként relézik. A userInfo-t típus szerint kell szétválasztani (`userInfo["type"] == "standaloneSessionCompleted"` → `eventSink?(["type": "standaloneSession", "payload": …])`, egyébként a mai summary-ág). Plusz új MethodChannel-metódus: `ackStandaloneSession`.
   - **Android** — `WatchBridge.kt` új message-path ága + egy **manifest-deklarált** listener a `PhoneWatchSummaryListenerService` mintájára (vagy annak kiterjesztése), ami a payloadot a `WatchSummaryBuffer`-hez hasonló pufferbe teszi, ha a Flutter engine nem fut. Ez itt, a summary-val ellentétben, **alapkövetelmény**: a telefon jellemzően zsebben/táskában kerül elő, nem futó appal.
2. **`watch_workout_service.dart`**: új `WatchStandaloneSession` esemény-osztály (`fromJson`-nal, a `WatchWorkoutSummary` mintájára) + `ackStandaloneSession(String standaloneSessionId)` + `syncTemplates(...)` (F6b).
3. **Feldolgozó** — a `WorkoutResumePrompt._onWatchEvent` ikertestvére, de a mérete miatt **külön, `BuildContext`-mentes osztályba** (`lib/features/workouts/application/standalone_session_processor.dart`), hogy unit-tesztelhető legyen:
   - idempotencia-guard: ha már létezik session `clientId == standaloneSessionId`, csak ack;
   - generikus gyakorlat feloldása (név szerinti keresés, hiány esetén `ExerciseRepository.create`);
   - `WorkoutSessionRepository.create(clientId: …, startedAt: …, finishedAt: …, templateName: <lokalizált cím>, sets: [...], rpe: …, activeCalories: …, averageHeartRate: …, healthWorkoutId: …)` — a `clientId` paraméter új (D-F6.3);
   - Android-ág: HC-írás a `HealthService.writeStrengthWorkoutAndGetId`-vel, a kapott id a `healthWorkoutId`-be;
   - ack küldése a natív hídon át — **minden ágon**, a dedupolt eseten is.
4. **Template-push hívási pontjai** (F6b): app-indulás + terv-mentés/-módosítás után; kapuzás a `watchWorkoutEnabled` kapcsolóval.
5. **UI**: a session a listában a meglévő ⌚-badge-dzsel jelenik meg (B15, design „C · Session card” frame) — nincs új UI-elem.

---

## 7. Engedélyek és korlátok

- **watchOS**: a HealthKit-engedélyt eddig is a watch kérte első használatkor — standalone-nál ez az egyetlen kérési pont (nincs telefon-onboarding előtte). A `healthDenied` képernyő (B10) változatlanul kezeli a megtagadást, csak most az indítási flow-ból is elérhető.
- **Wear OS**: `BODY_SENSORS` / `ACTIVITY_RECOGNITION` / `android.permission.health.READ_HEART_RATE` runtime-kérések — a `MainActivity.requestSensorPermissionsIfNeeded()` ma az `onCreate`-ben fut, tehát a launcher-tap előtt már lezajlik. Új kérési pont nem kell; a picker → start átmenet előtt viszont **ellenőrizni** kell (megtagadás esetén az `ExerciseService` amúgy is kcal-only módban indul, ez elfogadott degradáció).
- **Akku/kijelző**: semmi új az F4-hez képest — ugyanaz az exercise-session fut, csak a trigger más.

---

## 8. Amit a design lezárt (a korábbi §7 helyett)

| Korábbi nyitott design-kérdés | Design válasza |
|---|---|
| Idle → launcher kompozíció | AW 12 / W 11: kompaktabb brand-moment + `primary`-fill pill + halvány caption |
| Picker stílusa, „Quick strength” kiemelése, cache-kor jelzése | AW 13 / W 12: kiemelt (világosabb `22241B`) quick-kártya `bolt` ikonnal, alatta max. 5 terv címmel + gyakorlatszámmal; **cache-kor nem jelenik meg** |
| Standalone-jelző hangsúlya | Diszkrét `phonelink_off` glyph, muted szín, chip és copy nélkül |
| Sync-státusz a summaryn + pending-lista láthatósága | `sync_pending` → `sync_done` chip; a queue csak egy halvány `sync_queue_count` sorként látszik, 1-nél több elemnél |

---

## 9. Tesztelési terv

- **Dart unit**: standalone-feldolgozó — idempotencia (dupla kézbesítés → egy session, két ack), a session **lezártan** jön létre (a resume-prompt `inProgress`-sweepje nem akad rá), generikus gyakorlat létrehozása csak egyszer, Android-ági HC-írás + `healthWorkoutId`-kitöltés, `reps == 10` minden létrehozott szetten (a backend-drop szabály miatt), az `rpe` átvezetése (kitöltve és skip-elve is), payload-dekódolás (`WatchStandaloneSession.fromJson`), F6b: template-push serializálás.
- **iOS manuális** (szimulátorpár): standalone start → lokális szettek + rest → end (effort) → summary sync-chip → telefon elérhetővé válik → session megjelenik az appban ⌚-badge-dzsel; telefon-app kilőve a szinkron alatt → következő indításkor feldolgozódik; watch-app kilövése aktív standalone session alatt → recovery; telefon közben indít edzést → `startRejected` + a standalone session zavartalan; telefon `state`/`end` üzenete standalone alatt → figyelmen kívül marad.
- **Wear manuális** (emulátorpár): ugyanezek + több pending session felhalmozása és sorban szinkronizálása; `standaloneSessionAck` elvesztése → újraküldés → dedup; a telefon `/start` üzenete standalone alatt → `startRejected`, a futó exercise sértetlen; új SUMMARY képernyő auto-dismissel.
- **Regresszió**: a phone-mastered flow (F0–F5) bitre azonos; a resume-prompt sweep viselkedése változatlan telefon-oldali árva sessionökre; a picker/launcher nem jelenik meg, amíg phone-mastered session fut.

---

## 10. Ütemezés és becslés

| Ütem | Tartalom | Becslés | Előfeltétel |
|---|---|---|---|
| F6-design | AW 12–15 / W 11–14 + string-kulcsok | M | **kész** |
| F6a | §12 lépései: launcher + picker-váz, lokális rögzítés/rest/pending-tár, Wear SUMMARY fázis, szinkron-protokoll + telefon-oldali feldolgozó, teszt | L | platformonként az adott F5a-ág (iOS: S8; Android: S10–S14) |
| F6b | §13: template-szinkron + picker-feltöltés + gyakorlat-léptetés | M | F6a |

---

## 11. Döntések és nyitott kérdések

**Eldöntve 2026-07-25 (a fejlesztés ezekkel indul):**

1. **Default reps: 10** (`standaloneDefaultReps`), `weight = 0` — D-F6.8. A lokális stepper F5b/F6b terület.
2. **A generikus gyakorlat neve** a `standalone_session_title` szövegével azonos („Gyors erőedzés” / „Quick strength”) — D-F6.3.
3. **A szinkron a telefonon is néma**: nincs snackbar/notification a beérkező standalone sessionről; a session-listában a ⌚-badge az egyetlen jelzés (§6/5).
4. **Az effort-selector standalone-ban is fut** (skip-elhető): a meglévő `EffortSelectorView` / `EffortSelectorScreen` újrahasznosítva, az `rpe` a payloadon utazik (§4.1) és a `create(rpe:)`-be kerül.

**Nyitott (F6b-ig nem blokkol):**

5. **Template-lista mérete/frissítése** (§4.3): elég-e az 5 legutóbbi terv és a két push-pont? A Data Layer üzenet-limit ~100 KB — bőven belefér, de a serializáláskor mérjük meg.
6. **Wear-oldali standalone recovery** (S15, 2026-07-26 felfedezve) — **PÓTOLVA, 2026-07-26.**
   *A hiány:* az iOS-ágon az S9 explicit `recoverStandaloneSessionIfNeeded()`-t épített (`HKHealthStore.recoverActiveWorkoutSession` + a mentett aktív-snapshot visszaolvasása), amit a `LifeyWatchApp` indulásakor hív. A Wear-oldalon ez nem volt implementálva: a `StandaloneSessionStore.loadActive(context)` létezett, de senki nem hívta — az `ExerciseService.saveStandaloneActiveSnapshot()`-tal írt recovery-snapshotot semmi nem olvasta vissza folyamathalál után.
   *A pótlás:* Health Services `ExerciseClient.getCurrentExerciseInfoAsync()` — a szabványos Health Services minta pontosan erre az esetre ("az app folyamata meghalt, fut-e még a *saját* exercise-em") — `ExerciseTrackedStatus.OWNED_EXERCISE_IN_PROGRESS`-t ad vissza, ha igen. Az új `ExerciseService.recoverIfNeeded(context)` companion suspend fun ezt ellenőrzi (csak akkor, ha a `SessionStateHolder` friss/üres **és** van mentett aktív snapshot), és ha mindhárom feltétel teljesül, egy új `ACTION_RECOVER_STANDALONE` intenttel elindítja a service-t. A service-példányon belüli `recoverStandaloneExercise()` **nem hívja újra a `startExerciseAsync`-et** (az exercise már fut Health Services szinten) — csak `setUpdateCallback`-kel újra csatlakozik az élő frissítésekhez, és a mentett JSON-ból (`parseStandaloneSets` az új dekóder, a `parseStandaloneTemplate` mintájára) visszaállítja a `SessionStateHolder`-t egy új `onStandaloneRecovered(...)` metóduson keresztül (iOS `recoverStandaloneSessionIfNeeded()`-jének megfelelője).
   A trigger `MainActivity.onCreate()`-ben ül, a meglévő `flushPending`/`sendAdoptionRequestIfNeeded` újrapróbálkozások mellett — mindhárom "az app friss indulásakor pótoljuk, ami a halott folyamat alatt kimaradt" mintát követi.
   *Ellenőrzés:* `:wear:compileDebugKotlin` + `:app:compileDebugKotlin` → `BUILD SUCCESSFUL`. Élő teszt (folyamat kilövése standalone session közben, majd az app újranyitása) továbbra sem futott le — ehhez fizikai eszköz vagy emulátor kell, ugyanúgy, ahogy az S12/S18 többi esete is a fejlesztő kézi tesztjére támaszkodott.

7. **Nem F6a-hiba, de itt jegyezve** (2026-07-26): a `test/features/statistics/application/stat_chart_data_test.dart` › „StatsRange.all has no cutoff” **dátumfüggően bukik**, és bitre azonos az `origin/main`-nel — a watch-munkához semmi köze. Ok: a teszt `_day(offset)` helpere `DateTime(y,m,d).subtract(Duration(days: offset))`-et használ, ami **abszolút 24 órás** egységekkel számol, így egy óraátállítást átlépve 23:00-ra csúszik éjfél helyett (mai dátummal az `_day(1000)` 2023-10-31-re esik, közvetlenül az őszi átállítás utánra). A javítás a teszt-helperben van (naptári nap-léptetés `Duration` helyett), nem a produkciós kódban — külön, F6-tól független feladat.
8. **F6a-hiba — a log-kontroll standalone-ban a telefon elérhetőségére volt kapuzva, mindkét platformon** — **JAVÍTVA, 2026-07-26.**
   *A hiba:* a log-korong `canTap`/ghosted/„telefon nem érhető el” feltételei az F5a-ból öröklődtek mindkét UI-ba (`Views/ActiveWorkoutView.swift` és `ui/ActiveWorkoutScreen.kt`), és nem vették figyelembe a standalone módot. Egy valódi standalone edzésen (telefon nincs hatótávon) az `isPhoneReachable` / `hasConnectedNode` hamis, tehát a „+1 szett” korong **letiltva és ghosted** lett volna, „A telefon nem érhető el” felirattal — vagyis az F6a fő funkciója, a lokális szett-logolás, használhatatlan. A user által elvégzett S12 kézi teszt ezt vélhetően azért nem fogta meg, mert a telefon a közelben volt.
   *A javítás:* mindkét platformon bevezetve egy `requiresPhone` (= `!isStandalone`) származtatott érték, és a három feltétel erre épül. Standalone módban a korong mindig aktív, és a „telefon nem érhető el” felirat **nem jelenik meg** — a fejléc `phonelink_off` standalone-jelvénye már jelzi a helyzetet, a felirat ott hibaüzenetnek látszana egy szándékosan telefon nélküli edzés közben. A telefon-mesterelt út viselkedése bitre változatlan (ott `requiresPhone` igaz).
   *Ellenőrzés:* `flutter test` 386 zöld / 1 bukó (a §11/7 DST-artefakt), `flutter analyze` tiszta, `:app:` + `:wear:compileDebugKotlin` és a teljes `LifeyWatch` target `-warnings-as-errors` típusellenőrzése zöld. Élő standalone teszt (telefon nélkül) továbbra is ajánlott az S18 körében.

*(A korábbi „fix rest-hossz”, „Drift-séma és gyakorlat nélküli szettek”, valamint a §7 négy design-kérdése a design-szinkronnal zárult le — lásd §0, D-F6.3, §8.)*

---

## 12. Fejlesztési terv apró lépésekben (F6a)

Minden lépés önmagában fordul, tesztelhető, és nem töri a meglévő F0–F5-viselkedést. Az „Ellenőrzés” az, amit a lépés végén ténylegesen le kell futtatni/megnézni.

### 12.0 Függőségi gráf és párhuzamosítás

```
S1 (kulcsok + protokoll-konstansok, közös)
  └─▶ S2 ─▶ S3 ─▶ S4 ─▶ S5   (Dart: esemény, ack, repository+gyakorlat, feldolgozó)
                        │
                        ├─▶ iOS-ág:     S6 ─▶ S7 ─▶ S8 ─▶ S9 ─▶ S10 ─▶ S11 ─▶ S12
                        └─▶ Android-ág: S13 ─▶ S14 ─▶ S15 ─▶ S16 ─▶ S17 ─▶ S18
                                                                            └─▶ S19 (közös zárás)
```

- **S1–S5 közös előfeltétel** (Dart + protokoll-szerződés) — utána az iOS- és az Android-ág **teljesen párhuzamosan** vihető, nincs köztük közös fájl.
- Mindkét ág „telefon-oldal → tár/transzport → állapotgép → UI” sorrendű, hogy a hídvégek előbb legyenek készen, mint az őket használó felület.
- Ha egy platformon egyedül dolgozol: az S6–S12 és az S13–S18 sorrendje egymással felcserélhető.
- **Platform-előfeltétel**: az adott ág előtt annak az F5a-ága fusson le (iOS: 43-as doc S8; Android: S10–S14), mert a standalone log-kontroll ugyanaz a lap, csak lokális módban.

---

### S1 — Protokoll-szerződés + string-kulcsok rögzítése *(közös, kód-viselkedés nélkül)* — **kész, 2026-07-26**

**Fájlok:** `mobile/android/wear/src/main/res/values/strings.xml`, `.../values-en/strings.xml`, `mobile/ios/LifeyWatch/Localizable.xcstrings`, `mobile/lib/l10n/app_hu.arb` + `app_en.arb` (a `standaloneSessionTitle` telefon-oldali párja — camelCase, a Dart ARB-konvenció szerint; a `app_localizations*.dart` generált, nem szerkeszthető, `flutter gen-l10n`-nel frissült)

**Teendő:**
- A §5 tábla összes kulcsa mindhárom watch-erőforrásba, azonos kulcsnévvel; a `standaloneSessionTitle` a **telefon** lokalizációjába is.
- Formátum-argumentumok kötötten: `active_sets_free_format` `%1$d` = szett sorszám, `%2$d` = összes ismétlés; `standalone_plan_exercises` `%d` (iOS)/`%1$d` (Wear) = gyakorlatszám; `sync_queue_count` ugyanígy = várakozó sessionök száma.
- Message-path/parancsnév konstansok: **nem kaptak külön konstans-fájlt** ebben a lépésben — a §4.1–4.3 payload-nevei (`standaloneSessionCompleted`, `standaloneSessionAck`, `templateSync`) már a doc maga a forrás; egy hívó nélküli Kotlin/Swift konstans holt kód lenne, ezért az S6/S13-tól kezdve a tényleges hídkód mellett jönnek létre.

**Ellenőrzés (elvégezve):**
- `python3 -c "json.load(...)"` mindhárom JSON-forrásra (2 ARB + xcstrings) zöld.
- `./gradlew :wear:processDebugResources` zöld (a Wear-modul erőforrásai fordulnak).
- `plutil -lint` nem használható ezen a gépen sima JSON-ra (triviális JSON-on is elhasal) — ez környezeti korlát, nem a fájl hibája; a `json.load` a mérvadó ellenőrzés.
- A 14 új F6-kulcs (`standalone_*`, `active_sets_free_format`, `summary_sets_label`, `sync_*`) karakterre egyezik a Wear HU/EN és az iOS xcstrings között (szkriptelt diff); a köztük lévő eltérés csak a **meglévő**, platform-specifikus képernyőkből ered (pl. `health_denied_*` csak iOS-en, `error_already_running_*` csak Wearen), nem az F6-tól.
- `flutter analyze lib/l10n`: nincs hiba.

---

### S2 — Dart: `WatchStandaloneSession` esemény *(közös)* — **kész, 2026-07-26**

**Fájlok:** `mobile/lib/core/watch/watch_workout_service.dart`, `mobile/test/core/watch/watch_workout_service_test.dart`

**Teendő:**
- Új osztályok: `WatchStandaloneSet { loggedAtEpochMs, reps, exerciseIndex }` és `WatchStandaloneSession { standaloneSessionId, templateId, startedAtEpochMs, endedAtEpochMs, rpe, sets, activeCalories, averageHeartRate, healthWorkoutId }` + `fromJson` (a `WatchWorkoutSummary` mintájára, doc-comment erre a docra hivatkozva).
- `_decodeEvent`: `case 'standaloneSession'` (a natív oldal `payload` kulcs alatt küldi, mint a summary-nál).
- Az `events` getter doc-commentjének felsorolása bővül.
- Teszt: fake EventChannel-lel érkező payload helyesen dekódolódik (üres `sets`, hiányzó opcionális mezők is), ismeretlen típus továbbra is stringként jön vissza.

**Ellenőrzés (elvégezve):** `flutter test test/core/watch/` — 17/17 zöld (2 új teszt: teljes payload két szettel, illetve üres `sets` + minden opcionális mező hiányzik). `flutter analyze lib/core/watch test/core/watch` — nincs hiba. Viselkedésváltozás nincs (senki sem emitál még ilyet).

---

### S3 — Dart: `ackStandaloneSession` MethodChannel-hívás *(közös)* — **kész, 2026-07-26**

**Fájlok:** ugyanaz, mint S2.

**Teendő:**
- `Future<void> ackStandaloneSession(String standaloneSessionId)` → `invokeMethod('ackStandaloneSession', {...})`, a meglévő `isAvailable`-guard + néma try/catch mintával. Nincs `accepted: false` ág (a §4.2 protokoll sem hordoz ilyet) — a watch a saját pending-tárából retry-z, a telefon csak sikeres feldolgozás után hívja ezt.
- Teszt: `isAvailable: false` → nincs hívás (a meglévő „no-ops when unavailable” teszthez adva); egyébként pontosan egy hívás a várt argumentummal.

**Ellenőrzés (elvégezve):** `flutter test test/core/watch/` — 18/18 zöld. `flutter analyze lib/core/watch test/core/watch` — nincs hiba.

---

### S4 — Dart: repository-kiegészítések (idempotens `clientId` + generikus gyakorlat) *(közös)* — **kész, 2026-07-26**

**Fájlok:** `mobile/lib/features/workouts/data/workout_session_repository.dart`, `.../exercise_repository.dart` (+ `.../application/exercise_controller.dart` érintetlen maradt, csak a `create` visszatérési típusa változott alatta) (+ tesztek)

**Teendő:**
- `WorkoutSessionRepository.create(...)`: új opcionális `String? clientId` paraméter — `clientId ?? newClientId()` egy `resolvedClientId` lokálisba (a paraméter és a régi lokális név ütközését elkerülendő). Más hívó nem változik (csak additív).
- `Future<bool> existsByClientId(String clientId)` — egyszerű `getSingleOrNull` lekérdezés.
- `ExerciseRepository.create` mostantól visszaadja az új `clientId`-t (`Future<void>` → `Future<String>`); az egyetlen hívó (`ExerciseController.addExercise`, deklarált `Future<void>` visszatérésű) változtatás nélkül fordul — Dart engedi egy `Future<String>`-et `Future<void>` pozícióban visszaadni.
- Új `Future<String> getOrCreateByName(String name)`: pontos névegyezés `getSingleOrNull`-lal, találat esetén annak `clientId`-ja, egyébként `create(name)`. Nem szűr a pending-delete-lel blokkolt sorokra (a `watchAll()` UI-szűrése) — ez a docban sincs elvárva, és ez a helper csak az egyetlen auto-generált standalone-gyakorlatot szolgálja ki.
- Teszt: kétszer hívva ugyanazzal a névvel egy gyakorlat keletkezik (`exercise_repository_test.dart`, 4 teszt); `create(clientId: 'x')` után `existsByClientId('x')` igaz, és az outbox-bejegyzés is ezzel az id-vel megy ki (`workout_session_repository_standalone_id_test.dart`, 4 teszt — ez az első dedikált teszt-fájl ehhez a viselkedéshez).

**Ellenőrzés (elvégezve):** `flutter test test/features/workouts/data/` — 20/20 zöld (a 8 új teszt + a 12 meglévő session-teszt változatlanul fut). `flutter analyze` a teljes projekten — nincs hiba (az `ExerciseController` és minden más hívó fordul a bővített visszatérési típussal).

---

### S5 — Dart: `StandaloneSessionProcessor` + bekötés *(közös)* — **kész, 2026-07-26**

**Fájlok:** új `mobile/lib/features/workouts/application/standalone_session_processor.dart`, `mobile/lib/features/workouts/application/workout_resume_prompt.dart` (+ új teszt)

**Teendő:**
- `BuildContext`-mentes osztály, konstruktor-injektált repository/watch-service függőségekkel: `Future<void> process(WatchStandaloneSession event, {required LanguagePreference language})` a §6/3 lépéssorral (idempotencia → gyakorlat → session-create → HC-írás Androidon → ack).
  - A `language` paraméterként érkezik, nem `Ref`-ből olvasva belül — így az osztály `HealthService` helyett egy szűkített `WriteHealthWorkout` függvénytípust kap (`writeStrengthWorkoutAndGetId` aláírása), pontosan a `WidgetSnapshotWriter` mintája szerint (`lib/core/home_screen_widget/widget_snapshot_writer.dart`): a valódi `HealthService.writeStrengthWorkoutAndGetId` `Platform.isAndroid`-ellenőrzést tartalmaz, ami a teszt-hoston (nem Android) mindig `null`-t adna vissza a mockolt `Health`-plugintól függetlenül — a szűkített függvénytípus ezt a tesztelhetetlenséget kerüli ki.
  - A lokalizált cím feloldása a `widget_snapshot_writer.dart`/`step_goal_notifier.dart` mintáját követi: `LanguagePreference.hungarian → Locale('hu')`, minden más (`system` is) → `Locale('en')`, majd `lookupAppLocalizations(locale).standaloneSessionTitle`.
- Bekötés: `WorkoutResumePrompt._onWatchEvent`-be egy `if (event is WatchStandaloneSession) { … return; }` ág (a summary-ág változatlan) — a `language`-t a `settingsControllerProvider`-ből olvassa ki.
- Tesztek (`standalone_session_processor_test.dart`, 9 teszt, valódi in-memory Drift DB-vel): teljes create-lánc (session lezártan, generikus gyakorlat neve, szettek reps/weight-je), HU cím-feloldás, idempotencia (második hívás nem duplikál, csak ack), két különböző session ugyanazt a gyakorlatot használja újra, HC-írás hívása/kihagyása a `healthWorkoutId` jelenléte szerint, üres `sets`, `rpe`/`averageHeartRate` átvitele. Az ack-ot a valódi `WatchWorkoutService.ackStandaloneSession`-ön keresztül, mock `MethodChannel`-lel ellenőrizve (nem csak a hívás tényét, az argumentumokat is).

**Ellenőrzés (elvégezve):** `flutter test test/features/workouts/application/standalone_session_processor_test.dart` — 9/9 zöld. `flutter analyze` a teljes projekten — nincs hiba. `flutter test` a teljes projekten — 336/337 zöld; az 1 bukás (`test/features/statistics/application/stat_chart_data_test.dart: StatsRange.all has no cutoff`) egy ettől a munkától **független, előzetesen is fennálló** időzóna-érzékeny teszt (a teszt-host EEST/UTC+3 időzónája miatt egy 2023-10-29-i dátum-bucketelés eltér) — a `statistics` feature-t ez a munka nem érintette. Kézzel indítva az app viselkedése változatlan (a natív oldal még nem küld/fogad ilyen eseményt).

> Innentől az iOS- és az Android-ág párhuzamos.

---

### S6 — iOS/telefon: fogadás + ack — **kész, 2026-07-26**

**Fájl:** `mobile/ios/Runner/WatchBridge.swift`

**Teendő:**
- `session(_:didReceiveUserInfo:)`: típus szerinti szétválasztás — `type == "standaloneSessionCompleted"` → `eventSink?(["type": "standaloneSession", "payload": userInfo])`; minden más marad a mai summary-ág (a mai payload nem hord `type`-ot, tehát a hiánya = summary).
- `handle(_:result:)`: új `case "ackStandaloneSession"` → `ackStandaloneSession(_:result:)`, ami `WCSession.default.sendMessage(["command": "standaloneSessionAck", "standaloneSessionId": …])`-t küld (a `ackSetLogged` mintája: `isReachable`-guard, nincs `accepted` mező, mert a §4.2 protokoll sem hordoz ilyet — lásd D-F6.9 kapcsán a Dart-oldali `ackStandaloneSession` doc-commentjét).

**Ellenőrzés (elvégezve):** `flutter build ios --no-codesign --device-id=<csatlakoztatott eszköz>` — sikeres (`✓ Built build/ios/iphoneos/Runner.app`); a szimulátoros build ezen a gépen a watch-companion-app miatt megkövetelt `--device-id` mellett is csak a fizikai eszközt listázta célnak (környezeti korlát, nem a kódé) — a fizikai eszköz felé futó build ugyanazt a `WatchBridge.swift`-et fordítja, tehát a típusellenőrzés ugyanaz. A Dart oldal a fake payloadra megkapja az eseményt (a watch-oldal még nem küld — az S7–S11 hátra van).

---

### S7 — watchOS: pending-tár + payload-modell — **kész, 2026-07-26**

**Fájlok:** új `mobile/ios/LifeyWatch/StandaloneSessionStore.swift`, `.../StandaloneSessionPayload.swift`

**Teendő:**
- `Codable` payload-struktúra a §4.1 szerint (`StandaloneSet` + `StandaloneSessionPayload`) — a `type` boríték-kulcs nincs benne a structban, azt S8 teszi rá küldéskor, mert minden sorba állított payload ugyanaz a típus, felesleges perzisztálni.
- JSON-fájl alapú tár az `Application Support`-ban (`StandaloneSessionStore`, singleton): `append(_:)`, `all()`, `remove(id:)`, plusz az élő session metájának kiírása (`StandaloneActiveSessionMeta` + `saveActive(...)`, `loadActive()`, `clearActive()`) az S9 recovery-jéhez.
- Egységes hozzáférés egy privát soros `DispatchQueue`-n (a doc „queue-n/aktoron” választási lehetőségéből a queue-t választva — a `WCSessionDelegate` callbackjei nem async-ok, egy actor minden hívási pontot `Task`-ba kényszerítene).
- **Xcode-projekt**: mindkét fájl felvéve a `Runner.xcodeproj/project.pbxproj`-ba (a projekt hagyományos, nem file-system-synchronized csoportokat használ — `PBXFileReference` + `PBXBuildFile` + a `LifeyWatch` csoport + a `LifeyWatch` target `PBXSourcesBuildPhase`-e, mind a négy helyen kézzel, hasonlóan a meglévő `PhoneConnector.swift`/`WorkoutManager.swift` bejegyzésekhez).

**Ellenőrzés (elvégezve):** `plutil -lint` a `project.pbxproj`-on — OK; a duplikált objektum-ID-k keresése (`isa = ` deklarációkra szűrve) — nincs ütközés. Teljes build: `xcodebuild -workspace Runner.xcworkspace -scheme LifeyWatch -destination 'id=<párosított fizikai óra>' -configuration Debug build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**; a derived-data-ban ellenőrizve, hogy mindkét új fájl valódi `.o` objektumfájllá fordult (`StandaloneSessionPayload.o`, `StandaloneSessionStore.o` a `LifeyWatch.build/.../arm64/` alatt) — tehát nem csak a projekt fájl szintaktikailag helyes, ténylegesen bekerültek a fordításba. Szimulátoron nem ellenőrizve (a user kérésére).

---

### S8 — watchOS: küldés + ack + retry — **kész, 2026-07-26**

**Fájl:** `mobile/ios/LifeyWatch/PhoneConnector.swift`

**Teendő:**
- `sendStandaloneSession(_ payload: StandaloneSessionPayload)` → `transferUserInfo` (a `sendSummary` mintája; a `type` kulcs kötelező, hogy a telefon szét tudja választani). A `Codable` → property-list-`[String: Any]` átalakítás `JSONEncoder` + `JSONSerialization` páron megy (a szintetizált `Encodable` a `nil` opcionálisokat kulcs-kihagyással kódolja, nem `null`-lal — ez kritikus, mert a property list nem ismeri a null-t, és a `transferUserInfo` némán elejtené az egész payloadot, ha becsúszna).
- `flushPendingStandaloneSessions()` — a tár összes elemét kiküldi; hívási pontok: a meglévő `activationDidCompleteWith` (ahol az `activate()`-ből hiányzó reachability-infó már megvan) és a meglévő `sessionReachabilityDidChange` (mindkettő már ott volt az F5-ös reachability-munkából, csak kiegészítve). A harmadik hívási pont (session-lezárás) az S9 feladata, ott, ahol a lezárás ténylegesen történik.
- `session(_:didReceiveMessage:)`: a `standaloneSessionAck` a meglévő `sessionClientId`-guard **elé** került, mert a §4.2 protokoll `standaloneSessionId`-t hordoz, nem `sessionClientId`-t — a guard emiatt elnyelte volna. `StandaloneSessionStore.shared.remove(id:)` + `NotificationCenter`-poszt (`.standaloneSessionAcked`) a summary-képernyő frissítéséhez — `NotificationCenter`-t választva a doc bullet szó szerinti API-ja helyett, mert az S9-cel bevezetendő `WorkoutManager` standalone-állapota még nem létezik; a poszt így nem forward-referencia, és S9/S11 feliratkozhat rá anélkül, hogy S8-at módosítani kellene.

**Ellenőrzés (elvégezve):** teljes `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'id=<párosított iPhone>' -configuration Debug build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED** (a `LifeyWatch` scheme közvetlenül a párosított fizikai órára időtúllépett — a gép és az óra közötti pillanatnyi kapcsolat hiánya, nem kód-hiba —, ezért a `Runner` scheme fordította le, ami a `LifeyWatch`-ot beágyazottként úgyis lefordítja); a `PhoneConnector.o` build-artifact frissen újragenerálva. Kézi, élő retry/ack-kör nem futtatható natív watch-oldali indítás nélkül (az S9 UI-bekötése hátravan) — ez a §8-as manuális teszt-lista (S12) feladata lesz.

---

### S9 — watchOS: `WorkoutManager` standalone mód — **kész, 2026-07-26**

**Fájlok:** `mobile/ios/LifeyWatch/WorkoutManager.swift` (fő), + három szükséges kísérő-módosítás (ld. lent): `PhoneConnector.swift`, `LifeyWatchApp.swift`, `Views/SummaryView.swift`

**Teendő:**
- Új publikált állapot: `isStandalone: Bool` (a doc két javaslata közül az egyszerűbb) + `standaloneSets: [StandaloneSet]` (az S7-ben már felvett típus újrahasznosítva, nem külön `LoggedSet`).
- `startStandalone()`: engedély-ellenőrzés → lokálisan generált `sessionClientId` (UUID, ugyanaz a publikált mező, amit a phone-mastered mód is használ — a meglévő `logSet()`/`requestEnd()` guardok így ingyen működnek) → `HKWorkoutConfiguration(.traditionalStrengthTraining, .indoor)` → a meglévő `startSession(configuration:)`; meta kiírása az S7-tárba. **Nem** küld `startedOnWatch`-ot (`notifyStartedOnWatchIfNeeded()` új `!isStandalone` guardja zárja ki). Az engedély-ellenőrzést kiemeltem egy közös `ensureHealthAuthorized()`-ba, amit a meglévő `start(configuration:)` is újrahasznosít (a doc „újrahasznosítva” szava szerint) — viselkedés nem változott, csak a duplikáció szűnt meg.
- `logSet()` lokális ága a 43-as doc §2.1 szerinti egyetlen elágazásponton (`beginLocalLogSet()`): azonnali `.confirmed` + haptika + `standaloneSets.append(...)` (`reps = standaloneDefaultReps = 10`) + meta-kiírás + lokális rest indítása (`restDeadlineUptime = systemUptime + 90`, `restTotalSeconds = 90`).
- `applyStateUpdate` (D-F6.2): standalone alatt eldobja a telefon state-jét; mivel a watch saját `sessionClientId`-ja ilyenkor mindig a lokális UUID, **bármilyen** bejövő state/context idegen id-vel érkezik — ez egyben „a telefon indítani próbált” jelzés is, ezért ilyenkor `sendStartRejected`-et küld.
- `endStandalone(rpe:)`: `finishAndSendSummary()` standalone változata — HKWorkout mentése, **`sendSummary` helyett** payload-építés + `StandaloneSessionStore.append` + `clearActive()` + `PhoneConnector.flushPendingStandaloneSessions()`; `phase = .summary(...)` a szettszámmal (`WorkoutSummaryData` új `setsCount: Int?` mezője — lásd lent). `requestEnd(rpe:)` ág elé kötve: standalone-ban nincs `.ending`, egyből ide hív, a meglévő `EffortSelectorView` UI-t megtartva (§11 döntés).
- Recovery induláskor: `recoverActiveWorkoutSession(completion:)` (`withCheckedContinuation`-nel async-osítva — a watchOS 10.0 deployment target miatt a completion-alapú API-t választottam a bizonytalan async-throws overload helyett) + `loadActive()` → visszatérés `.active`-ba standalone módban.

**A doc egy-fájlos listáján túli, szükséges módosítások** (mind a D-F6.2/D-F6.7 helyes működéséhez, nem elkerülhetők):
- `PhoneConnector.swift`: a `didReceiveMessage`'s `"end"` ága és az `applyContext`'s `desiredPhase == "ended"` fallback ága is kapott egy `!isStandalone` guardot — ezek **nem** `sessionClientId` szerint szűrnek, tehát egy elakadt/idegen telefon-oldali `end` üzenet a guard nélkül lezárná a futó standalone sessiont a rossz (`finishAndSendSummary`/`sendSummary`) úton. Ez pontosan a doc §9 tesztlistájának „telefon `state`/`end` üzenete standalone alatt → figyelmen kívül marad” pontja.
- `LifeyWatchApp.swift`: `AppDelegate.applicationDidFinishLaunching()` hívja a recovery-t — nem volt korábban semmilyen induláskori hook, amibe ez bekerülhetett volna a `WorkoutManager.swift`-en belül.
- `Views/SummaryView.swift`: a `#Preview`-ban lévő `WorkoutSummaryData(...)` hívás kapott egy `setsCount: nil`-t — a struct-mező bővítése miatt ez lefordíthatatlan lett volna e nélkül.

**Ellenőrzés (elvégezve):** teljes `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'id=<párosított iPhone>' -configuration Debug build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**; a `WorkoutManager.o` mindkét watch-architektúrára (`arm64`, `arm64_32`) frissen újrafordulva a derived data-ban ellenőrizve. Élő szimulátoros/fizikai-eszközös funkcionális teszt (session indul, szettek gyűlnek, lezáráskor payload a tárba kerül) **nem futtatható még** — ehhez a launcher/picker UI kell (S10), F6a-ban a `startStandalone()`-t semmi sem hívja meg még; ez a §9-es manuális teszt-lista (S12) feladata lesz.

---

### S10 — watchOS: launcher + picker — **kész, 2026-07-26**

**Fájlok:** `mobile/ios/LifeyWatch/Views/IdleView.swift`, új `Views/StandalonePickerView.swift`, `ContentView.swift` (+ `Runner.xcodeproj/project.pbxproj`, mint minden új fájlnál)

**Teendő:**
- `IdleView`: AW 12 szerinti kompozíció (kompaktabb badge/wordmark — a fraction 0.22/0.13-ról 0.19/0.11-re csökkentve —, `standalone_start_button` pill, `standalone_start_caption`), százalékos méretezéssel (`DynamicSizing`), a11y-címkével (`standalone_start_button_a11y`). A régi `idle_subtitle` hivatkozás megszűnt, a kulcs megmaradt a katalógusokban (§0.10 döntés szerint nem törlünk).
- `StandalonePickerView`: `standalone_picker_title` fejléc + kiemelt „Quick strength” kártya (`bolt` ikon, `standalone_quick_start` / `standalone_quick_caption`) + `standalone_empty_hint`; F6b-ben ide jön a template-lista. **A designban nem szerepel, de felvéve**: egy chevron-left vissza-gomb (top-leading) — F6a-ban a picker egyetlen sora a Quick strength, vissza-gomb nélkül a user véletlen megnyitás után beragadna. Az `effort_selector_back` kulcs szövegét (sima „Back”/„Vissza”) használja újra egy dedikált picker-kulcs helyett — ez az egyetlen tudatos kulcs-scope-keveredés ebben a lépésben. A „Quick strength” tap 300 ms-os debounce-szal + `isStarting`-guarddal védett (a `LogPage` mintája), és a guard sikertelen indítás után (a `phase` `.idle`-ban marad) magától felold.
- `ContentView`: `showStandalonePicker` **lokális `@State`** (nem a `WorkoutManager`-en, szemben a `showEffortSelector`-ral — ez tiszta UI-navigáció, nem üzleti állapot, amit a managernek ismernie kellene) az `.idle` ágon belül; a quick-tap → `WorkoutManager.startStandalone()` közvetlenül a `StandalonePickerView`-ból, a `ContentView` a `phase`-váltásból automatikusan lekövet.

**Ellenőrzés (elvégezve):** teljes `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'id=<párosított iPhone>' -configuration Debug build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**; `plutil -lint` + duplikált objektum-ID keresés a `project.pbxproj`-on rendben; a derived data-ban `StandalonePickerView.o` (új), `IdleView.o`, `ContentView.o` mind frissen újrafordulva. Élő szimulátoros/eszközös bejárás (launcher → picker → aktív képernyő) a §12-es manuális teszt-lista (S12) feladata — a szükséges kód-út mostantól végig megvan hozzá.

---

### S11 — watchOS: aktív képernyő + summary deltái — **kész, 2026-07-26**

**Fájlok:** `mobile/ios/LifeyWatch/Views/ActiveWorkoutView.swift`, `Views/SummaryView.swift` (+ szükséges kísérő-módosítás: `Theme/LifeyColors.swift`, `WorkoutManager.swift`)

**Teendő:**
- Fejléc: `HeaderChip` (a mindhárom lapon és a rest-hérón is újrahasznosított közös komponens) új kötelező `isStandalone` paramétert kapott — a glyph ezért nem csak a „STRENGTH” sor mellett jelenik meg, hanem minden fejléc-instance-on (log-lap eltelt idő, controls-lap eltelt idő, rest „Pihenő” címke is), a design §3.4 „mode, not alarm” általánosabb megfogalmazása szerint. SF Symbol: `iphone.slash` (a `phonelink_off` legközelebbi natív megfelelője). Az `onSurfaceVariant`-nál halványabb tónus egy **új** `LifeyColors.standaloneIndicator` (`#777264`) konstans — ezt a doc kifejezetten „halványabb, mint onSurfaceVariant” szóhasználata indokolja, tehát nem lehetett meglévő tokent újrahasznosítani.
- Gyakorlat-kártya (`ExerciseCard`): új opcionális `freeFormatSets: (count, totalReps)?` — standalone-ban `active_sets_free_format`-ot mutat `setsTotal`/pöttyök helyett, cím `standalone_quick_start` („Gyors erőedzés”). Ugyanez a felbontás a rest-hero „Next · …” sorának exercise-name-fallbackjén (`restExerciseName`) és a log-lap `contextLine`-ján is.
- Log-lap: a `.confirmed` állapot standalone-ban is mutat egy szám-sort a pipa alatt — mivel nincs `setsTotal`, ez is `active_sets_free_format`-ot használ (szettszám + összes ismétlés) egy dedikált „bare Set N” kulcs bevezetése helyett. A `.pending`/„Naplózás…” állapot már az S9-ből eleve sosem fut le standalone-ban (a helyi ág egyenesen `.confirmed`-be lép), ezért ehhez itt nem kellett új logika.
- `SummaryView`: negyedik csempe (`summary_sets_label`) **csak** `data.setsCount != nil` esetén, 2×2 `LazyVGrid`-del (a design AW15/W14 rácsa) a meglévő 3-elemű `HStack` helyett — a csempéket egy közös `statTiles(isCompact:)` `@ViewBuilder` építi fel mindkét elrendezéshez, hogy ne térjenek el egymástól idővel. Sync-chip (`sync_pending`/`sync_done`) + `sync_queue_count` sor (> 1 várakozó elemnél) `data.standaloneSessionId != nil` esetén — élőben frissül a `PhoneConnector` (S8) `.standaloneSessionAcked` `NotificationCenter`-posztjára feliratkozva, **az adott session id-jét** ellenőrizve (nem csak azt, hogy a tár kiürült-e — több párhuzamosan várakozó session esetén ez számítana).
- **Szükséges kísérő-módosítások**: `WorkoutSummaryData` kapott egy `standaloneSessionId: String?` mezőt (az S9-ben felvett `setsCount` mellé) — enélkül a `SummaryView` nem tudná megkülönböztetni „a saját sessionöm szinkronizált” és „a tár kiürült” között; a két meglévő `WorkoutSummaryData(...)` hívás (`finishAndSendSummary`, `endStandalone`) ennek megfelelően frissült.

**Ellenőrzés (elvégezve):** teljes `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'id=<párosított iPhone>' -configuration Debug build CODE_SIGNING_ALLOWED=NO` → **BUILD SUCCEEDED**, nulla figyelmeztetés az érintett fájlokban; `ActiveWorkoutView.o`, `SummaryView.o`, `WorkoutManager.o`, `LifeyColors.o` mind frissen újrafordulva. Szimulátoros/eszközös vizuális bejárás (45 mm/41 mm, mindhárom lap + summary) a §12-es manuális teszt-lista (S12) feladata.

---

### S12 — iOS: kézi végpróba — **kész, 2026-07-26 (a user kézi tesztje alapján, fizikai eszközön)**

**Teendő:** a §9 iOS-listája (teljes standalone kör; telefon-app kilövése; watch-app kilövése aktív session alatt; telefon indít közben; telefon `state`/`end` standalone alatt).

**Ellenőrzés:** mind az öt eset a §2/§3 szerint viselkedik, és a session a telefonon ⌚-badge-dzsel jelenik meg — a user saját fizikai óra+telefon páron elvégezte a kézi kört, jóváhagyva.

---

### S13 — Android/telefon: fogadás + puffer + ack — **kész, 2026-07-26**

**Fájlok:** `mobile/android/app/src/main/kotlin/com/khunor/lifey/WatchBridge.kt`, új `WatchStandaloneSessionBuffer.kt` (a doc felkínált alternatívája — külön osztály a meglévő `WatchSummaryBuffer` mellett, nem egy paraméterezett közös verzió, hogy a bevált, éles kódot ne kelljen átírni/migrálni), `PhoneWatchSummaryListenerService.kt`, `AndroidManifest.xml`

**Teendő:**
- `COMMAND_STANDALONE_SESSION = "standaloneSessionCompleted"` / `COMMAND_STANDALONE_ACK = "standaloneSessionAck"` konstansok.
- `onMessageReceived`: az új path → `eventSink?.success(mapOf("type" to "standaloneSession", "payload" to <parsed map>))` — a `sets` tömböt elemenként map-eli át (`loggedAtEpochMs`/`reps`/`exerciseIndex`); a `healthWorkoutId` itt mindig `null` (D-F6.5), függetlenül attól, mi jött a JSON-ban.
- `onMethodCall`: `"ackStandaloneSession"` → `sendMessage(COMMAND_STANDALONE_ACK, json)`.
- `PhoneWatchSummaryListenerService`: a `when (messageEvent.path)` most **mindkét** útvonalat kezeli (summary → `WatchSummaryBuffer`, standalone → az új `WatchStandaloneSessionBuffer`).
- `AndroidManifest.xml`: a meglévő `<service>` `<intent-filter>`-je egy **második `<data>` elemet** kapott ugyanabban a filterben (Androidon egy filteren belüli több `<data>` VAGY-kapcsolatban van, nem ÉS) — nem külön `<intent-filter>`/`<service>`, egyszerűbb és a merge-elt manifestben ellenőrizve helyesen működik.
- `onListen`: a standalone-tár drain-je a summary-drain mellé került.

**Ellenőrzés (elvégezve):** `./gradlew :app:compileDebugKotlin` → **BUILD SUCCESSFUL**; `./gradlew :app:processDebugMainManifest` → **BUILD SUCCESSFUL**, a merge-elt manifestben mindkét `<data>` útvonal jelen van a `PhoneWatchSummaryListenerService`-nél. Élő `adb`-injektált üzenet + Dart-oldali fogadás (futó és kilőtt app esetén) a §14-es Wear-oldali manuális teszt-listával együtt, az Android-ág végén (S18) ellenőrizhető ténylegesen — a wear-oldali küldő fél (S14) még nincs kész.

---

### S14 — Wear: pending-tár + küldés + ack + retry — **kész, 2026-07-26**

**Fájlok:** új `mobile/android/wear/src/main/kotlin/com/khunor/lifey/StandaloneSessionStore.kt`, `SummarySender.kt`, `PhoneListenerService.kt`, `MainActivity.kt` (+ szükséges kísérő-módosítás: `SessionStateHolder.kt`)

**Teendő:**
- `StandaloneSessionStore`: `SharedPreferences` + `JSONArray` (a `WatchSummaryBuffer` mintája) — `add`, `all` (`List<JSONObject>`), `remove(id)`, plusz `saveActive`/`loadActive`/`clearActive` az élő session metájához. Nyers JSON, nem típusos data class — ez illeszkedik a kódbázis meglévő konvenciójához (a `SummarySender`/`PhoneListenerService` sem használ típusos modellt egyik másik üzenethez sem).
- `SummarySender.sendStandaloneSession(context, payloadJson)` a `/lifey/watch/standaloneSessionCompleted` path-ra + `flushPending(context)`, ami a tár összes elemét újraküldi.
- `PhoneListenerService`: új `standaloneSessionAck` ág → `StandaloneSessionStore.remove(id)` + állapotfrissítés — ehhez a `SessionStateHolder`-be egy új `standaloneSessionAcked: SharedFlow<String>` került (az iOS `.standaloneSessionAcked` `NotificationCenter`-posztjának Kotlin-megfelelője), amire a majdani summary-képernyő (S17) iratkozhat fel.
  - **Eltérés a doc szövegétől**: `onCapabilityChanged` helyett `onPeerConnected(peer: Node)`-t implementáltam. A `onCapabilityChanged` egy `CAPABILITY_CHANGED` manifest-intent-filtert és egy telefon-oldali capability-deklarációt igényelne, ami ma nem létezik (a `lifey_watch_workout` capability csak az óra→telefon irányban van deklarálva). Az `onPeerConnected` a `WearableListenerService` beépített, kapu nélküli callbackje — a már meglévő `MESSAGE_RECEIVED`/`DATA_CHANGED` intent-filterek elegendők hozzá, nem igényel új capability-t, és pontosan ugyanazt a célt szolgálja (retry, amint a telefon újra elérhető), mint amit a doc szándékozott.
- `MainActivity.onCreate` → `flushPending` (`lifecycleScope`-pal, app-indulási retry) — ez fedi le azt az esetet, amikor a telefon csak azután kerül elő, hogy az óra-app már be lett zárva és újraindult; az `onPeerConnected` a menet közbeni újracsatlakozást fedi le.

**Ellenőrzés (elvégezve):** `./gradlew :wear:compileDebugKotlin` → **BUILD SUCCESSFUL**, nulla figyelmeztetés az érintett fájlokban; `./gradlew :wear:processDebugMainManifest` → **BUILD SUCCESSFUL** (a meglévő `pathPrefix="/lifey/watch"` intent-filter már lefedi az új `standaloneSessionAck` üzenetutat, manifest-módosítás nem kellett hozzá). Emulátorpáron kézzel a tárba tett elem kiküldése/ack-re törlése, valamint az `onPeerConnected` tényleges lefutása (nincs `CAPABILITY_CHANGED`-nél megbízhatóbb, de élőben még nem tesztelt API-választás) a §14-es Wear-oldali manuális teszt-lista (S18) feladata — ez a wear-oldali küldő fél még nincs bekötve élő session-lezáráshoz (az S15 feladata).

---

### S15 — Wear: `SessionStateHolder` + `ExerciseService` standalone ág — **kész, 2026-07-26**

**Fájlok:** `.../SessionStateHolder.kt`, `.../ExerciseService.kt` (+ szükséges kísérő-módosítás: `PhoneListenerService.kt`, `MainActivity.kt`)

**Teendő:**
- `SessionPhase`-hez `SUMMARY` (D-F6.7). `SessionMetadata`-hoz `isStandalone: Boolean` + `standaloneSets: List<StandaloneSet>` — **`standaloneSessionId` külön mező helyett** a meglévő `sessionClientId` újrahasznosítva (`SessionMetadata.standaloneSessionId` egy computed property, ami `isStandalone`-nál a `sessionClientId`-t adja vissza) — pontosan az iOS `WorkoutManager.sessionClientId` mintáját követve, hogy minden meglévő hívási hely automatikusan megkapja. „Lokális rest” nem kapott új mezőt: a meglévő `restDeadlineElapsedRealtimeMs`/`restTotalSeconds` írja mindkét mód, ahogy a doc is előírta.
- Új `onStandaloneStarted`, `onStandaloneSetLogged` (`reps = STANDALONE_DEFAULT_REPS = 10`, D-F6.8 — fájl-szintű `private const val`, az iOS `standaloneDefaultReps` párja; a hívás egyben a 90 s-os `STANDALONE_REST_SECONDS` rest-deadline-t is beállítja), `onStandaloneEnded(summary: StandaloneSummary)`.
  - **`onSyncStateChanged` külön metódus nélkül** — ezt már az S14 lefedte (`onStandaloneSessionAcked` + `standaloneSessionAcked: SharedFlow<String>`), a doc bullet ugyanarra a szükségletre utalt.
  - **Kotlin-specifikus eltérés**: mivel a Kotlin `enum class` — szemben a Swift `enum`-mal — nem tud asszociált értéket hordozni, a `SUMMARY` fázishoz tartozó adatok (időtartam, szettszám, avg HR, kcal, `standaloneSessionId`) egy külön `StandaloneSummary` data class + `SessionStateHolder.standaloneSummary: StateFlow<StandaloneSummary?>` formájában élnek, amit `onStandaloneEnded` a fázisváltással egyszerre állít be.
- `onStateSynced`: standalone alatt no-op guard a metódus elején (D-F6.2) — a tényleges `sendStartRejected`-küldés a `PhoneListenerService`-ben történik (ez az objektum nem éri el a `SummarySender`-t).
- `ExerciseService`: a közös engedély-ellenőrzés+konfiguráció-építés kiemelve egy `buildExerciseConfig()` helperbe (a doc „újrahasznosítás” szelleme, mint az iOS `ensureHealthAuthorized()`-nél). `ACTION_START_STANDALONE`/`startStandaloneIntent` (UUID-et maga generál, `sendStartedOnWatch` nélkül) és `ACTION_END_STANDALONE`/`endStandaloneIntent(rpe)` (a `sendSummary` helyett payload a `StandaloneSessionStore`-ba + `clearActive` + `flushPending`, majd `onStandaloneEnded` + `SUMMARY` fázis; a foreground-notification azonnal eltűnik, de a service ~6 mp-ig háttérben életben marad az `scheduleSummaryAutoDismiss()` késleltetett `reset()`+`stopSelf()`-jéhez — mirroring iOS `summaryAutoDismissSeconds`-t). Az élő-session recovery-snapshot (`StandaloneSessionStore.saveActive`) minden szett-logoláskor frissül egy `onCreate()`-beli flow-collectorral, nem csak indításkor — ez a doc bulletjén túlmutat, de szükséges a „minden szett után” követelményhez, és **maga a recovery-visszaolvasás (folyamathalál utáni resume) nincs implementálva** — ezt a §10 nyitott kérdésként rögzíti, mivel a doc S15 bulletje sem tartalmazta explicit módon (aszimmetria az iOS S9-hez képest, ahol ez benne volt).
- `PhoneListenerService`: `/start` standalone alatt → `sendStartRejected`, az exercise érintetlen; `/end` és a `desiredPhase: "ended"` fallback (`onDataChanged`) szintén no-op guarddal.
- **Szükséges, doc-listán túli módosítás**: a `SessionPhase` enumhoz `SUMMARY` hozzáadása után a `MainActivity.kt` `when (phase)` ága **fordítási hibává vált** (a `when` a Composable lambda implicit visszatérési értéke, tehát kimerítő kell legyen — ez ellentétben áll a korábbi feltételezésemmel, miszerint ez csak futásidőben ürült volna ki; a build ténylegesen ezt bizonyította). Egy explicit `SessionPhase.SUMMARY -> {}` ág került be — szándékosan üres/ideiglenes placeholder, nem egy kölcsönvett képernyő —, a valódi `SummaryScreen` az S17 feladata.

**Ellenőrzés (elvégezve):** `./gradlew :wear:compileDebugKotlin` → **BUILD SUCCESSFUL** (első próbálkozásra a `MainActivity.kt` `when`-je miatt elbukott, a fenti javítás után zöld), nulla figyelmeztetés az érintett fájlokban. Élő állapotátmenet-teszt (start → szett-logolás → end → SUMMARY → auto-dismiss) emulátorpáron a §15/§18-as manuális teszt-lista feladata — ehhez még kell a launcher/picker UI (S16) és az aktív képernyő End-gombjának standalone-ága (S17), mert semmi sem hívja meg még az `ACTION_START_STANDALONE`/`ACTION_END_STANDALONE` intenteket.

---

### S16 — Wear: launcher + picker — **kész, 2026-07-27**

**Fájlok:** `.../ui/IdleScreen.kt`, új `.../ui/StandalonePickerScreen.kt`, `MainActivity.kt` (+ `ExerciseService.kt` egy sornyi korrekció)

**Teendő:**
- `IdleScreen`: W 11 szerinti kompozíció, Wear Compose `Button` primary-konténerrel, stadium-alakkal; `standalone_start_caption` a mai `idle_subtitle` helyén.
- `StandalonePickerScreen`: `ScalingLazyColumn` a `standalone_picker_title` fejléccel, kiemelt quick-kártyával és `standalone_empty_hint`-tel.
- `MainActivity`: a picker megjelenítése lokális állapotból (a `SessionPhase.IDLE` ágon belül) + engedély-ellenőrzés a start előtt; start → `ExerciseService.startStandaloneIntent(...)`.

**Megvalósítás és eltérések a doc szövegétől:**
- `IdleScreen` most `IdleScreen(onStartTapped: () -> Unit)` — launcherré vált. A doc `Button`-t írt elő; ehelyett `CompactChip`-et implementáltam, az `ErrorScreen.kt` már meglévő mintáját követve. Indoklás: a Wear Compose `Button` alapból kör alakú (nem stadium), ami ellentmond a doc saját stadium-alak elvárásának; a `Chip` viszont `Column`-ban alapból teljes szélességre nyúlik (nem a design natural-width pill-je); a `CompactChip` az egyetlen a hármuk közül, ami tartalom-méretű, középre igazított pill-t ad — ez pontosan a canvas W 11 vizuálisan. A badge/leaf méretarányok (`LEAF_BADGE_SIZE_FRACTION`/`LEAF_MARK_SIZE_FRACTION`) 0.19f/0.11f-re csökkentek a gomb+felirat helyének. `standalone_start_button_a11y` a gomb `contentDescription`-je.
- `StandalonePickerScreen` (új fájl): `ScalingLazyColumn` + `rememberScalingLazyListState` — **az `androidx.wear.compose.foundation.lazy` csomagból**, nem a `androidx.wear.compose.material`-ból (utóbbi ugyan még lefordul, de deprecated — a fordító explicit erre a csomagra mutat). Egyetlen `Chip` sor (Quick strength, `Icons.Filled.Bolt`, label+secondaryLabel) + `standalone_empty_hint` alul. Vissza-nyíl a `EffortSelectorScreen.kt` pontos mintáját követve (top-start sarok, `effort_selector_back` contentDescription, nem a `ScalingLazyColumn` flow-jában). F6a-ban ez mindig az „üres/nincs terv” variáns — F6b (T4) tesz majd fölé szinkronizált terv-sorokat.
- `MainActivity`: `showStandalonePicker` lokális `remember { mutableStateOf(false) }` a `SessionPhase.IDLE` ágon belül (nem a `SessionStateHolder`-en, mert ez tisztán UI-navigáció, nem üzleti állapot — az iOS S10 `showEffortSelector`-mintáját tükrözi). Quick strength tap → `requestSensorPermissionsIfNeeded()` újra (nem csak `onCreate`-kor egyszer) + `ContextCompat.startForegroundService(..., ExerciseService.startStandaloneIntent(...))`.
- **Doc-listán túli, retroaktív korrekció**: az S16 UI-bekötés közben észrevettem, hogy `ExerciseService.startStandaloneExercise()`-nek (S15) nem volt védelme dupla egyidejű hívás ellen (szemben az iOS `guard phase == .idle`-jével). Hozzáadtam egy `if (SessionStateHolder.phase.value != SessionPhase.IDLE) return` guardot a metódus elejéhez — a debounce-nak a service-szinten a helye, nem a UI-n, hogy a védelem attól függetlenül is álljon, mi hívja ki (pl. jövőbeli másik belépési pont).

**Ellenőrzés (elvégezve):** `./gradlew :wear:compileDebugKotlin` → **BUILD SUCCESSFUL**, nulla figyelmeztetés az érintett fájlokban (az első próbálkozás két deprecation warningot adott a `ScalingLazyColumn`/`rememberScalingLazyListState`-re a `androidx.wear.compose.material` importból — a fenti csomagváltással megszűntek). A launcher → picker → aktív képernyő teljes útvonal élő emulátoros/kerek-kijelzős bejárása a §14/S18-as manuális teszt-lista feladata.

---

### S17 — Wear: aktív képernyő deltái + `SummaryScreen` — **kész, 2026-07-27**

**Fájlok:** `.../ui/ActiveWorkoutScreen.kt`, új `.../ui/SummaryScreen.kt`, `MainActivity.kt`, `.../ui/theme/LifeyColors.kt`, `values/strings.xml` + `values-en/strings.xml`

**Teendő:**
- Fejléc `phonelink_off` ikon (muted), `contentDescription = standalone_badge`; `active_sets_free_format` a terv nélküli kártyán; a log-lap lokális módja.
- `SummaryScreen`: W 14 szerint 4 csempe + sync-chip (`sync_pending`/`sync_done`) + `sync_queue_count` sor; a `MainActivity` `when (phase)` ágába `SessionPhase.SUMMARY -> SummaryScreen(...)`.

**Megvalósítás és eltérések a doc szövegétől:**
- `ActiveWorkoutScreen.kt` — a meglévő `HeaderChip`/`ExerciseCard`/`LogPage`/`LogCircle`/`LogStatusLine`/`MetricsOrRestPage`/`ControlsPage`/`RestHero` mind kaptak egy `isStandalone`/`freeFormatSets` paramétert (mirroring iOS `ActiveWorkoutView`-jának S11-es delta-listáját 1:1). `HeaderChip` az `Icons.Filled.PhonelinkOff` ikont rendereli `standaloneIndicator` (`#777264`) tinttel, `contentDescription = standalone_badge`, ha `isStandalone` — minden oldal fejlécén (Log/Metrics/Rest/Controls), nem csak a „STRENGTH” címkés oldalon (canvas W 13: „mode, not alarm”). `ExerciseCard` és a log-kör `Confirmed` állapota `active_sets_free_format`-ot ("n. szett · összesen r ismétlés") rendereli `setsDone`/`setsTotal` helyett, ha `freeFormatSets != null`. A log-lap `Ready` context-sora standalone alatt `standalone_quick_start`-ot mutat a „köv. szett” szám helyett (nincs terv, amihez viszonyítani). Az `exerciseName` egy közös, top-level `ActiveWorkoutScreen`-beli számítás lett (`metadata.exerciseName ?: standalone_quick_start-vagy-active_default_exercise`) — a korábbi három külön (LOG/METRICS/CONTROLS ágankénti) `stringResource` hívás helyett, hogy a standalone fallback egy helyen éljen.
- **End-gomb routing, doc-listán túli, de a §3.1/D-F6.2 szükséges következménye**: az `EffortSelectorScreen`-en a Confirm/Skip eddig mindig `SummarySender.sendEndRequested`-et hívott (a telefont kérve meg a session lezárására). Standalone alatt nincs telefon-mastered session, amit megkérni — a Confirm/Skip most `isStandalone`-on ágazik: standalone esetén `ContextCompat.startForegroundService(context, ExerciseService.endStandaloneIntent(context, rpe))`-ot hív (a `S15`-ben már kész `endStandaloneExercise` motort), egyébként a régi `sendEndRequested`-et — pontosan az iOS `WorkoutManager.beginEffortSelection()`-jén belüli azonos elágazást tükrözve.
- Új `SummaryScreen.kt`: `SessionStateHolder.standaloneSummary`-t figyeli (`collectAsState`), `null`-nál semmit nem renderel (a `MainActivity` csak azután lép `SUMMARY`-ba, hogy `onStandaloneEnded` a kettőt együtt állította be). Checkmark ikon + `summary_title`, `LazyVerticalGrid(GridCells.Fixed(2))` 4 csempével (idő, szett, átlag pulzus, kcal — a szett-csempe itt sosem opcionális, mert `StandaloneSummary.setsCount` nem nullable, szemben az iOS opcionális csempéjével), majd a sync-chip. **Nincs „Saved to Health” pill** — Android az órán sosem ír Health Connectbe (D-F6.5, csak a telefon), úgyhogy ez a rész az iOS-ből egyszerűen kimaradt, nem lett üresen portolva. A sync-chip `isSynced`/`pendingCount` állapota `remember(data.standaloneSessionId)`-vel inicializált a `StandaloneSessionStore.all(context)` aktuális tartalmából, majd egy `LaunchedEffect(data.standaloneSessionId)` iratkozik fel `SessionStateHolder.standaloneSessionAcked`-re — pontosan az iOS `SummaryView.init`+`.onReceive` párja.
- `LifeyColors.kt`: új `standaloneIndicator = Color(0xFF777264)` — az iOS S11-es identikus tokenjének Android-megfelelője, eddig hiányzott.
- `values/strings.xml` + `values-en/strings.xml`: 4 hiányzó kulcs pótolva (`summary_title`, `summary_time_label`, `summary_avg_hr_label`, `active_calories_unit`) — ezek eddig csak az iOS `Localizable.xcstrings`-ben léteztek (Android-oldalon sosem volt `SummaryScreen`), a `summary_sets_label`/`sync_*`/`standalone_badge`/`active_sets_free_format` kulcsok viszont már S1-ből megvoltak.

**Ellenőrzés (elvégezve):** `./gradlew :wear:compileDebugKotlin` (majd `--rerun` egy teljes újrafordítással) → **BUILD SUCCESSFUL**, nulla figyelmeztetés a projekt saját fájljaiban (a kimenetben csak a megszokott, e lépéstől független AGP/Gradle-plugin deprecation-sorok jelentek meg). `./gradlew :wear:processDebugMainManifest :wear:parseDebugLocalResources` → **BUILD SUCCESSFUL**, az új string-kulcsok érvényesek. A design szerinti tényleges vizuális megjelenés (kerek és négyzetes emulátoron, rest-hero és GO-flash változatlansága, a `phonelink_off` glyph valódi renderelése) a §14/S18-as manuális teszt-lista feladata — build-szinten csak a fordítás és a resource-validáció történt meg ezen a lépésen.

---

### S18 — Android: kézi végpróba — **kész, 2026-07-26** (fejlesztői eszközös visszaigazolás)

**Teendő:** a §9 Wear-listája (teljes kör; több pending session; elveszett ack → újraküldés → dedup; telefon indít közben; SUMMARY auto-dismiss).

**Ellenőrzés:** minden eset a §2/§3 szerint viselkedik, és a session a telefonon ⌚-badge-dzsel jelenik meg.

**Build-szintű előellenőrzés** (a kézi teszt előtt): `./gradlew :app:assembleDebug :wear:assembleDebug` → **BUILD SUCCESSFUL** (3m 47s, 385 task) — mindkét modul teljes összeállítása lefutott, ami az S13–S17 összes érintett fájlját és a cross-module drótozást lefedte build-szinten. A tényleges élő bejárást (pairing, üzenetküldés, standalone flow) a fejlesztő végezte el eszközön és igazolta vissza.

---

### S19 — Közös zárás — **kész, 2026-07-26**

**Teendő:**
- ✅ **Regressziós kör mindkét platformon** (F0–F5 phone-mastered flow változatlan): `flutter analyze` tiszta; `:app:compileDebugKotlin` + `:wear:compileDebugKotlin` → `BUILD SUCCESSFUL`; teljes `LifeyWatch` target típusellenőrzés hibátlan. `flutter test` 386 zöld / 1 bukó — a bukó bizonyítottan **nem** ehhez a munkához tartozik (§11/7: `origin/main`-nel bitre azonos statisztika-teszt, dátumfüggő DST-artefakt).
- ✅ `docs/watch/40-watch-app-plan.md` állapottáblázatának F6a-sora „✅ Kész”-re mindkét platformon (az S18 élő tesztje lefutott).
- ✅ Ennek a docnak a státusz-fejléce frissítve.
- ✅ **A §11/8 F6a-hiba javítva** (a log-kontroll standalone módban a telefon elérhetőségére volt kapuzva mindkét platformon) — lásd §11/8, javítás + ellenőrzés dokumentálva.
- ✅ **A §11/6 Wear-recovery aszimmetria pótolva** — `ExerciseService.recoverIfNeeded(context)` + `recoverStandaloneExercise()` + `SessionStateHolder.onStandaloneRecovered(...)`, `MainActivity.onCreate()`-ből indítva, a Health Services `getCurrentExerciseInfoAsync()` szabványos mintájával. Lásd §11/6, javítás + ellenőrzés dokumentálva. Élő teszt (folyamat kilövése + újranyitás közben fut-e még a session) hátravan.

- ✅ **10-es default reps eszközön megerősítve** (2026-07-26) — jónak bizonyult, marad; lásd D-F6.8.

**Nyitva maradó, apró finomítási pont** (nem blokkolja a lezárást, de nincs róla eszközös visszajelzés, ezért nem jelölöm ki magamtól a választ):
- Kell-e a `sync_queue_count` sor a UI-ba — csak akkor dönthető el, ha van rá konkrét eszközös tapasztalat (jelenleg nem panaszolta a user, de nem is erősítette meg explicit).

**Kiegészítő ellenőrzés (2026-07-28, a fenti regressziós körön túl):** `./gradlew :app:assembleDebug :wear:assembleDebug` → **BUILD SUCCESSFUL** (3m 47s) — a `compileDebugKotlin`-nál szélesebb kör: resource-merge, manifest-merge, dexing, csomagolás mindkét modulon, ami az S13–S17 összes cross-module drótozását lefedi build-szinten. `xcodebuild -workspace Runner.xcworkspace -scheme Runner build` (fizikai iPhone-célponttal) → **BUILD SUCCEEDED** — csak projekt-szintű, F6-tól független figyelmeztetések (`CFBundleShortVersionString` mismatch, `AppIntents.framework` metaadat-üzenetek). Az első futás `error: Module 'connectivity_plus' not found`-dal bukott — ez egy helyi, elavult CocoaPods-telepítés volt (a `Pods/` könyvtárból hiányzott a modul), nem kódhiba; `flutter pub get` + `pod install` után zöld. Külön jegyezve, mert egy tiszta checkout után ugyanez máshol is előjöhet.

---

## 13. F6b lépések (vázlat — lásd [49-watch-f6b-template-sync-plan.md](49-watch-f6b-template-sync-plan.md) az alapos tervért)

> Ez a táblázat az F6b **kiinduló vázlata** volt — a részletes terv (`restSeconds` valódi forrása, iOS `updateApplicationContext`-ütközés, exerciseIndex-feloldás, a gyakorlat-léptetés UX-ének designer-döntést igénylő hiánya, stb.) a 49-es docban készült el. Itt hagyva, mert a T1–T6 azonosítók még előfordulnak hivatkozásként (§14/1, D-F5b.8).

| Lépés | Tartalom | Fájlok |
|---|---|---|
| T1 | Dart: `syncTemplates(...)` a `WatchWorkoutService`-ben + serializálás a template-repositoryból (max. 5 friss terv, gyakorlatnév + `targetSets` + `restSeconds`) | `watch_workout_service.dart`, `workout_template_repository.dart` |
| T2 | Push-pontok: app-indulás + terv-mentés/-módosítás, `watchWorkoutEnabled` kapuzással | template-controller / app-indító hely |
| T3 | Natív továbbítás: iOS `updateApplicationContext` külön kulccsal, Android message + DataItem-tartalék | `Runner/WatchBridge.swift`, `WatchBridge.kt` |
| T4 | Watch-cache + picker feltöltése (`standalone_plan_exercises` sor), lista-üresség esetén az F6a-váz | `StandaloneSessionStore` / `PhoneConnector`, `PhoneListenerService`, picker-képernyők |
| T5 | Gyakorlat-léptetés a standalone sessionben + `exerciseIndex` a payloadban; a template `restSeconds` felülírja a 90 s defaultot | `WorkoutManager.swift`, `SessionStateHolder.kt`, aktív képernyők |
| T6 | Telefon-oldal: `templateId` → `templateClientId`/`templateName`, `exerciseIndex` → valódi gyakorlat a feldolgozóban + tesztek | `standalone_session_processor.dart` |

---

## 14. Ismert technikai ütközések

1. **Crown/rotary** (43-as doc §12): a lapozás foglalja a forgatást mindkét platformon — ezért nincs reps-stepper az F6a-ban (D-F6.8). Ha az F5b feloldja, a standalone log automatikusan örökli. **Az F5b terve megvan:** [48-watch-f5b-set-adjust-plan.md](48-watch-f5b-set-adjust-plan.md) — a feloldás D-F5b.1, és a D-F5b.8 kifejezetten előírja, hogy a stepper-komponens ne kösse magát a remote állapotgéphez, hogy az F6b újraírás nélkül átvehesse.
2. **Wear SUMMARY fázis** (D-F6.7): új fázis a `SessionStateHolder`-ben, amit a `MainActivity` `when (phase)` ága ma kimerítően kezel — a fordító kikényszeríti az új ág megírását, de az `ExerciseService.endExercise` mai „reset → IDLE” útját is át kell vezetni, hogy a phone-mastered vég ne kerüljön véletlenül SUMMARY-ba (v1-ben az ott továbbra sem jelenik meg).
3. **`didReceiveUserInfo` típusszétválasztás** (S6): a mai summary-payload nem hord `type` kulcsot — a szétválasztás a kulcs **hiányára** épül, ezért a summary-payloadot nem szabad utólag `type`-pal ellátni anélkül, hogy a régi watch-buildekkel való kompatibilitást átgondolnánk.

---

## 15. Élő tükrözés a telefonon (utólagos hibajavítás)

A live bridging watch→telefon fele (adoption-snapshot minden logolt szett után) kész volt, a telefon-oldali **megjelenítés** viszont nem követte: a `LogSessionScreen` a `_blocks`-ot egyetlen alkalommal, `initState`-ben építi fel a DB-sorból, és semmi nem olvasta újra. A tünetek, amiket a fejlesztő jelzett:

1. Órán indított edzés közben logolt szettek **nem jelentek meg** a telefonon — a `StandaloneSessionProcessor` végig frissítette a sort, csak a nyitott képernyő mutatta a fagyott, adopció-pillanatbeli másolatot.
2. Az órán lezárt edzés után a telefon **nyitva maradt** a már befejezett sessionön: a standalone vég nem `endRequested`-et küld (azt csak a phone-mastered ág használja), hanem a záró `standaloneSession` payloadot, amit a képernyő addig egyáltalán nem figyelt.
3. A sima „+1" tapre logolt szett **0 kg-mal** mentődött, mert csak az F5b stepper küld súlyt, és az `exercise_sets.weight` NOT NULL.

**A javítás:**

- **`LogSessionScreen.watchMastered`** (új konstruktor-flag) + `_startWatchMirror()`: a képernyő „tükör-módba" kapcsol, és a `workoutSessionControllerProvider`-re iratkozik fel (`ref.listenManual`), nem magára a watch-eseményre — a DB-írás a `WorkoutResumePrompt` saját listenerében, aszinkron történik ugyanazon a broadcast streamen, tehát az eseményre reagálva versenyeznénk vele. A flaget az adopciós push adja meg (`workout_resume_prompt.dart`), de bármelyik ide illő watch-esemény (`WatchStandaloneAdoption` / `WatchStandaloneSession`) is bekapcsolja — így hidegindítás után is önmagát javítja, legkésőbb a következő szettnél.
- **Teljes csere, nem merge** (`_rebuildBlocks`, kiemelve az `initState`-ből): a watch a teljes szettlistát küldi újra minden alkalommal, tehát ezen az oldalon nincs mit megőrizni vele szemben.
- **`_closeFromWatchMirror`**: `finishedAt`-et látva leállítja a tickereket/zenét/értesítést és kilép — de **nem ír** (a záró payload feldolgozása már megírta a sort, rpe-vel és health-id-vel együtt), és **nem küld `endWorkout`-ot** az órára (az óra magától zárt).
- **Nincs `startWorkout`/`updateState` push tükrözött sessionre**: az óra épp ezt az edzést futtatja. Ehhez tartozik a Wear-oldali `PhoneListenerService` javítása is: a `start` üzenetet csak akkor utasítja el `startRejected`-del, ha **más** `sessionClientId`-re jön — a saját standalone sessionjének id-jével érkező start a telefon adoptált tükrének a bejelentkezése, nem ütközés (a watchOS `applyStateUpdate` már eleve így különböztette meg).
- **Súly-visszaesés `StandaloneSessionProcessor._resolveWeights`-ben**, a telefon saját „+1" prefill-szabályát tükrözve (`LogSessionScreen._handleAddSet`): (1) az adott gyakorlat előző edzésének pozíció szerinti szettje, (2) különben az ebben a sessionben korábban logolt súly továbbvitele, (3) és csak végső esetben 0 (testsúlyos). A stepperrel megadott súlyt (a szándékos 0-t is) soha nem írja felül. Az `excludeSessionClientId` maga a tükör-sor, hogy egy adoption-újraküldés ne a saját korábbi becslését olvassa vissza „előzményként".

---

## 16. Kézi „szinkronizáld a telefonra" gomb (utólagos fejlesztés)

**A kért funkció:** ha az órán indított edzés mellett nem fut/nem futott a telefonos app, legyen egy gomb, ami újrapróbálja a szinkront — elindítja az edzést a telefonon és átküldi a **már logolt szetteket** is.

**A gomb:** maga a standalone-badge (`iphone.slash` / `PhonelinkOff`) lett kattinthatóvá téve a `HeaderChip`-ben, mindkét platformon. Az az ikon pontosan azt az állapotot jelzi, amin a felhasználó változtatni akar („ennek az edzésnek nincs telefon mögötte"), így külön kontrollt keresgélni felesleges munka lenne. Tapra rövid „sync" glyph a visszajelzés; a *tényleges* siker az, hogy a badge **eltűnik** (a telefon `adoptionAck`-ja átbillenti az `isAdopted`-et). A tap-célpont ki van párnázva, mert a glyph maga csak 14–16 dp/pt.

Új payload nem kell hozzá: az adoption-snapshot amúgy is viszi a session id-t, a kezdés idejét és az **összes eddig logolt szettet**, tehát egyetlen tap után a `StandaloneSessionProcessor.processAdoption` létrehozza az élő tükör-sort és feltölti a szetteket.

**Ehhez két iOS-specifikus hibát is javítani kellett** — a gomb enélkül pont a saját use case-ében nem csinált volna semmit (Androidon mindkettő eleve rendben volt):

1. **`sendAdoptionRequestIfNeeded()` reachability-kapuja.** A `WCSession.isReachable` pontosan akkor hamis, amikor a telefonos app nem fut — vagyis a kapu abban a helyzetben tiltotta a küldést, amiért ez a gomb létezik. A kézi út (`WorkoutManager.retryAdoption()`) ezért **nincs** rá kapuzva: a mögötte lévő `transferUserInfo` sorba állított kézbesítés, túléli a másik app bezártságát. Az automatikus triggerek viszont maradnak kapuzva — enélkül minden logolt szett után egy elavuló snapshot állna sorba egy esetleg kikapcsolt telefonnak.
2. **A telefon-oldali `didReceiveUserInfo` eldobta a payloadot, ha a Dart még nem figyelt.** A `transferUserInfo` háttér-indítással is megérkezhet, jóval azelőtt, hogy a Flutter felcsatolta volna az `EventChannel`-t — az `eventSink?(…)` ilyenkor némán elnyelte. Új `Runner/WatchEventBuffer.swift` (UserDefaults, mert a háttér-indítást az OS le is lőheti, mielőtt a Dart egyáltalán futna) puffereli, a `WatchBridge.onListen` pedig lecsapolja. Ez pontosan az a minta, ami Androidon a `WatchSummaryBuffer`/`WatchStandaloneSessionBuffer`/`WatchAdoptionBuffer` hármassal **eddig is megvolt** — tehát platform-eltérést zár be, nem új mechanizmust vezet be. Egy tárolóval, mert a pufferelt dictionary-k maguk hordozzák a `type` kulcsot és változatlanul mennek tovább.
