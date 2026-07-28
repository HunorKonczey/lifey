# 49 – F6b terv: Edzésterv-szinkron a watchra

Státusz: **tervezés — kódolás nem indult.** Az F6a (44-doc) mindkét platformon kódszinten kész (S1–S17), az élő kézi végpróba (S18) és a közös zárás (S19) még nyitott. Az F6b **T5/T6/T7** lépései emiatt, és egy külön ok miatt is (D-F6b.8), **blokkoltak** — lásd §11.

Kapcsolódó dokumentumok:
- [44-watch-f6-standalone-plan.md](44-watch-f6-standalone-plan.md) — az F6a terv és megvalósítás; ennek §13-a adta az eredeti, vázlatos T1–T6 listát, amit ez a doc pontosít és bővít. A D-F6.1–D-F6.9 alapdöntések (watch = mester standalone alatt, a séma nem bővül új mezővel, stb.) **változatlanul érvényesek** F6b-re is.
- [48-watch-f5b-set-adjust-plan.md](48-watch-f5b-set-adjust-plan.md) — a reps/súly stepper terve; a D-F5b.8 kifejezetten **F6b-re készítve** hagyja nyitva a stepper-komponenst (paraméterezhető kezdőérték, remote állapotgéptől független). Az F6b **T7** lépése ettől függ.
- `docs/watch/design/Lifey Watch Design.dc.html` — a legmagasabb kirajzolt frame **AW 15 / W 14** (F6a summary); **F6b-specifikus frame nincs** — sem a picker feltöltött állapotára, sem a gyakorlat-léptetésre. Lásd §0.
- [43-watch-f5-set-logging-plan.md](43-watch-f5-set-logging-plan.md) — a log-protokoll, amit az F6b is újrahasznosít (`exerciseIndex` mező már F6a óta a payloadban van, F6a-ban mindig `null`).

---

## 0. Design-lefedettség — a hiány pontos határa

Amit a canvas **megad**, és az F6a doc (0.2, §8) már rögzített:

| # | Design-elem | Frame | Következmény F6b-re |
|---|---|---|---|
| 0.1 | A picker kiemelt „Quick strength” kártyája + alatta **max 5 terv** sor, cím + gyakorlatszám | AW 13 / W 12 | A picker-feltöltés (T4) elrendezése ebből következik: quick-start mindig legfelül, utána a szinkronizált sorok, a `standalone_empty_hint` csak akkor látszik, ha a lista tényleg üres |
| 0.2 | `standalone_plan_exercises` kulcs (`„%1$d gyakorlat”`) | string-tábla | Már megvan az F6a S1-ből (44-doc §5) — F6b-nek nem kell új kulcs a sorhoz |
| 0.3 | A cache üres/elavult esetén az F6a-váz (csak quick-strength) | AW 13 kis variáns | Ez a **fallback**, nem a T4 fő útja — a picker-kódnak mindkét ágat kezelnie kell, de a design csak az üres ágat rajzolta le explicit módon |

Amit a canvas **nem ad meg**, és ennek a tervnek kell eldöntenie vagy blokkolt kérdésként jeleznie:

| # | Hiány | Hol |
|---|---|---|
| 0.4 | Hogyan mutat egy **kiválasztott, elindított** terv az aktív képernyőn (gyakorlat 1/4, léptetés) | **Nincs frame.** Legközelebbi rokon: a phone-mastered aktív képernyő (`ExerciseCard`/`setsDone/setsTotal`), de az egy **fixen egy gyakorlatra** épül, nem tervezett-sorozatra |
| 0.5 | Hogyan lép a user a következő gyakorlatra a terven belül | **Nincs frame, nincs szöveges specifikáció sem.** D-F6b.8 — blokkoló |
| 0.6 | A reps/súly stepper standalone alatt (a template `targetSets`-je hogyan jelenik meg induláskor) | A 48-doc AW 10/W 09 frame-je erre épült, de az **F5b remote útra** van rajzolva, nem standalone-ra — a canvas ott sem különbözteti meg a kettőt |

