# 54 – Cardio: GPS, nyomvonal és útvonal-megjelenítés

Státusz: **TERV.** Iteráció: **C4a** (nyomvonal-rögzítés + saját útvonalrajz), **C4b** (opcionális, valódi térképcsempe).
Előzmény: [51-cardio-overview-plan.md](51-cardio-overview-plan.md) (D-C.5, D-C.6),
[53-cardio-mobile-plan.md](53-cardio-mobile-plan.md) (élő képernyő), séma:
[52-cardio-domain-backend-plan.md](52-cardio-domain-backend-plan.md) (D-C1.2 — nyers pont nem megy szerverre).

Érintett aktivitások: **futás, séta, túrázás** alapból; **kültéri foci** opcionálisan (C9);
szobabicikli és teremkosár soha.

---

## 1. Miért külön iteráció

A GPS három olyan kockázatot hoz, ami egyikét sem éri meg a C2-vel keverni: **engedélykérés**
(ami elronthatja az indítás élményét), **háttérfutás** (amit az OS bármikor megszakíthat) és
**akkumulátor**. A C2 végén az app már tud élő cardiót rögzíteni GPS nélkül — ezért a C4a
tisztán ráépülő réteg, és ha csúszik, semmi nem áll miatta.

---

## 2. Függőség-döntés

### D-C4.1 — `geolocator`, nem `location`, és nem saját platform-csatorna

| Opció | Értékelés |
|---|---|
| Saját `MethodChannel` + natív `CLLocationManager` / `FusedLocationProvider` | Teljes kontroll, nulla függőség — de kb. 600 sor natív kód két platformon, engedélykezeléssel, háttér-módokkal és élettartam-kezeléssel együtt. Ez pont az a fajta újraírás, amit egy karbantartott csomag ingyen ad. |
| `location` csomag | Egyszerűbb API, de gyengébb az engedély-állapotok (különösen az „always” vs. „while in use”) és a háttér-konfiguráció kezelése. |
| **`geolocator`** | **Ez a döntés.** Kifejezetten nyomvonal-rögzítéshez való: `getPositionStream` `LocationSettings`-szel, platformspecifikus `AndroidSettings(foregroundNotificationConfig:)` és `AppleSettings(allowBackgroundLocationUpdates:, pauseLocationUpdatesAutomatically:)`, részletes engedély-állapot enum, `distanceFilter`, pontosság-szintek. Széles körben használt, karbantartott. |

Új dep-ként a CLAUDE.md indoklást vár: **ez az indoklás** — a funkció (kültéri edzés
nyomvonala) nélküle nem megvalósítható, a saját natív út pedig több kódot és több hibalehetőséget
jelentene ugyanazért. Térkép-SDK-t **nem** hozunk be (D-C.6).

Emellé kell: `permission_handler` **nem** — a `geolocator` saját engedély-API-ja elég;
felesleges plugin-átfedést nem viszünk be.

---

## 3. Engedélyek és a „soha ne blokkoljon” szabály (D-C.5)

### 3.1 Mikor kérünk

**Nem** az app első indításakor és **nem** az onboardingban. Akkor kérünk, amikor a felhasználó
először indít `DISTANCE` családú edzést — és **előtte** egy saját, egymondatos magyarázó lap
(„Az útvonal és a táv méréséhez helyadat kell; enélkül is elindíthatod az edzést, csak nyomvonal
nélkül”), a rendszer-párbeszéd elé. Ez az iOS-en gyakorlatilag kötelező jó gyakorlat, mert a
rendszer-dialógus **egyszer** kérdez.

### 3.2 Milyen szintet kérünk

`whileInUse` — ez **elég**, ha az edzés alatt előtér-szolgáltatás (Android) ill.
`allowsBackgroundLocationUpdates` (iOS) fut. Az „always” szintet **nem kérjük**: nincs rá
szükségünk, rontja az elfogadási arányt, és adatvédelmi kérdéseket nyit.

iOS-en emellett kérjük a **pontos helyet** (`Precise`); ha a user csak megközelítőt ad, a
nyomvonal használhatatlan → a UI figyelmeztet, és az edzés GPS nélküli módban fut.

### 3.3 Állapot-mátrix

| Engedély-állapot | Viselkedés |
|---|---|
| Megadva (precise) | Teljes nyomvonal-rögzítés |
| Megadva (approximate, iOS) | Nincs nyomvonal; táv kézzel; egyszeri, elvethető figyelmeztetés |
| Megtagadva | **Az edzés elindul**, GPS-ikon áthúzva a fejlécben, táv mező kézi bevitelre nyílik; egy „Engedélyezés” link a rendszer-beállításokba |
| Véglegesen megtagadva | Ugyanaz, de a link egyenesen az app-beállításokba visz |
| Helymeghatározás kikapcsolva (eszköz-szint) | Ugyanaz + „Kapcsold be a helymeghatározást” |
| Nincs jel (alagút, erdő) | Rögzítés folyik, a UI „gyenge jel” jelzést mutat; a hézagot a §4.3 kezeli |

