# 09 — Ütemezett edzések: domain és backend terv

Kiindulás: a személyi edző modul PT1–PT3 kész (trainer_clients, TrainerAccessService, ContentAssignmentService). Legutolsó migráció: `V44__add_user_names.sql` → az itteni **V45-tel** indul.

## V45__workout_schedules.sql

```sql
-- 1) ütemezés-definíció (sorozat)
create table workout_schedules (
    id                 bigserial primary key,
    trainer_id         bigint not null references users (id),
    client_id          bigint not null references users (id),
    source_template_id bigint not null,             -- az edző sablonja; szándékosan nem FK (soft delete-elhető)
    client_template_id bigint not null references workout_templates (id), -- a kliens másolata, ebből indulnak a sessionök
    recurrence         varchar(8) not null,         -- ONCE | DAILY | WEEKLY
    days_of_week       varchar(32),                 -- WEEKLY: pl. 'MON,THU' (ISO rövidítések, vesszővel)
    time_of_day        time,                        -- opcionális fali óra szerinti időpont, minden előfordulásra öröklődik
    start_date         date not null,
    end_date           date not null,               -- ONCE-nál = start_date; <= start_date + 3 hónap
    created_at         timestamptz not null default now(),
    cancelled_at       timestamptz,
    constraint workout_schedules_date_order check (end_date >= start_date)
);

create index workout_schedules_trainer_idx on workout_schedules (trainer_id, client_id);
create index workout_schedules_client_idx  on workout_schedules (client_id) where cancelled_at is null;

-- 2) session-bővítés: közelgő (ütemezett) sessionök
alter table workout_sessions alter column started_at drop not null;
alter table workout_sessions add column scheduled_for date;
alter table workout_sessions add column scheduled_time time;   -- a sorozat time_of_day-ének másolata (denormalizált: a session önmagában teljes)
alter table workout_sessions add column schedule_id bigint references workout_schedules (id);

-- egy session vagy megtörtént, vagy ütemezett (vagy már elindított ütemezett)
alter table workout_sessions add constraint workout_sessions_started_or_scheduled
    check (started_at is not null or scheduled_for is not null);

create index workout_sessions_upcoming_idx
    on workout_sessions (user_id, scheduled_for)
    where started_at is null and deleted_at is null;
```

Megjegyzések:

- `source_template_id` nem FK — ugyanaz az elv, mint az `origin_source_id`-nál: az edző törölheti az eredetit, a sorozat előzménye attól még értelmes.
- `schedule_id` FK-ja **restrict** (nincs cascade): sorozat-sort soha nem törlünk fizikailag, a lemondás `cancelled_at`.
- A `days_of_week` egyszerű CSV — nem kell külön tábla három bitnyi információnak; a parse/format a service-ben él (`DayOfWeek` enum nevek).
- A `time` típus (és a Java `LocalTime`) **szándékosan időzóna nélküli**: fali óra szerinti idő, a kliens készüléke értelmezi. Nincs `timestamptz`, nincs konverzió — a `scheduled_for + scheduled_time` páros együtt írja le a tervezett alkalmat, és a session-be denormalizáltan másolódik, hogy a sor a sorozat nélkül is teljes legyen (sync-barát).

## Entity-változások

### `WorkoutSession` (workout/session)

```java
@Column(name = "started_at")            // nullable lett
private Instant startedAt;

/** Naptári nap, amelyre az edző ütemezte; null a sima (kliens által indított) sessionöknél. */
@Column(name = "scheduled_for")
private LocalDate scheduledFor;

/** Opcionális fali óra szerinti időpont (a sorozat time_of_day-ének másolata); csak megjelenítés/sorrend. */
@Column(name = "scheduled_time")
private LocalTime scheduledTime;

/** A workout_schedules sor id-ja; Long, nem JPA-kapcsolat — a workout csomag ne függjön a trainer csomagtól. */
@Column(name = "schedule_id")
private Long scheduleId;
```

### `WorkoutSchedule` (trainer csomag)

Új entity a `com.lifey.trainer` alatt (`timeOfDay` mezője `LocalTime`, nullable). Ezzel a trainer csomagban 3 entity lesz (`TrainerClient`, `ContentAssignment`, `WorkoutSchedule`) → a konvenció szerint `entity/` alcsomagba szerveződnek (a meglévő kettő átmozgatásával). `Recurrence` enum: `ONCE, DAILY, WEEKLY`.

## ⚠ "Elvégzett = started_at not null" — kötelező audit

A rendszer minden pontja, ahol a session "megtörtént edzést" jelent, mostantól **szűrni köteles** a közelgő sorokra. Az érintett helyek (a jelen kód alapján):