**Következmény**: a T1–T4 lépések (szerializáció, push, natív átvitel, picker-feltöltés) a meglévő design-jegyzetekből levezethetők és blokkolás nélkül indíthatók. A **T5 (gyakorlat-léptetés)** viszont designer-bevonást igényel, mielőtt kódolható — ugyanaz a helyzet, mint a 48-doc D-F5b.1-nél volt a crown/rotary-ütközésnél, csak itt a hiány nagyobb (nincs *semmilyen* rajzolt válasz, nem csak egy ütköző részlet).

---

## 1. Cél és scope

**Cél:** amikor a user az órán **„Quick strength” helyett egy konkrét, a telefonon összeállított tervet** akar elindítani telefon nélkül, a legutóbbi néhány terve elérhető legyen a pickeren, és a session a terv gyakorlatait/cél-szettjeit kövesse — ugyanúgy lezártan szinkronizálva a telefonra, mint az F6a Quick strength sessionje.

### V1 scope (F6b)

1. **Template-szinkron**: a telefon a legutóbbi (max 5) terv egy tömörített másolatát pusholja a watchra — gyakorlatnév, cél-szettszám, **resolvált** rest-idő (§2 D-F6b.4).
2. **Picker feltöltése**: a szinkronizált tervek sorai a quick-strength kártya alatt, cím + gyakorlatszám.
3. **Session indítása tervből**: a watch a kiválasztott terv `templateId`-jét és az aktuális `exerciseIndex`-et küldi a payloadban induláskor és minden logolt szettnél.
4. **Telefon-oldali feloldás**: a feldolgozó a `templateId`/`exerciseIndex` alapján **valódi** gyakorlatokat ír be (nem a generikus „Quick strength”-et, D-F6.3 kivétele), és a session `templateClientId`/`templateName` mezőit is kitölti (`WorkoutSessionRepository.create` ezt **már ma is támogatja**, §6).

### V1-ben tudatosan NEM cél (amíg a §0.5 nyitott kérdés nem zárul)

- **Gyakorlat-léptetés UX-e** — ha a designer-döntés (§11/1) sokáig húzódik, a T1–T4 (szinkron + picker) attól még leszállítható: a picker mutatja a tervet, de a „start” egyelőre a régi, egy-gyakorlatos F6a-útra eshet vissza (lásd §11/1 „részleges leszállítás” opció).
- **Reps/súly-előtöltés a template `targetSets`-je alapján** — az F5b stepperje csak a *módosítást* oldja fel, nem a *kezdőérték-becslést* (D-F6b.9); a `targetSets` a szett-**darabszámra** vonatkozik (mikor van kész a gyakorlat), nem az ismétlésszámra.
- **Terv-szerkesztés az óráról** — a watch csak fogyaszt, nem ír vissza tervet.
- **Több mint 5 terv vagy lapozható lista** — ha a picker 5 sornál hosszabb kéne, az külön döntés (a design sem specifikál ennél többet).

---

## 2. Alapdöntések (D-F6b.1 … D-F6b.9)

### D-F6b.1 — A „legutóbbi 5 terv” forrása: session-history, nem template-timestamp

A `WorkoutTemplates` tábla (`lib/core/local_db/tables/workout_template_tables.dart`) **nem visz** `createdAt`/`updatedAt` mezőt — a `WorkoutTemplateRepository.watchAll()` a `name` szerint rendez ábécésorrendben, nem idő szerint. „Legutóbbi” tehát nem a terv létrehozásának/módosításának ideje (ilyen adat nincs), hanem **mikor használta a user legutóbb**.

A `recommended_template_provider.dart` már megold egy rokon feladatot (`predictNextTemplateClientId` — ciklus-detektálás a `sessionsDesc`-ben), de az **egyetlen** javasolt tervet ad vissza, nem egy 5 elemű listát. Az F6b-nek egy **új**, egyszerűbb szelektor kell:

