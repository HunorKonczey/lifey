package com.lifey.workout.session;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

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

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<WorkoutSession> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);

    long countByUserIdAndDeletedAtIsNullAndStartedAtGreaterThanEqual(Long userId, Instant from);

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
}
