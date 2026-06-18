-- Track the exact instant a weight entry was recorded, so that multiple
-- entries on the same day have a deterministic, time-aware order (newest first).
-- Previously rows only carried a date, leaving same-day entries unordered.

alter table weight_entries
    add column recorded_at timestamp with time zone;

-- Backfill existing rows from their date (midnight); new rows are stamped by the app.
update weight_entries
    set recorded_at = entry_date
    where recorded_at is null;

alter table weight_entries
    alter column recorded_at set not null;
