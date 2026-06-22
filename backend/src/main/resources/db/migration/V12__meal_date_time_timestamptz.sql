-- meals.date_time was stored as a naive timestamp, populated from the
-- mobile client's local wall-clock time with no zone info. The backend
-- compared it against the server's own clock (UTC on Railway) for the
-- @PastOrPresent check, so any user ahead of UTC got spurious 400s.
-- Existing rows have no recoverable zone, so they're reinterpreted as UTC;
-- new rows go through Instant end-to-end (mobile sends UTC ISO-8601).
alter table meals alter column date_time type timestamp with time zone using date_time at time zone 'UTC';
