-- How many sets a session plans for each of its exercises — the count the
-- mobile client renders as "done + still blank" set rows.
--
-- Until now this only ever existed in the client's local cache: the session
-- payload sent bare exerciseIds, so every server round-trip dropped it and the
-- planned-but-not-yet-logged rows disappeared from a session the moment it was
-- pulled back. Mirrors workout_template_exercises.target_sets (V19), including
-- being nullable: "no plan" is a real state (an exercise added ad hoc), and
-- every session written before this column existed has exactly that.
alter table workout_session_exercises add column target_sets integer;
