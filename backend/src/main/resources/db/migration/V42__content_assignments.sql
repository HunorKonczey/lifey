-- Trainer content assignment (docs/personal_trainer/02-domain-es-migraciok.md,
-- "Változás 3"). A trainer assigns their own workout template or recipe to a
-- client by deep-copying it (and everything it references) into the client's
-- account — foods/exercises are already user-owned since V40, so this is the
-- second half of that: templates/recipes get the same provenance columns
-- (foods/exercises got theirs in V40 already) so a client's copy can be traced
-- back to the trainer's original and deduplicated on re-assignment.

alter table recipes add column origin_source_id bigint;
alter table recipes add column origin_trainer_id bigint references users (id);
alter table workout_templates add column origin_source_id bigint;
alter table workout_templates add column origin_trainer_id bigint references users (id);

-- The fact log of what was assigned to whom — origin_source_id above is what a
-- copy's own row carries; source_id/copied_id here are what one particular
-- assignment action did (a trainer's "kiosztott tervek" view, and the signal
-- for "you already assigned this" on re-assignment).
create table content_assignments (
    id           bigserial primary key,
    trainer_id   bigint not null references users (id),
    client_id    bigint not null references users (id),
    content_type varchar(16) not null,   -- TEMPLATE | RECIPE
    source_id    bigint not null,        -- the trainer's original's id
    copied_id    bigint not null,        -- the id of the copy created in the client's account
    assigned_at  timestamptz not null default now()
);

create index content_assignments_trainer_idx on content_assignments (trainer_id, client_id);
