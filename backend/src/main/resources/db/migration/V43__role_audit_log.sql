-- Role-change audit log (docs/personal_trainer/02-domain-es-migraciok.md,
-- "Változás 4"). Roles themselves already live in the existing `user_roles`
-- collection table (V5__auth.sql) — this table only records the fact of each
-- change (who did it, to whom, what, when) for the super-admin's audit view.
-- Append-only: there is no update/delete path for this table in the code.
--
-- No ROLE_SUPER_ADMIN seed here on purpose — that grant is a one-off, manual,
-- environment-specific SQL statement run by whoever owns the deployment (see
-- RoleManagementServiceImpl's Javadoc), not something a repeatable migration
-- should hardcode an email address into.
create table role_audit_log (
    id             bigserial primary key,
    actor_id       bigint not null references users (id),  -- the super admin who made the change
    target_user_id bigint not null references users (id),  -- whose roles changed
    role           varchar(32) not null,                    -- e.g. ROLE_TRAINER
    action         varchar(8)  not null,                    -- GRANT | REVOKE
    created_at     timestamptz not null default now()
);

create index role_audit_log_target_idx on role_audit_log (target_user_id);