```dart
List<String> recentlyUsedTemplateClientIds(List<WorkoutSession> sessionsDesc, {int max = 5}) {
  final seen = <String>{};
  for (final s in sessionsDesc.where((s) => !s.inProgress)) {
    final id = s.templateClientId;
    if (id != null && seen.add(id)) {
      if (seen.length == max) break;
    }
  }
  return seen.toList();
}
```

— ugyanazt a `workoutSessionControllerProvider`-t olvassa, mint a `recommendedTemplateProvider`, tehát nincs új lekérdezés. **Elfogadott korlátozás**: egy frissen létrehozott, de még **sosem elindított** terv nem kerül be a listába (nincs mihez viszonyítani a „legutóbbi” szót) — ez jegyzendő, de nem blokkoló, mert a Quick strength kártya mindig elérhető marad.

### D-F6b.2 — iOS: `updateApplicationContext` egyetlen globális dict — a state-push és a template-push **nem küldhet külön, egymást felülíró hívást**

Ez a T1–T6 eredeti vázlat („iOS `updateApplicationContext` külön kulccsal”) egy rejtett csapdája. A mai `WatchBridge.swift` `pushContext(...)` **minden hívásnál nulláról épít egy `context` dict-et**, és azt küldi `WCSession.default.updateApplicationContext(context)`-tel:

```swift
private func pushContext(sessionClientId: String, title: String?, startedAtEpochMs: Int64?, state: [String: Any]?, desiredPhase: String) {
  var context: [String: Any] = ["sessionClientId": sessionClientId, "desiredPhase": desiredPhase]
  // ...csak ezek a kulcsok...
  try? WCSession.default.updateApplicationContext(context)
}
```

A `WCSession.applicationContext` **egyetlen, globális** dictionary — a rendszer nem merge-eli az egymást követő hívásokat, a legutóbbi **teljesen felülírja** az előzőt. Ha a `syncTemplates` egy különálló `updateApplicationContext(["templates": …])`-hívást tenne, az **törölné** a futó session állapotát a watch szemszögéből (és fordítva: egy `updateState` hívás menet közben törölné a szinkronizált terveket).

**A döntés:** a `WatchBridge` egy memóriában tartott `private var lastContext: [String: Any] = [:]` mezőt vezet. Minden push (session-state **és** template-sync) ebbe írja bele a saját kulcsait (`context["state"] = …` / `context["templates"] = …`), majd **a teljes, összevont dictionaryt** küldi újra. `pushContext` és az új `pushTemplates` ugyanazt a belső mezőt mutálja, sosem egy lokális, nulláról épített dictet. Ez érdemi, de kis kiterjedésű refaktor a meglévő `pushContext` körül — **T3 első fele**.

### D-F6b.3 — Android: nincs ilyen ütközés — külön `DataItem`-path elég

A `WatchBridge.kt` `pushState(...)` már **path-alapú**: `PutDataMapRequest.create(STATE_PATH)`. A Data Layer minden path-ot **függetlenül** tárol és szinkronizál — egy új `PutDataMapRequest.create(TEMPLATES_PATH)` a state-től teljesen elkülönülve frissül, nincs felülírás-veszély. A konzisztencia kedvéért a D-F6.9 mintáját érdemes követni: **üzenet az elsődleges út** (`MESSAGE_PATH_PREFIX/templateSync`), a `DataItem` csak tartalék az újracsatlakozáskor.

### D-F6b.4 — `restSeconds` forrása: **nem** a template, hanem a gyakorlat (+ user-default)

Az eredeti T1-sor („gyakorlatnév + `targetSets` + `restSeconds`”) pontatlan: a `TemplateExercise` (`domain/workout_template.dart`) **csak** `exerciseClientId` + `targetSets`-et hordoz, `restSeconds` mezője **nincs**. A tényleges forrás — ahogy a telefon-app maga is számolja (`log_session_screen.dart:631`):

