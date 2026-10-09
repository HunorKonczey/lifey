package com.lifey.nutrition.food;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

/** A named serving size of a food (LIF-146): "1 glass" = 150 g. Part of the food, not an entity of its own. */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Embeddable
public class FoodServing {

    @Column(nullable = false, length = 40)
    private String name;

    @Column(nullable = false)
    private double grams;
}
