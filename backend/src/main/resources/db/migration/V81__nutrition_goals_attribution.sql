-- Who last changed a user's nutrition goals, and when (docs/redesign-web/82 section 2.4), so the web can say
-- "set by your trainer on Sep 12" instead of hiding the chip (docs/redesign-web/78 section 6).
--
-- The pair moves only when one of the four goals (calories, protein, carbs, fat) actually changes value: the
-- mobile app PUTs its whole settings object on every change, and an unrelated sync must never overwrite
-- "set by your trainer". That rule lives in SettingsServiceImpl, not here.
--
-- Both columns are nullable and existing rows keep them null: null means "unknown", and the web then shows
-- no chip rather than inventing a date. nutrition_goals_set_by is a plain fact about who acted, not ownership
-- (the owner is user_id), and becomes null if that account is deleted while set_at stays: the goals are then
-- reported as set by a trainer with no name.
alter table user_settings
    add column nutrition_goals_set_by bigint references users (id) on delete set null,
    add column nutrition_goals_set_at timestamptz;

create index user_settings_nutrition_goals_set_by_idx on user_settings (nutrition_goals_set_by);
