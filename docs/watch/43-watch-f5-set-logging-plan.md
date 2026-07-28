# 43 – F5 terv: Set-logolás a watchról

Státusz: **F5a KÉSZ, 2026-07-26** — mindkét platform kódja lezárva (S1–S13), és a kézi végpróbák (S9 iOS, S14 Android) is lefutottak: a fejlesztő eszközön visszaigazolta, hogy a flow működik. A §10 nyitott kérdései lezárva (lentebb).

> **Ismert korlát, nem hiba:** ha a gyakorlatnak nincs több kitöltetlen tervezett sora (vagy terv nélkül, ad-hoc került fel), minden watch-tap **üres** (súly/ismétlés nélküli) szettet rögzít — a watch nem küld értéket, a telefon pedig azt logolja, ami a sorban van (§5.2/4, §3.3 „terven felüli szett”). Ez az F5a szándékos scope-korlátja; a feloldása az **F5b**: [48-watch-f5b-set-adjust-plan.md](48-watch-f5b-set-adjust-plan.md).
Az F5 design-frame-ek megvannak a canvasban (`docs/watch/design/Lifey Watch Design.dc.html`: **AW 08–11**, **W 07–10**, „F5 — set logging from the watch (v2)” szekció + az „F5/F6 string keys” tábla). Ez a doc a designhoz szinkronizálva van; a §11 a lépésenkénti fejlesztési terv, ami alapján iOS és Android párhuzamosan vihető.

Kapcsolódó dokumentumok:
- [40-watch-app-plan.md](40-watch-app-plan.md) — a fő terv; az F5 egy sorban: „«+1 szett» gomb a watchon → esemény a telefonra → a telefon logolja (a telefon marad a mester); offline eset: csak ha a telefon elérhető” (§7). A D3-csatornaterv már nevesíti a `setLoggedOnWatch` eseményt.
- [41-watch-design-prompt.md](41-watch-design-prompt.md) — az eredeti design-prompt §4-e az F5 koncepció-specifikáció (4 frame).
- [42-watch-design-implementation-plan.md](42-watch-design-implementation-plan.md) — D3 fejezet: az F5 design→dev lebontás vázlata; ez a doc azt részletezi ki.
- [45-watch-f5-f6-design-prompt.md](45-watch-f5-f6-design-prompt.md) — az F5/F6 canvas-bővítés design-promptja (teljesítve).
- [44-watch-f6-standalone-plan.md](44-watch-f6-standalone-plan.md) — az F6 a log-kontrollt „local mode”-ban újrahasznosítja (§2.1 alább), ezért az F5a állapotgépét úgy kell megírni, hogy a „pending” fázis kihagyható legyen.
- [48-watch-f5b-set-adjust-plan.md](48-watch-f5b-set-adjust-plan.md) — az **F5b** (reps/súly állítása a watchról) részletes terve: a §12 crown/rotary-ütközés feloldása, a stepper kezdőértékének protokoll-bővítése, és a lépésenkénti fejlesztési terv. Az F5a **után** indítható.

---

## 0. Design-szinkron napló (2026-07-25)

Mi változott a designhoz képest ebben a docban:

| # | Terület | Korábbi doc-állapot | Design (canvas) | Mostani doc-állapot |
|---|---|---|---|---|
| 0.1 | Kontroll elhelyezése | nyitott kérdés, (b) javaslat | **(b) eldöntve**: dedikált log-lap, sorrend **log ↔ metrika ↔ controls**, pöttyök 2 → 3 | §3.1 lezárva, §10/1 törölve |
| 0.2 | Kezdőlap | nem volt kimondva | a log-lap a **pager 1. lapja**, csuklóemelésre ez jön elő | §3.1 + §10/1 (új nyitott kérdés a rest-lel való interakcióra) |
| 0.3 | Copy: `log_set_pending` HU | „Logolás…” | **„Naplózás…”** | §3.4 frissítve (a design a mérvadó) |
| 0.4 | `log_set_logged` kulcs | hiányzott | **„Logged” / „Naplózva”** | §3.4-be felvéve |
| 0.5 | Hiba-copy szétválasztása | nyitott kérdés (§10/3) | **két külön állapot**: tap előtt ghosted + `phone_unreachable`, tap után `errorContainer` toast `log_set_failed`, ~2,5 s | §3.2/§3.4 lezárva, §10/3 törölve |
| 0.6 | CONFIRMED vizuál | „pill-increment + haptika” | check-ikon + **„Set 3 of 4”** a gyűrűben + „Logged” pill + scale-pop | §3.2 pontosítva |
| 0.7 | Rest-átmenet | „láncolt átmenet” | **350 ms** láncolt rest-takeover | §3.2 pontosítva |
| 0.8 | F5b (reps/súly) | csak említés | **kirajzolva** (AW 10 / W 09): crown/rotary forgatásra jelenik meg a log-lapon, 2 s tétlenség után eltűnik, `log_adjust_*` kulcsok | §9 + §12 (technikai ütközés a lapozó crown/rotary-használatával) |
| 0.9 | Wear reachability | „optimista küldés, `CapabilityClient` megbízhatatlan” | W 10 jegyzete `CapabilityClient`-et ír | **Konfliktus — a mérnöki döntés marad** (§4.4); a design vizuális állapota változatlanul él |
| 0.10 | Log-lap kontextussor | nem szerepelt | „Bench Press · Set 2 of 4” a gomb alatt | §3.4-be új kulcs javasolva (`log_set_context_format`) — a design kulcslistájából hiányzik |

Ami a designból **nem** került be és miért: semmi. Az F5b-t a design megrajzolta, de az ütemezés (F5a után, külön mini-terv) nem változott (§9).

---

## 1. Cél és scope

**Cél:** a user a szett befejezése után **az óráról, egyetlen tappal** logolhassa a szettet, telefon-elővétel nélkül. A telefon marad a mester: a watch csak eseményt küld, a tényleges logolás (Drift-írás, rest-indítás, state-frissítés) a telefonon történik, és az eredmény a meglévő state-sync útján ér vissza az órára.

### V1 scope (F5a)

