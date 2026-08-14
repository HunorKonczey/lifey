package com.lifey.workout.session;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface WorkoutSessionRepository extends JpaRepository<WorkoutSession, Long> {

    /**
     * History view — excludes upcoming/missed (trainer-scheduled, not-yet-started)
     * rows: "happened" means {@code startedAt} is set (docs/personal_trainer/
     * 09-utemezett-edzesek-domain-backend.md, "Elvégzett = started_at not null").
     */
    List<WorkoutSession> findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullOrderByStartedAtDesc(Long userId);

    /**
     * Same as {@link #findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullOrderByStartedAtDesc},
     * additionally scoped to one {@link SessionKind} — backs the `?kind=`
     * list filter (docs/cardio/52-cardio-domain-backend-plan.md §3.2 D-C1.3).
     * A separate method rather than a nullable-parameter query so the
     * unfiltered path (and its existing callers/tests) stays untouched.
     */
    List<WorkoutSession> findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullAndSessionKindOrderByStartedAtDesc(
            Long userId, SessionKind kind);

    /**
     * Paged history view — backs `GET /workout-sessions?page=` and the trainer
     * client-workout-sessions endpoint. Excludes upcoming/missed rows, same as
     * {@link #findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullOrderByStartedAtDesc}.
     */
    Page<WorkoutSession> findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNull(Long userId, Pageable pageable);

    /** Same as above, additionally scoped to one {@link SessionKind} — see the unpaged variant's doc. */
    Page<WorkoutSession> findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullAndSessionKind(
            Long userId, SessionKind kind, Pageable pageable);

    Optional<WorkoutSession> findByIdAndUserId(Long id, Long userId);

    /** Same as {@link #findByIdAndUserId}, additionally excluding soft-deleted rows — used by the trainer comment endpoint. */
    Optional<WorkoutSession> findByIdAndUserIdAndDeletedAtIsNull(Long id, Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<WorkoutSession> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);

    long countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(Long userId, Instant from);

    /**
     * Same as {@link #countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual},
     * scoped to one {@link SessionKind} — the statistics fajta-bontás
     * (docs/cardio/56-cardio-statistics-plan.md §2, D-C3.2). Only the CARDIO
     * count is queried; strengthWorkoutCount is derived as
     * {@code workoutCount - cardioWorkoutCount} in the service, since every
     * session has exactly one of the two {@link SessionKind} values.
     */
    long countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndSessionKind(
            Long userId, Instant from, SessionKind kind);

    /**
     * Σ moving_seconds over the same "since" window — the mozgásidő the
     * statistics `movingMinutes` field uses for cardio
     * (docs/cardio/56-cardio-statistics-plan.md D-C3.3), not the wall-clock
     * startedAt/finishedAt span. {@link WorkoutSession#movingSeconds} is
     * null for every STRENGTH session (see its own doc comment), so summing
     * across all kinds already yields the cardio-only total — SQL/JPQL
     * {@code sum} ignores nulls — without an extra kind filter.
     */
    @Query("""
            select coalesce(sum(w.movingSeconds), 0) from WorkoutSession w
            where w.user.id = :userId and w.deletedAt is null and w.startedAt >= :from
            """)
    long sumMovingSecondsSince(@Param("userId") Long userId, @Param("from") Instant from);

    /**
     * Σ distance_meters over the same window, joined through
     * {@link WorkoutSession#cardioDetails} — those fields live on
     * {@code CardioDetails}, not {@code WorkoutSession} itself
     * (docs/cardio/52-cardio-domain-backend-plan.md §2.2). The join alone
     * excludes every STRENGTH session (no {@code CardioDetails} row to join
     * to); {@code coalesce} still guards the "no cardio sessions in range at
     * all" case, where the join yields no rows and a plain {@code sum}
     * would otherwise be {@code null}.
     */
    @Query("""
            select coalesce(sum(c.distanceMeters), 0) from WorkoutSession w join w.cardioDetails c
            where w.user.id = :userId and w.deletedAt is null and w.startedAt >= :from
            """)
    double sumDistanceMetersSince(@Param("userId") Long userId, @Param("from") Instant from);

    /** Same as {@link #sumDistanceMetersSince}, for elevation gain. */
    @Query("""
            select coalesce(sum(c.elevationGainMeters), 0) from WorkoutSession w join w.cardioDetails c
            where w.user.id = :userId and w.deletedAt is null and w.startedAt >= :from
            """)
    double sumElevationGainMetersSince(@Param("userId") Long userId, @Param("from") Instant from);

    /**
     * Completed (not just started) sessions in a range — weekly trainer report
     * (docs/33): an achievement metric, unlike {@link #countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual}
     * which counts starts for a pace metric. {@code from} inclusive, {@code toExclusive} exclusive.
     */
    long countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNull(
            Long userId, Instant from, Instant toExclusive);

    /**
     * Same as {@link #countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNull},
     * scoped to one {@link SessionKind} — the weekly trainer report's
     * strength/cardio breakdown line (docs/cardio/56-cardio-statistics-plan.md
     * §6 ST9). Only the CARDIO count is queried; the strength count is derived
     * as {@code completedWorkouts - cardioWorkouts} in the service, mirroring
     * {@link #countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndSessionKind}.
     */
    long countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNullAndSessionKind(
            Long userId, Instant from, Instant toExclusive, SessionKind kind);

    /**
     * Σ distance_meters over a bounded range, restricted to completed
     * sessions — the weekly trainer report's cardio distance line. Unlike
     * {@link #sumDistanceMetersSince} (open-ended, used by the statistics
     * screen's "since X" totals, which deliberately include an
     * still-in-progress session's accrued distance), this report only ever
     * covers a week that has already fully elapsed by the time the job runs,
     * so an unfinished session here is an abandoned one — excluded the same
     * way {@link #countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNullAndSessionKind}
     * excludes it from the breakdown count, keeping the two numbers
     * consistent with each other.
     */
    @Query("""
            select coalesce(sum(c.distanceMeters), 0) from WorkoutSession w join w.cardioDetails c
            where w.user.id = :userId and w.deletedAt is null and w.startedAt >= :from
              and w.startedAt < :toExclusive and w.finishedAt is not null
            """)
    double sumDistanceMetersBetweenForCompleted(
            @Param("userId") Long userId, @Param("from") Instant from, @Param("toExclusive") Instant toExclusive);

    /** Every trainer-scheduled occurrence for a client in a date range — upcoming, missed, done and cancelled alike. */
    List<WorkoutSession> findByUserIdAndScheduledForIsNotNullAndScheduledForBetweenOrderByScheduledForAscScheduledTimeAsc(
            Long userId, LocalDate from, LocalDate to);

    /** Same as above, aggregated across every client of a trainer — backs the trainer calendar. */
    List<WorkoutSession> findByUserIdInAndScheduledForIsNotNullAndScheduledForBetweenOrderByScheduledForAscScheduledTimeAsc(
            List<Long> userIds, LocalDate from, LocalDate to);

    /** A schedule's future, not-yet-started occurrences — the set a schedule/occurrence cancellation soft-deletes. */
    List<WorkoutSession> findByScheduleIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(
            Long scheduleId, LocalDate today);

    long countByScheduleIdAndStartedAtIsNotNull(Long scheduleId);

    long countByScheduleIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForBefore(Long scheduleId, LocalDate today);

    long countByScheduleIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(Long scheduleId, LocalDate today);

    /** A program assignment's future, not-yet-started occurrences — the set an assignment cancellation soft-deletes. */
    List<WorkoutSession> findByProgramAssignmentIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(
            Long programAssignmentId, LocalDate today);

    long countByProgramAssignmentIdAndStartedAtIsNotNull(Long programAssignmentId);

    long countByProgramAssignmentIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForBefore(Long programAssignmentId, LocalDate today);

    long countByProgramAssignmentIdAndStartedAtIsNullAndDeletedAtIsNullAndScheduledForGreaterThanEqual(Long programAssignmentId, LocalDate today);

    /** Latest non-deleted, actually-started session timestamp for a user — trainer compliance overview (docs/29). */
    @Query("select max(s.startedAt) from WorkoutSession s where s.user.id = :userId and s.deletedAt is null and s.startedAt is not null")
    Optional<Instant> findMaxStartedAtByUserId(@Param("userId") Long userId);

    /**
     * Missed trainer-scheduled occurrences for this client under this trainer, within a
     * trailing window — covers both plain-schedule and program-assignment origins (see
     * docs/34-multi-week-program-plan.md). Must stay in sync with the MISSED branch of
     * WorkoutScheduleServiceImpl#occurrenceStatus() (trainer compliance overview, docs/29).
     * Native/union rather than JPQL: a JPQL query can't cleanly express "join whichever
     * of two possible parent tables applies to this row".
     */
    @Query(nativeQuery = true, value = """
            select count(*) from (
                select s.id from workout_sessions s
                join workout_schedules ws on s.schedule_id = ws.id
                where ws.trainer_id = :trainerId
                  and s.user_id = :clientId
                  and s.started_at is null
                  and s.deleted_at is null
                  and s.scheduled_for >= :windowStart
                  and s.scheduled_for < :today
                union all
                select s.id from workout_sessions s
                join program_assignments pa on s.program_assignment_id = pa.id
                where pa.trainer_id = :trainerId
                  and s.user_id = :clientId
                  and s.started_at is null
                  and s.deleted_at is null
                  and s.scheduled_for >= :windowStart
                  and s.scheduled_for < :today
            ) missed
            """)
    long countMissedOccurrences(@Param("trainerId") Long trainerId, @Param("clientId") Long clientId,
            @Param("windowStart") LocalDate windowStart, @Param("today") LocalDate today);

    /**
     * Whether the user already started (any) workout session within a local-day
     * window — used by {@code WorkoutReminderJob} to suppress the "workout
     * today" reminder once they've already worked out that morning, even if
     * the reminder's own scheduled occurrence is a different, still-unstarted
     * row.
     */
    boolean existsByUserIdAndDeletedAtIsNullAndStartedAtBetween(Long userId, Instant from, Instant to);

    /**
     * Candidate trainer-scheduled occurrences for the workout-reminder push job
     * (docs/30-push-notifications-plan.md, B3) — not yet started, not cancelled,
     * never reminded, and within a UTC-date window wide enough to cover every
     * user timezone offset. {@code WorkoutReminderJob} narrows this down to
     * "is it actually the user's local today, at/after send hour" in Java,
     * since that needs each user's {@code utcOffsetMinutes}.
     */
    @Query("""
            select s from WorkoutSession s
            join fetch s.user
            where s.startedAt is null
              and s.deletedAt is null
              and s.reminderSentAt is null
              and s.scheduledFor between :from and :to
            """)
    List<WorkoutSession> findReminderCandidates(@Param("from") LocalDate from, @Param("to") LocalDate to);
}
