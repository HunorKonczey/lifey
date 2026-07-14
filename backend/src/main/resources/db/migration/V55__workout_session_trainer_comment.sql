-- Session feedback loop (docs/31-session-feedback-loop-plan.md, B1): one
-- editable trainer comment per session, answering the client's rpe/feedback_note.
-- Written only by the trainer endpoint, never by the client-facing session API.
alter table workout_sessions add column trainer_comment text;
alter table workout_sessions add column trainer_comment_at timestamptz;
alter table workout_sessions add column trainer_comment_by bigint references users(id);
