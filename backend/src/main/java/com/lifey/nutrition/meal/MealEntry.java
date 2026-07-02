package com.lifey.nutrition.meal;

import com.lifey.common.domain.BaseEntity;
import com.lifey.nutrition.food.Food;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "meal_entries")
public class MealEntry extends BaseEntity {

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "meal_id", nullable = false)
    private Meal meal;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "food_id", nullable = false)
    private Food food;

    @Column(name = "quantity_in_grams", nullable = false)
    private double quantityInGrams;
}
