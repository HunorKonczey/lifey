# 40 – Watch alkalmazás terv (Apple Watch + Wear OS)

Státusz: **Android (Wear OS) — F0–F4 megvalósítva és emulátoron végigtesztelve (2026-07-16); az F4B design-adósság (12. fejezet) Wear OS oldalon nagyrészt lefejlesztve és fut Wear OS emulátoron ellenőrizve (2026-07-17, lásd 7.5.9) — a teljes brand-styling (B6) és a legtöbb funkcionális elem (B1–B5, B11–B13) kész; hátravan még az ENDING/SUMMARY fázispár (A5), az ambient-variáns (D0.3) és a telefon-oldali elemek (B14–B15). iOS (Apple Watch) — F0–F4 megvalósítva (2026-07-16), build-ellenőrizve (LifeyWatch target + teljes Runner workspace zöld); watchOS-szimulátoros/fizikai eszközös manuális teszt még hátravan, lásd 11.5. Az F4B design-adósság iOS oldalon még nem kezdődött el.**
Nyelv: a mobil oldali híd Dart, a watch appok **natívak** (SwiftUI ill. Kotlin/Compose — lásd 2. fejezet, ez nem választás kérdése, hanem platformkényszer)
Kapcsolódó dokumentumok:
- [16-apple-health-integration-plan.md](../16-apple-health-integration-plan.md) — a HealthKit-korlátok; a doc saját maga jelzi, hogy a benne leírt **manuális** "Import from Health" workout-párosítás 2026-07-16-tal megszűnt (lásd lent, 7. és 11. fejezet) — a session-gazdagítás (kalória/pulzus) mostantól kizárólag ebből a watch-integrációból jön
- [26-android-health-connect-integration-plan.md](../26-android-health-connect-integration-plan.md) — Health Connect párja, ugyanaz a superseded-jegyzet
- [24-ios-widget-live-activity-plan.md](../24-ios-widget-live-activity-plan.md) — a `lifey/live_activity` MethodChannel-minta, amit a watch-híd is követ
- [39-rest-timer-plan.md](../39-rest-timer-plan.md) — a `restEndsAtEpochMs` állapot, amit a watch is megjelenít
- [41-watch-design-prompt.md](41-watch-design-prompt.md) — a watch UI design-promptja; a kész design canvas: `docs/watch/design/Lifey Watch Design.dc.html`
- [42-watch-design-implementation-plan.md](42-watch-design-implementation-plan.md) — a design-implementáció terve (F4B fejlesztés → F4 design → F5 → F6, watchOS/Wear OS bontásban)

## Implementációs állapot (2026-07-16)

| Fázis | Android (Wear OS) | iOS (Apple Watch) |
|---|---|---|
| F0 — Spike-ok | ✅ Kész | ✅ Kész |
| F1 — Dart híd | ✅ Kész (mindkét platformra közös) | ✅ Kész (mindkét platformra közös) |
| F2 — Watch MVP (natív start/end/élő mérés) | ✅ Kész | ✅ Kész — lásd 11. fejezet |
| F3 — Wear OS MVP | ✅ Kész | n/a (iOS-nek nincs külön F3-a, az F2 a natív MVP) |
| F4 — Pihenő-visszaszámláló+haptika, Settings-kapcsoló, lokalizáció, hibaút | ✅ Kész (Android fele) | ✅ Kész (iOS fele) — lásd 11. fejezet |
| F4B — Design-parity: a 41-es design F4-scope funkciói, amik nem készültek el (lista: 12. fejezet) | 🔶 Nagyrészt kész — lásd 7.5.9 | ⏸ Nem kezdődött el |
| F5 — (v2) Set-logolás a watchról | ⏸ Nem kezdődött el — csak azután, hogy iOS is F4-en áll | ⏸ ua. |
| F6 — (v2) Standalone indítás a watchról | ⏸ ua. | ⏸ ua. |

**A terv**: az iOS-fejlesztés F2-től F4-ig 2026-07-16-ra elkészült (Android-dal egy szintre hozva) — a build-ellenőrzés (LifeyWatch target + teljes Runner workspace) zöld, a watchOS-szimulátoros/fizikai eszközös manuális teszt hátravan (11.5). Utána közösen térünk vissza F5/F6-ra, mindkét platformon egyszerre.

A 4–10. fejezet az **eredeti terv**, változatlanul hagyva referenciának. A ténylegesen megvalósult Android-implementáció (a tervtől való eltérésekkel, a build/tesztelés közben talált 3 valódi hibával és azok javításával) a **7. fejezet után, új 7.5 alfejezetben** van dokumentálva. Az iOS-oldal terve és tényleges megvalósítása a **11. fejezetben** (11.1–11.4 a terv, 11.5 a leszállított implementáció és a talált eltérések).

---

## 0. A feltett kérdések megválaszolása előre

### „Van lehetőség arra, hogy triggereljünk edzésindítást és -lezárást az alkalmazásból?”

**Igen, mindkét platformon**, de teljesen más mechanizmussal:

| | iOS / Apple Watch | Android / Wear OS |
|---|---|---|
| Indítás telefonról | **Van rá dedikált rendszer-API**: `HKHealthStore.startWatchApp(with:completion:)` — a telefon átad egy `HKWorkoutConfiguration`-t, a rendszer **elindítja a watch appot** (akkor is, ha nem fut), és az a konfigurációval azonnal indíthatja a `HKWorkoutSession`-t. | Nincs ilyen dedikált API, de ugyanez elérhető a **Wearable Data Layer**-rel: a telefon `MessageClient.sendMessage()`-et küld, a watchon egy manifestben deklarált **`WearableListenerService`** akkor is felébred, ha az app nem fut, és elindít egy foreground service-t, ami meghívja a Health Services `ExerciseClient.startExercise()`-t. |
| Lezárás telefonról | Nincs rendszer-API a leállításra — **WatchConnectivity** (`WCSession.sendMessage`) üzenettel mondjuk meg a watch appnak, hogy zárja le a sessionjét. Ha a watch épp nem elérhető, `updateApplicationContext`-tel („kívánt állapot: lezárva”) a következő ébredéskor zár. | Ugyanaz a `MessageClient` üzenet, a watch `endExercise()`-t hív. A Data Layer garantáltan kézbesít, amint a watch elérhető. |
| Előfeltétel | A watch app telepítve van (az iPhone-app watch-kísérőjeként települ; a Watch appból kapcsolható). | A watch app telepítve van (azonos `applicationId`, azonos aláírás). `CapabilityClient`-tel detektáljuk, és `RemoteActivityHelper`-rel megnyithatjuk a Play Store-t a watchon, ha hiányzik. |

### „Ha az appban elindul az edzés, az órai appban is el kell induljon, és trackeljen pulzust, elégetett kalóriát, strength edzésre specializálva”

Ez pontosan a tervezett fő use case, és **megvalósítható**:

- **iOS**: a watch app `HKWorkoutSession`-t futtat `activityType = .traditionalStrengthTraining` konfigurációval, `HKLiveWorkoutBuilder`-rel. Ez élőben gyűjti a pulzust (`heartRate`) és az aktív kalóriát (`activeEnergyBurned`), a végén pedig egy `HKWorkout`-ot ment a HealthKitbe — aminek az UUID-ja pont az a `healthWorkoutId`, amit a session-modellünk **már ma tárol**.
- **Wear OS**: a watch app a **Health Services** `ExerciseClient`-jét használja `ExerciseType.STRENGTH_TRAINING`-gel, `HEART_RATE_BPM` és `CALORIES_TOTAL` adattípusokkal. A végén Health Connect-be írható egy `ExerciseSessionRecord`, így a meglévő HC-importunk is konzisztens marad.
- A doc 16-ban leírt fal („nem látjuk élőben más appok workoutját”) itt **nem érvényes**: az ott felvetett kiskapu — „companion watchOS app, ami a *saját* `HKWorkoutSession`-jét futtatja” — pontosan ez a terv. A saját sessionünket teljes egészében látjuk és vezéreljük.

**Fontos korlát:** a Flutter **nem fut watchOS-en**, a Wear OS-en pedig a Health Services integráció miatt gyakorlatilag natív kód kell. Mindkét watch app natív lesz (SwiftUI ill. Kotlin + Compose for Wear OS), a Flutter-app egy vékony platform-channel hídon keresztül beszél velük — ugyanazzal a mintával, mint a Live Activity (`lifey/live_activity`).

---

## 1. Cél és scope

### V1 cél (ez a doc fő tárgya)

1. A telefonon elindított edzés **automatikusan elindul a watchon is** (strength-specifikus workout session).
2. A watch **élőben méri a pulzust és az elégetett kalóriát**, és mutatja az edzés állapotát (aktuális gyakorlat, szettek, eltelt idő, pihenő-visszaszámláló).
3. A telefonon lezárt edzés **lezárja a watch-sessiont is**, és a watch **összegzést küld vissza** (átlagpulzus, aktív kalória, health workout id), amit a meglévő gazdagító mezőkbe írunk (`activeCalories`, `averageHeartRate`, `healthWorkoutId` — a repository `update` már `Value`-alapú, absent-megőrző, tehát **zéró backend- és sémaváltozás**).
4. A telefon a set-logolásoknál frissíti a watch kijelzőjét (ugyanaz a `WorkoutSessionState` payload, ami a Live Activity-t és az Android ongoing notificationt is táplálja).

### V1-ben tudatosan NEM cél (későbbi fázis)

- Set-logolás a watchról (visszafelé irányuló írás) — 6. fázis.
- Edzésindítás a watchról, telefon nélkül (standalone) — 7. fázis.
- Élő pulzus megjelenítése a **telefon** UI-án (a watch méri, a telefonnak csak az összegzés kell) — opcionális extra.
- Komplikációk / watch face widget, edzésterv-böngészés a watchon.

---

## 2. Technológiai kényszerek és döntések

### D1 — A watch appok natívak

| Opció | Értékelés |
|---|---|
| Flutter a watchon | **watchOS: lehetetlen** (a Flutter engine nem támogatja). **Wear OS: elvben megy**, de a Health Services, az Ongoing Activity, a rotary input és az ambient mode mind natív API; egy Flutter-réteg csak plusz híd lenne egy 200×200 px-es képernyőért. |
| Natív SwiftUI + natív Compose for Wear OS | **Ez a döntés.** Mindkét platformon ez az egyetlen (iOS) ill. az egyértelműen jobb (Android) út. A watch UI szándékosan minimális (1–3 képernyő), a duplikált UI-költség kicsi. |

Következmény: a watch appokhoz Swift- és Kotlin-fejlesztés kell, és a CLAUDE.md „Never modify generated files” szabálya mellett a `mobile/ios` Xcode-projekt és a `mobile/android` Gradle-projekt kézi bővítése.

