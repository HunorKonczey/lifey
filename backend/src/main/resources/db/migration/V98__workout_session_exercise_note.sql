-- A free-text comment per exercise per session (LIF-224) — e.g. "seat on 4",
-- "next time +2.5 kg". Lives on the session's exercise link, not on the
-- exercise itself: the mobile client starts the next session's note from a
-- copy of the previous one, so editing it never rewrites an older session.
--
-- Nullable: no comment is the normal state, and every row written before
-- this column existed has none. 1000 characters matches
-- PlannedExerciseRequest.MAX_NOTE_LENGTH.
alter table workout_session_exercises add column note varchar(1000);