```dart
exercisesById[block.exerciseClientId]?.defaultRestSeconds ?? settings.defaultRestSeconds
```

azaz **`Exercise.defaultRestSeconds`** (per-gyakorlat override), ha az null, a **user globális rest-beállítása**. A szerializálónak (T1) ezt **fel kell oldania küldés előtt** — egy join az `Exercise`-ekre és egy `settings`-olvasás —, mert a watch nem ismeri sem az `Exercises` táblát, sem a `UserSettings`-et. A payload tehát **egy konkrét másodperc-számot** visz gyakorlatonként, nem egy nullable mezőt, aminek a watch nem tudná feloldani a defaultját.

### D-F6b.5 — `exerciseIndex` feloldása a feldolgozóban: valódi gyakorlat, nem a generikus „Quick strength”

A 44-doc D-F6.3-ja az F6a-ra ír elő egyetlen generikus gyakorlatot (`ExerciseRepository.getOrCreateByName`, `standalone_session_processor.dart`). F6b-ben, ha a payload `templateId`-t hordoz, a feldolgozónak **más ágon** kell futnia:

1. `WorkoutTemplateRepository.findByClientId(templateId)` — ha `null` (a user törölte a tervet, mióta a watch cache-elte), **fallback a generikus gyakorlatra** (nem hiba — §9/2).
2. Ha megvan, minden logolt szett `exerciseIndex`-ét a `template.exercises[exerciseIndex].exerciseClientId`-re oldja fel; ha az index kiesik a tartományból (a user szerkesztette a tervet — kevesebb gyakorlat maradt), **ugyanaz a fallback**.
3. `WorkoutSessionRepository.create(..., templateClientId: templateId, templateName: <cache-elt cím>, exercises: [...])` — ez a paraméter **már ma is létezik** a repository-n (ellenőrizve, `data/workout_session_repository.dart:171`), F6a-ban egyszerűen nem lett kitöltve.

Ez a döntés **nem bont protokollt és nem bővíti a sémát** — pontosan a D-F6.3 elve szerint jár el, csak a „generikus gyakorlat” ágat egy „valódi, feloldott gyakorlat” ággal egészíti ki.

### D-F6b.6 — Payload-méret: max 5 terv, tervenként max **12** gyakorlat *(nyitott, ökölszabály)*

A Data Layer/`transferUserInfo` limitje (~100 KB) 5 kis terv esetén nem szűk keresztmetszet, de egy elszabadult (50+ gyakorlatos) terv méretét és a picker-lista renderelési költségét érdemes korlátozni. **Nincs adatunk** arra, mennyi gyakorlatos tervek jellemzőek éles használatban — a 12-es szám ökölszabály, mérésre vár (§9). Ha egy terv ennél hosszabb, a **levágott** listát szinkronizáljuk (nem hagyjuk ki az egész tervet), a picker sorában a `standalone_plan_exercises` szám ekkor a **levágott** darabszámot mutatja — ez explicit tesztelendő eset.

### D-F6b.7 — Picker sorrend és megjelenés — a §0/0.1 explicit végrehajtása

Nincs új döntés: a quick-strength kártya marad legfelül (kiemelt háttér), alatta a szinkronizált tervek sora (cím + `standalone_plan_exercises`), a `standalone_empty_hint` csak akkor jelenik meg, ha a cache **valóban** üres (nincs 1 terv sem — akár mert sosem volt szinkron, akár mert a usernek nincs egyetlen terve sem). Az iOS `StandalonePickerView.swift` és az Android `StandalonePickerScreen.kt` **mai kódja** (F6a, S10/S16) ma feltétel nélkül csak a quick-strength kártyát és a hintet rajzolja — T4 ezt egészíti ki egy feltételes lista-szekcióval.

