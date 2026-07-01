-- Delta-sync support for the exercise master list (see docs/16-delta-sync-rollout.md).
-- Like foods, exercises are a shared/global catalog (no user_id) — the delta
-- feed is not user-scoped, matching FoodRepository.findByUpdatedAtGreaterThanEqual.
-- updated_at is bumped by the entity's @PrePersist/@PreUpdate lifecycle
-- callbacks (Exercise.java) rather than a DB trigger, since every write to
-- this table already goes through JPA. deleted_at is a tombstone replacing
-- the previous hard delete (repository.deleteById), which also fixes a
-- pre-existing gap: deleting an exercise still referenced by
-- workout_template_exercises/workout_session_exercises used to throw a DB
-- constraint violation; soft delete leaves the row in place.
alter table exercises add column updated_at timestamptz not null default now();
alter table exercises add column deleted_at timestamptz;

create index idx_exercises_updated_at on exercises (updated_at, id);
