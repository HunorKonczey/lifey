package com.lifey.nutrition.meal;

import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.meal.dto.MealEntryResponse;
import com.lifey.nutrition.meal.dto.MealResponse;
import com.lifey.nutrition.recipe.Recipe;
import org.junit.jupiter.api.Test;

import java.time.Instant;

import static org.assertj.core.api.Assertions.assertThat;

/** A meal entry's fibre and sugar scale with the grams like the other macros, and stay null when the food has none (LIF-145). */
class MealMapperTest {

    private static Food food(String name, Double fiber, Double sugar) {
        Food food = new Food();
        food.setId(1L);
        food.setName(name);
        food.setCaloriesPer100g(370);
        food.setProteinPer100g(13);
        food.setCarbsPer100g(60.0);
        food.setFatPer100g(7.0);
        food.setFiberPer100g(fiber);
        food.setSugarPer100g(sugar);
        return food;
    }

    private static MealResponse map(Food food, double grams) {
        Meal meal = new Meal();
        meal.setId(5L);
        meal.setDateTime(Instant.parse("2026-10-09T07:00:00Z"));
        MealEntry entry = new MealEntry();
        entry.setFood(food);
        entry.setQuantityInGrams(grams);
        meal.getEntries().add(entry);
        return MealMapper.toResponse(meal);
    }

    @Test
    void fibreAndSugarScaleWithTheGrams() {
        MealEntryResponse entry = map(food("Oats", 10.0, 1.2), 150).entries().get(0);

        assertThat(entry.fiber()).isEqualTo(15.0);
        assertThat(entry.sugar()).isEqualTo(1.8, org.assertj.core.data.Offset.offset(1e-9));
    }

    @Test
    void anEntryAddedAsPartOfARecipeNamesIt() {
        Meal meal = new Meal();
        meal.setId(5L);
        meal.setDateTime(Instant.parse("2026-10-09T07:00:00Z"));
        Recipe recipe = new Recipe();
        recipe.setId(7L);
        recipe.setName("Chilli");
        MealEntry tagged = new MealEntry();
        tagged.setFood(food("Beans", null, null));
        tagged.setQuantityInGrams(100);
        tagged.setRecipe(recipe);
        MealEntry loose = new MealEntry();
        loose.setFood(food("Salad", null, null));
        loose.setQuantityInGrams(50);
        meal.getEntries().add(tagged);
        meal.getEntries().add(loose);

        MealResponse response = MealMapper.toResponse(meal);

        assertThat(response.entries().get(0).recipeId()).isEqualTo(7L);
        assertThat(response.entries().get(0).recipeName()).isEqualTo("Chilli");
        assertThat(response.entries().get(1).recipeId()).isNull();
        assertThat(response.entries().get(1).recipeName()).isNull();
    }

    @Test
    void aFoodWithoutFigures_givesNullNotZero() {
        MealEntryResponse entry = map(food("Mystery bar", null, null), 150).entries().get(0);

        assertThat(entry.fiber()).isNull();
        assertThat(entry.sugar()).isNull();
        // the other macros are unaffected
        assertThat(entry.carbs()).isEqualTo(90.0);
    }
}
