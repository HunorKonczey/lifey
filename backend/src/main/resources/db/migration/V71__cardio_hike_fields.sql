-- Hike-specific fields for a DISTANCE-family cardio session (docs/cardio/60
-- §7 C8.1, docs/cardio/61 §4 M42): a backpack weight, the grade-adjusted
-- pace, a manual weather snapshot, and waypoints along the route.

-- Backpack weight and GAP land on cardio_details next to the other
-- family-specific columns (V67) — same 1:1 table, same reasoning: the
-- queries that touch it don't want to branch by family, and a nullable
-- column costs nothing on Postgres.
alter table cardio_details
    -- The one field only the user can know (docs/cardio/61 §4 M42) —
    -- refines the calorie estimate, but is never itself measured.
    add column backpack_weight_kg double precision,

    -- Grade-adjusted pace, computed client-side from the filtered GPS track
    -- at close time (docs/cardio/56-cardio-statistics-plan.md, the formula
    -- lives in features/workouts/domain/grade_adjusted_pace.dart) — same
    -- "computed once, synced as a plain value" treatment as the best-effort
    -- columns (V69), not the "derive it every read" treatment total work
    -- (docs/cardio/60 C7.6) gets: GAP needs the whole elevation profile, not
    -- two numbers already sitting on the row.
    add column avg_gap_seconds_per_km double precision,

    -- Weather (docs/cardio/60 Q-C8.1, decided 2026-08-19): manual entry, no
    -- external API — the same "kézzel szerkeszthető mező" pattern as
    -- backpack_weight_kg and device_calories above, not a timestamped
    -- capture-at-start snapshot. weather_condition is a free code (e.g.
    -- CLEAR, PARTLY_CLOUDY, CLOUDY, RAIN, SNOW, WINDY) the client maps to an
    -- icon — left unconstrained here, same precedent as game_format/
    -- distance_source: it drives display only, nothing downstream branches
    -- on it the way venue's CHECK-enforced value does.
    add column weather_temp_c double precision,
    add column weather_wind_kph double precision,
    add column weather_precip_mm double precision,
    add column weather_condition varchar(16),

    add constraint cardio_details_backpack_weight_nonneg_ck
        check (backpack_weight_kg is null or backpack_weight_kg >= 0),
    add constraint cardio_details_gap_nonneg_ck
        check (avg_gap_seconds_per_km is null or avg_gap_seconds_per_km >= 0),
    add constraint cardio_details_weather_wind_nonneg_ck
        check (weather_wind_kph is null or weather_wind_kph >= 0),
    add constraint cardio_details_weather_precip_nonneg_ck
        check (weather_precip_mm is null or weather_precip_mm >= 0);

-- Waypoints marked along a hike's route (docs/cardio/61 §4 M41). Position +
-- altitude only, no distance/elapsed-time columns: those are derived
-- client-side by matching the waypoint against the session's own local
-- track points, the same source the elevation profile (C8.3) reads from —
-- adding a second, server-stored copy of numbers the client already owns
-- would just be another place for them to disagree.
--
-- Same privacy tier as the route polyline (V54/route_polyline on
-- cardio_details, docs/cardio/54-cardio-gps-route-plan.md): a marked point
-- is a deliberate, coarse position the user chose to keep, not part of the
-- raw GPS track, which never leaves the phone (docs/cardio/52 D-C1.2).
create table cardio_waypoints (
    id                  bigserial primary key,
    workout_session_id  bigint not null references workout_sessions (id) on delete cascade,
    waypoint_index      integer not null,          -- 0-based, in the order they were marked
    latitude            double precision not null,
    longitude           double precision not null,
    altitude_meters     double precision,           -- null when the fix carried no altitude
    label               varchar(120),                -- always null in V1 (Q-D5); the column exists for the V2 rename feature

    constraint cardio_waypoints_session_index_unique unique (workout_session_id, waypoint_index)
);

create index cardio_waypoints_session_idx on cardio_waypoints (workout_session_id);
