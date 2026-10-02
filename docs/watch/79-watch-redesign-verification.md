# 79 – Watch redesign: watchOS szimulátoros végpróba

Státusz: **lezárva (2026-10-02).** Az Apple Watch app a mobil-redesign (`redesign/77`) témájával lefordul és fut a watchOS szimulátoron; a teljes edzésfolyamat (indítás → szett → pihenő → vezérlők → erőfeszítés → összegzés) végigment. Egy megjelenítési hibát találtunk és javítottunk (§4). A watch-komplikáció **nincs megépítve** — szándékosan nincs ebben a körben (§6).

Kapcsolódó dokumentumok:
- [redesign/77-mobile-redesign-plan.md](../redesign/77-mobile-redesign-plan.md) — §6: a Watch színillesztése itt maradt ki a mobil-redesignból; ez a doksi a Watch oldali lezárása.
- [42-watch-design-implementation-plan.md](42-watch-design-implementation-plan.md) — a Watch szín-tokenek (`LifeyColors.swift`) eredete.
- [48-watch-f5b-set-adjust-plan.md](48-watch-f5b-set-adjust-plan.md) — az Adjust lap (§3).
- [50-watch-f6c-session-plan-sync-plan.md](50-watch-f6c-session-plan-sync-plan.md) — a telefon-mesterelt folyamat eszközös végpróbája ott van hátra; ez a doksi nem váltja ki (§6).

---

## 1. Kiindulás

A feladat úgy szólt, hogy a Watch redesign Swift forrásai „nincsenek bekötve és lefordítva". Ellenőrzés után ez nem állt:

- a `LifeyWatch` target létezik a `mobile/ios/Runner.xcodeproj`-ban, és mind a 14 Swift forrása (`ContentView`, `WorkoutManager`, `PhoneConnector`, a `Views/` és a `Theme/` fájljai) a Sources fázisban van;
- a `LifeyColors.swift` már a redesign zsálya palettáját hordozza;
- a `LifeyWidgets` target viszont **csak iOS** (Today widget + Live Activity), watch widget extension nincs.

Tehát a hátralévő munka a **fordítás és a szimulátoros ellenőrzés** volt, nem a bekötés.

## 2. Hogyan kell futtatni

Xcode 26.5, watchOS 26.5 szimulátor, Apple Watch Series 11 (46 mm) — a párja az iPhone 17 Pro Max.

```bash
cd mobile/ios
xcodebuild -workspace Runner.xcworkspace -scheme LifeyWatch -configuration Debug \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  -derivedDataPath <build-dir> \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES DEVELOPMENT_TEAM="" build
xcrun simctl install <watch-udid> <build-dir>/Build/Products/Debug-watchsimulator/LifeyWatch.app
xcrun simctl launch  <watch-udid> com.khunor.lifey.watchkitapp
```

Három csapda, mindhárom pontosan reprodukálható:

1. **Workspace, nem projekt.** A `LifeyWatch` séma a `Runner`-től függ; a `-project Runner.xcodeproj` hívás a Flutter pluginmodulok nélkül elbukik (`Module 'connectivity_plus' not found`). A `Runner.xcworkspace` kell (előtte `flutter pub get` + `pod install` a `mobile/` alatt, ha a `Pods/` hiányos).
2. **Ad-hoc aláírás kell, `CODE_SIGNING_ALLOWED=NO` nem jó.** Aláíratlan buildnél a HealthKit entitlement nem kerül a binárisba, a `requestAuthorization` azonnal hibázik, és az app minden edzésindításnál a „Allow Health access" (`healthDenied`) képernyőre fut — úgy tűnik, mintha a folyamat hibás volna. `CODE_SIGN_IDENTITY="-"`-vel megjelenik a rendszer Health-engedélykérője.
3. **A Watch szimulátort a párosított iPhone-szimulátorral együtt kell bootolni.** A párok: 46 mm ↔ iPhone 17 Pro Max, 42 mm ↔ iPhone Air, Ultra 3 ↔ iPhone 17 (`xcrun simctl list pairs`). Párja nélkül a pár „disconnected".

A Health-engedély a szimulátoron a rendszerlapon adható meg (Review → Write Access → minden kapcsoló be → Next → Read Access → minden kapcsoló be → Done). A `simctl privacy grant health` itt `Operation not permitted`-et ad.

## 3. Végigkattintott képernyők

Minden kép a `screens/` mappában, 46 mm-es szimulátoron készült (416 × 496 px), az utolsó a 42 mm-esen.