### D2 — Kommunikációs csatorna telefon ↔ watch

**iOS:**

| Mechanizmus | Mire | Miért |
|---|---|---|
| `HKHealthStore.startWatchApp(with:)` | Indítás-trigger | Az egyetlen API, ami a watch appot el is indítja. A watch oldalon a `WKApplicationDelegate.handle(_ workoutConfiguration:)` kapja meg. |
| `WCSession.sendMessage` | Interaktív parancsok (end, pause) + state-frissítések, amikor mindkét app él | Azonnali, választ is adhat. Csak akkor működik, ha a watch app fut és elérhető (`isReachable`). |
| `WCSession.updateApplicationContext` | „Legutolsó ismert kívánt állapot” | Túléli az elérhetetlenséget: a rendszer a legfrissebb context-et kézbesíti, amint lehet. Ide megy a `WorkoutSessionState` snapshot és a `desiredPhase` (running/ended). |
| `WCSession.transferUserInfo` | Watch → telefon összegzés az edzés végén | Sorban áll és garantáltan átér akkor is, ha a telefon-app épp nem fut — a következő indításkor kézbesíti a rendszer. |
| *(v2 opció)* iOS 17+ workout session mirroring (`startMirroringToCompanionDevice`) | Élő metrika-stream a telefonra | Modern, HealthKit-natív út: a telefon is kap egy tükör-`HKWorkoutSession`-t és élő adatokat. V1-ben nem kell (nincs élő pulzus a telefonon), de a doc számol vele bővítésként. |

**Android:**

| Mechanizmus | Mire | Miért |
|---|---|---|
| `MessageClient` | Parancsok (start, end, pause) és state-frissítés | Fire-and-forget üzenet egy node-nak; a watchon `WearableListenerService` fogadja, app-újraindítás nélkül. |
| `DataClient` (DataItem) | „Legutolsó ismert állapot” szinkron | A Data Layer verziózott, offline-tűrő kulcs-érték szinkronja — az `updateApplicationContext` párja. Ide megy a `WorkoutSessionState` és a `desiredPhase`. |
| `CapabilityClient` | Watch app jelenlétének detektálása | A watch app deklarál egy `lifey_watch_workout` capability-t; a telefon így tudja, van-e kinek küldeni. |
| `RemoteActivityHelper` | Play Store megnyitása a watchon | Ha a capability hiányzik, felajánljuk a telepítést. |

Feltétel: a watch app **ugyanazzal az `applicationId`-vel és aláírással** épül, mint a telefonos — a Data Layer csak így kommunikál.

### D3 — A Flutter-híd mintája

Új platform-channel pár, a `WorkoutSessionNotifierService` (lásd `mobile/lib/core/workout_session_notifier/workout_session_notifier_service.dart`) mintájára:

- `MethodChannel('lifey/watch')` — Dart → natív parancsok: `isWatchAvailable`, `startWorkout`, `updateState`, `endWorkout`.
- `EventChannel('lifey/watch/events')` — natív → Dart események: `workoutStartedOnWatch`, `workoutSummary`, `watchReachabilityChanged`, (később) `setLoggedOnWatch`.

A Dart oldali `WatchWorkoutService` ugyanúgy injektálható channel-lel/flag-ekkel készül, mint a notifier service, hogy a meglévő tesztminta (fake channel, nem-mobil teszt-host) változtatás nélkül működjön.

### D4 — Ki a „forrás” (source of truth)?

**V1-ben a telefon a mester, a watch a szolga.** Az edzés-session a Drift-cache-ben él (offline-first, outbox), a watch csak: (a) szenzoradatot gyűjt, (b) állapotot jelenít meg, (c) a végén összegzést küld. Ez radikálisan leegyszerűsíti a konfliktuskezelést — nincs kétirányú merge, a watch-összegzés ugyanazon az absent-megőrző `repo.update` úton érkezik, mint a Health-import.

---

## 3. Architektúra-áttekintés

```
┌─────────────── telefon (Flutter) ───────────────┐
│ LogSessionScreen / SessionsTab / ResumePrompt   │
│        │ (ugyanazok a hívási pontok, mint a     │
│        │  WorkoutSessionNotifierService-nél)    │
│        ▼                                        │
│ WatchWorkoutService (Dart)                      │
│   MethodChannel 'lifey/watch'                   │
│   EventChannel  'lifey/watch/events'            │
└───────┬─────────────────────────────────────────┘
        │
  ┌─────┴──────────────┐        ┌──────────────────────┐
  │ iOS natív (Swift)  │        │ Android natív (Kotlin)│
  │ WatchBridge:       │        │ WatchBridge:          │
  │  startWatchApp()   │        │  MessageClient        │
  │  WCSession         │        │  DataClient           │
  └─────┬──────────────┘        └──────┬───────────────┘
        │                              │
┌───────▼──────────────┐      ┌────────▼───────────────┐
│ Apple Watch app      │      │ Wear OS app            │
│ (SwiftUI, watchOS10+)│      │ (Compose, Wear OS 3+)  │
│ HKWorkoutSession +   │      │ Health Services        │
│ HKLiveWorkoutBuilder │      │ ExerciseClient +       │
│ (.traditionalStrength│      │ foreground service     │
│  Training)           │      │ (STRENGTH_TRAINING)    │
│ → HKWorkout mentés   │      │ → Health Connect record│
└──────────────────────┘      └────────────────────────┘
```

### Adatfolyamok

**Indítás (telefon → watch):**
1. A user a telefonon elindítja az edzést (`LogSessionScreen`, ugyanott, ahol ma a `WorkoutSessionNotifierService.start()` hívódik).
2. `WatchWorkoutService.startWorkout(sessionClientId, title, startedAt, state)`.
3. iOS: a natív híd `startWatchApp(with:)`-et hív (`.traditionalStrengthTraining`, `.indoor`), majd `updateApplicationContext`-ben átadja a session-metaadatot (`sessionClientId`, cím, kezdés). A watch app a `handle(_:)`-ben elindítja a `HKWorkoutSession`-t.
4. Android: a híd a Data Layer-be írja a session-állapotot (`DataClient`), és `MessageClient`-tel `START` üzenetet küld. A watchon a `WearableListenerService` foreground service-t indít, az `ExerciseClient.startExercise()`-t hív.
5. A watch visszajelez (`workoutStartedOnWatch`) — a telefon UI opcionálisan mutathat egy kis „⌚ csatlakozva” jelzést.

**Élő állapot (telefon → watch, edzés közben):**
- Minden set-logolás / pihenőindítás után a meglévő `WorkoutSessionState` JSON (exerciseName, setsDone/total, restEndsAtEpochMs…) megy ki `updateApplicationContext` / `DataItem` formában. A watch ebből rendereli a „Bench Press · 2/4 · pihenő 0:47” képernyőt. **Nincs új állapotmodell** — a Live Activity-vel közös.

**Mérés (watch, lokálisan):**
- iOS: `HKLiveWorkoutBuilder` delegate → pulzus + aktív kalória a watch UI-ra.
- Android: `ExerciseUpdateCallback` → `HEART_RATE_BPM` és `CALORIES_TOTAL` a watch UI-ra. A foreground service Ongoing Activity-ként jelenik meg a watch felületén.

**Lezárás (telefon → watch → telefon):**
1. A user a telefonon befejezi az edzést → `WatchWorkoutService.endWorkout(sessionClientId)`.
2. `END` parancs megy a watchnak (WCSession message + applicationContext fallback / MessageClient + DataItem fallback).
3. A watch lezárja a sessiont, elmenti a workoutot (HealthKit `HKWorkout` / Health Connect `ExerciseSessionRecord`), és visszaküldi az összegzést: `{sessionClientId, activeCalories, averageHeartRate, healthWorkoutId, watchStartedAt, watchEndedAt}` — iOS-en `transferUserInfo`-val (sorban áll, ha a telefon-app nem fut), Androidon `MessageClient`-tel + DataItem fallback.
4. A telefon Dart oldala az eseményt a meglévő absent-megőrző `WorkoutSessionRepository.update` hívásra fordítja (`Value(activeCalories)`, `Value(averageHeartRate)`, `Value(healthWorkoutId)`) — pontosan úgy, ahogy a Health-import gazdagít. Innen a normál outbox/sync viszi a backendre. **Backend-változás: nincs.**

**Kézbesítési garancia a lezárásra:** ha a watch a lezáráskor nem elérhető (kifutott a hatótávból, lemerült), a `desiredPhase: ended` a context/DataItem-ben marad; a watch a következő kapcsolódáskor lezár és akkor küldi az összegzést. A telefon-oldal ezért a summary-t **bármikor, akár napokkal később is** el tudja fogadni — a `sessionClientId` alapján találja meg a sessiont, és mivel az update absent-megőrző, egy már szinkronizált sessiont is biztonságosan gazdagít utólag.

---

## 4. iOS watch app — részletes terv

### 4.1 Projektszerkezet

- Új watchOS App target a `mobile/ios/Runner.xcworkspace`-ben: `LifeyWatch` (SwiftUI, watchOS 10.0+ minimum — a friss workout API-k és a modern SwiftUI lifecycle miatt).
- A `flutter build ios` a teljes workspace-t építi, tehát a watch target **külön build-pipeline nélkül** része lesz az IPA-nak. (Ugyanez a helyzet, mint a Live Activity widget-extensionnél — bevált.)
- Fájlok (javasolt):
  - `LifeyWatch/LifeyWatchApp.swift` — `@main`, `WKApplicationDelegateAdaptor`
  - `LifeyWatch/WorkoutManager.swift` — `HKWorkoutSession` + `HKLiveWorkoutBuilder` életciklus (ObservableObject)
  - `LifeyWatch/PhoneConnector.swift` — `WCSessionDelegate`, parancsok/állapot fogadása, összegzés küldése
  - `LifeyWatch/Views/ActiveWorkoutView.swift` — fő képernyő (pulzus, kcal, eltelt idő, gyakorlat/szett, pihenő)
  - `LifeyWatch/Views/IdleView.swift` — „Indíts edzést a telefonon” üres állapot
- Telefon-oldali natív híd: `mobile/ios/Runner/WatchBridge.swift` — a `lifey/watch` MethodChannel + EventChannel kezelése, `WCSessionDelegate` a telefonon.

### 4.2 Engedélyek, entitlementek

- **HealthKit entitlement a watch targetre is** (a meglévő telefonos mellé): `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` a watch Info.plist-be. A watch **ír** is (workout mentés), tehát write-jog is kell: `HKQuantityType(.activeEnergyBurned)`, `HKQuantityType(.heartRate)` read + `HKObjectType.workoutType()` share.
- A HealthKit-engedélykérés watchOS-en a watch appban fut le első indításkor; a `startWatchApp` első hívása előtt a telefon-oldali onboardingban jelezzük, hogy a watchon jóvá kell hagyni.
- Background mode a watch targeten: `workout-processing` (enélkül a session nem él túl csuklóleengedést).

