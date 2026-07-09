-- Post-workout feedback: difficulty rating (RPE, 1-10) and an optional note,
-- captured after finishing a session. Both nullable; existing sessions were
-- logged before this feature and stay unrated.
alter table workout_sessions add column rpe integer;
alter table workout_sessions add column feedback_note text;
alter table workout_sessions add constraint workout_sessions_rpe_range
    check (rpe is null or (rpe >= 1 and rpe <= 10));