1. Dedikált **log-lap** az aktív képernyő pagerében, a lapok elején (§3.1 — design AW 08 / W 07).
2. `logSet` esemény watch → telefon, dedup-lal és ack-kal (§4).
3. A telefon a **saját aktuális pozíciója szerinti következő szettet** logolja — a watch nem választ gyakorlatot és nem küld reps/súly adatot (§5.2).
4. Megerősítés-feedback az órán (check + számláló-inkrement + haptika) és hibafeedback (telefon nem elérhető / timeout).

### V1-ben tudatosan NEM cél

- **Reps/súly-állítás a watchról** (crown/rotary stepper) — F5b, külön ütem, csak az F5a bevált egy-tapos flow-ja után (a 41-es prompt §4/3 és a design AW 10 jegyzete szerint is „secondary”).
- Offline set-logolás (nem elérhető telefon melletti queue-olás) — a 40-es doc F5-sora explicite kizárja; a nem-elérhető állapot **hibaút**, nem funkció.
- Gyakorlat-váltás / edzésterv-navigáció a watchról.
- Kilőtt telefon-app melletti logolás (lásd §7.3 — v1-ben hibaút).

---

## 2. Alapelv: a watch buta trigger, a telefon az igazság forrása

A 40-es doc D4-döntése (telefon = mester) itt is érvényes, és ez oldja fel a konfliktuskezelést:

- A watch **nem inkrementál lokálisan hitelesként** — a szett-számláló a telefonról visszaérkező state-syncből frissül (`setsDone`/`setsTotal` a meglévő `WorkoutSessionState`-ben). A watch legfeljebb **átmeneti „pending” állapotot** mutat a tap és az ack/state-frissülés között (§3.2).
- Ha a user **egyszerre** logol telefonon és órán, nincs merge-probléma: két `logSet`-ekvivalens művelet fut le a telefonon egymás után (kettőt logol), pontosan úgy, mintha kétszer nyomta volna meg a telefon gombját. A dedup (§4.2) csak a **ugyanazon watch-tap** duplikált kézbesítése ellen véd, nem szándékolt dupla logolás ellen.
- A „melyik gyakorlat, hányadik szett” kérdést kizárólag a telefon `LogSessionScreen`-je dönti el a saját aktuális állapotából (§5.2) — a watch payloadja ezt nem is tartalmazza.

### 2.1 F6-kompatibilitás (előre nézve)

A 44-es doc szerint standalone módban ugyanez a kontroll fut „local mode”-ban: **nincs PENDING, azonnali CONFIRMED**, a számláló lokálisan nő. Ezért az F5a állapotgépét (§3.2) úgy kell megírni, hogy a PENDING→CONFIRMED átmenet forrása cserélhető legyen (ack helyett azonnali lokális megerősítés) — konkrétan: a `logSet()` belépési pontban egy `mode`-elágazás, ne szétszórt `if`-ek a UI-ban.

---

## 3. UX-viselkedés (a design szerint)

### 3.1 A kontroll elhelyezése — **eldöntve: (b), dedikált log-lap elöl**

A design (AW 08 / W 07 + a szekció „Placement rationale” bekezdése) az opciók közül a **(b)**-t választotta:

- A pager **3 lapos** lesz: **0 = log**, **1 = metrika/rest**, **2 = controls**. (Ma: 0 = metrika/rest, 1 = controls.)
- Indoklás a designból: az (a) opció (alsó gomb a metrika-lapon) újranyitná a már megoldott körvágás-problémát (pont emiatt került a controls külön lapra F4-ben); a dedikált lap a teljes safe area-t egyetlen ~244 px tap-targetté teszi (a 48 px minimum ~5×-e), nulla mis-tap kockázattal az End/Pause mellett; a metrika-lap szándékosan gombmentes marad.
- A log-lap **az első lap**, mert a szettek között úgyis oda nyúl a user, és csuklóemelésre azonnal az jön elő.
- A pöttyök 2 → 3-ra bővülnek (Wearen a saját `PageDots`, ami már paraméteres — automatikusan jó lesz).

Vizuál (mindkét platformon azonos): sötét `primaryContainer` korong + primary gyűrű, benne óriási **„+1”** és alatta **„SET”**; a korong alatt kontextussor: „Bench Press · Set 2 of 4”. Az AW-lap tetején a meglévő `HeaderChip` az eltelt idővel (`fitness_center` ikon + „24:36”), a Wear-lapon csak az óra ideje — ez a két platform közti meglévő különbség, nem új döntés.

### 3.2 A tap utáni életciklus (watch-oldali mikro-állapotgép)

```
READY ──tap──▶ PENDING ──ack (≤5 s)──▶ CONFIRMED (1–1,5 s) ──▶ READY
                  │                       (check-ikon + „Set 3 of 4” + „Logged”
                  │                        pill, scale-pop, success-haptika; ha
                  │                        a telefon rest-et indított: 350 ms-os
                  │                        láncolt rest-hero takeover)
                  ├──timeout (5 s)──▶ FAILED (errorContainer toast ~2,5 s
                  │                    + error-haptika) ──▶ READY
                  └──nincs elérhető telefon már a tap előtt──▶ a gomb ghosted
                       (opacity .75, outline-gyűrű, szürke „+1 SET”),
                       alatta „Phone not reachable” chip; READY-be tér vissza,
                       amint a reachability helyreáll
```

- **PENDING alatt a gomb inaktív** (ez a dupla-tap elleni első védvonal; a debounce a második, §4.2). Vizuál: ghosted korong + `log_set_pending` felirat a „SET” helyén.
- A CONFIRMED-feedback akkor is a **visszaérkező state-ből** táplálkozik, ha vizuálisan optimista animációnak tűnik — a számláló soha nem mutat olyan értéket, amit a telefon nem erősített meg. Konkrétan: az ack váltja ki a check-ikont + haptikát, de a **számot mindig a `setsDone`/`setsTotal` élő értéke adja**. A gyakorlati sorrend: ack (≈100–300 ms) → state-sync (közvetlenül utána, mert a telefon a logolás után azonnal `updateState`-el) → a szám 2/4-ről 3/4-re vált a CONFIRMED ablakon belül. Ha a state-sync késik, a check látszik a régi számmal, majd a szám magától frissül — ez elfogadott, nem kell rá külön várakozó állapot.
- A „Set N of M” szemantikája **ugyanaz, mint a meglévő pillé**: `setsDone` / `setsTotal` (kész/összes) — a design AW 08 → AW 09 átmenete (2/4 → 3/4) pontosan ezt mutatja.
- Ha a logolás rest-indítást vált ki a telefonon (tipikus eset), a state-syncben megjövő `restRemainingSeconds` a meglévő úton átviszi a UI-t a rest-heróba. **A rest-hero a metrika-lapon van (1-es lap), a log-lap nem vált át rá** — a 350 ms-os „láncolt takeover” a lapon belüli/lapok közti vizuális megoldást a §10/1 nyitott kérdés zárja le eszközön.

