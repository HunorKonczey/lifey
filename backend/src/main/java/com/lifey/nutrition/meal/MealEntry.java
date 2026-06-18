package com.lifey.nutrition.meal;

import com.lifey.common.domain.BaseEntity;
import com.lifey.nutrition.food.Food;
import jakarta.persistence.Entity;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "meal_entries")
public class MealEntry extends BaseEntity {

    @ManyToOne
    private Meal meal;

    @ManyToOne
    private Food food;

    private Double quantityInGrams;

    // Getters and setters.
}
