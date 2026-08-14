# 52 – Cardio: domain, migrációk, backend API

Státusz: **TERV.** Iterációk: **C0** (taxonómia), **C1** (adat-mag), a C4a a nyomvonal-táblát viszi.
Előzmény: [51-cardio-overview-plan.md](51-cardio-overview-plan.md) — a D-C.1 (közös entitás) és a
D-C.2 (hibrid tárolás) döntés itt válik sémává.

Érintett meglévő kód:
- `backend/src/main/java/com/lifey/workout/session/` — `WorkoutSession`, `WorkoutSessionRepository`,
  `WorkoutSessionMapper`, `WorkoutSessionController`, `service/WorkoutSessionServiceImpl`,
  `dto/WorkoutSessionRequest|Response`
- `backend/src/main/resources/db/migration/` — legmagasabb alkalmazott: **V65** (V64 kimaradt),
  tehát az új migrációk **V66**-tól indulnak (indítás előtt ellenőrizd, hátha közben lett új)
- `backend/src/main/java/com/lifey/statistics/` — a C3-ban bővül, lásd [56-os doc](56-cardio-statistics-plan.md)

---

## 1. Enumok (C0)

Három enum, **kódstringként** tárolva (`varchar`), nem ordinal-ként — a séma túléli az
átrendezést, és a delta-sync payload olvasható marad.

```java
// com.lifey.workout.session.SessionKind
public enum SessionKind { STRENGTH, CARDIO }

// com.lifey.workout.session.cardio.ActivityType
public enum ActivityType {
    INDOOR_BIKE(ActivityFamily.MACHINE),
    RUNNING(ActivityFamily.DISTANCE),
    WALKING(ActivityFamily.DISTANCE),
    HIKING(ActivityFamily.DISTANCE),
    BASKETBALL(ActivityFamily.GAME),
    FOOTBALL(ActivityFamily.GAME),
    OTHER_CARDIO(ActivityFamily.GAME);   // menekülőút, lásd D-C1.4
    private final ActivityFamily family;
    // ...
}

// com.lifey.workout.session.cardio.ActivityFamily
public enum ActivityFamily { DISTANCE, MACHINE, GAME }
```

**Dart-párja** (`mobile/lib/features/workouts/domain/activity_type.dart`) ugyanezekkel a
kódokkal, a `exercise_enums.dart` mintájára: `kActivityTypes` lista megjelenítési sorrendben,
`activityTypeLabel(l10n, code)`, `activityTypeIcon(code)`, `activityTypeColor(code, context)`,
`activityFamilyOf(code)`. **Nem** generált fájl, kézzel írjuk.

### D-C1.4 — Miért van `OTHER_CARDIO`

Mert a séma-migráció drágább, mint egy enum-érték. Ha a user holnap elkezd evezni, addig is
`OTHER_CARDIO`-ként rögzítheti (`GAME` család = idő + pulzus + kalória, ami mindenre igaz), és a
következő iteráció emeli ki külön típussá. A UI-ban a picker legalján, „Egyéb” néven.

### D-C1.5 — Az `ActivityFamily` **nem** oszlop

A típusból egyértelműen következik, tehát származtatott (Java: enum-mező, Dart: switch). Külön
oszlopként tárolva két igazságforrás lenne, amiket egy elírás szétcsúsztat.

---

## 2. Séma

### 2.1 V66 — diszkriminátor a `workout_sessions`-ön

```sql
-- V66__cardio_session_kind.sql
ALTER TABLE workout_sessions
    ADD COLUMN session_kind   varchar(16) NOT NULL DEFAULT 'STRENGTH',
    ADD COLUMN activity_type  varchar(32),
    ADD COLUMN moving_seconds integer;

ALTER TABLE workout_sessions
    ADD CONSTRAINT workout_sessions_kind_activity_ck
        CHECK ((session_kind = 'STRENGTH' AND activity_type IS NULL)
            OR (session_kind = 'CARDIO'   AND activity_type IS NOT NULL));

CREATE INDEX idx_workout_sessions_user_kind_started
    ON workout_sessions (user_id, session_kind, started_at DESC)
    WHERE deleted_at IS NULL;
```