### 3.3 Fázis-kapuzás

- A kontroll csak `ACTIVE` fázisban él; `ENDING`/`SUMMARY`/`ERROR`/`IDLE` alatt a log-lap nem is létezik (a pager ezekben a fázisokban ma sem jelenik meg).
- **Pause alatt**: a gomb maradjon aktív — a pause csak a szenzor-sessiont érinti (B3), a telefon-oldali logolást nem.
- **Rest alatt**: a gomb elérhető marad (a user rövidítheti a pihenőt és logolhat korábban) — a telefon-oldali viselkedés (rest-újraindítás) a telefon meglévő set-logolási logikáját követi, a watch ebbe nem szól bele. A (b) elhelyezéssel ez ingyen megvan: a log-lap rest alatt is ott van, a rest-hero a szomszéd lapon.
- `setsDone == setsTotal` esetén a gomb **nem tiltódik le** — a telefon-app ma is enged terven felüli szettet logolni; a watch itt sem okosabb a telefonnál (a telefon-oldali szabály: §5.2/3).

### 3.4 Lokalizációs kulcsok (HU/EN)

A design „F5/F6 string keys” táblája a mérvadó. Androidon `values/strings.xml` (HU, default) + `values-en/strings.xml`, iOS-en `Localizable.xcstrings`, **azonos kulcsnevekkel** (40-es doc 8.2/3).

| Kulcs | EN | HU | Státusz |
|---|---|---|---|
| `log_set_button` | `+1 set` | `+1 szett` | design |
| `log_set_pending` | `Logging…` | `Naplózás…` | design (a korábbi „Logolás…” elavult) |
| `log_set_logged` | `Logged` | `Naplózva` | design |
| `log_set_failed` | `Couldn't log — try again` | `Nem sikerült — próbáld újra` | design |
| `phone_unreachable` | `Phone not reachable` | `A telefon nem érhető el` | design |
| `log_set_context_format` | `%1$s · Set %2$d of %3$d` | `%1$s · %2$d/%3$d szett` | **javaslat** — a design kirajzolja a sort („Bench Press · Set 2 of 4”), de a kulcslistából hiányzik |
| `log_set_button_a11y` | `Log one set` | `Egy szett naplózása` | **javaslat** — a korong nem szöveges gomb, kell neki accessibility label |

F5b-hez (még nem kell megírni, csak jegyezve): `log_adjust_title` (Adjust / Módosítás), `log_adjust_reps` (Reps / Ismétlés), `log_adjust_weight` (Weight / Súly), `log_adjust_confirm` (`Log {n} reps` / `{n} ismétlés naplózása`).

---

## 4. Protokoll

### 4.1 Új üzenet: `logSet` (watch → telefon)

Logikai payload:

```json
{
  "sessionClientId": "…",
  "eventId": "<watch-generálta UUID>",
  "loggedAtEpochMs": 1234567890123
}
```

- **Nincs** reps/súly/gyakorlat mező (v1) — lásd §2.
- `eventId`: iOS `UUID().uuidString`, Wear `java.util.UUID.randomUUID().toString()`.
- `loggedAtEpochMs` v1-ben csak diagnosztika (a telefon a saját `DateTime.now()`-ját stempeli a sorba) — de menjen, mert utólag nem lehet visszamenőleg bevezetni.

Fizikai forma platformonként (a meglévő konvenciók szerint — **ez a két oldal között kötelezően egyezik, itt a leggyakoribb hibaforrás**):

| Irány | iOS | Android |
|---|---|---|
| watch → telefon | `WCSession.sendMessage`, a message dict `"type": "logSet"` kulccsal (mint `endRequested`) | `MessageClient.sendMessage`, path `/lifey/watch/logSet`, body = a fenti JSON |
| telefon → watch (ack) | `WCSession.sendMessage`, a message dict **`"command": "logSetAck"`** kulccsal + kötelező `sessionClientId` | path `/lifey/watch/logSetAck`, body = ack-JSON |

> ⚠️ iOS-en a két irány **különböző kulcsot** használ: a watch→telefon üzenetek `type`-ot, a telefon→watch parancsok `command`-ot (`PhoneConnector.session(_:didReceiveMessage:)` erre kapcsol). Ugyanez a metódus **azonnal `return`-öl, ha nincs `sessionClientId`** a payloadban — az ack-be tehát kötelező betenni.

### 4.2 Dedup és debounce

- **Watch-oldali debounce**: PENDING alatt a gomb inaktív (§3.2) + 300 ms-os tap-debounce a gyors dupla-érintés ellen.
- **Telefon-oldali dedup**: a `LogSessionScreen` session-enként megjegyzi az utolsó **8** feldolgozott `eventId`-t memóriában; ismételt `eventId` no-op, de **újra ack-olódik** (hogy a watch retry-a is lezárhassa a PENDING-et). Perzisztálni nem kell — a dedup csak a kézbesítési retry ablakát fedi, nem napokat.

### 4.3 Ack: explicit válasz, nem a state-syncből kikövetkeztetve

```json
{ "sessionClientId": "…", "eventId": "…", "accepted": true }
```

- Miért nem elég a state-sync mint implicit ack: a `setsDone`-inkrement nem korrelálható egy konkrét tap-hez (párhuzamos telefon-oldali logolás összemoshatja), és Androidon a state-csatorna amúgy is best-effort rétegekre épül (40-es doc 7.5.2). Az explicit ack olcsó és egyértelmű.
- `accepted: false` esetei: nincs ilyen aktív session (`sessionClientId` nem egyezik), vagy a képernyő már záródik (`_finishedAt != null || _saving`) — a watch FAILED-et mutat.
- A state-sync ettől függetlenül, változatlanul megy — az frissíti a számlálót és indítja a rest-herót.

