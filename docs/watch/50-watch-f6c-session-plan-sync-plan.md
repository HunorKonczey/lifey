# 50 – F6c terv: a session élő gyakorlatlistája az órán

Státusz: **kód kész (2026-08-05), eszközös végpróba hátravan.** Két lépésben: az id-alapú session-terv (§1–§5), majd a rá épülő **gyakorlat-választó a telefonról indított edzésben** is (§6). `flutter test` 508 zöld, `flutter analyze` tiszta, `:app:` + `:wear:compileDebugKotlin` és a teljes `LifeyWatch` típusellenőrzés hibátlan.

Kapcsolódó dokumentumok:
- [49-watch-f6b-template-sync-plan.md](49-watch-f6b-template-sync-plan.md) — a template-sync és a gyakorlat-lista (§3.5, D-F6b.8), plusz az „Utólagos kiegészítés: gyakorlat-lista és a telefonon szerkesztett terv" szakasz, ami az F6c előtti félmegoldást (elrejtés) írja le.
- [44-watch-f6-standalone-plan.md](44-watch-f6-standalone-plan.md) — §4.1: a standalone protokoll, azaz a régi, pozíció-alapú index-tér.
- [48-watch-f5b-set-adjust-plan.md](48-watch-f5b-set-adjust-plan.md) — a prefill, ami szintén gyakorlathoz kötött.

---

## 1. A probléma

**A bejelentés:** „ha az edzésen (a telefonon) törlök vagy hozzáadok egy gyakorlatot, az órán a gyakorlat-listában a hozzáadott nem jelenik meg, a törölt pedig nem tűnik el."

Ez órán indított (standalone, telefon által adoptált) sessionre vonatkozik — telefon-mesterelt edzésnél az óra nem választ gyakorlatot, azt a telefon dönti el.

**A törölt eltüntetését** a 49-doc utólagos kiegészítése már megoldotta (a telefon pozíciónként jelzi, mit törölt; az óra kihagyja őket). **A hozzáadott gyakorlat** viszont nem volt hova tenni, és ez a terv erről szól.

### Miért nem volt hova tenni: az index-tér

A watch → telefon protokoll a gyakorlatot **pozícióval** azonosította: `sets[].exerciseIndex`, `currentExerciseIndex`, és telefon → watch irányban `setsDoneExerciseIndex`, `setsDonePerExercise`, `removedExerciseIndexes`. A pozíciók jelentését a **szinkronizált template** adta (`StandaloneSessionProcessor._resolveExercisesAndSets`: `template.exercises[index]`). Ebből következett minden korlát:

1. a sessionhöz utólag adott gyakorlatnak **nincs pozíciója** a tervben — egy kitalált index a feldolgozóban csendben a generikus „Quick strength" gyakorlatra esett volna (rossz attribúció, észrevétlenül);
2. a pozíciókat **nem lehet átszámozni**, mert a már logolt szettek a régi pozíciót hordozzák.

---

## 2. A megoldás: azonosító, nem pozíció

**D-F6c.1 — Az index-tér a session terve, ne a template.** A telefon minden state-syncben kiküldi a session **saját** gyakorlatlistáját; az óra ezt használja a cache-elt template helyett, amint megérkezett.

