-- The service's existsBy pre-check is racy across concurrent requests; since
-- unassign hard-deletes the fact row, this tuple is a true invariant. A lost
-- race becomes a constraint violation that rolls back the losing batch.
create unique index content_assignments_unique_idx
    on content_assignments (trainer_id, client_id, content_type, source_id);