### 4.3 Workout session életciklus (Swift vázlat)

```swift
// WorkoutManager.swift — lényegi váz
func start(configuration: HKWorkoutConfiguration) async throws {
    session = try HKWorkoutSession(healthStore: store, configuration: configuration)
    builder = session.associatedWorkoutBuilder()
    builder.dataSource = HKLiveWorkoutDataSource(healthStore: store,
                                                 workoutConfiguration: configuration)
    session.delegate = self
    builder.delegate = self
    let start = Date()
    session.startActivity(with: start)
    try await builder.beginCollection(at: start)
}

// HKLiveWorkoutBuilderDelegate — élő metrikák
func workoutBuilder(_ b: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
    // heartRate → bpm, activeEnergyBurned → kcal; @Published property-kre írás
}

func end() async throws -> WorkoutSummary {
    session.end()
    try await builder.endCollection(at: Date())
    let workout = try await builder.finishWorkout()   // → HKWorkout, mentve a HealthKitbe
    return WorkoutSummary(
        healthWorkoutId: workout?.uuid.uuidString,
        activeCalories: /* builder statistics: activeEnergyBurned sum */,
        averageHeartRate: /* builder statistics: heartRate avg */)
}
```

- Indítási konfiguráció: `activityType = .traditionalStrengthTraining`, `locationType = .indoor`.
- A `handle(_ workoutConfiguration:)` (WKApplicationDelegate) a `startWatchApp` érkezési pontja — innen hívjuk a `start`-ot, majd a legfrissebb `applicationContext`-ből olvassuk a session-metaadatot (cím, `sessionClientId`, kezdő state).
- **Idő-forrás:** a workout `startedAt`-ja a telefoné (a Drift-session már létezik) — a watch a saját HKWorkout-ját a tényleges watch-indítástól méri; az esetleges 1–5 mp csúszás elfogadható, az összegzésben mindkét időt visszaküldjük.

### 4.4 Watch UI (V1)

Egyetlen aktív képernyő, TabView-val két lappal (Apple Workout-app minta):

1. **Metrika-lap**: eltelt idő (nagy), pulzus (élő, ♥ ikonnal), aktív kcal, aktuális gyakorlat + szett-számláló (`exerciseName`, `setsDone/setsTotal` a telefonról).
2. **Vezérlő-lap**: End gomb (megerősítéssel; a telefonnak is szól — lásd 8.2 nyitott kérdés), Pause/Resume (csak a szenzor-sessiont pauzálja, a telefon-session időzítését nem — V1-ben akár el is hagyható).
- Pihenő: ha `restEndsAtEpochMs` a jövőben van, a metrika-lapon visszaszámláló + **haptika a pihenő lejártakor** (`WKInterfaceDevice.play(.notification)`) — ez a watch-verzió egyik legnagyobb hozzáadott értéke.
- Lokalizáció: HU/EN, a meglévő arb-kulcsok mintájára (a watch appnak saját `Localizable.xcstrings`-e lesz; a kulcsnevek kövessék az `app_en.arb` megfelelőit).

### 4.5 Telefon-oldali natív híd (Runner)

- `WatchBridge.swift` regisztrálja a channeleket az `AppDelegate`-ben (ugyanott, ahol a Live Activity channel).
- `startWorkout` implementáció:
  1. `WCSession.default.isPaired && isWatchAppInstalled` ellenőrzés → ha nem, `notAvailable` eredmény (a Dart oldal csendben no-opol, mint a notifier service engedély-megtagadásnál).
  2. `HKHealthStore().startWatchApp(with: config) { success, error in ... }`
  3. `updateApplicationContext(["sessionClientId": ..., "title": ..., "startedAtEpochMs": ..., "state": {...}, "desiredPhase": "running"])`
- `updateState` → csak az applicationContext frissítése (+ ha `isReachable`, `sendMessage` az azonnali frissítésért).
- `endWorkout` → `sendMessage(["command": "end"])` ha elérhető, és **mindig** `desiredPhase: "ended"` a contextbe (fallback).
- Bejövő `transferUserInfo` (összegzés) → EventChannel-re `workoutSummary` esemény. Ha a Flutter engine épp nem fut (app kilőve), a WCSession a userInfo-t a következő indulásig őrzi — az `AppDelegate` a delegate-et korán állítsa be, hogy az esemény ne vesszen el.

---

## 5. Wear OS app — részletes terv

### 5.1 Projektszerkezet

- Új Gradle-modul: `mobile/android/wear/` (a `settings.gradle`-be felvéve). Kotlin + Compose for Wear OS, `minSdk 30` (Wear OS 3), `targetSdk` a telefonéval azonos.
- **Azonos `applicationId`** a telefonos apppal (Data Layer-feltétel), `<uses-feature android:name="android.hardware.type.watch"/>`, standalone=false meta-data V1-ben (`com.google.android.wearable.standalone: false` — a telefon-app a mester).
- Fájlok (javasolt):
  - `wear/src/main/java/.../MainActivity.kt` + `ui/ActiveWorkoutScreen.kt`, `ui/IdleScreen.kt` (Compose for Wear OS, `TimeText`, `ScalingLazyColumn` ahol kell)
  - `ExerciseService.kt` — foreground service, ami a Health Services `ExerciseClient`-et birtokolja; Ongoing Activity notificationnel
  - `PhoneListenerService.kt : WearableListenerService` — `START`/`END`/`STATE` üzenetek fogadása (manifestben deklarálva → app-újraindítás nélkül ébred)
  - `SummarySender.kt` — összegzés küldése a telefonnak
- Telefon-oldali natív híd: `mobile/android/app/src/main/kotlin/.../WatchBridge.kt` — `lifey/watch` channelek, `MessageClient`/`DataClient`/`CapabilityClient` hívások, bejövő üzenetek fogadása (a telefonon is kell egy `WearableListenerService` a watch → telefon összegzéshez, hogy kilőtt app mellett is megérkezzen; az esemény ilyenkor perzisztálódik — lásd 5.4).

### 5.2 Engedélyek

- Watch manifest: `BODY_SENSORS` (pulzus — runtime permission a watchon!), `ACTIVITY_RECOGNITION`, `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_HEALTH`, `POST_NOTIFICATIONS`.
- A `BODY_SENSORS`-t a watch app első indításkor / első `START` parancsnál kéri el. Ha megtagadva: az exercise elindul, de pulzus nélkül (a Health Services kalóriabecslése gyengébb lesz) — az összegzésben `averageHeartRate: null`.
- Health Connect írás (opcionális, ajánlott): `androidx.health.connect` a watch-modulban vagy a session végén a **telefon** írja HC-be — egyszerűbb, ha a telefon írja, mert ott már van HC-integráció (doc 26); ekkor a `healthWorkoutId` a telefon által írt HC-record id-je. **Döntés: a telefon ír HC-be** a beérkező összegzésből, a watch csak mér.

### 5.3 Exercise életciklus (Kotlin vázlat)

```kotlin
// ExerciseService.kt — lényegi váz
val config = ExerciseConfig(
    exerciseType = ExerciseType.STRENGTH_TRAINING,
    dataTypes = setOf(DataType.HEART_RATE_BPM, DataType.CALORIES_TOTAL),
    isAutoPauseAndResumeEnabled = false,   // súlyzós edzésnél az auto-pause zavaró
    isGpsEnabled = false,
)
exerciseClient.setUpdateCallback(callback)
exerciseClient.startExercise(config)

// ExerciseUpdateCallback
override fun onExerciseUpdateReceived(update: ExerciseUpdate) {
    val hr = update.latestMetrics.getData(DataType.HEART_RATE_BPM).lastOrNull()?.value
    val kcal = update.latestMetrics.getData(DataType.CALORIES_TOTAL)?.total
    // → StateFlow → Compose UI + mentés a végösszegzéshez
}

suspend fun end(): WorkoutSummary {
    exerciseClient.endExercise()
    // az utolsó ExerciseUpdate aggregátumaiból: total kcal, avg HR (magunk átlagoljuk a mintákból)
}
```

- Egyetlen app futtathat exercise-t egyszerre a watchon; ha más app edzése fut, a `startExercise` jelzi — ilyenkor a watch UI hibát mutat, és a telefonnak `startRejected` esemény megy (a telefon-app kiírja: „Az órán már fut egy edzés”).
- A foreground service Ongoing Activity-t regisztrál, így az edzés a watch felületén (recent apps / felszín) mindig visszaugorható.

### 5.4 Kézbesítés kilőtt telefon-app mellett

A watch → telefon összegzés `MessageClient`-tel megy, de a telefonon a manifestben deklarált `WearableListenerService` fogadja, aminek **nem előfeltétele a futó Flutter-engine**. A service az összegzést egy kis lokális pufferbe írja (SharedPreferences/fájl), és a Dart oldal app-indításkor (a `WorkoutResumePrompt` meglévő „induláskori sweep” pontján) kiolvassa és feldolgozza. Így a summary akkor sem vész el, ha a user az edzés lezárása után azonnal kilőtte az appot.

---

## 6. Flutter-oldali munka (Dart)

### 6.1 Új szolgáltatás: `WatchWorkoutService`

Hely: `mobile/lib/core/watch/watch_workout_service.dart` (+ provider). API:

```dart
class WatchWorkoutService {
  Future<bool> isWatchAppAvailable();          // párosítva + telepítve
  Future<void> startWorkout({required String sessionClientId, required String title,
      required DateTime startedAt, required WorkoutSessionState state});
  Future<void> updateState({required String sessionClientId,
      required WorkoutSessionState state});    // set-logolás, pihenőindítás után
  Future<void> endWorkout({required String sessionClientId});
  Stream<WatchEvent> get events;               // summary, startedOnWatch, startRejected…
}
```

- A `WorkoutSessionState`-et **újrahasznosítjuk** a `workout_session_notifier` csomagból (esetleg közös helyre emelve, pl. `core/workout_session_state.dart` — a notifier service és a watch service is importálja).
- Tesztelhetőség: injektálható `MethodChannel` + `isAvailable`/platform-flag konstruktor-paraméterek, pontosan a `WorkoutSessionNotifierService` mintájára — a meglévő tesztek stílusában unit-tesztelhető nem-mobil hoston is.

### 6.2 Hívási pontok

Ugyanaz a három hely, ahol ma a notifier service hívódik (a szolgáltatás maga válogatja szét a platform-ágakat):