- A `DEFAULT 'STRENGTH'` teszi visszamenőleg konzisztenssé a meglévő sorokat **és** a régi
  klienseket, amelyek nem küldenek `sessionKind`-ot.
- A `CHECK` a D-C.1 diszkriminátor-invariánsát őrzi adatbázis-szinten. Ez fontos: a
  `session_kind` sok helyen `switch`-elni fog, és egy inkonzisztens sor néma hibát okozna.
- A parciális index a fajta-szűrt listákat és a C3 statisztika-lekérdezéseit szolgálja ki.
  A meglévő `(user_id, started_at)` lekérdezéseket nem rontja el.

### 2.2 V67 — `cardio_details` (1:1)

Egy sor session-önként, csak `CARDIO` fajtánál. Minden metrika nullable — nem minden család
tölti mindet (lásd [51 §3](51-cardio-overview-plan.md)).

```sql
-- V67__cardio_details.sql
CREATE TABLE cardio_details (
    id                      bigserial PRIMARY KEY,
    workout_session_id      bigint      NOT NULL UNIQUE
                                REFERENCES workout_sessions (id) ON DELETE CASCADE,

    -- DISTANCE + MACHINE
    distance_meters         double precision,
    elevation_gain_meters   double precision,
    elevation_loss_meters   double precision,
    max_altitude_meters     double precision,
    steps                   integer,
    avg_cadence             double precision,   -- spm (futás) vagy rpm (bicikli)
    max_cadence             double precision,

    -- MACHINE
    avg_watts               double precision,
    max_watts               double precision,
    resistance_level        integer,
    device_calories         double precision,   -- a gép kijelzője, lásd 51 Q4

    -- közös élettani
    max_heart_rate          double precision,
    hr_zone1_seconds        integer,
    hr_zone2_seconds        integer,
    hr_zone3_seconds        integer,
    hr_zone4_seconds        integer,
    hr_zone5_seconds        integer,

    -- GAME
    intensity               smallint,           -- 1..5
    venue                   varchar(16),        -- INDOOR | OUTDOOR
    game_format             varchar(32),        -- szabad szöveg-kód: 5V5, SMALL_SIDED, PRACTICE...
    score_points            integer,            -- kosár: pont · foci: gól
    score_assists           integer,
    score_rebounds          integer,

    -- eredetjelzés (51 R8)
    distance_source         varchar(16),        -- MEASURED | MANUAL | DEVICE
    calories_source         varchar(16),

    -- nyomvonal (54-es doc)
    route_polyline          text,               -- encoded polyline, tömörített
    route_point_count       integer,

    CONSTRAINT cardio_details_intensity_ck CHECK (intensity IS NULL OR intensity BETWEEN 1 AND 5),
    CONSTRAINT cardio_details_venue_ck     CHECK (venue IS NULL OR venue IN ('INDOOR','OUTDOOR'))
);
```

> **Megvalósításkori eltérés (C1.2, 2026-08-10):** a fenti vázlat eredetileg saját
> `created_at`/`updated_at` oszlopot is javasolt — a ténylegesen megírt `V67__cardio_details.sql`
> **nem** viszi. Indok: a meglévő gyerektáblák (`workout_session_exercises`,
> `program_workouts`) egyike sem kap saját időbélyeget, csak a top-level, önmagában
> szinkronizálandó táblák (pl. `training_programs`); a `cardio_details` sosem szinkronizálódik
> önállóan (lásd §4), tehát a saját időbélyeg holt súly lett volna. A tényleges migráció:
> [59-cardio-implementation-plan.md C1.2](59-cardio-implementation-plan.md).

**Miért egy tábla és nem három családonként?** Mert a lekérdezések (statisztika, lista,
PR-számítás) családoktól függetlenül futnak, és három `LEFT JOIN` háromszoros komplexitás
nulla haszonért. A nullable oszlopok Postgresen gyakorlatilag ingyen vannak.

