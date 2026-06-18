package com.lifey.nutrition.food;

import com.lifey.common.domain.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;

@Getter
@Setter
@Entity
@Table(name = "foods")
public class Food extends BaseEntity {

    @Column(nullable = false)
    private String name;

    @Column(name = "calories_per_100g", nullable = false)
    private double caloriesPer100g;

    @Column(name = "protein_per_100g", nullable = false)
    private double proteinPer100g;

    @Column(name = "carbs_per_100g")
    private Double carbsPer100g;

    @Column(name = "fat_per_100g")
    private Double fatPer100g;
}