### 4.4 Elérhetőség-detektálás

- **iOS**: a meglévő `WCSession.isReachable` + a már bekötött `reachabilityChanged` esemény — a gomb ghosted állapota ebből táplálkozik. A `PhoneConnector.sendMessage` amúgy is `isReachable`-re guard-ol, tehát a nem-elérhető eset nem is generál hálózati kísérletet.
- **Android**: nincs megbízható folyamatos reachability-jel. A design W 10 jegyzete `CapabilityClient`-et említ, de **ez a projektben bizonyítottan megbízhatatlan** (40-es doc 7.5.5 + `WatchBridge.kt` `targetNodes()` doc-comment: „Mismatched certificate” miatt üres eredmény valós, csatlakozott órával is), és a Dart-oldali `WatchReachabilityChanged` Androidon sosem tüzel (12.4/B14). **Döntés: Androidon a küldés optimista** — a gomb alapból aktív, a hibát az ack-timeout jelzi (§3.2). Best-effort előszűrés: ha a `NodeClient.getConnectedNodes()` üres, a gomb már a tap előtt ghosted (ugyanaz a vizuál, amit a design W 10 rajzol) — de erre nem építünk garanciát, és `CapabilityClient`-re nem támaszkodunk.

---

## 5. Dart-oldali munka

### 5.1 `watch_workout_service.dart`

1. Új eseményosztály `WatchSetLogged { sessionClientId, eventId, loggedAtEpochMs }` + `case 'setLogged'` a `_decodeEvent` switch-ben, a meglévő `WatchEndRequested`/`WatchLiveMetrics` minta szerint. (A natív oldal `"type": "setLogged"` néven emitálja az EventChannelre — a wire-parancs neve `logSet`, az EventChannel-esemény neve `setLogged`, mint ahogy az `endRequested` is a natív parancsnevet viszi tovább; a §11 lépései ezt konzisztensen használják.)
2. Új metódus: `Future<void> ackSetLogged({required String eventId, required bool accepted})` → `_channel.invokeMethod('ackSetLogged', {...})`, a többi hívás best-effort try/catch mintájával.

### 5.2 `LogSessionScreen`

3. `_onWatchEvent` új `case WatchSetLogged()`:
   - guard: `event.sessionClientId != _sessionClientId` → `accepted: false`;
   - guard: `_finishedAt != null || _saving` → `accepted: false`;
   - dedup: ha `event.eventId` benne van a `_recentWatchSetEventIds` (max 8 elemű FIFO) listában → **nem logol**, de `accepted: true` ack-ot küld;
   - egyébként: logol a **meglévő úton**, felveszi az `eventId`-t a listára, `accepted: true`.
4. **Melyik sort logolja** (`_nextRowToLogFromWatch()`), a meglévő `_currentExerciseBlock()`-ra építve:
   1. az aktuális blokk (`_currentExerciseBlock()`) **első `!isDone` sora** → `_handleRowMarkDone(bi, ri)`;
   2. ha az aktuális blokkban nincs ilyen: az **első blokk, amiben van `!isDone` sor** → annak első ilyen sora;
   3. ha sehol nincs: `_handleAddSet(bi, prefillFromPrevious: true)` az aktuális blokkra, majd az új sor `_handleRowMarkDone`-ja — ez adja a §3.3 „terven felüli szett engedélyezve” viselkedést.
   - A logolás így automatikusan viszi a `_syncRestEphemeralState()` + `_rescheduleRestNotification()` + `_autoSave()` láncot, tehát a rest-indítás és a state-sync ingyen jön.
   - **Következmény, amit tudni kell**: a watchról logolt sor a benne lévő (tervezett/előtöltött) súly-ismétlés értékekkel megy be; ha a sor üres volt, üresen marad készként. Ez pontosan az, amit a telefon saját pipa-gombja is csinál — nincs külön szabály.
5. Az ack elküldése minden ágon: `unawaited(ref.read(watchWorkoutServiceProvider).ackSetLogged(eventId: …, accepted: …))`.

### 5.3 Tesztek

6. Unit tesztek a meglévő fake-channel mintával (`test/core/watch/watch_workout_service_test.dart`): `setLogged` dekódolás, `ackSetLogged` MethodChannel-hívás argumentumai, `isAvailable == false` → nincs hívás.
7. Screen-szintű teszt a dedup/guard logikára (ha a `LogSessionScreen` közvetlenül nehezen tesztelhető, a §5.2/3–4 logikát ki kell emelni egy tiszta függvénybe/kis osztályba, és azt tesztelni — ez a preferált irány).

---

## 6. Natív munka

### 6.1 watchOS (`mobile/ios/LifeyWatch/`)

- `PhoneConnector`: `sendLogSet(sessionClientId:eventId:loggedAtEpochMs:)` (`sendMessage`, reply-handler nélkül) + a `didReceiveMessage` switch új `case "logSetAck"` ága → `WorkoutManager`.
- `WorkoutManager`: a §3.2 mikro-állapotgép — `@Published private(set) var logSetState: LogSetState` (`.ready/.pending(eventId)/.confirmed/.failed`), `logSet()` belépési pont, 5 s timeout-`Task`, haptikák (`WKInterfaceDevice.current().play(.success)` / `.failure`), 1,2 s után CONFIRMED → READY.
- `ActiveWorkoutView`: új `LogPage` a `TabView` **0-s tagjén**, a metrika 1-re, a controls 2-re csúszik; a `.digitalCrownRotation(… from: 0, through: 2 …)` felső határa 2-re nő.
- Telefon-oldal (`Runner/WatchBridge.swift`): `didReceiveMessage` új `case "logSet"` → `eventSink?(["type": "setLogged", …])`; új `ackSetLogged` MethodChannel-metódus → `sendMessage(["command": "logSetAck", "sessionClientId": …, "eventId": …, "accepted": …])`.

### 6.2 Wear OS (`mobile/android/wear/`)