**Miért nem a `workout_sessions`-ön?** Mert az minden lista- és sync-lekérdezésben benne van
(dashboard, edzői naptár, heti riport), és nem akarunk 25 oszloppal szélesíteni egy táblát, ahol
az esetek zömében mind NULL. A `cardio_details` csak akkor joinolódik, ha kell.

### 2.3 V68 — `cardio_splits` (C6 előkészítés, üresen is bevezethető)

```sql
CREATE TABLE cardio_splits (
    id                 bigserial PRIMARY KEY,
    workout_session_id bigint  NOT NULL REFERENCES workout_sessions (id) ON DELETE CASCADE,
    split_index        integer NOT NULL,          -- 0-tól
    distance_meters    double precision NOT NULL, -- rendszerint 1000
    duration_seconds   integer NOT NULL,
    elevation_delta_m  double precision,
    avg_heart_rate     double precision,
    UNIQUE (workout_session_id, split_index)
);
```

A splitek **kliensen számolódnak** a záráskor, és úgy szinkronizálódnak — nem a szerver
származtatja. Indok: a szerver nem kap nyers GPS-pontokat (lásd D-C1.2), és a kézzel rögzített,
GPS nélküli edzésnél sincs miből számolnia.

### D-C1.2 — A nyers GPS-pontok **nem** mennek fel a szerverre

Egy 2 órás túra ~7 000 pont. Feltöltve ez sávszélesség, tárhely és személyes helyadat, három
olyan költség, amiért cserébe a szerver semmit nem nyújt (nem elemzünk szerveroldalon
nyomvonalat). Ezért:

- a **nyers pontok csak a telefon driftjében** élnek (`CardioTrackPoints` tábla, [54-es doc](54-cardio-gps-route-plan.md)),
- a szerverre egy **enkódolt polyline** megy (`route_polyline`, ~10 bájt/pont, ritkított
  pontokkal jellemzően 5–20 kB), ami elég az összegzés-térkép újrarajzolásához bármelyik eszközön,
- ha a user törli a session-t, a polyline is megy vele (CASCADE).

Következmény: **nincs `cardio_track_points` tábla a backendben.** Ha később kell (pl. web-admin
nyomvonal-elemzés), az additív bővítés.

---

## 3. Entitás- és DTO-változások

### 3.1 `WorkoutSession` (bővítés)

```java
@Enumerated(EnumType.STRING)
@Column(name = "session_kind", nullable = false)
private SessionKind sessionKind = SessionKind.STRENGTH;

/** Non-null exactly when {@link #sessionKind} is CARDIO (DB CHECK enforces it). */
@Enumerated(EnumType.STRING)
@Column(name = "activity_type")
private ActivityType activityType;

/**
 * Time actually spent moving, in seconds — the wall-clock span minus pauses and
 * auto-pause gaps. This, not (finishedAt - startedAt), is what statistics count:
 * a 3-hour hike with a 40-minute lunch is not a 3-hour workout.
 * Null for a STRENGTH session (there the span is the workout).
 */
@Column(name = "moving_seconds")
private Integer movingSeconds;

@OneToOne(mappedBy = "workoutSession", cascade = CascadeType.ALL, orphanRemoval = true)
private CardioDetails cardioDetails;

@OneToMany(mappedBy = "workoutSession", cascade = CascadeType.ALL, orphanRemoval = true)
@OrderBy("splitIndex ASC")
private List<CardioSplit> splits = new ArrayList<>();
```

Új osztályok a `com.lifey.workout.session.cardio` alcsomagban: `CardioDetails`, `CardioSplit`,
`ActivityType`, `ActivityFamily`. A `SessionKind` a `session` gyökérben marad (nem cardio-specifikus).
A CLAUDE.md csomagszabálya szerint: 2+ azonos fajtájú fájlnál alcsomag — itt két entitás +
két enum, tehát az alcsomag indokolt.

### 3.2 `WorkoutSessionRequest` / `Response` (additív)

