-- Delta-sync support for workout templates (see docs/16-delta-sync-rollout.md).
-- Only the parent `workout_templates` row is tracked; workout_template_exercises
-- are never independently delta-synced (§2.3) — the mobile client replaces all
-- of a template's exercise links whenever the template itself appears in the
-- delta feed.
-- updated_at is bumped by the entity's @PrePersist/@PreUpdate lifecycle
-- callbacks (WorkoutTemplate.java) rather than a DB trigger, since every
-- write to this table already goes through JPA. deleted_at is a tombstone
-- replacing the previous hard delete (repository.deleteByIdAndUserId, which
-- relied on ORM cascade to remove workout_template_exercises — soft-deleting
-- the template now leaves those links in place, harmless since they're
-- excluded via the template's own deleted_at filter everywhere it's queried,
-- and existing workout_sessions.template_id references still resolve fine).
alter table workout_templates add column updated_at timestamptz not null default now();
alter table workout_templates add column deleted_at timestamptz;

create index idx_workout_templates_updated_at on workout_templates (updated_at, id);
