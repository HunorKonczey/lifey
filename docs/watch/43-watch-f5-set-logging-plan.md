# 43 – F5 terv: Set-logolás a watchról

Státusz: **terv, 2026-07-19 — implementáció nem kezdődött el.**
Előfeltétel a 42-es doc sorrendje szerint: a D2 (F4 design-styling) lezárása és az **F5 design-fázis** (a canvasban ma nincs F5-frame) — a design-prompt: [45-watch-f5-f6-design-prompt.md](45-watch-f5-f6-design-prompt.md).

Kapcsolódó dokumentumok:
- [40-watch-app-plan.md](40-watch-app-plan.md) — a fő terv; az F5 egy sorban: „«+1 szett» gomb a watchon → esemény a telefonra → a telefon logolja (a telefon marad a mester); offline eset: csak ha a telefon elérhető” (§7). A D3-csatornaterv már nevesíti a `setLoggedOnWatch` eseményt.
- [41-watch-design-prompt.md](41-watch-design-prompt.md) — az eredeti design-prompt §4-e az F5 koncepció-specifikáció (4 frame).
- [42-watch-design-implementation-plan.md](42-watch-design-implementation-plan.md) — D3 fejezet: az F5 design→dev lebontás vázlata; ez a doc azt részletezi ki.
- [45-watch-f5-f6-design-prompt.md](45-watch-f5-f6-design-prompt.md) — az F5/F6 canvas-bővítés önhordó design-promptja.

---

## 1. Cél és scope

**Cél:** a user a szett befejezése után **az óráról, egyetlen tappal** logolhassa a szettet, telefon-elővétel nélkül. A telefon marad a mester: a watch csak eseményt küld, a tényleges logolás (Drift-írás, rest-indítás, state-frissítés) a telefonon történik, és az eredmény a meglévő state-sync útján ér vissza az órára.

### V1 scope (F5a)

1. Log-set kontroll az aktív képernyőn (elhelyezés: design-fázis dönti, javaslat lent, §3.1).
2. `logSet` esemény watch → telefon, dedup-lal és ack-kal (§4).
3. A telefon a **saját aktuális pozíciója szerinti következő szettet** logolja — a watch nem választ gyakorlatot és nem küld reps/súly adatot.
4. Megerősítés-feedback az órán (pill-increment + haptika) és hibafeedback (telefon nem elérhető / timeout).

### V1-ben tudatosan NEM cél

- **Reps/súly-állítás a watchról** (crown/rotary stepper) — F5b, külön ütem, csak az F5a bevált egy-tapos flow-ja után (a 41-es prompt §4/3 szerint is „clearly secondary”).
- Offline set-logolás (nem elérhető telefon melletti queue-olás) — a 40-es doc F5-sora explicite kizárja; a nem-elérhető állapot **hibaút**, nem funkció.
- Gyakorlat-váltás / edzésterv-navigáció a watchról.
- Kilőtt telefon-app melletti logolás (lásd §7.3 — v1-ben hibaút).

---

## 2. Alapelv: a watch buta trigger, a telefon az igazság forrása

A 40-es doc D4-döntése (telefon = mester) itt is érvényes, és ez oldja fel a konfliktuskezelést:

- A watch **nem inkrementál lokálisan hitelesként** — a szett-számláló a telefonról visszaérkező state-syncből frissül (`setsDone` a meglévő `WorkoutSessionState`-ben). A watch legfeljebb **átmeneti „pending” állapotot** mutat a tap és az ack/state-frissülés között (§3.2).
- Ha a user **egyszerre** logol telefonon és órán, nincs merge-probléma: két `logSet`-ekvivalens művelet fut le a telefonon egymás után (kettőt logol), pontosan úgy, mintha kétszer nyomta volna meg a telefon gombját. A dedup (§4.2) csak a **ugyanazon watch-tap** duplikált kézbesítése ellen véd, nem szándékolt dupla logolás ellen.
- A „melyik gyakorlat, hányadik szett” kérdést kizárólag a telefon `LogSessionScreen`-je dönti el a saját aktuális állapotából — a watch payloadja ezt nem is tartalmazza.

---

## 3. UX-viselkedés (a design-fázis bemenete)

### 3.1 A kontroll elhelyezése — javaslat

A jelenlegi képernyőszerkezet **mindkét platformon 2-lapos pager** (iOS: `TabView` + `.page`; Wear: `HorizontalPager` + `PageDots` — 40-es doc 7.5.9/B7), és a metrika-lapon **szándékosan nincs semmilyen gomb** (a Wear-oldali körvágás-tapasztalat miatt). Az F5 ezt a szabályt kénytelen érinteni. Opciók:

