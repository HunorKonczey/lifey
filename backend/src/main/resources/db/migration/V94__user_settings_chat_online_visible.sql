-- LIF-153 (docs/chat/40-trainer-chat-plan.md section 23): whether the people a user shares a chat thread with may see that
-- the user is online. On by default, like the other chat switches; the chat service reads it (read-only on user_settings).
alter table user_settings add column chat_online_visible boolean not null default true;
