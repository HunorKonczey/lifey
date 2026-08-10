-- Cardio metrics for a CARDIO-kind workout_sessions row (docs/cardio/52
-- §2.2, docs/cardio/51 D-C.2 hybrid storage): a few common columns live on
-- workout_sessions itself (V66), everything family-specific lives here in a
-- single 1:1 table rather than one table per family — the queries that touch
-- it (session detail, statistics) don't want to branch by family, and the
-- nullable columns cost nothing on Postgres.
--
-- One row per cardio session. Never independently delta-synced (docs/cardio/52
-- §4) — a write here must bump the parent workout_sessions.updated_at, same
-- as exercise_sets/workout_session_exercises already have to.
create table cardio_details (
    id                     bigserial primary key,
    workout_session_id     bigint not null unique references workout_sessions (id) on delete cascade,

    -- DISTANCE + MACHINE
    distance_meters        double precision,
    elevation_gain_meters  double precision,
    elevation_loss_meters  double precision,
    max_altitude_meters    double precision,
    steps                  integer,
    avg_cadence            double precision,  -- steps/min (running) or rpm (indoor bike)
    max_cadence            double precision,

    -- MACHINE
    avg_watts               double precision,
    max_watts                double precision,
    resistance_level        integer,
    device_calories          double precision,  -- the machine's own display, docs/cardio/51 Q4 — never auto-summed

    -- shared physiological
    max_heart_rate           double precision,
    hr_zone1_seconds         integer,
    hr_zone2_seconds         integer,
    hr_zone3_seconds         integer,
    hr_zone4_seconds         integer,
    hr_zone5_seconds         integer,

    -- GAME
    intensity                smallint,      -- 1..5, subjective
    venue                    varchar(16),   -- INDOOR | OUTDOOR — drives GPS + watch locationType
    game_format              varchar(32),   -- free-text code: 5V5, SMALL_SIDED, PRACTICE, ...
    score_points             integer,       -- basketball: points · football: goals
    score_assists            integer,
    score_rebounds           integer,

    -- provenance (docs/cardio/51 R8: a manual override always wins over a measured value)
    distance_source           varchar(16),  -- MEASURED | MANUAL | DEVICE
    calories_source           varchar(16),

    -- route (docs/cardio/54) — an encoded, simplified polyline; raw GPS points never leave the phone
    route_polyline             text,
    route_point_count          integer,

    constraint cardio_details_intensity_ck check (intensity is null or intensity between 1 and 5),
    constraint cardio_details_venue_ck check (venue is null or venue in ('INDOOR', 'OUTDOOR'))
);
