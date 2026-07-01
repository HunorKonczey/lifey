-- Delta-sync support for meals (see docs/16-delta-sync-rollout.md).
-- Only the parent `meals` row is tracked; meal_entries are never
-- independently delta-synced (§2.3) — the mobile client replaces all of a
-- meal's entries whenever the meal itself appears in the delta feed.
-- updated_at is bumped by the entity's @PrePersist/@PreUpdate lifecycle
-- callbacks (Meal.java) rather than a DB trigger, since every write to this
-- table already goes through JPA. deleted_at is a tombstone replacing the
-- previous hard delete (repository.deleteByIdAndUserId, which relied on ORM
-- cascade to remove meal_entries — soft-deleting the meal now leaves its
-- entries in place, harmless since they're excluded via the meal's own
-- deleted_at filter everywhere they're queried).
alter table meals add column updated_at timestamptz not null default now();
alter table meals add column deleted_at timestamptz;

create index idx_meals_updated_at on meals (updated_at, id);
