-- 1) schedule (recurrence) definition
create table workout_schedules (
    id                  bigserial primary key,
    trainer_id          bigint not null references users (id),
    client_id           bigint not null references users (id),
    source_template_id  bigint not null,             -- the trainer's template; deliberately not an FK (soft-deletable)
    client_template_id  bigint not null references workout_templates (id), -- the client's copy occurrences start from
    recurrence          varchar(8) not null,          -- ONCE | DAILY | WEEKLY
    days_of_week        varchar(32),                  -- WEEKLY: e.g. 'MON,THU' (ISO abbreviations, comma-separated)
    time_of_day         time,                          -- optional wall-clock time, inherited by every occurrence
    start_date          date not null,
    end_date            date not null,                 -- ONCE: = start_date; <= start_date + 3 months
    created_at          timestamptz not null default now(),
    cancelled_at        timestamptz,
    constraint workout_schedules_date_order check (end_date >= start_date)
);

create index workout_schedules_trainer_idx on workout_schedules (trainer_id, client_id);
create index workout_schedules_client_idx  on workout_schedules (client_id) where cancelled_at is null;

-- 2) session extension: upcoming (scheduled) sessions
alter table workout_sessions alter column started_at drop not null;
alter table workout_sessions add column scheduled_for date;
alter table workout_sessions add column scheduled_time time;   -- copy of the schedule's time_of_day (denormalized: the session is self-contained)
alter table workout_sessions add column schedule_id bigint references workout_schedules (id);

-- a session is either something that happened, or something scheduled (or an already-started scheduled one)
alter table workout_sessions add constraint workout_sessions_started_or_scheduled
    check (started_at is not null or scheduled_for is not null);

create index workout_sessions_upcoming_idx
    on workout_sessions (user_id, scheduled_for)
    where started_at is null and deleted_at is null;
