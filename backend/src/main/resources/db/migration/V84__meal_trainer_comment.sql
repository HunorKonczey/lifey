-- A trainer's comment on one of a client's logged meals (LIF-144), the meal twin of V55's session comment: one
-- editable comment per meal, written only by the trainer endpoint, never by the client-facing meal API. The columns
-- are nullable and existing meals keep them null (no comment).
--
-- trainer_comment_by is a plain fact about who wrote it, not ownership (the owner is user_id), so a deleted trainer
-- account leaves the comment in place and the author null, as with workout_sessions. No new push switch: the existing
-- user_settings.trainer_comment_push_enabled (V56) covers every comment a trainer writes.
alter table meals add column trainer_comment text;
alter table meals add column trainer_comment_at timestamptz;
alter table meals add column trainer_comment_by bigint references users (id) on delete set null;
