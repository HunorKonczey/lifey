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
     * {@code from} is inclusive, {@code toExclusive} is exclusive — callers pass
     * the day after the last day they want included (see
     * MealServiceImpl#findAllForUserBetween).
     */
    @Query("""
            select m from Meal m
            where m.user.id = :userId and m.deletedAt is null
              and m.dateTime >= :from and m.dateTime < :toExclusive
            order by m.dateTime desc
            """)
    List<Meal> findAllByUserIdAndDeletedAtIsNullAndDateTimeRange(
            @Param("userId") Long userId, @Param("from") Instant from, @Param("toExclusive") Instant toExclusive);

    /**
     * Delta-sync feed (docs/16-delta-sync-rollout.md) — deliberately not
     * deletedAt-filtered: it must surface tombstoned rows (deletedAt set) so
     * the mobile client can remove them locally.
     */
    Page<Meal> findByUserIdAndUpdatedAtGreaterThanEqual(Long userId, Instant since, Pageable pageable);

    /** Latest non-deleted meal timestamp for a user — trainer compliance overview (docs/29). */
    @Query("select max(m.dateTime) from Meal m where m.user.id = :userId and m.deletedAt is null")
    Optional<Instant> findMaxDateTimeByUserId(@Param("userId") Long userId);

    @Query("""
            select coalesce(sum(f.caloriesPer100g * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from and e.meal.deletedAt is null
            """)
    double sumCaloriesSince(@Param("userId") Long userId, @Param("from") Instant from);

    /** Same as {@link #sumCaloriesSince} with an upper bound — weekly trainer report (docs/33), one call per client-day. */
    @Query("""
            select coalesce(sum(f.caloriesPer100g * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from and e.meal.dateTime < :toExclusive
              and e.meal.deletedAt is null
            """)
    double sumCaloriesBetween(@Param("userId") Long userId, @Param("from") Instant from, @Param("toExclusive") Instant toExclusive);

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