| Opció | Mellette | Ellene |
|---|---|---|
| (a) Nagy alsó gomb a metrika-lapon | „A legkönnyebb tap az egész órán” (prompt §4/1) — lapozni sem kell | Újranyitja a Wear-oldali körvágás-problémát; a metrika-lap zsúfoltabb |
| (b) Külön, harmadik lap a pagerben (metrika ↔ **log** ↔ controls) | Illik a meglévő mintába; a log-lap egyetlen óriási gomb lehet (teljes tap-target) | Egy lapozás izzadt kézzel a tap előtt |
| (c) Hardver-interakció (crown/rotary-nyomás, dupla-tap gesztus) | Nulla UI-hely | watchOS-en a crown-press rendszer-foglalt; Wear-en gyártófüggő; felfedezhetetlen |

**Javaslat: (b)**, a log-lap a pager **első** lapja legyen (log ↔ metrika ↔ controls), mert szettek között úgyis oda nyúl a user — de ez pontosan az a döntés, amit a design-fázisnak (45-ös prompt, F5/1 frame) kell vizuálisan validálnia, mindkét platformon. A (a) opciót a designer akkor válassza, ha meg tudja oldani a kerek kijelzőn a körvágás nélküli elrendezést.

### 3.2 A tap utáni életciklus (watch-oldali mikro-állapotgép)

```
READY ──tap──▶ PENDING ──ack (≤5 s)──▶ CONFIRMED (1–1,5 s) ──▶ READY
                  │                       (pill 2/4→3/4, positive-villanás,
                  │                        success-haptika; ha a telefon
                  │                        rest-et indított: rest-hero átmenet)
                  ├──timeout (5 s)──▶ FAILED (hibaszöveg + haptika) ──▶ READY
                  └──nincs elérhető telefon már a tap előtt──▶ a gomb ghosted,
                       „Phone not reachable” magyarázat (READY-be visszatér,
                       amint a reachability helyreáll)
```

- **PENDING alatt a gomb inaktív** (ez a dupla-tap elleni első védvonal; a debounce a második, §4.2).
- A CONFIRMED-feedback akkor is a **visszaérkező state-ből** (vagy explicit ack-ból) táplálkozik, ha vizuálisan optimista animációnak tűnik — a pill soha nem mutat olyan értéket, amit a telefon nem erősített meg.
- Ha a logolás rest-indítást vált ki a telefonon (tipikus eset), a state-syncben megjövő `restEndsAtEpochMs` a meglévő úton átviszi a UI-t a rest-heróba — a CONFIRMED→rest-hero láncolt átmenetet a design rajzolja meg (prompt §4/2).

### 3.3 Fázis-kapuzás

- A kontroll csak `ACTIVE` fázisban él; `ENDING`/`SUMMARY`/`ERROR`/`IDLE` alatt nem létezik.
- **Pause alatt**: a gomb maradjon aktív — a pause csak a szenzor-sessiont érinti (B3), a telefon-oldali logolást nem. A design jelezze a pauzált kontextust, de ne tiltsa a logolást.
- **Rest alatt**: a gomb maradjon elérhető (a user rövidítheti a pihenőt és logolhat korábban) — a telefon-oldali viselkedés (rest-újraindítás/-elvetés) a telefon meglévő set-logolási logikáját követi, a watch ebbe nem szól bele. Ha a (b) elhelyezés nyer, ez ingyen megvan (a log-lap rest alatt is odalapozható); ha az (a), a rest-hero tetején/alján kell neki hely.
- `setsDone == setsTotal` esetén a gomb **nem tiltódik le** — a telefon-app ma is enged terven felüli szettet logolni; a watch itt sem okosabb a telefonnál.

### 3.4 Lokalizációs kulcsok (HU/EN, a meglévő kézi szinkron-minta szerint)

| Kulcs | EN | HU |
|---|---|---|
| `log_set_button` | `+1 set` | `+1 szett` |
| `log_set_pending` | `Logging…` | `Logolás…` |
| `log_set_failed` | `Couldn't log — try again` | `Nem sikerült — próbáld újra` |
| `phone_unreachable` | `Phone not reachable` | `A telefon nem érhető el` |

(A pontos copy a design-fázis kimenete; Androidon `values/strings.xml` + `values-en/strings.xml`, iOS-en `Localizable.xcstrings`, azonos kulcsnevekkel — 40-es doc 8.2/3 döntése szerint.)

---

## 4. Protokoll

### 4.1 Új üzenet: `logSet` (watch → telefon)

```json
{
  "type": "logSet",
  "sessionClientId": "…",
  "eventId": "<watch-generálta UUID>",
  "loggedAtEpochMs": 1234567890123
}
```

- **Nincs** reps/súly/gyakorlat mező (v1) — lásd §2.
- iOS: `WCSession.sendMessage` (a watch `PhoneConnector`-jából, a meglévő `endRequested`/`startRejected` mintájára). A `sendMessage` a háttérben lévő telefon-appot is felébreszti — ez iOS-en kiterjeszti a „telefon elérhető” esetek körét.
- Android: `MessageClient.sendMessage` a `SummarySender` meglévő mintájára; a telefon-oldali fogadó a meglévő `WearableListenerService`-útvonal.

