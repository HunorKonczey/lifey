# 49 – F6b terv: Edzésterv-szinkron a watchra

Státusz: **LEZÁRVA, 2026-07-30 (T1–T8).** A teljes F6b funkcionalitás megvalósult mindkét platformon: terv-szinkron → picker → session indítása tervből → aktív képernyő terv-tudatos deltái → gyakorlat-lista váltással. Az élő kézi végpróbát (§8, T8) a user elvégezte fizikai eszközön — **a teszt hibákat talált**, ezek javítása **egy külön beszélgetésben** folyik, ennek a doknak a lépésein már kívül. `docs/watch/40-watch-app-plan.md` F6b-sora ennek megfelelően frissítve.

> **Terv-revízió, 2026-07-29 — nincs több blokkoló.** A korábbi verzió két külső függőségen állt: a gyakorlat-váltás UX-e designer-döntésre várt, a stepper-bekötés pedig az F5b-re. Mindkettő lezárva: a **D-F6b.8** eldönti a gyakorlat-váltást (`ControlsPage` → gyakorlat-lista, közvetlen ugrással) — nem ízlés-kérdésként, hanem mert a gesztus-készlet foglaltsága és három korábbi, eszközön ellenőrzött döntés egyetlen épkézláb helyre szűkítette; a **D-F6b.9** pedig **kiveszi a steppert az F6b scope-jából**, hogy egy önmagában teljes funkció ne egy független terv ütemezésén üljön (a folytatás helye a 48-doc S14). Emellett kiderült, hogy a **telefon-oldali feldolgozó kimaradt a T-listából** — saját tervezési hiba, most **T5** lett belőle, és szándékosan a watch-lépések elé került (a fogadó előbb kész, mint a küldő). Részletek: §9 és §11.

Az F6a (44-doc) mindkét platformon **teljesen kész**, beleértve az élő kézi végpróbát (S18) is — 40-doc, 2026-07-26.

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

Amit a canvas **nem ad meg** — mindhármat **ez a terv dönti el** (2026-07-29), designer-review-ra érdemesen, de nem blokkolóként:

| # | Hiány | Hol |
|---|---|---|
| 0.4 | Hogyan mutat egy **kiválasztott, elindított** terv az aktív képernyőn (gyakorlat 1/4, léptetés) | **Nincs frame.** Legközelebbi rokon: a phone-mastered aktív képernyő (`ExerciseCard`/`setsDone/setsTotal`) — **ezt vesszük át változatlanul** (§3.4), tehát a hiány nem igényel új vizuális nyelvet |
| 0.5 | Hogyan lép a user a következő gyakorlatra a terven belül | **Nincs frame, nincs szöveges specifikáció sem** — **ezt a terv dönti el** (D-F6b.8): `ControlsPage` → gyakorlat-lista, a T4-ben már megépített picker-alakot újrahasználva. Designer-review-ra érdemes, de **nem blokkol** |
| 0.6 | A reps/súly stepper standalone alatt (a template `targetSets`-je hogyan jelenik meg induláskor) | **Tárgytalan** — a stepper kikerült az F6b scope-jából (D-F6b.9); a 48-doc AW 10/W 09 frame-je az F5b remote útra vonatkozik |

**Következmény**: a T1–T4 lépések (szerializáció, push, natív átvitel, picker-feltöltés) a meglévő design-jegyzetekből levezethetők és blokkolás nélkül indíthatók. A **T5 (gyakorlat-léptetés)** viszont designer-bevonást igényel, mielőtt kódolható — ugyanaz a helyzet, mint a 48-doc D-F5b.1-nél volt a crown/rotary-ütközésnél, csak itt a hiány nagyobb (nincs *semmilyen* rajzolt válasz, nem csak egy ütköző részlet).

---

## 1. Cél és scope

**Cél:** amikor a user az órán **„Quick strength” helyett egy konkrét, a telefonon összeállított tervet** akar elindítani telefon nélkül, a legutóbbi néhány terve elérhető legyen a pickeren, és a session a terv gyakorlatait/cél-szettjeit kövesse — ugyanúgy lezártan szinkronizálva a telefonra, mint az F6a Quick strength sessionje.

### V1 scope (F6b)

1. **Template-szinkron**: a telefon a legutóbbi (max 5) terv egy tömörített másolatát pusholja a watchra — gyakorlatnév, cél-szettszám, **resolvált** rest-idő (§2 D-F6b.4).
2. **Picker feltöltése**: a szinkronizált tervek sorai a quick-strength kártya alatt, cím + gyakorlatszám.
3. **Session indítása tervből**: a watch a kiválasztott terv `templateId`-jét és az aktuális `exerciseIndex`-et küldi a payloadban induláskor és minden logolt szettnél.
4. **Gyakorlat-váltás menet közben**: a `ControlsPage`-ről nyíló gyakorlat-lista, közvetlen ugrással bármelyik gyakorlatra (**D-F6b.8**).
5. **Telefon-oldali feloldás**: a feldolgozó a `templateId`/`exerciseIndex` alapján **valódi** gyakorlatokat ír be (nem a generikus „Quick strength”-et, D-F6.3 kivétele), és a session `templateClientId`/`templateName` mezőit is kitölti (`WorkoutSessionRepository.create` ezt **már ma is támogatja**, §6).

### V1-ben tudatosan NEM cél

- **Reps/súly stepper standalone módban** — **kivéve az F6b scope-jából** (D-F6b.9): a szettek itt is fix `reps=10`/`weight=0` értékkel jönnek létre, ahogy az F6a ma is szállítja. A bekötés az F5b befejezése utáni követő-lépés, a 48-doc S14-ében.
- **Automatikus gyakorlat-léptetés** — tudatosan elvetve (D-F6b.8): a `targetSets` nullable, tehát a kiváltó feltétel gyakran nem is létezne, és a néma átbillenés rossz gyakorlatra logolna.
- **Terv-szerkesztés az óráról** — a watch csak fogyaszt, nem ír vissza tervet.
- **Több mint 5 terv** — a design sem specifikál ennél többet; a lista mindkét platformon natívan görgethető, tehát a limit nem UI-korlát, hanem tudatos scope (D-F6b.1).

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

### D-F6b.8 — Gyakorlat-váltás: **explicit lista a ControlsPage-ről**, se automatika, se új gesztus — **eldöntve 2026-07-29**

Korábban ez volt a terv egyetlen blokkolója (designer-inputra várt). **A döntés megszületett** — a canvas nem ad hozzá frame-et (§0/0.4–0.5), de a hiány nem indokolja a leállást: a választást teljes egészében a meglévő, eszközön már bevált F5a/F5b/F6a döntések kényszerítik ki, nem ízlés kérdése. Designer-review-ra érdemes visszatérni, de **nem blokkol**.

**A gesztus-készlet ma teljesen foglalt** — ez zárja ki az elegánsabbnak tűnő utakat:

| Felület | Ki foglalja | Hol dőlt el |
|---|---|---|
| Korong **tap** | szett logolása | F5a §3.1 |
| Korong **long-press** | reps/súly adjust | 48-doc D-F5b.1 (**eszközön ellenőrizve**) |
| Crown / rotary | lapozás a 3 lap között | 48-doc D-F5b.1, §12 |

**A döntés:** a `ControlsPage`-re (3. lap) kerül egy **„Gyakorlatok” vezérlő**, ami egy külön, egyszerű **gyakorlat-listát** nyit; a listában a terv minden gyakorlata egy sor (név + eddigi szettek), tapre az adott gyakorlatra **ugrik** a session, és a nézet bezárul. Nem „Next” léptető: **közvetlen ugrás bármelyik gyakorlatra**.

**Miért ez, és miért nem a másik három:**

