package com.lifey.nutrition.food;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "foods")
public class Food extends BaseEntity {

    private String name;

    private Double caloriesPer100g;

    private Double proteinPer100g;

    private Double carbsPer100g;

    private Double fatPer100g;

    // Getters and setters.
}
