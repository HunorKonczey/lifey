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
     * {@code from}/{@code to} bound the range — callers with an open-ended
     * bound pass {@link com.lifey.common.util.DateRanges#DISTANT_PAST}/{@code
     * _FUTURE} rather than null (see DailyStepCountServiceImpl#findAllForUser).
     * Do not change this back to a {@code (:from is null or ...)} form:
     * Postgres can't infer a type for a parameter used only in an {@code is
     * null} check ("could not determine data type of parameter $n"), and it
     * only surfaces once exactly one of from/to is non-null in a caller's
     * actual query — passing both null lets Hibernate simplify the predicate
     * away and never hits the bug, which is how this shipped unnoticed.
     */
    @Query("select d from DailyStepCount d where d.user.id = :userId and d.deletedAt is null "
            + "and d.date >= :from and d.date <= :to "
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
