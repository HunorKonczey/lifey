-- Delta-sync support for workout sessions (see docs/16-delta-sync-rollout.md).
-- Only the parent `workout_sessions` row is tracked; workout_session_exercises
-- and exercise_sets are never independently delta-synced (§2.3) — the mobile
-- client replaces all of a session's children whenever the session itself
-- appears in the delta feed.
-- updated_at is bumped by the entity's @PrePersist/@PreUpdate lifecycle
-- callbacks (WorkoutSession.java) rather than a DB trigger, since every write
-- to this table already goes through JPA. deleted_at is a tombstone
-- replacing the previous hard delete (repository.deleteByIdAndUserId, which
-- relied on ORM cascade to remove both child tables — soft-deleting the
-- session now leaves its children in place, harmless since they're excluded
-- via the session's own deleted_at filter everywhere it's queried).
alter table workout_sessions add column updated_at timestamptz not null default now();
alter table workout_sessions add column deleted_at timestamptz;

create index idx_workout_sessions_updated_at on workout_sessions (updated_at, id);
