-- Apple Health import fields for workout sessions. All nullable; existing
-- sessions were not imported from Apple Health, so they stay null.
alter table workout_sessions add column active_calories double precision;
alter table workout_sessions add column average_heart_rate double precision;
alter table workout_sessions add column health_workout_id varchar(255);
