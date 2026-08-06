-- Chat notification preferences (docs/chat/40-trainer-chat-plan.md §3.2).
-- The columns land in I1 together with the rest of the chat schema; the push
-- pipeline that reads chat_push_enabled arrives in I2 and the quiet-hours
-- window in I5.
alter table user_settings
    add column chat_push_enabled boolean not null default true;
alter table user_settings
    add column chat_quiet_hours_start time;
alter table user_settings
    add column chat_quiet_hours_end time;
