# 44 – F6 terv: Standalone edzésindítás a watchról

Státusz: **terv, 2026-07-19 — implementáció nem kezdődött el.**
Ez az a „külön funkcionális tervdoc”, amit a 40-es doc F6-sora és a 42-es doc D4.2/1 pontja előírt. Előfeltétel a 42-es sorrend szerint: az **F5 (43-as doc)** leszállítása — az F6 a log-set kontrollt újrahasznosítja — és az **F6 design-fázis**: [45-watch-f5-f6-design-prompt.md](45-watch-f5-f6-design-prompt.md).

Kapcsolódó dokumentumok:
- [40-watch-app-plan.md](40-watch-app-plan.md) — a fő terv; F6 egy sorban: „Edzés indítása óráról telefon nélkül; a watch lokálisan gyűjt, és kapcsolódáskor a telefon sessiont kreál belőle — külön tervezést igényel (ütközés a resume-prompt logikával)” (§7).
- [41-watch-design-prompt.md](41-watch-design-prompt.md) — §5: az eredeti F6 koncepció-specifikáció (4 frame).
- [42-watch-design-implementation-plan.md](42-watch-design-implementation-plan.md) — D4: design→dev vázlat; ez a doc a részletes kibontása.
- [43-watch-f5-set-logging-plan.md](43-watch-f5-set-logging-plan.md) — a log-set kontroll és a `logSet`-protokoll, amit az F6 lokális módban újrahasznosít.

---

## 1. Cél és scope

**Cél:** a user **telefon nélkül** (otthon hagyta, lemerült, edzőteremben szekrényben) elindíthasson egy strength-edzést az óráról; a watch lokálisan mér és logol; amikor a telefon legközelebb elérhető, a session **magától megjelenik az appban**, mintha ott rögzítették volna.

### Ütemezett al-fázisok

| Al-fázis | Tartalom |
|---|---|
| **F6a** | Quick-start: egyetlen „szabad” strength-session (terv/gyakorlatlista nélkül), lokális szett-számlálással, end-utáni szinkronnal |
| **F6b** | Template-picker: a telefon legutóbbi tervei szinkronizálva az órára; indítás tervből; a szinkronizált gyakorlatlista megjelenítése |
| **F6c** *(nem tervezett, csak nevesített)* | Menet közbeni kézátadás (a telefon élőben átveszi a standalone sessiont) — lásd D-F6.1; v2-ben tudatosan nincs |

### Tudatosan NEM cél

- Élő tükrözés a telefonra standalone mód alatt (D-F6.1).
- Standalone **telepítés** (watch app telefon-app nélkül, Play/App Store-ból) — D-F6.4.
- Gyakorlat-szintű reps/súly-szerkesztés az órán (az F5b stepper-döntését követi, ha az elkészül).
- Edzésterv-**böngészés** a watchon a szinkronizált néhány friss terven túl.

---

## 2. Alapdöntések (D-F6.1 … D-F6.6)

### D-F6.1 — Standalone alatt a watch a mester, a session végéig

A v1-architektúra (telefon = mester, 40-es doc D4) standalone módban megfordul: **amíg a session él, a watch a kizárólagos igazságforrás**; a telefon a kész, lezárt sessiont kapja meg utólag. Ha a telefon a session **közben** válik elérhetővé, akkor sem történik élő kézátadás — a watch végigviszi, és a végén szinkronizál. Ez radikálisan leegyszerűsíti az állapotgépet (nincs menet közbeni master-csere, nincs kétirányú live-merge), és a 40-es doc kézbesítési-garancia mintáira (queue-olt átvitel) épülhet. A kézátadás F6c-ként nevesítve marad, terv nélkül.

### D-F6.2 — Ütközés a telefon-oldali sessionnel és a resume-prompttal

- **Telefon indít, miközben az órán standalone session fut**: a watch a **meglévő `startRejected` úton** utasítja el (40-es doc §5.3 / B12 — „az órán már fut egy edzés”); a telefon-session ettől még zavartalanul fut watch-mérés nélkül. Új kód nem kell, csak az elutasítás-ok (a standalone exercise ugyanúgy foglalja a szenzor-sessiont, mint bármely más appé).
- **Standalone session fut az órán ÉS a telefonon is fut egy session**: két független session — a szinkronkor a standalone külön sessionként jön létre. Nem dedupolunk „ugyanaz az edzés lehetett” alapon (a user explicit két helyen indított — az ő döntése; törölni bármelyiket egy tap).
- **Resume-prompt**: a beérkező standalone session **már lezárva** érkezik (`endedAt` kitöltve), ezért a `WorkoutResumePrompt` „félbe maradt aktív session” detektora **definíció szerint nem** akadhat rá — a feldolgozó (§5) közvetlenül lezárt sessiont ír a repositoryba. Tesztben explicit ellenőrizendő (§8), mert a 40-es doc épp ezt az ütközést jelölte fő kockázatnak.