**D-F6c.2 — A gyakorlatot `exerciseId` azonosítja, nem a pozíciója.** *(Ez váltja ki a terv első változatának átszámozás + `planVersion` gépezetét — lásd §5.)* Az `exerciseId` (az exercise `clientId`-ja) **eddig is ott volt** a template-sync payloadban, csak a watch sosem küldte vissza (49-doc §4.1: „a watch csak az indexet küldi"). Mostantól:

- minden logolt szett viszi a saját `exerciseId`-ját (`sets[].exerciseId`), a `exerciseIndex` mellett;
- az adoption-snapshot viszi a `currentExerciseId`-t a `currentExerciseIndex` mellett;
- a telefon a `setsDoneExerciseId`-t küldi a `setsDoneExerciseIndex` mellett;
- a feldolgozó **az id-t oldja fel először**, és csak azután esik vissza a pozícióra.

Ettől a lista bármikor változhat: egy pozíció azt jelenti, amit az *aktuális* lista mond, egy id viszont ugyanazt a gyakorlatot örökre. Így **nincs szükség sem a már logolt szettek átszámozására, sem a payload verziózására** — a terv legkockázatosabbnak jelölt része egyszerűen megszűnt.

**D-F6c.3 — Egy dolgot mégis át kell képezni: azt, hogy épp melyik gyakorlaton áll az óra.** Az a mező pozíció (a UI-nak az kell), tehát új lista érkezésekor az óra megkeresi a *korábbi* gyakorlat id-jét az új listában, és arra állítja az indexet. Ha az a gyakorlat már nincs a listában (a telefonon törölték), az első befejezetlenre lép — ugyanoda, ahova minden más automatikus léptetés.

**D-F6c.4 — A payload JSON-string a state-en belül.** A session-terv a state-sync payload `sessionPlan` mezőjében utazik, **JSON stringként**: a Wear DataItem-transport (`WatchBridge.kt` `toDataMap()`) csak lapos skalárokat és int-listákat visz, egy string viszont minden úton (message, DataItem, iOS applicationContext) változatlanul átmegy — és mindkét óra-app amúgy is dekódol már template-JSON-t.

**D-F6c.5 — Visszafelé kompatibilitás mindkét irányban.** Régi óra + új telefon: az óra nem ismeri a `sessionPlan`-t, marad a template-listánál, és pozíciót küld vissza — a telefon az id hiányában a régi úton old fel. Új óra + régi telefon: nem jön `sessionPlan`, az óra a cache-elt templatet használja. Mindkettő a mai kódútra esik vissza, tehát a két app külön szállítható.

---

## 3. Mi hova került

### Telefon (Dart)

| Fájl | Változás |
|---|---|
| `presentation/watch_session_plan.dart` | **új** — `buildWatchSessionPlanJson`: a session gyakorlatai (`exerciseId`, név, `restSeconds`, `targetSets` = az **élő** sorszám, `setsDone`, `previousSets`) |
| `workout_session_notifier_service.dart` | `WorkoutSessionState.sessionPlan` + `setsDoneExerciseId` |
| `log_session_screen.dart` | a két mező kitöltése; `_watchCurrentExerciseClientId` az adoptionből; `watchCurrentBlock` id-vel |
| `watch_set_log_decision.dart` | `watchCurrentBlock(..., currentExerciseClientId:)` — az id nyer, a template nem is kell hozzá |
| `watch_workout_service.dart` | `WatchStandaloneSet.exerciseId`, `WatchStandaloneAdoption.currentExerciseId` |
| `standalone_session_processor.dart` | a szett gyakorlatát **id-ből** oldja fel (a helyi `exercises` táblához ellenőrizve), különben index, különben generikus; terv nélküli sessionben a felismert id-kból áll a gyakorlatlista |
| `exercise_repository.dart` | `existingClientIds` — a dangling id kiszűrése |
| `WatchBridge.kt` (telefon) | az új kulcsok továbbadása — **és a `currentExerciseIndex`, amit eddig egyáltalán nem adott tovább** (F6b-óta meglévő, csendes Android-hiba) |

### Óra (mindkét platform, tükrözve)

- `sessionPlanExercises` + `activePlanExercises` (= a telefon terve, különben a cache-elt template). **Minden** „melyik gyakorlat" döntés ezt olvassa: aktuális gyakorlat, készültség, automatikus léptetés, pihenőidő, prefill, lista-UI.
- `standaloneCurrentExerciseId`, és minden kimenő payload viszi (`sets[].exerciseId`, `currentExerciseId`).
- Szett-számlálás id-alapon, a pozíció csak tartalék (egy pre-F6c szettnek nincs id-ja).
- A telefon szettszáma id szerint párosítva (`phoneSetsExerciseId`); a pozíció-alapú `setsDonePerExercise`/`removedExerciseIndexes` **csak a template-módban** él — terv mellett azok a pozíciók már mást jelentenének.
- Új terv érkezésekor `applySessionPlan` képezi át az aktuális gyakorlatot (D-F6c.3).
- A recovery-snapshot round-trippeli a tervet és a szettek id-ját, különben egy folyamathalál után egy terv-pozíciót template-pozícióként olvasnánk vissza.
- A „Gyakorlatok" chip mostantól akkor is látszik, ha egy Quick strength sessionhöz a telefonon adtak gyakorlatot (egy elemnél többre).

---

## 4. Hibautak és edge case-ek

| # | Eset | Viselkedés |
|---|---|---|
| 4.1 | A telefonon törölt gyakorlaton áll az óra | A következő state-sync az első befejezetlenre lépteti (D-F6c.3); a kézi választás „ragadóssága" erre nem érvényes |
| 4.2 | Olyan gyakorlatot törölnek, amibe az óra már logolt | A szettek megmaradnak (a merge nem dob el logolt adatot), és velük a gyakorlat is visszakerül a session tervébe — a törlés ilyenkor nem érvényesül, ez tudatos (49-doc) |
| 4.3 | Az `exerciseId`-hoz tartozó gyakorlatot azóta törölték a telefonon | A feldolgozó nem bízik benne (`existingClientIds`), és a pozícióra, majd a generikusra esik vissza |
| 4.4 | A telefon nincs hatótávon | Nem jön új terv; az óra a legutóbb kapotton (vagy a cache-elt templaten) dolgozik tovább, és id-vel logol — a szettek attribúciója így is pontos marad |
| 4.5 | Folyamathalál az órán | A snapshot visszahozza a tervet, az indexet és a szettek id-ját |
| 4.6 | Quick strength session, amihez a telefonon adnak gyakorlatot | Megjelenik a listában és logolható — korábban nem létezett ilyen út |

---

## 5. Amit a terv első változatához képest **nem** csináltunk

Az eredeti terv `planVersion`-t és a már logolt szettek átszámozását írta elő (régi D-F6c.2/D-F6c.3). Egyikre sincs szükség: ha a szett a saját `exerciseId`-ját viszi, akkor nincs olyan pillanat, amikor egy régi listával küldött szettet egy új listával kellene értelmezni — épp azt a versenyhelyzetet szünteti meg, amiért a verziózás kellett volna. Az `exerciseId` ráadásul már ott volt a template-sync payloadban (49-doc §4.1 kifejezetten jegyzi, hogy „egy jövőbeli változás kulcsolhat rá"), tehát az óra oldalán nem kellett új adat.

## 6. Gyakorlat-választó a **telefonról indított** edzésben is

**A bejelentés:** „a gyakorlat-lista csak akkor van ott, ha óráról indítom az edzést; ha telefonról, akkor nem látszik az órán." Plusz: „a fő képernyőn van egy gyakorlat-név és szett-számláló — arra lépve is nyíljon meg a gyakorlat-oldal."

A 49-doc kifejezetten úgy zárta le, hogy a lista „továbbra is csak terv-alapú standalone sessionben látszik (quick strength és phone-mastered esetben nincs mire váltani)" — ez telefon-mesterelt edzésnél azért volt igaz, mert a watch csak egy néma „+1" eseményt küldött, a sort pedig a telefon választotta ki. **Az F6c id-alapú attribúciója után viszont van mire váltani**, mert az óra meg tudja nevezni a gyakorlatot.

Ami ehhez bekerült:

- **A session-terv minden edzéshez kimegy**, nem csak a watch-mesteresekhez (`_watchSessionPlan` gate megszűnt) — ez a lista, amit az óra mutat.
- **`logSet` + `exerciseId`**: ha az óra saját listájából választottak, a tap megnevezi a gyakorlatot. A telefon ezt a blokkot célozza (`selectWatchSetLogTargetIn`) — **pinnelve**, tehát egy már kész gyakorlatra mutatva új sort fűz hozzá, nem lép át máshova (ugyanaz az elv, mint a prefillnél). Ismeretlen/eltűnt id esetén visszaesik a telefon saját szabályára.
- **Új üzenet: `exerciseSelected`** (watch → telefon, szett nélkül) — a választás azonnal átáll a telefonon is, tehát a következő state-push (gyakorlatnév, szettszám, stepper-prefill) már azt írja le. Elveszhet: a szett úgyis magával viszi az id-t.
- **Az órán** (mindkét platform): `currentExerciseId` = a lokális választás, különben amit a telefon mondott (`setsDoneExerciseId`); a lokális felülírás törlődik, amint a telefon ugyanazt (vagy a felhasználó által azóta a telefonon választott másikat) visszaigazolja. Választáskor a telefon prefillje eldobódik, hogy a stepper ne a régi gyakorlat számaival nyíljon.
- **A chip** ott van, ahol van miből választani (`canChooseExercise`: egynél több gyakorlat a listában, vagy terv-alapú standalone), és a **metrikák-lap gyakorlat-kártyája / pihenő-hero-ja is megnyitja a listát** — ez az a képernyő, ahol a felhasználó észreveszi, hogy rossz gyakorlaton áll.

**Tesztek:** `decideWatchSetLog` három új ága (választott blokk nyitott sora; kész gyakorlatra új sor; a sessionből eltűnt választás visszaesése). `flutter test` 508 zöld.

---

## 7. Amit ez a terv **nem** old meg

- A gyakorlatok **sorrendjének** átrendezése a telefonon: az id-alapú attribúció bírná, de a telefon UI-ja ma nem kínálja.
- Eszközös végpróba (mindkét platform): hozzáadás/törlés a telefonon futó edzés közben, kézi váltás az órán **mindkét indítási módban**, a metrikák-lapról nyitott lista, offline óra, régi/új build párosítás.
