package com.lifey.nutrition.recipe.generation.dto;

/**
 * Deliberately its own enum rather than {@code nutrition.meal.MealType}: this
 * one is a prompt setting that may grow (brunch, pre-workout, …) without
 * touching what a logged meal can be.
 */
public enum MealType {
    BREAKFAST,
    LUNCH,
    DINNER,
    SNACK
}