Mindkettőbe **egy** új blokk kerül, hogy a rekord ne hízzon 20 mezőt:

```java
public record WorkoutSessionRequest(
        // ... a meglévő mezők változatlanul ...

        /*
         * Null or STRENGTH from any client that predates cardio — the server
         * defaults to STRENGTH, so old clients keep their exact behaviour.
         */
        SessionKind sessionKind,

        /* Required exactly when sessionKind is CARDIO; rejected otherwise (400). */
        ActivityType activityType,

        @PositiveOrZero Integer movingSeconds,

        /* Cardio metrics; must be null unless sessionKind is CARDIO. */
        @Valid CardioDetailsRequest cardio,

        /* Per-km/lap splits, computed client-side. Replaces the whole list on update. */
        List<@Valid CardioSplitRequest> splits
) {}
```

Validáció a service-ben (nem Bean Validationnel, mert keresztmezős):
`sessionKind == CARDIO` ⇒ `activityType != null`; `sessionKind != CARDIO` ⇒ `cardio == null &&
splits` üres. Sértésre `400`, a `common/exception` meglévő mintájával.

A `Response` szimmetrikusan kap `sessionKind`, `activityType`, `movingSeconds`,
`cardio: CardioDetailsResponse`, `splits`. **Fontos:** a `sessionKind` a válaszban
**mindig ki van töltve** (sosem null), így a kliensek nem `null`-ból következtetnek.

> **Megvalósításkori pontosítás (C1.4, 2026-08-10):** a `cardio` blokk is **teljes csere**
> update-kor, ugyanúgy mint `splits` — egy `cardio: null` update **törli** a session meglévő
> cardio-adatait, nem "hagyja változatlanul". Ez a doksi eredeti szövegéből nem következett
> egyértelműen, de a `replaceSets`/`replacePlannedExercises` meglévő mintája (mindig teljes
> csere) és a mobil kliens működése (mindig a teljes aktuális állapotot küldi) ezt diktálja.
> Lásd [59-cardio-implementation-plan.md C1.4](59-cardio-implementation-plan.md).

### D-C1.3 — Nincs új controller és nincs új végpont-család

A `/api/v1/workout-sessions` marad az egyetlen belépési pont, minden meglévő végponttal
(`findAll`, `findPage`, `findDelta`, `create`, `update`, `delete`). Ez a D-C.1 egyenes
következménye: a delta-sync kurzor, a lapozás és az edzői láthatóság egy helyen marad.

Egyetlen **additív** bővítés a listázó végpontokon egy opcionális szűrő:

```
GET /api/v1/workout-sessions?page=0&size=20&kind=CARDIO
```

`kind` hiánya = minden fajta (a mai viselkedés). A **delta-sync végpont
(`?updatedSince=`) NEM kap `kind` szűrőt** — a mobil kliensnek minden változás kell, és a
szűrt delta csendben lyukat ütne a helyi cache-ben.

> **Megvalósításkori pontosítás (C1.4):** a `findPageForUser` (az edzői kliens-nézet, `/api/v1/trainer/clients/{clientId}/workout-sessions`)
> **sem** kapott `kind` paramétert C1.4-ben — a metódus-szignatúra változatlan maradt, hogy a
> `TrainerClientDataController` érintetlen legyen. Ha az edzői nézetnek is kell fajta-szűrés,
> az a web-oldali C1w munka része ([58-cardio-web-plan.md](58-cardio-web-plan.md)), nem itt dől el.

### 3.3 Mapper

A `WorkoutSessionMapper` kap egy `toCardioDetails` / `toCardioResponse` párt. A meglévő
`ExerciseSummary` lista cardiónál **üres lista, nem null** — ez az [51 R1/R4](51-cardio-overview-plan.md)
kockázat legolcsóbb kezelése: minden meglévő fogyasztó (web-admin, edzői nézet, mobil) üres
listát iterál, nem NPE-zik.

---

## 4. Delta-sync: a kötelező `updatedAt`-bump (R3)

