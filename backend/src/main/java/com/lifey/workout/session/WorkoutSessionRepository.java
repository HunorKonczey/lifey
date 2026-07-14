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
     * Paged history view — backs `GET /workout-sessions?page=` and the trainer
     * client-workout-sessions endpoint. Excludes upcoming/missed rows, same as
     * {@link #findAllByUserIdAndDeletedAtIsNullAndStartedAtIsNotNullOrderByStartedAtDesc}.
     */
    Page<WorkoutSession> findByUserIdAndDeletedAtIsNullAndStartedAtIsNotNull(Long userId, Pageable pageable);

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
     * Completed (not just started) sessions in a range — weekly trainer report
     * (docs/33): an achievement metric, unlike {@link #countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual}
     * which counts starts for a pace metric. {@code from} inclusive, {@code toExclusive} exclusive.
     */
    long countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqualAndStartedAtLessThanAndFinishedAtIsNotNull(
            Long userId, Instant from, Instant toExclusive);

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
