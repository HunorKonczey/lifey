-- Each set now carries the instant it was logged, used to compute rest time
-- between consecutive sets. Existing rows have no recoverable timestamp, so
-- they're backfilled from their session's started_at.
alter table exercise_sets add column performed_at timestamp with time zone;

update exercise_sets es
set performed_at = ws.started_at
from workout_sessions ws
where es.workout_session_id = ws.id;

alter table exercise_sets alter column performed_at set not null;