| Hely | Hívás |
|---|---|
| `LogSessionScreen` — edzés indítása | `startWorkout(...)` (a notifier `start` mellett) |
| `LogSessionScreen` — set logolva / pihenő indul | `updateState(...)` (a notifier `update` mellett) |
| `LogSessionScreen` / `SessionsTab` — edzés vége | `endWorkout(...)` (a notifier `end` mellett) |
| `WorkoutResumePrompt` — induláskori sweep | árva watch-session lezárása (`endWorkout`), pufferelt summary feldolgozása |

Opcionális refaktor: a két szolgáltatás fölé egy vékony `WorkoutSurfaceCoordinator` (egy hívás → notifier + watch), hogy a képernyők ne két service-t hívjanak — de V1-ben a párhuzamos hívás is elfogadható, kisebb diff.

### 6.3 Summary-feldolgozó

```dart
// events stream: WatchWorkoutSummary(sessionClientId, activeCalories,
//                averageHeartRate, healthWorkoutId, ...)
await repo.update(summary.sessionClientId,
  activeCalories: Value(summary.activeCalories),
  averageHeartRate: Value(summary.averageHeartRate),
  healthWorkoutId: Value(summary.healthWorkoutId),
  // minden más mező absent → érintetlen
);
```

- Ha a `sessionClientId`-hez nincs session (elméleti eset: törölték), a summary-t eldobjuk, logolva.
- Ha a sessionben **már van** `healthWorkoutId`, a watch-summary **nem írja felül** — egyszerű „csak ha null” guard a feldolgozóban. (Eredetileg a kézi Health-import frissebb user-szándékának védelmére íródott; a manuális import 2026-07-16-tal megszűnt — 7.5.8 —, de a guard továbbra is hasznos: megvédi egy már feldolgozott watch-summaryt egy késve/duplán beérkező második summary-től.)
- UI: a session-kártyán a meglévő `fromAppleHealth`-badge logika jelenítheti meg, hogy az adat az óráról jött — V1-ben elég a meglévő „Health” badge, később külön ⌚ badge.

### 6.4 Beállítás / feature-gate

- Új kapcsoló a Settingsben: „Edzés indítása az órán” (alapból **be**, ha van párosított óra + telepített watch app; a kapcsoló csak akkor látszik, ha `isWatchAppAvailable()` valaha igazat adott).
- Az egész watch-híd `Platform.isIOS || Platform.isAndroid` mögött, más platformon no-op — az app watch nélkül pontosan úgy működik, mint ma.

---

## 7. Fázisokra bontás és becslés

| Fázis | Tartalom | Becslés (relatív) |
|---|---|---|
| **F0 — Spike-ok** | (a) `startWatchApp` + `handle(_:)` end-to-end proof of concept üres watch appal; (b) Wear `WearableListenerService` ébresztés kilőtt watch-app mellett; (c) Gradle wear-modul + Flutter build együttélés ellenőrzése | S–M |
| **F1 — Dart híd + állapot-refaktor** | `WatchWorkoutService`, `WorkoutSessionState` közösre emelése, hívási pontok bekötése, unit tesztek (fake channel) | M |
| **F2 — iOS watch MVP** | Watch target, WorkoutManager (start/end, HR+kcal), PhoneConnector, 2 képernyős UI, summary-visszaút, `WatchBridge.swift` | L |
| **F3 — Wear OS MVP** | Wear-modul, ExerciseService + ListenerService, Compose UI, summary-visszaút + telefon-oldali perzisztens fogadó, HC-írás a telefonon | L |
| **F4 — Pihenő + polish** | `restEndsAtEpochMs` visszaszámláló + haptika mindkét watchon, lokalizáció, badge, Settings-kapcsoló, hibautak (startRejected, engedély-megtagadás) | M |
| **F4B — Design-parity (utólag felvett fázis)** | A 41-es design F4-scope-jának le nem fejlesztett **funkcionális** elemei: controls-lap/szekció + Pause, end-requested-váró és saved-összegző képernyő (iOS), hibaképernyők az órán, degradált HR-állapot, GO-pillanat, telefon-oldali „Measuring” pill + ⌚ badge — részletes, kód ellen ellenőrzött lista a 12. fejezetben | M–L |
| **F5 — (v2) Set-logolás a watchról** | „+1 szett” gomb a watchon → esemény a telefonra → a telefon logolja (a telefon marad a mester); offline eset: csak ha a telefon elérhető | M–L |
| **F6 — (v2) Standalone indítás a watchról** | Edzés indítása óráról telefon nélkül; a watch lokálisan gyűjt, és kapcsolódáskor a telefon sessiont kreál belőle — külön tervezést igényel (ütközés a resume-prompt logikával) | L |

Az F2 és F3 egymástól független, párhuzamosan is mehet. **Tényleges sorrend**: F0 → F1 → F3 → F4(Android fele) — az eredeti javaslat (iOS előbb) helyett Android ment előbb, mert ebben a fejlesztői környezetben (Windows) nincs Xcode, csak Android SDK + emulátor volt elérhető build/tesztelés célra. Az iOS-oldal (F2, F4 iOS fele) Mac-en folytatódik.

---

## 7.5 Android — tényleges megvalósítás, eltérések a tervtől

Ez az alfejezet a **ténylegesen leszállított** Wear OS implementációt írja le — a 4–10. fejezet eredeti terve több ponton pontatlannak/hiányosnak bizonyult a valós Play Services viselkedéssel szemben; itt van dokumentálva, mi és miért változott.

### 7.5.1 Fájlok (a tervezettek helyett/mellett ténylegesen létrejöttek)

**`mobile/android/wear/src/main/kotlin/com/khunor/lifey/`:**
- `MainActivity.kt` — Compose host (`IdleScreen`/`ActiveWorkoutScreen` a `SessionStateHolder.phase` alapján) + a runtime engedélyek elkérése (lásd 7.5.3)
- `SessionStateHolder.kt` — process-wide `StateFlow`-alapú állapot (session-metaadat + élő metrikák), amit a `PhoneListenerService`, az `ExerciseService` és a Compose UI is olvas/ír
- `PhoneListenerService.kt : WearableListenerService` — start/state/end üzenetek és a state DataItem fogadása
- `ExerciseService.kt` — foreground service, Health Services `ExerciseClient`, élő HR/kcal, pihenő-haptika ütemező
- `SummarySender.kt` — összegzés/`startRejected`/`endRequested` küldése a telefonnak
- `ui/IdleScreen.kt`, `ui/ActiveWorkoutScreen.kt` — a tervezett 2 képernyő, Compose for Wear OS-ben

**`mobile/android/app/src/main/kotlin/com/khunor/lifey/`:**
- `WatchBridge.kt` — a tervezett MethodChannel/EventChannel híd, kibővítve (lásd 7.5.2)
- `WatchSummaryBuffer.kt` + `PhoneWatchSummaryListenerService.kt` — a tervezett "kilőtt app melletti kézbesítés" (§5.4) SharedPreferences-alapú puffere

### 7.5.2 Architektúra-eltérés: a state a **DataItem helyett/mellett az üzenetben** utazik

A terv (§D2, §3 "Élő állapot") a `DataClient`/DataItem-et szánta a session-állapot (gyakorlatnév, szettek, pihenő-időzítő) elsődleges szinkron-csatornájának, a `MessageClient`-et pedig csak "alacsony-latency nudge"-nak. **Emulátoron párosított két Wear OS/telefon eszköz között ez a DataItem-szinkron megbízhatatlannak bizonyult**: a `dataClient.putDataItem()` lokálisan mindig sikeresnek jelentkezett, de a másik oldal `onDataChanged`-je **soha nem hívódott meg** — a logcat `Mismatched certificate: AppKey[com.google.android.gms,...]` hibákat mutatott a két párosított eszköz Play Services-példánya közti belső capability/data-szinkron körül (ismert, dokumentálatlan gyengéje az Android Studio-s emulátor-párosításnak).