| Hely | Változás |
|---|---|
| `WorkoutSessionRepository.findByUserIdAndDeletedAtIsNull` (lista/lapozás) | az **előzmény**-lista `started_at is not null`-t szűr; a mobil lokálisan bontja szét közelgő/előzmény nézetre — a *szerver-oldali* lista végpont az előzményt adja |
| `StatisticsServiceImpl` (edzésszám, volumen, időtartam, aktív kcal, pulzus) | minden aggregáció csak `started_at is not null` sorokból |
| `TrainerClientDataController` / kliens edzés-előzmény végpont | előzmény = elvégzett; a közelgőket a külön ütemterv-végpont adja |
| Delta sync (`findByUserIdAndUpdatedAtGreaterThanEqual`) | **NEM szűr** — a sync-nek épp le kell vinnie a közelgőket is |

Módszer: repository-szintű elnevezett metódusok (`...AndStartedAtIsNotNull`) az előzmény-útvonalakon + **regressziós teszt**, amely közelgő sessionök jelenlétében ellenőrzi, hogy a statisztika és az előzmény-lista változatlan eredményt ad.

## Csomagstruktúra (bővítés)

```
com.lifey.trainer/
  entity/
    TrainerClient.java, ContentAssignment.java, WorkoutSchedule.java   # entity/ alcsomag (3 entity)
  repository/
    TrainerClientRepository, ContentAssignmentRepository, WorkoutScheduleRepository
  controller/
    …meglévők…
    WorkoutScheduleController.java        # ütemezés végpontok (edző oldal)
  service/
    …meglévők…
    WorkoutScheduleService(+Impl)         # validálás, generálás, materializálás, lemondás
  exception/
    ScheduleHorizonExceededException,     # > 3 hónap
    ScheduleInPastException,
    EmptyRecurrenceException,             # WEEKLY nap-kiválasztás nélkül
    ScheduleNotFoundException,
    OccurrenceNotCancellableException     # múltbeli vagy már elkezdett előfordulás
  dto/ …
```

## Végpontok (mind `ROLE_TRAINER` + `TrainerAccessService.requireActiveClient`)

| Metódus | Útvonal | Leírás |
|---|---|---|
| POST | `/api/v1/trainer/schedules` | Sorozat létrehozása: `{ clientId, templateId, recurrence, daysOfWeek?, timeOfDay?, startDate, endDate? }` (`timeOfDay`: `"HH:mm"`, opcionális) → válasz: sorozat + létrejött előfordulások száma. Hibák: 400 (múltbeli kezdés, üres WEEKLY, dátum-sorrend, érvénytelen időpont), 404 (nem az edző sablonja), 422 (> 3 hónap horizont) |
| GET | `/api/v1/trainer/clients/{clientId}/schedules` | A kliens aktív sorozatai: ismétlődés-leírás, sablon-név, elvégzett/kihagyott/hátralévő darabszám |
| GET | `/api/v1/trainer/clients/{clientId}/scheduled-sessions?from&to` | Előfordulás-lista naptár/idővonal nézethez: dátum + időpont (ha van), sablon-név, származtatott státusz (`UPCOMING / DONE / MISSED / CANCELLED`), sorozat-id |
| DELETE | `/api/v1/trainer/schedules/{scheduleId}` | Sorozat lemondása: `cancelled_at` + jövőbeli el nem kezdett előfordulások soft delete |
| DELETE | `/api/v1/trainer/scheduled-sessions/{sessionId}` | Egyetlen jövőbeli, el nem kezdett előfordulás lemondása; különben 409 |

A kliens (mobil) oldalon **nincs új végpont**: a közelgő sessionök a meglévő delta sync-en érkeznek, az indítás/törlés a meglévő session-útvonalakon megy.

A `scheduleId`/`sessionId`-alapú műveletek jogosultsága: a sor `trainer_id`-jának egyeznie kell a bejelentkezett edzővel (nem elég a szerepkör) — különben 404 (nem 403: ne szivárogjon, hogy létezik).

## WorkoutScheduleService — a lényegi logika

