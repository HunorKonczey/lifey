-- Cardio & sport sessions (docs/cardio/51-cardio-overview-plan.md, D-C.1): a
-- cardio session is the same workout_sessions row as a strength one, told
-- apart by session_kind. Existing rows default to 'STRENGTH', so both the
-- data and any client that doesn't yet send sessionKind keep behaving
-- exactly as before. activity_type is required exactly when the kind is
-- CARDIO — enforced below, not left to application code alone.
alter table workout_sessions add column session_kind varchar(16) not null default 'STRENGTH';
alter table workout_sessions add column activity_type varchar(32);
alter table workout_sessions add column moving_seconds integer;

alter table workout_sessions add constraint workout_sessions_kind_activity_ck
    check ((session_kind = 'STRENGTH' and activity_type is null)
        or (session_kind = 'CARDIO' and activity_type is not null));

create index idx_workout_sessions_user_kind_started
    on workout_sessions (user_id, session_kind, started_at desc)
    where deleted_at is null;
