-- Per-user opt-out for the trainer-comment push notification
-- (docs/31-session-feedback-loop-plan.md, B3b). Default true: the trainer
-- relationship is something the client accepted, and the OS notification
-- permission prompt is the real consent gate.
alter table user_settings add column trainer_comment_push_enabled boolean not null default true;
