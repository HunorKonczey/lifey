-- Interval training for the indoor bike (docs/cardio/60 §6, D-C7.1): a
-- reusable *plan* ("4×4 perc kemény / 3 perc könnyű") is its own,
-- user-owned entity, while its *execution* is not — that lands in
-- cardio_splits (V68), which already stores exactly this shape (an ordered
-- index + a duration) and only lacked a type and a power column. The
-- summary's split list therefore renders intervals with no change of its own
-- (docs/cardio/61 §3 M39).

-- 1) the reusable plan. Delta-synced like workout_templates
--    (docs/16-delta-sync-rollout.md): updated_at is bumped by the entity's
--    JPA lifecycle callbacks (SyncableEntity), deleted_at is a tombstone.
--    Deleting a plan must never touch the sessions run with it — nothing
--    references this table from the session side, so that holds by
--    construction.
create table cardio_interval_plans (
    id          bigserial primary key,
    user_id     bigint not null references users (id),
    name        varchar(120) not null,
    updated_at  timestamptz not null default now(),
    deleted_at  timestamptz
);

create index cardio_interval_plans_user_idx on cardio_interval_plans (user_id) where deleted_at is null;
create index cardio_interval_plans_updated_at_idx on cardio_interval_plans (updated_at, id);

-- 2) the plan's steps: one flat, ordered list where a row is either a plain
--    STEP (a duration at a target intensity) or a REPEAT block that holds
--    steps of its own (docs/cardio/61 §3 M37 — "4× (4:00 kemény + 3:00
--    könnyű)"). Nesting is exactly one level deep: a REPEAT must be
--    top-level (parent_step_id is null below), so a block can never contain
--    another block.
--
--    Target intensity is a three-step scale (könnyű · közepes · kemény), not
--    a resistance level or a watt target: resistance runs on a different
--    scale on every machine, so a plan carrying it wouldn't be reusable, and
--    most home machines report no watts at all (docs/cardio/61 §7).
create table cardio_interval_steps (
    id               bigserial primary key,
    plan_id          bigint not null references cardio_interval_plans (id) on delete cascade,
    parent_step_id   bigint,                -- null = top level; otherwise the REPEAT block this step sits in
    step_index       integer not null,      -- 0-based among siblings
    step_type        varchar(16) not null,  -- STEP | REPEAT
    name             varchar(60),           -- "Bemelegítés"; optional, the intensity label carries the meaning
    intensity        varchar(16),           -- EASY | MODERATE | HARD — STEP only
    duration_seconds integer,               -- STEP only
    repeat_count     integer,               -- REPEAT only

    -- A child must live in the same plan as its block. Expressible as a
    -- composite FK (hence the id+plan_id unique below) — otherwise a step
    -- could be re-parented into another user's plan and only application
    -- code would notice.
    constraint cardio_interval_steps_id_plan_unique unique (id, plan_id),
    constraint cardio_interval_steps_parent_fk
        foreign key (parent_step_id, plan_id) references cardio_interval_steps (id, plan_id) on delete cascade,

    -- Siblings are ordered, and the order is a position, not a hint: two
    -- steps at the same index inside the same block would make the plan's
    -- playback order arbitrary. `nulls not distinct` so the constraint also
    -- covers the top level, where parent_step_id is null (Postgres 15+).
    constraint cardio_interval_steps_sibling_index_unique
        unique nulls not distinct (plan_id, parent_step_id, step_index),

    constraint cardio_interval_steps_type_ck check (step_type in ('STEP', 'REPEAT')),

    -- The two row shapes, each fully specified: a STEP has a duration and an
    -- intensity and no repeat count; a REPEAT has a count, no duration or
    -- intensity of its own, and sits at the top level (no nested blocks).
    constraint cardio_interval_steps_shape_ck check (
        (step_type = 'STEP'
             and intensity is not null and intensity in ('EASY', 'MODERATE', 'HARD')
             and duration_seconds is not null and duration_seconds > 0
             and repeat_count is null)
        or (step_type = 'REPEAT'
             and intensity is null
             and duration_seconds is null
             and repeat_count is not null and repeat_count between 1 and 99
             and parent_step_id is null))
);

create index cardio_interval_steps_plan_idx on cardio_interval_steps (plan_id);
create index cardio_interval_steps_parent_idx on cardio_interval_steps (parent_step_id) where parent_step_id is not null;

-- 3) the execution side. Every split that exists today is a per-km/lap
--    DISTANCE split, so that's the column default — existing rows migrate
--    themselves and the running split list (C6) keeps behaving exactly as
--    before, down to a client that doesn't send splitType at all.
alter table cardio_splits add column split_type varchar(16) not null default 'DISTANCE';
alter table cardio_splits add column avg_watts double precision;

-- The executed section carries its own intensity rather than pointing back
-- at the plan: the plan is editable and deletable, and a summary that
-- silently changed its section labels when a plan got edited months later
-- would be lying about what was done.
alter table cardio_splits add column intensity varchar(16);

-- An interval section has a duration but not necessarily a distance — most
-- indoor bikes report none. DISTANCE splits stay exactly as strict as they
-- were (checked below), so nothing about the running path loosens here.
alter table cardio_splits alter column distance_meters drop not null;

alter table cardio_splits
    add constraint cardio_splits_type_ck check (split_type in ('DISTANCE', 'INTERVAL')),
    add constraint cardio_splits_distance_required_ck
        check (split_type <> 'DISTANCE' or distance_meters is not null),
    add constraint cardio_splits_intensity_ck
        check (intensity is null
            or (split_type = 'INTERVAL' and intensity in ('EASY', 'MODERATE', 'HARD'))),
    add constraint cardio_splits_avg_watts_nonneg_ck
        check (avg_watts is null or avg_watts >= 0);
