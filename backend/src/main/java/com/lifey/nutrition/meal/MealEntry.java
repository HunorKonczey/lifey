package com.lifey.nutrition.meal;

import com.lifey.common.domain.BaseEntity;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.recipe.Recipe;
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

    /**
     * The recipe this entry came from, when it was added as part of one (docs/88); null for entries added as plain foods,
     * macros or a photo estimate, and for entries of a recipe that has since been deleted for good. Soft-deleted recipes
     * stay referenced.
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "recipe_id")
    private Recipe recipe;
}