- `SummarySender`: `sendLogSet(context, sessionClientId, eventId, loggedAtEpochMs)` a meglévő JSON-küldő mintával.
- `SessionStateHolder`: `logSetState: StateFlow<LogSetState>` + `onLogSetRequested/onLogSetAck/onLogSetTimeout/onLogSetSettled`.
- `ExerciseService`: a timeout-ütemezés és a haptika a service `scope`-jában fut (a `restVibrationJob`/`scheduleRestVibration` mintájára), **nem** a Compose-képernyőn — így a UI eldobása nem szakítja meg.
- `PhoneListenerService`: új `"$MESSAGE_PATH_PREFIX/logSetAck"` ág → `SessionStateHolder`. **Manifest-módosítás nem kell**: a service intent-filtere `pathPrefix="/lifey/watch"`-ra megy.
- `ActiveWorkoutScreen`: `LogPage` composable, `PAGE_COUNT = 3`, `LOG_PAGE = 0` / `METRICS_PAGE = 1` / controls = 2; a `PageDots` paraméteres, magától jó lesz.
- Telefon-oldal (`app/.../WatchBridge.kt`): új `"$MESSAGE_PATH_PREFIX/logSet"` ág az `onMessageReceived`-ben → `eventSink?.success(mapOf("type" to "setLogged", …))`; új `"ackSetLogged"` MethodCall → `sendMessage`.
  - **Szándékosan nem** bővítjük a manifest-deklarált `PhoneWatchSummaryListenerService`-t: az csak a `/lifey/watch/summary` path-ra van szűrve, tehát a `logSet` kizárólag az élő Flutter-engine-hez kötött listenerhez jut el — pontosan a §7.3 „kilőtt app = hibaút, nem bufferelünk” döntés.

---

## 7. Hibautak és edge case-ek

| # | Eset | Viselkedés |
|---|---|---|
| 7.1 | Ack-timeout (telefon nem válaszol 5 s-en belül) | FAILED-feedback az órán; a telefon **lehet, hogy mégis logolt** (az ack veszett el) — a user a visszaérkező state-syncből (számláló) látja az igazságot; a retry-tap új `eventId`-t kap, tehát tényleg új szettet logol. Ezt a maradék kockázatot v1-ben elfogadjuk (a set-logolás a telefonon egy tappal korrigálható). |
| 7.2 | `sessionClientId`-mismatch (a telefonon már másik/semmilyen session fut) | `accepted: false` → FAILED. A következő state-sync/end úgyis rendbe rakja a watch fázisát. |
| 7.3 | Telefon-app kilőve | iOS: a `sendMessage` háttérben felébreszti az appot — ha a Flutter engine és a `LogSessionScreen` már nem áll fel időben aktív sessionnel, az eset a 7.2-be fut. Android: a `WearableListenerService` felébred, de a `logSet` path-ra nincs manifest-listener (§6.2) → nincs ack → 7.1. **V1-döntés: ez hibaút**, nem buffereljük a logSet-et (ellentétben a summary-val) — egy „log” parancsnak friss kontextus kell. |
| 7.4 | Dupla kézbesítés (transport-retry) | Telefon-oldali `eventId`-dedup (§4.2) — egy logolás, ismételt ack. |
| 7.5 | Pause alatt tap | Logolódik (§3.3) — a pause csak szenzor-ügy. |
| 7.6 | Rest alatt tap | Logolódik; a rest-kezelés a telefon meglévő logikája szerint (§3.3). |
| 7.7 | Tap, majd a user azonnal a controls-lapra lapoz | Az állapotgép a `WorkoutManager`/`SessionStateHolder`/`ExerciseService` szintjén él, nem a lapon — a timeout és a haptika lefut, a CONFIRMED/FAILED vizuál a log-lapra visszalapozva is konzisztens (ha addigra lejárt, READY-t lát). |
| 7.8 | A telefonon közben másik gyakorlatra lépett a user | A telefon a **saját** aktuális pozíciója szerint logol (§5.2) — a watch kontextussora a következő state-syncben követi. Nem hiba. |

---

## 8. Tesztelési terv

- **Dart unit** (fake channel): §5.3.
- **iOS manuális** (watchOS-szimulátor + iOS-szimulátor pár): tap → telefon logol → számláló frissül → rest-hero lánc; dupla-gyors-tap → egy szett; telefon-app háttérben → működik; telefon-app kilőve → FAILED; repülő módú telefon → ghosted gomb (reachability).
- **Wear manuális** (emulátorpár): ugyanezek + ack-timeout szimulálása (telefon-app kilőve → FAILED 5 s után); `getConnectedNodes` üres eset.
- **Regresszió**: F4-viselkedés watch-tap nélkül bitre azonos; a 3-lapos pager nem töri a meglévő GO-flash/rest-hero átmeneteket, a crown/rotary lapozás mindhárom lapot eléri, a page-dots 3 pöttyöt rajzol.

---

## 9. Ütemezés és becslés

| Ütem | Tartalom | Becslés | Státusz |
|---|---|---|---|
| F5-design | 45-ös prompt F5-fele (4+4 frame) + elhelyezés-döntés | M | **kész** (AW 08–11, W 07–10) |
| F5a | Protokoll (§4) + Dart (§5) + mindkét natív oldal (§6) + teszt (§8) — lépésenként a §11-ben | M–L | következő |
| F5b | Reps/súly-stepper (crown/rotary) — csak F5a-tapasztalat után; a design megvan (AW 10 / W 09), de van egy megoldandó technikai ütközés (§12) | M | **a mini-terv megvan**: [48-watch-f5b-set-adjust-plan.md](48-watch-f5b-set-adjust-plan.md) |

Az F5a a két natív oldalon párhuzamosítható (a Dart-oldal és a protokoll közös előfeltétel) — a lépések függőségi gráfja a §11.0-ban.

---

## 10. Döntések (mind lezárva, 2026-07-26)

Nyitott kérdés nem maradt.

