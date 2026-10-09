-- LIF-149: a place for work that must run exactly once per database, however many instances or restarts it takes - the
-- first user is the backfill of fibre and sugar for the foods saved before V89 (LIF-145).
--
-- A row per job. The job claims it with a lease (claimed_until), so two instances never run it at once and a crashed run
-- is picked up again once the lease expires; cursor_id makes it resumable (the work goes through foods by id); completed_at
-- is what stops it for good. The row is inserted here, not by the job, so the first deploy needs no "does it exist yet?"
-- race - and a fresh database just finds nothing to do and completes.
create table one_time_jobs (
    name            varchar(100) primary key,
    cursor_id       bigint      not null default 0,
    claimed_until   timestamptz,
    completed_at    timestamptz,
    processed_count integer     not null default 0,
    filled_count    integer     not null default 0
);

insert into one_time_jobs (name) values ('food-fiber-sugar-backfill');
