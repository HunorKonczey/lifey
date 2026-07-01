-- Delta-sync support for water entries (see docs/16-delta-sync-rollout.md).
-- updated_at is bumped by the entity's @PrePersist/@PreUpdate lifecycle
-- callbacks (WaterEntry.java) rather than a DB trigger, since every write to
-- this table already goes through JPA. deleted_at is a tombstone replacing
-- the previous hard delete (repository.deleteByIdAndUserId).
alter table water_entries add column updated_at timestamptz not null default now();
alter table water_entries add column deleted_at timestamptz;

create index idx_water_entries_updated_at on water_entries (updated_at, id);
