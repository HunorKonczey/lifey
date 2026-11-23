-- Provenance of an imported workout session (docs/integrations/89 D-G2,
-- D-G3). A run recorded on a Garmin (through Garmin Connect), on an Apple
-- Watch by another app, and so on, is imported from Apple Health / Health
-- Connect as an ordinary CARDIO session. These two columns say where it
-- came from:
--   import_source    HEALTH (from the phone's health store, M1) or GARMIN
--                    (the direct Garmin API, M4). Null means the session was
--                    recorded in Lifey itself, which covers every row that
--                    exists before this migration.
--   import_app_name  the store's source name, e.g. 'Garmin Connect'. Display
--                    only.
alter table workout_sessions
    add column import_source   varchar(16),
    add column import_app_name varchar(64);

alter table workout_sessions
    add constraint workout_sessions_import_source_ck
        check (import_source in ('HEALTH', 'GARMIN')),
    add constraint workout_sessions_import_app_name_ck
        check (import_app_name is null or import_source is not null);

-- Dedupe key for imports: one session per health-store record per user.
-- The index is partial on import_source, not only on health_workout_id,
-- because health_workout_id already marks a Lifey-recorded session *paired*
-- with a store workout (V15). Those rows are not imports, and a user can
-- delete a paired session and pair a new one with the same store workout.
-- Soft-deleted imports stay in the index on purpose, so a deleted import is
-- never imported again (D-G3).
create unique index workout_sessions_user_id_health_workout_id_unique
    on workout_sessions (user_id, health_workout_id)
    where import_source is not null and health_workout_id is not null;
