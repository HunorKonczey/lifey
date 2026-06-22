package com.lifey.nutrition.meal;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface MealRepository extends JpaRepository<Meal, Long> {

    List<Meal> findAllByUserIdOrderByDateTimeDesc(Long userId);

    Optional<Meal> findByIdAndUserId(Long id, Long userId);

    boolean existsByIdAndUserId(Long id, Long userId);

    void deleteByIdAndUserId(Long id, Long userId);

    @Query("""
            select coalesce(sum(f.caloriesPer100g * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from
            """)
    double sumCaloriesSince(@Param("userId") Long userId, @Param("from") Instant from);

    @Query("""
            select coalesce(sum(f.proteinPer100g * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from
            """)
    double sumProteinSince(@Param("userId") Long userId, @Param("from") Instant from);

    @Query("""
            select coalesce(sum(coalesce(f.carbsPer100g, 0) * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from
            """)
    double sumCarbsSince(@Param("userId") Long userId, @Param("from") Instant from);

    @Query("""
            select coalesce(sum(coalesce(f.fatPer100g, 0) * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.user.id = :userId and e.meal.dateTime >= :from
            """)
    double sumFatSince(@Param("userId") Long userId, @Param("from") Instant from);
}
