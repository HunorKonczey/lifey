package com.lifey.vitals;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface DailyVitalsRepository extends JpaRepository<DailyVitals, Long> {

    List<DailyVitals> findAllByUserIdAndDeletedAtIsNullOrderByDateDesc(Long userId);

    /**
     * {@code from}/{@code to} are never null: open bounds come in as {@link com.lifey.common.util.DateRanges}
     * constants. See {@link com.lifey.steps.DailyStepCountRepository} for why an {@code is null} predicate breaks on
     * Postgres.
     */
    @Query("select v from DailyVitals v where v.user.id = :userId and v.deletedAt is null "
            + "and v.date >= :from and v.date <= :to order by v.date desc")
    List<DailyVitals> findByUserIdAndDeletedAtIsNullAndDateRange(
            @Param("userId") Long userId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    /**
     * Deliberately not deletedAt-filtered: the (user_id, entry_date) unique constraint means re-posting a deleted
     * day must revive the existing row rather than insert a duplicate.
     */
    Optional<DailyVitals> findByUserIdAndDate(Long userId, LocalDate date);

    Optional<DailyVitals> findByIdAndUserId(Long id, Long userId);

    /** Delta-sync feed: deliberately not deletedAt-filtered, so the client gets the tombstones. */
    Page<DailyVitals> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
}