| # | Képernyő | Fájl | Eredmény |
|---|---|---|---|
| 1 | Idle / launcher: levélmonogram, „Lifey", „Start workout" pill, „or start on your phone" | `01-idle.png` | ✅ zsálya `primary` pill, `trueBlack` háttér |
| 2 | Edzésválasztó („Start"): Quick strength kártya, „Plans sync from your phone" | `02-picker.png` | ✅ a javítás után (§4); sablon- és cardio-sor nincs, mert nincs szinkronizált telefon |
| 3 | Aktív edzés — metrikaoldal: STRENGTH fejléc, eltelt idő, pulzus, kcal, gyakorlat-kártya | `03-active-metrics.png` | ✅ élő pulzus (~58–60 bpm) a szimulátor szenzorából |
| 4 | Aktív edzés — log oldal: „+1 set" és „Adjust" korong | `04-active-log-set.png` | ✅ |
| 5 | Adjust lap: Reps / Weight váltó, −/+ léptető, „Log 10 reps" | `05-adjust-reps.png` | ✅ barna (`secondary`) „mellékút" jelölés a 48-doc szerint |
| 6 | Pihenő: REST fejléc, 01:30-as visszaszámláló sáv, „Next · …", pulzus, kcal | `06-rest.png` | ✅ a sáv a hátralévő idővel arányosan fogy |
| 7 | Vezérlők: End / Pause | `07-controls.png` | ✅ |
| 8 | Szüneteltetett állapot: End / Resume | `08-paused.png` | ✅ az eltelt idő megáll |
| 9 | Erőfeszítés-választó („How hard was it?"), 5 → 7 | `09-effort.png` | ✅ |
| 10 | Összegzés: „Workout saved", idő 02:32, 1 set, pulzus, kcal | `11-summary.png` | ✅ a szettszám egyezik a rögzítettel; néhány másodperc után magától az edzésválasztóra lép |
| 11 | 42 mm-es idle (compact elrendezés) | `13-idle-42mm.png` | ✅ |

A „Health access" (`healthDenied`) képernyő is megjelent a 2. csapda miatt (cím, magyarázat, „Review access" gomb, ami visszavisz az idle-re) — ez a viselkedés a `WorkoutManager.dismissError()` szerint helyes.

### Működés, ami elsőre hibának látszik, de szándékos

- **A „+1 set" az Adjust lapot nyitja**, ha az adott gyakorlathoz nincs mit előtölteni (`WorkoutManager.hasLogSetPrefill` hamis): egy üres szettet nem érdemes egy koppintással rögzíteni, ezért a léptető az alapértékekkel (10 ismétlés, 0 kg) nyílik. Az első szett után a koppintás már közvetlenül rögzít.
- **Az Adjust lap 3 másodperc tétlenség után bezárul** (`logAdjustIdleDismissSeconds`), szett rögzítése nélkül. Automatizált (lassú) koppintásnál ez azt eredményezi, hogy a szett „nem számolódik"; kézzel nem jön elő.

## 4. Talált és javított hiba

**A „Quick strength" cím betűnél tört** („strengt / h") a 46 mm-es edzésválasztón: a `quickStrengthCard` `.body` félkövér szövege szélesebb volt, mint a hely, és semmi nem engedett skálázást. Javítás: `Views/StandalonePickerView.swift` — a cím `.lineLimit(2)` + `.minimumScaleFactor(0.7)`-et kapott, így a „strength" szó egyben marad. Szimulátoron ellenőrizve (`02-picker.png`: „Quick / strength"). A fordítás a javítás után is hibátlan.

## 5. Ellenőrzött build

- `xcodebuild … -scheme LifeyWatch -configuration Debug`, watchOS Simulator, ad-hoc aláírással: **BUILD SUCCEEDED**, hiba és Watch-forrásra eső figyelmeztetés nélkül.
- A Runner és a Watch együtt épül, a `Runner` séma nem változott.

## 6. Nem lett ellenőrizve / nincs megépítve

| Tétel | Miért | Teendő |
|---|---|---|
| **Watch komplikáció / widget** | Nincs ilyen target és nincs terv sem. A `LifeyWidgets` az iPhone-é (Today widget, Live Activity). Egy WidgetKit extension a Watchhoz új feature: külön terv kell (milyen családok, milyen adat, hogyan jut el az órára). | Külön terv, ha kell |
| Telefon-mesterelt folyamat (a telefon indítja az edzést, `startWatchApp`) | Ehhez a Flutter `Runner` appot is telepíteni és bejelentkeztetni kellene a párosított iPhone-szimulátoron | az `50` doksi eszközös végpróbájával együtt |
| Sablon- és cardio-sorok az edzésválasztóban | Szinkronizált sablon nélkül üres | telefon-szinkronnal |
| 42 mm-es szimulátor kezelése | A vezérlő hozzáférését nem hagyták jóvá; csak az idle kép készült | kézzel vagy jóváhagyás után |
| Ultra 3 (49 mm), Wear OS | nem része ennek a körnek | — |
| Dynamic Type nagy szövegmérettel | nem próbáltuk | — |

## 7. Következmények a többi dokumentumra

- `REMAINING-WORK.md` §2.1 „Natív felületek": a **Watch** kikerül a sorból (kész, ez a doksi); az iOS widget / Live Activity és az Android widget színillesztése marad.
- `docs/README.md`: a `watch/` sor a 79-es dokumentummal bővült.
