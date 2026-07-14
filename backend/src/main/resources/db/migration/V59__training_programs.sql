-- Multi-week program builder (docs/34-multi-week-program-plan.md)

-- 1) reusable blueprint
create table training_programs (
    id          bigserial primary key,
    user_id     bigint not null references users (id),   -- the trainer
    name        varchar(120) not null,
    weeks_count int not null,
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    deleted_at  timestamptz,
    constraint training_programs_weeks check (weeks_count between 1 and 12)
);

create index training_programs_user_idx on training_programs (user_id) where deleted_at is null;

-- 2) week x day -> template slots
create table program_workouts (
    id           bigserial primary key,
    program_id   bigint not null references training_programs (id),
    week_number  int not null,                  -- 1-based, <= weeks_count
    day_of_week  varchar(3) not null,            -- ISO abbreviation, 'MON'..'SUN' (same codes as workout_schedules.days_of_week)
    template_id  bigint not null references workout_templates (id),  -- trainer's own template
    time_of_day  time,
    note         varchar(500),                   -- trainer-facing progression note
    constraint program_workouts_slot_unique unique (program_id, week_number, day_of_week),
    constraint program_workouts_week check (week_number >= 1)
);

create index program_workouts_program_idx on program_workouts (program_id);

-- 3) materialized "this program was started for this client" fact
create table program_assignments (
    id            bigserial primary key,
    program_id    bigint not null references training_programs (id),
    trainer_id    bigint not null references users (id),
    client_id     bigint not null references users (id),
    program_name  varchar(120) not null,         -- snapshot, survives program rename/delete
    start_date    date not null,                 -- always a Monday
    end_date      date not null,                 -- start_date + weeks*7 - 1
    assigned_at   timestamptz not null default now(),
    cancelled_at  timestamptz,
    constraint program_assignments_date_order check (end_date >= start_date)
);

create index program_assignments_trainer_idx on program_assignments (trainer_id, client_id);
create index program_assignments_client_idx on program_assignments (client_id) where cancelled_at is null;

-- 4) session extension: which program assignment (if any) generated this occurrence
alter table workout_sessions add column program_assignment_id bigint references program_assignments (id);

create index workout_sessions_program_idx
    on workout_sessions (program_assignment_id)
    where program_assignment_id is not null;