### D-F6b.8 — **Blokkoló**: gyakorlat-léptetés UX-e nincs megtervezve

Lásd §0/0.4–0.5. Ez a terv **nem dönt** helyette — a lehetséges irányok (csak jegyzésképpen, nem javaslatként, mert designer-inputot igényel):

| Opció | Vázlat |
|---|---|
| (a) Automatikus léptetés | A gyakorlat automatikusan lép, amint a `targetSets`-nyi szett meglett rá — a user semmit nem tap-el a léptetéshez, csak logol |
| (b) Kézi „Next exercise” | Külön, explicit gomb/gesztus a log-lapon vagy egy negyedik lapon a pageren |
| (c) Tap a gyakorlat nevén | A meglévő `ExerciseCard`-ra tap léptet — kompakt, de rejtett, hasonló felfedezhetőségi kérdés, mint a 48-doc D-F5b.1-nél a long-pressnél |

Amíg ez nincs eldöntve, a **T5/T6/T7** (léptetés, aktív képernyő terv-tudatos deltái, stepper-bekötés) nem kódolható felelősséggel — lásd §11/1 a részleges-leszállítás opcióért.

### D-F6b.9 — A reps/súly stepper standalone alatt: **csak módosítás, nem becslés** — függ az F5b-től

A 48-doc D-F5b.8 kifejezetten úgy készíti elő az F5b stepper-komponensét, hogy F6b paraméterezve átvehesse (kezdőérték + „confirm” akció paraméterként, nem a remote `logSetState`-hez kötve). Az F6b-nek **nem kell** okosabbnak lennie: a stepper kezdőértéke a D-F6.8 fix defaultja (**reps 10, súly 0**) marad — a „mi volt a múltkori teljesítményed erre a gyakorlatra” **a telefon dolga** (43-doc alapelve: a watch soha nem okosabb a telefonnál), és a watchnak ehhez amúgy sem lenne history-adata. A stepper csak azt oldja fel, hogy a user **helyben módosíthassa** a defaultot, mielőtt logol.

**Függőség**: az F5b ma **S1/14** lépésnél tart (48-doc). A T7 (stepper-bekötés) emiatt **blokkolt**, amíg az F5b natív ágai (S6/S7 iOS, S11/S12 Android) el nem készülnek — de ez **csak T7-et** blokkolja, a T1–T6 F5b nélkül is leszállítható (a szettek F6b-ben is fix `reps=10/weight=0` értékkel logolódnak, amíg a stepper nincs kész).

---

## 3. Watch-oldali munka

### 3.1 Template-cache

Ugyanabban a lokális tárban él, mint a pending-session lista (44-doc §3.2), külön kulcs alatt: watchOS JSON-fájl (`Application Support`), Wear `SharedPreferences` (a `StandaloneSessionStore` mintájára, új `templates` kulccsal, nem új osztállyal — a meglévő store bővül, nem klónozódik). Egy elem:

```json
{
  "templateId": "…",
  "title": "Push day",
  "exercises": [
    { "exerciseId": "…", "name": "Bench Press", "targetSets": 4, "restSeconds": 90 }
  ]
}
```

`exerciseId` az `exerciseClientId` — a watch sosem oldja fel, csak visszaküldi `exerciseIndex`-ként (a tömbön belüli pozíciót, nem az id-t magát — így a payload kicsi marad, egyezik a 44-doc §4.1 eredeti indoklásával).

### 3.2 Picker feltöltése (T4)

A quick-strength kártya alatt, cache-ből olvasva: cím + `standalone_plan_exercises` (`%1$d gyakorlat`, **már létező kulcs**). Tap → a kiválasztott `templateId`-vel indítja a standalone sessiont (§3.3). Üres cache → a mai F6a-váz változatlanul (§0/0.3).

### 3.3 Session indítása tervből (T5, blokkolt §11/1 szerint)

