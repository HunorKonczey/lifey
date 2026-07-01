package com.lifey.nutrition.recipe;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface RecipeRepository extends JpaRepository<Recipe, Long> {

    List<Recipe> findAllByUserIdAndDeletedAtIsNullOrderByFavoriteDescNameAsc(Long userId);

    Page<Recipe> findByUserIdAndDeletedAtIsNull(Long userId, Pageable pageable);

    Page<Recipe> findByUserIdAndDeletedAtIsNullAndNameContainingIgnoreCase(
            Long userId, String search, Pageable pageable);

    Optional<Recipe> findByIdAndUserId(Long id, Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<Recipe> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
}
