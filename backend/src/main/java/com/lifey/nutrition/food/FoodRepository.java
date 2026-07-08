package com.lifey.nutrition.food;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface FoodRepository extends JpaRepository<Food, Long> {

    List<Food> findAllByUserIdAndHiddenFalseOrderByName(Long userId);

    Page<Food> findByUserIdAndHiddenFalse(Long userId, Pageable pageable);

    /**
     * Accent-insensitive (e.g. "a" matches "á") on top of case-insensitive,
     * via Postgres' {@code unaccent} extension (see V47__unaccent_search.sql).
     * Uses Hibernate's generic {@code function()} passthrough so entity
     * property paths (not raw column names) are preserved for Pageable sorting.
     */
    @Query("SELECT f FROM Food f WHERE f.user.id = :userId AND f.hidden = false "
            + "AND cast(function('unaccent', lower(f.name)) as string) "
            + "LIKE cast(function('unaccent', lower(concat('%', :search, '%'))) as string)")
    Page<Food> findByUserIdAndHiddenFalseAndNameContainingIgnoreCase(
            @Param("userId") Long userId, @Param("search") String search, Pageable pageable);

    /**
     * Delta-sync feed (docs/15-delta-sync.md) — deliberately not
     * hidden-filtered: it must surface tombstoned rows (hidden = true,
     * deletedAt set) and any edit to an already-hidden shadow food.
     */
    Page<Food> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);

    Optional<Food> findByUserIdAndNameIgnoreCase(Long userId, String name);

    /**
     * Matches the {@code foods_name_unique_idx} conflict check (visible foods
     * only) for the trainer content-assignment deep copy — see
     * ContentAssignmentServiceImpl.
     */
    Optional<Food> findByUserIdAndNameIgnoreCaseAndHiddenFalse(Long userId, String name);

    Optional<Food> findByIdAndUserId(Long id, Long userId);

    Optional<Food> findByUserIdAndBarcode(Long userId, String barcode);

    /** Dedupe lookup for the trainer content-assignment deep copy (see ContentAssignmentServiceImpl). */
    Optional<Food> findByUserIdAndOriginTrainerIdAndOriginSourceIdAndDeletedAtIsNull(
            Long userId, Long originTrainerId, Long originSourceId);
}
