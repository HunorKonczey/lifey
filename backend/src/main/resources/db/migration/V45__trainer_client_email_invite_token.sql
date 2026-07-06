-- Optional email-based accept/decline channel for trainer invites
-- (docs/personal_trainer/01-koncepcio-es-folyamatok.md). Only populated while
-- lifey.trainer-invite.email-enabled is on; holds a SHA-256 hash of the opaque
-- token embedded in the invite email's links, never the raw token itself.
alter table trainer_clients add column email_token_hash varchar(64);

create unique index trainer_clients_email_token_hash_uq
    on trainer_clients (email_token_hash)
    where email_token_hash is not null;