A `WorkoutSession` osztály fejdokumentációja már ma figyelmeztet: **csak a szülő van
delta-syncelve**, a gyerekek nincsenek önállóan tombstone-ozva, ezért ha csak gyerek változik,
a Hibernate dirty-checking nem bumpolja a szülő `updatedAt`-jét, és a változás **soha nem ér át**
a másik eszközre.

A `cardioDetails` és a `splits` **pontosan ilyen gyerekek**. Ezért:

1. A `WorkoutSessionServiceImpl#update` meglévő explicit bump-ágát ki kell terjeszteni: ha a
   cardio-blokk vagy a split-lista megváltozott, ugyanúgy `touch()`-olni kell a szülőt.
2. Kötelező teszt (`WorkoutSessionServiceTest`): „csak a `cardio.distanceMeters` változik” →
   a session `updatedAt`-je nő, és megjelenik a `?updatedSince=` válaszban.
3. Ugyanez a kliensoldalon: a drift-repository cardio-mező-módosítása is enqueue-l egy
   session-update outbox-elemet, nem csak a detail-sort írja.

Ez a terv legkönnyebben elrontható pontja — a hiba **néma** (semmi nem hibázik, csak nem
szinkronizál), ezért van külön elfogadási feltétele.

---

## 5. Trainer / web-admin hatás (R4)

| Felület | Ma | C1 után | Teendő |
|---|---|---|---|
| Edzői kliens-nézet session-listája | gyakorlat-lista + szettszám | `exercises: []` → „üres edzés” látszat | C1: a DTO `sessionKind`/`activityType` mezője már ott van; **C1w**: a web-oldali `kind`-elágazás — a teljes fájl-leltár és a lépések: [58-cardio-web-plan.md](58-cardio-web-plan.md) |
| Edzői naptár | ütemezett session-ök | cardio session-t ma senki nem ütemez | Nem érintett V1-ben |
| Heti edzői riport | `workoutCount` | megnő | [56-os doc §4](56-cardio-statistics-plan.md) |
| Trainer-komment / RPE-hurok | session-szintű | változatlanul működik cardióra is | Nincs teendő — ez a D-C.1 haszna |

---

## 6. Backend feladatlista

| # | Lépés | Iteráció |
|---|---|---|
| B1 | `SessionKind`, `ActivityType`, `ActivityFamily` enumok | C0 |
| B2 | V66 migráció (diszkriminátor + CHECK + index) | C1 |
| B3 | V67 migráció (`cardio_details`) | C1 |
| B4 | V68 migráció (`cardio_splits`) | C1 |
| B5 | `CardioDetails`, `CardioSplit` entitások + a `WorkoutSession` bővítése | C1 |
| B6 | DTO-bővítés (`CardioDetailsRequest/Response`, `CardioSplitRequest/Response`) + keresztmezős validáció | C1 |
| B7 | Mapper + `ExerciseSummary` üres-lista garancia | C1 |
| B8 | `?kind=` szűrő a lista-végpontokon (a deltán **nem**) | C1 |
| B9 | `updatedAt`-bump kiterjesztése + teszt (§4) | C1 |
| B10 | Repository-metódusok a statisztikához (`countByKind`, `sumDistance`, `sumMovingSeconds`) | C3 |
| B11 | `StatisticsResponse` bővítés | C3 → [56](56-cardio-statistics-plan.md) |
| B12 | Postman-kollekció frissítése (`docs/postman/`) | C1 |

### Tesztek (kötelező minimum)

- Migrációs teszt: meglévő session-ök `session_kind = 'STRENGTH'`, `activity_type IS NULL`.
- CHECK-constraint teszt: `CARDIO` + `activity_type NULL` beszúrása elbukik.
- Régi kliens szimulációja: `sessionKind` nélküli create → `STRENGTH` lesz, a válasz kitölti.
- Cardio create → read → update → delta-lekérdezés kör (a §4 bump-tesztet is beleértve).
- `?kind=CARDIO` csak cardio session-t ad vissza, és a lapozás konzisztens.
