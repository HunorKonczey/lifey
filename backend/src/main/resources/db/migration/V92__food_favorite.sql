-- LIF-147: a favourite mark on a food, like the one a recipe has had since V13. Not null with a false default, so every
-- existing food is simply "not a favourite" and the delta-sync feed needs no backfill.
alter table foods add column favorite boolean not null default false;
