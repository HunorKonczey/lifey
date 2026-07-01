-- Delta-sync support for daily step counts (see docs/16-delta-sync-rollout.md).
-- updated_at is bumped by the entity's @PrePersist/@PreUpdate lifecycle
-- callbacks (DailyStepCount.java) rather than a DB trigger, since every write
-- to this table already goes through JPA. deleted_at is a tombstone
-- replacing the previous hard delete (repository.deleteByIdAndUserId).
alter table daily_step_counts add column updated_at timestamptz not null default now();
alter table daily_step_counts add column deleted_at timestamptz;

create index idx_daily_step_counts_updated_at on daily_step_counts (updated_at, id);
