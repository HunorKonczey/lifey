# 40 – Watch alkalmazás terv (Apple Watch + Wear OS)

Státusz: javaslat / előzetes terv
Nyelv: a mobil oldali híd Dart, a watch appok **natívak** (SwiftUI ill. Kotlin/Compose — lásd 2. fejezet, ez nem választás kérdése, hanem platformkényszer)
Kapcsolódó dokumentumok:
- [16-apple-health-integration-plan.md](16-apple-health-integration-plan.md) — a HealthKit-korlátok és a session-gazdagítás (kalória/pulzus) alapjai
- [26-android-health-connect-integration-plan.md](26-android-health-connect-integration-plan.md) — Health Connect párja
- [24-ios-widget-live-activity-plan.md](24-ios-widget-live-activity-plan.md) — a `lifey/live_activity` MethodChannel-minta, amit a watch-híd is követ
- [39-rest-timer-plan.md](39-rest-timer-plan.md) — a `restEndsAtEpochMs` állapot, amit a watch is megjelenít

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
- Ha a sessionben **már van** `healthWorkoutId` (a user közben kézzel Health-importált), a watch-summary **nem írja felül** — a kézi import a frissebb user-szándék. (Egy egyszerű „csak ha null” guard a feldolgozóban.)
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
| **F5 — (v2) Set-logolás a watchról** | „+1 szett” gomb a watchon → esemény a telefonra → a telefon logolja (a telefon marad a mester); offline eset: csak ha a telefon elérhető | M–L |
| **F6 — (v2) Standalone indítás a watchról** | Edzés indítása óráról telefon nélkül; a watch lokálisan gyűjt, és kapcsolódáskor a telefon sessiont kreál belőle — külön tervezést igényel (ütközés a resume-prompt logikával) | L |

Az F2 és F3 egymástól független, párhuzamosan is mehet. A javasolt sorrend: F0 → F1 → F2 → F4(iOS fele) → F3 → F4(Android fele), mert a fejlesztői környezetben (memória: mindkét build fut itt) az iOS-oldal a kockázatosabb (Xcode-target + entitlement), azt érdemes előbb kivenni.

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

1. **End gomb a watchon**: V1-ben a watch End gombja (a) csak a szenzor-sessiont zárja, a telefon-session nyitva marad; vagy (b) a telefonnak is küld egy `endRequested`-et, és a telefon zárja a sessiont (RPE-dialógussal a telefonon)? **Javaslat: (b)** — de a telefon-oldali „edzés vége” flow (feedback sheet) miatt a telefonon kell megerősíteni.
2. **Élő pulzus a telefon UI-án** edzés közben: kell-e V1-be? (iOS-en WCSession message-ekkel vagy iOS 17 mirroringgal menne.) **Javaslat: nem**, V1 az összegzésre fókuszál.
3. Watch app **külön lokalizációs pipeline**-ja: kézzel tartjuk szinkronban az arb-kulcsokkal, vagy generálunk? V1: kézzel (≈15 string).
4. `traditionalStrengthTraining` vs `functionalStrengthTraining` (iOS) ill. `STRENGTH_TRAINING` vs `WEIGHTLIFTING` (Wear): melyik aktivitástípus? **Javaslat: traditional / STRENGTH_TRAINING** — a kalóriamodell súlyzós edzésre kalibrált, és a Fitness-gyűrűkben is így jelenik meg.

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

---

## 10. Összefoglaló

- **Mindkét kérdésre igen a válasz**: telefonról indítható és zárható a watch-edzés (iOS-en dedikált `startWatchApp` API-val, Androidon Data Layer üzenettel + `WearableListenerService`-szel), és a watch strength-specifikus workout sessionben élőben méri a pulzust és a kalóriát.
- A terv a meglévő építőkövekre ül: a `WorkoutSessionState` (Live Activity / ongoing notification) lesz a watch-kijelző adatmodellje, az `activeCalories`/`averageHeartRate`/`healthWorkoutId` mezők és az absent-megőrző repository-update lesz az összegzés célja — **se séma-, se backend-változás nem kell**.
- A legnagyobb munka a két natív watch app (SwiftUI + Compose for Wear OS); a Flutter-oldal egy vékony, a meglévő mintát követő channel-híd.
- V1-ben a telefon a mester: a watch mér, kijelez és összegez; a watchról set-logolás és standalone indítás v2.