`WorkoutManager.startStandalone()` (iOS) / `startStandaloneExercise()` (Android) **ma paraméter nélküli** — F6b-ben egy `template: CachedTemplate?` paramétert kap. Ha nem `nil`, a session `currentExerciseIndex = 0`-val indul, az aktív képernyő fejléce/`ExerciseCard`-ja a template gyakorlatnevét és `targetSets`/`restSeconds`-át mutatja a fix defaultok helyett. A léptetés maga a §2 D-F6b.8 nyitott kérdése.

### 3.4 Aktív képernyő deltái (T6, blokkolt §11/1 szerint)

A mai F6a-s `freeFormatSets`/`active_sets_free_format` ág (44-doc §3.4, S11/S17) **tervezett** módban visszavált a phone-mastered `setsDone`/`setsTotal` megjelenésre (van cél-szettszám!) — csak a `restSeconds` forrása marad lokális (a szinkronizált érték, nem a phone-mastered rest-sync). Az `ExerciseCard` mindkét platformon **már támogatja** ezt az ágat (`freeFormatSets == null` esetén a `setsDone/setsTotal` utat futtatja) — nincs új komponens, csak új hívási paraméterek.

---

## 4. Protokoll

### 4.1 `templateSync` (telefon → watch) — pontosított séma

```json
{
  "type": "templateSync",
  "syncedAtEpochMs": 0,
  "templates": [
    {
      "templateId": "…",
      "title": "Push day",
      "exercises": [
        { "exerciseId": "…", "name": "Bench Press", "targetSets": 4, "restSeconds": 90 }
      ]
    }
  ]
}
```

Eltérés a 44-doc §4.3 eredeti vázlatától: a `restSeconds` **resolvált** érték (D-F6b.4), nem a template natív mezője (olyan nincs is). `exercises` legfeljebb `12` elem tervenként (D-F6b.6), `templates` legfeljebb `5` elem (D-F6b.1).

### 4.2 `standaloneSessionCompleted` bővítése (watch → telefon)

A 44-doc §4.1 payloadja **változatlan formában** kap valódi értéket: `"templateId"` (F6a-ban mindig `null`, F6b-ben a kiválasztott terv id-je) és `sets[].exerciseIndex` (F6a-ban mindig `null`, F6b-ben a template `exercises` tömbjén belüli pozíció). **Nincs protokoll-bővítés** — a mezők már F6a óta jelen vannak, csak eddig sosem kaptak értéket.

### 4.3 Átvitel

Lásd D-F6b.2 (iOS, context-merge) és D-F6b.3 (Android, külön `DataItem`-path). Push-pontok (T2): app-indulás, terv **mentés, módosítás és törlés** — **az eredeti T1-vázlat nem említette a törlést**, pedig anélkül egy törölt terv örökre a watch cache-ében ragadna; ez a T2 explicit kiegészítése. Kapuzás: a meglévő `watchWorkoutEnabled` kapcsoló (mint minden más watch-forgalom).

---

## 5. Telefon-oldali (Dart) munka

