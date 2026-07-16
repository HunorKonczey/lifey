# 40 – Watch alkalmazás terv (Apple Watch + Wear OS)

Státusz: **Android (Wear OS) — F0–F4 megvalósítva és emulátoron végigtesztelve (2026-07-16). iOS (Apple Watch) — F0–F4 megvalósítva (2026-07-16), build-ellenőrizve (LifeyWatch target + teljes Runner workspace zöld); watchOS-szimulátoros/fizikai eszközös manuális teszt még hátravan, lásd 11.5.**
Nyelv: a mobil oldali híd Dart, a watch appok **natívak** (SwiftUI ill. Kotlin/Compose — lásd 2. fejezet, ez nem választás kérdése, hanem platformkényszer)
Kapcsolódó dokumentumok:
- [16-apple-health-integration-plan.md](16-apple-health-integration-plan.md) — a HealthKit-korlátok; a doc saját maga jelzi, hogy a benne leírt **manuális** "Import from Health" workout-párosítás 2026-07-16-tal megszűnt (lásd lent, 7. és 11. fejezet) — a session-gazdagítás (kalória/pulzus) mostantól kizárólag ebből a watch-integrációból jön
- [26-android-health-connect-integration-plan.md](26-android-health-connect-integration-plan.md) — Health Connect párja, ugyanaz a superseded-jegyzet
- [24-ios-widget-live-activity-plan.md](24-ios-widget-live-activity-plan.md) — a `lifey/live_activity` MethodChannel-minta, amit a watch-híd is követ
- [39-rest-timer-plan.md](39-rest-timer-plan.md) — a `restEndsAtEpochMs` állapot, amit a watch is megjelenít

## Implementációs állapot (2026-07-16)

| Fázis | Android (Wear OS) | iOS (Apple Watch) |
|---|---|---|
| F0 — Spike-ok | ✅ Kész | ✅ Kész |
| F1 — Dart híd | ✅ Kész (mindkét platformra közös) | ✅ Kész (mindkét platformra közös) |
| F2 — Watch MVP (natív start/end/élő mérés) | ✅ Kész | ✅ Kész — lásd 11. fejezet |
| F3 — Wear OS MVP | ✅ Kész | n/a (iOS-nek nincs külön F3-a, az F2 a natív MVP) |
| F4 — Pihenő-visszaszámláló+haptika, Settings-kapcsoló, lokalizáció, hibaút | ✅ Kész (Android fele) | ✅ Kész (iOS fele) — lásd 11. fejezet |
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