Egyik ág sem akadályozza meg az edzés indítását vagy mentését. Ez a D-C.5 gyakorlati alakja.

---

## 4. Rögzítés

### 4.1 Mintavétel

```dart
LocationSettings(
  accuracy: LocationAccuracy.best,   // futás/túra: best; séta: high is elég
  distanceFilter: 5,                 // méter — állóhelyben nem generál pontot
)
```

Adaptív finomítás: `GAME` (kültéri) és séta esetén `distanceFilter: 10` és `high` pontosság —
kevesebb pont, kevesebb akku, a pontosság bőven elég.

**Minden beérkező pont azonnal a driftbe íródik** (nem memóriapufferbe): egy 3 órás túra
közepén lelőtt app így legfeljebb egy pontot veszít. Ez a `CardioTrackPoints` tábla:

```dart
class CardioTrackPoints extends Table {
  TextColumn get sessionClientId => text().references(WorkoutSessions, #clientId)();
  IntColumn  get seq => integer()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get altitude => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  RealColumn get speed => real().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
  @override Set<Column> get primaryKey => {sessionClientId, seq};
}
```

Ez a tábla **soha nem szinkronizálódik** (D-C1.2) — kliens-lokális, és a session törlésekor
kaszkádolva törlődik. Az outbox nem lát belőle semmit.

### 4.2 Szűrés és simítás

Egy nyers GPS-stream 10–15%-kal is túlbecsülheti a távot, ha nem szűrünk. Sorrendben:

1. **Pontosság-kapu**: `accuracy > 20 m` → pont eldobva (túránál 30 m, mert az erdő alatt
   különben mindent eldobnánk).
2. **Sebesség-kapu**: ha két pont közti implikált sebesség > az aktivitás plafonja
   (séta 8 km/h, futás 30 km/h, kerékpár 80 km/h) → ugrás, eldobva.
3. **Minimális elmozdulás**: < 3 m elmozdulás nem növeli a távot (GPS-remegés állóhelyben).
4. **Magasság-simítás**: mozgóátlag 5 pontra; a szintemelkedésbe csak a **> 1 m**
   monoton szakaszok számítanak — enélkül egy sík séta is „200 m emelkedést” mutatna.
5. **Táv**: haversine a szűrt szomszédos pontok között, futó összegzéssel (nem a végén egyben).

Ez tiszta, tesztelhető függvényként él (`lib/features/workouts/domain/track_filter.dart`),
rögzített minta-nyomvonalakkal a tesztekben.

### 4.3 Hézagok

Ha > 60 s telik el pont nélkül (alagút, jel-vesztés, OS-felfüggesztés), a hézagot **nem hidaljuk
át egyenessel a távban** (az hamis adat lenne), de a rajzon szaggatott vonallal jelezzük.
A hézag hossza a `SUMMARY`-ben látszik („2 perc jel nélkül”).

### 4.4 Háttérfutás

| Platform | Megoldás |
|---|---|
| Android | `AndroidSettings.foregroundNotificationConfig` → előtér-szolgáltatás **a már meglévő ongoing notificationnel egy vizuális egységben** (nem két értesítés!). `FOREGROUND_SERVICE_LOCATION` engedély, API 34+ szolgáltatástípus deklaráció a manifestben. |
| iOS | `AppleSettings(allowBackgroundLocationUpdates: true, pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true)` + `UIBackgroundModes: location` az `Info.plist`-ben. A Live Activity amúgy is fut, tehát a user látja, hogy mérünk. |

**Két értesítés elkerülése (Android):** a C2 ongoing notification és a C4a előtér-szolgáltatás
ugyanaz a notification legyen — a szolgáltatás a meglévő csatornát és id-t használja. Ez konkrét
implementációs csapda, külön feladatlista-tétel (§7 G6).

### 4.5 Akkumulátor

Cél és mérési kötelezettség: **≤ 8 % / óra** fogyás futásnál, képernyő kikapcsolva, közepes
eszközön. Ha ezt túllépjük, a `distanceFilter` és a pontosság lazul. A mérés a C4a
elfogadási feltétele ([51 §7](51-cardio-overview-plan.md)), a mért érték a doc §8-ba kerül.

---

## 5. Tárolás és szinkron

Záráskor (`ENDING` → `SUMMARY`):

1. A szűrt pontokból **ritkított polyline** készül (Douglas–Peucker, ~5 m tűrés) — jellemzően
   a pontok 10–20%-a marad, a rajz szemre azonos.
