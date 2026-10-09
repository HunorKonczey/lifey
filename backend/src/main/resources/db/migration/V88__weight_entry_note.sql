-- LIF-115: an optional free-text note on a weigh-in ("after a run", "fasted"), at most 280 characters (bounded in the
-- API; the column matches). recorded_at already exists (V1) and was server-stamped only; it is now also accepted from
-- the client, so a weigh-in logged offline keeps the time it was taken rather than the time it synced.
alter table weight_entries add column note varchar(280);
