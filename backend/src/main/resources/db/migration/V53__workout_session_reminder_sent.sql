-- Marks when the trainer-scheduled-workout push reminder was sent for an
-- occurrence (docs/30-push-notifications-plan.md, B3), so the reminder job
-- never sends twice. Null means "not sent yet" for every existing row.
alter table workout_sessions add column reminder_sent_at timestamp with time zone;