2. Enkódolás: Google **encoded polyline algorithm** (5 tizedes) — kb. 8–10 bájt/pont; egy 10 km-es
   futás így ~3–6 kB.
3. Ez megy a `cardio_details.route_polyline` mezőbe, a `route_point_count`-tal együtt, a
   normál session-update outbox-elemmel ([52 §4](52-cardio-domain-backend-plan.md) bump-szabály!).
4. A splitek is ekkor számolódnak (`cardio_splits`), a szűrt pontokból.
5. A nyers `CardioTrackPoints` **marad lokálisan** (újraszámoláshoz, C6/C8 elemzésekhez), de
   egy karbantartó lépés a 90 napnál régebbi nyers pontokat törli — a polyline addigra a
   szerveren van, a részletes elemzést pedig senki nem futtatja fél év múlva.

### D-C4.2 — A polyline az igazságforrás a megjelenítéshez

Minden eszköz (másik telefon, web-admin, edzői nézet) a polyline-t rajzolja. Így a nyomvonal
akkor is látszik, ha a nyers pontok már törlődtek vagy másik eszközön nem is léteztek.

---

## 6. Megjelenítés

### 6.1 C4a — `RoutePainter` (saját festés, nulla új dep) — D-C.6

- Bemenet: dekódolt polyline + opcionális szín-skálázó (tempó vagy magasság szerint).
- Kivetítés: Web-Mercator, majd a bounding boxra illesztve, `aspect ratio` megőrzéssel,
  belső margóval.
- Rajz: háttér = `surfaceContainer` téma-szín; útvonal = 3–4 px vastag, lekerekített végű
  vonal a **primary** színnel; start/vég marker (kör + zászló-ikon); szaggatott szakasz a
  jel-hézagoknál; opcionális **tempó-szerinti gradiens** (lassú → gyors: a téma metrika-színei
  közti interpoláció).
- Használat: session-összegzés (nagy), session-kártya (kis, statikus miniatűr).
- Előny: offline, téma-tudatos (világos/sötét), nincs csempe-licenc, nincs hálózati kérés az
  edzés után, és pontosan úgy néz ki, mint a `TimeSeriesChart` — egy vizuális nyelv.
- Hátrány, tudatosan vállalva: **nincs térképi kontextus** (utcanevek, tereptárgyak).
  A túránál ez a legfájóbb — ezért van C4b.

Teljesítmény: a festés `RepaintBoundary`-ban, a dekódolt pontok memoizálva; a kártya-miniatűr
`Picture`-ként cache-elve, hogy a listagörgetés ne fessen újra.

### 6.2 C4b — valódi térképcsempe *(opcionális, csak ha kell)*

Ha a nyomvonal kontextus nélkül kevésnek bizonyul (leginkább a túránál):
`flutter_map` + OSM raszter-csempék. Ekkor eldöntendő: csempe-forrás és annak
használati feltételei, kötelező attribúció a UI-ban, csempe-cache mérete, és offline viselkedés.
Ez a doc **nem** dönti el — a C4b saját mini-tervet kap, ha egyáltalán elindul.

---

## 7. Feladatlista (C4a)

| # | Lépés |
|---|---|
| G1 | `geolocator` bevezetése + platform-konfiguráció (Info.plist kulcsok, Android manifest engedélyek és szolgáltatástípus) |
| G2 | `LocationService` a `lib/core/location/`-ben: engedély-állapot stream, pozíció-stream, aktivitás-függő beállítások, no-op teszt-implementáció |
| G3 | `CardioTrackPoints` drift-tábla + azonnali írás |
| G4 | `track_filter.dart` (pontosság-, sebesség-, elmozdulás-kapuk, magasság-simítás, haversine-táv) + tesztek rögzített nyomvonalakon |
| G5 | Engedély-utak UI-ja (§3.3 mátrix), magyarázó lap, „GPS nélkül is megy” ág |
| G6 | Háttérfutás: Android előtér-szolgáltatás **a meglévő ongoing notificationnel egyesítve**, iOS háttér-mód |
| G7 | Auto-pause bekötése a GPS-sebességre ([53 §4.3](53-cardio-mobile-plan.md)) |
| G8 | Záró feldolgozás: ritkítás → polyline-enkódolás → `cardio_details` → outbox-bump; splitek számítása |
| G9 | `RoutePainter` + összegzés-nézet + kártya-miniatűr |
| G10 | Nyers pontok 90 napos karbantartó törlése |
| G11 | Akku-mérés és a §4.5 küszöb ellenőrzése, az eredmény ide dokumentálva |

---

## 8. Mérési napló *(a C4a után töltendő)*

| Dátum | Eszköz | Aktivitás | Hossz | Mért táv | Referencia | Eltérés | Akku/óra |
|---|---|---|---|---|---|---|---|
| – | – | – | – | – | – | – | – |