### 4.2 Dedup és debounce

- **Watch-oldali debounce**: PENDING alatt a gomb inaktív (§3.2) + 300 ms-os tap-debounce a gyors dupla-érintés ellen.
- **Telefon-oldali dedup**: a feldolgozó session-enként megjegyzi az utolsó N (elég: 8) feldolgozott `eventId`-t memóriában; ismételt `eventId` no-op, de **újra ack-olódik** (hogy a watch retry-a is lezárhassa a PENDING-et). Perzisztálni nem kell — a dedup csak a kézbesítési retry ablakát fedi, nem napokat.

### 4.3 Ack: explicit válasz, nem a state-syncből kikövetkeztetve

A telefon a sikeres (vagy dedup-olt) logolás után **explicit ack-üzenetet** küld vissza:

```json
{ "type": "logSetAck", "eventId": "…", "accepted": true }
```

- Miért nem elég a state-sync mint implicit ack: a `setsDone`-inkrement nem korrelálható egy konkrét tap-hez (párhuzamos telefon-oldali logolás összemoshatja), és Androidon a state-csatorna amúgy is best-effort rétegekre épül (40-es doc 7.5.2). Az explicit ack olcsó és egyértelmű.
- `accepted: false` esetei: nincs ilyen aktív session (`sessionClientId` nem egyezik), vagy a Dart-oldal nem tud logolni (pl. a session épp záródik) — a watch FAILED-et mutat.
- A state-sync ettől függetlenül, változatlanul megy — az frissíti a pillt és indítja a rest-herót.

### 4.4 Elérhetőség-detektálás

- **iOS**: a meglévő `WCSession.isReachable` + a már bekötött `reachabilityChanged` esemény — a gomb ghosted állapota ebből táplálkozik.
- **Android**: nincs megbízható folyamatos reachability-jel (a `CapabilityClient` bizonyíthatóan megbízhatatlan — 40-es doc 7.5.5; a Dart-oldali `WatchReachabilityChanged` Androidon sosem tüzel — 12.4/B14). **Ezért Androidon a küldés optimista**: a gomb alapból aktív, és a hibát az ack-timeout jelzi (§3.2). Best-effort előszűrés: ha a `NodeClient.getConnectedNodes()` üres, a gomb már a tap előtt ghosted — de erre nem építünk garanciát.

---

## 5. Dart-oldali munka

1. **`watch_workout_service.dart`**: új eseménytípus `WatchSetLogged { sessionClientId, eventId, loggedAtEpochMs }` a meglévő `WatchWorkoutSummary`/`WatchEndRequested`/… dekóder-minta szerint; + új metódus a natív híd felé az ack visszaküldésére (`ackSetLogged(eventId, accepted)` a `lifey/watch` MethodChannel-en).
2. **`LogSessionScreen`**: a `WatchSetLogged` eseményt a **meglévő set-logolási útra** köti (ugyanaz a kódút, mint a képernyő saját „log set” gombja — rest-indítással, state-sync-frissítéssel együtt), majd ack-ol. Guard: csak akkor logol, ha az esemény `sessionClientId`-ja a képernyő aktív sessionjével egyezik; különben `accepted: false`.
3. **Dedup-tár**: a `LogSessionScreen`-state-ben (vagy a service-ben) az utolsó 8 `eventId` — lásd §4.2.
4. **Unit tesztek** a meglévő fake-channel mintával: `WatchSetLogged` dekódolás, dedup (ismételt eventId → egy logolás, két ack), session-mismatch → `accepted: false`.

---

## 6. Natív munka

### 6.1 watchOS (`mobile/ios/LifeyWatch/`)

- `PhoneConnector`: `sendLogSet(eventId:)` (`sendMessage`, reply-handler nélkül — az ack külön üzenetként jön a meglévő `didReceiveMessage`-be) + `logSetAck` fogadása → `WorkoutManager`-be.
- `WorkoutManager`: a §3.2 mikro-állapotgép (`logSetState: ready/pending/confirmed/failed` published property + 5 s timeout-`Task` + haptikák — success: `.success`, fail: `.failure`).
- `ActiveWorkoutView`: az elhelyezés-döntés szerinti UI (javaslat: új első lap a `TabView`-ban); a `NSNull`-sanitizálás (11.5/1) itt nem játszik, mert a payload minden mezője kötelező.
- Telefon-oldal (`Runner/WatchBridge.swift`): `logSet` üzenet → EventChannel; `ackSetLogged` MethodChannel-hívás → `sendMessage` vissza a watchnak.

### 6.2 Wear OS (`mobile/android/wear/`)

