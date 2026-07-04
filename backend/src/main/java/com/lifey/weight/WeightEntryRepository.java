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
     * {@code from}/{@code to} are both optional (either or both may be null) —
     * backs the `?from&to` query params on `GET /weights` and the trainer
     * client-weights endpoint alike (docs/personal_trainer/03-backend-terv.md).
     */
    @Query("select w from WeightEntry w where w.user.id = :userId and w.deletedAt is null "
            + "and (:from is null or w.date >= :from) and (:to is null or w.date <= :to) "
            + "order by w.date desc, w.recordedAt desc")
    List<WeightEntry> findByUserIdAndDeletedAtIsNullAndDateRange(
            @Param("userId") Long userId, @Param("from") LocalDate from, @Param("to") LocalDate to);

    Optional<WeightEntry> findFirstByUserIdAndDeletedAtIsNullOrderByDateDescRecordedAtDesc(Long userId);

    Optional<WeightEntry> findByIdAndUserId(Long id, Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<WeightEntry> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
}
