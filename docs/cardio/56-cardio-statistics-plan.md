# 56 – Cardio: statisztika, rekordok, riportok — „mi romolhat el”

Státusz: **TERV.** Iteráció: **C3** (a C6/C8 sport-specifikus metrikákat tesz hozzá).
Előzmény: [51-cardio-overview-plan.md](51-cardio-overview-plan.md) (D-C.9, R2),
[52-cardio-domain-backend-plan.md](52-cardio-domain-backend-plan.md) (séma).
Háttér: [../17-statistics-page-plan.md](../17-statistics-page-plan.md),
[../38-personal-records-plan.md](../38-personal-records-plan.md),
[../37-streaks-weekly-recap-plan.md](../37-streaks-weekly-recap-plan.md),
[../33-weekly-trainer-report-plan.md](../33-weekly-trainer-report-plan.md).

> Ez a doc a felhasználó kifejezett aggályára válaszol: *„ügyelni kell a statisztikára, mert az
> elromolhat, hogy többféle edzés jön be.”* Az alábbi §1 az **ütközési leltár** — minden hely,
> ahol ma az „edzés” szó egyet jelent az „erősítő edzéssel”.

---

## 1. Ütközési leltár — hol jelent ma az „edzés” szó erősítő edzést

| # | Hely | Mai jelentés | Mi történik cardióval, ha nem nyúlunk hozzá |
|---|---|---|---|
| S1 | `statistics/StatisticsServiceImpl#forPeriodSinceForUser` → `workoutCount` | minden nem törölt, elindított session | A szám **megugrik** (séta is beleszámít) — dashboard, web-dashboard, edzői nézet mind ezt mutatja |
| S2 | `StatMetric.workoutCount` (mobil) | „minden nem-upcoming, ezen a héten indított session” | ua. |
| S3 | `StatMetric.workoutMinutes` | befejezett session-ök **bruttó** hossza | Egy 3 órás túra 40 perc ebéddel **180 percnek** számít — hamis (ezért van `movingSeconds`) |
| S4 | `StatMetric.activeCalories` | óráról jött kalória | Ez cardióval **javul**, nem romlik — de a `device_calories` (gép kijelzője) **nem** kerülhet bele automatikusan ([51 Q4](51-cardio-overview-plan.md)) |
| S5 | „Összes emelt súly” / volumen | szettek szorzata | Cardio session-nél 0 — helyes, de a **grafikon** nem mutathat 0-ás pontokat ott, ahol nincs is erősítő edzés (lásd D-C3.3) |
| S6 | `weekly_recap.dart`: `workoutsDone`, `workoutMinutes`, `workoutDays` | a fenti szabályok szerint | A heti visszatekintő számai megugranak, a „minutes” a bruttó időt hozza |
| S7 | Edzés-streak (`features/streaks/`) | „volt-e edzés aznap” | Egy 8 perces séta streaket tartana életben — ezért a küszöb ([51 Q1](51-cardio-overview-plan.md#8--döntések-eldöntve-2026-08-09): ≥ 15 perc mozgásidő **vagy** erősítő session) |
| S8 | `TrainerWeeklyReportJob` / `WeeklyReportServiceImpl` | edzésszám a kliensről az edzőnek | Az edző azt látja, hogy a kliens „6-szor edzett”, közben 4 séta volt |
| S9 | Személyes rekordok (`personal_record.dart`) | szett-alapú PR-ok | Cardio session **nem termelhet** erősítő PR-t; és hiányoznak a cardio-PR-ok |
| S10 | Web-statisztika (`web/src/features/statistics/aggregate.ts`) + edzői fülek | ua. mint S1–S3 | Külön kódbázis, ugyanaz a probléma — a teljes web-leltár: [58-cardio-web-plan.md §2](58-cardio-web-plan.md) |
| S11 | `recommended_template_provider` (következő terv javaslata) | session-ök terv-ciklusa | Cardio session-ök **zajt visznek** a ciklus-detektálásba |

---

## 2. Alapdöntések

### D-C3.1 — A `workoutCount` jelentése **nem változik**: „összes edzés”

Nem nevezzük át, nem szűkítjük erősítőre. Indok: négy felület (mobil dashboard, web dashboard,
edzői nézet, heti riport) és két kódbázis olvassa; a jelentés csendes megváltoztatása pontosan az a
fajta törés, amit el akarunk kerülni. Egy séta **valóban** edzés — a felhasználó is annak
tekinti. Ami hiányzik, az nem szűkítés, hanem **bontás**.

### D-C3.2 — A bontás additív: `strengthCount` / `cardioCount` a meglévő mező mellé

```java
public record StatisticsResponse(
        double totalCalories, double totalProtein, double totalCarbs, double totalFat,
        int workoutCount,              // változatlan jelentés: az összes
        Double latestWeight, double totalWater,
        // új, additív mezők:
        int strengthWorkoutCount,
        int cardioWorkoutCount,
        int movingMinutes,             // Σ moving_seconds / 60, cardio session-ökre
        double totalDistanceMeters,
        double totalElevationGainMeters
) {}
```

Régi kliens: az extra JSON-mezőket figyelmen kívül hagyja. Új kliens: `workoutCount` továbbra is
a főszám, a bontás alatta jelenik meg.

### D-C3.3 — A `workoutMinutes` mostantól **mozgásidőt** számol, ahol van

Ez az egyetlen hely, ahol **jelentés-változtatást** javaslok, mert a jelenlegi szabály cardióra
nyilvánvalóan hamis (S3). A szabály:

> `effectiveMinutes(session) = movingSeconds != null ? movingSeconds/60 : (finishedAt - startedAt)`

Erősítő session-nél `movingSeconds` null → a mai viselkedés **bitre azonos**. Cardiónál a
szünetek nélküli valós idő számít. A `weekly_recap.dart` dokumentált szabálya és a
`StatMetric.workoutMinutes` doc-kommentje ennek megfelelően frissül — a repo szokása szerint a
szabály a kód mellett, kommentben él, nem csak itt.

### D-C3.4 — Fajta-szűrő a statisztika-képernyőn, nem külön metrikák duplázása

Nem hozunk létre `strengthWorkoutCount`/`cardioWorkoutCount` **`StatMetric`-eket** — az a
metrika-listát felduzzasztaná és a felhasználót választásra kényszerítené ott, ahol egy szűrő
elég. Helyette a képernyő tetején egy `SegmentedButton`: **Mind / Erősítő / Cardio**, ami az
összes „edzés” jellegű metrikára hat. A meglévő tartomány-választó mellé kerül.

### D-C3.5 — Az üres nap nem 0, hanem hiányzó adat

Ez már ma is elv a `weekly_recap`-ben (a kalória-átlag nem osztódik 7-tel). A cardio-metrikákra
ugyanez kell: egy hét, amiben nem futott, nem „0 km/nap átlag”, hanem „nincs adat” — különben a
tempó- és távdiagram tele lesz hamis nullákkal. A `TimeSeriesChart` ezt már tudja kezelni
(hiányzó pont ≠ 0 pont); a cardio-adatsorok építőjének **explicit hiányt** kell adnia.

---

## 3. Új metrikák (`StatMetric` bővítés)

| Új `StatMetric` | Egység | Aggregáció | Család |
|---|---|---|---|
| `cardioDistance` | km / mérföld | `sum` | `DISTANCE`, `MACHINE` |
| `cardioMovingMinutes` | perc | `sum` | mind |
| `cardioElevationGain` | m / láb | `sum` | `DISTANCE` |
| `cardioAvgPace` | perc/km | **`average`, távval súlyozva** | `DISTANCE` (futás, séta) |
| `maxHeartRate` | bpm | `average` (napi maximumok átlaga) | mind |
| `cardioSessions` | – | `sum` | mind |

### D-C3.6 — Az átlagtempó **távval súlyozott**, nem a napi tempók számtani átlaga

Egy 1 km-es kocogás és egy 20 km-es futam tempójának számtani átlaga értelmetlen szám. A
súlyozott átlag (`Σ idő / Σ táv`) az egyetlen definíció, ami a felhasználó fejében lévő
„milyen gyors voltam” kérdésre válaszol. Ez egy **új aggregációs típus** a
`StatAggregationType`-ban (`weightedAverage`), ami eddig nem létezett — ezt a C3-ban vezetjük be,
a `stat_chart_data.dart` megfelelő ágával együtt.

---

## 4. Felületenkénti teendők

| Felület | Teendő | Iteráció |
|---|---|---|
| Mobil statisztika-képernyő | Fajta-szűrő (D-C3.4), új metrikák, `weightedAverage` ág, hiány-kezelés (D-C3.5) | C3 |
| Mobil dashboard | Az „edzések” szám alá egy halk bontás-sor („3 erősítő · 2 cardio”); a legutóbbi edzések listája ikonos | C3 |
| Heti visszatekintő (`weekly_recap`) | `workoutMinutes` → mozgásidő-szabály; új sor a heti távról, ha volt cardio; a `workoutDays` szabálya változatlan | C3 |
| Edzés-streak | **Eldöntve** ([51 Q1](51-cardio-overview-plan.md#8--döntések-eldöntve-2026-08-09)): streaket az ér, ami **≥ 15 perc mozgásidő** *vagy* erősítő session. A küszöb egyetlen konstans (nem beállítás), és a mozgásidő a mérce, nem a bruttó — különben az appot nyitva felejtve is jár a nap | C3 |
| Backend `StatisticsResponse` | D-C3.2 additív mezők + repository-lekérdezések | C3 |
| Edzői heti riport (`WeeklyReportServiceImpl`) | Az edzésszám mellé fajta-bontás és össztáv; a riport-sablon (`mail/`) egy sorral bővül | C3 |
| Edzői kliens-nézet (web) | Session-kártya ikonnal + fő metrikával; a statisztika-fül szűrője — [58 W2](58-cardio-web-plan.md) | C1w |
| Web statisztika (`aggregate.ts`) | Ugyanazok a szabályok, mint mobilon — **a definíciók egyezését teszt őrzi** ([58 WB10–WB12](58-cardio-web-plan.md)) | C3w |
| `recommended_template_provider` | Cardio session-ök kiszűrése a ciklus-detektálásból (S11) | C0 audit része |

### D-C3.7 — A szabályok egyetlen helyen, prózában is rögzítve

A mobil és a web külön implementálja ugyanazt az aggregációt (ma is). A definíciók
(`workoutCount`, `effectiveMinutes`, súlyozott tempó, streak-küszöb) **ebbe a docba**, a §2–§3-ba
kerülnek, és mindkét kódbázis kommentje ide hivatkozik. Ez ma is így működik a
`weekly_recap.dart` doc-kommentjeinél — csak most explicit szabállyá tesszük.

---

## 5. Személyes rekordok (S9)

### 5.1 Védelem: cardio nem termel erősítő PR-t

A PR-motor bemenetét `sessionKind == 'STRENGTH'`-re szűrjük. Ez a [53 §0](53-cardio-mobile-plan.md)
audit egyik kötelező tétele — enélkül egy üres session „0 kg-os PR"-t vagy kivételt okozhat.

### 5.2 Új cardio-rekordok (C3 alap, C6/C8 bővíti)

| Rekord | Aktivitás | Számítás |
|---|---|---|
| Leghosszabb táv | futás, séta, túra, bicikli | `max(distance_meters)` |
| Leghosszabb mozgásidő | mind | `max(moving_seconds)` |
| Legnagyobb szintemelkedés | túra, futás | `max(elevation_gain_meters)` |
| Leggyorsabb 1 km / 5 km / 10 km | futás | **C6** — a nyomvonal csúszóablakos legjobbja, nem a teljes távú átlagtempó |
| Legnagyobb összmunka (kJ) | szobabicikli | **C7** |

### D-C3.8 — A „leggyorsabb 5 km” csak nyomvonalból számolható, ezért C6

Egy 7 km-es futás átlagtempójából nem lehet 5 km-es rekordot mondani. A csúszóablakos számítás a
nyers pontokra épül, tehát a C4a után van értelme — addig a táv/idő rekordok is bőven adnak
visszajelzést.

### D-C3.9 — A GAP (emelkedés-normált tempó) képlete: Minetti-féle metabolikus költség (C8.2)

A GAP azt válaszolja meg: *mekkora tempó lenne ugyanez az erőkifejtés sík terepen?* — nem a
meredekség szerinti lineáris „büntetés", hanem a tényleges metabolikus költséget modellezi, mert
egy 15%-os lejtő nem fele annyiba kerül, mint egy 15%-os emelkedő (a nagyon meredek lejtő a
fékezés miatt megint drágul).

A képlet Minetti et al. (2002, *J Appl Physiol* 93.3: 1039–1046) mért futási
energiaköltség-görbéjének ötödfokú polinom-illesztése, ±45%-os meredekségig érvényesítve:

```
C(i) = 155.4·i⁵ − 30.4·i⁴ − 43.3·i³ + 46.3·i² + 19.5·i + 3.6      [J·kg⁻¹·m⁻¹]
```

ahol `i` a meredekség hányadosként (0,10 = 10%-os emelkedő), `C(i)` a vízszintes méterenkénti
metabolikus költség. `C(0) = 3,6 J·kg⁻¹·m⁻¹` a sík futás költsége — ez a képlet saját, mért
referenciapontja, nem külön becsült érték.

Szakaszonként (a szűrt nyomvonal két egymást követő pontja között): a `C(i)/C(0)` arány
**sík-egyenértékű távra** váltja át a szakasz vízszintes távját — `d_ekv = d_szakasz · C(i)/C(0)`.
A teljes GAP a session összes idejének és az összes sík-egyenértékű távnak a hányadosa:

```
GAP [s/km] = Σ(idő_szakasz) / Σ(d_ekv_szakasz) · 1000
```

Sík terepen minden szakasz meredeksége 0, tehát `C(i)/C(0) = 1` minden szakaszon — a
sík-egyenértékű táv megegyezik a tényleges távval, és a GAP **pontosan** a nyers átlagtempóval
egyezik (ez a C8.2 kész-ha-ja, tesztelve). Hiányzó magasságadatú szakasz meredeksége 0-nak
számít (nem hagyjuk ki a szakaszt a nevezőből) — ugyanaz az „egy hiányzó pont nem dobja el az
egészet" elv, mint `cardio_splits_calculator.dart`-ban.

**Az irány könnyen elcserélhető, ezért kimondva**: emelkedőn `C(i) > C(0)`, tehát a
sík-egyenértékű táv **nagyobb** a ténylegesnél ugyanannyi idő alatt — a GAP **gyorsabb** számot ad,
mint a nyers tempó (jóváírja az emelkedőt). Lejtőn nagyjából -20%-ig `C(i) < C(0)` (Minetti mért
minimuma ott van), a sík-egyenértékű táv **kisebb** — a GAP **lassabb**, mint a nyers tempó
(leszámítja az „ingyen" lejtős sebességet). -20% után a görbe visszakúszik a sík költség felé (és
azon túl is), így egy nagyon meredek lejtő GAP-ja megint közelít a nyers tempóhoz, sőt túl is
szárnyalhatja.

**A képlet egyetlen helyen él**: `features/workouts/domain/grade_adjusted_pace.dart`
(`computeGradeAdjustedPaceSecondsPerKm`), a backend és a web soha nem számol GAP-ot újra — a
kliens a session zárásakor egyszer kiszámolja és elküldi (`avg_gap_seconds_per_km`, V71,
[60 C8.1](60-cardio-sport-specifics-plan.md)), ugyanaz a „kiszámolva, nem újraszámolva"
minta, mint a legjobb-résztávaknál.

---

## 6. Feladatlista (C3)

| # | Lépés |
|---|---|
| ST1 | Backend: repository-lekérdezések (fajtánkénti szám, Σ mozgásidő, Σ táv, Σ szintemelkedés) |
| ST2 | Backend: `StatisticsResponse` additív bővítés + teszt (régi mezők értéke változatlan) |
| ST3 | Mobil: `StatMetric` bővítés + `weightedAverage` aggregációs típus |
| ST4 | Mobil: fajta-szűrő a statisztika-képernyőn; hiány-kezelés (D-C3.5) |
| ST5 | Mobil: `effectiveMinutes` szabály (D-C3.3) a statisztikában és a heti recapben, doc-kommentekkel |
| ST6 | Mobil: dashboard bontás-sor + ikonos legutóbbi edzések |
| ST7 | Streak-küszöb bevezetése (termékdöntés után), egy konstans, tesztelve |
| ST8 | PR-motor: erősítő-szűrő + cardio-rekordok (táv, idő, szintemelkedés) |
| ST9 | Edzői heti riport + e-mail sablon bővítés |
| ST10 | Web: `aggregate.ts` szabály-paritás + edzői fülek + session-kártya |
| ST11 | **Paritás-teszt**: azonos bemenetre a mobil és a web aggregáció ugyanazt adja (a §2–§3 definíciói szerint) |

---

## 7. Elfogadás

- [ ] Egy tisztán erősítő előzményű felhasználónál **minden** statisztikai szám bitre azonos a
      cardio bevezetése előttivel (regressziós teszt rögzített adathalmazon)
- [ ] Cardio hozzáadása után minden szám a §2–§3 definíciói szerint helyes, és a definíció a
      kódban kommentként ide hivatkozik
- [ ] A tempó-metrika súlyozott átlagot használ, és 0 távú napon nem oszt nullával
- [ ] Cardio session nem termel erősítő PR-t; erősítő session nem termel cardio-PR-t
- [ ] A mobil és a web ugyanarra az adathalmazra ugyanazt a heti összesítést adja