### D-F6.3 — A standalone session adatmodellje: a meglévő session-séma, új mező nélkül

A szinkronkor a telefon a **meglévő** `WorkoutSession`-t hozza létre a meglévő outbox/sync útra:

- `clientId` = a watch által generált `standaloneSessionId` (UUID). Ez adja az **idempotenciát**: ismételt kézbesítéskor a „létezik-e már session ezzel a clientId-vel” ellenőrzés no-op-ol.
- F6a-ban: cím = lokalizált „Watch workout” (kulcs: `standalone_session_title`), szettek = N darab logolt szett gyakorlat-hozzárendelés nélkül, ahogy a séma engedi (ha a séma gyakorlatot követel, egy generikus „Strength” gyakorlat alá — implementáció elején tisztázandó a Drift-séma ellen).
- F6b-ben: `templateId` alapján a terv gyakorlatai szerint (a watch szett-logjai sorrendben a terv gyakorlataira képezve — a watch a template szinkronizált gyakorlatlistáját lépteti, lásd §4.2).
- Gazdagítás (`activeCalories`, `averageHeartRate`, `healthWorkoutId`) ugyanazokba a mezőkbe, mint a watch-summary ma — a ⌚-badge (B15) ingyen működik.
- **Backend-változás: nincs** — a session a normál outbox-úton szinkronizál a szerverre.

### D-F6.4 — A Wear `standalone` manifest-flag marad `false`

A `com.google.android.wearable.standalone: false` (40-es doc §5.1) a **terjesztésről** szól (telepíthető-e a watch app telefon-app nélkül), nem a futásról — a lokális indításhoz nem kell átállítani. Amíg az app fiók-alapú és a telefon-app a belépési pont, a `true` csak támogatási terhet hozna (telefon-app nélküli telepítések, amikkel nincs mit kezdeni). Ha később app-store-os standalone-terjesztés kell, az külön döntés.

### D-F6.5 — HealthKit / Health Connect írás standalone módban

- **iOS**: változatlan — a watch `HKWorkoutSession`-je a végén `HKWorkout`-ot ment, a `healthWorkoutId` a szinkron-payloadban utazik (a 40-es doc 11.1/1 szerint iOS-en ez mindig is a watch dolga volt).
- **Android**: a meglévő 7.5.7-minta — **a telefon írja a HC-rekordot** a beérkező szinkron-payloadból (`HealthService.writeStrengthWorkoutAndGetId`), a watch csak mér. A standalone-payload `healthWorkoutId`-ja Androidon ezért null-ként érkezik, és a telefon-oldali feldolgozó tölti ki — pontosan, ahogy a watch-summary ma.

### D-F6.6 — Idő-forrás

Standalone módban nincs telefon-`startedAt` — a session ideje **a watch órája** szerint rögzül (`startedAtEpochMs`/`endedAtEpochMs` a payloadban). A watch és a telefon wall-clockja eltérhet; ezt elfogadjuk (a 40-es doc 8.1 idő-eltérés sora ugyanígy döntött), a payload nem hord külön korrekciót.

---

## 3. Watch-oldali munka

### 3.1 Új fázisok és belépési pont

A meglévő fázismodell (IDLE → ACTIVE → ENDING → SUMMARY, ERROR) így bővül:

```
IDLE ──„Start workout” tap──▶ (F6b: PICKER) ──▶ STANDALONE_ACTIVE
STANDALONE_ACTIVE ──End (megerősítéssel)──▶ STANDALONE_SUMMARY (sync-státusszal) ──▶ IDLE
```

- Az **Idle képernyő launcherré válik** (prompt §5/1): a meglévő brand-moment mellé `primary`-fill „Start workout” gomb.
- `STANDALONE_ACTIVE` a meglévő ACTIVE-képernyő **változata**, nem új képernyő: ugyanaz a metrika/rest/controls-szerkezet + diszkrét „not connected/standalone” jelző + a **lokális** log-set kontroll (az F5 UI-ja, de a `logSet` üzenet helyett lokális számláló-inkrement — itt nincs PENDING/ack, a tap azonnal CONFIRMED).
- **Nincs telefon-vezérelt rest** standalone módban — v1-döntés: a watch a szett-logoláskor **saját, fix hosszú** rest-visszaszámlálót indít (alapérték: 90 s; F6b-ben a template hordozhat rest-hosszt, ha a szinkron-payloadba belefér). A meglévő rest-hero/GO/haptika kód újrahasznosul, csak a deadline forrása lokális.
- `ENDING` fázis standalone-ban **nincs** (nincs kire várni) — az End megerősítés után egyből zárás + `STANDALONE_SUMMARY`.

