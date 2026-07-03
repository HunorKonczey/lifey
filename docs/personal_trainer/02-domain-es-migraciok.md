# 02 — Domain-modell és migrációk

## Kiindulási állapot (tényleges kód, 2026-07)

- `foods` és `exercises` **globális, közös katalógusok** — nincs `user_id` (a V6__ownership.sql szándékosan hagyta ki őket). Mindkettő `SyncableEntity` (delta sync-elt, soft delete).
- `recipes`, `workout_templates`, `meals`, `workout_sessions`, `weight_entries`, stb. már user-tulajdonúak.
- Legutolsó migráció: `V39__user_avatars.sql` → az itteni migrációk **V40-től** indulnak.
- `exercises`-t a `V2__seed_exercises.sql` seedelte (közös alap-katalógus).

## Változás 1 — `foods` és `exercises` user-tulajdonba adása

Ez a modul előfeltétele: az edző "saját ételei/gyakorlatai" csak így értelmezhetők, és a deep-copy hozzárendelés is erre épül.

### V40__foods_exercises_ownership.sql

Lépések (egy migrációban, tranzakcióban):

```sql
-- 1) oszlopok
alter table foods add column user_id bigint references users (id);
alter table exercises add column user_id bigint references users (id);
-- provenance a későbbi trainer-másolatokhoz (minden érintett táblára, lásd Változás 3)
alter table foods add column origin_source_id bigint;
alter table foods add column origin_trainer_id bigint references users (id);
alter table exercises add column origin_source_id bigint;
alter table exercises add column origin_trainer_id bigint references users (id);

-- 2) az ELSŐ (legrégebbi, nem-legacy) user megkapja az eredeti sorokat
update foods set user_id = (select id from users
    where lower(email) <> 'legacy@lifey.local' order by id limit 1);
update exercises set user_id = (select id from users
    where lower(email) <> 'legacy@lifey.local' order by id limit 1);

-- 3) MINDEN TOVÁBBI user teljes másolatot kap a katalógusról,
--    és az Ő hivatkozásaik átíródnak a saját másolataikra.
--    (PL/pgSQL DO blokk: userenként insert..select a foods/exercises-ből,
--    old_id → new_id mapping temp táblába, majd update:
--      - meal_entries.food_id           (a user meal-jein keresztül)
--      - recipe_ingredients.food_id     (a user receptjein keresztül)
--      - workout_template_exercises.exercise_id (a user sablonjain keresztül)
--      - workout_session_exercises / exercise_sets.exercise_id (a user sessionjein keresztül))

-- 4) not null + indexek
alter table foods alter column user_id set not null;
alter table exercises alter column user_id set not null;
create index foods_user_id_idx on foods (user_id);
create index exercises_user_id_idx on exercises (user_id);

-- 5) delta sync: minden átírt hivatkozású szülő-entitás updated_at bump-ja,
--    hogy a mobil kliensek lehúzzák a változást
update meals set updated_at = now() where id in (…érintett…);
update recipes set updated_at = now() where …;
update workout_templates set updated_at = now() where …;
update workout_sessions set updated_at = now() where …;
```

> A 3) pont a legkényesebb rész — a pontos PL/pgSQL a megvalósításkor készül, de a szerkezete: `for u in (select users, kivéve az első és a legacy) loop → create temp table id_map as insert…returning → update hivatkozások a mapping alapján → end loop`. A `barcode` unique constraintet (ha van) `(user_id, barcode)`-ra kell módosítani; ugyanígo a food-név dedupe indexet (V4) `(user_id, name)`-re.

### Kód-változások

- `Food` és `Exercise` entity: `@ManyToOne User user` + `originSourceId`, `originTrainerId` mezők.
- `FoodService`/`ExerciseService` + repository-k: minden lekérdezés a bejelentkezett userre szűr (pontosan úgy, ahogy a `RecipeService` már csinálja) — a controller réteg nem változik.
- **Barcode lookup** (`GET /foods/barcode/{barcode}`): userre szűrve keres; ha nincs találat, az OpenFoodFacts-ből behúzott étel az aktuális userhez jön létre.
- **Seed új usernek:** a V2-es közös exercise-seed kiesik. A meglévő `UserRegisteredEvent` mintára új listener (`StarterCatalogListener`): regisztrációkor bemásolja az alap gyakorlat-katalógust az új usernek. A forrás egy kódban tartott lista vagy egy `exercise_catalog_seed` referencia tábla — javasolt: **kódban tartott lista** (egyszerűbb, verziózható).

### Delta sync hatás (⚠ legnagyobb kockázat)

- A foods/exercises sync végpontok mostantól user-szűrtek. A **duplikált** userek régi cache-e a mobilon **érvénytelen id-kat** tartalmaz (az ő ételeik új id-t kaptak).
- Megoldás: a szülő-entitások `updated_at` bump-ja (5. lépés) miatt a következő delta sync lehozza az átkötött sorokat, a régi food/exercise sorok pedig az ő szemszögéből "eltűnnek" — de a drift cache-ben ott maradhatnak árva sorok.
- **Javaslat:** a migrációval egyidejű mobil app verzió **egyszeri kényszerített teljes újraszinkront** végez (sync cursor reset a foods/exercises táblákra). Ez a `docs/16-delta-sync-rollout.md` mintáit követi. Mivel jelenleg gyakorlatilag egy valós felhasználó van, a kockázat kezelhető — de a migrációt Testcontainers-teszttel le kell fedni (több user, kereszthivatkozások).

---

## Változás 2 — Edző–kliens kapcsolat és meghívók

### V41__trainer_clients.sql

