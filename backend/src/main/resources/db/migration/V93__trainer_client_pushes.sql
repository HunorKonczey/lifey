-- LIF-100 (docs/85-trainer-push-plan.md): pushes to the trainer about a client.
alter table user_settings add column client_missed_workout_push_enabled boolean not null default true;
alter table user_settings add column client_weigh_in_push_enabled boolean not null default true;

-- Set when a missed trainer-scheduled occurrence was announced to the trainer (or the trainer had the push switched off), so it is never announced twice.
alter table workout_sessions add column missed_notified_at timestamptz;