- `SummarySender`: `sendLogSet(eventId)` a meglévő küldő-minta szerint.
- `SessionStateHolder`: a §3.2 mikro-állapotgép `StateFlow`-ként; timeout-ütemezés az `ExerciseService`-ben futó coroutine-nal (a rest-haptika `Job`-mintájára — a UI-tól függetlenül él).
- `PhoneListenerService`: `logSetAck` üzenet fogadása → `SessionStateHolder`.
- Haptika: `Vibrator` a meglévő rest-haptika mintájára (rövid dupla success-pattern / hosszabb fail).
- `ActiveWorkoutScreen`: az elhelyezés-döntés szerinti UI (javaslat: harmadik pager-lap + a `PageDots` 3-pontosra bővítése).
- Telefon-oldal (`WatchBridge.kt` + a meglévő listener service): `logSet` → EventChannel; ack visszaküldése `MessageClient`-tel.

---

## 7. Hibautak és edge case-ek

| # | Eset | Viselkedés |
|---|---|---|
| 7.1 | Ack-timeout (telefon nem válaszol 5 s-en belül) | FAILED-feedback az órán; a telefon **lehet, hogy mégis logolt** (az ack veszett el) — a user a visszaérkező state-syncből (pill-érték) látja az igazságot; a retry-tap új `eventId`-t kap, tehát tényleg új szettet logol. Ezt a maradék kockázatot v1-ben elfogadjuk (a set-logolás a telefonon egy tappal korrigálható). |
| 7.2 | `sessionClientId`-mismatch (a telefonon már másik/semmilyen session fut) | `accepted: false` → FAILED. A következő state-sync/end úgyis rendbe rakja a watch fázisát. |
| 7.3 | Telefon-app kilőve | iOS: a `sendMessage` háttérben felébreszti az appot — ha a Flutter engine és a `LogSessionScreen` már nem áll fel időben aktív sessionnel, az eset a 7.2-be fut. Android: a `WearableListenerService` felébred, de Flutter engine nélkül nincs ki logoljon → nincs ack → 7.1. **V1-döntés: ez hibaút**, nem buffereljük a logSet-et (ellentétben a summary-val) — egy „log” parancsnak friss kontextus kell. |
| 7.4 | Dupla kézbesítés (transport-retry) | Telefon-oldali `eventId`-dedup (§4.2) — egy logolás, ismételt ack. |
| 7.5 | Pause alatt tap | Logolódik (§3.3) — a pause csak szenzor-ügy. |
| 7.6 | Rest alatt tap | Logolódik; a rest-kezelés a telefon meglévő logikája szerint (§3.3). |

---

## 8. Tesztelési terv

- **Dart unit** (fake channel): lásd §5/4.
- **iOS manuális** (watchOS-szimulátor + iOS-szimulátor pár): tap → telefon logol → pill frissül → rest-hero lánc; dupla-gyors-tap → egy szett; telefon-app háttérben → működik; telefon-app kilőve → FAILED; repülő módú telefon → ghosted gomb (reachability). |
- **Wear manuális** (emulátorpár): ugyanezek + ack-timeout szimulálása (telefon-app kilőve → FAILED 5 s után); `getConnectedNodes` üres eset.
- **Regresszió**: F4-viselkedés watch-tap nélkül bitre azonos; a 3-lapos pager nem töri a meglévő GO-flash/rest-hero átmeneteket.

---

## 9. Ütemezés és becslés

| Ütem | Tartalom | Becslés |
|---|---|---|
| F5-design | A 45-ös prompt F5-fele (4+4 frame) + elhelyezés-döntés (§3.1) lezárása | M |
| F5a | Protokoll (§4) + Dart (§5) + mindkét natív oldal (§6) + teszt (§8) | M–L |
| F5b | Reps/súly-stepper (crown/rotary) — csak F5a-tapasztalat után, külön mini-terv | M |

Az F5a a két natív oldalon párhuzamosítható (a Dart-oldal és a protokoll közös előfeltétel).

---

## 10. Nyitott kérdések (design-/implementáció-előtti döntések)

1. **Kontroll-elhelyezés** (§3.1 a/b/c) — a design-fázis zárja le, mindkét platformra. Javaslat: (b), log-lap elöl.
2. **Rest alatti elérhetőség** vizuális formája — ha (a) opció nyer, hol fér el a rest-herón?
3. **FAILED-copy**: megkülönböztessük-e a „telefon nem elérhető” és az „elutasítva” esetet a watchon, vagy elég egy közös hibaszöveg? Javaslat: két külön kulcs (§3.4), mert a teendő más (közelebb menni vs. telefont elővenni).
4. **Ack-timeout értéke**: 5 s a javaslat — emulátor-tapasztalat alapján kalibrálandó (a Wear-emulátorpár üzenet-latencyje ismerten szeszélyes).