```
create(trainerId, req):
  requireActiveClient(trainerId, req.clientId)
  template = az edző sablonjai közül (ownership check)          # 404
  validate: startDate >= ma; WEEKLY → daysOfWeek nem üres
  endDate = ONCE → startDate; egyébként req.endDate             # kötelező, ha nem ONCE
  if endDate > startDate.plusMonths(3) → 422
  dates = generateOccurrences(recurrence, daysOfWeek, startDate, endDate)   # tiszta függvény
  if dates.size() > 100 → 422 (sanity cap)
  @Transactional:
    clientCopy = élő kliens-másolat (origin_trainer_id=trainer, origin_source_id=template.id)
                 ?: contentAssignmentService.assign(trainer, client, TEMPLATE, template.id)  # deep copy + assignment log
    schedule = insert workout_schedules
    for date in dates:
      insert workout_sessions (user=client, scheduledFor=date, scheduledTime=req.timeOfDay,
                               scheduleId, template=clientCopy, templateName=clientCopy.name,
                               startedAt=null)          # SyncableEntity → updated_at beáll, sync leviszi
```

- `generateOccurrences` **tiszta, dátum-aritmetikás** függvény (`LocalDate`, nincs időzóna): ONCE → 1 nap; DAILY → minden nap zárva-zárva; WEEKLY → a kiválasztott `DayOfWeek`-ek a tartományban. Külön unit-teszt (hónap-átfordulás, szökőnap, üres eredmény ha WEEKLY-ben nincs találat a tartományban → 400).
- **A tervezett gyakorlatok NEM materializálódnak** — a közelgő session csak fejléc. A kliens indításakor a mobil a meglévő "sablonból indítás" flow-val tölti fel a `plannedExercises`-t a sablon-másolatból, és `started_at`-ot állít (lokálisan, majd push sync). Ha a kliens időközben törölte a sablon-másolatot, az indítás üres sessionként megy tovább a `template_name` snapshottal — nem hiba.

```
cancelSchedule(trainerId, scheduleId):
  schedule = sajátom (trainer_id egyezés)                       # 404
  @Transactional:
    schedule.cancelledAt = now()
    soft delete: a sorozat sessionjei, ahol started_at is null és scheduled_for >= ma
    (deleted_at + updated_at bump → tombstone sync)
```

### Bontás-hook (REVOKED)

A kapcsolat-bontás meglévő service-útvonala (edző oldali eltávolítás és kliens oldali kilépés **egyaránt**) kiegészül: az adott edző–kliens pár nem lemondott sorozataira `cancelSchedule` fut. Egy tranzakcióban a REVOKED-ra állítással.

## Delta sync hatás

- `WorkoutSessionSyncDto` (le és fel): + `scheduledFor`, + `scheduledTime`; a `startedAt` **nullable lesz**.
- A nullable `startedAt` **nem kompatibilitási kockázat** — eldöntött (2026-07-04): az app még nincs kiadva, nincs régi verzió a felhasználóknál, ezért nem kell API-verzió-kapu vagy koordinált release; a mobil sémafrissítés a backenddel együtt, normál módon megy ki.
- A mobil push (session indítása/szerkesztése) a `scheduledFor`/`scheduledTime`/`scheduleId` mezőket **változatlanul küldi vissza** — a szerver-oldali upsert nem engedi őket kliensről módosítani (read-only mezők a push feldolgozásban: a szerver a saját tárolt értékét tartja meg).
- Kliens-oldali törlés a meglévő session-törlés útvonalon (tombstone fel) — a szerver ütemterv-nézete ebből származtatja a "kliens törölte" státuszt.

## Tesztek

- **`generateOccurrences` unit:** ONCE/DAILY/WEEKLY, hónap-átfordulás, 3 hónapos határ (pont 3 hónap OK, +1 nap 422), WEEKLY üres kiválasztás → 400, WEEKLY találat nélküli tartomány → 400, 100-as cap.
- **`WorkoutScheduleServiceTest`:** idegen kliens → 403; idegen sablon → 404; másolat-újrahasznosítás (van élő másolat → nem duplikál, nincs → assign hívódik + assignment log); materializált darabszám; a `timeOfDay` minden előfordulásra öröklődik (és null is maradhat); tranzakciós rollback (ha a session-insert elhasal, sorozat sincs).
- **Lemondás:** sorozat-lemondás csak a jövőbeli el nem kezdetteket törli (múltbeli kihagyott + elvégzett marad); előfordulás-lemondás elkezdett sessionre → 409; másik edző sorozata → 404.
- **Bontás-hook:** REVOKED (mindkét irányból) → aktív sorozat lemondva, jövőbeli előfordulások törölve.
- **Regresszió (kritikus):** közelgő sessionök jelenlétében a statisztika-aggregátumok, a session-előzmény lista és a trainer kliens-edzés végpont eredménye változatlan; a delta sync viszont **tartalmazza** a közelgőket.
- **Controller:** `ROLE_USER` a `/trainer/schedules`-re → 403; validációs hibakódok (400/404/409/422) leképezése.