1. **(a) automatikus léptetés — elvetve.** Két végzetes hibája van. Egy: a `TemplateExercise.targetSets` **nullable** (`domain/workout_template.dart`), tehát a kiváltó feltétel gyakran nem is létezik — a léptetés némán soha nem történne meg. Kettő: a user szeme előtt **magától** átbillenne a gyakorlat, és a következő tap már a rossz gyakorlatra logolna — pontosan az a „a watch okoskodik és téved" minta, amit a D-F6.8 (fix reps 10 becslés helyett) és a D-F6.9 (üzenet a DataItem helyett) is elutasított.
2. **(b) gomb a log-lapon — elvetve.** Az F5a a log-lapot szándékosan **egyetlen, óriási** tap-targetté tette („5× a 48 px minimum"), és a 48-doc D-F5b.1 az adjust-gombot **kifejezetten emiatt** utasította el ott. Egy harmadik terv nem nyithatja újra ugyanazt a lezárt kérdést.
3. **(b') negyedik pager-lap — elvetve.** A `PAGE_COUNT` feltételessé tétele (3 vagy 4 a módtól függően) index-eltolódási hibák klasszikus forrása, és **a phone-mastered flow lapozását is érintené** — az F6b-nek nulla hatása kell legyen az F0–F5 útra.
4. **(c) tap a gyakorlatnéven — elvetve.** A `MetricsOrRestPage` a kódban is rögzítetten „deliberately button-free" (§12.1 B4/B6 öröksége), plusz rejtett affordancia lenne.

**Miért ugrólista és nem „Next" léptető:** egy „Next" chip egyirányú. Vagy körbe-fordul (a user észrevétlenül visszakerül az 1. gyakorlatra → néma rossz adat), vagy megáll a végén (nincs semmilyen visszaút egy félre-tapolás után). Az ugrólista mindkettőt megoldja, **és** lefedi a valós edzőtermi esetet is: a user nem a terv sorrendjében halad, mert a guggoló-állvány foglalt. Ez nem extra dísz, hanem a funkció lényege. Komponens-kockázat sincs: a lista alakja **pontosan a T4-ben már megépített** `StandalonePickerScreen`/`StandalonePickerView`.

**Ha a user sosem vált:** minden szett a 0. gyakorlatra megy. Ez **kiszámítható és őszinte** — a képernyőn végig az a gyakorlatnév látszik, amire logol; nincs meglepetés, és a telefonon javítható (ugyanaz az elv, mint a D-F6.8 fix repsénél).

### D-F6b.9 — A reps/súly stepper **kikerül az F6b scope-jából** — **eldöntve 2026-07-29**

Korábban ez volt a terv második blokkolója: a T7 (stepper-bekötés standalone módba) arra várt, hogy az F5b natív ágai elkészüljenek. **A döntés: az F6b ezt nem várja meg — a stepper teljesen kikerül ebből a tervből.**

**Indoklás.** Az F5b ma **S1/14** lépésnél tart (48-doc) — a natív ágai (S6/S7 iOS, S11/S12 Android) még hozzá sem kezdtek. Az F6b-t ehhez kötni azt jelentené, hogy egy önmagában teljes, működő és értékes funkció (terv-szinkron + terv szerinti session) egy tőle **független** terv ütemezésén ülne. A két plan összekötése nem tesz semmit stabilabbá, csak a szállítást késlelteti és a hibakeresést nehezíti (egy élő teszt hibájáról nem tudnánk, melyik plan okozta).

**Amit ez a gyakorlatban jelent:** az F6b-ben logolt szettek — pontosan úgy, ahogy az F6a **ma is** szállítja — fix `reps = 10`, `weight = 0` értékkel jönnek létre (D-F6.8), a user a telefonon pontosít. Az F6b **nem ront** ezen semmit, csak nem is javít rajta.

**A folytatás helye:** a 48-doc **D-F5b.8** már ma is kifejezetten úgy készíti elő a stepper-komponenst, hogy a kezdőérték és a „confirm" akció paraméter legyen (ne a remote `logSetState`-hez kötve) — épp azért, hogy a standalone ág **újraírás nélkül** átvehesse. A bekötés így az F5b befejezése után egy kicsi, izolált követő-lépés lesz, **a 48-doc S14-es zárásában** (ami már ma is nevesíti: „Ha az F6b-t elkezdjük: a stepper-komponens átvétele a standalone logba"). Ez a doc onnantól nem tartozik hozzá.

**Ami ettől függetlenül igaz marad:** a stepper kezdőértéke akkor sem lesz „okos" becslés — a `targetSets` a szett-**darabszámra** vonatkozik, nem az ismétlésszámra, és a watchnak nincs history-adata. „Mi volt a múltkori teljesítményed" **a telefon dolga** (43-doc alapelve: a watch soha nem okosabb a telefonnál).

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

### 3.3 Session indítása tervből (T6)

`WorkoutManager.startStandalone()` (iOS) / `startStandaloneExercise()` (Android) **ma paraméter nélküli** — F6b-ben egy `template: CachedTemplate?` (iOS) / `templateJson: String?` (Android, a store nyers-JSON konvenciója szerint) paramétert kap. Ha nem null, a session a terv másolatát és `currentExerciseIndex = 0`-t tart el, az aktív képernyő pedig a template gyakorlatnevét, `targetSets`-ét és `restSeconds`-át mutatja a fix defaultok helyett.

**Fontos: a session a terv egy pillanatképét (snapshot) viszi magával, nem a cache-re mutató hivatkozást.** Ha menet közben új `templateSync` érkezik és felülírja a cache-t, a futó session **nem változhat meg alatta** — a gyakorlatnevek és a `restSeconds` a session teljes hosszán stabilak maradnak. Ez ugyanaz az elv, mint a D-F6.1-é (standalone alatt a watch a mester): a futó session állapotát semmilyen kívülről érkező adat nem írhatja át.

**A `restSeconds` forrása** tervezett módban a snapshot **aktuális gyakorlatának** értéke, nem a fix 90 s (44-doc §3.5) — gyakorlat-váltáskor tehát a következő szett rest-hossza is átvált. A rest-mechanika maga (deadline-mező, GO-flash, haptika) változatlan.

### 3.4 Aktív képernyő deltái (T7)

A mai F6a-s `freeFormatSets`/`active_sets_free_format` ág (44-doc §3.4, S11/S17) **tervezett** módban visszavált a phone-mastered `setsDone`/`setsTotal` megjelenésre (van cél-szettszám!). Az `ExerciseCard` mindkét platformon **már támogatja** ezt az ágat (`freeFormatSets == null` esetén a `setsDone/setsTotal` utat futtatja) — nincs új komponens, csak új hívási paraméterek.

- `setsDone` = az **aktuális** gyakorlatra logolt szettek száma (a `standaloneSets` szűrése `exerciseIndex` szerint), nem az összes.
- `setsTotal` = a snapshot `targetSets`-e. **Ha `null`** (nullable a sémában), a kártya visszaesik az F6a `active_sets_free_format` sorára az adott gyakorlatra — nincs kitalált célszám.
- A `phonelink_off` standalone-glyph (44-doc §3.4) **változatlanul ott marad**: a session akkor is watch-only, ha terv szerint megy.

### 3.5 Gyakorlat-lista (T7, D-F6b.8)

A `ControlsPage`-en az End/Pause pár **alá** kerül egy `standalone_exercise_list_title` feliratú vezérlő (csak tervezett módban látszik; quick-strength sessionben és phone-mastered sessionben nincs ott). Megnyitja a gyakorlat-listát:

- Egy sor a snapshot minden gyakorlatához: **név** + alatta a szett-állás — `active_sets_format` (`n/m szett`), ha van `targetSets`, különben `standalone_exercise_sets_done` (`n szett`).
- Az **aktuális** gyakorlat sora kiemelt (`containerHigh` háttér, ahogy a picker quick-strength kártyája), a többi `surface` — pontosan a T4-es picker vizuális nyelve.
- Tap → a session arra a gyakorlatra ugrik, a nézet bezárul, vissza a `ControlsPage`-re. **Nincs megerősítés** (visszafordítható művelet: a user egy tappal visszaugorhat).
- Vissza-affordancia a `StandalonePickerScreen`/`EffortSelectorScreen` mai top-start nyilával, `effort_selector_back` címkével.

Komponens-szinten ez a **T4-ben már megépített** `StandalonePickerScreen`/`StandalonePickerView` alakja (`ScalingLazyColumn` / lista + sorok), nem új szerkezet.

**Amit a váltás NEM csinál:** nem zár le szettet, nem indít restet, nem módosít visszamenőleg semmit. Csak a *következő* logolás célját változtatja meg. A már logolt szettek `exerciseIndex`-e véglegesen az marad, ami logoláskor aktuális volt.

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

A T1–T4 **egyetlen új kulcsot sem** igényelt: a `standalone_plan_exercises` már megvolt (44-doc §5, F6a S1). A D-F6b.8 gyakorlat-listája **két újat** hoz — ezeket a **T7** vezeti be, mindhárom helyre azonos kulcsnévvel (`values/strings.xml` HU-default, `values-en/strings.xml`, `Localizable.xcstrings`), az F6a S1 mintájára:

| Kulcs | EN | HU | Hol |
|---|---|---|---|
| `standalone_exercise_list_title` | `Exercises` | `Gyakorlatok` | a `ControlsPage` vezérlőjének felirata **és** a lista címe (ugyanaz a szó mindkét helyen — nem érdemes két kulcs) |
| `standalone_exercise_sets_done` | `%1$d sets` | `%1$d szett` | a lista sorának alsorja, ha a gyakorlatnak **nincs** `targetSets`-e |

Újrahasznosított kulcsok, új nélkül: `active_sets_format` (`n/m szett`) a `targetSets`-szel rendelkező sorokhoz, `effort_selector_back` a vissza-nyílhoz (ugyanígy csinálja a mai `StandalonePickerScreen` is).

---

## 8. Tesztelési terv

- **Dart unit**: `recentlyUsedTemplateClientIds` (D-F6b.1: dedup, sorrend, `max`, törölt/soha-nem-használt terv kizárása); a `restSeconds`-resolváló (per-exercise override vs. user-default vs. mindkettő hiánya); a feldolgozó `templateId`/`exerciseIndex` ága (érvényes index, tartományon kívüli index → fallback, törölt template → fallback); `WorkoutSessionRepository.create` a `templateClientId`/`exercises`-szel valóban a helyes gyakorlatokra ír.
- **iOS manuális**: a picker mutatja az 5 legutóbbi tervet a helyes sorrendben; terv-törlés után a watch cache **legfeljebb egy szinkronig** elavult marad, utána eltűnik a sor; egy tervvel indított session a telefonon a **valódi** gyakorlatnevekkel jelenik meg, nem „Gyakorlat”-tal.
- **Wear manuális**: ugyanezek + a D-F6b.2 context-merge tényleges ellenőrzése (egy session **fut**, közben egy template mentés a telefonon **nem** szakítja meg/törli a watch aktív állapotát — ez a legfontosabb regressziós eset, mert épp ez a hiba, amit a D-F6b.2 megelőz).
- **Görgethetőség (minden érintett watch-képernyőn, mindkét platformon)**: a T4.5-ös hibajavítás óta kötelező ellenőrzési pont — **koronával/rotaryval és ujjal is** görgethető-e a picker, a summary, az effort-selector és a T7 gyakorlat-listája, **elegendő tartalommal** (5 szinkronizált terv, ill. 6+ gyakorlatos terv), nem csak az üres/rövid esettel. Ugyanitt: az `ActiveWorkoutView` 3 lapos **lapozása** koronával/rotaryval **változatlanul** működik-e (nem alakult-e görgetéssé).
- **Regresszió**: az F6a Quick strength út (`templateId == null`) **bitre változatlan** — ez a legfontosabb védőháló, mert a T1–T6 mind ugyanazokat a fájlokat érinti, amiket az F6a már leszállított.

---

## 9. Ütemezés, becslés és függőségi gráf

**Nincs több külső blokkoló.** A D-F6b.8 (gyakorlat-váltás) eldőlt, a D-F6b.9 (stepper) kikerült a scope-ból — az F6b innentől **önmagában, végig leszállítható**, egyik lépése sem vár másik tervre vagy külső döntésre.

```
T1 (szerializáció) ─▶ T2 (push-pontok) ─▶ T3 (natív híd) ─▶ T4 (cache + picker)     [KÉSZ]
                                                                    │
                                                                    ▼
                                              T5 (telefon: feldolgozó feloldás)
                                                    ── a fogadó előbb kész, mint a küldő ──
                                                                    │
                                        ┌───────────────────────────┴───────────────────────────┐
                                        ▼                                                       ▼
                             T6-iOS (session tervből)                          T6-Android (session tervből)
                                        │                                                       │
                                        ▼                                                       ▼
                             T7-iOS (aktív képernyő + lista)              T7-Android (aktív képernyő + lista)
                                        │                                                       │
                                        └───────────────────────────┬───────────────────────────┘
                                                                    ▼
                                                     T8 (közös zárás + regresszió)
```

**Az újraszámozás oka (2026-07-29):** a régi terv T7-je a stepper-bekötés volt (törölve, D-F6b.9), a **telefon-oldali feldolgozó viszont kimaradt a T-listából** — a §5/4 leírta, de egyetlen ütemhez sem volt rendelve. Ez saját tervezési hiba volt; most **T5** lett belőle, és **szándékosan a watch-lépések elé** került: így a telefon már akkor helyesen dolgozza fel a terv-attribútumos payloadot, amikor a watch elkezdi küldeni (a fogadó előbb kész, mint a küldő — ugyanaz a sorrendi elv, amit a T3→T4 is követett).

| Ütem | Tartalom | Becslés | Előfeltétel |
|---|---|---|---|
| T1–T4 | Szinkron + natív híd + cache + picker, mindkét platform | M | F6a S1–S17 — **kész, 2026-07-29** |
| T5 | Telefon: `templateId`/`exerciseIndex` feloldás a feldolgozóban + tesztek | S | T1 (a payload-alak) — tiszta Dart, watch nélkül tesztelhető |
| T6 | Watch: session indítása tervből + snapshot + `exerciseIndex` a szetteken | M | T4 (cache), T5 (fogadó kész) |
| T7 | Watch: aktív képernyő terv-tudatos deltái + gyakorlat-lista + 2 új kulcs | M | T6 |
| T8 | Közös zárás + regresszió | S | T5–T7 |

---

## 10. Hibautak és edge case-ek

| # | Eset | Viselkedés |
|---|---|---|
| 10.1 | A user törli a tervet a telefonon, miközben a watch cache-ében még ott van | A picker sora **legfeljebb egy szinkronig** (a következő T2 push-pontig) marad látható; ha a user mégis elindítja, a feldolgozó a D-F6b.5 fallback-jét futtatja (generikus gyakorlat) — nem hiba |
| 10.2 | A terv `exercises`-listája rövidebb lett, mint a watch cache-elt `exerciseIndex`-e | Ugyanaz a fallback (D-F6b.5) |
| 10.3 | A watchWorkoutEnabled kapu menet közben kikapcsolódik | A már cache-elt tervek a watchon maradnak (nincs "töröld a cache-t" push), de új szinkron nem megy ki — megegyezik a mai state-sync kapuzás viselkedésével |
| 10.4 | A terv gyakorlatszáma > 12 (D-F6b.6) | Levágott lista szinkronizálódik, a picker sora a levágott számot mutatja |
| 10.5 | Session fut standalone-ban, közben a telefon egy `templateSync`-et pushol | D-F6b.2 miatt **nem** törli a futó session state-jét — ez a legfontosabb regressziós teszt (§8). Ezen felül a futó session a terv **snapshotján** dolgozik (§3.3), tehát a gyakorlatnevek és rest-idők sem változhatnak meg alatta |
| 10.6 | A user sosem vált gyakorlatot a terven belül | Minden szett a 0. gyakorlatra megy. Kiszámítható és a képernyőn végig látszik; a telefonon javítható (D-F6b.8) |
| 10.7 | A user félretap-ol a gyakorlat-listában | Egy tappal visszaugorhat — a lista közvetlen ugrás, nem egyirányú léptető (D-F6b.8). A **már** logolt szettek `exerciseIndex`-e nem változik visszamenőleg (§3.5) |
| 10.8 | A terv egy gyakorlatának nincs `targetSets`-e | Az aktív kártya az F6a `active_sets_free_format` sorára esik vissza arra a gyakorlatra, a lista sora a `standalone_exercise_sets_done` kulcsot használja — **nincs kitalált célszám** (§3.4, §7) |
| 10.9 | A user a terv utolsó gyakorlatán is túl akar menni | Nincs „vége" állapot: a lista mindig nyitva van, bármelyik gyakorlatra visszaugorhat, és tetszőleges számú extra szettet logolhat bármelyikre. A `targetSets` **cél**, nem korlát |

---

## 11. Nyitott kérdések — **mind lezárva, 2026-07-29**

Blokkoló nem maradt; az F6b végig kódolható. A négy korábbi kérdés sorsa:

1. **Gyakorlat-léptetés UX-e → ELDÖNTVE, lásd D-F6b.8.** `ControlsPage` → gyakorlat-lista, közvetlen ugrással. Nem designer-inputra vártunk a végén: a gesztus-készlet (tap/long-press/crown) teljes foglaltsága és három korábbi, eszközön ellenőrzött döntés (F5a „egy óriási target", 48-doc D-F5b.1, §12.1 B4/B6) gyakorlatilag **egyetlen** épkézláb helyre szűkítette a vezérlőt. A canvas-hiány marad — designer-review-ra érdemes visszatérni, de a döntés áll, és a T4-ben már megépített picker-alakot használja újra, tehát nem hoz új vizuális nyelvet.
   - *Az egykori „részleges leszállítás" vészmegoldás (a `templateId` csak informális, a session mégis a generikus gyakorlatra ír) ezzel **tárgytalan** — nem volt jó opció (a felhasználói érték nagy részét elvesztette volna), és most nincs is rá szükség.*
2. **D-F6b.6 tervenkénti gyakorlat-limit (12) → LEZÁRVA, marad.** A T1.2 implementálta és tesztelte; a vágás nem rejtett, mert a picker `standalone_plan_exercises` száma a **levágott** hosszt mutatja. A payload így is néhány kB (5 terv × max 12 gyakorlat × 4 mező) — nagyságrendekkel a ~100 kB-os Data Layer limit alatt. Csak akkor hangolandó, ha éles használat mást mutat.
3. **Stepper-bekötés → KIVÉVE a scope-ból, lásd D-F6b.9.** Az F6b nem vár az F5b-re; a folytatás helye a 48-doc S14.
4. **Picker 5-ös limitje / lapozhatóság → LEZÁRVA, nem probléma.** Mindkét platform listája natívan görgethető (`ScalingLazyColumn`, ill. a watchOS lista) — a T4 implementációja ezt már bizonyította. Az 5-ös szám tudatos scope-döntés (D-F6b.1), nem UI-korlát.

**Ami tudatosan vállalt maradék-kockázat** (nem nyitott kérdés, hanem elfogadott viselkedés):

- Ha a user sosem vált gyakorlatot, minden szett a terv 0. gyakorlatára megy — kiszámítható, a képernyőn végig látszik, telefonon javítható (D-F6b.8).
- A szettek `reps=10`/`weight=0` értékkel jönnek létre, amíg az F5b stepper-bekötése meg nem történik (D-F6b.9, D-F6.8).
- A picker és a gyakorlat-lista is **pillanatkép**, nem élőben figyelt adat (T4.2/T4.4 döntése, ill. §3.3 snapshot-elve).

---

## 12. Fejlesztési lépések

Minden lépés önmagában fordul, tesztelhető, és nem töri a meglévő F6a-viselkedést — a 44-doc §12 és a 48-doc §13 mintájára. A **T1–T4** iterációkra bontva (és kész); a **T5–T8** lépés-szinten van leírva, iterációkra akkor bontható, amikor sorra kerül (a T1–T4 tapasztalata szerint a bontás pontosabb lesz, ha közvetlenül a megvalósítás előtt készül — a T2 reaktív megközelítése és a T4.1 guard-sorrendi hibája is így került elő).

### T1 — Dart: szerializáció és a szolgáltatás-metódus

Három iteráció, szigorúan egymásra épülve. Mindhárom **tiszta Dart**, natív oldal nélkül — a végén a telefon *tudna* szinkronizálni, de még semmi nem hívja meg (a push-pontok a T2 dolga), tehát **viselkedésváltozás nincs**.

#### T1.1 — A „legutóbb használt tervek” szelektor *(tiszta függvény)* — **kész, 2026-07-28**

**Fájlok:** új `mobile/lib/features/workouts/application/watch_template_sync.dart`, új `mobile/test/features/workouts/application/watch_template_sync_test.dart`

**Teendő:** `recentlyUsedTemplateClientIds(List<WorkoutSession> sessionsDesc, {int max = 5})` a D-F6b.1 szerint — a `recommendedTemplateProvider` `predictNextTemplateClientId`-jának egyszerűbb testvére: dedup, `inProgress`-sessionök kihagyása, sorrend-tartás (legutóbb használt elöl), `max`-nál elvágva. Semmi Riverpod, semmi I/O.

**Megvalósítás:** `LinkedHashSet` (a Dart `<String>{}` alapértelmezése) adja a dedupot **és** a beszúrási sorrend megőrzését egyszerre, így egy ismétlődő terv a **frissebb** használatának pozícióját tartja meg, nem csúszik le a régebbihez. A `max`-ra futás a **különböző** tervekre számol (a `Set.length`-re, nem a végigjárt sessionökre) — hat session három tervvel nem vág le semmit.

**Ellenőrzés (elvégezve):** `flutter test .../watch_template_sync_test.dart` → **8/8 zöld**; `flutter analyze` a két új fájlra → **No issues found**. Lefedett ágak: üres history, sorrend-tartás, ismétlődő terv, `templateClientId == null` (üres edzés), futó session kihagyása, `max`-on túli vágás, „különböző tervek számítanak a `max`-ba, nem a sessionök”, egyedi `max`. Viselkedésváltozás nincs — a függvénynek egyelőre nincs hívója (a szerializáló a T1.2, a push-pontok a T2).

#### T1.2 — Payload-modell + a szerializáló — **kész, 2026-07-28**

**Fájlok:** ugyanaz a `watch_template_sync.dart` + teszt

**Teendő:** a §4.1 payload-alakja Dart-modellként (`WatchTemplatePayload`/`WatchTemplateExercisePayload` + `toJson`), és a szerializáló, ami a **D-F6b.4** rest-resolválást (`Exercise.defaultRestSeconds` → `UserSettings.defaultRestSeconds`) és a **D-F6b.6** kettős vágást (max 5 terv, tervenként max 12 gyakorlat) egy helyen végzi. Bemenete kész adat (`List<WorkoutTemplate>`, `List<Exercise>`, `UserSettings`, a T1.1 id-listája) — **nem** olvas repositoryból, hogy a `StandaloneSessionProcessor` S5-ös mintája szerint tesztelhető maradjon.

**Megvalósítás és a menet közben hozott apró döntések:**
- `restSeconds` a payloadban **nem nullable** — a resolválás küldés előtt megtörténik, mert a watch sem az `Exercises` táblát, sem a `UserSettings`-et nem ismeri (D-F6b.4). A `targetSets` viszont nullable maradt, és a `toJson` **kihagyja**, ha null: mindkét natív híd (`toDataMap()`, `sanitizedForPropertyList`) amúgy is kiszűri a nullokat, tehát az explicit null csak zaj lenne.
- **Három csendes eldobási ág** (mind normális eset, nem hiba): (1) olyan id, amihez már nincs terv (a user törölte, de a sessionjei még hivatkoznak rá, tehát a T1.1 továbbra is visszaadja); (2) olyan gyakorlat, ami nincs az `exercises` listában (jellemzően folyamatban lévő törlés — az `ExerciseRepository.watchAll` már kiszűri); (3) olyan terv, ami a szűrés után **egyetlen** gyakorlat nélkül maradna — üres tervet indítani az órán zsákutca, arra a „Quick strength” kártya a jobb válasz. Ez a harmadik ág a doc szövegén túli, menet közben hozott döntés.
- A `maxTemplates` a szerializálóban is ott van, **nem** csak a T1.1 szelektorban: a payload-méret (D-F6b.6 valódi motivációja) *wire*-szintű aggály, tehát a wire-payload építője kell garantálja, bárki is hívja. Az eldobott tervek **nem fogyasztják** a keretet (a `payloads.length`-re számol, nem a végigjárt id-kre) — külön tesztelve.
- A hosszú terv **vágódik, nem esik ki** — egy 20 gyakorlatos terv is hasznos, a picker `standalone_plan_exercises` száma ilyenkor a levágott hosszt mutatja, ami pontosan az, amit a watch ténylegesen tárol.

**Ellenőrzés (elvégezve):** `flutter test .../watch_template_sync_test.dart` → **19/19 zöld** (8 a T1.1-ből + 11 új); `flutter analyze` a két fájlra → **No issues found**. Lefedve: recency-sorrend győz az ábécés `templates`-listán, per-gyakorlat override, account-default fallback, `toJson` teljes alakja (a `targetSets` kihagyásával együtt), mindhárom eldobási ág, 20→12 vágás, terv-keret túllépése, „eldobott tervek nem fogyasztják a keretet”, üres bemenet. Viselkedésváltozás nincs — a szerializálónak még nincs hívója (a service-metódus a T1.3, a push-pontok a T2).

#### T1.3 — `WatchWorkoutService.syncTemplates(...)` — **kész, 2026-07-28**

**Fájlok:** `mobile/lib/core/watch/watch_workout_service.dart`, `mobile/test/core/watch/watch_workout_service_test.dart`

**Teendő:** új `syncTemplates(List<WatchTemplatePayload> templates)` a `startWorkout`/`updateState` mintájára — `_channel.invokeMethod('syncTemplates', {...})`, `isAvailable`-guard, best-effort `try/catch`. A natív oldalon még **nincs** handler (az a T3) — a `catch` pont ezt nyeli el, ahogy minden más metódusnál is a bevezetés pillanatában.

**Megvalósítás és a menet közben hozott apró döntések:**
- **A service a tipizált modellt kapja**, nem előre szerializált mapet, és maga hívja a `toJson`-t — pontosan a `startWorkout(state: WorkoutSessionState)` → `'state': state.toJson()` precedense. Ez egy `core/` → `features/` importot jelent (`WatchTemplatePayload`), ami **bevett ebben a kódbázisban** (pl. `core/home_screen_widget/widget_snapshot_writer.dart`, `core/health/step_goal_notifier.dart`), nem réteg-sértés.
- **Az üres lista is kimegy**, nem ugorjuk át a hívást: pontosan így kapja meg az óra, hogy ürítse a cache-ét, ha a usernek épp az utolsó terve is törlődött. (Ha skippelnénk, az óra örökre a régi listát mutatná.)
- **`syncedAtEpochMs` a telefon órájáról** — ugyanaz a döntés, mint a D-F6.6-nál a session-időknél: a két eszköz fali órája eltérhet, és a telefon az autoritás arra, mikor publikálta ezt a listát. A metóduson belül generálódik (nem paraméter) — a teszt ezért `greaterThanOrEqualTo(before)`-ral ellenőrzi, nem fix értékkel.

**Ellenőrzés (elvégezve):** `flutter test .../watch_workout_service_test.dart` → **25/25 zöld** (21 meglévő + 4 új: teljes payload + óra-bélyeg, üres lista is kimegy, `isAvailable: false` no-op, `MissingPluginException` elnyelése). `flutter analyze` a három érintett fájlra → **No issues found**. **Teljes regresszió:** `flutter test` → **372 zöld / 1 bukó**, a bukó a 44-doc §11/7-ben már rögzített, F6-tól független `stat_chart_data_test.dart` DST-artefakt (a T1 előtti alapállapot ugyanez az egy bukó volt). Viselkedésváltozás nincs — a metódusnak még nincs hívója (push-pontok: T2), és natív handler sincs hozzá (T3).

**T1 ezzel lezárva**: a telefon *tudna* szinkronizálni (szelektor → szerializáló → csatorna-hívás), de még semmi nem hívja meg.

### T2 — Push-pontok: **reaktív derivált állapot**, nem kézzel elhelyezett hívások

**Megközelítés-váltás a §4.3/§5-höz képest (2026-07-28).** Az eredeti szöveg „push-pontokat” írt elő: app-indulás + terv mentés/módosítás/törlés, a `WorkoutTemplateController` mutációiba kötve. A T1 lezárása után ez **rosszabb megoldásnak látszik**, három okból:

1. **A §4.3 maga is amiatt szorult javításra**, hogy az eredeti T1-vázlat lefelejtette a *törlést* — pontosan az a hibaosztály, amit a kézzel elhelyezett hívások termelnek. Ugyanez a csapda még legalább négyszer ott van: a szerver-pull is módosíthat tervet (`refresh()`/`pullAll()`), egy **gyakorlat átnevezése** megváltoztatja a payload `name` mezőjét, a **rest-beállítás** módosítása a `restSeconds`-öt, egy **befejezett edzés** pedig magát a sorrendet (D-F6b.1 recency). Nyolc-tíz hívási pontot kézzel karbantartani garantáltan elavul.
2. A kódbázisban **van bevált minta pontosan erre**: a `WidgetSnapshotController` (`core/home_screen_widget/`) ugyanezt a feladatot oldja meg a home-screen widgetre — `ref.listen` a forrás-providerekre, debounce, app-root-on `ref.watch`-csal életben tartva (`app.dart:54`). Az F6b-nek nincs oka ettől eltérni.
3. Reaktívan az **app-indulás** sem külön eset: a provider első kibocsátása maga a kezdeti push.

**Következmény**: a §4.3 „push-pontok” listája továbbra is *leírja*, mikor kell szinkronizálni — de nem hívási helyekként, hanem a derivált állapot bemeneteiként, amiket a T2.1 provider figyel. A `watchWorkoutEnabled` kapuzás is ide kerül (a payload üres, ha a kapcsoló ki van kapcsolva), nem minden hívási helyre külön.

#### T2.1 — A „mi legyen most az órán” derivált provider — **kész, 2026-07-28**

**Fájlok:** `mobile/lib/features/workouts/application/watch_template_sync.dart`, teszt ugyanott

**Teendő:** `watchTemplateSyncPayloadProvider` — `Provider<List<WatchTemplatePayload>>`, ami a négy forrást (`workoutSessionControllerProvider`, `workoutTemplateControllerProvider`, `exerciseControllerProvider`, `settingsControllerProvider`) figyeli, és a T1.1 + T1.2 függvényeket futtatja rájuk. `watchWorkoutEnabled == false` → üres lista. Bármelyik forrás még tölt (`AsyncValue.value == null`) → üres lista (nem küldünk fél-adatot). **Semmilyen mellékhatás** — ez tisztán derivált állapot, a tényleges push a T2.2.

**Megvalósítás:** a `settings` olvasása **előre került** a másik három elé, hogy a `watchWorkoutEnabled == false` ág azonnal kilépjen — kikapcsolt watch-forgalomnál a provider így a session-/template-/exercise-streamekre rá sem iratkozik. Mindkét üres-lista ág (kapu kikapcsolva, ill. valamelyik forrás tölt) **ugyanazt jelenti a watchnak, mint a „nincs egy terved sem”**: ürítsd a cache-t — ez a T1.3-ban rögzített „az üres lista is kimegy” döntéssel együtt konzisztens.

**Teszt-harness tanulság:** a `ProviderContainer`-es teszteknél nem elég a `settingsControllerProvider.future`-t bevárni — mind a négy forrás külön `Stream`, és a payload csak akkor áll össze, ha mindegyik szállított. A harness ezért egy `settle()` closure-t ad vissza a containerrel együtt, ami **pontosan azokat** a forrásokat várja be, amelyek ténylegesen emittálnak; így a „valamelyik forrás tölt” eset úgy áll ellenőrzés alatt, hogy a **többi már feloldódott** — nem trivális zöld amiatt, hogy még semmi nem érkezett meg.

**Ellenőrzés (elvégezve):** `flutter test .../watch_template_sync_test.dart` → **24/24 zöld** (19 a T1-ből + 5 új); `flutter analyze` a két fájlra → **No issues found**. Lefedve: mind a négy forrás összeépítése (recency-sorrend a sessionökből, név/rest a gyakorlatokból), kikapcsolt `watchWorkoutEnabled`, mindhárom „forrás tölt” ág külön-külön, nincs egyetlen terv sem, és a törölt-de-history-ban-élő terv eldobása végponttól végpontig. Viselkedésváltozás nincs — a providert még senki nem figyeli (az a T2.2).

#### T2.2 — A pusher controller + app-root bekötés — **kész, 2026-07-28**

**Fájlok:** új `mobile/lib/core/watch/watch_template_sync_controller.dart`, `mobile/lib/app.dart`, új `mobile/test/core/watch/watch_template_sync_controller_test.dart` (+ a T2.1 provider javítása, lásd lent)

**Teendő:** debounce (a widget-controller 2 s-ához hasonlóan), **dedup** (csak akkor hív `syncTemplates`-et, ha a szerializált payload ténylegesen változott az utoljára kiküldötthöz képest — a widget-writer nem dedupol, mert lokális prefs-be írni ingyen van, egy watch-push viszont nem), majd `WatchWorkoutService.syncTemplates(...)`. `app.dart`-ban egy `ref.watch(...)` sor.

**⚠️ Riverpod 3 buktató — a `WidgetSnapshotController` mintája itt NEM működik.** Az eredeti terv (és az első implementáció) a `WidgetSnapshotController`-t másolta: a controller konstruktorában `ref.listen(watchTemplateSyncPayloadProvider, ...)`. Ez **élesben csendben elromlott volna** — a teszt kapta el:
- A Riverpod 3 egy sima `Provider`-t **piszkosnak jelöl, de nem számol újra**, amíg az egyetlen feliratkozója egy `ref.listen`. A callback így soha nem tüzel; **`fireImmediately: true` sem segít** (pontosan ezen a felálláson ellenőrizve). Tünet: a tervek app-indításkor kimennek, utána soha többé.
- A `WidgetSnapshotController` azért ússza meg, mert **`StreamNotifier`-ekre** figyel (`dashboardControllerProvider` stb.), amik maguktól „forrók" — a `watchTemplateSyncPayloadProvider` viszont *derivált*.
- **A megoldás:** a controller kettéválik. A `_watchTemplateSyncControllerProvider` (privát) tartja a stabil objektumot a debounce-timerrel és a dedup-kulccsal; a publikus `watchTemplateSyncControllerProvider` egy `Provider<void>`, ami **`ref.watch`-csal** olvassa a payloadot és átadja a controllernek. Az app-root `ref.watch`-a tartja aktívan → ez kényszeríti ki az újraszámolást. A kettéválasztás nem stílus: ha a controller maga rebuildelődne payload-változásra, minden alkalommal elveszítené a saját debounce/dedup állapotát. A produkciós fájl doc-commentje ezt kiemelten jelzi, hogy senki ne „egyszerűsítse vissza".

**Egyéb megvalósítási részletek:**
- `_lastPushed` **az `await` előtt** frissül, hogy egy repülés közben érkező második változás ahhoz mérődjön, amit épp küldünk, ne az azelőttihez.
- Az `isAvailable`-guard a `schedulePush`-ban van (nem a konstruktorban), mert a controller most már állapotmentesen épül fel.

**A T2.1 utólagos javítása (ugyanebben a lépésben):** a T2.2 írása közben kiderült, hogy a T2.1 provider **két szemantikailag különböző esetet mosott össze** üres listára: „ki van kapcsolva a watch-forgalom" (→ *tényleg* ürítsd a cache-t) és „valamelyik forrás még tölt" (→ **nem tudjuk**, ne nyúlj a cache-hez). Így minden hidegindításkor kiment volna egy hamis cache-ürítés, mielőtt a valódi lista megérkezik — a 2 s debounce ezt *általában* elnyelte volna, de lassú hidegindításnál (nagy history, hideg DB) nem. **Javítva**: a provider típusa `Provider<List<WatchTemplatePayload>?>`, ahol **`null` = „még nem tudjuk, ne pusholj", `[]` = „az órán semmi ne legyen"**. A `schedulePush` a `null`-t eldobja.

**Ellenőrzés (elvégezve):** `flutter test .../watch_template_sync_controller_test.dart` → **9/9 zöld**: első push a debounce után, debounce előtt nincs push, valódi változásra új push, **azonos payload újrakibocsátására nincs**, terven *belüli* változás (rest-idő) is push-ot vált ki, `null` payloadra soha nincs push, `null → []` átmenetre **van** (valódi „üríts" válasz), változás-sorozat egyetlen push-ba olvad, és watch-támogatás nélküli platformon semmi nem történik. `flutter analyze` az 5 érintett fájlra → **No issues found**. **Teljes regresszió:** `flutter test` → **386 zöld / 1 bukó**, a bukó továbbra is a 44-doc §11/7-ben rögzített, F6-tól független DST-artefakt.

**T2 ezzel lezárva**: a telefon most már ténylegesen szinkronizál — de a natív oldalon még nincs `syncTemplates` handler (T3), tehát a hívás egyelőre `MissingPluginException`-nel elnyelődik.

### T3 — Natív továbbítás: a telefon oldala

**Scope-határ T3 és T4 közt** (a §12 elején lévő eredeti vázlat file-listája alapján): T3 a **telefon-natív** oldal — `WatchBridge.swift`/`WatchBridge.kt` fogadja a `syncTemplates` MethodChannel-hívást és kiküldi a drótra. A **watch-oldali** fogadás/tárolás/picker-feltöltés (`PhoneConnector.swift`, `PhoneListenerService.kt`, `StandaloneSessionStore`-bővítés, picker-képernyők) T4. A payload T3-ban **még nyers dictionary/JSON marad** mindkét oldalon (a `state`-push mai mintája szerint) — nincs típusos Swift/Kotlin modell, azt majd a T4 watch-oldali dekódere vezeti be, ha kell.

Három iteráció, **platformonként elválasztva** — az iOS-ág (T3.1 → T3.2) egymásra épül, az Android-ág (T3.3) független, a kettő párhuzamosítható:

#### T3.1 — iOS: a `pushContext` context-merge refaktor (D-F6b.2 megvalósítása) — **kész, 2026-07-29**

**Miért ez külön lépés, és miért ez van elöl:** ez **nem** a template-szinkron kódja — a mai, éles `pushContext`-et alakítja át, amit **minden** state-push használ (`startWorkout`, `updateState`, `endWorkout`). A mai kód minden híváskor egy vadonatúj `context` dictet épít fel és azt küldi `updateApplicationContext`-tel — ha a T3.2-ben a `syncTemplates` egy hasonlóan „nulláról épített" dictet küldene, az **törölné** a futó session state-jét a watch szemén (és fordítva egy state-push törölné a szinkronizált terveket), mert a `WCSession.applicationContext` egyetlen globális dict, amit a rendszer nem merge-el (lásd D-F6b.2 részletesen §2-ben). Ezt a kockázatot **azelőtt** kell megszüntetni, hogy a második írófél (`syncTemplates`) egyáltalán megjelenik a képben.

**Fájlok:** `mobile/ios/Runner/WatchBridge.swift`

**Teendő:**
- Egy `private var lastContext: [String: Any] = [:]` példányváltozó a `WatchBridge`-en.
- A mai `pushContext(sessionClientId:title:startedAtEpochMs:state:desiredPhase:)` **nem egy helyi `context`-et épít és küld**, hanem a **`lastContext`-et mutálja** (a session-kulcsokat felülírva/törölve a jelenlegi szabályok szerint — pl. `title`/`startedAtEpochMs` csak akkor kerül be, ha nem nil, pontosan mint ma), majd a **teljes** `lastContext`-et küldi `updateApplicationContext`-tel.
- **Fontos, nem triviális részlet**: az `endWorkout` ma `state: nil`-lel hívja a `pushContext`-et — ennek a mai kódban **nincs hatása** a state kulcsra (mert a `if let state` guard csak akkor ír, ha van érték, sosem töröl). Ez a viselkedés **megmarad** a refaktor után is (a `lastContext["state"]` nem törlődik `endWorkout`-nál sem ma, sem refaktor után) — ez **nem regresszió**, csak explicit dokumentálva, mert könnyű azt hinni, hogy a merge-esítés ezen változtat.
- **Amit a refaktor NEM csinál**: nem vezet be semmilyen új mezőt, nem hív semmilyen új natív API-t — tisztán a „nulláról épített dict" → „perzisztens dict mutálása" átalakítás. A `syncTemplates`/`templates` kulcs bevezetése a **T3.2** feladata.

**Megvalósítás:** pontosan a tervezett alakban — `private var lastContext: [String: Any] = [:]` a `WatchBridge`-en, a `pushContext` a helyi `context`-építés helyett a `lastContext`-et mutálja (`lastContext["sessionClientId"] = …`, feltételes `if let title { lastContext["title"] = title }` stb., változatlan logikával), majd a **teljes** `lastContext`-et küldi `updateApplicationContext`-tel. A doc-comment kiemelten rögzíti az `endWorkout`/`state: nil` nem-törlő viselkedést, hogy a jövőben senki ne higgye tévesen regressziónak vagy hiányzó törlésnek.

**Ellenőrzés (elvégezve):** `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'id=00008120-00166C683440201E' build` (fizikai iPhone) → **BUILD SUCCEEDED**; a `WatchBridge.swift`-re szűrve **nulla** figyelmeztetés/hiba (a kimenetben csak a projekt-szintű, ettől a fájltól független `appintentsmetadataprocessor`/AppIntents-üzenetek jelentek meg, ugyanazok, mint minden korábbi Runner-buildben). **Viselkedési regresszió-kockázat**: mivel ez élő, dolgozó session-szinkron kódot refaktorál, a tényleges viselkedési ellenőrzés (indítás → state-frissítések → zárás, ugyanúgy működik-e, mint refaktor előtt) a **§9 Wear-listájával és az iOS-listával együtt, S18-stílusban** történik — build-szinten most csak a fordítás igazolható, ahogy S18-nál is (44-doc) a build-ellenőrzés különvált az élő teszttől.

#### T3.2 — iOS: a `syncTemplates` handler — **kész, 2026-07-29**

**Fájlok:** ugyanaz a `WatchBridge.swift`

**Teendő:**
- `case "syncTemplates": syncTemplates(call, result: result)` a `handle(_:result:)` switch-ében.
- `private func syncTemplates(_ call: FlutterMethodCall, result: @escaping FlutterResult)`: kiolvassa `args["templates"]` (`[[String: Any]]`) és `args["syncedAtEpochMs"]`-t, `sanitizedForPropertyList`-tel megtisztítja (a meglévő függvény már kezeli a beágyazott tömböket/dictionary-ket, ellenőrizve — `if let array = value as? [Any] { return array.compactMap { sanitizedForPropertyList($0) } }`), majd a **T3.1-es `lastContext`** `"templates"` kulcsába írja és `updateApplicationContext`-tel elküldi a teljes (session state + templates) dictet.
- **Nincs `sendMessage`-fallback** — szemben a state-push-sal, aminek van egy azonnali `sendMessage` párja is (§4.3 D-F6.9 szellemében): a template-szinkronnak nincs latencia-érzékeny „élő" fele, a `updateApplicationContext` queue-olt kézbesítése (akár később, amikor a watch elérhető lesz) pontosan elég — ez konzisztens a §4.3-ban már rögzített döntéssel.
- Üres `templates` tömb is átmegy változtatás nélkül (a T1.3 „üres lista is kimegy" döntése natívan is érvényesül, mert a `sanitizedForPropertyList` egy üres tömböt üres tömbként ad vissza, nem hagyja ki).

**Megvalósítás:** a tervezett alakban — `case "syncTemplates": syncTemplates(call, result: result)` a switch-ben; a metódus `guard let`-tel olvassa ki `templates`-et (`[[String: Any]]`) és `syncedAtEpochMs`-t (elutasítja a hívást, ha bármelyik hiányzik vagy rossz típusú — a többi handlerrel egyező „csendes `result(nil)`" stílus), majd `lastContext["templates"]`/`lastContext["syncedAtEpochMs"]`-t írja és a **teljes** `lastContext`-et küldi. A `sanitizedForPropertyList(templates) as? [Any]` pontosan az `updateState` `sanitizedState = (sanitizedForPropertyList(state) as? [String: Any]) ?? [:]` mintáját tükrözi, csak tömbre. A `pushContext` doc-commentjében a „once syncTemplates exists" előretekintő megjegyzést lecseréltem a tényleges hivatkozásra (`written by [syncTemplates]`), hogy ne maradjon elavult utalás a kódban.

**Ellenőrzés (elvégezve):** `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'id=00008120-00166C683440201E' build` → **BUILD SUCCEEDED**; a `WatchBridge.swift`-re szűrve **nulla** figyelmeztetés/hiba. A natív handler tényleges elérése (hogy a T2.2 Dart-hívás már nem `MissingPluginException`-t kap) élő szimulátorpár/eszköz nélkül build-szinten nem figyelhető meg — ez a §9/S18-stílusú élő teszt feladata.

#### T3.3 — Android: a `syncTemplates` handler (D-F6b.3) — **kész, 2026-07-29**

**Fájlok:** `mobile/android/app/src/main/kotlin/com/khunor/lifey/WatchBridge.kt`

**Teendő:** nincs itt a D-F6b.2-höz hasonló előfeltétel-refaktor — a `pushState` már **path-alapú** `DataItem`-eket ír (`PutDataMapRequest.create(STATE_PATH)`), egy új, önálló `TEMPLATES_PATH` semmilyen meglévő adatot nem érint.
- `"syncTemplates" -> syncTemplates(call, result)` a `when (call.method)` blokkban.
- `private fun syncTemplates(call: MethodCall, result: MethodChannel.Result)`: kiolvassa `args["templates"]` (`List<Map<*, *>>`) és `args["syncedAtEpochMs"]`-t.
- **Üzenet, elsődleges út** (D-F6.9 mintája): `sendMessage(COMMAND_TEMPLATE_SYNC, <JSON payload>)` — a `templates` listát és a `syncedAtEpochMs`-t egy `JSONObject`/`JSONArray`-ba szerializálva, a `stateMessagePayload`-hoz hasonló kézi JSON-építéssel (nem Gson/Moshi — a kódbázis sehol nem használ JSON-szerializáló könyvtárat, kézzel épít `JSONObject`-eket, ahogy a `stateMessagePayload` és az `emitStandaloneSession`-höz tartozó dekódolás is).
- **`DataItem`, tartalék**: egy új `pushTemplates(...)` a `pushState`-hez hasonlóan, `PutDataMapRequest.create(TEMPLATES_PATH)`-szel — a `DataMap`-nek nincs natív „tömb gyakorlat-listája" típusa, ezért a `templates` mező valószínűleg egy szerializált JSON-string lesz a `DataMap`-en belül (nem egy `putDataMapArrayList`-lel felépített natív struktúra) — **ez a T3.3 egyetlen nyitott implementációs döntése**, amit a tényleges kódolás pillanatában kell eldönteni a `DataMap` API tényleges lehetőségei alapján.
- Új path-konstans (`TEMPLATES_PATH`) és üzenet-parancs (`COMMAND_TEMPLATE_SYNC`) a companion object meglévő konstans-blokkjába, a `STATE_PATH`/`COMMAND_START` mintájára.

**Megvalósítás:** a tervezett alakban, egy döntéssel a nyitva hagyott ponton — a `DataMap`-nek valóban nincs natív „tömb gyakorlat-listával" típusa, úgyhogy a `pushTemplates` a teljes `templates` struktúrát egy `templatesJson` string mezőbe szerializálja a `DataMap`-en belül. Ehhez egy **általános, rekurzív** JSON-konvertáló kellett (`Any?.toJsonValue()`) — a meglévő `Map<String, Any?>.toDataMap()` csak egy szintet kezel (a `state` mezőhöz elég volt), de egy terv beágyazott `exercises` listája miatt ez nem elég. A konverter Map-eknél a `null` értékeket kihagyja (a `stateMessagePayload` `if (value != null)` mintáját követve) — bár ez a gyakorlatban nem is fordulhat elő, mert a Dart-oldali `toJson()` már eleve kihagyja a hiányzó opcionálisokat, nem `null`-ként küldi.

- **Üzenet, elsődleges út**: `sendMessage(COMMAND_TEMPLATE_SYNC, templateSyncMessagePayload(...))` — a `templateSyncMessagePayload` a `stateMessagePayload` mellé került, ugyanazt a `toJsonValue()`-t használva a `templates` mezőre.
- **`DataItem`, tartalék**: `pushTemplates(...)` a `pushState` közvetlen párja, de **nincs context-merge kockázata** — a `TEMPLATES_PATH` egy önálló path, amit a Data Layer sosem kever össze a `STATE_PATH`-sal (D-F6b.3, szemben az iOS D-F6b.2 problémájával).
- Két új konstans a companion objectbe: `TEMPLATES_PATH` (`$MESSAGE_PATH_PREFIX/templates`) és `COMMAND_TEMPLATE_SYNC` (`"templateSync"`, egyezik a Dart-oldali `type: "templateSync"` protokoll-névvel, §4.1).
- **Nem kellett manifest-módosítás**: a `syncTemplates` telefon→óra irányú, a manifest-deklarált `<data>`-utak (a `PhoneWatchSummaryListenerService`-nél) csak a Flutter-engine nélkül is fogadandó **óra→telefon** üzenetekhez kellenek (summary, standaloneSessionCompleted) — ez itt nem az az eset.

**Ellenőrzés (elvégezve):** `./gradlew :app:compileDebugKotlin --rerun` (teljes újrafordítás) → **BUILD SUCCESSFUL**, nulla figyelmeztetés a projekt saját fájljaiban (csak a megszokott, ettől független AGP/Gradle-plugin sorok). `./gradlew :app:assembleDebug` → **BUILD SUCCESSFUL** (resource/manifest-merge + dexing is lefutott, nem csak a Kotlin-fordítás).

---

**A T3 egésze után**: a telefon mindkét platformon ténylegesen kiküldi a szinkronizált terveket a drótra — de a watch oldalán még semmi nem fogadja, dekódolja vagy tárolja őket (az T4 feladata), úgyhogy **megfigyelhető viselkedésváltozás továbbra sincs**, csak a build-ellenőrzések igazolják a lépést.

### T4 — Watch-cache + picker feltöltése

**Scope-határ**: T4 a **watch-oldali** fogadás + tárolás + megjelenítés. A **tényleges indítás** egy szinkronizált tervből — `WorkoutManager.startStandalone(template:)` / `startStandaloneExercise(template:)` — a **T6** feladata (§3.3). T4 tehát a picker-sorokat **megjeleníti** (cím + `standalone_plan_exercises` szám, D-F6b.7 sorrendje szerint: a quick-strength kártya marad legfelül/kiemelt, a szinkronizált sorok alatta, a `standalone_empty_hint` csak üres cache-nél), de a **tap-kezelésük egyelőre inert** — pontosan úgy dokumentálva a kódban, mint az F6a S15-ös `SessionPhase.SUMMARY -> {}` szándékosan üres ága volt: nem hamis/kölcsönvett funkció, csak őszintén jelzett „ez még nincs bekötve".

*(A T4 megírásakor ez a bekötés még a designer-döntéstől blokkolt T5 feladata volt — a 2026-07-29-es terv-revízió óta ez a **T6**, és nincs blokkolva. A kódban hagyott „T5"-hivatkozásokat a T6 megvalósításakor kell átvezetni, amikor amúgy is eltűnnek.)*

---

#### T4.5 — watchOS: görgethetőség — **utólagos hibajavítás, kész, 2026-07-29**

**A hiba (user jelentette eszközön):** az Apple Watch-appban **sehol nem működött a koronás görgetés**, a picker („edzés indításnál") pedig **ujjal sem** volt görgethető. Ez valós, szállított hiba volt, nem hiányzó funkció.

**Ok.** A watch-app **egyetlen** képernyője sem tartalmazott görgethető konténert (`ScrollView`/`List`) — mind ugyanazt a mintát használta: `GeometryReader` → `VStack` → `.frame(width:height: geometry.size.height)`. A tartalom képernyőmagasságra **rögzítve** volt, tehát a rendszernek nem is volt mit görgetnie, és a korona sem kapott görgetési célpontot. A pickernél ez a **T4.2-vel vált tünetté**: F6a-ban a képernyőn egyetlen kártya + egy hint volt (befért), a szinkronizált terv-sorok viszont 5 tervnél garantáltan túllógnak. A design ezt egyébként kezdettől előírta („watchOS lista-carousel", 44-doc §3.1) — a T4.2 ezt nem vette át, ez az én hibám volt.

**Javítás.** `ScrollView` a `StandalonePickerView`, `SummaryView`, `EffortSelectorView`, `HealthDeniedView` és `EndingView` tartalma köré. Két dolgot kellett vele együtt megoldani:

- **Függőleges középre igazítás megőrzése.** A régi `.frame(height: geometry.size.height)` a tartalmat középre tette; `ScrollView`-ban ez felülre ugrott volna — vizuális regresszió a már jóváhagyott képernyőkön. A tartalom ezért `.frame(minHeight: geometry.size.height)`-et kap: ha befér, pontosan úgy néz ki, mint eddig (középen); ha nem fér be, a `ScrollView` veszi át.
- **A picker vissza-nyila a görgetett folyamba került** (a cím mellé, egy `HStack`-be), a korábbi `ZStack`-es lebegő elhelyezés helyett: egy fixen lebegő gomb folyamatosan elnyelte volna a bal felső sarokban a tapeket, ahogy a terv-sorok alatta elgördülnek.

**Az `ActiveWorkoutView` szándékosan érintetlen**: ott a korona a 3 lap közti **lapozást** vezérli (48-doc D-F5b.1, eszközön igazolva), nem görgetést — egy `ScrollView` ott elrontaná a lapozást.

**Ellenőrzés (elvégezve):** `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'generic/platform=iOS' build` → **BUILD SUCCEEDED**, nulla hiba/figyelmeztetés a `LifeyWatch/Views` alatt. *(Fizikai eszköz épp nem volt csatlakoztatva, ezért generikus célpont — a Swift-fordítás így is teljes.)* **A tényleges görgetés eszközön még ellenőrzendő** — ez a felhasználói visszaigazolás köre.

**Tanulság a hátralévő lépésekhez:** a **T7** gyakorlat-listája (§3.5) ugyanilyen változó hosszú lista — **eleve `ScrollView`-val** kell megépíteni, nem utólag. Ugyanez a §8 tesztlistájába is bekerül: *minden* új watch-képernyőnél explicit ellenőrzendő a koronás és az ujjal görgetés.

Négy iteráció, **platformonként elválasztva**, a T3-mintát követve — mindegyik platformon belül „fogadás+tárolás" → „UI" sorrendben:

#### T4.1 — iOS: fogadás + cache — **kész, 2026-07-29**

**Fájlok:** `mobile/ios/LifeyWatch/StandaloneSessionPayload.swift` (új `CachedTemplate`/`CachedTemplateExercise` Codable structok), `mobile/ios/LifeyWatch/StandaloneSessionStore.swift` (új `templates`-fájl + `saveTemplates(_:)`/`loadTemplates()`), `mobile/ios/LifeyWatch/PhoneConnector.swift`

**⚠️ Buktató, amit a vizsgálat feltárt — `applyContext` idő előtt kilépne egy csak-terveket-hordozó contextnél.** A mai `applyContext(_ context:)`:
```swift
guard !context.isEmpty, let sessionClientId = context["sessionClientId"] as? String else {
  return
}
```
Ez a guard **azelőtt** tér vissza, hogy bármi mást megnézne a contextből. A T3.1-es `lastContext` viszont pontosan azt a helyzetet teszi lehetővé (sőt, egy friss páron ez lesz a **jellemző** első eset), hogy a `templates` kulcs **van**, de `sessionClientId` **nincs** — a user még sosem indított sessiont a telefonról/óráról, csak a terv-szinkron már lefutott. A mai kód ezt a contextet **teljes egészében eldobná**, a szinkronizált tervek sosem jutnának el a cache-be. **A javítás**: a `templates` kiolvasása/tárolása kerüljön a `sessionClientId`-guard **elé**, a saját, önálló feltétele mellett — ugyanaz a hibaosztály és ugyanaz a javítási minta, mint az S8-as `standaloneSessionAck`-guard-sorrend fix volt (44-doc S8: „ack-guard-ordering fix").

**Teendő:**
- `applyContext`-ben egy új, a `sessionClientId`-guard elé kerülő ág: `if let templates = context["templates"] as? [[String: Any]] { ... decode → StandaloneSessionStore.shared.saveTemplates(...) }` — fut **függetlenül** attól, hogy van-e `sessionClientId` a contextben.
- `CachedTemplateExercise { exerciseId: String, name: String, restSeconds: Int, targetSets: Int? }` / `CachedTemplate { templateId: String, title: String, exercises: [CachedTemplateExercise] }` — a §4.1 payload-alakja, típusosan (a `StandaloneSet`/`StandaloneSessionPayload` mintáját követve, nem nyers dictionary — ez az egyetlen watch-oldali komponens, ahol iOS típusos modellt használ, Android nem, lásd T4.3).
- A nyers `[[String: Any]]` → `[CachedTemplate]` leképezés: mivel a dictionary már `sanitizedForPropertyList`-en átment (property-list-kompatibilis, tehát `JSONSerialization.data(withJSONObject:)` biztonságosan újra JSON-ná alakítja), a legegyszerűbb út `JSONSerialization.data(withJSONObject:)` + `JSONDecoder().decode([CachedTemplate].self, from:)` — nem kézi mezőnkénti kiolvasás, mint a `state`-nél, mert itt **van** Codable modell, aminek a gépi dekódolás direkt megfelel.
- `StandaloneSessionStore`: új `templatesURL`, `saveTemplates(_:)` (felülír, nem összefésül — a szinkron mindig a teljes, friss listát küldi), `templates() -> [CachedTemplate]` (üres tömb, ha nincs fájl vagy dekódolási hiba).

**Megvalósítás:** a tervezett alakban, egy döntéssel: a `[[String: Any]] → [CachedTemplate]` leképezés `JSONSerialization.data(withJSONObject:)` + `JSONDecoder().decode(...)` — nem kézi mezőnkénti kiolvasás, mint az `applyState` teszi a `state`-nél, mert itt **van** Codable célmodell, aminek a gépi dekódolás direkt megfelel (a `state`-nek nincs saját típusa, azt közvetlenül a `WorkoutManager` mezőire képezzük le). A tömb már átment `WatchBridge`'s `sanitizedForPropertyList`-en a küldés előtt (T3.2), tehát garantáltan property-list-biztonságos — a `JSONSerialization` visszafelé-konvertálása emiatt nem hibázhat formátum miatt.

Az `applyTemplateSync(_:)` **minden** `applyContext`-hívásnál lefut, **feltétel nélkül** — beleértve a sima session-state push-okat is, ha korábban már volt terv-szinkron (mert a T3.1-es `lastContext` a `templates` kulcsot minden további push-nál is továbbviszi). Ez azt jelenti, hogy a `saveTemplates` a gyakorlatban **gyakran ugyanazt az adatot írja felül újra** — ez egy tudatosan vállalt, olcsó redundancia (helyi fájlírás, nem hálózati hívás, mint a T2.2-es dedup-indoka volt), nem hiba: extra dedup-logika bevezetése itt aránytalan komplexitás lenne egy gyakorlatilag ingyenes műveletért.

**Ellenőrzés (elvégezve):** `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'id=00008120-00166C683440201E' build` → **BUILD SUCCEEDED**; a három érintett fájlra (`StandaloneSessionPayload.swift`, `StandaloneSessionStore.swift`, `PhoneConnector.swift`) szűrve **nulla** figyelmeztetés/hiba. A tényleges „context csak terveket hordoz, session-t nem" eset build-szinten nem reprodukálható (ahhoz élő pár kell) — ez S18-stílusú élő teszt, de a kód **build-szinten már úgy néz ki**, hogy ez az ág fusson.

#### T4.2 — iOS: a picker beolvassa a cache-t — **kész, 2026-07-29**

**Fájlok:** `mobile/ios/LifeyWatch/Views/StandalonePickerView.swift`

**Teendő:** a mai, mindig-üres-variánst renderelő nézet kiegészül egy `StandaloneSessionStore.shared.templates()` olvasással — a D-F6b.7 sorrend szerint a quick-strength kártya alatt egy sor **minden** cache-elt tervhez (cím + `standalone_plan_exercises(exercises.count)`), a `standalone_empty_hint` csak akkor, ha a lista **üres**. Minden sor kap egy `onTap` closure-t, de a `StandalonePickerView`-t példányosító hely (`ContentView.swift`) egyelőre egy **explicit, dokumentált no-op**-ot ad át — a doc-comment egyértelműen jelzi, hogy ez T5-re vár, nem elfelejtett bekötés.

**Megvalósítás és egy eltérés a doc szövegétől:** a design szerinti sorrendben (D-F6b.7: quick-strength mindig legfelül, `container`-háttérrel + `bolt` ikonnal, a szinkronizált sorok alatta plain `surface`-háttérrel, ikon nélkül — pontosan az AW 13 canvas szerint) — új `TemplateRow` private struct, a meglévő `standalone_plan_exercises` kulcsot használva (F6a S1-ből, eddig kihasználatlan volt). A `templates` egy `@State`-be kerül, **nem élőben figyelt** — `.onAppear`-nál olvasódik be egyszer, ugyanazt a „point-in-time snapshot" szerződést követve, mint a `StandaloneSessionStore` minden más olvasása ebben a kódbázisban (S9 recovery-load, S11 summary pending-count). Egy szinkron, ami épp akkor érkezik, amikor ez a képernyő már látszik, csak a következő megnyitáskor jelenik meg — elfogadható frissességi ablak a pickeren, amit a user csak röviden néz meg tap előtt.

**Eltérés a §12 szövegétől**: a terv „a `StandalonePickerView`-t példányosító hely (`ContentView.swift`) egyelőre egy explicit, dokumentált no-op-ot ad át"-ot írt elő — ehelyett az `onTemplateTapped` egy **default paraméterértéket** kapott (`{ _ in }`) magán a `StandalonePickerView`-n, dokumentálva a struct-szintű doc-commentben. Ez ugyanazt az őszinte „T5-re vár" jelzést adja, de nem igényel érintetlen `ContentView.swift`-módosítást — a dokumentáció egy helyen él (a típuson), nem duplikálódik minden hívási helyen.

**Ellenőrzés (elvégezve):** `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'id=00008120-00166C683440201E' build` → **BUILD SUCCEEDED**; a `StandalonePickerView.swift`-re szűrve **nulla** figyelmeztetés/hiba. A vizuális megjelenés (kézzel a cache-fájlba írt teszt-JSON-nal) élő eszközön ellenőrizhető — ez már a §9 iOS-listájának köre.

#### T4.3 — Android: fogadás + cache — **kész, 2026-07-29**

**Fájlok:** `mobile/android/wear/src/main/kotlin/com/khunor/lifey/StandaloneSessionStore.kt`, `mobile/android/wear/src/main/kotlin/com/khunor/lifey/PhoneListenerService.kt`

**Nincs itt a T4.1-hez hasonló guard-sorrend csapda** — pontosan azért, mert a T3.3 saját, önálló üzenet-path-ot (`$MESSAGE_PATH_PREFIX/templateSync`) és önálló `DataItem`-path-ot (`TEMPLATES_PATH`) épített, ami sosem keveredik a state-sync `when`/`if` ágaival. Egyetlen dolog, amire figyelni kell: a `TEMPLATES_PATH` konstans **ma csak a telefon-modulban** (`WatchBridge.kt`, `:app`) létezik — a `PhoneListenerService.kt` (`:wear`, külön Gradle-modul/APK) a saját, duplikált `STATE_PATH`-mintáját követve **saját, kézzel egyeztetett** konstansot kap ugyanazzal a string-értékkel (ez már ma is így van a state-nél — nem új kockázat, csak egy meglévő minta követése).

**Teendő:**
- `StandaloneSessionStore.kt`: új `KEY_TEMPLATES`, `saveTemplates(context, templatesJson: String)` / `templates(context): List<JSONObject>` — **nyers JSON**, nem típusos data class, a store meglévő konvencióját követve (ellentétben az iOS T4.1-gyel — a két platform itt tudatosan eltér, mert Android sehol nem vezetett be Codable-szerű típusos modellt a watch↔telefon üzenetekhez).
- `PhoneListenerService.kt`: `onMessageReceived`-ben új `"$MESSAGE_PATH_PREFIX/templateSync" -> applyTemplateSyncMessage(messageEvent.data)` ág; `onDataChanged`-ben egy második `if (event.dataItem.uri.path == TEMPLATES_PATH) { ... }` (a mai kód csak `STATE_PATH`-ra szűr, most path szerint elágazik). Mindkettő a T3.3 `templateSyncMessagePayload`/`pushTemplates` JSON-alakját dekódolja `StandaloneSessionStore.saveTemplates`-be.

**Megvalósítás:** a tervezett alakban, minimális diffel a meglévő, működő `onDataChanged`-ben — az új `TEMPLATES_PATH`-ág **a régi `STATE_PATH`-guard elé** került egy külön `if`/`continue` párral, a state-kezelő kód **egyetlen sora sem változott**. A `templatesJson` mindkét úton (üzenet és `DataItem`) ugyanabba a `StandaloneSessionStore.saveTemplates`-be fut be — az üzenet-oldalon a `JSONObject`-ből kiemelt `templates` tömböt `.toString()`-gel alakítom vissza JSON-stringgé, mert a store (Android-konvenció szerint, iOS-szel ellentétben) nyers JSON-t tárol, nem típusos modellt.

**Ellenőrzés (elvégezve):** `./gradlew :wear:compileDebugKotlin --rerun` (teljes újrafordítás) → **BUILD SUCCESSFUL**, nulla figyelmeztetés a projekt saját fájljaiban. `./gradlew :wear:assembleDebug` → **BUILD SUCCESSFUL** (resource/manifest-merge is lefutott).

#### T4.4 — Android: a picker beolvassa a cache-t — **kész, 2026-07-29**

**Fájlok:** `mobile/android/wear/src/main/kotlin/com/khunor/lifey/ui/StandalonePickerScreen.kt`

**Teendő:** a T4.2 iOS-változatának Compose-megfelelője — a `ScalingLazyColumn`-ba a quick-strength `Chip` alá egy `item` minden cache-elt tervre (cím + gyakorlatszám), a `standalone_empty_hint` csak üres cache-nél. A sorok `onClick`-je itt is **explicit, dokumentált no-op** marad — a `MainActivity.kt`-beli hívó felel a T5-ig tartó placeholder-átadásért.

**Megvalósítás:** a T4.2 iOS-verziójának pontos Compose-megfelelője — a meglévő quick-strength `Chip` (`containerHigh` háttér) érintetlen maradt, alá egy `TemplateRow` sor kerül minden cache-elt tervhez (`surface` háttér, ikon nélkül, pontosan a W 12 canvas szerint), a `standalone_empty_hint` csak üres cache-nél. A `template` egy nyers `JSONObject` (`StandaloneSessionStore.templates()` konvenciója), `opt*`-tal olvasva — nem vezettem be data classt egyetlen hívási helyért, ahogy a store és a `PhoneListenerService` egésze is nyers JSON-nal dolgozik. A `templates` lista `remember { ... }`-mel, egyszeri olvasás kompozíciónként — ugyanaz a „point-in-time snapshot" szerződés, mint a T4.2-es iOS `@State`-nél.

**Ellenőrzés (elvégezve):** `./gradlew :wear:compileDebugKotlin --rerun` (teljes újrafordítás) → **BUILD SUCCESSFUL**, nulla figyelmeztetés a projekt saját fájljaiban. `./gradlew :wear:assembleDebug :app:assembleDebug` → **BUILD SUCCESSFUL** mindkét Android modulra (resource/manifest-merge is lefutott).

---

**A T4 egésze után**: a szinkronizált tervek ténylegesen megjelennek a picker-en mindkét platformon (cím + gyakorlatszám) — ez az első **megfigyelhető** F6b-viselkedés. A sorra tapre viszont még nem történik semmi (a bekötés a **T6** feladata), ez explicit dokumentálva marad a kódban és itt is.

---

### T5 — Telefon: `templateId`/`exerciseIndex` feloldás a feldolgozóban — **kész, 2026-07-29**

**Fájlok:** `mobile/lib/features/workouts/application/standalone_session_processor.dart`, teszt ugyanott

**Miért ez megy előre a watch-lépések elé:** tiszta Dart, watch nélkül teljesen unit-tesztelhető, és a **fogadó oldalt készíti el azelőtt**, hogy a watch elkezdene terv-attribútumos payloadot küldeni (T6). Fordított sorrendben egy élő teszt hibájáról nem lehetne megmondani, a küldő vagy a fogadó rontotta-e el.

**Teendő** (D-F6b.5 szerint):
- Ha a payload `templateId`-t hordoz: `WorkoutTemplateRepository.findByClientId(templateId)`, majd minden szett `exerciseIndex`-ének feloldása `template.exercises[i].exerciseClientId`-re.
- `WorkoutSessionRepository.create(..., templateClientId:, templateName:, exercises:)` — mindhárom paraméter **már ma is létezik** (§6), F6a csak nem töltötte ki. Az `exercises` a terv **teljes** gyakorlatlistája (`PlannedExerciseInput`), nem csak azok, amikre ténylegesen ment szett — így a session a telefonon a tervvel azonosan néz ki.
- **Fallback a generikus gyakorlatra** (a mai F6a-út) minden fel nem oldható esetben: nincs `templateId`; a terv azóta törlődött; az `exerciseIndex` kiesik a tartományból (a user szerkesztette a tervet); az `exerciseIndex` `null`. **Egyik sem hiba** — mindegyik normális, és egyik sem akadályozhatja meg a session létrejöttét (az adatvesztés lenne).
- **Vegyes eset**: egy sessionön belül lehet feloldható és fel nem oldható szett is (pl. a terv közben rövidült) — **szettenként** dől el, nem az egész sessionre.

**Megvalósítás:** a tervezett alakban, egy pontosítással a „generikus gyakorlat" kezelésénél. A régi F6a-kód **eagerly** hozta létre/kérte le a generikus gyakorlatot minden hívásnál. A vegyes eset (D-F6b.5) miatt ez most **feltételes**: `needsGenericExercise` egy szinkron predikátum, ami *az összes szett* `exerciseIndex`-ét megnézi a template-feloldás után, **mielőtt** bármilyen async gyakorlat-létrehozás történne — ha egyetlen szett sem szorul rá (mert a terv teljes egészében feloldódott), a `getOrCreateByName` **meg sem hívódik**. A feloldás/fallback logikáját egyetlen `_resolvesWithinTemplate(exerciseIndex, template)` helperbe emeltem ki, hogy a `exercises`-lista és a `sets`-lista építése ne duplikálja a feltételt.

**A `templateClientId` konzisztensen `null` marad minden fallback-ágon** — nem csak akkor, ha eleve nem volt `templateId`, hanem akkor is, ha a terv időközben törlődött. Ez szándékos: egy törölt tervre mutató, „lógó" hivatkozás rosszabb lenne, mint az őszinte „nincs terv-kapcsolat" — ugyanaz az elv, mint a `title`-nél (`template?.name ?? genericTitle`), a kettő mindig együtt esik vissza.

**Ellenőrzés (elvégezve):** `flutter test .../standalone_session_processor_test.dart` → **14/14 zöld** (8 meglévő + 6 új: érvényes index → valódi gyakorlat, a terv **teljes** tervezett listája `targetSets`-tel együtt átmegy még akkor is, ha egy gyakorlatra nem is ment szett, `templateId` nélküli payload bitre változatlan, törölt terv → fallback, tartományon kívüli index → **szettenkénti** fallback (a session mégis template-linkelt marad), `null` index → fallback). `flutter analyze` a két érintett fájlra → **No issues found**. **Teljes regresszió:** `flutter test` → **392 zöld / 1 bukó**, a bukó a már ismert, F6-tól független `stat_chart_data_test.dart` DST-artefakt (a T5 előtti alapállapot ugyanez az egy volt).

---

### T6 — Watch: session indítása tervből *(platformonként, párhuzamosítható)* — **kész, 2026-07-30**

**Fájlok:** iOS `WorkoutManager.swift`, `Views/StandalonePickerView.swift`, `StandaloneSessionPayload.swift`; Android `SessionStateHolder.kt`, `ExerciseService.kt`, `ui/StandalonePickerScreen.kt`, `MainActivity.kt`

**Teendő:**
- A T4-ben szándékosan no-opként hagyott `onTemplateTapped` bekötése: a kiválasztott terv **snapshotjával** indít standalone sessiont (§3.3 — nem a cache-re mutató hivatkozással, hogy egy menet közbeni `templateSync` ne írhassa át a futó sessiont).
- A session-állapot bővül: terv-snapshot + `currentExerciseIndex` (iOS `WorkoutManager` published property; Android `SessionMetadata` mező).
- A logolt szettek megkapják az `exerciseIndex`-et — a protokoll **már ma is** viszi (F6a-ban mindig `null`, §4.2), tehát **nincs protokoll-bővítés**.
- A `restSeconds` forrása tervezett módban a snapshot aktuális gyakorlatának értéke a fix 90 s helyett (§3.3).
- A recovery-snapshot (`StandaloneSessionStore` active-meta) is hordozza a terv-snapshotot és az indexet. *(A Wear-oldali recovery visszaolvasása a 44-doc §11/6 szerint ma amúgy sincs implementálva — ez a lépés nem hozza be, de nem is rontja el.)*

**Eltérés a doc fájllistájától — `ContentView.swift` végül nem változott.** A terv ezt is érintett fájlként sorolta fel, de kiderült, hogy nincs rá szükség: a `quickStrengthCard` már ma is **közvetlenül** hívja a `WorkoutManager.shared.startStandalone()`-t a `StandalonePickerView`-n belül, nem egy `ContentView`-től kapott callback-en át. A `TemplateRow` tapja ugyanezt a mintát követi (`WorkoutManager.shared.startStandalone(template:)`, saját `templateTapped(_:)` metódussal), ezért a T4.2-ben bevezetett `onTemplateTapped: (String) -> Void` callback **feleslegessé vált és törlődött** — nem `ContentView`-nek delegál, a nézet maga indít. Az `isStarting` debounce mindkét induló útra (quick-strength **és** terv-sorok) kiterjed, egy közös flaggel — egy terv-sor tapre induló session közben a quick-strength kártya és az összes többi sor is `disabled`.

**Android-oldalon a minta más, tudatosan** — ott az `onTemplateTapped` callback **megmaradt**, mert `MainActivity` (nem a Composable) birtokolja a `requestSensorPermissionsIfNeeded()`-hez szükséges `ComponentActivity`-t; a `StandalonePickerScreen` a teljes `JSONObject`-et adja tovább (nem csak az id-t, ahogy T4.4-ben még csak `templateId`-t adott át) — `MainActivity` ezt egyenesen a `startStandaloneIntent(templateJson:)` extra-jába teszi.

**A tervezett terv-modellek platformonként eltérő rétegben élnek**, tudatosan: iOS-en a `CachedTemplate`/`CachedTemplateExercise` (T4.1-ből) egyben a **tárolási** és a **session-állapot** modell is — a `WorkoutManager.standaloneTemplate` közvetlenül ezt tárolja. Androidon viszont a `StandaloneSessionStore` a T4.3 óta is **nyers JSON** marad (a kódbázis meglévő konvenciója a wire/tár rétegre), és T6 egy **külön, típusos** `StandaloneTemplate`/`StandaloneTemplateExercise` párt vezetett be `SessionStateHolder.kt`-ban, amit az `ExerciseService.parseStandaloneTemplate(...)` dekódol a picker JSON-jából **egyszer**, induláskor — a session-állapot onnantól típusos, a tár- és drót-réteg nem. Ez a T4.3-ban már dokumentált platform-aszimmetria (D-F6b.3-mal rokon, de nem azzal azonos indok) folytatása, nem új inkonzisztencia.

**Ellenőrzés (elvégezve):** `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'generic/platform=iOS' build` → **BUILD SUCCEEDED**, nulla figyelmeztetés/hiba a három érintett iOS-fájlban. `./gradlew :wear:compileDebugKotlin --rerun` (teljes újrafordítás) → **BUILD SUCCESSFUL**, nulla figyelmeztetés a projekt saját fájljaiban. `./gradlew :wear:assembleDebug` → **BUILD SUCCESSFUL** (resource/manifest-merge is lefutott). Dart-fájl nem változott, a Dart-suite újrafuttatása nem indokolt. A tényleges „terv szerint indul és a helyes indexszel logol" a T8 élő tesztjének köre.

---

### T7 — Watch: aktív képernyő + gyakorlat-lista *(platformonként, párhuzamosítható)* — **kész, 2026-07-30**

**Fájlok:** iOS `WorkoutManager.swift`, `Views/ActiveWorkoutView.swift`, `Localizable.xcstrings`; Android `SessionStateHolder.kt`, `ui/ActiveWorkoutScreen.kt`, `values/strings.xml`, `values-en/strings.xml`

**Teendő:**
- §3.4 aktív-képernyő delták: `setsDone` = az **aktuális** gyakorlatra logolt szettek száma, `setsTotal` = a snapshot `targetSets`-e, `targetSets == null` esetén visszaesés az F6a `active_sets_free_format` sorára. A `phonelink_off` glyph marad.
- §3.5 gyakorlat-lista + a `ControlsPage` vezérlője (csak tervezett módban látszik).
- A §7 két új kulcsa mindhárom erőforrás-helyre, azonos kulcsnévvel.

**Közös konszolidáció mindkét platformon, doc-listán túl.** A `setsDone`/`setsTotal`/`freeFormatSets`/gyakorlatnév számítása a régi kódban **három helyen** duplikálódott platformonként (log-lap kontextsora, aktív gyakorlat-kártya, rest-hero „Next" sora) — mindegyik saját `if (isStandalone) … else …` ágat futtatott. T7 ezt **egy közös számításba** vonta össze, amit minden érintett hely ugyanonnan olvas:
- **iOS**: `WorkoutManager.activeExerciseDisplay` (computed property, + a mögötte lévő `standaloneCurrentExercise`/`standaloneSetsForCurrentExercise` helperek) és egy új top-level `ActiveExerciseDisplay` struct.
- **Android**: `ActiveExerciseDisplay` data class a `SessionStateHolder.kt`-ban (tisztán Kotlin, Compose-független — mintázatra `StandaloneSet`/`StandaloneSummary` mellé), és egy `@Composable activeExerciseDisplay(metadata)` függvény az `ActiveWorkoutScreen.kt`-ban, ami `stringResource`-t hív (ezért nem lehetett a state-rétegben, ellentétben iOS `String(localized:)`-jével, ami bárhonnan hívható).

Ez **bizonyítottan visszafelé kompatibilis**: mindkét platformon a phone-mastered és a quick-strength ág a régi kód **pontos** reprodukciója (a `else`/utolsó ág mindkét nyelven szó szerint a korábbi számítás), a template-ág pedig **új**, harmadik lehetőségként ékelődik be — nem módosítja a másik kettő viselkedését.

- **A rest-hero „Next" sora most a valódi gyakorlatnevet mutatja** tervezett módban, a fix `standalone_quick_start` helyett — korábban `RestHero`/`RestHeroView` mindig a `standalone_quick_start` fallbacket kapta standalone alatt (mert `setsDone`/`setsTotal` sosem volt kitöltve arra az ágra); most a közös `display`-en át a rest alatt is a **soron következő** gyakorlat neve (és — ha van `targetSets` — a „Set n of total" sor is) jelenik meg.
- **A gyakorlat-lista komponens-szinten a T4-es picker alakja** — iOS `ScrollView` + sor-VStack-ek (a T4.5-ös görgethetőségi lecke szerint eleve görgethetőnek épült), Android `ScalingLazyColumn` (a T4.4 nem-deprecated importjával). Egyik platformon sem új vizuális nyelv.
- **A váltás nem „Next", hanem közvetlen ugrás** (D-F6b.8): tap → `selectStandaloneExercise(_:)` / `onStandaloneExerciseSelected(index)` → azonnal vissza a `ControlsPage`-re. Nincs megerősítés, nincs hatása a már logolt szettekre.
- **Android-oldali eltérés a doc szövegétől**: a `LogStatusLine` korábbi `if (isStandalone) { return "standalone_quick_start" } else if (...)` ága **kikerült** — a `display.name`/`display.setsDone`/`display.setsTotal` már mindent kódol, a külön `isStandalone`-ág redundáns és (a template-ág bevezetése után) **helytelen** lett volna, mert mindig „Gyors erőedzés"-t mutatott volna template módban is. A `phone_unreachable` pill `isStandalone`-feltétele változatlanul megmaradt (az egyetlen hely, ahol tényleg a mód, nem a gyakorlat számít).

**Ellenőrzés (elvégezve):** `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'generic/platform=iOS' build` → **BUILD SUCCEEDED**, nulla figyelmeztetés/hiba a két érintett Swift-fájlban. `./gradlew :wear:compileDebugKotlin --rerun` → **BUILD SUCCESSFUL**, nulla figyelmeztetés a projekt saját fájljaiban (az első próbálkozás egy `Icons.Filled.List` deprecation-t adott, az `AutoMirrored` változatra váltva megszűnt — ugyanaz a hibaosztály, mint a T3.3-as `ScalingLazyColumn`-nál). `./gradlew :wear:assembleDebug :app:assembleDebug` → **BUILD SUCCESSFUL** mindkét Android modulra. A lista tényleges vizuális ellenőrzése kerek és négyzetes kijelzőn, élő eszközön a T8 feladata.

---

### T8 — Közös zárás — **lezárva, 2026-07-30**

**Teendő:**
- **Regresszió**: az F6a quick-strength út (`templateId == null`) **bitre változatlan** — ez a legfontosabb védőháló, mert a T5–T7 ugyanazokat a fájlokat érinti, amiket az F6a leszállított. Plusz a phone-mastered F0–F5 út érintetlensége.
- A §8 tesztlistájának élő bejárása mindkét platformon.
- `docs/watch/40-watch-app-plan.md` F6b-sorának státusza.
- Ennek a docnak a fejlécében: implementáció kész dátuma + az eszközön hozott finomítások.

**Build/lint szint (elvégezve):**

- `flutter test` → **392 zöld / 1 bukó**, a bukó a §11/§9-ben már rögzített, F6-tól független `stat_chart_data_test.dart` DST-artefakt. Nincs regresszió a T5 óta változott Dart-kódhoz képest.
- `./gradlew :app:assembleDebug :wear:assembleDebug` → **BUILD SUCCESSFUL**, nulla figyelmeztetés.
- `xcodebuild -workspace Runner.xcworkspace -scheme Runner -destination 'generic/platform=iOS' build` → **BUILD SUCCEEDED**, nulla figyelmeztetés/hiba.

**Élő kézi végpróba: elvégezte a user, fizikai eszközön.** A §8 tesztlistáját ő futtatta végig — a kódolási munka ezzel innentől ennek a doknak a hatókörén kívülre kerül. **A teszt hibákat talált** — ezek javítása **egy külön beszélgetésben** történik, nem ebben a sessionben, és nem ennek a doknak a T-lépései alatt. Ez a doc tehát az F6b **tervezését és az első implementációs kört** zárja le, nem azt állítja, hogy a funkció hibátlanul működik éles használatban.
