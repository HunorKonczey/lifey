-- Foods and exercises stop being shared global catalogs (see V6__ownership.sql,
-- which deliberately excluded them) and become user-owned, like every other
-- personally-tracked entity. This is the prerequisite for the personal-trainer
-- module (docs/personal_trainer/02-domain-es-migraciok.md, "Változás 1"): a
-- trainer's own foods/exercises are what gets deep-copied into a client's
-- account on assignment, and "my own content" only means something once every
-- user has their own copy rather than sharing one catalog.
--
-- origin_source_id/origin_trainer_id are added now (nullable, unused until the
-- trainer content-assignment feature lands) so that migration isn't needed
-- again later.

alter table foods add column user_id bigint references users (id);
alter table foods add column origin_source_id bigint;
alter table foods add column origin_trainer_id bigint references users (id);

alter table exercises add column user_id bigint references users (id);
alter table exercises add column origin_source_id bigint;
alter table exercises add column origin_trainer_id bigint references users (id);

-- The earliest non-legacy user keeps the original rows as-is (no copy needed).
-- Falls back to the legacy placeholder (guaranteed to exist — see
-- V6__ownership.sql) when there is no real user yet: a brand new database only
-- has V2__seed_exercises.sql's seed rows and nobody to own them, and the NOT
-- NULL constraint further down would otherwise fail on those NULL user_ids.
update foods set user_id = coalesce(
    (select id from users where lower(email) <> 'legacy@lifey.local' order by id limit 1),
    (select id from users where lower(email) = 'legacy@lifey.local')
) where user_id is null;
update exercises set user_id = coalesce(
    (select id from users where lower(email) <> 'legacy@lifey.local' order by id limit 1),
    (select id from users where lower(email) = 'legacy@lifey.local')
) where user_id is null;

-- The old catalog-wide unique indexes must go before the copy loop below: once
-- a second user has their own "Rice" (hidden = false), a still-global unique
-- index on name would reject the copy. Recreated as per-user further down.
drop index foods_barcode_idx;
drop index foods_name_unique_idx;

-- Every other real user gets a full copy of the catalog, and every one of
-- their own rows that referenced the shared foods/exercises gets repointed to
-- their own copy. Row-by-row (rather than a single INSERT...SELECT...RETURNING)
-- so the old-id -> new-id mapping is unambiguous — this table is small enough
-- in practice (docs/personal_trainer/02-domain-es-migraciok.md notes there is
-- currently effectively one real user) that a loop's performance is a non-issue,
-- and correctness here matters far more than speed: this is the single riskiest
-- migration in the codebase.
do $$
declare
    first_user_id bigint;
    target        record;
    src           record;
    new_food_id   bigint;
    new_exercise_id bigint;
begin
    select id into first_user_id from users
        where lower(email) <> 'legacy@lifey.local' order by id limit 1;

    if first_user_id is null then
        return;
    end if;

    for target in
        select id from users where id <> first_user_id and lower(email) <> 'legacy@lifey.local'
    loop
        create temp table food_id_map (old_id bigint primary key, new_id bigint) on commit drop;
        create temp table exercise_id_map (old_id bigint primary key, new_id bigint) on commit drop;

        for src in select * from foods where user_id = first_user_id loop
            insert into foods (user_id, name, calories_per_100g, protein_per_100g, carbs_per_100g,
                                fat_per_100g, barcode, hidden, updated_at, deleted_at)
            values (target.id, src.name, src.calories_per_100g, src.protein_per_100g, src.carbs_per_100g,
                    src.fat_per_100g, src.barcode, src.hidden, src.updated_at, src.deleted_at)
            returning id into new_food_id;
            insert into food_id_map (old_id, new_id) values (src.id, new_food_id);
        end loop;

        for src in select * from exercises where user_id = first_user_id loop
            insert into exercises (user_id, name, category, equipment, updated_at, deleted_at)
            values (target.id, src.name, src.category, src.equipment, src.updated_at, src.deleted_at)
            returning id into new_exercise_id;
            insert into exercise_id_map (old_id, new_id) values (src.id, new_exercise_id);
        end loop;

        -- Repoint this user's own rows (never another user's) onto their new copies.
        update meal_entries me
            set food_id = m.new_id
            from meals ml, food_id_map m
            where me.meal_id = ml.id and ml.user_id = target.id and me.food_id = m.old_id;

        update recipe_ingredients ri
            set food_id = m.new_id
            from recipes r, food_id_map m
            where ri.recipe_id = r.id and r.user_id = target.id and ri.food_id = m.old_id;

        update workout_template_exercises wte
            set exercise_id = m.new_id
            from workout_templates wt, exercise_id_map m
            where wte.workout_template_id = wt.id and wt.user_id = target.id and wte.exercise_id = m.old_id;

        update workout_session_exercises wse
            set exercise_id = m.new_id
            from workout_sessions ws, exercise_id_map m
            where wse.workout_session_id = ws.id and ws.user_id = target.id and wse.exercise_id = m.old_id;

        update exercise_sets es
            set exercise_id = m.new_id
            from workout_sessions ws, exercise_id_map m
            where es.workout_session_id = ws.id and ws.user_id = target.id and es.exercise_id = m.old_id;

        -- Delta sync (docs/16-delta-sync-rollout.md): bump every parent entity this
        -- user owns whose children may now point at different food/exercise ids, so
        -- the mobile client's next sync pulls the corrected rows instead of drifting.
        update meals set updated_at = now() where user_id = target.id;
        update recipes set updated_at = now() where user_id = target.id;
        update workout_templates set updated_at = now() where user_id = target.id;
        update workout_sessions set updated_at = now() where user_id = target.id;

        drop table food_id_map;
        drop table exercise_id_map;
    end loop;
end $$;

alter table foods alter column user_id set not null;
alter table exercises alter column user_id set not null;
create index foods_user_id_idx on foods (user_id);
create index exercises_user_id_idx on exercises (user_id);

-- Uniqueness moves from catalog-wide to per-user: two different users can now
-- each have their own "Rice" or their own product tagged with the same barcode.
create unique index foods_barcode_idx on foods (user_id, barcode);
create unique index foods_name_unique_idx on foods (user_id, lower(trim(both from name))) where hidden = false;
