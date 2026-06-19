-- Ownership: every personally-tracked record (recipes, meals, workout templates,
-- workout sessions, weight entries) belongs to exactly one user, resolved from the
-- JWT on every request, never accepted as request input (see docs/09-auth-module.md).
--
-- Foods and exercises are deliberately NOT included here: they stay shared
-- reference catalogs (like a public food/exercise database), visible to every
-- authenticated user rather than owned by one.

-- Bootstrap a placeholder owner for any data that predates accounts existing
-- (rows created while the app had no auth at all). Nobody can log into this
-- account: its password hash is the same unusable placeholder V5 used.
insert into users (email, password_hash, created_at)
    select 'legacy@lifey.local', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', now()
    where not exists (select 1 from users where lower(email) = 'legacy@lifey.local');

insert into user_roles (user_id, role)
    select id, 'ROLE_USER' from users where lower(email) = 'legacy@lifey.local'
    on conflict do nothing;

alter table recipes add column user_id bigint references users (id);
alter table meals add column user_id bigint references users (id);
alter table workout_templates add column user_id bigint references users (id);
alter table workout_sessions add column user_id bigint references users (id);
alter table weight_entries add column user_id bigint references users (id);

update recipes set user_id = (select id from users where lower(email) = 'legacy@lifey.local') where user_id is null;
update meals set user_id = (select id from users where lower(email) = 'legacy@lifey.local') where user_id is null;
update workout_templates set user_id = (select id from users where lower(email) = 'legacy@lifey.local') where user_id is null;
update workout_sessions set user_id = (select id from users where lower(email) = 'legacy@lifey.local') where user_id is null;
update weight_entries set user_id = (select id from users where lower(email) = 'legacy@lifey.local') where user_id is null;

alter table recipes alter column user_id set not null;
alter table meals alter column user_id set not null;
alter table workout_templates alter column user_id set not null;
alter table workout_sessions alter column user_id set not null;
alter table weight_entries alter column user_id set not null;

create index recipes_user_id_idx on recipes (user_id);
create index meals_user_id_idx on meals (user_id);
create index workout_templates_user_id_idx on workout_templates (user_id);
create index workout_sessions_user_id_idx on workout_sessions (user_id);
create index weight_entries_user_id_idx on weight_entries (user_id);
