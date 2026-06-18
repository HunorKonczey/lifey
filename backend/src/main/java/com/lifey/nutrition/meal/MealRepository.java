package com.lifey.nutrition.meal;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

public interface MealRepository extends JpaRepository<Meal, Long> {

    List<Meal> findAllByOrderByDateTimeDesc();

    @Query("""
            select coalesce(sum(f.caloriesPer100g * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.dateTime >= :from
            """)
    double sumCaloriesSince(@Param("from") LocalDateTime from);

    @Query("""
            select coalesce(sum(f.proteinPer100g * e.quantityInGrams / 100.0), 0)
            from MealEntry e join e.food f
            where e.meal.dateTime >= :from
            """)
    double sumProteinSince(@Param("from") LocalDateTime from);
}
