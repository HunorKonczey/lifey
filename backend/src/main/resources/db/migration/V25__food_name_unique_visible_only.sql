-- The unique index on food names was created before the hidden column existed.
-- Hidden foods are macro-entry shadows: they are never shown in pickers, so two
-- hidden foods with the same name must be allowed (e.g. logging "kaja" twice as
-- a quick macro). Only visible foods need the uniqueness guarantee.
DROP INDEX foods_name_unique_idx;
CREATE UNIQUE INDEX foods_name_unique_idx ON foods (lower(trim(both from name))) WHERE hidden = false;