1. **Rest és a log-lap együttélése** → **nincs auto-lapozás**, a design szándéka szerint. Implementálva így (S8/S13), és az eszközös körben (S9/S14) rendben volt — a log-lapra érkező csuklóemelés nem zavaró, a rest a szomszéd lapon egy swipe. Ha az F5b után mégis zavaróvá válik (mert az adjust miatt többet időzünk a log-lapon), továbbra is egy `animateScrollToPage`/`selectedPage = 1` sor.
2. **Ack-timeout értéke** → **5 s, marad.** Bevezetve mindkét platformon (`logSetAckTimeoutSeconds` / `LOG_SET_ACK_TIMEOUT_MS`), és az eszközös körben (S9/S14) jónak bizonyult — a valós latencia mellett nem futott bele fals timeoutba. Az F5b ugyanezt a konstanst örökli.
3. **`log_set_context_format` és `log_set_button_a11y`** (§3.4) → **a javasolt kulcsnév + copy változtatás nélkül maradt**, mindhárom lokalizációs fájlban (S1). Külön designer-visszaigazolás nem érkezett; ez a tényleges, szállított szöveg.

*(A korábbi „kontroll-elhelyezés”, „rest alatti elérhetőség” és „FAILED-copy szétválasztása” kérdéseket a design lezárta — lásd §0.)*

---

## 11. Fejlesztési terv apró lépésekben (F5a)

Minden lépés önmagában fordul, tesztelhető, és nem töri a meglévő F4-viselkedést. Az „Ellenőrzés” oszlop az, amit a lépés végén ténylegesen le kell futtatni/megnézni.

### 11.0 Függőségi gráf és párhuzamosítás

```
S1 (kulcsok+konstansok, közös)
  └─▶ S2 ─▶ S3 ─▶ S4   (Dart: esemény, ack-metódus, screen-bekötés + teszt)
             │
             ├─▶ iOS-ág:     S5 ─▶ S6 ─▶ S7 ─▶ S8 ─▶ S9
             └─▶ Android-ág: S10 ─▶ S11 ─▶ S12 ─▶ S13 ─▶ S14
                                                          └─▶ S15 (közös zárás)
```

- **S1–S4 közös előfeltétel** (Dart + protokoll-szerződés) — ezek után az iOS- és az Android-ág **teljesen párhuzamosan** vihető, nincs köztük közös fájl.
- Az iOS-ág és az Android-ág is „telefon-oldal → watch-oldal → UI” sorrendű, hogy a hídvégek előbb legyenek készen, mint az őket használó felület.
- Ha egy platformon egyedül dolgozol: az S5–S9 és az S10–S14 sorrendje egymással felcserélhető.

---

### S1 — Protokoll-szerződés + string-kulcsok rögzítése *(közös, kód-viselkedés nélkül)*

**Fájlok:** `mobile/android/wear/src/main/res/values/strings.xml`, `mobile/android/wear/src/main/res/values-en/strings.xml`, `mobile/ios/LifeyWatch/Localizable.xcstrings`

**Teendő:**
- Vedd fel a §3.4 kulcsokat mindhárom helyre, azonos kulcsnévvel: `log_set_button`, `log_set_pending`, `log_set_logged`, `log_set_failed`, `phone_unreachable`, `log_set_context_format`, `log_set_button_a11y`.
- HU a `values/strings.xml`-be (ez a default), EN a `values-en/`-be; iOS-en mindkét nyelv az xcstrings-be.
- Az `log_set_context_format` argumentum-sorrendje kötött: `%1$s` = gyakorlat, `%2$d` = `setsDone`, `%3$d` = `setsTotal`.

**Ellenőrzés:** mindkét app fordul; a kulcsok listája a két platformon karakterre egyezik (`diff` a kulcsneveken).

---

### S2 — Dart: `WatchSetLogged` esemény *(közös)*

**Fájlok:** `mobile/lib/core/watch/watch_workout_service.dart`, `mobile/test/core/watch/watch_workout_service_test.dart`

**Teendő:**
- Új osztály `WatchSetLogged { sessionClientId, eventId, loggedAtEpochMs }` + `fromJson`, a `WatchLiveMetrics` mintájára; doc-comment hivatkozzon erre a docra.
- `_decodeEvent`: `case 'setLogged'`.
- Frissítsd a `events` getter doc-commentjének felsorolását.
- Teszt: a fake EventChannel-lel érkező `{'type': 'setLogged', …}` map helyesen dekódolódik; ismeretlen típus továbbra is stringként jön vissza.

**Ellenőrzés:** `flutter test test/core/watch/` zöld. Viselkedésváltozás nincs (senki sem emitál még ilyet).

---

### S3 — Dart: `ackSetLogged` MethodChannel-hívás *(közös)*

**Fájlok:** ugyanaz, mint S2.

**Teendő:**
- `Future<void> ackSetLogged({required String eventId, required bool accepted})` → `invokeMethod('ackSetLogged', {'eventId': …, 'accepted': …})`, a meglévő `isAvailable`-guard + néma try/catch mintával (natív handler még nincs → `MissingPluginException`, elnyelve).
- Teszt: `isAvailable: false` → nincs hívás; egyébként pontosan egy hívás a várt argumentumokkal.

**Ellenőrzés:** `flutter test` zöld.

---

### S4 — Dart: `LogSessionScreen` bekötés (guard + dedup + logolás + ack) *(közös)*

**Fájlok:** `mobile/lib/features/workouts/presentation/log_session_screen.dart` (+ új teszt)

**Teendő:**
- `_onWatchEvent`: `case WatchSetLogged()` a §5.2 szerint (session-guard → záródás-guard → dedup → logolás → ack minden ágon).
- `_recentWatchSetEventIds`: 8 elemű FIFO a state-ben.
- `_nextRowToLogFromWatch()`: a §5.2/4 három szabálya, a meglévő `_currentExerciseBlock()`-ra építve; a tényleges logolás **kizárólag** a meglévő `_handleRowMarkDone` / `_handleAddSet` hívásokon keresztül (ne másold a rest/persist láncot).
- A dedup + sorválasztó logikát emeld ki tesztelhető, `BuildContext`-mentes formába (tiszta függvény vagy kis helper-osztály), és arra írj tesztet: ismételt `eventId` → egy logolás + két ack; session-mismatch → `accepted: false`; „minden sor kész” → új sor keletkezik és készre megy.

**Ellenőrzés:** `flutter test` zöld; az app kézzel indítva ugyanúgy viselkedik (a watch még nem küld semmit → az új kód nem fut).

> Innentől az iOS- és az Android-ág párhuzamos.