Egyetlen tábla viszi a meghívót ÉS a kapcsolatot (a meghívó a kapcsolat `PENDING` állapota — nem kell két tábla):

```sql
create table trainer_clients (
    id           bigserial primary key,
    trainer_id   bigint not null references users (id),
    client_id    bigint not null references users (id),
    status       varchar(16) not null,        -- PENDING | ACTIVE | DECLINED | REVOKED | EXPIRED
    created_at   timestamptz not null default now(),
    expires_at   timestamptz not null,        -- created_at + 24h (csak PENDING-re értelmes)
    responded_at timestamptz,                 -- elfogadás/elutasítás ideje
    revoked_at   timestamptz,
    revoked_by   bigint references users (id),-- ki bontotta (edző vagy kliens)
    constraint trainer_clients_no_self check (trainer_id <> client_id)
);

create index trainer_clients_trainer_idx on trainer_clients (trainer_id, status);
create index trainer_clients_client_idx  on trainer_clients (client_id, status);

-- egy edző–kliens párnak legfeljebb egy élő (PENDING/ACTIVE) sora lehet
create unique index trainer_clients_one_live_uq
    on trainer_clients (trainer_id, client_id)
    where status in ('PENDING', 'ACTIVE');
```

Megjegyzések:

- **`EXPIRED` státuszt nem cron állítja**: olvasáskor a `PENDING and expires_at < now()` sorokat a service lejártként kezeli (nem listázza), és egy alacsony prioritású takarító job (a meglévő `PasswordResetTokenCleanupJob` mintájára) állítja át ténylegesen `EXPIRED`-re.
- **24 órás rate-limit** lekérdezésből: `exists(select 1 from trainer_clients where trainer_id=? and client_id=? and created_at > now() - interval '24 hours')` → ha igaz, új meghívó tiltva. (Az e-mail → client_id feloldás a meghíváskor történik, így a tábla nem tárol e-mailt.)
- **Történet megőrzése:** bontás/elutasítás után a sor megmarad (audit), új meghívó **új sort** szúr be — ezért nincs teljes unique a (trainer_id, client_id) páron, csak az élő állapotokra.

## Változás 3 — Hozzárendelések (provenance + assignment log)

### V42__content_assignments.sql

```sql
-- provenance oszlopok a másolat-célpontokra (foods/exercises a V40-ben már megkapta)
alter table recipes add column origin_source_id bigint;
alter table recipes add column origin_trainer_id bigint references users (id);
alter table workout_templates add column origin_source_id bigint;
alter table workout_templates add column origin_trainer_id bigint references users (id);

create table content_assignments (
    id           bigserial primary key,
    trainer_id   bigint not null references users (id),
    client_id    bigint not null references users (id),
    content_type varchar(16) not null,   -- TEMPLATE | RECIPE
    source_id    bigint not null,        -- az edző eredetijének id-ja
    copied_id    bigint not null,        -- a kliensnél létrejött másolat id-ja
    assigned_at  timestamptz not null default now()
);

create index content_assignments_trainer_idx on content_assignments (trainer_id, client_id);
```

Megjegyzések:

- `origin_source_id` **szándékosan nem FK** — az edző törölheti (soft delete) az eredetit, a kliens másolata attól még él.
- A dedupe kulcsa másoláskor: "van-e a kliensnek olyan food/exercise sora, ahol `origin_trainer_id = edző` és `origin_source_id = forrás-id` és `deleted_at is null`" → ha igen, azt használjuk újra a hivatkozás átkötésénél.
- A `content_assignments` a **tény-napló** (mit osztott ki az edző) — az edző "Kiosztott tervek" nézete és az újra-hozzárendelési figyelmeztetés forrása.

## Változás 4 — Szerepkör-audit (super admin)

### V43__role_audit_log.sql

A szerepkörök a meglévő `user_roles` collection-táblában élnek — a kiosztás/visszavonás oda ír. Mivel a szerepkör-változás biztonsági szempontból érzékeny, minden változás audit-naplóba kerül:

```sql
create table role_audit_log (
    id             bigserial primary key,
    actor_id       bigint not null references users (id),  -- ki végezte (super admin)
    target_user_id bigint not null references users (id),  -- kinek
    role           varchar(32) not null,                   -- pl. ROLE_TRAINER
    action         varchar(8)  not null,                   -- GRANT | REVOKE
    created_at     timestamptz not null default now()
);

create index role_audit_log_target_idx on role_audit_log (target_user_id);
```

Megjegyzések:

- **Nincs `ROLE_SUPER_ADMIN`-seed migráció** — a super admin kiosztása környezet-specifikus (konkrét e-mail cím), ezért **egyszeri kézi SQL**:
  `insert into user_roles (user_id, role) select id, 'ROLE_SUPER_ADMIN' from users where lower(email) = '<tulajdonos e-mail>';`
  Migrációba égetett e-mail cím nem való (dev/prod eltér, és a migráció megismételhetetlen).
- Az audit-tábla **append-only** — nincs update/delete útvonal a kódban.

## Frissített domain-áttekintés (delta)

```
User ─┬─< Food            (ÚJ: user_id, origin_*)
      ├─< Exercise        (ÚJ: user_id, origin_*)
      ├─< Recipe          (origin_* ÚJ)
      ├─< WorkoutTemplate (origin_* ÚJ)
      ├─< trainer_clients (trainer_id oldalról)   ÚJ
      ├─< trainer_clients (client_id oldalról)    ÚJ
      ├─< content_assignments (trainer/client)    ÚJ
      └─< role_audit_log (actor/target)           ÚJ
```

A `docs/03-domain-model.md`-t a megvalósításkor frissíteni kell (Food/Exercise + user kapcsolat, új entitások).
