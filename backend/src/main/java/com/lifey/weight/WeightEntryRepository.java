package com.lifey.weight;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface WeightEntryRepository extends JpaRepository<WeightEntry, Long> {

    List<WeightEntry> findAllByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(Long userId);

    /**
     * Newest-first, limited via {@code pageable} — backs the trainer
     * dashboard's weight-trend sparkline (docs/personal_trainer/06-design.md
     * §3.2), which only needs the last handful of entries, not the full history.
     */
    List<WeightEntry> findAllByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(Long userId, Pageable pageable);

    /**
     * {@code from}/{@code to} bound the range — callers with an open-ended
     * bound pass {@link com.lifey.common.util.DateRanges#DISTANT_PAST}/{@code
     * _FUTURE} rather than null (see WeightServiceImpl#findAllForUser). Do not
     * change this back to a {@code (:from is null or ...)} form: Postgres can't
     * infer a type for a parameter used only in an {@code is null} check
     * ("could not determine data type of parameter $n"), and it only surfaces
     * once exactly one of from/to is non-null in a caller's actual query —
     * passing both null lets Hibernate simplify the predicate away and never
     * hits the bug, which is how this shipped unnoticed.
     */
    @Query("select w from WeightEntry w where w.user.id = :userId and w.deletedAt is null "
            + "and w.date >= :from and w.date <= :to "
            + "order by w.date desc, w.recordedAt desc")
    List<WeightEntry> findByUserIdAndDeletedAtIsNullAndDateRange(
            @Param("userId") Long userId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    Optional<WeightEntry> findFirstByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(Long userId);

    /** Newest entry strictly before a date — baseline for the weekly trainer report's weight-change calc (docs/33). */
    Optional<WeightEntry> findFirstByUserIdAndDeletedAtIsNullAndDateLessThanOrderByDateDescRecordedAtDesc(
            Long userId, LocalDate date);

    Optional<WeightEntry> findByIdAndUserId(Long id, Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<WeightEntry> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
}