---

### S5 — iOS/telefon: `logSet` fogadás + `ackSetLogged` metódus

**Fájl:** `mobile/ios/Runner/WatchBridge.swift`

**Teendő:**
- `handle(_:result:)`: új `case "ackSetLogged"` → kiolvassa az `eventId`/`accepted` argumentumokat, és `WCSession.default.isReachable` esetén `sendMessage(["command": "logSetAck", "sessionClientId": …, "eventId": …, "accepted": …])`.
  - A `sessionClientId`-t is át kell adni Dart-ból **vagy** el kell tárolni a legutóbbi `updateState` hívásból — **javaslat: adja át a Dart** (`ackSetLogged` argumentumai közé vedd fel), így a híd állapotmentes marad; ekkor az S3 metódusszignatúra `sessionClientId`-vel bővül (frissítsd az S3 tesztjét is).
- `session(_:didReceiveMessage:)`: új `case "logSet"` → `eventSink?(["type": "setLogged", "sessionClientId": …, "eventId": …, "loggedAtEpochMs": …])`.

**Ellenőrzés:** iOS-app fordul; `ackSetLogged` hívásra a logban látszik a `sendMessage` kísérlet (watch-oldali fogadó még nincs).

---

### S6 — watchOS: `PhoneConnector.sendLogSet` + ack fogadás

**Fájl:** `mobile/ios/LifeyWatch/PhoneConnector.swift`

**Teendő:**
- `sendLogSet(sessionClientId:eventId:loggedAtEpochMs:)` a `sendEndRequested` mintájára (a privát `sendMessage` már `isReachable`-re guard-ol — ez adja ingyen a §4.4 iOS-ágát).
- `session(_:didReceiveMessage:)`: a `command` switch új `case "logSetAck"` ága → `Task { @MainActor in WorkoutManager.shared.applyLogSetAck(eventId:accepted:) }`.

**Ellenőrzés:** fordul; a watch a telefontól kapott ack-ra belép a `WorkoutManager` metódusába (breakpoint/log).

---

### S7 — watchOS: `WorkoutManager` mikro-állapotgép

**Fájl:** `mobile/ios/LifeyWatch/WorkoutManager.swift`

**Teendő:**
- `enum LogSetState: Equatable { case ready, pending(String), confirmed, failed }` + `@Published private(set) var logSetState: LogSetState = .ready`.
- `func logSet()`: guard `phase == .active`, `sessionClientId != nil`, `logSetState == .ready`; UUID-generálás; `.pending(eventId)`; `PhoneConnector.sendLogSet(…)`; 5 s timeout-`Task` (a `scheduleSummaryAutoDismiss` mintájára, cancellálható).
- `func applyLogSetAck(eventId:accepted:)`: csak akkor hat, ha a `pending` eventId egyezik; timeout-Task cancel; `accepted` → `.confirmed` + `.success` haptika, 1,2 s után `.ready`; különben `.failed` + `.failure` haptika, 2,5 s után `.ready`.
- Timeout lejáratkor: `.failed` ugyanezzel a lecsengéssel.
- `reset()`-be: `logSetState = .ready` + a taskok cancelje.
- **F6-ra készen (§2.1):** a `logSet()`-ben egyetlen elágazás döntse el, hogy remote (pending) vagy local (azonnali confirmed) módban fut — most csak a remote ág létezik.

**Ellenőrzés:** unit-szintű ellenőrzés nincs (nincs watch-teszt-target) — a szimulátoros kézi kör az S9-ben.

---

### S8 — watchOS: log-lap a pagerben

**Fájl:** `mobile/ios/LifeyWatch/Views/ActiveWorkoutView.swift`

**Teendő:**
- Új `private struct LogPage: View` az AW 08/09/11 frame-ek szerint: 244 pt-arányos korong (`DynamicSizing` százalékos elrendezéssel, nem fix px — 12.1 B4), `+1` / `SET`, alatta a `log_set_context_format` sor, felül a meglévő `HeaderChip` az eltelt idővel.
- A `logSetState` szerinti négy vizuál (ready / pending ghosted + `log_set_pending` / confirmed check + `log_set_logged` / failed toast), plusz a nem-elérhető ghosted állapot.
- `TabView`: `LogPage().tag(0)`, `MetricsPage().tag(1)`, `ControlsPage().tag(2)`; a `.digitalCrownRotation(… through: 2 …)`.
- Tap → `WorkoutManager.shared.logSet()`; 300 ms debounce (§4.2).
- `accessibilityLabel(Text("log_set_button_a11y"))`.

**Ellenőrzés:** szimulátoron mindhárom lap elérhető swipe-pal és crown-nal; a GO-flash és a rest-hero változatlanul működik.

---

### S9 — iOS: kézi végpróba — **kész, 2026-07-26** (fejlesztői eszközös visszaigazolás)

**Teendő:** a §8 iOS-listája (tap → logolás → számláló → rest-lánc; dupla tap; háttérben lévő telefon; kilőtt telefon; repülő mód).

**Ellenőrzés:** mind az öt eset a §3.2/§7 szerint viselkedik.

---

### S10 — Android/telefon: `logSet` fogadás + `ackSetLogged` metódus

**Fájl:** `mobile/android/app/src/main/kotlin/com/khunor/lifey/WatchBridge.kt`

**Teendő:**
- `COMMAND_LOG_SET = "logSet"` / `COMMAND_LOG_SET_ACK = "logSetAck"` konstansok.
- `onMessageReceived`: `"$MESSAGE_PATH_PREFIX/$COMMAND_LOG_SET"` → JSON-parse → `eventSink?.success(mapOf("type" to "setLogged", …))`.
- `onMethodCall`: `"ackSetLogged"` → `sendMessage(COMMAND_LOG_SET_ACK, ackJson)` (a meglévő executor-os `sendMessage` privát metóduson át).
- **Ne** nyúlj a `PhoneWatchSummaryListenerService`-hez és a manifesthez (§6.2 utolsó pontja).

**Ellenőrzés:** app fordul; `adb` logban látszik a `sendMessage(logSetAck)` kísérlet.

---

### S11 — Wear: `SummarySender.sendLogSet` + ack fogadás

