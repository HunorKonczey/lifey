package com.lifey.nutrition.recipe;

import com.lifey.common.exception.ResourceNotFoundException;
import com.lifey.nutrition.food.Food;
import com.lifey.nutrition.food.FoodRepository;
import com.lifey.nutrition.recipe.dto.RecipeIngredientRequest;
import com.lifey.nutrition.recipe.dto.RecipeRequest;
import com.lifey.nutrition.recipe.dto.RecipeResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class RecipeServiceImplTest {

    @Mock
    RecipeRepository recipeRepository;

    @Mock
    FoodRepository foodRepository;

    @InjectMocks
    RecipeServiceImpl service;

    @Test
    void create_resolvesFoodsAndReturnsResponse() {
        when(foodRepository.findById(1L)).thenReturn(Optional.of(food(1L, "Chicken")));
        when(recipeRepository.save(any(Recipe.class))).thenAnswer(inv -> {
            Recipe r = inv.getArgument(0);
            r.setId(7L);
            return r;
        });
        RecipeRequest request = new RecipeRequest("Chicken & rice", "prep",
                List.of(new RecipeIngredientRequest(1L, 200.0)));

        RecipeResponse result = service.create(request);

        assertThat(result.id()).isEqualTo(7L);
        assertThat(result.name()).isEqualTo("Chicken & rice");
        assertThat(result.ingredients()).singleElement().satisfies(i -> {
            assertThat(i.foodId()).isEqualTo(1L);
            assertThat(i.foodName()).isEqualTo("Chicken");
            assertThat(i.quantityInGrams()).isEqualTo(200.0);
        });
    }

    @Test
    void create_throwsWhenFoodMissing() {
        when(foodRepository.findById(99L)).thenReturn(Optional.empty());
        RecipeRequest request = new RecipeRequest("Bad", null,
                List.of(new RecipeIngredientRequest(99L, 100.0)));

        assertThatThrownBy(() -> service.create(request))
                .isInstanceOf(ResourceNotFoundException.class)
                .hasMessageContaining("Food not found: 99");
    }

    @Test
    void update_rebuildsIngredientList() {
        Recipe existing = new Recipe();
        existing.setId(3L);
        existing.setName("Old");
        RecipeIngredient old = new RecipeIngredient();
        old.setRecipe(existing);
        old.setFood(food(2L, "Rice"));
        old.setQuantityInGrams(50.0);
        existing.getIngredients().add(old);

        when(recipeRepository.findById(3L)).thenReturn(Optional.of(existing));
        when(foodRepository.findById(1L)).thenReturn(Optional.of(food(1L, "Chicken")));
        RecipeRequest request = new RecipeRequest("New", "desc",
                List.of(new RecipeIngredientRequest(1L, 300.0)));

        RecipeResponse result = service.update(3L, request);

        assertThat(result.name()).isEqualTo("New");
        assertThat(result.ingredients()).singleElement().satisfies(i -> {
            assertThat(i.foodId()).isEqualTo(1L);
            assertThat(i.quantityInGrams()).isEqualTo(300.0);
        });
        // old ingredient replaced (orphanRemoval handles deletion at flush)
        assertThat(existing.getIngredients()).hasSize(1);
    }

    @Test
    void findById_throwsWhenMissing() {
        when(recipeRepository.findById(99L)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> service.findById(99L))
                .isInstanceOf(ResourceNotFoundException.class);
    }

    private static Food food(Long id, String name) {
        Food f = new Food();
        f.setId(id);
        f.setName(name);
        f.setCaloriesPer100g(100);
        f.setProteinPer100g(10);
        return f;
    }
}
