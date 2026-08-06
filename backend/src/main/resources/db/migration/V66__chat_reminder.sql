-- I5 (docs/chat/40-trainer-chat-plan.md §5.4): the "still not read" reminder.
--
-- The cap is per user, not per thread ("one reminder a day"), but there is no
-- per-user chat row to hang it on — so the timestamp is written to every one of
-- the user's participant rows when a reminder goes out, and the job reads the
-- newest of them. That keeps the state inside the chat domain instead of
-- widening user_settings, which holds preferences rather than delivery state.
alter table chat_participants add column last_reminded_at timestamptz;

-- The job scans for participants whose unread messages have aged past the
-- threshold; without this it would be a sequential scan over every row on every
-- five-minute tick.
create index if not exists idx_chat_participant_reminder
    on chat_participants (last_reminded_at);
