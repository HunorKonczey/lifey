-- Postgres does not auto-create indexes on foreign-key columns, so the
-- child-row lookups below (load a parent's children) were doing sequential
-- scans. These cover the hot "fetch children of one parent" query paths.
-- Reverse-direction FKs (e.g. *_entries.food_id) are intentionally left
-- unindexed for now; add them only if those lookups/deletes prove slow.

create index meal_entries_meal_id_idx on meal_entries (meal_id);
create index recipe_ingredients_recipe_id_idx on recipe_ingredients (recipe_id);
create index exercise_sets_workout_session_id_idx on exercise_sets (workout_session_id);
create index workout_template_exercises_template_id_idx on workout_template_exercises (workout_template_id);
create index workout_session_exercises_exercise_id_idx on workout_session_exercises (exercise_id);
