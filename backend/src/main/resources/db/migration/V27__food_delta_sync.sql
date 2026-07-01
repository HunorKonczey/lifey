-- Delta-sync support for the foods catalog (see docs/15-delta-sync.md).
-- updated_at is bumped by the entity's @PrePersist/@PreUpdate lifecycle
-- callbacks (Food.java) rather than a DB trigger, since every write to this
-- table already goes through JPA — no raw-SQL/batch path bypasses it.
-- deleted_at is a single-purpose tombstone, kept separate from the existing
-- `hidden` flag (which is dual-purpose: it also marks quick-macro shadow
-- foods that were never deleted, just never meant to appear in pickers).
alter table foods add column updated_at timestamptz not null default now();
alter table foods add column deleted_at timestamptz;

create index idx_foods_updated_at on foods (updated_at, id);
