package com.lifey.steps;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface DailyStepCountRepository extends JpaRepository<DailyStepCount, Long> {

    List<DailyStepCount> findAllByUserIdAndDeletedAtIsNullOrderByDateDesc(Long userId);

    /**
     * {@code from}/{@code to} are both optional (either or both may be null) —
     * backs the `?from&to` query params on `GET /steps` and the trainer
     * client-steps endpoint alike (docs/personal_trainer/03-backend-terv.md).
     */
    @Query("select d from DailyStepCount d where d.user.id = :userId and d.deletedAt is null "
            + "and (:from is null or d.date >= :from) and (:to is null or d.date <= :to) "
            + "order by d.date desc")
    List<DailyStepCount> findByUserIdAndDeletedAtIsNullAndDateRange(
            @Param("userId") Long userId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    /**
     * Deliberately not deletedAt-filtered: the (user_id, entry_date) unique
     * constraint means re-posting steps for a previously deleted date must
     * find and revive the existing row rather than attempt a duplicate insert.
     */
    Optional<DailyStepCount> findByUserIdAndDate(Long userId, LocalDate date);

    Optional<DailyStepCount> findByIdAndUserId(Long id, Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<DailyStepCount> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
}
