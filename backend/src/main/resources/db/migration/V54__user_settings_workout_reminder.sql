-- Per-user opt-out for the trainer-scheduled-workout push reminder
-- (docs/30-push-notifications-plan.md, B3b). Default true: a trainer-scheduled
-- workout is something the client signed up for, and the OS notification
-- permission prompt is the real consent gate.
alter table user_settings add column workout_reminder_enabled boolean not null default true;
