package com.lifey.nutrition.food;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface FoodRepository extends JpaRepository<Food, Long> {

    List<Food> findAllByUserIdAndHiddenFalseOrderByName(Long userId);

    Page<Food> findByUserIdAndHiddenFalse(Long userId, Pageable pageable);

    Page<Food> findByUserIdAndHiddenFalseAndNameContainingIgnoreCase(Long userId, String search, Pageable pageable);

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