### 3.2 Lokális perzisztencia és folytatás

- **Pending-session tár**: a lezárt, még nem szinkronizált sessionök listája — watchOS: JSON-fájl az app konténerében (`Application Support`); Wear: `SharedPreferences`/DataStore (a `WatchSummaryBuffer` telefon-oldali mintájára). Egy elem = a teljes szinkron-payload (§4.1). Sikeres ack után törlődik.
- **Élő session túlélése**: process-halál/reboot ellen — watchOS: `HKHealthStore.recoverActiveWorkoutSession` induláskor + a session-meta (startedAt, szett-log) folyamatos kiírása a lokális tárba; Wear: a Health Services exercise a service-t túléli, induláskor `ExerciseClient` állapot-lekérdezés + ugyanaz a meta-kiírás. Ha az app úgy indul, hogy élő standalone exercise van, `STANDALONE_ACTIVE`-ba tér vissza.
- Több pending session felhalmozódhat (a user kétszer edz, mire a telefon előkerül) — a tár lista, a szinkron sorban küldi őket.

### 3.3 Template-szinkron fogadása (F6b)

- A telefon által pusholt template-lista (§4.2) lokális cache-be kerül (ugyanaz a tár, külön kulcs); a PICKER ebből épül. Ha a cache üres (sosem volt telefon-kapcsolat a legutóbbi frissítés óta), a PICKER csak a „Quick strength” elemet mutatja — az F6a-flow mindig működik.
- A lista frissessége best-effort: a picker jelezheti a cache korát nem kell hozzá UI-döntés a design előtt.

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
  "sets": [ { "loggedAtEpochMs": 0, "exerciseIndex": null } ],
  "activeCalories": 0.0,
  "averageHeartRate": 0.0,
  "healthWorkoutId": "<iOS: HKWorkout uuid; Android: null>"
}
```

- **Átvitel**: iOS — `transferUserInfo` (pontosan a summary-minta: sorban áll, kézbesít, amint a telefon elérhető, akár napokkal később); Android — `MessageClient`-küldés kapcsolódáskor (`onPeerConnected`/app-indulás trigger) + a lokális pending-tárból retry, amíg ack nem jön; a DataItem-út best-effort tartalék marad (a 7.5.2-megbízhatatlanság miatt nem elsődleges).
- **Ack**: a telefon `standaloneSessionAck { standaloneSessionId }` üzenetet küld sikeres (vagy idempotensen dedup-olt) feldolgozás után; a watch ekkor törli a pending-elemet. Ack nélkül a payload a tárban marad és újraküldődik.
- `exerciseIndex`: F6a-ban null; F6b-ben a szinkronizált template gyakorlatlistájának indexe (a watch csak indexet küld, a nevek/azonosítók feloldása a telefoné — a payload kicsi marad).

### 4.2 `templateSync` (telefon → watch, F6b)

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

- Küldés: app-indításkor és terv-módosításkor, a legutóbbi legfeljebb ~5 terv. iOS: `updateApplicationContext` (a state-sync mellett, külön kulcs alatt) — a rendszer a legfrissebbet kézbesíti; Android: message-alapú push (a 7.5.2-tanulság szerint a teljes payload az üzenetben) + DataItem best-effort.
- Ez az **első telefon→watch adatirány a session-state-en kívül** — a Dart-oldalon új `WatchWorkoutService`-metódust igényel (§5/3), de a natív csatornák meglévők.

---

## 5. Telefon-oldali munka (Dart + natív híd)

1. **Natív fogadók**: iOS — a `Runner/WatchBridge.swift` `didReceiveUserInfo`-ja már fogad userInfo-t (summary); a `standaloneSessionCompleted` típust ugyanígy relézi az EventChannel-re. Android — a meglévő telefon-oldali `WearableListenerService` + `WatchSummaryBuffer`-minta **kiterjesztve**: a standalone-payload is pufferelődik, ha a Flutter engine nem fut (ez itt, a summary-val ellentétben, alapkövetelmény — a telefon jellemzően zsebben/táskában kerül elő).
2. **`watch_workout_service.dart`**: új eseménytípus `WatchStandaloneSession(payload)` + `ackStandaloneSession(standaloneSessionId)` metódus + `syncTemplates(templates)` metódus (F6b).
3. **Feldolgozó** (a `WorkoutResumePrompt` induláskori sweep-jén ÉS élő eseményként — a summary-feldolgozó ikertestvére):
   - idempotencia-guard: ha már létezik session `clientId == standaloneSessionId`, csak ack (§ D-F6.3);
   - session-létrehozás lezárt állapotban a repository-n át (outbox-ra kerül, normál sync viszi a backendre);
   - Android-ág: HC-írás a 7.5.7-úton, `healthWorkoutId` kitöltése;
   - ack küldése a natív hídon át.
4. **Template-push hívási pontjai** (F6b): app-indulás + terv-mentés/-módosítás után; a kapuzás a meglévő `watchWorkoutEnabled` settings-kapcsolóval közös.
5. **UI**: a session a listában a meglévő ⌚-badge-dzsel jelenik meg (B15 — nincs új UI-elem); opcionális finomítás: a badge-tooltip standalone esetben is helytálló („Órán mérve”).

---

## 6. Engedélyek és korlátok

- **watchOS**: a HealthKit-engedélyt eddig is a watch kérte első használatkor — standalone-nál ez az egyetlen kérési pont (nincs telefon-onboarding előtte). A `healthDenied` képernyő (B10) változatlanul kezeli a megtagadást, csak most az indítási flow-ból is elérhető.
- **Wear OS**: `BODY_SENSORS`/`ACTIVITY_RECOGNITION`/`health.READ_HEART_RATE` runtime-kérések (7.5.3) — a launcher „Start workout” tapja előtt kell lefusson, a `MainActivity` meglévő engedély-flow-jával.
- **Akku/kijelző**: semmi új az F4-hez képest — ugyanaz az exercise-session fut, csak a trigger más.

---

## 7. Amit a design-fázisnak kell eldöntenie (a 45-ös prompt bemenete)

1. **Idle → launcher** kompozíció: hogyan fér el a brand-moment ÉS a Start-gomb a kerek kijelzőn (prompt §5/1).
2. **Picker** (F6b): lista-stílus, „Quick strength” kiemelése, cache-kor jelzése kell-e.
3. **Standalone-jelző** az aktív képernyőn: mennyire legyen hangsúlyos a „not connected” (javaslat: diszkrét — ez normál üzemmód, nem hiba).
4. **Sync-státusz a summary-n**: „Will sync to phone” kártya, pending (muted glyph) vs. synced (`tertiary` check) állapotpár (prompt §5/4) — és hogy a pending-lista (több felhalmozott session) látszik-e valahol, vagy a szinkron teljesen néma.

---

## 8. Tesztelési terv

- **Dart unit**: standalone-feldolgozó — idempotencia (dupla kézbesítés → egy session, két ack), lezártként jön létre (resume-prompt nem triggerel), Android-ági HC-írás + `healthWorkoutId`-kitöltés, template-push serializálás.
- **iOS manuális** (szimulátorpár): standalone start → lokális szettek + rest → end → telefon elérhetővé válik → session megjelenik az appban badge-dzsel; telefon-app kilőve a szinkron alatt → következő indításkor feldolgozódik; watch-app kilövése aktív standalone session alatt → recovery; telefon közben indít edzést → `startRejected`.
- **Wear manuális** (emulátorpár): ugyanezek + több pending session felhalmozása és sorban szinkronizálása; `standaloneSessionAck` elvesztése → újraküldés → dedup.
- **Regresszió**: a phone-mastered flow (F0–F5) bitre azonos; a resume-prompt sweep viselkedése változatlan telefon-oldali árva sessionökre.

---

## 9. Ütemezés és becslés

| Ütem | Tartalom | Becslés | Előfeltétel |
|---|---|---|---|
| F6-design | A 45-ös prompt F6-fele (4+4 frame) + a §7 döntések | M | F5-design (a log-set kontroll újrahasznosítása miatt) |
| F6a | Launcher + quick-start, lokális rögzítés + pending-tár, szinkron-protokoll + telefon-oldali feldolgozó, teszt | L | F5a (lokális log-set kontroll), F6-design |
| F6b | Template-szinkron + picker + exercise-léptetés | M | F6a |

---

## 10. Nyitott kérdések

1. **Fix rest-hossz F6a-ban** (§3.1): 90 s jó default? Legyen-e az órán állítható (rotary/crown) még F6a-ban, vagy az már F5b/F6b-terület? Javaslat: fix 90 s, állítás később.
2. **Drift-séma és a gyakorlat nélküli szettek** (D-F6.3): az implementáció legelső lépéseként ellenőrizendő, hogy a séma engedi-e — ha nem, a generikus „Strength” gyakorlat-sor a megoldás, és az F6a-becslés nem változik.
3. **Szinkron némasága** (§7/4): kapjon-e a user telefon-oldali visszajelzést (snackbar/notification) arról, hogy „bejött egy edzés az órádról”? Javaslat: v1-ben néma (a session-listában úgyis látszik), de a design-fázis mondhat mást.
4. **Template-lista mérete/frissítése** (§4.2): elég-e az 5 legutóbbi terv és a két push-pont? Ha a tervek nagyok (sok gyakorlat), payload-limit ellenőrzés kell (Data Layer üzenet-limit ~100 KB — bőven belefér, de rögzítsük).
