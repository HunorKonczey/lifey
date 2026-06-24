-- Optional daily step goal, alongside the other per-user daily goals.

alter table user_settings add column daily_step_goal integer;
