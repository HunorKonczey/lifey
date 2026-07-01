package com.lifey.nutrition.meal;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface MealRepository extends JpaRepository<Meal, Long> {

    List<Meal> findAllByUserIdAndDeletedAtIsNullOrderByDateTimeDesc(Long userId);

    Optional<Meal> findByIdAndUserId(Long id, Long userId);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<Meal> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);

    @Query("""
            select coalesce(sum(f.caloriesPer100g * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from and e.meal.deletedAt is null
            """)
    double sumCaloriesSince(@Param("userId") Long userId, @Param("from") Instant from);

    @Query("""
            select coalesce(sum(f.proteinPer100g * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from and e.meal.deletedAt is null
            """)
    double sumProteinSince(@Param("userId") Long userId, @Param("from") Instant from);

    @Query("""
            select coalesce(sum(coalesce(f.carbsPer100g, 0) * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from and e.meal.deletedAt is null
            """)
    double sumCarbsSince(@Param("userId") Long userId, @Param("from") Instant from);

    @Query("""
            select coalesce(sum(coalesce(f.fatPer100g, 0) * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from and e.meal.deletedAt is null
            """)
    double sumFatSince(@Param("userId") Long userId, @Param("from") Instant from);
}
