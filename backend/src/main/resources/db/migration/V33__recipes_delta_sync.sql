-- Delta-sync support for recipes (see docs/16-delta-sync-rollout.md).
-- Only the parent `recipes` row is tracked; recipe_ingredients are never
-- independently delta-synced (§2.3) — the mobile client replaces all of a
-- recipe's ingredients whenever the recipe itself appears in the delta feed.
-- updated_at is bumped by the entity's @PrePersist/@PreUpdate lifecycle
-- callbacks (Recipe.java) rather than a DB trigger, since every write to
-- this table already goes through JPA. deleted_at is a tombstone replacing
-- the previous hard delete (repository.deleteByIdAndUserId, which relied on
-- ORM cascade to remove recipe_ingredients — soft-deleting the recipe now
-- leaves its ingredients in place, harmless since they're excluded via the
-- recipe's own deleted_at filter everywhere it's queried).
alter table recipes add column updated_at timestamptz not null default now();
alter table recipes add column deleted_at timestamptz;

create index idx_recipes_updated_at on recipes (updated_at, id);
