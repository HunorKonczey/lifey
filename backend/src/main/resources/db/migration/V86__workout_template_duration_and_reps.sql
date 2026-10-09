-- What a trainer says about a workout template beyond its set counts (LIF-106): how long the session takes, and how many
-- repetitions each exercise asks for. Both are optional, and null means "not said" - until now the duration was only
-- ever estimated (8 minutes an exercise) and the repetitions lived nowhere.
--
-- The phone does not know these columns and its template PUT does not send them, so the service treats an absent value
-- as "keep what is stored" rather than "clear it" (a zero clears); see WorkoutTemplateServiceImpl. Existing templates
-- keep null, which every reader already handles.
alter table workout_templates add column duration_minutes integer;
alter table workout_template_exercises add column target_reps integer;