1. **`watch_workout_service.dart`** — `syncTemplates(List<WorkoutTemplate> templates)` (a `startWorkout`/`updateState` mintájára, `_channel.invokeMethod('syncTemplates', {...})`, best-effort try/catch).
2. **Új szerializáló** (`lib/features/workouts/application/watch_template_sync.dart` vagy hasonló) — a D-F6b.1 szelektor + a D-F6b.4 `restSeconds`-resolválás + a D-F6b.6 vágás egy helyen, tesztelhetően (tiszta függvény, `Ref`-mentes, a `StandaloneSessionProcessor` S5-ös mintáját követve).
3. **Push-pontok bekötése** (T2) — app-indulás (a `flushPending`-hez hasonló helyen) + a template-controller mentés/módosítás/**törlés** metódusai után, `watchWorkoutEnabled` kapuval.
4. **`standalone_session_processor.dart` bővítése** (D-F6b.5) — a `templateId`/`exerciseIndex` feloldó ág + a `WorkoutSessionRepository.create`-nek átadott `templateClientId`/`templateName`/`exercises` immár nem mindig a generikus gyakorlatra mutat.

---

## 6. Amit a séma **már ma is** támogat — nincs backend- vagy Drift-változás

Ellenőrizve mindkét érintett repository ellen:

- `WorkoutSessionRepository.create(...)` **már ma is** elfogadja a `templateClientId`, `templateName` és `exercises: List<PlannedExerciseInput>` paramétereket (`data/workout_session_repository.dart:171`) — F6a egyszerűen nem töltötte ki őket.
- `WorkoutSession` domain-modell (`domain/workout_session.dart`) **már ma is** hordozza a `templateClientId`/`templateName` mezőket.
- A `⌚`-badge (B15) és a normál session-nézetek **template-linkelt sessiont már ma is** helyesen renderelnek (ez a normál, telefonon indított „terv szerint edzek” flow-jából jön) — F6b-nek ehhez **semmit nem kell** hozzáadnia az UI-n a telefon oldalán.

Ez érdemben csökkenti az F6b kockázatát: a legnagyobb bizonytalanság (§0/0.4–0.5) **kizárólag a watch-oldali UX-ben** van, a telefon-oldali adatmodell és megjelenítés kész.

---

## 7. Lokalizáció

**Nincs biztosan új kulcs** — a `standalone_plan_exercises` már megvan (44-doc §5, F6a S1). Ha a §11/1 designer-döntés (gyakorlat-léptetés) egy explicit UI-elemet hoz (pl. „Next exercise” gomb), az **akkor** kap saját kulcsot — ezt a T5/T6 lépések vezetik be, nem ez a szakasz.

---

## 8. Tesztelési terv

- **Dart unit**: `recentlyUsedTemplateClientIds` (D-F6b.1: dedup, sorrend, `max`, törölt/soha-nem-használt terv kizárása); a `restSeconds`-resolváló (per-exercise override vs. user-default vs. mindkettő hiánya); a feldolgozó `templateId`/`exerciseIndex` ága (érvényes index, tartományon kívüli index → fallback, törölt template → fallback); `WorkoutSessionRepository.create` a `templateClientId`/`exercises`-szel valóban a helyes gyakorlatokra ír.
- **iOS manuális**: a picker mutatja az 5 legutóbbi tervet a helyes sorrendben; terv-törlés után a watch cache **legfeljebb egy szinkronig** elavult marad, utána eltűnik a sor; egy tervvel indított session a telefonon a **valódi** gyakorlatnevekkel jelenik meg, nem „Gyakorlat”-tal.
- **Wear manuális**: ugyanezek + a D-F6b.2 context-merge tényleges ellenőrzése (egy session **fut**, közben egy template mentés a telefonon **nem** szakítja meg/törli a watch aktív állapotát — ez a legfontosabb regressziós eset, mert épp ez a hiba, amit a D-F6b.2 megelőz).
- **Regresszió**: az F6a Quick strength út (`templateId == null`) **bitre változatlan** — ez a legfontosabb védőháló, mert a T1–T6 mind ugyanazokat a fájlokat érinti, amiket az F6a már leszállított.

---

## 9. Ütemezés, becslés és függőségi gráf

```
T1 (Dart: szerializáció) ─▶ T2 (push-pontok)
                                  │
                    ┌─────────────┴─────────────┐
                    ▼                             ▼
        T3-iOS (context-merge)          T3-Android (DataItem+message)
                    │                             │
                    ▼                             ▼
                 T4-iOS (picker)           T4-Android (picker)
                    │                             │
     ══════════ §11/1 designer-döntés (D-F6b.8) ══════════
                    │                             │
                    ▼                             ▼
              T5/T6-iOS                     T5/T6-Android
                    │                             │
     ══════════ F5b natív ágai készen (48-doc) ══════════
                    │                             │
                    ▼                             ▼
                 T7-iOS                      T7-Android
                    │                             │
                    └─────────────┬───────────────┘
                                   ▼
                          T8 (közös zárás + regresszió)
```

| Ütem | Tartalom | Becslés | Előfeltétel |
|---|---|---|---|
| T1–T4 | Szinkron + picker-feltöltés, mindkét platform | M | F6a S1–S17 (kész) |
| T5–T6 | Léptetés + aktív képernyő terv-tudatos deltái | M | **§11/1 designer-döntés** |
| T7 | Stepper-bekötés standalone módban | S | **F5b natív ágai** (48-doc, ma S1/14) |
| T8 | Közös zárás | S | T1–T7 |

---

## 10. Hibautak és edge case-ek

| # | Eset | Viselkedés |
|---|---|---|
| 10.1 | A user törli a tervet a telefonon, miközben a watch cache-ében még ott van | A picker sora **legfeljebb egy szinkronig** (a következő T2 push-pontig) marad látható; ha a user mégis elindítja, a feldolgozó a D-F6b.5 fallback-jét futtatja (generikus gyakorlat) — nem hiba |
| 10.2 | A terv `exercises`-listája rövidebb lett, mint a watch cache-elt `exerciseIndex`-e | Ugyanaz a fallback (D-F6b.5) |
| 10.3 | A watchWorkoutEnabled kapu menet közben kikapcsolódik | A már cache-elt tervek a watchon maradnak (nincs "töröld a cache-t" push), de új szinkron nem megy ki — megegyezik a mai state-sync kapuzás viselkedésével |
| 10.4 | A terv gyakorlatszáma > 12 (D-F6b.6) | Levágott lista szinkronizálódik, a picker sora a levágott számot mutatja |
| 10.5 | Session fut standalone-ban, közben a telefon egy `templateSync`-et pushol | D-F6b.2 miatt **nem** törli a futó session state-jét — ez a legfontosabb regressziós teszt (§8) |

---

## 11. Nyitott kérdések (rangsorolva)

1. **[BLOKKOLÓ]** Gyakorlat-léptetés UX-e (D-F6b.8, §0/0.4–0.5) — designer-döntés kell, mielőtt T5/T6/T7 kódolható. **Részleges leszállítási opció**, ha ez sokáig húzódik: T1–T4 (szinkron + picker) önmagában is értéket ad — a picker mutatja a tervet, de a tényleges indítás egyelőre visszaesik az F6a egy-gyakorlatos útjára (a `templateId` bekerül a payloadba `informational`-ként, a session mégis a generikus gyakorlatra íródik) — ez a doc **nem javasolja** alapesetként, csak jegyzi mint vészmegoldást, ha a scope nyomás alá kerül.
2. **[NEM BLOKKOLÓ]** D-F6b.6 tervenkénti gyakorlat-limit (12) — ökölszabály, valós adat nélkül; mérésre/hangolásra vár, ha a T1 implementáció közben kiderül, hogy a jellemző tervek ennél hosszabbak.
3. **[NEM BLOKKOLÓ, F5b-függő]** T7 (stepper) csak azután indítható, hogy az F5b natív ágai (48-doc S6/S7 iOS, S11/S12 Android) elkészültek.
4. **[NEM BLOKKOLÓ]** A picker 5-ös limitje bővíthető-e/legyen-e lapozható — a design nem specifikál ennél többet, tehát V1-ben nem téma, csak ha a használat mást mutat.

---

## 12. Fejlesztési lépések (T1–T8)

*(Részletes S-szintű bontás — a 44-doc §12 és a 48-doc §13 mintájára — csak azután íródik meg, hogy a §11/1 designer-döntés megszületett; addig a fenti T-szintű bontás a mérvadó munkaegység.)*