**Fájlok:** `mobile/android/wear/src/main/kotlin/com/khunor/lifey/SummarySender.kt`, `.../PhoneListenerService.kt`

**Teendő:**
- `sendLogSet(context, sessionClientId, eventId, loggedAtEpochMs)` a `sendEndRequested` JSON-mintájával, path `/lifey/watch/logSet`.
- `PhoneListenerService.onMessageReceived`: új `"$MESSAGE_PATH_PREFIX/logSetAck"` ág → JSON-parse → `SessionStateHolder.onLogSetAck(eventId, accepted)`.

**Ellenőrzés:** emulátorpáron a telefonról manuálisan kiváltott ack megérkezik (log).

---

### S12 — Wear: `SessionStateHolder` állapotgép + `ExerciseService` timeout/haptika

**Fájlok:** `.../SessionStateHolder.kt`, `.../ExerciseService.kt`

**Teendő:**
- `SessionStateHolder`: `sealed interface LogSetState { Ready; Pending(eventId); Confirmed; Failed }` + `MutableStateFlow` + `onLogSetRequested(eventId)`, `onLogSetAck(eventId, accepted)` (csak egyező eventId-re hat), `onLogSetTimeout(eventId)`, `onLogSetSettled()`; a `reset()` ezt is nullázza.
- `ExerciseService.onCreate()`: a `restVibrationJob` mintájára egy `logSetJob`, ami a `logSetState` flow-t figyeli: `Pending` → 5 s timeout ütemezése; `Confirmed`/`Failed` → haptika (rövid dupla / hosszabb egy) + a lecsengés (1,2 s ill. 2,5 s után `onLogSetSettled()`).
- A tényleges küldés a UI-ból indul (`scope.launch { SummarySender.sendLogSet(...) }`, mint az `sendEndRequested`) — a **timeout és a haptika azonban a service-ben él**, hogy a képernyő eldobása ne szakítsa meg.

**Ellenőrzés:** fordul; a state-flow átmenetei logból követhetők.

---

### S13 — Wear: log-lap a pagerben

**Fájl:** `mobile/android/wear/src/main/kotlin/com/khunor/lifey/ui/ActiveWorkoutScreen.kt`

**Teendő:**
- `LOG_PAGE = 0`, `METRICS_PAGE = 1`, controls = 2, `PAGE_COUNT = 3`; a `when (page)` ágak átszámozása (a `else ->` ág ma a controls — ezt nevesített indexre kell váltani, különben a 3. lap is controls lesz).
- Új `LogPage` composable a W 07/08/10 frame-ek szerint (`Box` + `clickable`, kép nélkül; a `logSetState` négy vizuálja + a `NodeClient`-alapú best-effort ghosted állapot, §4.4).
- `PageDots` hívás változatlan (paraméteres).
- Tap → `SessionStateHolder.onLogSetRequested(uuid)` + `SummarySender.sendLogSet(...)`; 300 ms debounce.
- `contentDescription = stringResource(R.string.log_set_button_a11y)`.

**Ellenőrzés:** kerek emulátoron mindhárom lap elérhető swipe-pal és rotary-val, a pöttyök hárman vannak, semmi nem lóg a bezel alá.

---

### S14 — Android: kézi végpróba — **kész, 2026-07-26** (fejlesztői eszközös visszaigazolás)

**Teendő:** a §8 Wear-listája (a fentiek + ack-timeout 5 s után kilőtt telefon-appal; üres `getConnectedNodes`).

**Ellenőrzés:** mind a hat eset a §3.2/§7 szerint viselkedik.

---

### S15 — Közös zárás — **kész, 2026-07-26**

**Teendő:**
- ✅ Regressziós kör mindkét platformon watch-tap nélkül (F4-viselkedés változatlan) — `flutter test` 319/319, `flutter analyze` tiszta, mindkét Android-modul és a teljes `LifeyWatch` target fordul; a 8 érintett natív híd-fájl diffje **kizárólag hozzáadás**, egyetlen törölt/módosított sor nélkül.
- ✅ `docs/watch/40-watch-app-plan.md` állapottáblázatának F5-sora „✅ Kész”-re (mindkét platform átment).
- ✅ Ennek a docnak a státusz-fejléce + a §10 döntései lezárva (auto-lapozás: nincs; timeout: 5 s marad).
- ▶️ Az F5b terve megvan és minden döntése lezárva: [48-watch-f5b-set-adjust-plan.md](48-watch-f5b-set-adjust-plan.md) — a §12 ütközés feloldása a **D-F5b.1** (long-press). Indítható.

---

## 12. Előre látott technikai ütközés az F5b-hez (nem F5a-feladat)

A design (AW 10 / W 09) az adjust-nézetet **a crown/rotary forgatásával** hívná elő a log-lapon. Mindkét platformon ez ütközik a már meglévő használattal:

- **watchOS**: az `ActiveWorkoutView` a `.digitalCrownRotation`-t a **lapozásra** használja (a `crownRotation` ↔ `selectedPage` kétirányú kötéssel).
- **Wear**: a `HorizontalPager` `rotaryScrollableBehavior = RotaryScrollableDefaults.snapBehavior(pagerState)`-tel szintén a **lapozásra** kapja a rotary-t.

Az F5b-nek tehát el kell döntenie, hogyan adja át a crown/rotary fókuszt a log-lapnak (pl. a log-lap saját `focusable` + crown-binding, ami a lapon tartózkodva elnyeli a forgatást, és a lapozás ott csak swipe-pal megy) — vagy más reveal-gesztust kell választani. Ezt a design-döntést az F5b mini-tervben kell lezárni, mert érinti a lapozás felfedezhetőségét.

> **FELOLDVA:** [48-watch-f5b-set-adjust-plan.md](48-watch-f5b-set-adjust-plan.md) **D-F5b.1** (2026-07-26) — három opció (crown-elnyelés / long-press / gomb) kiértékelve, a döntés a **long-press**: a crown-elnyelés épp az alapértelmezett lapon szüntetné meg a lapozás elsődleges affordanciáját. A felfedezhetőséget egy apró barna `tune` glyph ellensúlyozza a korongon. Ez felülírja a canvas reveal-szabályát (AW 10 jegyzete), a „secondary” szándékot viszont megőrzi.
