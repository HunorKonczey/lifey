package com.lifey.nutrition.recipe;

import com.lifey.common.domain.BaseEntity;
import com.lifey.nutrition.food.Food;
import jakarta.persistence.Entity;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "recipe_ingredients")
public class RecipeIngredient extends BaseEntity {

    @ManyToOne
    private Recipe recipe;

    @ManyToOne
    private Food food;

    private Double quantityInGrams;

    // Getters and setters.
}
