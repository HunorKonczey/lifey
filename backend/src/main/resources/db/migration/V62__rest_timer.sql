alter table user_settings add column rest_timer_enabled boolean not null default true;
alter table user_settings add column default_rest_seconds integer not null default 90;
alter table exercises add column default_rest_seconds integer;
