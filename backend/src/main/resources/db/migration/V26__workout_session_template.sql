-- Links a logged workout session back to the template it was started from
-- (nullable — a session can be started "empty", with no template). The name
-- is snapshotted at creation time so a session still shows what it was
-- called even if the template is later renamed or deleted.
alter table workout_sessions add column template_id bigint references workout_templates(id) on delete set null;
alter table workout_sessions add column template_name varchar(255);

create index workout_sessions_template_id_idx on workout_sessions (template_id);
