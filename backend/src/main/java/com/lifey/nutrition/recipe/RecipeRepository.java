package com.lifey.nutrition.recipe;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface RecipeRepository extends JpaRepository<Recipe, Long> {

    List<Recipe> findAllByUserIdAndDeletedAtIsNullOrderByFavoriteDescNameAsc(Long userId);

    Page<Recipe> findByUserIdAndDeletedAtIsNull(Long userId, Pageable pageable);

    /** Accent-insensitive on top of case-insensitive — see FoodRepository's equivalent method for the rationale. */
    @Query("SELECT r FROM Recipe r WHERE r.user.id = :userId AND r.deletedAt IS NULL "
            + "AND cast(function('unaccent', lower(r.name)) as string) "
            + "LIKE cast(function('unaccent', lower(concat('%', :search, '%'))) as string)")
    Page<Recipe> findByUserIdAndDeletedAtIsNullAndNameContainingIgnoreCase(
            @Param("userId") Long userId, @Param("search") String search, Pageable pageable);

    Optional<Recipe> findByIdAndUserId(Long id, Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<Recipe> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);
}