**A javítás**: a `start`/`state` üzenetek (`WatchBridge.kt`'s `stateMessagePayload()`) mostantól **a teljes állapotot JSON-ban hordozzák** (`sessionClientId`, `title`, `state{exerciseName, setsDone, setsTotal, restEndsAtEpochMs}`), nem csak a `sessionClientId`-t. A wear oldali `PhoneListenerService.applyStateMessage()` ezt dekódolja és alkalmazza — ez lett az elsődleges csatorna. A `pushState`/DataItem write megmaradt, mint best-effort tartalék (ha egyszer a szinkron működne, pl. fizikai eszközön, az is segít az "óra épp nem elérhető" esetben) — de **nem megbízható**, erre nem szabad építeni.

Ugyanez a bizonytalanság **valós fizikai eszközön (nem emulátoron) elképzelhető, hogy nem áll fenn** — ha valaha fizikai Wear OS órán tesztelünk, érdemes újra megnézni, hogy a DataItem-szinkron ott működik-e; ha igen, a duplikált JSON-payload akkor is ártalmatlan (redundáns, de helyes).

### 7.5.3 Új felfedezések: futásidejű engedélyek (a tervben nem szerepeltek)

A §5.2 csak a `BODY_SENSORS`-t (és a manifestben deklarált `ACTIVITY_RECOGNITION`/`FOREGROUND_SERVICE_HEALTH`-et) említette. Valós tesztelés (API 34+/36 rendszerképen) két további, **futásidőben ténylegesen megadandó** engedélyt igényelt, amik nélkül az `ExerciseService` `SecurityException`-nel elszállt:

1. **`ACTIVITY_RECOGNITION`** — a `health`-típusú foreground service indítása (API 34+) megköveteli, hogy legalább egy a `{ACTIVITY_RECOGNITION, HIGH_SAMPLING_RATE_SENSORS, health.READ_HEART_RATE, health.READ_SKIN_TEMPERATURE, health.READ_OXYGEN_SATURATION}` halmazból ténylegesen meg legyen adva — nem elég deklarálni a manifestben.
2. **`android.permission.health.READ_HEART_RATE`** — API 36+ rendszerképeken a Health Services **elutasítja** a `HEART_RATE_BPM` adattípust, ha csak `BODY_SENSORS` van megadva; ez az új, granulárisabb engedély kell helyette/mellette.

Mindkettőt a `MainActivity.kt` kéri el a `BODY_SENSORS`/`POST_NOTIFICATIONS` mellett, első indításkor.

### 7.5.4 Package visibility (Android 11+) — új manifest-bejegyzés mindkét oldalon

A `MessageClient`/`DataClient`/`CapabilityClient` hívások **némán** blokkolva voltak (`AppsFilter: ... BLOCKED` a logcat-ban), mert egyik manifest sem deklarálta a láthatóságot a Wear companion csomagra. Mindkét (`mobile/android/app` és `mobile/android/wear`) manifestbe bekerült:
```xml
<queries>
    <package android:name="com.google.android.apps.wear.companion"/>
    <package android:name="com.google.android.wearable.app"/>
</queries>
```
Enélkül a teljes Data Layer néma módon nem működik — ez valószínűleg **minden** Android 11+ célzó, Wearable Data Layer-t használó appra vonatkozik, nem csak erre.

### 7.5.5 `CapabilityClient` megbízhatatlansága — `NodeClient` fallback

A §D2-ben tervezett `CapabilityClient`-alapú "van-e kinek küldeni" detekció (`lifey_watch_workout` capability) ugyanabba a Play Services szinkron-problémába futott, mint a DataItem (7.5.2) — a capability-broadcast néha sosem jutott el a másik oldalra, így `FILTER_REACHABLE` (és még `FILTER_ALL` is) üres listát adott, **annak ellenére, hogy a `NodeClient.getConnectedNodes()` helyesen látta a párosított órát**. Javítás (`WatchBridge.kt`'s `targetNodes()`): ha a capability-alapú keresés üres, essen vissza az összes csatlakoztatott node-ra — mivel ennek az appnak úgyis csak egy watch-társa lehet (azonos `applicationId`), egy node, amin nincs telepítve a wear app, egyszerűen figyelmen kívül hagyja az üzenetet.

### 7.5.6 F4 (Android fele) — a megvalósult forma

- **Pihenő-visszaszámláló + haptika**: `SessionStateHolder.onStateSynced`-ben a `restEndsAtEpochMs` — a többi mezővel ellentétben — **mindig felülíródik** (nem "hiányzó → előző érték megtartása"), mert a null↔érték váltás gyakori egy session alatt, és a null a wire-on megkülönböztethetetlen a "hiányzó kulcs"-tól. Az `ExerciseService` a service teljes életciklusán át figyeli ezt egy `Job`-bal ütemezett `delay`+`Vibrator.vibrate(VibrationEffect.createOneShot(...))` hívással — függetlenül attól, hogy az `ActiveWorkoutScreen` épp látszik-e.
- **Settings-kapcsoló**: `UserSettings.watchWorkoutEnabled` (default: be), a Settings képernyőn csak akkor jelenik meg a sor, ha `isWatchAppAvailable()` aktuálisan igazat ad (a terv §6.4 "valaha igazat adott" perzisztens-flag ötletéhez képest egyszerűsítve — nincs külön perzisztált mező). A `startWorkout`/`updateState` hívások kapuzva vannak ezzel; az `endWorkout` **szándékosan nem** — ha a kapcsolót menet közben kikapcsolják, egy már elindult watch-session-t akkor is le kell tudni zárni.
- **Lokalizáció**: `values-en/strings.xml` mint teljes HU/EN pár (a `values/strings.xml` HU az alap).
- **`startRejected` visszajelzés**: snackbar a telefonon (`AppSnackbar.showInfo`), ha az órán már fut más edzés.
- **Ikonok**: a telefon app meglévő launcher- és értesítés-ikonjai (`ic_launcher.png`, `ic_stat_lifey.xml`) újrahasznosítva a wear modulban — nem kellett új design asset.
- **Végpont (End gomb) döntés**: a §8.2 nyitott kérdés 1 (b) opciója valósult meg — a watch End gombja `endRequested` üzenetet küld, a telefon a saját `_finishWorkout()`-ját futtatja (RPE-dialógus, majd lezárás), a watch csak akkor zárja a szenzor-sessiont, amikor a valódi `end` parancs visszaér.

### 7.5.7 A HC-írás végleges helye (§5.2 döntés megerősítve, más úton)

A §5.2 "a telefon ír HC-be" döntése megvalósult, de **nem natív Kotlin kóddal**, hanem a meglévő Dart `health` csomagon keresztül: `HealthService.writeStrengthWorkoutAndGetId()` (`mobile/lib/core/health/health_service.dart`) írja a Health Connect rekordot és — mivel a `health` csomag `writeWorkoutData` nem ad vissza uuid-ot — utána a meglévő `recentStrengthWorkouts()` lekérdezéssel (idő-közelség alapján) megkeresi a saját maga által írt rekord uuid-ját. Ez a `workout_resume_prompt.dart`'s `_onWatchEvent`-jéből hívódik, amikor a watch-summary `healthWorkoutId`-ja null (ez csak Androidon fordul elő — iOS-en a watch már valódi `HKWorkout` uuid-ot küld). Ez a megoldás elkerülte egy új natív Health Connect Gradle-függőség bevezetését.

### 7.5.8 A manuális Health-import teljes megszűnése

A doc 16/26 által leírt **manuális** "Import from Health" workout-párosítási flow (finish-time dialógusok, edit-time "pair now" gomb) **2026-07-16-tal teljesen megszűnt** — mindkét platformon, mivel megosztott Flutter/Dart kódban élt. A `_finishWorkout()` mostantól: RPE-visszajelzés → egyenesen lezárás + dashboard, health-dialógus nélkül. Az `activeCalories`/`averageHeartRate`/`healthWorkoutId` mezők és a rájuk épülő UI (stat-kártyák, "Health" jelvény a session-listán) megmaradtak — ezek forrása mostantól kizárólag a watch-összegzés. Ez feleslegessé tette a §8.1 kockázati táblázat "HealthKit dupla-számolás" sorát is (nincs többé manuális import-lista, amit szűrni kellene).

### 7.5.9 F4B — Wear OS design-styling (B6) és egy UX-korrekció menet közben (2026-07-17)

A 12. fejezet felmérésekor (2026-07-17 reggel) az F4B lista B1–B6 és B11–B13 tételei még mind hiányoztak Androidon. Ugyanaznap, egy ülésben lefejlesztve:

**Design-token infrastruktúra** (`mobile/android/wear/src/main/kotlin/com/khunor/lifey/ui/theme/`):
- `LifeyColors.kt` — a 41-es prompt §2 teljes dark-palettája (surface-rétegek, `primary`/`secondary`/`tertiary`, metric-accent színek, error-család) egy helyen, flat konstansként.
- `LifeyTheme.kt` — ezeket Wear Compose Material `Colors`/`Typography`-jára képezi (tabular-szám `fontFeatureSettings` a hero-számjegyeken), és explicit true-black háttérre kényszeríti a képernyőt — a modulnak nincs `themes.xml`-je, enélkül a platform default (nem fekete) háttéren futott volna az app.
- `LifeyShapes.kt` — a prompt §1 radius-skálája (8/16/20/24/pill) konstansként.
- Új függőség: `androidx.compose.material:material-icons-extended` (♥ `Favorite`, láng `LocalFireDepartment`, `FitnessCenter`, `Timer`, `Pause`/`PlayArrow`/`Stop`, `HeartBroken`, `PriorityHigh`) — a Wear Compose saját `Icon`-ja bármilyen `ImageVector`-t elfogad, ez a klasszikus Compose Material ikon-készlet így is működik.

**Alkalmazva** `IdleScreen`/`ActiveWorkoutScreen`/`ErrorScreen`-en: „STRENGTH”/„REST” fejléc-chip, ♥/🔥 accent-színes ikonok a metrikákon, `container`-hátterű gyakorlat-kártya, „already running” hiba ikon-badge-dzsel és alcímmel, degradált HR-chip `heart_broken` ikonnal, `surface`-badge a leaf-mark mögött.

**Egy elszánt token-ellentmondás**: a ♥ (heart-rate) accent színe a promptban `#C46A6A`, de a leszállított canvas (`Lifey Watch Design.dc.html`) **minden egyes frame-jén** (Apple Watch, Wear OS, telefon) következetesen `#D97F7F`-et használ. Ugyanazt a szabályt alkalmazva, mint amit a 42-es doc D0.1-je az eltelt idő színére hozott (canvas > prompt, mert a canvas a későbbi, vizuálisan ellenőrzött állapot), a `LifeyColors.heart` a canvas értékét követi. Ez a 42-es dokban nincs formálisan D0-döntésként rögzítve — érdemes megerősíteni, hogy ez szándékos volt-e a canvas oldalán.

**UX-korrekció menet közben — B11 terve megváltozott**: az eredeti (fejlesztés közben leszállított) verzió egyetlen görgethető `Column`-ba tette a metrikákat/pihenő-hero-t ÉS az End/Pause gombokat (a §12.1 B11 sorának megfelelően, csak `ScalingLazyColumn` helyett plain `Column`-nal — lásd az eredeti 7.5.6-ot). **Éles Wear OS emulátoron ez rosszul nézett ki**: a tartalom magassága majdnem pontosan kitöltötte a kerek kijelzőt, ezért az End gomb görgetés nélkül is belógott minden metrika-/pihenő-nézet aljába, a kerek burkolat pedig csúnyán körbevágta. Felhasználói visszajelzésre újratervezve: **2-lapos `HorizontalPager`** — 1. lap: metrikák vagy pihenő-hero (soha semmilyen gomb), 2. lap: End + Pause, egy elhalványított gyakorlat-emlékeztető kártyával. Az oldalak közti navigációhoz egy saját, kézzel rajzolt 2-pontos indikátor készült (`PageDots`) — a Wear Compose Material saját `HorizontalPageIndicator`-ja kipróbálva **semmit nem rajzolt ki** kerek emulátoron (pixel-szintű ellenőrzéssel megerősítve, crash nélkül; feltehetően a curved-style layout-nak több kontextus kell, mint amit egy sima `BoxScope` ad neki — nem lett tovább vizsgálva). **Következmény a hátralévő munkára**: az A5 (ENDING/SUMMARY Wear-fázisok, lásd D1.3 a 42-es dokban) ugyanezt a lapozós mintát kövesse a görgetés helyett, amikor megépül.

**Egyéb, a felmérés közben észrevett hiány javítva**: a `RestHero`-ból hiányzott a kis HR/kcal-sor, amit a canvas Wear 04 mutat (a pihenő alatt korábban egyáltalán nem látszott pulzus/kalória) — pótolva. A gyakorlatnév és a mértékegység-szövegek `maxLines`/`overflow` védelem nélkül futottak, ami hosszú gyakorlatnévnél csonkolást, rövid mértékegységnél (`kcal`) sortörést okozott — mindkettő javítva.

**Ellenőrzés módja**: `:wear:compileDebugKotlin` + `:wear:assembleDebug` zöld; a tényleges UI-t egy futó `Wear_OS_Large_Round` emulátorra telepítve, `adb`-vel indított állapotokkal (idle/metrika/pihenő/controls/hiba) screenshotolva ellenőrizve — nem csak build-szinten. A screenshothoz használt ideiglenes állapot-seedelő kód (`MainActivity`) a commit előtt eltávolítva.

**Amit ez NEM fed le** (F4B-ből még hátravan Androidon): A5 (ENDING/SUMMARY Wear-fázisok — nincs hozzá canvas-frame sem), ambient/dimmed-variáns (D0.3), telefon-oldali „Measuring”-pill és ⌚-badge (B14/B15). iOS oldalon a teljes F4B (B1–B10 iOS-fele) érintetlen.

### Állapot (2026-07-16)

- **F1 — kész.** `WatchWorkoutService` + hívási pontok (`LogSessionScreen`, `WorkoutResumePrompt`) + `WorkoutSessionRepository.enrichHealthMetrics` + unit tesztek a repóban.
- **F0(a) + F2 natív váz — Mac gépen készül.** `LifeyWatch` watchOS-target felvéve (`mobile/ios/Runner.xcodeproj`), minimális SwiftUI váz (`handle(_:)` proof of concept) + `mobile/ios/Runner/WatchBridge.swift` (a `lifey/watch` csatorna teljes `isWatchAppAvailable`/`startWorkout`/`updateState`/`endWorkout` implementációja, `startWatchApp`/`WCSession` alapon). Build-ellenőrzés folyamatban.
- **F0(b,c) + F3 natív váz — Android fele elkezdve ezen a Macen, a folytatás Windowson lesz.** `mobile/android/wear/` Gradle-modul (üres Compose-mentes MainActivity + `PhoneListenerService` mint `WearableListenerService`) és `mobile/android/app/.../WatchBridge.kt` (a `lifey/watch` csatorna Kotlin oldala, `MessageClient`/`DataClient`/`CapabilityClient` alapon) megvan és lefordul (`./gradlew :wear:assembleDebug`, `:app:compileDebugKotlin` mindkettő zöld). **A tényleges Wear OS emulátoros/fizikai órás tesztelés és a hátralévő F3-munka (Compose UI, `ExerciseClient` integráció, HC-írás) Windows gépen folytatódik** — a Wear OS/Android Studio toolchain ott is teljes értékű, nincs Mac-kényszer ezen a felén (lásd 0. fejezet).

---

## 8. Kockázatok, korlátok, nyitott kérdések

### 8.1 Kockázatok

| Kockázat | Hatás | Kezelés |
|---|---|---|
| `startWatchApp` megbízhatatlansága (ismerten flaky lehet, ha a watch alszik/töltőn van) | Az edzés a watchon nem indul el | Retry (1×), majd `applicationContext`-ben a `desiredPhase: running` — ha a user felébreszti a watch appot, az contextből indít. A telefon-UI nem blokkol a watchra. |
| Wear: más app exercise-e fut | `startExercise` elutasítva | `startRejected` esemény → telefon-toast; a watch UI felajánlja az átvételt (v2). |
| Idő-eltérés telefon ↔ watch | HR/kcal ablak nem pontosan fedi a sessiont | Elfogadjuk; a summary a watch tényleges start/end idejét is hordozza, csak diagnosztikára. |
| Flutter + Xcode watch target CI-ben | Build-törés | F0 spike (c) pont; a watch target csak Release-Runner sémához kötve. |
| Azonos `applicationId` a wear-modulban | Play-feltöltési komplexitás | App Bundle-lel a wear-APK ugyanabban a release-ben megy; app még nincs kiadva (memória), így migrációs teher nincs. |
| Akku a watchon | Hosszú edzésnél merülés | Strength-profil GPS nélkül olcsó; ambient/always-on módban csak az idő frissül (rendszer-viselkedés), extra munka nem kell. |
| HealthKit dupla-számolás: a watch HKWorkout-ot ír, a Health-import (doc 16) pedig olvas | Ugyanaz az edzés kétszer jelenhet meg importforrásként | Az import-lista szűrje ki azokat a HKWorkout-okat, amelyek `sourceRevision`-je a saját watch appunk — vagy egyszerűbben: amelyek uuid-je már szerepel bármely session `healthWorkoutId`-jában (ez utóbbi már majdnem adott). |

### 8.2 Nyitott kérdések (implementáció előtt döntendő)

1. **End gomb a watchon**: V1-ben a watch End gombja (a) csak a szenzor-sessiont zárja, a telefon-session nyitva marad; vagy (b) a telefonnak is küld egy `endRequested`-et, és a telefon zárja a sessiont (RPE-dialógussal a telefonon)? **Javaslat: (b)** — de a telefon-oldali „edzés vége” flow (feedback sheet) miatt a telefonon kell megerősíteni. **✅ Eldőlt, mindkét platformon megvalósítva (b) szerint (7.5.6 Androidon, 11.1 iOS-en).**
2. **Élő pulzus a telefon UI-án** edzés közben: kell-e V1-be? (iOS-en WCSession message-ekkel vagy iOS 17 mirroringgal menne.) **Javaslat: nem**, V1 az összegzésre fókuszál. **✅ Változatlanul nem V1-cél.**
3. Watch app **külön lokalizációs pipeline**-ja: kézzel tartjuk szinkronban az arb-kulcsokkal, vagy generálunk? V1: kézzel (≈15 string). **✅ Megvalósítva mindkét platformon: kézzel — Androidon `values/strings.xml` + `values-en/strings.xml` pár (7.5.6), iOS-en `Localizable.xcstrings` ugyanazokkal a kulcsokkal (11.3).**
4. `traditionalStrengthTraining` vs `functionalStrengthTraining` (iOS) ill. `STRENGTH_TRAINING` vs `WEIGHTLIFTING` (Wear): melyik aktivitástípus? **Javaslat: traditional / STRENGTH_TRAINING** — a kalóriamodell súlyzós edzésre kalibrált, és a Fitness-gyűrűkben is így jelenik meg. **✅ Mindkét platformon megvalósítva: `STRENGTH_TRAINING` Androidon, `traditionalStrengthTraining` iOS-en (`WatchBridge.swift`'s `startWorkout`).**

---

## 9. Tesztelési terv

- **Dart unit**: `WatchWorkoutService` fake channel-lel (meglévő minta), summary-feldolgozó (null-guard `healthWorkoutId`-ra, hiányzó session, absent-megőrzés) — a `workout_session_repository` meglévő tesztjei mellé.
- **iOS manuális mátrix** (watchOS-szimulátor párban az iOS-szimulátorral; a szimulátor szintetikus HR-t ad):
  - indítás telefonról → watch app felugrik, session fut;
  - set-logolás → watch kijelző frissül; pihenő-visszaszámláló + haptika;
  - lezárás telefonról → watch zár, summary beér, session-mezők kitöltve;
  - lezárás **elérhetetlen** watch mellett (repülő mód) → watch később zár, summary később ér be;
  - telefon-app kilőve edzés végén → summary a következő indításkor dolgozódik fel;
  - HealthKit-engedély megtagadva a watchon → edzés a telefonon zavartalan, watch Idle-t mutat.
- **Wear manuális mátrix** (Wear OS emulátor + telefon-emulátor párosítva; szintetikus szenzorok `adb`-vel):
  - ugyanazok a forgatókönyvek + `BODY_SENSORS` megtagadva (kcal HR nélkül), más app exercise-e fut (`startRejected`), watch app nincs telepítve (capability-hiány → no-op + Play-ajánlat).
- **Regresszió**: watch nélkül (se párosítva, se telepítve) az edzés-flow bitre azonosan viselkedik a maival — a híd minden hívása no-op.

**Android — ténylegesen lefedve (2026-07-16, emulátorpár + `adb`, nem a fenti manuális mátrix szerint sorban, hanem hibakeresés közben szervesen)**: teljes start→élő HR/kcal-mérés→end→summary kör működik valós (bár emulált) Health Services szenzoradattal; `startExercise` engedély-hiány miatti elutasítás (`SecurityException`) felfedezve és javítva; `startRejected` útvonal kódszinten kész, de másik app aktív exercise-ével nem lett explicit tesztelve; capability-hiány (watch app nincs telepítve) eset nem lett explicit tesztelve. **Fizikai Wear OS eszközön még nem futott végig.**

---

## 10. Összefoglaló

- **Mindkét kérdésre igen a válasz**: telefonról indítható és zárható a watch-edzés (iOS-en dedikált `startWatchApp` API-val, Androidon Data Layer üzenettel + `WearableListenerService`-szel), és a watch strength-specifikus workout sessionben élőben méri a pulzust és a kalóriát.
- A terv a meglévő építőkövekre ül: a `WorkoutSessionState` (Live Activity / ongoing notification) lesz a watch-kijelző adatmodellje, az `activeCalories`/`averageHeartRate`/`healthWorkoutId` mezők és az absent-megőrző repository-update lesz az összegzés célja — **se séma-, se backend-változás nem kell**.
- A legnagyobb munka a két natív watch app (SwiftUI + Compose for Wear OS); a Flutter-oldal egy vékony, a meglévő mintát követő channel-híd.
- V1-ben a telefon a mester: a watch mér, kijelez és összegez; a watchról set-logolás és standalone indítás v2.
- **Android (Wear OS) oldalon ez a terv 2026-07-16-ra teljes egészében megvalósult és emulátoron végigtesztelve működik** — a tervtől eltérő pontok (DataItem-szinkron megbízhatatlansága, plusz futásidejű engedélyek, package visibility, `CapabilityClient` fallback) a 7.5 fejezetben vannak dokumentálva.
- **iOS-en (Apple Watch) F0–F4 szintén megvalósult 2026-07-16-ra** — build-ellenőrizve (a `LifeyWatch` watchOS target és a teljes `Runner` workspace is hibátlanul fordul), de watchOS-szimulátoros/fizikai eszközös manuális teszt még nem futott le. A tervezett (11.1–11.4) és a ténylegesen leszállított munka (a `WatchBridge.swift`-ben talált NSNull/property-list hibával együtt) a 11.5 fejezetben van dokumentálva.

---

## 11. iOS — hátralévő munka az Android-szinthez

Az Android F0–F4 megvalósítása közben szerzett tapasztalatok (7.5 fejezet) alapján pontosítva. Ez a lista volt a Mac-en folytatódó fejlesztés kiindulópontja — **2026-07-16-ra mind a négy pont megvalósult, lásd 11.5** a tényleges leszállítás és a tervtől való eltérések dokumentációjáért. A pontok alább változatlanul maradnak referenciának, ✅ jelöléssel.

### 11.1 F2 — iOS watch MVP (a fő hátralévő munka) — ✅ megvalósítva

A `mobile/ios/LifeyWatch/` korábban csak az F0-spike-ot tartalmazta. A hiányzó darabok mind elkészültek:

1. **`WorkoutManager.swift`** — a §4.3-ban vázolt valódi `HKWorkoutSession` + `HKLiveWorkoutBuilder` életciklus: `start(configuration:)` a kapott `HKWorkoutConfiguration`-ból, élő HR/kcal gyűjtés a `HKLiveWorkoutBuilderDelegate`-en át, `finishAndSendSummary()` ami elmenti a valódi `HKWorkout`-ot (ennek `uuid`-ja a `healthWorkoutId` — **iOS-en ezt közvetlenül a watch adja, nincs szükség a 7.5.7-ben leírt Android-oldali "phone ír HC-be, majd visszakeresi az uuid-ot" kerülőútra**). ✅
2. **`PhoneConnector.swift`** — `WCSessionDelegate` a watch oldalán: `applicationContext`/`sendMessage` fogadása, `transferUserInfo` küldése a végén. A telefon oldali fogadó (`mobile/ios/Runner/WatchBridge.swift`'s `didReceiveUserInfo`) változtatás nélkül fogadja. ✅
3. **Valódi UI** — `Views/ActiveWorkoutView.swift` (eltelt idő, élő HR, kcal, gyakorlat/szett-számláló, pihenő-visszaszámláló — az Android `ActiveWorkoutScreen.kt` volt a vizuális/adatmodell-referencia) + `Views/IdleView.swift`, a placeholder `ContentView.swift` helyett (ami most csak a fázis szerint választ a kettő között). ✅
4. **Xcode projekt bekötés** — a `LifeyWatch` watchOS App target már korábban fel volt véve a workspace-be (F0); az új fájlok (`WorkoutManager.swift`, `PhoneConnector.swift`, a `Views/` csoport, `Localizable.xcstrings`) kézzel lettek bekötve a `project.pbxproj`-ba (`PBXFileReference`/`PBXBuildFile`/`PBXGroup`/`PBXSourcesBuildPhase`/`PBXResourcesBuildPhase` bejegyzések) — ellenőrizve `plutil -lint`-tel és sikeres build-del. ✅
5. **Végpont (End gomb)** — a 8.2/1. nyitott kérdés (b) opciója (Androidon 7.5.6): a watch End gombja **nem** hív közvetlenül `session.end()`-et, hanem `endRequested` `sendMessage`-et küld a telefonnak (`WorkoutManager.requestEnd()` → `PhoneConnector.sendEndRequested`); a watch csak a ténylegesen visszaérkező `end` parancsra zárja a `HKWorkoutSession`-t (`finishAndSendSummary()`). A Dart oldal (`WatchEndRequested` esemény) változtatás nélkül fogadja — az iOS natív oldal (mindkét irányban: watch küldés + `Runner/WatchBridge.swift`'s fogadása) elkészült. ✅

### 11.2 Architektúra-tanulság Androidról, amit érdemes végiggondolni iOS-en is

A 7.5.2-ben leírt DataItem-megbízhatatlanság **Android/Play Services-specifikus** volt (két emulátor GmsCore-példánya közti capability/data-szinkron hiba) — nincs okunk feltételezni, hogy az Apple `WCSession.updateApplicationContext` ugyanígy megbízhatatlan lenne (a WatchConnectivity történetileg stabilabb). **Mindazonáltal érdemes ugyanazt a mintát követni**: a `sendMessage`/`updateApplicationContext` payloadja már most is hordozza a teljes state-et (nem csak egy azonosítót) — tehát a §4.5-ben vázolt terv itt már eleve helyes, nincs szükség utólagos módosításra, csak arra, hogy tesztelés közben (watchOS-szimulátorpárban, majd fizikai eszközön) figyeljünk rá, tényleg megérkezik-e az `applicationContext` a watch oldalra minden esetben.

**Ami tényleg felszínre került (nem a DataItem-szinkron, hanem property-list szerializáció)**: lásd 11.5 — a state-payloadban gyakori `null` (pl. `restEndsAtEpochMs` amíg nincs pihenő) `NSNull`-ként érkezett a Flutter-kódektől, ami `updateApplicationContext`/`sendMessage`-nél érvénytelen property-list érték, és a meglévő `try?` némán elnyelte a hibát.

### 11.3 F4 — iOS fele (Android után, a doc saját fázis-sorrendje szerint) — ✅ megvalósítva

1. **Pihenő-visszaszámláló + haptika**: `restEndsAtEpochMs` megjelenítése az `ActiveWorkoutView`-n (mm:ss visszaszámláló) + `WKInterfaceDevice.play(.notification)` pontosan a pihenő lejártakor — a haptika-ütemezés (`WorkoutManager.scheduleRestHaptic`) **függetlenül fut** attól, hogy melyik nézet van épp képernyőn, mert magában a mindig-élő `WorkoutManager.shared`-ben él (nem a View-ban) — ez az iOS-megfelelője az Android mindig-élő `ExerciseService`-ének (7.5.6). ✅
2. **Teljes HU/EN lokalizáció** — `LifeyWatch/Localizable.xcstrings`, az Android `values`/`values-en` kulcsaival 1:1 megegyezve (`idle_title`, `idle_subtitle`, `active_default_exercise`, `active_sets_format`, `active_rest_format`, `active_heart_rate_unit`, `active_calories_unit`, `active_end_button`), kézzel szinkronban tartva. A String Catalog `sourceLanguage`-e `en` (a Runner-projekt `developmentRegion`-jét követve, eltérően az Android `values/` HU-alapértelmezésétől) — a `project.pbxproj` `knownRegions`-ébe felkerült a `hu`. ✅
3. **Settings-kapcsoló** ("Edzés indítása az órán") — platformfüggetlen Dart kód, változtatás nélkül működik iOS-en is. ✅ (nem igényelt iOS-natív munkát)
4. **`startRejected` visszajelzés** — a Dart-oldal már kész volt; az iOS natív oldal mindkét fele elkészült: a watch (`WorkoutManager.start`'s catch ága) elutasítás esetén `PhoneConnector.sendStartRejected`-et hív, a telefon (`Runner/WatchBridge.swift`) továbbítja a Dart oldalnak. ✅

### 11.4 Amit NEM kell újra megcsinálni iOS-hez (már kész, platformfüggetlen)

- A teljes Dart-oldali híd (`WatchWorkoutService`, `WatchWorkoutSummary`, `WatchStartRejected`, `WatchEndRequested`) — F1-ben elkészült, mindkét platformra közös, változtatás nélkül működik, amint az iOS natív oldal helyesen küldi/fogadja ugyanazokat az esemény-típusokat.
- A manuális Health-import eltávolítása (7.5.8) — már megtörtént, mindkét platformra egyszerre (megosztott Dart kód).
- A HC-write-és-uuid-visszakeresés mintája **nem kell iOS-re** — ott a watch már közvetlenül valódi `HKWorkout` uuid-ot ad (11.1/1. pont).

### 11.5 iOS — tényleges megvalósítás, eltérések a tervtől

Ez az alfejezet a **ténylegesen leszállított** F2+F4 iOS-implementációt írja le, a 7.5 Android-alfejezet mintájára.

**Új fájlok:**
- `mobile/ios/LifeyWatch/WorkoutManager.swift` — `HKWorkoutSession`/`HKLiveWorkoutBuilder` életciklus, élő HR/kcal, pihenő-haptika ütemezés, `applyStateUpdate` (Android `SessionStateHolder.onStateSynced` mintájára: `restEndsAtEpochMs` mindig felülíródik, a többi mező csak ha jelen van).
- `mobile/ios/LifeyWatch/PhoneConnector.swift` — `WCSessionDelegate`, a `SessionStateHolder`+`PhoneListenerService`+`SummarySender` Android-hármas iOS-megfelelője egyetlen fájlban.
- `mobile/ios/LifeyWatch/Views/ActiveWorkoutView.swift`, `Views/IdleView.swift` — a tervezett 2 képernyő.
- `mobile/ios/LifeyWatch/Localizable.xcstrings` — HU/EN String Catalog.

**Módosított fájl:**
- `mobile/ios/Runner/WatchBridge.swift` — két valódi hiba javítva build/implementáció közben (a 7.5-höz hasonlóan, ahol az Android-oldalon is a tényleges implementáció közben derültek ki a tervtől eltérő korlátok):
  1. **`NSNull`/property-list hiba** (lásd 11.2 vége): a Flutter standard method codec a Dart `null`-t `NSNull`-ként kódolja a state-mapben (nem hagyja ki a kulcsot), és sem `WCSession.updateApplicationContext`, sem `sendMessage` nem fogad el `NSNull`-t — érvénytelen property-list érték. A meglévő `try?` ezt némán elnyelte, azaz a state-szinkron **minden alkalommal megbukott volna**, amikor nincs aktív pihenő (a leggyakoribb eset). Javítás: új `sanitizedForPropertyList(_:)` helper, ami rekurzívan kiszűri az `NSNull`-t mielőtt a payload elmegy.
  2. **`endRequested` továbbítás hiánya**: a `didReceiveMessage` eddig csak a `startRejected` típust kezelte — az `endRequested` (amit a watch End gombja küld) nem jutott el a Dart oldalra. Bővítve, ugyanazzal a mintával.
- `mobile/ios/Runner.xcodeproj/project.pbxproj` — kézzel bekötve az új fájlok (`PBXFileReference`/`PBXBuildFile`/`PBXGroup`/`PBXSourcesBuildPhase`/`PBXResourcesBuildPhase`), a `knownRegions`-be felvéve a `hu`.

**HealthKit-típusok**: `HKObjectType.quantityType(forIdentifier:)` a hagyományos formában (nem a `HKQuantityType(.heartRate)` kényelmi inicializáló), mert az utóbbi újabb OS-verziót igényelne, mint a target `WATCHOS_DEPLOYMENT_TARGET`-je (10.0).

**Végállapot-eldöntés**: a `WorkoutManager.finishAndSendSummary()` a `session.end()` + `builder.endCollection`/`finishWorkout` előtt olvassa ki a `builder.statistics(for:)`-ból az átlagpulzust és összkalóriát — nem kell a Dart/Android-oldali "utólagos lekérdezés" mintát követni, mert a builder statisztikái a `finishWorkout()` után is elérhetők maradnak, de a kiolvasás sorrendje (előbb statisztika, utána `finishWorkout`) biztonságosabb.

**Build-ellenőrzés (2026-07-16, ezen a Macen)**: mindkét build zöld — `xcodebuild -target LifeyWatch -sdk watchsimulator` és a teljes `xcodebuild -workspace Runner.xcworkspace -scheme Runner` (CocoaPods + SPM + beágyazott `LifeyWatch`/`LifeyWidgets` targetekkel) is `BUILD SUCCEEDED`-del zárult, új fájlokra vonatkozó figyelmeztetés nélkül. **Watch-szimulátoros vagy fizikai órás manuális futtatás (a §9 teszt-mátrix szerint) még nem történt** — ez van hátra, mielőtt F2/F4 az Androidhoz hasonlóan "emulátoron/szimulátoron végigtesztelve" státuszba kerülhetne.

---

## 12. F4B — a designban szereplő, de le nem fejlesztett funkciók (design-adósság)

Felmérés: **2026-07-17**, a design-anyagok ([41-watch-design-prompt.md](41-watch-design-prompt.md) + a leszállított canvas, `docs/watch/design/Lifey Watch Design.dc.html`) és a tényleges kód (`mobile/ios/LifeyWatch/`, `mobile/android/wear/`, telefon-oldali Dart) összevetése alapján.

**Kontextus**: a canvas az F4-scope-ot **7 Apple Watch-frame + 6 Wear OS-frame + dynamic-sizing sor + 3 telefon-oldali elem** formában fedi le. A felmérés idején (2026-07-17) a jelenlegi implementáció funkcionálisan F4-en állt, de a watch-UI mindkét platformon stock-widget volt (2 fázis: `IDLE`/`ACTIVE`, egy-egy egyszerű képernyő — `ContentView.swift` ill. `SessionStateHolder.SessionPhase`), és a designnak több eleme **nem csak styling, hanem hiányzó funkció** volt. Ezek együtt az **F4B** fázis. Sorrend: előbb az F4B-funkciók lefejlesztése, utána a design-styling ráhúzása — a lebontást a [42-watch-design-implementation-plan.md](42-watch-design-implementation-plan.md) tartalmazza.

**Frissítés (2026-07-17, még aznap)**: Wear OS oldalon a legtöbb lista alábbi tétele (B1–B6, B11–B13) azóta elkészült — lásd 7.5.9. A táblázatok alább **változatlanul a felmérés eredeti állapotát** mutatják referenciaként (mit írt le a canvas mint hiányt), az egyes sorok végén ✅-jelöléssel és 7.5.9-hivatkozással jelezve, mi készült el azóta. iOS oldalon (12.2) és a telefon-oldalon (12.4) semmi nem változott — azok a listák továbbra is pontosan leírják a hátralévő munkát.

A frame-hivatkozások a canvas számozását követik (Apple Watch 01–07, Wear OS 01–06, telefon A–C).

### 12.1 Mindkét watch-platformon hiányzik

| # | Hiányzó funkció | Design-forrás | Mai állapot a kódban |
|---|---|---|---|
| B1 | **Pihenő mint hero-állapot**: a visszaszámláló átveszi a képernyőt — drain-elő progress-ring, „of 1:30” cél-idő, „Next · Bench Press — Set 3 of 4” sor, utolsó 5 mp színváltás `negative #E08A52`-re | AW 03, Wear 04; prompt §3.3 | A rest csak egy plusz caption-sor a metrikák közt (`ActiveWorkoutView.restText`, `ActiveWorkoutScreen` `active_rest_format` Text). **✅ Android (Wear OS): kész — `RestHero`, lásd 7.5.9.** iOS: változatlanul hátravan. |
| B2 | **Rest-end „GO” vizuális pillanat**: a 0-ra érésnél a haptika mellé 1–2 mp-es vizuális flash/átmenet | prompt §3.4 (a canvas csak „snaps back to metrics”-et említ — lásd 12.5) | Csak haptika van (`WorkoutManager.scheduleRestHaptic` / `ExerciseService` vibrátor), vizuális állapot nincs. **✅ Android (Wear OS): kész — `GoFlash`, lásd 7.5.9.** iOS: változatlanul hátravan. |
| B3 | **Pause/Resume** (csak a szenzor-sessiont pauzálja, a telefon-session időzítését nem) | AW 04, Wear 03 | Egyik platformon sincs pause; a §4.4 „V1-ben akár el is hagyható” opcióval éltünk. **✅ Android (Wear OS): kész.** iOS: változatlanul hátravan. |
| B4 | **Dynamic sizing**: százalék-alapú paddingek és metrika-típusskála (SwiftUI `ViewThatFits`/scaled metrics, Compose `BoxWithConstraints`-frakciók), 41 mm / 1.2″ ellenőrzéssel | canvas „Dynamic sizing” sor | Fix dp/pt paddingek és fix font-stílusok mindkét képernyőn. **✅ Android (Wear OS): kész** (`BoxWithConstraints` + `isCompactScreen`, lásd `DynamicSizing.kt`) — fizikai 1.2″ eszközön még nem ellenőrizve. iOS: változatlanul hátravan. |
| B5 | **Idle brand-moment**: levél/eco jel + „Lifey” wordmark az üres képernyőn | AW 01, Wear 01; prompt §3.1 | Két sor natúr szöveg (`IdleView`, `IdleScreen`), semmilyen brand-elem. **✅ Android (Wear OS): kész** (kézzel rajzolt levél-jel `surface`-badge-ben). iOS: változatlanul hátravan. |
| B6 | **Teljes brand-styling** (átfogó): warm-black rétegzett felületek, moss-olive primary, metric-accent színek (♥ `#C46A6A`+ikon, kcal `#E0915A`+láng), „STRENGTH” fejléc-chip, szett-számláló pill, tabular numerálok, radius-skála | minden frame; prompt §1–2 | Stock platform-téma, ikonok és szín-tokenek nélkül — a design-prompt kiinduló diagnózisa („unstyled stock-widget UI”) változatlanul áll. **✅ Android (Wear OS): kész, lásd 7.5.9** (`LifeyColors.kt`/`LifeyShapes.kt`/`LifeyTheme.kt`, `material-icons-extended`) — a ♥ szín a canvas `#D97F7F`-jét követi, nem a prompt `#C46A6A`-ját, lásd 7.5.9-ben a megjegyzést. Szett-számláló **pill/dot** helyett Androidon szöveg maradt (a canvas Wear-sora sem dot-ot, hanem szöveget mutat — nincs eltérés). iOS: változatlanul hátravan. |

### 12.2 iOS-specifikus hiányok

| # | Hiányzó funkció | Design-forrás | Mai állapot a kódban |
|---|---|---|---|
| B7 | **Lapozós szerkezet (TabView), külön controls-lap** End+Pause gombbal, Apple Workout-minta | AW 02+04; terv §4.4 (eredetileg is 2 lap volt tervben) | `ContentView` egyetlen `ActiveWorkoutView`-t mutat, az End gomb a metrikák alatt inline |
| B8 | **„End requested — waiting for phone” képernyő** („Finish on your iPhone / Rate your effort…”) az End megnyomása után, amíg a telefon `end` parancsa vissza nem ér | AW 05 | A `requestEnd()` után a nézet változatlan marad; nincs köztes fázis |
| B9 | **„Workout saved” összegző képernyő**: teljes idő, átlag bpm, kcal, „Saved to Health” jelzés, ~6 mp után auto-dismiss → Idle | AW 06 | `finishAndSendSummary()` után azonnal Idle-be vált, az összegzést a user az órán sosem látja |
| B10 | **HealthKit-engedély-hiba képernyő** („Allow Health access” + „Review access” gomb) | AW 07 | Engedély-hiba esetén a watch egyszerűen Idle-t mutat (§9 teszt-mátrix szerinti viselkedés, de dedikált képernyő nélkül) |

### 12.3 Wear OS-specifikus hiányok

| # | Hiányzó funkció | Design-forrás | Mai állapot a kódban |
|---|---|---|---|
| B11 | **`ScalingLazyColumn`-szerkezet**: metrikák felül, lejjebb görgetve a controls-szekció (End workout + Pause), jobb oldali scroll-jelzővel | Wear 02+03 | Fix, nem görgethető `Column`, End gomb inline. **✅ Kész, de a tervezettől eltérő megoldással, lásd 7.5.9**: nem `ScalingLazyColumn`-görgetés, hanem egy 2-lapos `HorizontalPager` (metrika/pihenő-lap + külön controls-lap, saját 2-pontos oldaljelzővel) — kerek kijelzőn a görgetős változat az End/Pause gombot minden metrika-nézet alján belógatta, körvágva. |
| B12 | **„Workout already running” hibaképernyő az órán** (OK gombbal) | Wear 05; terv §5.3 („a watch UI hibát mutat”) | A `startRejected` a telefonra megy (snackbar ✅), de az óra UI-jának nincs hiba-fázisa — a `SessionPhase` csak `IDLE`/`ACTIVE`. **✅ Kész** — `ErrorScreen` (ikon-badge, alcím, OK-pill), lásd 7.5.9. |
| B13 | **Degradált HR-állapot**: „––” placeholder (muted) + „Heart rate off — allow sensors” chip, ami az engedély-sheetet nyitja | Wear 06; prompt §3.6 | HR-megtagadásnál a HR-sor egyszerűen nem jelenik meg (`liveMetrics.heartRateBpm?.let`), nincs „––” és nincs engedély-chip. **✅ Kész** — `HeartRateReading` degradált ága (`heart_broken` ikon, „--” szöveg) + engedély-chip, lásd 7.5.9. |

### 12.4 Telefon-oldali hiányok (Flutter)

| # | Hiányzó funkció | Design-forrás | Mai állapot a kódban |
|---|---|---|---|
| B14 | **„Measuring” pill** a log-képernyő fejlécében, a `workoutStartedOnWatch` eseményre | telefon B | A `startedOnWatch` esemény a Dart-hídon átjön, de UI-t nem hajt; a Health-store-poll alapú near-live HR-kijelző (`_pollHeartRate`) részben fedi a szándékot, de nem ez a designolt ⌚-pill |
| B15 | **⌚ „Watch” badge** a session-kártyán a régi „Health” badge helyett, amikor a metrikák watch-summaryból jöttek | telefon C; §6.3 („később külön ⌚ badge”) | `sessions_tab.dart` a `session.fromAppleHealth` alapján a régi „Health” badge-et mutatja. Megjegyzés: a manuális Health-import megszűnése (7.5.8) óta gazdagítás **kizárólag** watch-summaryból jöhet, így külön adatmezőre nincs szükség — csak a badge vizuális cseréje és a mező/getter átnevezése kell. **✅ Eldőlt (2026-07-17, a 42-es doc D0.4 döntése): nem lesz új mező.** |

A telefon A elem (Settings-kapcsoló) és a startRejected-snackbar **kész** (7.5.6, 11.3) — ezek nem F4B-tételek, csak a design-styling érintheti őket.

### 12.5 Ami a design-oldalon hiányzik (a canvas hiányai — a 42-es doc tervezi be)

- **F5/F6 koncepció-frame-ek**: a prompt §4–5 kérte, de a leszállított canvas **csak az F4-scope-ot** tartalmazza — az F5/F6 design még el sem készült.
- **Ambient/always-on dimmed variáns**: a prompt §6 kért egy frame-et, a canvasban nincs.
- **„GO”-pillanat frame** (prompt §3.4): a canvas a rest-végét csak szövegesen írja le („view snaps back to metrics”), dedikált frame nélkül.
- **Token-ellentmondás**: az eltelt idő színe a promptban `onSurface` (neutrális hero, §2.6), a canvasban „Elapsed in primary olive” — implementáció előtt el kell dönteni.
