-- Best-effort sub-distances for a running session (docs/cardio/60 C6.1,
-- docs/cardio/56 D-C3.8): the fastest continuous 1/5/10 km inside the
-- session, NOT the average pace extrapolated over those distances.
--
-- Computed client-side from the filtered GPS track at close time, same as
-- cardio_splits (V68) — the server never sees raw GPS points (docs/cardio/52
-- D-C1.2), so there is nothing here to derive server-side. Nullable: a
-- treadmill run, a walk, or a run shorter than the window leaves them null
-- (null, never 0 — 0 would read as an impossibly fast record).
alter table cardio_details
    add column best_1k_seconds  integer,
    add column best_5k_seconds  integer,
    add column best_10k_seconds integer;

alter table cardio_details
    add constraint cardio_details_best_efforts_nonneg_ck
        check ((best_1k_seconds is null or best_1k_seconds >= 0)
           and (best_5k_seconds is null or best_5k_seconds >= 0)
           and (best_10k_seconds is null or best_10k_seconds >= 0)),

    -- These are absolute durations of a longer and longer stretch, so a
    -- shorter distance can never take more time than a longer one that
    -- contains it. A violation means the sliding window was computed wrong
    -- (e.g. it ran across a GPS gap, docs/cardio/60 §9) — and a bad
    -- best-effort value is silent: it lands in the PR list and stays there.
    -- Each pair is checked separately so a missing middle value (5k null,
    -- 1k + 10k present) is still constrained.
    add constraint cardio_details_best_efforts_monotonic_ck
        check ((best_1k_seconds is null or best_5k_seconds is null or best_1k_seconds <= best_5k_seconds)
           and (best_5k_seconds is null or best_10k_seconds is null or best_5k_seconds <= best_10k_seconds)
           and (best_1k_seconds is null or best_10k_seconds is null or best_1k_seconds <= best_10k_seconds));
