-- Per-km/lap splits for a DISTANCE-family cardio session (docs/cardio/52
-- §2.3, docs/cardio/51 §3.2). Computed client-side at close time from the
-- filtered GPS track and synced as a plain replace-the-whole-list — the
-- server never sees raw GPS points in the first place (docs/cardio/52
-- D-C1.2), so there is nothing server-side to derive these from.
create table cardio_splits (
    id                    bigserial primary key,
    workout_session_id    bigint not null references workout_sessions (id) on delete cascade,
    split_index           integer not null,           -- 0-based
    distance_meters       double precision not null,  -- usually 1000 (one km)
    duration_seconds      integer not null,
    elevation_delta_m     double precision,
    avg_heart_rate        double precision,

    constraint cardio_splits_session_index_unique unique (workout_session_id, split_index)
);

create index cardio_splits_session_idx on cardio_splits (workout_session_id);
